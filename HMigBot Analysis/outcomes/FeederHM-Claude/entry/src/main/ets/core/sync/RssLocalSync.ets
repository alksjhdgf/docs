/**
 * RssLocalSync.ets —— 源 model/RssLocalSync.kt（订阅源刷新主流程）。
 *
 * - 全局互斥 syncMutex：同一时刻只运行一次同步；syncWorkerRunning 在 try/finally 中置 true/false（FS-A01）。
 *   源"单线程派发器"在 ArkTS 中天然成立（主线程事件循环），2 路"并发"只交错 IO 等待（FS-A06）。
 * - 陈旧阈值、选源、同步链预处理、applyRemoteReadMarks、全文预取调度（FS-A02..A08）。
 * - 每源：开始写 currently_syncing=true 与 last_sync，结束复位；HttpError 带 Retry-After 时同主机全部源延后；
 *   成功后对本源新条目应用全局屏蔽词（FS-A09/A30）。
 * - 条目：guid（alternateId 规则，Java String.hashCode）、增量 upsert、跨源去重、字段映射、回退时钟、
 *   远端已读、过滤规则、正文 blob（files/articles/<id>.txt.gz）、源元数据回写、站点图标、保留裁剪（FS-A23..A35/A40）。
 * 增量（ETag/Last-Modified 条件请求）由 core/net HttpClient 的缓存层完成（forceNetwork → max-age=60）。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { Either, Left, Right } from '../util/Either';
import { JavaUrl } from '../util/JavaUrl';
import { javaStringHashCode } from '../util/JavaHash';
import { FilePathProvider, blobFilePath, blobFullFilePath } from '../util/Constants';
import { sloppyLinkToStrictURLNoThrows, urlHasNoAuthParams, urlHasNoQueryParams } from '../util/LinkUtils';
import { ID_UNSET } from '../model/Enums';
import { EPOCH_MS, Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { ParsedArticle, ParsedFeed, SiteMetaData } from '../model/Parsed';
import { HttpClient } from '../net/HttpClient';
import { AsyncMutex } from '../net/Interceptors';
import { toError } from '../net/NetworkResult';
import { FeedDao } from '../db/FeedDao';
import { FeedItemDao, FeedItemWithText } from '../db/FeedItemDao';
import { BlocklistDao } from '../db/BlocklistDao';
import { ReadStatusSynced, ReadStatusSyncedDao, RemoteReadMarkDao, RemoteReadMarkReadyToBeApplied, SYNC_REMOTE_ID
} from '../db/SyncDaos';
import { SettingsStore } from '../settings/SettingsStore';
import { htmlToPlainText } from '../html/HtmlToPlainText';
import { FullTextParser, writeGzipTextFile } from '../html/FullTextParser';
import { FeedParserError, FetchError, HttpError } from '../parser/FeedParserError';
import { ArticleFilterPolicy, ArticleFilterRules } from './ArticleFilterRules';
import { fetchFeed, getSiteMetaData } from './FeedFetcher';
import { OgImageFetcher, defaultOgImageFetcher, resolveThumbnailImage } from './Thumbnails';
import { SyncStatus } from './SyncStatus';

export { SyncStatus };

const LOG_TAG: string = 'FEEDER_RSS_LOCAL_SYNC';
const MINUTE_MS: number = 60 * 1000;
const DAY_MS: number = 24 * 60 * MINUTE_MS;

// ============================================================ 反向依赖注入点

/**
 * Feeder Sync 客户端（源 SyncRestClient；实现属 page-sync 切片的 features/sync/SyncRestClient，经 setSyncChainClient 注册）。
 * 方法内部自行处理"未配置同步链"；抛出的异常由调用方吞掉只记日志。
 */
export interface SyncChainClient {
  isConfigured(): boolean;

  getFeeds(): Promise<void>;

  getRead(): Promise<void>;

  getDevices(): Promise<void>;

  sendUpdatedFeeds(): Promise<void>;

  markAsRead(): Promise<void>;
}

let syncChainClient: SyncChainClient | null = null;

