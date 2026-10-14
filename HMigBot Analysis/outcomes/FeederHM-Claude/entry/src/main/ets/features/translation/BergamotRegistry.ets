/*
 * BergamotRegistry — BergamotModelManager 的数据类型、清单解析与路径解析（自 BergamotModels.ets 拆出，≤600 行）。
 * 源：localtranslation/BergamotModelManager.kt :256-393、:562-713。
 */

export enum BergamotLanguagePairStatus {
  RegistryMissing = 'RegistryMissing',
  Unavailable = 'Unavailable',
  AvailableToDownload = 'AvailableToDownload',
  Downloaded = 'Downloaded'
}

export enum BergamotPreparationError {
  RegistryMissing = 'RegistryMissing',
  NoAppModel = 'NoAppModel',
  DownloadFailed = 'DownloadFailed'
}

const MOZILLA_FIELD_REQUIRED: string = 'Bergamot registry record is missing a required field';
const PIVOT_LANGUAGE: string = 'en';
const DEFAULT_MODEL_BASE_URL: string = 'https://bergamot.s3.amazonaws.com/models';
const ANDROID_FILTER_EXPRESSION: string = 'env.appinfo.OS == \'Android\'';
const STABLE_VERSION_REGEX: RegExp = new RegExp('^[0-9]+(\\.[0-9]+)*$');
const REQUIRED_MODEL_FILE_TYPES: string[] = ['model', 'lex', 'vocab', 'srcvocab', 'trgvocab'];

class RegistryParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RegistryParseError';
  }
}

/** 源 @Serializable BergamotModelFile */
export class BergamotModelFile {
  name: string;
  remoteUrl: string;
  size: number;
  expectedSha256Hash: string;
  url: string | null = null;
  config: Object | null = null;

  constructor(name: string, remoteUrl: string, size: number, expectedSha256Hash: string = '') {
    this.name = name;
    this.remoteUrl = remoteUrl;
    this.size = size;
    this.expectedSha256Hash = expectedSha256Hash;
  }

  withUrl(url: string): BergamotModelFile {
    const f = new BergamotModelFile(this.name, this.remoteUrl, this.size, this.expectedSha256Hash);
    f.url = url;
    f.config = this.config;
    return f;
  }

  /** kotlinx 序列化（explicitNulls=false、encodeDefaults=false） */
  toJson(): Record<string, Object> {
    const o: Record<string, Object> = {};
    o['name'] = this.name;
    o['remoteUrl'] = this.remoteUrl;
    o['size'] = this.size;
    if (this.expectedSha256Hash.length > 0) {
      o['expectedSha256Hash'] = this.expectedSha256Hash;
    }
    if (this.url !== null) {
      o['url'] = this.url;
    }
    if (this.config !== null) {
      o['config'] = this.config;
    }
    return o;
  }
}

/** 源 @Serializable BergamotModelRegistryEntry */
export class BergamotModelRegistryEntry {
  from: string;
  to: string;
  files: Map<string, BergamotModelFile>;

  constructor(from: string, to: string, files: Map<string, BergamotModelFile>) {
    this.from = from;
    this.to = to;
    this.files = files;
  }

  toJson(): Record<string, Object> {
    const files: Record<string, Object> = {};
    this.files.forEach((f: BergamotModelFile, part: string) => {
      files[part] = f.toJson();
    });
    const o: Record<string, Object> = {};
    o['from'] = this.from;
    o['to'] = this.to;
    o['files'] = files;
    return o;
  }
}

export function registryToJson(entries: BergamotModelRegistryEntry[]): string {
  return JSON.stringify(entries.map((e: BergamotModelRegistryEntry) => e.toJson()));
}

/** 源 sealed BergamotModelPreparation（Ready / Error） */
export class BergamotModelPreparation {
  readonly isReady: boolean;
  readonly modelRegistry: BergamotModelRegistryEntry[];
  readonly reason: BergamotPreparationError | null;
  readonly sourceLanguage: string;
  readonly targetLanguage: string;

  private constructor(isReady: boolean, modelRegistry: BergamotModelRegistryEntry[],
    reason: BergamotPreparationError | null, sourceLanguage: string, targetLanguage: string) {
    this.isReady = isReady;
    this.modelRegistry = modelRegistry;
    this.reason = reason;
    this.sourceLanguage = sourceLanguage;
    this.targetLanguage = targetLanguage;
  }

  static ready(modelRegistry: BergamotModelRegistryEntry[]): BergamotModelPreparation {
    return new BergamotModelPreparation(true, modelRegistry, null, '', '');
  }

