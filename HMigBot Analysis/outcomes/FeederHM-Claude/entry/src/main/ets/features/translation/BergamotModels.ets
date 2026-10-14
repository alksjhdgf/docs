/*
 * BergamotModels — Bergamot 离线翻译模型清单/下载/管理/删除。
 * 源：localtranslation/BergamotModelManager.kt（全量语义）。
 *   - 清单：Mozilla Remote Settings `translations-models`，缓存 `registry-v3.json`，7 天新鲜期；离线用缓存（TR-A22）。
 *   - 记录过滤：filter_expression 为空或 Android；同对多版本稳定优先再取最大版本；缺 model/lex/词表丢弃（TR-A23）。
 *   - 中转：无直连且两端非 en → src→en + en→dst（TR-A24）。
 *   - 下载：`.download` 临时文件 → SHA-256 校验 → 移动；无哈希/不符即失败且清理（TR-A25/26）；运行时 WASM 同理（TR-A27）。
 *   - 全局串行 + 进度发布（结束清空）（TR-A28）；存储 `<filesDir>/translation-models/bergamot/<from>-<to>/`（TR-A29）。
 * 大文件下载走 request.agent（带进度、直接落盘）；无 Ability 上下文时（主机单测）回落 HttpClient。
 */
import { request } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { HttpClient } from '../../core/net/HttpClient';
import { HttpRequest } from '../../core/net/HttpMessages';
import { decodeUtf8 } from '../../core/util/TextCodec';
import {
  deleteFile, deleteRecursively, directorySize, isDirectory, isFile, joinPath, lastModifiedMs, mkdirs, moveReplacing,
  parentDir, readTextOrNull, sha256OfFile, writeBytes, writeText
} from './TranslationIo';
import { normalizeLanguageCode } from './LanguageUtils';
import {
  BergamotLanguagePairStatus, BergamotModelDownloadProgress, BergamotModelFile, BergamotModelPreparation,
  BergamotModelRegistryEntry, BergamotPreparationError, LanguagePairInfo, ModelDownloadState, parseRegistry,
  resolvePath, AsyncMutex, BergamotProgressBus
} from './BergamotRegistry';

export {
  BergamotLanguagePairStatus, BergamotModelDownloadProgress, BergamotModelFile, BergamotModelPreparation,
  BergamotModelRegistryEntry, BergamotPreparationError, LanguagePairInfo
} from './BergamotRegistry';

export const DEFAULT_REGISTRY_URL: string =
  'https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/translations-models/records?_limit=10000';
export const MOZILLA_ATTACHMENT_BASE_URL: string = 'https://firefox-settings-attachments.cdn.mozilla.net/';
export const REGISTRY_FILE_NAME: string = 'registry-v3.json';
export const REGISTRY_MAX_AGE_MS: number = 7 * 24 * 60 * 60 * 1000;
export const RUNTIME_FILE_NAME: string = 'bergamot-translator-worker.wasm';
export const RUNTIME_SIZE_BYTES: number = 5174294;
export const RUNTIME_SHA256: string = '95a2b58dd6773bf1b3f345d71f9149928b9f75f4ec9c9064c0b3e42c298671b2';
export const DEFAULT_RUNTIME_URL: string =
  'https://cdn.jsdelivr.net/npm/@browsermt/bergamot-translator@0.4.5/worker/bergamot-translator-worker.wasm';

/** 网络抽象（源 OkHttpClient）：便于单测注入 */
export interface BergamotFetcher {
  /** GET 文本；非 2xx 或 IO 失败返回 null */
  fetchText(url: string): Promise<string | null>;
  /** 下载到 destPath；onBytes 收到新增字节数；非 2xx/IO 失败返回 false */
  download(url: string, destPath: string, onBytes: (delta: number) => void): Promise<boolean>;
}

class HttpBergamotFetcher implements BergamotFetcher {
  async fetchText(url: string): Promise<string | null> {
    try {
      const resp = await HttpClient.main().execute(HttpRequest.get(url));
      if (!resp.isSuccessful() || resp.body === null) {
        return null;
      }
      return decodeUtf8(new Uint8Array(resp.body));
    } catch (e) {
      return null;
    }
  }

  async download(url: string, destPath: string, onBytes: (delta: number) => void): Promise<boolean> {
    const ctx = AppBootstrap.context();
    if (ctx !== null) {
      return this.downloadWithAgent(ctx, url, destPath, onBytes);
    }
    try {
      const resp = await HttpClient.main().execute(HttpRequest.get(url));
      if (!resp.isSuccessful() || resp.body === null) {
        return false;
      }
      const bytes = new Uint8Array(resp.body);
      writeBytes(destPath, bytes);
      onBytes(bytes.length);
      return true;
    } catch (e) {
      return false;
    }
  }

