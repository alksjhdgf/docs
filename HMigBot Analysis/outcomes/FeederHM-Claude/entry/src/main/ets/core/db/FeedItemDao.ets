/**
 * FeedItemDao（源 db/room/FeedItemDao.kt）+ 源 archmodel/FeedItemStore.kt 的原始 SQL（列表/计数/上下方标已读）。
 * SQL 照源；Flow → observeXxx(…, cb)（返回反订阅函数）；PagingSource → limit/offset 分页查询。
 * 所有方法末参 tx：AppDatabase.transaction 内传入事务连接；缺省普通连接（写经串行写锁，完成后 DbNotifier 通知）。
 */
import { relationalStore } from '@kit.ArkData';
import { FeedItem, FeedItemCursor, FeedItemIdWithLink, FeedItemWithFeed } from '../model/FeedItem';
import { PREVIEW_COLUMNS, PreviewItem } from '../model/Parsed';
import { ID_SAVED_ARTICLES, ID_UNSET } from '../model/Enums';
import { EPOCH_MS } from '../model/Feed';
import { FeedListFilter } from '../settings/SettingsModels';
import {
  AppDatabase, DbConn, SqlArg, TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_READ_STATUS_SYNCED, boolArg, numArgs,
  observeQuery, placeholders, strArgs
} from './AppDatabase';
import {
  FEED_ITEM_COLUMNS, FEED_ITEM_COLUMNS_WITH_FEED, RowMapper, colNum, colStr, feedItemToValues, readAll, readFeedItem,
  readFeedItemIdWithLink, readFeedItemWithFeed, readFirst, readNumberColumn, readPreviewItem, readScalarNumber,
  readStringColumn, setClause, valuesInOrder, colUrlOrNull
} from './DbRows';

// These are backed by a database index
export const FEED_ITEM_LIST_SORT_ORDER_DESC: string = 'primary_sort_time DESC, pub_date DESC, feed_items.id DESC';
export const FEED_ITEM_LIST_SORT_ORDER_ASC: string = 'primary_sort_time ASC, pub_date ASC, feed_items.id ASC';

/** 源 upsertFeedItems 的 Pair<FeedItem, String> */
export interface FeedItemWithText {
  item: FeedItem;
  text: string;
}

export type FeedItemTextBlock = (item: FeedItem, text: string) => Promise<void>;

/** 源 loadFeedItemsForContentProvider 的 Cursor 行（id,title,text） */
export class ContentProviderItem {
  id: number = ID_UNSET;
  title: string = '';
  text: string = '';
}

const readContentProviderItem: RowMapper<ContentProviderItem> = (rs: relationalStore.ResultSet): ContentProviderItem => {
  const c: ContentProviderItem = new ContentProviderItem();
  c.id = colNum(rs, 'id', ID_UNSET);
  c.title = colStr(rs, 'title');
  c.text = colStr(rs, 'text');
  return c;
};

const ITEM_TABLES: string[] = [TABLE_FEED_ITEMS];
/** 列表/计数依赖 feeds（tag/标题 join） */
const LIST_TABLES: string[] = [TABLE_FEED_ITEMS, TABLE_FEEDS];

/**
 * 源 FeedItemStore.rawQueryFilter（:130-180），逐行照搬。DB-A23/A24/A25。
 * 返回追加到 `WHERE\n` 之后的 SQL 片段，参数追加到 args。
 */