  static error(reason: BergamotPreparationError, sourceLanguage: string,
    targetLanguage: string): BergamotModelPreparation {
    return new BergamotModelPreparation(false, [], reason, sourceLanguage, targetLanguage);
  }
}

/** 源 LanguagePairInfo */
export class LanguagePairInfo {
  sourceLanguage: string;
  targetLanguage: string;
  sizeBytes: number;

  constructor(sourceLanguage: string, targetLanguage: string, sizeBytes: number) {
    this.sourceLanguage = sourceLanguage;
    this.targetLanguage = targetLanguage;
    this.sizeBytes = sizeBytes;
  }
}

/** 源 BergamotModelDownloadProgress */
export class BergamotModelDownloadProgress {
  readonly sourceLanguage: string;
  readonly targetLanguage: string;
  readonly fileName: string;
  readonly downloadedBytes: number;
  readonly totalBytes: number;
  readonly isRuntimeDownload: boolean;

  constructor(sourceLanguage: string, targetLanguage: string, fileName: string, downloadedBytes: number,
    totalBytes: number, isRuntimeDownload: boolean = false) {
    this.sourceLanguage = sourceLanguage;
    this.targetLanguage = targetLanguage;
    this.fileName = fileName;
    this.downloadedBytes = downloadedBytes;
    this.totalBytes = totalBytes;
    this.isRuntimeDownload = isRuntimeDownload;
  }

  get isIndeterminate(): boolean {
    return this.totalBytes <= 0;
  }

  get fraction(): number {
    return this.totalBytes <= 0 ? 0 : Math.min(1, Math.max(0, this.downloadedBytes / this.totalBytes));
  }
}

/** 源 private data class ModelDownloadState */
export class ModelDownloadState {
  totalBytes: number;
  downloadedBytes: number = 0;

  constructor(totalBytes: number) {
    this.totalBytes = totalBytes;
  }

  addAlreadyDownloaded(file: BergamotModelFile): void {
    this.downloadedBytes += Math.max(0, file.size);
  }

  addBytes(bytes: number): void {
    this.downloadedBytes += Math.max(0, bytes);
  }

  toProgress(sourceLanguage: string, targetLanguage: string, fileName: string,
    isRuntimeDownload: boolean): BergamotModelDownloadProgress {
    return new BergamotModelDownloadProgress(sourceLanguage, targetLanguage, fileName, this.downloadedBytes,
      this.totalBytes, isRuntimeDownload);
  }

  static forPath(path: BergamotModelRegistryEntry[]): ModelDownloadState {
    let total = 0;
    for (let i = 0; i < path.length; i++) {
      path[i].files.forEach((f: BergamotModelFile) => {
        total += Math.max(0, f.size);
      });
    }
    return new ModelDownloadState(total);
  }
}

export type ProgressListener = (progress: BergamotModelDownloadProgress | null) => void;

/** 源 MutableStateFlow<BergamotModelDownloadProgress?>：可观察 + 订阅（返回反订阅函数） */
@ObservedV2
export class BergamotProgressBus {
  @Trace value: BergamotModelDownloadProgress | null = null;
  private listeners: ProgressListener[] = [];

  set(progress: BergamotModelDownloadProgress | null): void {
    this.value = progress;
    const ls = this.listeners.slice();
    for (let i = 0; i < ls.length; i++) {
      try {
        ls[i](progress);
      } catch (e) {
        console.warn(`BergamotProgressBus: listener failed: ${(e as Error)?.message}`);
      }
    }
  }

  subscribe(cb: ProgressListener): () => void {
    this.listeners.push(cb);
    return () => {
      const i = this.listeners.indexOf(cb);
      if (i >= 0) {
        this.listeners.splice(i, 1);
      }
    };
  }
}

/** 源 kotlinx.coroutines.sync.Mutex.withLock（FIFO 串行） */
export class AsyncMutex {
  private tail: Promise<void> = Promise.resolve();

  withLock<T>(block: () => Promise<T>): Promise<T> {
    const run: Promise<T> = this.tail.then((): Promise<T> => block());
    this.tail = run.then((): void => {
    }, (): void => {
    });
    return run;
  }
}

// ------------------------------------------------------------------ 清单解析

function reqString(o: Record<string, Object>, key: string): string {
  const v = o[key];
  if (typeof v !== 'string') {
    throw new RegistryParseError(`${MOZILLA_FIELD_REQUIRED}: ${key}`);
  }
  return v as string;
}

function reqNumber(o: Record<string, Object>, key: string): number {
  const v = o[key];
  if (typeof v !== 'number') {
    throw new RegistryParseError(`${MOZILLA_FIELD_REQUIRED}: ${key}`);
  }
  return v as number;
}