/** 注册（或 null 注销）同步链客户端；未注册时同步链步骤为 no-op（等价于未配置同步链） */
export function setSyncChainClient(client: SyncChainClient | null): void {
  syncChainClient = client;
}

export function getSyncChainClient(): SyncChainClient | null {
  return syncChainClient;
}

/** 源 Repository.isSyncChainConfigured */
export function isSyncChainConfigured(): boolean {
  const c: SyncChainClient | null = syncChainClient;
  return c !== null && c.isConfigured();
}

/** 源 runOnceFullTextSync(di, triggeredByUser) 的注入点（SyncScheduler.init 注册） */
export type FullTextSyncRequester = (triggeredByUser: boolean) => void;

let fullTextSyncRequester: FullTextSyncRequester | null = null;

export function setFullTextSyncRequester(cb: FullTextSyncRequester | null): void {
  fullTextSyncRequester = cb;
}

// ============================================================ 共享工具

/** 源 syncMutex（全局） */
export const syncMutex: AsyncMutex = new AsyncMutex();

/**
 * 源 ParsedArticle.alternateId：`"$id|${content_text.hashCode()}|${title.hashCode()}"`
 * （id 为 null 时字面 "null"；null.hashCode() = 0）。
 */
export function alternateIdOf(article: ParsedArticle): string {
  return `${article.id !== null ? article.id : 'null'}|${javaStringHashCode(article.content_text)}|` +
    `${javaStringHashCode(article.title)}`;
}

/** 源 SyncRemoteStore.setSynced：插入 read_status_synced（重复忽略） */
export async function setSynced(feedItemId: number): Promise<void> {
  const r: ReadStatusSynced = new ReadStatusSynced();
  r.feed_item = feedItemId;
  r.sync_remote = SYNC_REMOTE_ID;
  await ReadStatusSyncedDao.insert(r);
}

/**
 * 源 Repository.applyRemoteReadMarks（FS-A07）：就绪的远端已读标记 → 本地已读并标已同步，删除已应用标记，
 * 再清理指向已读条目的标记（防止覆盖用户有意的"标为未读"）。
 */
export async function applyRemoteReadMarks(): Promise<void> {
  const toBeApplied: RemoteReadMarkReadyToBeApplied[] = await RemoteReadMarkDao.getRemoteReadMarksReadyToBeApplied();
  const itemIds: number[] = toBeApplied.map((m: RemoteReadMarkReadyToBeApplied): number => m.feedItemId);
  if (itemIds.length > 0) {
    await FeedItemDao.markAsRead(itemIds);
  }
  for (const itemId of itemIds) {
    await setSynced(itemId);
  }
  const markIds: number[] = toBeApplied.map((m: RemoteReadMarkReadyToBeApplied): number => m.id);
  if (markIds.length > 0) {
    await RemoteReadMarkDao.deleteByIds(markIds);
  }
  await RemoteReadMarkDao.deleteRemoteReadMarksForReadItems();
}

/** 源 SyncRemoteStore.deleteStaleRemoteReadMarks(now)：删除 7 天前的远端已读标记 */
export async function deleteStaleRemoteReadMarks(nowMs: number = Date.now()): Promise<void> {
  await RemoteReadMarkDao.deleteStaleRemoteReadMarks(nowMs - 7 * DAY_MS);
}

function fileExists(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isFile();
  } catch (e) {
    return false;
  }
}

async function ensureDir(dir: string): Promise<void> {
  try {
    if (!fs.accessSync(dir)) {
      await fs.mkdir(dir, true);
    }
  } catch (e) {
    console.warn(LOG_TAG, `mkdirs failed for ${dir}: ${(e as Error).message}`);
  }
}

async function deleteFileQuietly(path: string): Promise<void> {
  try {
    if (fileExists(path)) {
      await fs.unlink(path);
    }
  } catch (e) {
    console.error(LOG_TAG, `Failed to delete ${path}: ${(e as Error).message}`);
  }
}

