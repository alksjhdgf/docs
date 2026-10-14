/**
 * FeedStore（源 archmodel/FeedStore.kt）：订阅源相关仓储，薄封装 FeedDao。
 * Flow → observeXxx(cb)（返回反订阅函数）；Paging3 → PagedList（见 RepoTypes）。
 */
import { Feed, FeedForSettings, FeedTitle, FeedUnreadCount } from '../model/Feed';
import { ID_UNSET } from '../model/Enums';
import { AppDatabase, DbConn, TABLE_FEEDS, TABLE_FEED_ITEMS } from '../db/AppDatabase';
import { DbConstraintError, FeedDao } from '../db/FeedDao';
import { PagedList, PagedListCallback, PagingConfig } from './RepoTypes';

/** 源 getPagedNavDrawerItems 的 PagingConfig(pageSize=10, initialLoadSize=50, prefetchDistance=50) */
export const NAV_DRAWER_PAGING: PagingConfig = new PagingConfig(10, 50, 50);

/** 源 SQLiteConstraintException 判定（FeedDao.upsert 抛 DbConstraintError；底层 RDB 约束失败亦视为同类） */
function isConstraintError(e: Error): boolean {
  if (e instanceof DbConstraintError) {
    return true;
  }
  const msg: string = e?.message ?? '';
  return msg.toLowerCase().indexOf('constraint') >= 0;
}

export class FeedStore {
  private static inst: FeedStore | null = null;

  // Need only be internally consistent within the composition; this object outlives all compositions
  private nextTagUiId: number = -1000;
  // But IDs need to be consistent even if tags come and go
  private readonly tagUiIds: Map<string, number> = new Map<string, number>();

  static instance(): FeedStore {
    if (FeedStore.inst === null) {
      FeedStore.inst = new FeedStore();
    }
    return FeedStore.inst as FeedStore;
  }

  /** 源 getTagUiId：从 -1001 起递减，同进程内同一 tag 稳定 */
  getTagUiId(tag: string): number {
    const existing: number | undefined = this.tagUiIds.get(tag);
    if (existing !== undefined) {
      return existing;
    }
    this.nextTagUiId = this.nextTagUiId - 1;
    this.tagUiIds.set(tag, this.nextTagUiId);
    return this.nextTagUiId;
  }

  async getFeed(feedId: number): Promise<Feed | null> {
    return await FeedDao.getFeed(feedId);
  }

  async getFeedByUrl(url: string): Promise<Feed | null> {
    return await FeedDao.loadFeedWithUrl(url);
  }

  /**
   * RP-A29：id>0 更新并返回原 id，否则插入并返回新 id。
   * 照源 @Insert(onConflict = REPLACE)：url 已存在时 SQLite 先删除冲突旧行（经 FK 级联删其文章及已同步标记）
   * 再插入新行，返回新的 AUTOINCREMENT id。FeedDao.insertFeed 对 url 冲突改为原地更新（不符源语义），
   * 故此处在同一事务内先按 url 删除（DAO 删除路径显式级联），再插入，等价 REPLACE 的删+插。
   */
  async saveFeed(feed: Feed): Promise<number> {
    if (feed.id > ID_UNSET) {
      await FeedDao.updateFeed(feed);
      return feed.id;
    }
    return await AppDatabase.transaction<number>(async (tx: DbConn): Promise<number> => {
      await FeedDao.deleteFeedWithUrl(feed.url, tx);
      return await FeedDao.insertFeed(feed, tx);
    });
  }

  async toggleNotifications(feedId: number, value: boolean): Promise<void> {
    await FeedDao.setNotify(feedId, value);
  }

  async getDisplayTitle(feedId: number): Promise<string | null> {
    const t: FeedTitle | null = await FeedDao.getFeedTitle(feedId);
    return t !== null ? t.displayTitle : null;
  }

  async renameTag(oldTag: string, newTag: string): Promise<void> {
    await FeedDao.renameTag(oldTag, newTag);
  }

  async deleteFeeds(feedIds: number[]): Promise<void> {
    if (feedIds.length === 0) {
      return;
    }
    await FeedDao.deleteFeeds(feedIds);
  }

  /** RP-A31：去重标签，按 NOCASE 排序（含空串标签，照源） */
  async getAllTags(): Promise<string[]> {
    return await FeedDao.loadTags();
  }