function asObject(v: Object | undefined | null): Record<string, Object> {
  if (v === undefined || v === null || typeof v !== 'object' || Array.isArray(v)) {
    throw new RegistryParseError('Expected JSON object');
  }
  return v as Record<string, Object>;
}

class MozillaRecord {
  name: string = '';
  version: string = '';
  fileType: string = '';
  hash: string = '';
  size: number = 0;
  location: string = '';
  fromLang: string = '';
  toLang: string = '';
  filterExpression: string = '';
}

function parseMozillaRecord(v: Object): MozillaRecord {
  const o = asObject(v);
  const r = new MozillaRecord();
  r.name = reqString(o, 'name');
  r.version = reqString(o, 'version');
  r.fileType = reqString(o, 'fileType');
  const att = asObject(o['attachment']);
  r.hash = reqString(att, 'hash');
  r.size = reqNumber(att, 'size');
  r.location = reqString(att, 'location');
  r.fromLang = reqString(o, 'fromLang');
  r.toLang = reqString(o, 'toLang');
  const fe = o['filter_expression'];
  if (fe !== undefined && fe !== null) {
    if (typeof fe !== 'string') {
      throw new RegistryParseError('filter_expression');
    }
    r.filterExpression = fe as string;
  }
  return r;
}

function isCompatibleWithAndroidRelease(r: MozillaRecord): boolean {
  const fe = r.filterExpression.trim();
  return fe === '' || fe === ANDROID_FILTER_EXPRESSION;
}

function versionParts(version: string): number[] {
  return version.split('.').map((part: string) => {
    let digits = '';
    for (let i = 0; i < part.length; i++) {
      const c = part.charAt(i);
      if (c >= '0' && c <= '9') {
        digits += c;
      } else {
        break;
      }
    }
    const n = digits.length > 0 ? parseInt(digits, 10) : 0;
    return Number.isFinite(n) && n <= 2147483647 ? n : 0;
  });
}

function compareVersionParts(left: number[], right: number[]): number {
  const maxLength = Math.max(left.length, right.length);
  for (let i = 0; i < maxLength; i++) {
    const l = i < left.length ? left[i] : 0;
    const r = i < right.length ? right[i] : 0;
    if (l !== r) {
      return l < r ? -1 : 1;
    }
  }
  return 0;
}

function isCompleteModel(files: Map<string, BergamotModelFile>): boolean {
  return files.has('model') && files.has('lex') && (files.has('vocab') || (files.has('srcvocab') && files.has('trgvocab')));
}

class ModelSetCandidate {
  from: string = '';
  to: string = '';
  version: string = '';
  entry: BergamotModelRegistryEntry | null = null;
}

function parseMozillaRegistry(root: Record<string, Object>, attachmentBaseUrl: string): BergamotModelRegistryEntry[] {
  const data = root['data'];
  if (!Array.isArray(data)) {
    throw new RegistryParseError('data');
  }
  const records = (data as Array<Object>).map((v: Object) => parseMozillaRecord(v));
  // groupBy (from, to, version)：保持首次出现顺序
  const setOrder: string[] = [];
  const sets = new Map<string, MozillaRecord[]>();
  for (let i = 0; i < records.length; i++) {
    const r = records[i];
    if (!isCompatibleWithAndroidRelease(r)) {
      continue;
    }
    const key = `${r.fromLang.toLowerCase()}\u0000${r.toLang.toLowerCase()}\u0000${r.version}`;
    const list = sets.get(key);
    if (list === undefined) {
      sets.set(key, [r]);
      setOrder.push(key);
    } else {
      list.push(r);
    }
  }
  const pairOrder: string[] = [];
  const pairs = new Map<string, ModelSetCandidate[]>();
  for (let i = 0; i < setOrder.length; i++) {
    const list = sets.get(setOrder[i]) as MozillaRecord[];
    const files = new Map<string, BergamotModelFile>();
    for (let j = 0; j < list.length; j++) {
      const r = list[j];
      if (REQUIRED_MODEL_FILE_TYPES.indexOf(r.fileType) < 0) {
        continue;
      }
      files.set(r.fileType, new BergamotModelFile(r.name, attachmentBaseUrl + r.location, r.size, r.hash));
    }
    if (!isCompleteModel(files)) {
      continue;
    }
    const c = new ModelSetCandidate();
    c.from = list[0].fromLang.toLowerCase();
    c.to = list[0].toLang.toLowerCase();
    c.version = list[0].version;
    c.entry = new BergamotModelRegistryEntry(c.from, c.to, files);
    const pairKey = `${c.from}\u0000${c.to}`;
    const pl = pairs.get(pairKey);
    if (pl === undefined) {
      pairs.set(pairKey, [c]);
      pairOrder.push(pairKey);
    } else {
      pl.push(c);
    }
  }
  const out: BergamotModelRegistryEntry[] = [];
  for (let i = 0; i < pairOrder.length; i++) {
    out.push(selectBestModelSet(pairs.get(pairOrder[i]) as ModelSetCandidate[]));
  }
  return out;
}