/** 删除条目的正文 blob 与全文 blob（FS-A34） */
export async function deleteArticleFiles(ids: number[], paths: FilePathProvider): Promise<void> {
  for (const id of ids) {
    await deleteFileQuietly(blobFilePath(id, paths.articleDir));
    await deleteFileQuietly(blobFullFilePath(id, paths.fullArticleDir));
  }
}

/** 源 URL(protocol, host, port, "")：站点根 */
function siteRootOf(homePageUrl: string | null): JavaUrl | null {
  if (homePageUrl === null) {
    return null;
  }
  try {
    const u: JavaUrl = JavaUrl.parse(homePageUrl);
    return JavaUrl.parse(`${u.protocol}://${u.host}${u.port !== -1 ? ':' + u.port : ''}`);
  } catch (e) {
    console.debug(LOG_TAG, `Bad site url: ${homePageUrl}`);
    return null;
  }
}

class ParsedWithGuid {
  item: ParsedArticle;
  guid: string;

  constructor(item: ParsedArticle, guid: string) {
    this.item = item;
    this.guid = guid;
  }
}

// ============================================================ RssLocalSync

export class RssLocalSync {
  private static inst: RssLocalSync | null = null;

  private paths: FilePathProvider | null = null;
  private client: HttpClient | null = null;
  private ogFetcher: OgImageFetcher | null = null;

  static instance(): RssLocalSync {
    if (RssLocalSync.inst === null) {
      RssLocalSync.inst = new RssLocalSync();
    }
    return RssLocalSync.inst as RssLocalSync;
  }

  /** 由 SyncScheduler.init 调用；client/ogFetcher 缺省用主 HttpClient */
  static configure(paths: FilePathProvider, client: HttpClient | null = null,
    ogFetcher: OgImageFetcher | null = null): void {
    const s: RssLocalSync = RssLocalSync.instance();
    s.paths = paths;
    s.client = client;
    s.ogFetcher = ogFetcher;
  }

  get filePathProvider(): FilePathProvider | null {
    return this.paths;
  }

  private httpClient(): HttpClient {
    return this.client !== null ? this.client : HttpClient.main();
  }

  /**
   * 源 syncFeeds（公开版）：取 syncMutex，maxFeedItemCount 取设置 maximumCountPerFeed（FS-A01/A02）。
   * @returns outer 流程走完为 true（调用方通常忽略）
   */
  async syncFeeds(feedId: number = ID_UNSET, feedTag: string = '', forceNetwork: boolean = false,
    minFeedAgeMinutes: number = 5): Promise<boolean> {
    console.debug(LOG_TAG, 'Taking sync mutex');
    return syncMutex.withLock<boolean>(async (): Promise<boolean> => {
      try {
        SyncStatus.setSyncWorkerRunning(true);
        return await this.syncFeedsInternal(feedId, feedTag, SettingsStore.instance().maximumCountPerFeed,
          forceNetwork, minFeedAgeMinutes, false);
      } finally {
        SyncStatus.setSyncWorkerRunning(false);
      }
    });
  }

