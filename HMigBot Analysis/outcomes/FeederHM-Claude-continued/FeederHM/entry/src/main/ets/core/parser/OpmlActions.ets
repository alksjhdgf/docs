/**
 * OpmlActions.ets —— 导入/导出动作与落库（依赖系统 Kit / 数据库，本地单测不加载本文件）：
 *  - 源 model/opml/OPMLImporter.kt：OPMLImporter（feed 按 url upsert 保留 id、设置经 UserSettings.setSetting、屏蔽词合并）
 *  - 源 model/opml/OpmlActions.kt：exportOpml / importOpml（Toast + 导入后触发一次用户同步）
 *  - 源 model/export/SavedArticlesExporter.kt / SavedArticlesImporter.kt：exportSavedArticles / importSavedArticles
 *  - SAF ContentResolver 的等价物：DocumentViewPicker 返回的 uri（或沙箱路径）经 CoreFileKit fileIo 读写
 *  - 反向依赖钩子（conventions §C）：Toast（源 ToastMaker；未注册回退 promptAction.showToast）、
 *    导入后同步（源 runOnceRssSync(triggeredByUser = true)；由同步引擎注册）
 * 源动作在 ApplicationCoroutineScope 执行（离开页面不取消）：调用方不要把返回的 Promise 绑在页面生命周期上。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { decodeUtf8, encodeUtf8 } from '../util/TextCodec';
import { promptAction } from '@kit.ArkUI';
import { Feed } from '../model/Feed';
import { FeedItem, FeedItemWithFeed } from '../model/FeedItem';
import { FeedDao } from '../db/FeedDao';
import { FeedItemDao } from '../db/FeedItemDao';
import { BlocklistDao } from '../db/BlocklistDao';
import { getAllSettings, setSetting } from '../settings/UserSettings';
import { Either } from '../util/Either';
import { writeOpmlString } from './OpmlWriter';
import {
  OPMLParserHandler,
  OpmlError,
  OpmlPullParser,
  OpmlUnknownError,
  mergeBlocklistPatterns
} from './OpmlParser';
import {
  SavedArticlesStore,
  buildSavedArticlesExport,
  encodeSavedArticlesExport,
  importSavedArticlesContent
} from './SavedArticlesExport';

const WRITER_LOG_TAG: string = 'FEEDER_OPMLWRITER';
const IMPORTER_LOG_TAG: string = 'FEEDER_OMPLIMPORT';
const ACTIONS_LOG_TAG: string = 'FEEDER_OPMLACTIONS';
const SAVED_EXPORT_LOG_TAG: string = 'FEEDER_SAVEDARTEXPORT';
const SAVED_IMPORT_LOG_TAG: string = 'FEEDER_SAVEDARTIMPORT';

// =====================================================================
// 反向依赖钩子
// =====================================================================

/** 源 ToastMaker.makeToast(resId | text) */
export type ImportExportToastHook = (message: Resource | string) => Promise<void>;
/** 源 runOnceRssSync(di, triggeredByUser = true) */
export type OpmlImportSyncHook = () => Promise<void>;

let toastHook: ImportExportToastHook | null = null;
let importSyncHook: OpmlImportSyncHook | null = null;

export function setImportExportToastHook(cb: ImportExportToastHook | null): void {
  toastHook = cb;
}

export function setOpmlImportSyncHook(cb: OpmlImportSyncHook | null): void {
  importSyncHook = cb;
}

async function makeToast(message: Resource | string): Promise<void> {
  try {
    const cb: ImportExportToastHook | null = toastHook;
    if (cb !== null) {
      await cb(message);
      return;
    }
    promptAction.showToast({ message: message });
  } catch (e) {
    console.error(ACTIONS_LOG_TAG, `toast failed: ${(e as Error)?.message}`);
  }
}

/** 源 `(it.localizedMessage ?: it.message)?.let { toastMaker.makeToast(it) }` */
async function toastErrorMessage(e: Error | null): Promise<void> {
  if (e === null || e === undefined) {
    return;
  }
  const msg: string | undefined = e.message;
  if (msg !== undefined && msg !== null && msg.length > 0) {
    await makeToast(msg);
  }
}

async function runImportSync(): Promise<void> {
  const cb: OpmlImportSyncHook | null = importSyncHook;
  if (cb === null) {
    console.info('TODO:runOnceRssSync(triggeredByUser=true):importOpml — sync hook not registered');
    return;
  }
  await cb();
}

// =====================================================================
// 文件读写
// =====================================================================

/** 读取全部字节；文件不存在/无权限时抛错 */
export async function readAllBytes(uriOrPath: string): Promise<Uint8Array> {
  const file: fs.File = await fs.open(uriOrPath, fs.OpenMode.READ_ONLY);
  try {
    const chunks: Uint8Array[] = [];
    let total: number = 0;
    while (true) {
      const buf: ArrayBuffer = new ArrayBuffer(65536);
      const n: number = await fs.read(file.fd, buf, { offset: total, length: 65536 });
      if (n <= 0) {
        break;
      }
      chunks.push(new Uint8Array(buf, 0, n));
      total += n;
    }
    const out: Uint8Array = new Uint8Array(total);
    let pos: number = 0;
    for (const c of chunks) {
      out.set(c, pos);
      pos += c.length;
    }
    return out;
  } finally {
    await fs.close(file);
  }
}