export function rawQueryFilter(filter: FeedListFilter, search: string, args: SqlArg[], minReadTime: number,
  feedId: number, tag: string): string {
  const onlySavedArticles: boolean = feedId === ID_SAVED_ARTICLES;
  let q: string = '';
  // Always blocklist
  q += 'block_time is null\n';
  // List filter
  if (!onlySavedArticles) {
    q += 'AND (\n';
    if (filter.unread && !filter.recentlyRead && !filter.read) {
      q += 'read_time is null\n';
    } else {
      q += '(read_time is null or read_time >= ?)\n';
      args.push(filter.read ? EPOCH_MS : minReadTime);
    }
    if (filter.saved) {
      q += 'OR (bookmarked = 1)\n';
    }
    q += ')\n';
  }
  if (search.length > 0) {
    // User probably means the literal characters
    const sanitizedSearch: string = search
      .split('\\').join('\\\\')
      .split('%').join('\\%')
      .split('_').join('\\_');
    q += 'AND (\n';
    q += 'plain_title LIKE ?\n';
    args.push(`%${sanitizedSearch}%`);
    q += 'OR plain_snippet LIKE ?\n';
    args.push(`%${sanitizedSearch}%`);
    q += ')\n';
  } else if (onlySavedArticles) {
    q += 'AND bookmarked = 1\n';
  } else if (feedId > ID_UNSET) {
    q += 'AND feed_id IS ?\n';
    args.push(feedId);
  } else if (tag.length > 0) {
    q += 'AND tag IS ?\n';
    args.push(tag);
  }
  return q;
}

export class FeedItemDao {
  // ============================================================ writes