  /** 源 internal syncFeeds（测试可直接调用；不取互斥锁） */
  async syncFeedsInternal(feedId: number, feedTag: string, maxFeedItemCount: number, forceNetwork: boolean,
    minFeedAgeMinutes: number, debugReallyForceNetwork: boolean): Promise<boolean> {
    let result: boolean = false;
    let needFullTextSync: boolean = false;
    // Let all new items share download time
    const downloadTime: number = Date.now();
    const started: number = Date.now();
    try {
      let staleTime: number;
      if (debugReallyForceNetwork) {
        staleTime = Date.now() + DAY_MS;
      } else if (forceNetwork) {
        // Under no circumstances should we spam servers more than once per minute intentionally
        staleTime = Date.now() - MINUTE_MS;
      } else {
        staleTime = Date.now() - Math.max(minFeedAgeMinutes, 1) * MINUTE_MS;
      }
      // Fetch sync stuff first - this is fast
      const sc: SyncChainClient | null = syncChainClient;
      if (sc !== null) {
        try {
          await sc.getFeeds();
          await sc.getRead();
          await sc.getDevices();
          await sc.sendUpdatedFeeds();
          await sc.markAsRead();
        } catch (e) {
          console.error(LOG_TAG, `error with syncClient: ${toError(e as Object).message}`);
        }
      }

      const feedsToFetch: Feed[] = await this.feedsToSync(feedId, feedTag, staleTime);
      console.debug(LOG_TAG, `Syncing ${feedsToFetch.length} feeds`);
      needFullTextSync = feedsToFetch.some((f: Feed): boolean => f.fullTextByDefault);

      // Concurrent but on a single thread: only IO waits interleave
      const concurrentJobs: number = 2;
      const jobs: Promise<void>[] = [];
      for (let jobIndex = 0; jobIndex < concurrentJobs; jobIndex++) {
        jobs.push(this.runShard(feedsToFetch, jobIndex, concurrentJobs, maxFeedItemCount, forceNetwork,
          downloadTime));
      }
      await Promise.all(jobs);

      try {
        await applyRemoteReadMarks();
      } catch (e) {
        console.error(LOG_TAG, `Error on final apply: ${toError(e as Object).message}`);
      }
      result = true;
    } catch (e) {
      console.error(LOG_TAG, `Outer error: ${toError(e as Object).message}`);
    } finally {
      if (needFullTextSync) {
        this.requestFullTextSync();
      }
    }
    console.debug(LOG_TAG, `Completed in ${Date.now() - started} ms`);
    return result;
  }

  private requestFullTextSync(): void {
    const cb: FullTextSyncRequester | null = fullTextSyncRequester;
    if (cb !== null) {
      cb(false);
      return;
    }
    const paths: FilePathProvider | null = this.paths;
    if (paths === null) {
      console.error(LOG_TAG, 'Full text sync requested before configure()');
      return;
    }
    // APP-A70：生产路径（configure 未注入 client）复用进程单例；仅测试注入 client 时另建
    (this.client !== null ? new FullTextParser(paths, this.client) : FullTextParser.instance(paths))
      .parseFullArticlesForMissing().catch((e: Error) => {
      console.error(LOG_TAG, `Full text sync failed: ${e?.message}`);
    });
  }

  private async runShard(feeds: Feed[], jobIndex: number, concurrentJobs: number, maxFeedItemCount: number,
    forceNetwork: boolean, downloadTime: number): Promise<void> {
    for (let index = 0; index < feeds.length; index++) {
      if (index % concurrentJobs === jobIndex) {
        await this.handleFeed(feeds[index], maxFeedItemCount, forceNetwork, downloadTime);
      }
    }
  }

  /** 源 handleFeed（FS-A09）：单源失败不影响其他源，异常不外抛 */
  private async handleFeed(feed: Feed, maxFeedItemCount: number, forceNetwork: boolean,
    downloadTime: number): Promise<void> {
    try {
      // Want unique sync times.
      const syncTime: number = Date.now();
      await FeedDao.setCurrentlySyncingOn(feed.id, true, syncTime);
      const r: Either<FeedParserError, boolean> = await this.syncFeed(feed.id, maxFeedItemCount, forceNetwork,
        downloadTime);
      const err: FeedParserError | null = r.leftOrNull();
      if (err !== null) {
        console.error(LOG_TAG,
          `Failed to sync ${feed.displayTitle}: ${feed.url} because:\n${err.description}`);
        if (err instanceof HttpError) {
          const seconds: number | null = (err as HttpError).retryAfterSeconds;
          if (seconds !== null) {
            // Feeds can share retry after if they are on the same server
            await FeedDao.setRetryAfterForFeedsWithBaseUrl(JavaUrl.parse(feed.url).host, Date.now() + seconds * 1000);
          }
        }
      } else {
        const s: SettingsStore = SettingsStore.instance();
        await BlocklistDao.setItemBlockStatusForNewInFeed(feed.id, syncTime, s.applyBlocklistToSummaries,
          s.applyBlocklistToLinks);
      }
    } catch (e) {
      console.error(LOG_TAG, `Failed to sync ${feed.displayTitle}: ${feed.url}: ${toError(e as Object).message}`);
    } finally {
      try {
        await FeedDao.setCurrentlySyncingOn(feed.id, false);
      } catch (e) {
        console.error(LOG_TAG, `Failed to reset currently_syncing: ${toError(e as Object).message}`);
      }
    }
  }

