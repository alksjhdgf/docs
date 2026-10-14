/**
 * FeedItemStore（源 archmodel/FeedItemStore.kt）：文章条目仓储，薄封装 FeedItemDao / BlocklistDao。
 * 原始 SQL（rawQueryFilter/计数/上下方标已读）由 core/db/FeedItemDao 照源实现；本层负责
 * PreviewItem → FeedListItem 转换（含日期格式化 formatForFeed）与分页（PagedList）。
 */
import { i18n } from '@kit.LocalizationKit';
import { FeedItem, FeedItemCursor, FeedItemIdWithLink, FeedItemWithFeed, FeedListItem } from '../model/FeedItem';
import { PreviewItem } from '../model/Parsed';
import { EPOCH_MS, JavaTime, ZonedDateTimeValue } from '../model/Feed';
import { TABLE_FEEDS, TABLE_FEED_ITEMS } from '../db/AppDatabase';
import { FeedItemDao, FeedItemTextBlock, FeedItemWithText } from '../db/FeedItemDao';
import { BlocklistDao } from '../db/BlocklistDao';
import { SettingsStore } from '../settings/SettingsStore';
import { FeedListFilter } from '../settings/SettingsModels';
import { PagedList, PagedListCallback, PagingConfig } from './RepoTypes';

/** 源 getPagedFeedItemsRaw 的 PagingConfig(pageSize=10, initialLoadSize=100, prefetchDistance=100) */
export const FEED_LIST_PAGING: PagingConfig = new PagingConfig(10, 100, 100);

// ============================================================ 日期格式化（源 ZonedDateTime?.formatForFeed）

let cachedFormatKey: string = '';
let cachedTimeFormat: Intl.DateTimeFormat | null = null;
let cachedDateFormat: Intl.DateTimeFormat | null = null;

function systemLocale(): string {
  try {
    return i18n.System.getSystemLocale();
  } catch (e) {
    return 'en-US';
  }
}

function systemIs24Hour(): boolean {
  try {
    return i18n.System.is24HourClock();
  } catch (e) {
    return true;
  }
}