  private downloadWithAgent(ctx: common.UIAbilityContext, url: string, destPath: string,
    onBytes: (delta: number) => void): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const config: request.agent.Config = {
        action: request.agent.Action.DOWNLOAD,
        url: url,
        saveas: destPath,
        overwrite: true,
        mode: request.agent.Mode.FOREGROUND,
        network: request.agent.Network.ANY,
        gauge: false,
        retry: true,
        redirect: true
      };
      let lastProcessed = 0;
      let httpOk = true;
      let settled = false;
      let taskId = '';
      const finish = (ok: boolean): void => {
        if (settled) {
          return;
        }
        settled = true;
        if (taskId.length > 0) {
          request.agent.remove(taskId).catch((e: Error) => {
            console.warn(`BergamotModels: remove task failed: ${e?.message}`);
          });
        }
        resolve(ok && httpOk);
      };
      request.agent.create(ctx, config).then((task: request.agent.Task) => {
        taskId = task.tid;
        task.on('progress', (p: request.agent.Progress) => {
          const delta = p.processed - lastProcessed;
          if (delta > 0) {
            lastProcessed = p.processed;
            onBytes(delta);
          }
        });
        task.on('response', (r: request.agent.HttpResponse) => {
          if (r.statusCode < 200 || r.statusCode >= 300) {
            httpOk = false;
          }
        });
        task.on('completed', (p: request.agent.Progress) => {
          const delta = p.processed - lastProcessed;
          if (delta > 0) {
            lastProcessed = p.processed;
            onBytes(delta);
          }
          finish(true);
        });
        task.on('failed', (p: request.agent.Progress) => {
          finish(false);
        });
        task.start().catch((e: Error) => {
          console.warn(`BergamotModels: start download failed: ${e?.message}`);
          finish(false);
        });
      }).catch((e: Error) => {
        console.warn(`BergamotModels: create download failed: ${e?.message}`);
        finish(false);
      });
    });
  }
}

function sanitizedModelFileName(name: string): string {
  const base = name.substring(name.lastIndexOf('/') + 1);
  const cleaned = base.replace(new RegExp('[^A-Za-z0-9._-]+', 'g'), '_');
  return cleaned.trim().length === 0 ? 'model-file' : cleaned;
}

export class BergamotModelManager {
  private static inst: BergamotModelManager | null = null;

  private readonly rootOverride: string | null;
  private readonly registryUrl: string;
  private readonly attachmentBaseUrl: string;
  private readonly runtimeUrl: string;
  private readonly runtimeSha256: string;
  private readonly fetcher: BergamotFetcher;
  private readonly downloadMutex: AsyncMutex = new AsyncMutex();
  /** 源 downloadProgress: StateFlow */
  readonly progress: BergamotProgressBus = new BergamotProgressBus();

  constructor(rootDir: string | null = null, registryUrl: string = DEFAULT_REGISTRY_URL,
    attachmentBaseUrl: string = MOZILLA_ATTACHMENT_BASE_URL, runtimeUrl: string = DEFAULT_RUNTIME_URL,
    runtimeSha256: string = RUNTIME_SHA256, fetcher: BergamotFetcher | null = null) {
    this.rootOverride = rootDir;
    this.registryUrl = registryUrl;
    this.attachmentBaseUrl = attachmentBaseUrl;
    this.runtimeUrl = runtimeUrl;
    this.runtimeSha256 = runtimeSha256;
    this.fetcher = fetcher !== null ? fetcher : new HttpBergamotFetcher();
  }

  static instance(): BergamotModelManager {
    if (BergamotModelManager.inst === null) {
      BergamotModelManager.inst = new BergamotModelManager();
    }
    return BergamotModelManager.inst as BergamotModelManager;
  }

  /** `<filesDir>/translation-models/bergamot` */
  storageLocation(): string {
    if (this.rootOverride !== null) {
      return this.rootOverride;
    }
    const paths = AppBootstrap.filePaths();
    const filesDir = paths !== null ? paths.filesDir : '';
    return joinPath(joinPath(filesDir, 'translation-models'), 'bergamot');
  }

  private registryFile(): string {
    return joinPath(this.storageLocation(), REGISTRY_FILE_NAME);
  }

  private runtimeFile(): string {
    return joinPath(this.storageLocation(), RUNTIME_FILE_NAME);
  }

  pairDir(from: string, to: string): string {
    return joinPath(this.storageLocation(), `${from}-${to}`);
  }

  /** 当前下载进度（null = 无下载） */
  downloadProgress(): BergamotModelDownloadProgress | null {
    return this.progress.value;
  }

  private runtimeVerified(): boolean {
    const f = this.runtimeFile();
    return isFile(f) && sha256OfFile(f).toLowerCase() === this.runtimeSha256.toLowerCase();
  }