  /** 源 syncFeed：Right(true) 表示成功或被 retry-after 跳过 */
  private async syncFeed(feedId: number, maxFeedItemCount: number, forceNetwork: boolean,
    downloadTime: number): Promise<Either<FeedParserError, boolean>> {
    // Load it again to ensure we get the latest value for retry-after since this can be shared across feeds
    const feedSql: Feed | null = await FeedDao.syncLoadFeed(feedId, Date.now());
    if (feedSql === null) {
      console.info(LOG_TAG, `Skipping feed ${feedId} due to retry-after changing mid sync`);
      return new Right<FeedParserError, boolean>(true);
    }
    const url: string = feedSql.url;
    // Belts and suspenders
    if (feedSql.retryAfter > Date.now()) {
      console.info(LOG_TAG, `Skipping ${feedSql.displayTitle} due to retry-after. Earliest retry: ${feedSql.retryAfter}`);
      return new Right<FeedParserError, boolean>(true);
    }
    console.debug(LOG_TAG, `Fetching ${feedSql.displayTitle}`);

    const fetched: Either<FeedParserError, ParsedFeed> = await fetchFeed(url, forceNetwork, this.client);
    const feed: ParsedFeed | null = fetched.getOrNull();
    if (feed === null) {
      // Nothing was parsed, nothing to do. lastSync time has already been updated
      return new Left<FeedParserError, boolean>(fetched.leftOrNull() as FeedParserError);
    }
    try {
      await this.processFeed(feedSql, feed, maxFeedItemCount, downloadTime);
      return new Right<FeedParserError, boolean>(true);
    } catch (t) {
      return new Left<FeedParserError, boolean>(new FetchError(url, toError(t as Object)));
    }
  }

