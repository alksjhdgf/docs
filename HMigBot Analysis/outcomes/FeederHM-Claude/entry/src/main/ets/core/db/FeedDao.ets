/**
 * FeedDao（源 db/room/FeedDao.kt）。SQL 照源；Flow → observeXxx(…, cb) 返回反订阅函数；PagingSource → limit/offset。
 * 所有方法末参 tx：在 AppDatabase.transaction 内传入事务连接；缺省为普通连接（写入经串行写锁并在完成后通知）。
 *
 * 差异（实现期自述，台账未登记）：insertFeed 源为 OnConflictStrategy.REPLACE（url 冲突时删旧行并级联删其全部文章），
 * 此处改为「按 id/url 命中则原地 UPDATE 并返回原 id」，避免级联误删。
 */
import { relationalStore } from '@kit.ArkData';
import { Feed, FeedForSettings, FeedTitle, FeedUnreadCount } from '../model/Feed';
import { ID_ALL_FEEDS, ID_SAVED_ARTICLES, ID_UNSET } from '../model/Enums';
import {
  AppDatabase, DbConn, SqlArg, TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_READ_STATUS_SYNCED, boolArg, numArgs,
  observeQuery, placeholders
} from './AppDatabase';
import {
  FEED_COLUMNS, feedToValues, readAll, readFeed, readFeedForSettings, readFeedTitle, readFeedUnreadCount, readFirst,
  readNumberColumn, readScalarNumber, readStringColumn, setClause, valuesInOrder
} from './DbRows';

/** 写 feeds 的同时可能级联 feed_items / read_status_synced */
const FEED_DELETE_TABLES: string[] = [TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_READ_STATUS_SYNCED];

/** 唯一约束冲突（Room 抛 SQLiteConstraintException 的等价） */
export class DbConstraintError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DbConstraintError';
  }
}

/**
 * 源 getPagedNavDrawerItems 的 SQL（:133-163），$ID_* 已代入。
 * 注（RP-A21）：「starred」段为无 GROUP BY 的聚合，SQLite（Android 同为 SQLite）恒返回 1 行，
 * 无收藏时为 (-20, sum=NULL→0)；源 NavDrawer.kt:164 亦据此硬编码 itemIndex == 2 放分隔线。照源保留。
 */
function navDrawerSql(expandedCount: number): string {
  const inTags: string = placeholders(expandedCount);
  return `
            -- wrap in select so we can collate in order
            select * from (
                -- all items
                select ${ID_ALL_FEEDS} as id, '' as display_title, '' as tag, '' as image_url, sum(unread) as unread_count, 0 as expanded, 0 as sort_section, 0 as sort_tag_or_feed
                from feeds_with_items_for_nav_drawer
                -- starred
                union
                select ${ID_SAVED_ARTICLES} as id, '' as display_title, '' as tag, '' as image_url, sum(bookmarked) as unread_count, 0 as expanded, 1 as sort_section, 0 as sort_tag_or_feed
                from feeds_with_items_for_nav_drawer
                where bookmarked
                -- tags
                union
                select ${ID_UNSET} as id, tag as display_title, tag, '' as image_url, sum(unread) as unread_count, tag in (${inTags}) as expanded, 2 as sort_section, 0 as sort_tag_or_feed
                from feeds_with_items_for_nav_drawer
                where tag is not ''
                group by tag
                -- feeds
                union
                select feed_id as id, display_title, tag, image_url, sum(unread) as unread_count, 0 as expanded, case when tag is '' then 3 else 2 end as sort_section, 1 as sort_tag_or_feed
                from feeds_with_items_for_nav_drawer
                where tag is '' or tag in (${inTags})
                group by feed_id
            )
            -- sort them
            order by sort_section, tag, sort_tag_or_feed, display_title collate nocase
        `;
}

export class FeedDao {
  // ------------------------------------------------------------ writes