/** 稳定版优先，再取版本号最大；并列取先出现者（Kotlin maxWithOrNull） */
function selectBestModelSet(candidates: ModelSetCandidate[]): BergamotModelRegistryEntry {
  let best = candidates[0];
  for (let i = 1; i < candidates.length; i++) {
    const c = candidates[i];
    const bestStable = STABLE_VERSION_REGEX.test(best.version) ? 1 : 0;
    const cStable = STABLE_VERSION_REGEX.test(c.version) ? 1 : 0;
    let cmp = bestStable - cStable;
    if (cmp === 0) {
      cmp = compareVersionParts(versionParts(best.version), versionParts(c.version));
    }
    if (cmp < 0) {
      best = c;
    }
  }
  return best.entry as BergamotModelRegistryEntry;
}

function parseLegacyRegistry(root: Record<string, Object>): BergamotModelRegistryEntry[] {
  const out: BergamotModelRegistryEntry[] = [];
  const keys = Object.keys(root);
  for (let i = 0; i < keys.length; i++) {
    const normalizedKey = keys[i].toLowerCase();
    if (normalizedKey.length < 4) {
      continue;
    }
    const from = normalizedKey.substring(0, 2);
    const to = normalizedKey.substring(2, 4);
    const filesObj = asObject(root[keys[i]]);
    const files = new Map<string, BergamotModelFile>();
    const parts = Object.keys(filesObj);
    for (let j = 0; j < parts.length; j++) {
      const value = filesObj[parts[j]];
      if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        continue;
      }
      const fo = value as Record<string, Object>;
      const nameV = fo['name'];
      if (nameV === undefined || nameV === null || typeof nameV === 'object') {
        continue;
      }
      const name = `${nameV}`;
      const lower = name.toLowerCase();
      const remoteUrl = (lower.startsWith('http://') || lower.startsWith('https://')) ? name :
        `${DEFAULT_MODEL_BASE_URL}/${from}${to}/${name}`;
      const sizeV = fo['size'];
      let size = 0;
      if (sizeV !== undefined && sizeV !== null && typeof sizeV !== 'object') {
        const n = Number(`${sizeV}`);
        size = Number.isInteger(n) ? n : 0;
      }
      const hashV = fo['expectedSha256Hash'];
      const hash = (hashV !== undefined && hashV !== null && typeof hashV !== 'object') ? `${hashV}` : '';
      const f = new BergamotModelFile(name.substring(name.lastIndexOf('/') + 1), remoteUrl, size, hash);
      const cfg = fo['config'];
      f.config = cfg !== undefined ? cfg : null;
      files.set(parts[j], f);
    }
    out.push(new BergamotModelRegistryEntry(from, to, files));
  }
  return out;
}

/** 源 parseRegistry：任一解析错误 → null */
export function parseRegistry(content: string, attachmentBaseUrl: string): BergamotModelRegistryEntry[] | null {
  try {
    const root = asObject(JSON.parse(content) as Object);
    if (Object.keys(root).indexOf('data') >= 0) {
      return parseMozillaRegistry(root, attachmentBaseUrl);
    }
    return parseLegacyRegistry(root);
  } catch (e) {
    return null;
  }
}

/** TR-A24：直连优先；一端为 en 且无直连 → null；否则 src→en + en→dst */
export function resolvePath(registry: BergamotModelRegistryEntry[], sourceLanguage: string,
  targetLanguage: string): BergamotModelRegistryEntry[] | null {
  const direct = registry.find((e: BergamotModelRegistryEntry) => e.from === sourceLanguage && e.to === targetLanguage);
  if (direct !== undefined) {
    return [direct];
  }
  if (sourceLanguage === PIVOT_LANGUAGE || targetLanguage === PIVOT_LANGUAGE) {
    return null;
  }
  const outbound = registry.find((e: BergamotModelRegistryEntry) => e.from === sourceLanguage && e.to === PIVOT_LANGUAGE);
  const inbound = registry.find((e: BergamotModelRegistryEntry) => e.from === PIVOT_LANGUAGE && e.to === targetLanguage);
  if (outbound !== undefined && inbound !== undefined) {
    return [outbound, inbound];
  }
  return null;
}