  async isRuntimeDownloaded(): Promise<boolean> {
    return this.runtimeVerified();
  }

  /** TR-A27：已校验则不再下载；哈希不符视为失败 */
  async downloadRuntime(): Promise<boolean> {
    return this.downloadMutex.withLock<boolean>(async (): Promise<boolean> => {
      try {
        if (this.runtimeVerified()) {
          return true;
        }
        const dest = this.runtimeFile();
        mkdirs(parentDir(dest));
        const file = new BergamotModelFile(RUNTIME_FILE_NAME, this.runtimeUrl, RUNTIME_SIZE_BYTES, this.runtimeSha256);
        return await this.downloadFile(file, dest, '', '', new ModelDownloadState(RUNTIME_SIZE_BYTES), true);
      } finally {
        this.progress.set(null);
      }
    });
  }

  /** 源 runtimeFileUrl()：`file://` URI 或 null */
  async runtimeFileUrl(): Promise<string | null> {
    return this.runtimeVerified() ? `file://${this.runtimeFile()}` : null;
  }

  /** TR-A28/A46：确保语言对（含中转）模型已下载 */
  async prepare(sourceLanguage: string, targetLanguage: string): Promise<BergamotModelPreparation> {
    return this.downloadMutex.withLock<BergamotModelPreparation>(async (): Promise<BergamotModelPreparation> => {
      const source = normalizeLanguageCode(sourceLanguage);
      const target = normalizeLanguageCode(targetLanguage);
      try {
        const registry = await this.loadRegistry(true, source, target);
        if (registry === null) {
          return BergamotModelPreparation.error(BergamotPreparationError.RegistryMissing, source, target);
        }
        const path = resolvePath(registry, source, target);
        if (path === null) {
          return BergamotModelPreparation.error(BergamotPreparationError.NoAppModel, source, target);
        }
        const downloadState = ModelDownloadState.forPath(path);
        const entries: BergamotModelRegistryEntry[] = [];
        for (let i = 0; i < path.length; i++) {
          const entry = path[i];
          const downloaded = await this.ensureDownloaded(entry, downloadState);
          if (downloaded === null) {
            return BergamotModelPreparation.error(BergamotPreparationError.DownloadFailed, entry.from, entry.to);
          }
          entries.push(downloaded);
        }
        return BergamotModelPreparation.ready(entries);
      } finally {
        this.progress.set(null);
      }
    });
  }

  /** TR-A20：allowNetwork=false 时只读缓存清单，不联网 */
  async languagePairStatus(sourceLanguage: string, targetLanguage: string,
    allowNetwork: boolean = true): Promise<BergamotLanguagePairStatus> {
    const source = normalizeLanguageCode(sourceLanguage);
    const target = normalizeLanguageCode(targetLanguage);
    const registry = await this.loadRegistry(allowNetwork, null, null);
    if (registry === null) {
      return BergamotLanguagePairStatus.RegistryMissing;
    }
    const path = resolvePath(registry, source, target);
    if (path === null) {
      return BergamotLanguagePairStatus.Unavailable;
    }
    for (let i = 0; i < path.length; i++) {
      if (!this.isDownloaded(path[i])) {
        return BergamotLanguagePairStatus.AvailableToDownload;
      }
    }
    return BergamotLanguagePairStatus.Downloaded;
  }

  /** TR-A29：删除语言对（含中转路径各段）目录 */
  async deleteLanguagePair(sourceLanguage: string, targetLanguage: string): Promise<void> {
    const source = normalizeLanguageCode(sourceLanguage);
    const target = normalizeLanguageCode(targetLanguage);
    const registry = await this.loadRegistry(false, null, null);
    if (registry === null) {
      return;
    }
    const path = resolvePath(registry, source, target);
    if (path === null) {
      return;
    }
    for (let i = 0; i < path.length; i++) {
      deleteRecursively(this.pairDir(path[i].from, path[i].to));
    }
  }

  /** TR-A29/A47：文件齐全的语言对与目录总字节 */
  async getDownloadedLanguagePairs(): Promise<LanguagePairInfo[]> {
    const registry = await this.loadRegistry(false, null, null);
    if (registry === null) {
      return [];
    }
    const out: LanguagePairInfo[] = [];
    for (let i = 0; i < registry.length; i++) {
      const entry = registry[i];
      const dir = this.pairDir(entry.from, entry.to);
      if (!isDirectory(dir)) {
        continue;
      }
      let complete = true;
      entry.files.forEach((file: BergamotModelFile) => {
        if (!isFile(joinPath(dir, sanitizedModelFileName(file.name)))) {
          complete = false;
        }
      });
      if (complete) {
        out.push(new LanguagePairInfo(entry.from, entry.to, directorySize(dir)));
      }
    }
    return out;
  }