  private async processFeed(feedSql: Feed, feed: ParsedFeed, maxFeedItemCount: number,
    downloadTime: number): Promise<void> {
    const paths: FilePathProvider | null = this.paths;
    if (paths === null) {
      throw new Error('RssLocalSync not configured (FilePathProvider missing)');
    }
    const items: ParsedArticle[] | null = feed.items;
    let isNotUniqueIds: boolean = false;
    if (items !== null) {
      // This can only detect between items present in one feed. See NIXOS
      const ids: Set<string | null> = new Set<string | null>();
      items.forEach((it: ParsedArticle) => {
        ids.add(it.id);
      });
      isNotUniqueIds = ids.size !== items.length;
    }
    const alreadyReadGuids: Set<string> =
      new Set<string>(await RemoteReadMarkDao.getGuidsWhichAreSyncedAsReadInFeed(feedSql.url));
    // Compiled once per feed per sync. Never inside the item loop.
    const rules: ArticleFilterRules = ArticleFilterRules.compile(feedSql.blockRules, feedSql.allowRules);

    // Feed convention: items are listed newest-first. Reverse so we process oldest-first.
    const itemsWithGuids: ParsedWithGuid[] = items === null ? [] : items.map((it: ParsedArticle): ParsedWithGuid => {
      const guid: string = (isNotUniqueIds || feedSql.alternateId) ? alternateIdOf(it) :
        (it.id !== null ? it.id : alternateIdOf(it));
      return new ParsedWithGuid(it, guid);
    }).reverse();
    const totalItems: number = itemsWithGuids.length;
    const ogFetcher: OgImageFetcher = this.ogFetcher !== null ? this.ogFetcher : defaultOgImageFetcher(this.client);

    const feedItemSqls: FeedItemWithText[] = [];
    for (let index = 0; index < totalItems; index++) {
      const item: ParsedArticle = itemsWithGuids[index].item;
      const guid: string = itemsWithGuids[index].guid;
      // Per-feed rules: filtered items never become a row, file, or notification. Filtering inside the loop keeps
      // isNotUniqueIds and the fallback clock index unaffected (FS-A40).
      if (!ArticleFilterPolicy.shouldKeep(item, rules)) {
        console.debug(LOG_TAG, `Filtered by feed rules: [${item.title}] [${feed.title}]`);
        continue;
      }
      // Each undated item in the feed gets a distinct fallback clock (earlier in feed = more recent).
      const fallbackClock: number = downloadTime - (totalItems - 1 - index) * 1000;
      const altId: string = alternateIdOf(item);
      let feedItemSql: FeedItem | null = await FeedItemDao.loadFeedItem(altId, feedSql.id);
      if (feedItemSql === null) {
        feedItemSql = await FeedItemDao.loadFeedItem(item.id !== null ? item.id : altId, feedSql.id);
      }
      if (feedItemSql === null) {
        feedItemSql = new FeedItem();
        feedItemSql.firstSyncedTime = downloadTime;
      }
      const fi: FeedItem = feedItemSql;
      // If new item, see if duplicates exist
      if (fi.id !== ID_UNSET || !feedSql.skipDuplicates ||
        !(await FeedItemDao.duplicationExists(fi.id, item.title !== null ? item.title : '', item.url))) {
        fi.updateFromParsedEntry(item, guid, feed, htmlToPlainText, fallbackClock);
        fi.feedId = feedSql.id;
        if (feedSql.fetchOgImages) {
          fi.thumbnailImage = await resolveThumbnailImage(fi.thumbnailImage, item.url, item.hasFeedImage, ogFetcher);
        }
        if (alreadyReadGuids.has(fi.guid)) {
          fi.readTime = fi.readTime !== null ? fi.readTime : Date.now();
          fi.notified = true;
        }
        const text: string = item.content_html !== null ? item.content_html :
          (item.content_text !== null ? item.content_text : '');
        const pair: FeedItemWithText = { item: fi, text: text };
        feedItemSqls.push(pair);
      } else {
        console.info(LOG_TAG, `Duplicate story ignored: [${item.title}] [${feed.title}]`);
      }
    }

    await FeedItemDao.upsertFeedItems(feedItemSqls, async (feedItem: FeedItem, text: string): Promise<void> => {
      await ensureDir(paths.articleDir);
      await writeGzipTextFile(blobFilePath(feedItem.id, paths.articleDir), text);
      // Pre-marked as read from a remote read-mark: set synced so it won't be echoed back to the server.
      if (alreadyReadGuids.has(feedItem.guid)) {
        await setSynced(feedItem.id);
      }
    });

    // Try to look for image if not done before (only once)
    if (feedSql.imageUrl === null && feedSql.siteFetched === EPOCH_MS) {
      const siteUrl: JavaUrl | null = siteRootOf(feed.home_page_url);
      if (siteUrl !== null) {
        feedSql.siteFetched = Date.now();
        const meta: Either<FeedParserError, SiteMetaData> = await getSiteMetaData(siteUrl, this.client);
        const md: SiteMetaData | null = meta.getOrNull();
        if (md !== null && md.feedImage !== null) {
          try {
            feedSql.imageUrl = JavaUrl.parse(md.feedImage).toString();
          } catch (e) {
            console.debug(LOG_TAG, `Bad feedImage url: ${feed.home_page_url}`);
          }
        }
      }
    }

    // Update feed last so lastsync is only set after all items have been handled
    feedSql.title = feed.title !== null ? feed.title : feedSql.title;
    // Do not update feed url if auth or token params
    const currentUrl: JavaUrl = sloppyLinkToStrictURLNoThrows(feedSql.url);
    if (urlHasNoAuthParams(currentUrl) && urlHasNoQueryParams(currentUrl) && feed.feed_url !== null) {
      feedSql.url = sloppyLinkToStrictURLNoThrows(feed.feed_url).toString();
    }
    // Important to keep image if there is one in case of null
    if (feed.icon !== null) {
      feedSql.imageUrl = sloppyLinkToStrictURLNoThrows(feed.icon).toString();
    }
    await FeedDao.upsert(feedSql);

    // Finally, prune database of old items; never items still present in the feed or the currently open article
    const presentIds: Set<number> = new Set<number>();
    feedItemSqls.forEach((p: FeedItemWithText) => {
      presentIds.add(p.item.id);
    });
    const currentArticleId: number = SettingsStore.instance().currentArticleId;
    const keepCount: number = Math.max(maxFeedItemCount, items !== null ? items.length : 0);
    const articlesToDelete: number[] = (await FeedItemDao.getItemsToBeCleanedFromFeed(feedSql.id, keepCount))
      .filter((id: number): boolean => !presentIds.has(id) && id !== currentArticleId);

    await deleteArticleFiles(articlesToDelete, paths);
    if (articlesToDelete.length > 0) {
      await FeedItemDao.deleteFeedItems(articlesToDelete);
    }
    await deleteStaleRemoteReadMarks();
    console.debug(LOG_TAG, `Fetched ${feedSql.displayTitle}`);
  }