  private static async write(sql: string, args: SqlArg[], tx: DbConn | null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const n: number = await c.exec(sql, args);
      c.markChanged(ITEM_TABLES);
      return n;
    });
  }

  private static async insertRow(c: DbConn, item: FeedItem): Promise<number> {
    const values: relationalStore.ValuesBucket = feedItemToValues(item);
    if (item.id > ID_UNSET) {
      values['id'] = item.id;
    }
    const id: number = await c.insert(TABLE_FEED_ITEMS, values, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
    c.markChanged(ITEM_TABLES);
    return id;
  }

  private static async updateRow(c: DbConn, item: FeedItem): Promise<number> {
    const args: SqlArg[] = valuesInOrder(feedItemToValues(item), FEED_ITEM_COLUMNS);
    args.push(item.id);
    const n: number = await c.exec(`UPDATE feed_items SET ${setClause(FEED_ITEM_COLUMNS)} WHERE id = ?`, args);
    c.markChanged(ITEM_TABLES);
    return n;
  }

  /** 源 insert IGNORE：DB-A04 (guid,feed_id) 重复被忽略，返回 -1 */
  static async insertFeedItem(item: FeedItem, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => FeedItemDao.insertRow(c, item));
  }

  /** 源 insertFeedItems（Room 单事务批量插入），返回各行 id（忽略者 -1） */
  static async insertFeedItems(items: FeedItem[], tx: DbConn | null = null): Promise<number[]> {
    const body = async (c: DbConn): Promise<number[]> => {
      const ids: number[] = [];
      for (const it of items) {
        ids.push(await FeedItemDao.insertRow(c, it));
      }
      return ids;
    };
    if (tx !== null) {
      return await body(tx);
    }
    if (items.length === 0) {
      return [];
    }
    return await AppDatabase.transaction<number[]>(body);
  }

  static async updateFeedItem(item: FeedItem, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => FeedItemDao.updateRow(c, item));
  }

  static async updateFeedItems(items: FeedItem[], tx: DbConn | null = null): Promise<number> {
    const body = async (c: DbConn): Promise<number> => {
      let n: number = 0;
      for (const it of items) {
        n += await FeedItemDao.updateRow(c, it);
      }
      return n;
    };
    if (tx !== null) {
      return await body(tx);
    }
    if (items.length === 0) {
      return 0;
    }
    return await AppDatabase.transaction<number>(body);
  }

  /** 显式级联 read_status_synced（DB-A05） */
  static async deleteFeedItems(ids: number[], tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const ph: string = placeholders(ids.length);
      await c.exec(`DELETE FROM read_status_synced WHERE feed_item IN (${ph})`, numArgs(ids));
      const n: number = await c.exec(`DELETE FROM feed_items WHERE id IN (${ph})`, numArgs(ids));
      c.markChanged([TABLE_FEED_ITEMS, TABLE_READ_STATUS_SYNCED]);
      return n;
    });
  }

  static async deleteFeedItem(item: FeedItem, tx: DbConn | null = null): Promise<number> {
    return await FeedItemDao.deleteFeedItems([item.id], tx);
  }

  /**
   * 源扩展 upsertFeedItems（:580-607，DB-A19）：id>0 更新、否则插入并回填 id；随后对每条调用 block。
   * 更新与插入各自原子；block（写正文文件等 I/O）在写锁之外执行。
   */
  static async upsertFeedItems(itemsWithText: FeedItemWithText[], block: FeedItemTextBlock,
    tx: DbConn | null = null): Promise<void> {
    const updatedItems: FeedItemWithText[] = itemsWithText.filter((p: FeedItemWithText): boolean => p.item.id > ID_UNSET);
    await FeedItemDao.updateFeedItems(updatedItems.map((p: FeedItemWithText): FeedItem => p.item), tx);

    const insertedItems: FeedItemWithText[] =
      itemsWithText.filter((p: FeedItemWithText): boolean => p.item.id <= ID_UNSET);
    const insertedIds: number[] =
      await FeedItemDao.insertFeedItems(insertedItems.map((p: FeedItemWithText): FeedItem => p.item), tx);

    for (const p of updatedItems) {
      await block(p.item, p.text);
    }
    const n: number = Math.min(insertedIds.length, insertedItems.length);
    for (let i = 0; i < n; i++) {
      const p: FeedItemWithText = insertedItems[i];
      p.item.id = insertedIds[i];
      await block(p.item, p.text);
    }
  }

  static async updateWordCountFull(id: number, wordCount: number, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('update feed_items set word_count_full = ? where id = ?', [wordCount, id], tx);
  }

  /** DB-A26：保留首次已读时间并置 notified */
  static async markAllAsRead(readTime: number = Date.now(), tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET read_time = coalesce(read_time, ?), notified = 1', [readTime], tx);
  }

  static async markAllAsReadInFeed(feedId: number | null, readTime: number = Date.now(),
    tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write(
      'UPDATE feed_items SET read_time = coalesce(read_time, ?), notified = 1 WHERE feed_id IS ?', [readTime, feedId], tx);
  }

  static async markAllAsReadInTag(tag: string, readTime: number = Date.now(), tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write(`
        UPDATE feed_items
        SET read_time = coalesce(read_time, ?), notified = 1
        WHERE id IN (
          SELECT feed_items.id
          FROM feed_items
          LEFT JOIN feeds ON feed_items.feed_id = feeds.id
          WHERE tag IS ?
        )`, [readTime, tag], tx);
  }

  static async markAsUnread(id: number, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET read_time = null WHERE id IS ?', [id], tx);
  }

  static async markAsRead(ids: number[], readTime: number = Date.now(), tx: DbConn | null = null): Promise<void> {
    const args: SqlArg[] = [readTime];
    for (const id of ids) {
      args.push(id);
    }
    await FeedItemDao.write(
      `UPDATE feed_items SET read_time = coalesce(read_time, ?), notified = 1 WHERE id IN (${placeholders(ids.length)})`,
      args, tx);
  }

  static async setBookmarked(id: number, bookmarked: boolean, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET bookmarked = ? WHERE id IS ?', [boolArg(bookmarked), id], tx);
  }

  /** DB-A32：导入按链接批量置收藏 */
  static async setBookmarkedByLinks(links: string[], tx: DbConn | null = null): Promise<number> {
    return await FeedItemDao.write(`UPDATE feed_items SET bookmarked = 1 WHERE link IN (${placeholders(links.length)})`,
      strArgs(links), tx);
  }

  static async markAsNotified(ids: number[], notified: boolean = true, tx: DbConn | null = null): Promise<void> {
    const args: SqlArg[] = [boolArg(notified)];
    for (const id of ids) {
      args.push(id);
    }
    await FeedItemDao.write(`UPDATE feed_items SET notified = ? WHERE id IN (${placeholders(ids.length)})`, args, tx);
  }

  static async markAsNotifiedById(id: number, notified: boolean = true, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET notified = ? WHERE id IS ?', [boolArg(notified), id], tx);
  }

  static async markTagAsNotified(tag: string, notified: boolean = true, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write(`
        UPDATE feed_items
        SET notified = ?
        WHERE id IN (
          SELECT feed_items.id
          FROM feed_items
          LEFT JOIN feeds ON feed_items.feed_id = feeds.id
          WHERE tag IS ?
        )`, [boolArg(notified), tag], tx);
  }

  static async markAllAsNotified(notified: boolean = true, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET notified = ?', [boolArg(notified)], tx);
  }

  static async markAsReadAndNotified(id: number, readTime: number = Date.now(), tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET read_time = coalesce(read_time, ?), notified = 1 WHERE id IS ?',
      [readTime, id], tx);
  }

  static async markAsReadAndNotifiedAndOverwriteReadTime(id: number, readTime: number = Date.now(),
    tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET read_time = ?, notified = 1 WHERE id IS ?', [readTime, id], tx);
  }

  static async markAsFullTextDownloaded(feedItemId: number, tx: DbConn | null = null): Promise<void> {
    await FeedItemDao.write('UPDATE feed_items SET fulltext_downloaded = 1 WHERE id = ?', [feedItemId], tx);
  }

  /**
   * 源 FeedItemStore.markAsReadRaw（:182-248，DB-A27）：按游标 (primary_sort_time, pub_date, id)
   * 把排序在当前条目之后（descending=true：更旧）/之前的、且符合当前过滤的文章标已读；写后通知刷新。
   */
  static async markAsReadRaw(feedId: number, tag: string, filter: FeedListFilter, search: string, minReadTime: number,
    descending: boolean, cursor: FeedItemCursor, tx: DbConn | null = null): Promise<void> {
    const args: SqlArg[] = [];
    let q: string = 'UPDATE feed_items SET read_time = coalesce(read_time, ?), notified = 1\n';
    args.push(Date.now());
    q += 'WHERE id IN (\n';
    q += 'SELECT feed_items.id FROM feed_items\n';
    q += 'LEFT JOIN feeds ON feed_items.feed_id = feeds.id\n';
    q += 'WHERE\n';
    q += rawQueryFilter(filter, search, args, minReadTime, feedId, tag);
    // this version of sqlite doesn't seem to support tuple comparisons
    q += 'and (\n';
    q += descending ? 'primary_sort_time < ?\n' : 'primary_sort_time > ?\n';
    args.push(cursor.primarySortTime);
    q += descending ? 'or primary_sort_time = ? and pub_date < ?\n' : 'or primary_sort_time = ? and pub_date > ?\n';
    args.push(cursor.primarySortTime);
    args.push(cursor.pubDate);
    q += descending ? 'or primary_sort_time = ? and pub_date = ? and feed_items.id < ?\n' :
      'or primary_sort_time = ? and pub_date = ? and feed_items.id > ?\n';
    args.push(cursor.primarySortTime);
    args.push(cursor.pubDate);
    args.push(cursor.id);
    q += ')\n';
    // where id in (
    q += ')\n';
    await FeedItemDao.write(q, args, tx);
  }

  // ============================================================ reads

  /** DB-A20：非收藏条目按排序跳过前 keepCount 条，返回其余 id */
  static async getItemsToBeCleanedFromFeed(feedId: number, keepCount: number, tx: DbConn | null = null): Promise<number[]> {
    return readNumberColumn(await AppDatabase.reader(tx).query(`
        SELECT id FROM feed_items
        WHERE feed_id IS ? AND bookmarked = 0
        ORDER BY primary_sort_time DESC, pub_date DESC
        LIMIT -1 OFFSET ?
        `, [feedId, keepCount]));
  }

  static async loadFeedItem(guid: string, feedId: number | null, tx: DbConn | null = null): Promise<FeedItem | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feed_items WHERE guid IS ? AND feed_id IS ?',
      [guid, feedId]), readFeedItem);
  }

  static async loadFeedItemById(id: number, tx: DbConn | null = null): Promise<FeedItem | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feed_items WHERE id IS ?', [id]), readFeedItem);
  }

  static async loadFeedItemByLink(link: string, tx: DbConn | null = null): Promise<FeedItem | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM feed_items WHERE link IS ? ORDER BY id LIMIT 1',
      [link]), readFeedItem);
  }

  /** 源 loadFeedItemWithFeed / getFeedItem（同 SQL） */
  static async getFeedItem(id: number, tx: DbConn | null = null): Promise<FeedItemWithFeed | null> {
    return readFirst(await AppDatabase.reader(tx).query(`
        SELECT ${FEED_ITEM_COLUMNS_WITH_FEED}
        FROM feed_items
        LEFT JOIN feeds ON feed_items.feed_id = feeds.id
        WHERE feed_items.id IS ?
        `, [id]), readFeedItemWithFeed);
  }

  /** 源 getFeedItemFlow（文章详情可观察，DB-A28） */
  static observeFeedItem(id: number, cb: (item: FeedItemWithFeed | null) => void): () => void {
    return observeQuery<FeedItemWithFeed | null>(LIST_TABLES, () => FeedItemDao.getFeedItem(id), cb);
  }

  static async loadFeedUrlOfFeedItem(id: number, tx: DbConn | null = null): Promise<string | null> {
    return readFirst(await AppDatabase.reader(tx).query(`
        SELECT feeds.url
        FROM feed_items
        LEFT JOIN feeds ON feed_items.feed_id = feeds.id
        WHERE feed_items.id IS ?
        `, [id]), (rs: relationalStore.ResultSet): string | null => colUrlOrNull(rs, 'url'));
  }

  static async loadFeedItemsInFeedDescDoNotUseInProd(feedId: number, tx: DbConn | null = null): Promise<FeedItem[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT *
        FROM feed_items
        WHERE feed_items.feed_id = ?
        ORDER BY primary_sort_time DESC, pub_date DESC
        `, [feedId]), readFeedItem);
  }

  static async loadFeedItemsForContentProvider(tx: DbConn | null = null): Promise<ContentProviderItem[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT id as id, title as title, plain_snippet as text
        FROM feed_items
        WHERE block_time is null
        ORDER BY primary_sort_time DESC, pub_date DESC
        `), readContentProviderItem);
  }

  static async loadFeedItemsInFeedForContentProvider(feedId: number,
    tx: DbConn | null = null): Promise<ContentProviderItem[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT id as id, title as title, plain_snippet as text
        FROM feed_items
        WHERE feed_items.feed_id = ?
          AND block_time is null
        ORDER BY primary_sort_time DESC, pub_date DESC
        `, [feedId]), readContentProviderItem);
  }

  /** DB-A30：小组件（源 FeedItemStore.getWidgetFeedListItems 分派），降序最多 50 条 */
  static async getWidgetPreviews(feedId: number, tag: string, tx: DbConn | null = null): Promise<PreviewItem[]> {
    let where: string;
    const args: SqlArg[] = [];
    if (feedId === ID_SAVED_ARTICLES) {
      where = 'bookmarked = 1';
    } else if (feedId > ID_UNSET) {
      where = 'feed_id IS ?';
      args.push(feedId);
    } else if (tag.length > 0) {
      where = 'tag IS ?';
      args.push(tag);
    } else {
      where = '1';
    }
    const whereClause: string = where === '1' ? 'WHERE block_time IS NULL' : `WHERE ${where}\n          AND block_time IS NULL`;
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT ${PREVIEW_COLUMNS}
        FROM feed_items
        LEFT JOIN feeds ON feed_items.feed_id = feeds.id
        ${whereClause}
        ORDER BY ${FEED_ITEM_LIST_SORT_ORDER_DESC}
        LIMIT 50
        `, args), readPreviewItem);
  }

  static observeWidgetPreviews(feedId: number, tag: string, cb: (items: PreviewItem[]) => void): () => void {
    return observeQuery<PreviewItem[]>(LIST_TABLES, () => FeedItemDao.getWidgetPreviews(feedId, tag), cb);
  }

  /** 源 FeedItemStore.getPagedFeedItemsRaw 的分页查询（DB-A22..A25）；limit=-1 取全部 */
  static async getPreviewsRaw(feedId: number, tag: string, minReadTime: number, newestFirst: boolean,
    filter: FeedListFilter, search: string, limit: number = -1, offset: number = 0,
    tx: DbConn | null = null): Promise<PreviewItem[]> {
    const args: SqlArg[] = [];
    let q: string = `SELECT ${PREVIEW_COLUMNS} FROM feed_items\n`;
    q += 'LEFT JOIN feeds ON feed_items.feed_id = feeds.id\n';
    q += 'WHERE\n';
    q += rawQueryFilter(filter, search, args, minReadTime, feedId, tag);
    q += newestFirst ? `ORDER BY ${FEED_ITEM_LIST_SORT_ORDER_DESC}\n` : `ORDER BY ${FEED_ITEM_LIST_SORT_ORDER_ASC}\n`;
    q += 'LIMIT ? OFFSET ?\n';
    args.push(limit);
    args.push(offset);
    return readAll(await AppDatabase.reader(tx).query(q, args), readPreviewItem);
  }

  /** 源 FeedItemStore.getFeedItemCountRaw */
  static async getFeedItemCountRaw(feedId: number, tag: string, minReadTime: number, filter: FeedListFilter,
    search: string, tx: DbConn | null = null): Promise<number> {
    const args: SqlArg[] = [];
    let q: string = 'SELECT count(*) FROM feed_items\n';
    q += 'LEFT JOIN feeds ON feed_items.feed_id = feeds.id\n';
    q += 'WHERE\n';
    q += rawQueryFilter(filter, search, args, minReadTime, feedId, tag);
    const n: number | null = readScalarNumber(await AppDatabase.reader(tx).query(q, args));
    return n === null ? 0 : n;
  }

  static observeFeedItemCountRaw(feedId: number, tag: string, minReadTime: number, filter: FeedListFilter,
    search: string, cb: (count: number) => void): () => void {
    return observeQuery<number>(LIST_TABLES,
      () => FeedItemDao.getFeedItemCountRaw(feedId, tag, minReadTime, filter, search), cb);
  }

  /** DB-A29：notified=0、未读、未屏蔽，降序最多 20 条 */
  static async loadItemsToNotify(feedIds: number[], tx: DbConn | null = null): Promise<FeedItemWithFeed[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT ${FEED_ITEM_COLUMNS_WITH_FEED}
        FROM feed_items
        LEFT JOIN feeds ON feed_items.feed_id = feeds.id
        WHERE feed_id IN (${placeholders(feedIds.length)}) AND notified IS 0 AND read_time is null
          AND block_time is null
        ORDER BY ${FEED_ITEM_LIST_SORT_ORDER_DESC}
        LIMIT 20
        `, numArgs(feedIds)), readFeedItemWithFeed);
  }

  static async getBookmarkedItemsForExport(tx: DbConn | null = null): Promise<FeedItemWithFeed[]> {
    return readAll(await AppDatabase.reader(tx).query(`
        SELECT ${FEED_ITEM_COLUMNS_WITH_FEED}
        FROM feed_items
        LEFT JOIN feeds ON feed_items.feed_id = feeds.id
        WHERE bookmarked = 1
          AND link IS NOT NULL
        ORDER BY link
        `), readFeedItemWithFeed);
  }

  static async getLinksOfBookmarks(tx: DbConn | null = null): Promise<string[]> {
    return readStringColumn(await AppDatabase.reader(tx).query(
      'SELECT link FROM feed_items WHERE bookmarked = 1 order by link'));
  }

  static async getOpenArticleWith(itemId: number, tx: DbConn | null = null): Promise<string | null> {
    return readFirst(await AppDatabase.reader(tx).query(`
            SELECT feeds.open_articles_with
            FROM feed_items
            LEFT JOIN feeds ON feed_items.feed_id = feeds.id
            WHERE feed_items.id IS ?
        `, [itemId]), (rs: relationalStore.ResultSet): string | null => rs.isColumnNull(0) ? null : rs.getString(0));
  }

  static async getFullTextByDefault(itemId: number, tx: DbConn | null = null): Promise<boolean | null> {
    const v: number | null = readScalarNumber(await AppDatabase.reader(tx).query(`
            SELECT feeds.fulltext_by_default
            FROM feed_items
            LEFT JOIN feeds ON feed_items.feed_id = feeds.id
            WHERE feed_items.id IS ?
        `, [itemId]));
    return v === null ? null : v !== 0;
  }

  static async getLink(itemId: number, tx: DbConn | null = null): Promise<string | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT link FROM feed_items WHERE feed_items.id IS ?', [itemId]),
      (rs: relationalStore.ResultSet): string | null => rs.isColumnNull(0) ? null : rs.getString(0));
  }

  /** DB-A31 */
  static async getFeedsItemsWithDefaultFullTextNeedingDownload(tx: DbConn | null = null): Promise<FeedItemIdWithLink[]> {
    return readAll(await AppDatabase.reader(tx).query(`
            SELECT fi.id, fi.link
            FROM feed_items fi
            JOIN feeds f ON feed_id = f.id
            WHERE f.fulltext_by_default = 1
                AND fi.fulltext_downloaded <> 1
                and block_time is null
        `), readFeedItemIdWithLink);
  }

  static observeFeedsItemsWithDefaultFullTextNeedingDownload(cb: (items: FeedItemIdWithLink[]) => void): () => void {
    return observeQuery<FeedItemIdWithLink[]>(LIST_TABLES,
      () => FeedItemDao.getFeedsItemsWithDefaultFullTextNeedingDownload(), cb);
  }

  /** DB-A29：订阅 notify=1、notified=0、未读、未屏蔽 */
  static async getFeedItemsNeedingNotifying(tx: DbConn | null = null): Promise<number[]> {
    return readNumberColumn(await AppDatabase.reader(tx).query(`
            SELECT fi.id
            FROM feed_items fi
            JOIN feeds f ON feed_id = f.id
            WHERE f.notify IS 1 AND fi.notified IS 0 AND fi.read_time is null
              and block_time is null
        `));
  }

  static observeFeedItemsNeedingNotifying(cb: (ids: number[]) => void): () => void {
    return observeQuery<number[]>(LIST_TABLES, () => FeedItemDao.getFeedItemsNeedingNotifying(), cb);
  }

  static async getItemWith(feedUrl: string, articleGuid: string, tx: DbConn | null = null): Promise<number | null> {
    return readScalarNumber(await AppDatabase.reader(tx).query(`
            SELECT fi.id
            FROM feed_items fi
            JOIN feeds f ON fi.feed_id = f.id
            where f.url IS ? AND fi.guid IS ?
        `, [feedUrl, articleGuid]));
  }

  /** DB-A21 */
  static async duplicationExists(id: number, plainTitle: string, link: string | null,
    tx: DbConn | null = null): Promise<boolean> {
    const v: number | null = readScalarNumber(await AppDatabase.reader(tx).query(`
            select exists(
                select id
                from feed_items
                where id <> ? and (plain_title = ? or link = ?) and plain_title <> '' and link is not null and link <> ''
            )
        `, [id, plainTitle, link]));
    return v !== null && v !== 0;
  }

  static async getAllFeedItemIds(tx: DbConn | null = null): Promise<number[]> {
    return readNumberColumn(await AppDatabase.reader(tx).query('SELECT id FROM feed_items'));
  }
}