  /**
   * 源 insertFeed（REPLACE）。返回行 id。
   * id>0 且存在 → 原地更新；否则 url 已存在 → 原地更新该行（保留 id 与文章）；否则插入。
   */
  static async insertFeed(feed: Feed, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      if (feed.id > ID_UNSET) {
        const byId: number | null = readScalarNumber(await c.query('SELECT id FROM feeds WHERE id IS ?', [feed.id]));
        if (byId !== null) {
          await FeedDao.updateRow(c, feed, feed.id);
          return feed.id;
        }
      }
      const byUrl: number | null = readScalarNumber(await c.query('SELECT id FROM feeds WHERE url IS ?', [feed.url]));
      if (byUrl !== null) {
        await FeedDao.updateRow(c, feed, byUrl);
        return byUrl;
      }
      const values: relationalStore.ValuesBucket = feedToValues(feed);
      if (feed.id > ID_UNSET) {
        values['id'] = feed.id;
      }
      const rowId: number = await c.insert(TABLE_FEEDS, values, relationalStore.ConflictResolution.ON_CONFLICT_ABORT);
      c.markChanged([TABLE_FEEDS]);
      return rowId;
    });
  }

  /** 源 @Update：按主键更新全列，返回影响行数 */
  static async updateFeed(feed: Feed, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      return await FeedDao.updateRow(c, feed, feed.id);
    });
  }

  /**
   * 源 @Upsert：先插入；唯一约束冲突则按主键更新（返回 -1）。
   * 主键不存在（id 未设而 url 冲突）时更新 0 行 → 抛 DbConstraintError，供 Repository 照源回退
   * （FeedStore.upsertFeed：按 url 取 id 后再 upsert）。
   */
  static async upsert(feed: Feed, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const conflictSql: string = feed.id > ID_UNSET ?
        'SELECT count(*) FROM feeds WHERE id IS ? OR url IS ?' : 'SELECT count(*) FROM feeds WHERE url IS ?';
      const conflictArgs: SqlArg[] = feed.id > ID_UNSET ? [feed.id, feed.url] : [feed.url];
      const conflicts: number | null = readScalarNumber(await c.query(conflictSql, conflictArgs));
      if (conflicts === null || conflicts === 0) {
        const values: relationalStore.ValuesBucket = feedToValues(feed);
        if (feed.id > ID_UNSET) {
          values['id'] = feed.id;
        }
        const rowId: number = await c.insert(TABLE_FEEDS, values, relationalStore.ConflictResolution.ON_CONFLICT_ABORT);
        c.markChanged([TABLE_FEEDS]);
        return rowId;
      }
      const updated: number = await FeedDao.updateRow(c, feed, feed.id);
      if (updated === 0) {
        throw new DbConstraintError(`UNIQUE constraint failed: feeds.url (${feed.url})`) as Object as Error;
      }
      return -1;
    });
  }

  private static async updateRow(c: DbConn, feed: Feed, id: number): Promise<number> {
    const args: SqlArg[] = valuesInOrder(feedToValues(feed), FEED_COLUMNS);
    args.push(id);
    const n: number = await c.exec(`UPDATE feeds SET ${setClause(FEED_COLUMNS)} WHERE id = ?`, args);
    c.markChanged([TABLE_FEEDS]);
    return n;
  }

  /** 显式级联（feed_items → read_status_synced），保证 DB-A05 不依赖连接级 foreign_keys */
  private static async deleteWhere(c: DbConn, where: string, args: SqlArg[]): Promise<number> {
    await c.exec(`DELETE FROM read_status_synced WHERE feed_item IN (SELECT id FROM feed_items WHERE feed_id IN (SELECT id FROM feeds WHERE ${where}))`, args);
    await c.exec(`DELETE FROM feed_items WHERE feed_id IN (SELECT id FROM feeds WHERE ${where})`, args);
    const n: number = await c.exec(`DELETE FROM feeds WHERE ${where}`, args);
    c.markChanged(FEED_DELETE_TABLES);
    return n;
  }

  static async deleteFeed(feed: Feed, tx: DbConn | null = null): Promise<number> {
    return await FeedDao.deleteFeedWithId(feed.id, tx);
  }

  static async deleteFeedWithId(feedId: number, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => FeedDao.deleteWhere(c, 'id IS ?', [feedId]));
  }

  static async deleteFeeds(ids: number[], tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx,
      (c: DbConn): Promise<number> => FeedDao.deleteWhere(c, `id IN (${placeholders(ids.length)})`, numArgs(ids)));
  }

  static async deleteFeedWithUrl(url: string, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => FeedDao.deleteWhere(c, 'url is ?', [url]));
  }

  private static async update(sql: string, args: SqlArg[], tx: DbConn | null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const n: number = await c.exec(sql, args);
      c.markChanged([TABLE_FEEDS]);
      return n;
    });
  }

  static async setNotify(id: number, notify: boolean, tx: DbConn | null = null): Promise<void> {
    await FeedDao.update('UPDATE feeds SET notify = ? WHERE id IS ?', [boolArg(notify), id], tx);
  }

  static async setNotifyForTag(tag: string, notify: boolean, tx: DbConn | null = null): Promise<void> {
    await FeedDao.update('UPDATE feeds SET notify = ? WHERE tag IS ?', [boolArg(notify), tag], tx);
  }

  static async renameTag(oldTag: string, newTag: string, tx: DbConn | null = null): Promise<void> {
    await FeedDao.update('UPDATE feeds SET tag = ? WHERE tag IS ?', [newTag, oldTag], tx);
  }

  static async setAllNotify(notify: boolean, tx: DbConn | null = null): Promise<void> {
    await FeedDao.update('UPDATE feeds SET notify = ?', [boolArg(notify)], tx);
  }

  static async setCurrentlySyncingOn(feedId: number, syncing: boolean, lastSync: number | null = null,
    tx: DbConn | null = null): Promise<void> {
    if (lastSync !== null) {
      await FeedDao.update('UPDATE feeds SET currently_syncing = ?, last_sync = ? WHERE id IS ?',
        [boolArg(syncing), lastSync, feedId], tx);
    } else {
      await FeedDao.update('UPDATE feeds SET currently_syncing = ? WHERE id IS ?', [boolArg(syncing), feedId], tx);
    }
  }

  /** DB-A36：只推迟不提前 */
  static async setRetryAfterForFeedsWithBaseUrl(host: string, retryAfter: number,
    tx: DbConn | null = null): Promise<void> {
    await FeedDao.update(`UPDATE feeds SET retry_after = ? WHERE url LIKE '%' || ? || '%' AND retry_after < ?`,
      [retryAfter, host, retryAfter], tx);
  }

  // ------------------------------------------------------------ reads

  static async getFeed(feedId: number, tx: DbConn | null = null): Promise<Feed | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feeds WHERE id IS ?', [feedId]), readFeed);
  }

  static observeFeed(feedId: number, cb: (feed: Feed | null) => void): () => void {
    return observeQuery<Feed | null>([TABLE_FEEDS], () => FeedDao.getFeed(feedId), cb);
  }

  static async loadTags(tx: DbConn | null = null): Promise<string[]> {
    return readStringColumn(await AppDatabase.reader(tx).query('SELECT DISTINCT tag FROM feeds ORDER BY tag COLLATE NOCASE'));
  }

  static observeAllTags(cb: (tags: string[]) => void): () => void {
    return observeQuery<string[]>([TABLE_FEEDS], () => FeedDao.loadTags(), cb);
  }

  static async syncLoadFeed(feedId: number, retryAfter: number, tx: DbConn | null = null): Promise<Feed | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feeds WHERE id IS ? and retry_after < ?',
      [feedId, retryAfter]), readFeed);
  }

  static async syncLoadFeedIfStale(feedId: number, staleTime: number, retryAfter: number,
    tx: DbConn | null = null): Promise<Feed | null> {
    return readFirst(await AppDatabase.reader(tx).query(
      'SELECT * FROM feeds WHERE id is ? AND last_sync < ? AND retry_after < ?', [feedId, staleTime, retryAfter]),
      readFeed);
  }

  static async syncLoadFeedsInTag(tag: string, retryAfter: number, tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT * FROM feeds WHERE tag IS ? AND retry_after < ? ORDER BY last_sync', [tag, retryAfter]), readFeed);
  }

  static async syncLoadFeedsInTagIfStale(tag: string, staleTime: number, retryAfter: number,
    tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT * FROM feeds WHERE tag IS ? AND last_sync < ? AND retry_after < ? ORDER BY last_sync',
      [tag, staleTime, retryAfter]), readFeed);
  }

  static async syncLoadFeeds(retryAfter: number, tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT * FROM feeds WHERE retry_after < ? ORDER BY last_sync', [retryAfter]), readFeed);
  }

  static async syncLoadFeedsIfStale(staleTime: number, retryAfter: number, tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT * FROM feeds WHERE last_sync < ? AND retry_after < ? ORDER BY last_sync', [staleTime, retryAfter]),
      readFeed);
  }

  static async getFeedsByTitle(tag: string, tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query('SELECT * FROM feeds WHERE tag IS ? ORDER BY title', [tag]),
      readFeed);
  }

  static async loadFeedsForSettings(tx: DbConn | null = null): Promise<FeedForSettings[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT
            id,
            COALESCE(NULLIF(custom_title, ''), title) as title,
            notify
        FROM feeds
        ORDER BY COALESCE(NULLIF(custom_title, ''), title) COLLATE NOCASE
        `), readFeedForSettings);
  }

  static observeFeedsForSettings(cb: (feeds: FeedForSettings[]) => void): () => void {
    return observeQuery<FeedForSettings[]>([TABLE_FEEDS], () => FeedDao.loadFeedsForSettings(), cb);
  }

  static async getAllFeeds(tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query('select * from feeds'), readFeed);
  }

  /** 源 loadFeedsForContentProvider（Cursor(id,title) 按 title） */
  static async loadFeedsForContentProvider(tx: DbConn | null = null): Promise<FeedTitle[]> {
    return readAll(await AppDatabase.reader(tx).query('SELECT id as id, title as title FROM feeds ORDER BY title'),
      readFeedTitle);
  }

  static async loadFeedWithUrl(url: string, tx: DbConn | null = null): Promise<Feed | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feeds WHERE url IS ?', [url]), readFeed);
  }

  static async loadFeedIdsToNotify(tx: DbConn | null = null): Promise<number[]> {
    return readNumberColumn(await AppDatabase.reader(tx).query('SELECT id FROM feeds WHERE notify IS 1'));
  }

  /** DB-A33：抽屉条目（limit=-1 取全部） */
  static async getNavDrawerItems(expandedTags: string[], limit: number = -1, offset: number = 0,
    tx: DbConn | null = null): Promise<FeedUnreadCount[]> {
    const args: SqlArg[] = [];
    for (const t of expandedTags) {
      args.push(t);
    }
    for (const t of expandedTags) {
      args.push(t);
    }
    args.push(limit);
    args.push(offset);
    return readAll(await AppDatabase.reader(tx).query(`${navDrawerSql(expandedTags.length)} LIMIT ? OFFSET ?`, args),
      readFeedUnreadCount);
  }

  static observeNavDrawerItems(expandedTags: string[], cb: (items: FeedUnreadCount[]) => void): () => void {
    const tags: string[] = expandedTags.slice();
    return observeQuery<FeedUnreadCount[]>([TABLE_FEEDS, TABLE_FEED_ITEMS], () => FeedDao.getNavDrawerItems(tags), cb);
  }

  static async getFeedTitle(feedId: number, tx: DbConn | null = null): Promise<FeedTitle | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT id, title, custom_title FROM feeds WHERE id IS ?',
      [feedId]), readFeedTitle);
  }

  static async getFeedIdForUrl(url: string, tx: DbConn | null = null): Promise<number | null> {
    return readScalarNumber(await AppDatabase.reader(tx).query('SELECT id FROM feeds where url is ?', [url]));
  }

  static async getFeedTitlesWithId(feedId: number, tx: DbConn | null = null): Promise<FeedTitle[]> {
    return readAll(await AppDatabase.reader(tx).query('SELECT id, title, custom_title FROM feeds WHERE id IS ?',
      [feedId]), readFeedTitle);
  }

  static async getFeedTitlesWithTag(feedTag: string, tx: DbConn | null = null): Promise<FeedTitle[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT id, title, custom_title FROM feeds WHERE tag IS ? ORDER BY title COLLATE NOCASE', [feedTag]),
      readFeedTitle);
  }

  static async getAllFeedTitles(tx: DbConn | null = null): Promise<FeedTitle[]> {
    return readAll(await AppDatabase.reader(tx).query(
      'SELECT id, title, custom_title FROM feeds ORDER BY title COLLATE NOCASE'), readFeedTitle);
  }

  /** 源 FeedStore.getFeedTitles 的分派（id>0 / 非空白 tag / 全部），可观察 */
  static observeFeedTitles(feedId: number, tag: string, cb: (titles: FeedTitle[]) => void): () => void {
    return observeQuery<FeedTitle[]>([TABLE_FEEDS], (): Promise<FeedTitle[]> => {
      if (feedId > ID_UNSET) {
        return FeedDao.getFeedTitlesWithId(feedId);
      } else if (tag.trim().length > 0) {
        return FeedDao.getFeedTitlesWithTag(tag);
      }
      return FeedDao.getAllFeedTitles();
    }, cb);
  }

  /** DB-A37：MAX(last_sync)（故意不按 currently_syncing 过滤） */
  static async getCurrentlySyncingLatestTimestamp(tx: DbConn | null = null): Promise<number | null> {
    return readScalarNumber(await AppDatabase.reader(tx).query('SELECT MAX(last_sync) FROM feeds'));
  }

  static observeCurrentlySyncingLatestTimestamp(cb: (ts: number | null) => void): () => void {
    return observeQuery<number | null>([TABLE_FEEDS], () => FeedDao.getCurrentlySyncingLatestTimestamp(), cb);
  }

  static async getFeedsOrderedByUrl(tx: DbConn | null = null): Promise<Feed[]> {
    return readAll(await AppDatabase.reader(tx).query('SELECT * FROM feeds ORDER BY url'), readFeed);
  }

  static observeFeedsOrderedByUrl(cb: (feeds: Feed[]) => void): () => void {
    return observeQuery<Feed[]>([TABLE_FEEDS], () => FeedDao.getFeedsOrderedByUrl(), cb);
  }
}