/** 源 DateFormat.getTimeFormat(context)：跟随系统 12/24 小时制 */
function timeFormat(locale: string, is24: boolean): Intl.DateTimeFormat {
  let opts: Intl.DateTimeFormatOptions;
  if (is24) {
    opts = { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' };
  } else {
    opts = { hour: 'numeric', minute: '2-digit', hourCycle: 'h12' };
  }
  return new Intl.DateTimeFormat(locale, opts);
}

/** 源 DateFormat.getMediumDateFormat(context) */
function mediumDateFormat(locale: string): Intl.DateTimeFormat {
  const opts: Intl.DateTimeFormatOptions = { dateStyle: 'medium' };
  return new Intl.DateTimeFormat(locale, opts);
}

function ensureFormatters(): void {
  const locale: string = systemLocale();
  const is24: boolean = systemIs24Hour();
  const key: string = `${locale}|${is24}`;
  if (key === cachedFormatKey && cachedTimeFormat !== null && cachedDateFormat !== null) {
    return;
  }
  try {
    cachedTimeFormat = timeFormat(locale, is24);
    cachedDateFormat = mediumDateFormat(locale);
  } catch (e) {
    cachedTimeFormat = timeFormat('en-US', is24);
    cachedDateFormat = mediumDateFormat('en-US');
  }
  cachedFormatKey = key;
}

/**
 * 源 formatForFeed（RP-A16）：发布日（本地时区）>= 今天 → 系统时间格式，否则系统中等日期格式；null/不可解析 → ""。
 * nowMs 可注入（测试用）。
 */
export function formatForFeed(pubDate: string | null, nowMs: number = Date.now()): string {
  if (pubDate === null) {
    return '';
  }
  const z: ZonedDateTimeValue | null = JavaTime.parseZoned(pubDate);
  if (z === null) {
    return '';
  }
  const startOfToday: Date = new Date(nowMs);
  startOfToday.setHours(0, 0, 0, 0);
  ensureFormatters();
  const d: Date = new Date(z.epochMs);
  try {
    if (z.epochMs >= startOfToday.getTime()) {
      return (cachedTimeFormat as Intl.DateTimeFormat).format(d);
    }
    return (cachedDateFormat as Intl.DateTimeFormat).format(d);
  } catch (e) {
    return d.toLocaleString();
  }
}

/** 源 PreviewItem.toFeedListItem（RP-A16：unread = read_time 为空） */
export function previewToFeedListItem(p: PreviewItem): FeedListItem {
  return new FeedListItem(p.id, p.plainTitle, p.plainSnippet, p.feedDisplayTitle, p.readTime === null,
    formatForFeed(p.pubDate), p.image, p.link, p.bookmarked, p.feedImageUrl, p.primarySortTime, p.pubDate,
    p.bestWordCount);
}

function toListItems(previews: PreviewItem[]): FeedListItem[] {
  return previews.map((p: PreviewItem): FeedListItem => previewToFeedListItem(p));
}

const LIST_TABLES: string[] = [TABLE_FEED_ITEMS, TABLE_FEEDS];

export class FeedItemStore {
  private static inst: FeedItemStore | null = null;

  static instance(): FeedItemStore {
    if (FeedItemStore.inst === null) {
      FeedItemStore.inst = new FeedItemStore();
    }
    return FeedItemStore.inst as FeedItemStore;
  }

  /** 同步新条目时按当前"应用到摘要/链接"设置屏蔽本源新条目 */
  async setBlockStatusForNewInFeed(feedId: number, blockTime: number): Promise<void> {
    const s: SettingsStore = SettingsStore.instance();
    await BlocklistDao.setItemBlockStatusForNewInFeed(feedId, blockTime, s.applyBlocklistToSummaries,
      s.applyBlocklistToLinks);
  }

  /** 重算全部条目屏蔽状态（源 BlocklistUpdateJob 的默认分支，SS-A23/RP-A35） */
  async setItemBlockStatus(blockTime: number): Promise<void> {
    const s: SettingsStore = SettingsStore.instance();
    await BlocklistDao.setItemBlockStatus(blockTime, s.applyBlocklistToSummaries, s.applyBlocklistToLinks);
  }

  async getFeedItemCountRaw(feedId: number, tag: string, minReadTime: number, filter: FeedListFilter,
    search: string): Promise<number> {
    return await FeedItemDao.getFeedItemCountRaw(feedId, tag, minReadTime, filter, search);
  }

  /** 源 getFeedItemCountRaw: Flow<Int> */
  observeFeedItemCountRaw(feedId: number, tag: string, minReadTime: number, filter: FeedListFilter, search: string,
    cb: (count: number) => void): () => void {
    return FeedItemDao.observeFeedItemCountRaw(feedId, tag, minReadTime, filter, search, cb);
  }

  /** RP-A18：小组件列表（收藏/单源/标签/全部），最新优先、最多 50 条、不受过滤/排序影响 */
  async getWidgetFeedListItems(feedId: number, tag: string): Promise<FeedListItem[]> {
    return toListItems(await FeedItemDao.getWidgetPreviews(feedId, tag));
  }

  observeWidgetFeedListItems(feedId: number, tag: string, cb: (items: FeedListItem[]) => void): () => void {
    return FeedItemDao.observeWidgetPreviews(feedId, tag, (previews: PreviewItem[]) => {
      cb(toListItems(previews));
    });
  }

  /** 源 getPagedFeedItemsRaw（RP-A09..A14）。返回未启动的 PagedList */
  getPagedFeedItemsRaw(feedId: number, tag: string, minReadTime: number, newestFirst: boolean, filter: FeedListFilter,
    search: string, cb: PagedListCallback<FeedListItem>): PagedList<FeedListItem> {
    return new PagedList<FeedListItem>(async (limit: number, offset: number): Promise<FeedListItem[]> => {
      return toListItems(await FeedItemDao.getPreviewsRaw(feedId, tag, minReadTime, newestFirst, filter, search, limit,
        offset));
    }, LIST_TABLES, FEED_LIST_PAGING, cb);
  }

  /** 源 markAsReadRaw（RP-A28）：写后 DbNotifier 通知（由 DAO 完成）→ 列表刷新 */
  async markAsReadRaw(feedId: number, tag: string, filter: FeedListFilter, search: string, minReadTime: number,
    descending: boolean, cursor: FeedItemCursor): Promise<void> {
    await FeedItemDao.markAsReadRaw(feedId, tag, filter, search, minReadTime, descending, cursor);
  }

  async markAsNotified(itemIds: number[]): Promise<void> {
    if (itemIds.length === 0) {
      return;
    }
    await FeedItemDao.markAsNotified(itemIds);
  }

  async markAsRead(itemIds: number[]): Promise<void> {
    if (itemIds.length === 0) {
      return;
    }
    await FeedItemDao.markAsRead(itemIds);
  }

  /** read_time = coalesce(read_time, readTime)（保留已有），notified=1；readTime 不早于 EPOCH */
  async markAsReadAndNotified(itemId: number, readTime: number = Date.now()): Promise<void> {
    await FeedItemDao.markAsReadAndNotified(itemId, Math.max(readTime, EPOCH_MS));
  }

  async markAsReadAndNotifiedAndOverwriteReadTime(itemId: number, readTime: number): Promise<void> {
    await FeedItemDao.markAsReadAndNotifiedAndOverwriteReadTime(itemId, Math.max(readTime, EPOCH_MS));
  }

  async markAsUnread(itemId: number): Promise<void> {
    await FeedItemDao.markAsUnread(itemId);
  }

  async setBookmarked(itemId: number, bookmarked: boolean): Promise<void> {
    await FeedItemDao.setBookmarked(itemId, bookmarked);
  }

  async getFullTextByDefault(itemId: number): Promise<boolean> {
    const v: boolean | null = await FeedItemDao.getFullTextByDefault(itemId);
    return v !== null ? v : false;
  }

  observeFeedItem(itemId: number, cb: (item: FeedItemWithFeed | null) => void): () => void {
    return FeedItemDao.observeFeedItem(itemId, cb);
  }

  async getFeedItemId(feedUrl: string, articleGuid: string): Promise<number | null> {
    return await FeedItemDao.getItemWith(feedUrl, articleGuid);
  }

  async getLink(itemId: number): Promise<string | null> {
    return await FeedItemDao.getLink(itemId);
  }

  /** 条目所属源的 open_articles_with 原值 */
  async getArticleOpener(itemId: number): Promise<string | null> {
    return await FeedItemDao.getOpenArticleWith(itemId);
  }

  async markAllAsReadInFeed(feedId: number): Promise<void> {
    await FeedItemDao.markAllAsReadInFeed(feedId);
  }

  async markAllAsReadInTag(tag: string): Promise<void> {
    await FeedItemDao.markAllAsReadInTag(tag);
  }

  async markAllAsRead(): Promise<void> {
    await FeedItemDao.markAllAsRead();
  }

  observeFeedsItemsWithDefaultFullTextNeedingDownload(cb: (items: FeedItemIdWithLink[]) => void): () => void {
    return FeedItemDao.observeFeedsItemsWithDefaultFullTextNeedingDownload(cb);
  }

  async getFeedsItemsWithDefaultFullTextNeedingDownload(): Promise<FeedItemIdWithLink[]> {
    return await FeedItemDao.getFeedsItemsWithDefaultFullTextNeedingDownload();
  }

  async markAsFullTextDownloaded(feedItemId: number): Promise<void> {
    await FeedItemDao.markAsFullTextDownloaded(feedItemId);
  }

  observeFeedItemsNeedingNotifying(cb: (ids: number[]) => void): () => void {
    return FeedItemDao.observeFeedItemsNeedingNotifying(cb);
  }

  async getFeedItemsNeedingNotifying(): Promise<number[]> {
    return await FeedItemDao.getFeedItemsNeedingNotifying();
  }

  async loadFeedItem(guid: string, feedId: number): Promise<FeedItem | null> {
    return await FeedItemDao.loadFeedItem(guid, feedId);
  }

  async upsertFeedItems(itemsWithText: FeedItemWithText[], block: FeedItemTextBlock): Promise<void> {
    await FeedItemDao.upsertFeedItems(itemsWithText, block);
  }

  /** RP-A33：保留每源最新 keepCount 条，收藏永不清理 */
  async getItemsToBeCleanedFromFeed(feedId: number, keepCount: number): Promise<number[]> {
    return await FeedItemDao.getItemsToBeCleanedFromFeed(feedId, keepCount);
  }

  async deleteFeedItems(ids: number[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    await FeedItemDao.deleteFeedItems(ids);
  }

  async updateWordCountFull(id: number, wordCount: number): Promise<void> {
    await FeedItemDao.updateWordCountFull(id, wordCount);
  }

  async duplicateStoryExists(id: number, title: string, link: string | null): Promise<boolean> {
    return await FeedItemDao.duplicationExists(id, title, link);
  }

  async getArticle(id: number): Promise<FeedItemWithFeed | null> {
    return await FeedItemDao.getFeedItem(id);
  }
}