  /** 源 feedsToSync（FS-A04）：staleTime ≤ 0 时不带 last_sync 条件（内部使用） */
  async feedsToSync(feedId: number, tag: string, staleTime: number = -1): Promise<Feed[]> {
    const now: number = Date.now();
    if (feedId > 0) {
      const feed: Feed | null = staleTime > 0 ? await FeedDao.syncLoadFeedIfStale(feedId, staleTime, now) :
        await FeedDao.syncLoadFeed(feedId, now);
      return feed !== null ? [feed] : [];
    }
    if (tag.length > 0) {
      return staleTime > 0 ? await FeedDao.syncLoadFeedsInTagIfStale(tag, staleTime, now) :
        await FeedDao.syncLoadFeedsInTag(tag, now);
    }
    return staleTime > 0 ? await FeedDao.syncLoadFeedsIfStale(staleTime, now) : await FeedDao.syncLoadFeeds(now);
  }
}

/** 源 CleanupOrphanedFilesJob（FS-A35）：删除不对应任何现存条目 id 的正文/全文文件 */
export async function cleanupOrphanedFiles(paths: FilePathProvider): Promise<void> {
  try {
    console.info(LOG_TAG, 'Starting cleanup of orphaned article files');
    const ids: number[] = await FeedItemDao.getAllFeedItemIds();
    await cleanupDirectory(paths.articleDir, ids, (id: number, dir: string): string => blobFilePath(id, dir));
    await cleanupDirectory(paths.fullArticleDir, ids, (id: number, dir: string): string => blobFullFilePath(id, dir));
    console.info(LOG_TAG, 'Completed cleanup of orphaned article files');
  } catch (e) {
    console.error(LOG_TAG, `Error during cleanup of orphaned files: ${toError(e as Object).message}`);
  }
}

async function cleanupDirectory(directory: string, validIds: number[],
  fileProvider: (id: number, dir: string) => string): Promise<void> {
  let isDir: boolean = false;
  try {
    isDir = fs.accessSync(directory) && fs.statSync(directory).isDirectory();
  } catch (e) {
    isDir = false;
  }
  if (!isDir) {
    console.debug(LOG_TAG, `Directory doesn't exist: ${directory}`);
    return;
  }
  const valid: Set<string> = new Set<string>();
  validIds.forEach((id: number) => {
    valid.add(fileProvider(id, directory));
  });
  const prefix: string = directory.endsWith('/') ? directory : directory + '/';
  let deletedCount: number = 0;
  const names: string[] = await fs.listFile(directory);
  for (const name of names) {
    const path: string = prefix + name;
    try {
      if (!valid.has(path) && fs.statSync(path).isFile()) {
        await fs.unlink(path);
        deletedCount++;
      }
    } catch (e) {
      console.error(LOG_TAG, `Error processing file ${path}: ${toError(e as Object).message}`);
    }
  }
  console.info(LOG_TAG, `Deleted ${deletedCount} orphaned files from ${directory}`);
}