  async getRegistryEntries(): Promise<BergamotModelRegistryEntry[]> {
    const r = await this.loadRegistry(false, null, null);
    return r !== null ? r : [];
  }

  private async loadRegistry(allowNetwork: boolean, sourceLanguage: string | null,
    targetLanguage: string | null): Promise<BergamotModelRegistryEntry[] | null> {
    const file = this.registryFile();
    const text = readTextOrNull(file);
    const cached = text !== null ? parseRegistry(text, this.attachmentBaseUrl) : null;
    if (cached !== null) {
      const isFresh = Date.now() - lastModifiedMs(file) < REGISTRY_MAX_AGE_MS;
      if (isFresh || !allowNetwork) {
        return cached;
      }
    }
    if (allowNetwork) {
      if (sourceLanguage !== null && targetLanguage !== null) {
        this.progress.set(new BergamotModelDownloadProgress(sourceLanguage, targetLanguage, REGISTRY_FILE_NAME, 0, 0,
          false));
      }
      const fetched = await this.fetchRegistry();
      if (fetched !== null) {
        return fetched;
      }
    }
    return cached;
  }

  private async fetchRegistry(): Promise<BergamotModelRegistryEntry[] | null> {
    try {
      const body = await this.fetcher.fetchText(this.registryUrl);
      if (body === null) {
        return null;
      }
      const parsed = parseRegistry(body, this.attachmentBaseUrl);
      if (parsed === null) {
        return null;
      }
      writeText(this.registryFile(), body);
      return parsed;
    } catch (e) {
      return null;
    }
  }

  private matchesSha256(file: BergamotModelFile, path: string): boolean {
    return file.expectedSha256Hash.trim().length > 0 &&
      sha256OfFile(path).toLowerCase() === file.expectedSha256Hash.toLowerCase();
  }

  private isDownloaded(entry: BergamotModelRegistryEntry): boolean {
    const dir = this.pairDir(entry.from, entry.to);
    let all = true;
    entry.files.forEach((file: BergamotModelFile) => {
      if (!all) {
        return;
      }
      const local = joinPath(dir, sanitizedModelFileName(file.name));
      if (!(isFile(local) && this.matchesSha256(file, local))) {
        all = false;
      }
    });
    return all;
  }

  /** TR-A25/A26 */
  private async ensureDownloaded(entry: BergamotModelRegistryEntry,
    downloadState: ModelDownloadState): Promise<BergamotModelRegistryEntry | null> {
    const downloadedFiles = new Map<string, BergamotModelFile>();
    const dir = this.pairDir(entry.from, entry.to);
    mkdirs(dir);
    const parts: string[] = [];
    entry.files.forEach((_f: BergamotModelFile, part: string) => {
      parts.push(part);
    });
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      const file = entry.files.get(part) as BergamotModelFile;
      if (file.expectedSha256Hash.trim().length === 0) {
        return null;
      }
      const localFile = joinPath(dir, sanitizedModelFileName(file.name));
      let ready = false;
      if (isFile(localFile) && this.matchesSha256(file, localFile)) {
        downloadState.addAlreadyDownloaded(file);
        ready = true;
      } else {
        ready = await this.downloadFile(file, localFile, entry.from, entry.to, downloadState, false);
      }
      if (!ready) {
        return null;
      }
      downloadedFiles.set(part, file.withUrl(`file://${localFile}`));
    }
    const downloadedEntry = new BergamotModelRegistryEntry(entry.from, entry.to, downloadedFiles);
    try {
      writeText(joinPath(dir, 'model.json'), JSON.stringify(downloadedEntry.toJson()));
    } catch (e) {
      console.warn(`BergamotModels: write model.json failed: ${(e as Error)?.message}`);
    }
    return downloadedEntry;
  }

  private async downloadFile(modelFile: BergamotModelFile, destination: string, sourceLanguage: string,
    targetLanguage: string, downloadState: ModelDownloadState, isRuntimeDownload: boolean): Promise<boolean> {
    const tempFile = `${destination}.download`;
    let succeeded = false;
    try {
      this.progress.set(downloadState.toProgress(sourceLanguage, targetLanguage, modelFile.name, isRuntimeDownload));
      deleteFile(tempFile);
      mkdirs(parentDir(tempFile));
      const ok = await this.fetcher.download(modelFile.remoteUrl, tempFile, (delta: number) => {
        downloadState.addBytes(delta);
        this.progress.set(downloadState.toProgress(sourceLanguage, targetLanguage, modelFile.name, isRuntimeDownload));
      });
      if (ok && isFile(tempFile) && this.matchesSha256(modelFile, tempFile)) {
        mkdirs(parentDir(destination));
        succeeded = moveReplacing(tempFile, destination);
      }
    } catch (e) {
      succeeded = false;
    }
    if (!succeeded) {
      deleteFile(tempFile);
    }
    return succeeded;
  }
}