/** 截断打开（沙箱路径不存在时创建；picker uri 由系统保存器预先创建）；失败抛错 */
async function openForWrite(uriOrPath: string): Promise<fs.File> {
  const mode: number = uriOrPath.startsWith('file://') ?
    (fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC) :
    (fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  return await fs.open(uriOrPath, mode);
}

async function writeUtf8(file: fs.File, text: string): Promise<void> {
  const bytes: Uint8Array = encodeUtf8(text);
  let written: number = 0;
  while (written < bytes.length) {
    const chunk: Uint8Array = bytes.slice(written);
    const n: number = await fs.write(file.fd, chunk.buffer as ArrayBuffer, { offset: written, length: chunk.length });
    if (n <= 0) {
      throw new Error('Failed to write stream');
    }
    written += n;
  }
}

/** 截断并写入 UTF-8 文本；打开/写入失败均抛错 */
export async function writeAllText(uriOrPath: string, text: string): Promise<void> {
  const file: fs.File = await openForWrite(uriOrPath);
  try {
    await writeUtf8(file, text);
  } finally {
    await fs.close(file);
  }
}

// =====================================================================
// OPMLImporter（源 OPMLImporter.kt）
// =====================================================================

/** 源 SettingsStore.blockListPreference.first()：glob 去掉首尾 `*` */
export async function loadBlockListPatterns(): Promise<string[]> {
  const globs: string[] = await BlocklistDao.getGlobPatterns();
  return globs.map((p: string): string => p.length >= 2 ? p.substring(1, p.length - 1) : '');
}

/** 源 SettingsStore.addBlocklistPattern：空白跳过、lowercase().trim()、唯一冲突忽略（不触发屏蔽重算，同源） */
export async function addBlocklistPattern(value: string): Promise<void> {
  if (value.trim().length === 0) {
    return;
  }
  try {
    await BlocklistDao.insertSafely(value.toLowerCase().trim());
  } catch (e) {
    // Ignore: Query style method can't define ignore on constraint failures
    console.debug(IMPORTER_LOG_TAG, `addBlocklistPattern ignored: ${(e as Error)?.message}`);
  }
}

export class OPMLImporter implements OPMLParserHandler {
  /** FP-A56：已有同 url → 整行覆盖为 OPML 值并保留 id；否则插入；OPML 外订阅不动 */
  async saveFeed(feed: Feed): Promise<void> {
    const existing: Feed | null = await FeedDao.loadFeedWithUrl(feed.url);
    if (existing !== null) {
      const updated: Feed = feed.copy();
      updated.id = existing.id;
      await FeedDao.updateFeed(updated);
    } else {
      await FeedDao.insertFeed(feed);
    }
  }

  /** FP-A57：key 忽略大小写匹配 UserSettings 并按类型转换；未知 key 仅告警 */
  async saveSetting(key: string, value: string): Promise<void> {
    await setSetting(key, value);
  }

  /** FP-A58 */
  async saveBlocklistPatterns(patterns: string[]): Promise<void> {
    const existingPatterns: string[] = await loadBlockListPatterns();
    for (const p of mergeBlocklistPatterns(patterns, existingPatterns)) {
      await addBlocklistPattern(p);
    }
  }
}

// =====================================================================
// exportOpml / importOpml（源 OpmlActions.kt）
// =====================================================================

export class OpmlExportUnknownError {
  readonly throwable: Error;

  constructor(throwable: Error) {
    this.throwable = throwable;
  }
}

/**
 * FP-A46..A52：导出当前订阅/设置/屏蔽词到 uri。打开失败等异常 → Toast `Failed to export OPML` + 异常消息，返回 Left；
 * 写入阶段 IO 错误照源只记日志（源 writeOutputStream catch IOException）。
 */
export async function exportOpml(uri: string): Promise<Either<OpmlExportUnknownError, boolean>> {
  try {
    const start: number = Date.now();
    const file: fs.File = await openForWrite(uri);
    try {
      const content: string = await writeOpmlString(getAllSettings(), await loadBlockListPatterns(),
        await FeedDao.loadTags(), (tag: string): Promise<Feed[]> => FeedDao.getFeedsByTitle(tag));
      try {
        await writeUtf8(file, content);
      } catch (ioe) {
        console.error(WRITER_LOG_TAG, `Failed to write stream: ${(ioe as Error)?.message}`);
      }
    } finally {
      await fs.close(file);
    }
    console.debug(ACTIONS_LOG_TAG, `Exported OPML in ${Date.now() - start} ms`);
    return Either.right<OpmlExportUnknownError, boolean>(true);
  } catch (e) {
    const err: Error = e as Error;
    console.error(ACTIONS_LOG_TAG, `Failed to export OPML: ${err?.message}`);
    await makeToast($r('app.string.failed_to_export_OPML'));
    await toastErrorMessage(err);
    return Either.left<OpmlExportUnknownError, boolean>(new OpmlExportUnknownError(err));
  }
}

/** 源 androidTest parseFile：读文件失败（如不存在）→ Left(OpmlUnknownError)。FP-A59 */
export async function parseOpmlFile(parser: OpmlPullParser, uriOrPath: string): Promise<Either<OpmlError, boolean>> {
  let bytes: Uint8Array;
  try {
    bytes = await readAllBytes(uriOrPath);
  } catch (t) {
    return Either.left<OpmlError, boolean>(new OpmlUnknownError(t as Error));
  }
  return await parser.parseBytesWithFallback(bytes);
}

/**
 * FP-A61/A62：解析 uri → 落库 → 无论成败触发一次用户同步 → 结果 Left 时 Toast `Failed to import OPML`；
 * 外层异常（如打不开文件）Toast 文案 + 异常消息（源此时不触发同步）。
 */
export async function importOpml(uri: string,
  handler: OPMLParserHandler = new OPMLImporter()): Promise<Either<OpmlError, boolean>> {
  try {
    const start: number = Date.now();
    const parser: OpmlPullParser = new OpmlPullParser(handler);
    const bytes: Uint8Array = await readAllBytes(uri);
    const result: Either<OpmlError, boolean> = await parser.parseBytesWithFallback(bytes);
    await runImportSync();
    if (result.isLeft()) {
      await makeToast($r('app.string.failed_to_import_OPML'));
    }
    console.debug(ACTIONS_LOG_TAG, `Imported OPML in ${Date.now() - start} ms`);
    return result;
  } catch (e) {
    const err: Error = e as Error;
    console.error(ACTIONS_LOG_TAG, `Failed to import OPML: ${err?.message}`);
    await makeToast($r('app.string.failed_to_import_OPML'));
    await toastErrorMessage(err);
    return Either.left<OpmlError, boolean>(new OpmlUnknownError(err));
  }
}

// =====================================================================
// 收藏文章导出/导入（源 SavedArticlesExporter.kt / SavedArticlesImporter.kt）
// =====================================================================

export class DbSavedArticlesStore implements SavedArticlesStore {
  getFeedIdForUrl(url: string): Promise<number | null> {
    return FeedDao.getFeedIdForUrl(url);
  }

  insertFeed(feed: Feed): Promise<number> {
    return FeedDao.insertFeed(feed);
  }

  loadFeedItem(guid: string, feedId: number): Promise<FeedItem | null> {
    return FeedItemDao.loadFeedItem(guid, feedId);
  }

  loadFeedItemByLink(link: string): Promise<FeedItem | null> {
    return FeedItemDao.loadFeedItemByLink(link);
  }

  setBookmarked(id: number, bookmarked: boolean): Promise<void> {
    return FeedItemDao.setBookmarked(id, bookmarked);
  }

  insertFeedItem(item: FeedItem): Promise<number> {
    return FeedItemDao.insertFeedItem(item);
  }

  setBookmarkedByLinks(links: string[]): Promise<number> {
    return FeedItemDao.setBookmarkedByLinks(links);
  }
}

export class SavedArticlesError {
  readonly throwable: Error;

  constructor(throwable: Error) {
    this.throwable = throwable;
  }
}

/** FP-A63/A66/A67 */
export async function exportSavedArticles(uri: string): Promise<Either<SavedArticlesError, boolean>> {
  try {
    const start: number = Date.now();
    const items: FeedItemWithFeed[] = await FeedItemDao.getBookmarkedItemsForExport();
    await writeAllText(uri, encodeSavedArticlesExport(buildSavedArticlesExport(items)));
    console.debug(SAVED_EXPORT_LOG_TAG, `Exported saved articles in ${Date.now() - start} ms`);
    return Either.right<SavedArticlesError, boolean>(true);
  } catch (e) {
    const err: Error = e as Error;
    console.error(SAVED_EXPORT_LOG_TAG, `Failed to export saved articles: ${err?.message}`);
    await makeToast($r('app.string.failed_to_export_saved_articles'));
    await toastErrorMessage(err);
    return Either.left<SavedArticlesError, boolean>(new SavedArticlesError(err));
  }
}

/** FP-A64/A65/A66/A67 */
export async function importSavedArticles(uri: string,
  store: SavedArticlesStore = new DbSavedArticlesStore()): Promise<Either<SavedArticlesError, boolean>> {
  try {
    const start: number = Date.now();
    const bytes: Uint8Array = await readAllBytes(uri);
    // 源 bufferedReader().readText()（UTF-8，不剥 BOM）
    const content: string = decodeUtf8(bytes);
    await importSavedArticlesContent(store, content);
    console.debug(SAVED_IMPORT_LOG_TAG, `Imported saved articles in ${Date.now() - start} ms`);
    return Either.right<SavedArticlesError, boolean>(true);
  } catch (e) {
    const err: Error = e as Error;
    console.error(SAVED_IMPORT_LOG_TAG, `Failed to import saved articles: ${err?.message}`);
    await makeToast($r('app.string.failed_to_import_saved_articles'));
    await toastErrorMessage(err);
    return Either.left<SavedArticlesError, boolean>(new SavedArticlesError(err));
  }
}