  observeAllTags(cb: (tags: string[]) => void): () => void {
    return FeedDao.observeAllTags(cb);
  }

  observeFeedForSettings(cb: (feeds: FeedForSettings[]) => void): () => void {
    return FeedDao.observeFeedsForSettings(cb);
  }

  /** 源 getPagedNavDrawerItems(expandedTags)：未 start；由调用方（PagedListHandle.replace）启动 */
  getPagedNavDrawerItems(expandedTags: Set<string>, cb: PagedListCallback<FeedUnreadCount>): PagedList<FeedUnreadCount> {
    const tags: string[] = Array.from(expandedTags);
    return new PagedList<FeedUnreadCount>(
      (limit: number, offset: number): Promise<FeedUnreadCount[]> => FeedDao.getNavDrawerItems(tags, limit, offset),
      [TABLE_FEEDS, TABLE_FEED_ITEMS], NAV_DRAWER_PAGING, cb);
  }

  /** 源 getFeedTitles：feedId>0 → 该源；tag 非空白 → 该标签；否则全部 */
  observeFeedTitles(feedId: number, tag: string, cb: (titles: FeedTitle[]) => void): () => void {
    return FeedDao.observeFeedTitles(feedId, tag, cb);
  }

  observeCurrentlySyncingLatestTimestamp(cb: (ts: number | null) => void): () => void {
    return FeedDao.observeCurrentlySyncingLatestTimestamp(cb);
  }

  async setCurrentlySyncingOn(feedId: number, syncing: boolean, lastSync: number | null = null): Promise<void> {
    await FeedDao.setCurrentlySyncingOn(feedId, syncing, lastSync);
  }

  /**
   * RP-A30：upsert；id 未设置而 url 已存在（唯一约束冲突）时按 url 取已有 id 再 upsert（更新而非重复插入）。
   * 返回值照源 Room @Upsert：插入返回新 rowid，更新返回 -1。
   */
  async upsertFeed(feedSql: Feed): Promise<number> {
    try {
      return await FeedDao.upsert(feedSql);
    } catch (e) {
      const err: Error = e as Error;
      if (isConstraintError(err) && feedSql.id === ID_UNSET) {
        const feedId: number | null = await FeedDao.getFeedIdForUrl(feedSql.url);
        if (feedId !== null) {
          const copy: Feed = feedSql.copy();
          copy.id = feedId;
          return await FeedDao.upsert(copy);
        }
      }
      throw err;
    }
  }

  async getFeedsOrderedByUrl(): Promise<Feed[]> {
    return await FeedDao.getFeedsOrderedByUrl();
  }

  /** 源 deleteFeed(url)：仅删行（同步链用），不清快捷方式、不改当前选择 */
  async deleteFeedByUrl(url: string): Promise<void> {
    await FeedDao.deleteFeedWithUrl(url);
  }

  async syncLoadFeedIfStale(feedId: number, staleTime: number, retryAfter: number): Promise<Feed | null> {
    return await FeedDao.syncLoadFeedIfStale(feedId, staleTime, retryAfter);
  }

  async syncLoadFeed(feedId: number, retryAfter: number): Promise<Feed | null> {
    return await FeedDao.syncLoadFeed(feedId, retryAfter);
  }

  async syncLoadFeedsInTagIfStale(tag: string, staleTime: number, retryAfter: number): Promise<Feed[]> {
    return await FeedDao.syncLoadFeedsInTagIfStale(tag, staleTime, retryAfter);
  }

  async syncLoadFeedsIfStale(staleTime: number, retryAfter: number): Promise<Feed[]> {
    return await FeedDao.syncLoadFeedsIfStale(staleTime, retryAfter);
  }

  async syncLoadFeedsInTag(tag: string, retryAfter: number): Promise<Feed[]> {
    return await FeedDao.syncLoadFeedsInTag(tag, retryAfter);
  }

  async syncLoadFeeds(retryAfter: number): Promise<Feed[]> {
    return await FeedDao.syncLoadFeeds(retryAfter);
  }

  /** RP-A34：只把 URL 含该 host 的源 retry_after 往后推 */
  async setRetryAfterForFeedsWithBaseUrl(host: string, retryAfter: number): Promise<void> {
    await FeedDao.setRetryAfterForFeedsWithBaseUrl(host, retryAfter);
  }
}
