/**
 * DbRows — ResultSet 行映射与实体 → ValuesBucket（源 Room 生成的 *_Impl 映射 + Converters 读取容错）。
 * 读取时：Instant 列 → Converters.instantFromLong；pub_date → Converters.dateTimeFromString；
 * URL 列 → Converters.urlFromString；image_url(条目) → ThumbnailImage.fromJson（DB-A11..A14）。
 */
import { relationalStore } from '@kit.ArkData';
import { Converters, DEFAULT_URL, EPOCH_MS, Feed, FeedTitle, FeedForSettings, FeedUnreadCount } from '../model/Feed';
import { FeedItem, FeedItemWithFeed, FeedItemIdWithLink, FeedItemForReadMark } from '../model/FeedItem';
import { PreviewItem } from '../model/Parsed';
import { ThumbnailImage } from '../model/Thumbnail';
import { ID_UNSET } from '../model/Enums';

export type RowMapper<T> = (rs: relationalStore.ResultSet) => T;

export function colIndex(rs: relationalStore.ResultSet, name: string): number {
  return rs.getColumnIndex(name);
}

export function colIsNull(rs: relationalStore.ResultSet, name: string): boolean {
  const i: number = rs.getColumnIndex(name);
  return i < 0 || rs.isColumnNull(i);
}

export function colStr(rs: relationalStore.ResultSet, name: string, def: string = ''): string {
  const i: number = rs.getColumnIndex(name);
  if (i < 0 || rs.isColumnNull(i)) {
    return def;
  }
  return rs.getString(i);
}

export function colStrOrNull(rs: relationalStore.ResultSet, name: string): string | null {
  const i: number = rs.getColumnIndex(name);
  if (i < 0 || rs.isColumnNull(i)) {
    return null;
  }
  return rs.getString(i);
}

export function colNum(rs: relationalStore.ResultSet, name: string, def: number = 0): number {
  const i: number = rs.getColumnIndex(name);
  if (i < 0 || rs.isColumnNull(i)) {
    return def;
  }
  return rs.getLong(i);
}

export function colNumOrNull(rs: relationalStore.ResultSet, name: string): number | null {
  const i: number = rs.getColumnIndex(name);
  if (i < 0 || rs.isColumnNull(i)) {
    return null;
  }
  return rs.getLong(i);
}

export function colBool(rs: relationalStore.ResultSet, name: string, def: boolean = false): boolean {
  const i: number = rs.getColumnIndex(name);
  if (i < 0 || rs.isColumnNull(i)) {
    return def;
  }
  return rs.getLong(i) !== 0;
}

/** Instant 列（NOT NULL）：异常值读为 EPOCH */
export function colInstant(rs: relationalStore.ResultSet, name: string): number {
  const v: number | null = Converters.instantFromLong(colNumOrNull(rs, name));
  return v === null ? EPOCH_MS : v;
}

export function colInstantOrNull(rs: relationalStore.ResultSet, name: string): number | null {
  return Converters.instantFromLong(colNumOrNull(rs, name));
}

/** URL 列（NOT NULL）：宽松解析 */
export function colUrl(rs: relationalStore.ResultSet, name: string): string {
  const v: string | null = Converters.urlFromString(colStrOrNull(rs, name));
  return v === null ? DEFAULT_URL : v;
}

export function colUrlOrNull(rs: relationalStore.ResultSet, name: string): string | null {
  return Converters.urlFromString(colStrOrNull(rs, name));
}

export function colPubDate(rs: relationalStore.ResultSet, name: string): string | null {
  return Converters.dateTimeFromString(colStrOrNull(rs, name));
}

export function colThumbnail(rs: relationalStore.ResultSet, name: string): ThumbnailImage | null {
  return Converters.thumbnailImageFromString(colStrOrNull(rs, name));
}

/** 读全部行并关闭 ResultSet */
export function readAll<T>(rs: relationalStore.ResultSet, mapper: RowMapper<T>): T[] {
  const out: T[] = [];
  try {
    while (rs.goToNextRow()) {
      out.push(mapper(rs));
    }
  } finally {
    rs.close();
  }
  return out;
}

/** 读首行（无行 → null）并关闭 */
export function readFirst<T>(rs: relationalStore.ResultSet, mapper: RowMapper<T>): T | null {
  try {
    if (rs.goToNextRow()) {
      return mapper(rs);
    }
    return null;
  } finally {
    rs.close();
  }
}

/** 读首行首列数值（无行或 NULL → null） */
export function readScalarNumber(rs: relationalStore.ResultSet): number | null {
  try {
    if (rs.goToNextRow() && !rs.isColumnNull(0)) {
      return rs.getLong(0);
    }
    return null;
  } finally {
    rs.close();
  }
}

/** 读首列全部字符串（NULL 行跳过，同 Room 对非空 List<String> 的读取结果差异，台账未登记） */
export function readStringColumn(rs: relationalStore.ResultSet): string[] {
  const out: string[] = [];
  try {
    while (rs.goToNextRow()) {
      if (!rs.isColumnNull(0)) {
        out.push(rs.getString(0));
      }
    }
  } finally {
    rs.close();
  }
  return out;
}

export function readNumberColumn(rs: relationalStore.ResultSet): number[] {
  const out: number[] = [];
  try {
    while (rs.goToNextRow()) {
      if (!rs.isColumnNull(0)) {
        out.push(rs.getLong(0));
      }
    }
  } finally {
    rs.close();
  }
  return out;
}

// ---------------------------------------------------------------- feeds

export const readFeed: RowMapper<Feed> = (rs: relationalStore.ResultSet): Feed => {
  const f: Feed = new Feed();
  f.id = colNum(rs, 'id', ID_UNSET);
  f.title = colStr(rs, 'title');
  f.customTitle = colStr(rs, 'custom_title');
  f.url = colUrl(rs, 'url');
  f.tag = colStr(rs, 'tag');
  f.notify = colBool(rs, 'notify');
  f.imageUrl = colUrlOrNull(rs, 'image_url');
  f.lastSync = colInstant(rs, 'last_sync');
  f.responseHash = colNum(rs, 'response_hash');
  f.fullTextByDefault = colBool(rs, 'fulltext_by_default');
  f.openArticlesWith = colStr(rs, 'open_articles_with');
  f.alternateId = colBool(rs, 'alternate_id');
  f.currentlySyncing = colBool(rs, 'currently_syncing');
  f.whenModified = colInstant(rs, 'when_modified');
  f.siteFetched = colInstant(rs, 'site_fetched');
  f.skipDuplicates = colBool(rs, 'skip_duplicates');
  f.retryAfter = colInstant(rs, 'retry_after');
  f.summarizeOnOpen = colBool(rs, 'summarize_on_open');
  f.fetchOgImages = colBool(rs, 'fetch_og_images');
  f.blockRules = colStr(rs, 'block_rules');
  f.allowRules = colStr(rs, 'allow_rules');
  return f;
};

/** Feed → 全列（不含 id） */
export function feedToValues(f: Feed): relationalStore.ValuesBucket {
  const v: relationalStore.ValuesBucket = {
    'title': f.title,
    'custom_title': f.customTitle,
    'url': f.url,
    'tag': f.tag,
    'notify': f.notify ? 1 : 0,
    'image_url': f.imageUrl,
    'last_sync': f.lastSync,
    'response_hash': f.responseHash,
    'fulltext_by_default': f.fullTextByDefault ? 1 : 0,
    'open_articles_with': f.openArticlesWith,
    'alternate_id': f.alternateId ? 1 : 0,
    'currently_syncing': f.currentlySyncing ? 1 : 0,
    'when_modified': f.whenModified,
    'site_fetched': f.siteFetched,
    'skip_duplicates': f.skipDuplicates ? 1 : 0,
    'retry_after': f.retryAfter,
    'summarize_on_open': f.summarizeOnOpen ? 1 : 0,
    'fetch_og_images': f.fetchOgImages ? 1 : 0,
    'block_rules': f.blockRules,
    'allow_rules': f.allowRules,
  };
  return v;
}

export const FEED_COLUMNS: string[] = [
  'title', 'custom_title', 'url', 'tag', 'notify', 'image_url', 'last_sync', 'response_hash',
  'fulltext_by_default', 'open_articles_with', 'alternate_id', 'currently_syncing', 'when_modified',
  'site_fetched', 'skip_duplicates', 'retry_after', 'summarize_on_open', 'fetch_og_images', 'block_rules',
  'allow_rules',
];

export const readFeedTitle: RowMapper<FeedTitle> = (rs: relationalStore.ResultSet): FeedTitle =>
new FeedTitle(colNum(rs, 'id', ID_UNSET), colStr(rs, 'title'), colStr(rs, 'custom_title'));

export const readFeedForSettings: RowMapper<FeedForSettings> = (rs: relationalStore.ResultSet): FeedForSettings =>
new FeedForSettings(colNum(rs, 'id', ID_UNSET), colStr(rs, 'title'), colBool(rs, 'notify'));

export const readFeedUnreadCount: RowMapper<FeedUnreadCount> = (rs: relationalStore.ResultSet): FeedUnreadCount => {
  const c: FeedUnreadCount = new FeedUnreadCount();
  c.id = colNum(rs, 'id', ID_UNSET);
  c.displayTitle = colStr(rs, 'display_title');
  c.tag = colStr(rs, 'tag');
  c.imageUrl = colUrlOrNull(rs, 'image_url');
  c.unreadCount = colNum(rs, 'unread_count');
  c.expanded = colBool(rs, 'expanded');
  return c;
};

// ---------------------------------------------------------------- feed_items

export const readFeedItem: RowMapper<FeedItem> = (rs: relationalStore.ResultSet): FeedItem => {
  const it: FeedItem = new FeedItem();
  it.id = colNum(rs, 'id', ID_UNSET);
  it.guid = colStr(rs, 'guid');
  it.title = colStr(rs, 'title');
  it.plainTitle = colStr(rs, 'plain_title');
  it.plainSnippet = colStr(rs, 'plain_snippet');
  it.thumbnailImage = colThumbnail(rs, 'image_url');
  it.imageFromBody = colBool(rs, 'image_from_body');
  it.enclosureLink = colStrOrNull(rs, 'enclosure_link');
  it.enclosureType = colStrOrNull(rs, 'enclosure_type');
  it.author = colStrOrNull(rs, 'author');
  it.pubDate = colPubDate(rs, 'pub_date');
  it.link = colStrOrNull(rs, 'link');
  it.oldUnread = colBool(rs, 'unread', true);
  it.notified = colBool(rs, 'notified');
  it.feedId = colNumOrNull(rs, 'feed_id');
  it.firstSyncedTime = colInstant(rs, 'first_synced_time');
  it.primarySortTime = colInstant(rs, 'primary_sort_time');
  it.oldPinned = colBool(rs, 'pinned');
  it.bookmarked = colBool(rs, 'bookmarked');
  it.fullTextDownloaded = colBool(rs, 'fulltext_downloaded');
  it.readTime = colInstantOrNull(rs, 'read_time');
  it.wordCount = colNum(rs, 'word_count');
  it.wordCountFull = colNum(rs, 'word_count_full');
  it.blockTime = colInstantOrNull(rs, 'block_time');
  return it;
};

/** FeedItem → 全列（不含 id） */
export function feedItemToValues(it: FeedItem): relationalStore.ValuesBucket {
  const v: relationalStore.ValuesBucket = {
    'guid': it.guid,
    'title': it.title,
    'plain_title': it.plainTitle,
    'plain_snippet': it.plainSnippet,
    'image_url': Converters.stringFromThumbnailImage(it.thumbnailImage),
    'image_from_body': it.imageFromBody ? 1 : 0,
    'enclosure_link': it.enclosureLink,
    'enclosure_type': it.enclosureType,
    'author': it.author,
    'pub_date': it.pubDate,
    'link': it.link,
    'unread': it.oldUnread ? 1 : 0,
    'notified': it.notified ? 1 : 0,
    'feed_id': it.feedId,
    'first_synced_time': it.firstSyncedTime,
    'primary_sort_time': it.primarySortTime,
    'pinned': it.oldPinned ? 1 : 0,
    'bookmarked': it.bookmarked ? 1 : 0,
    'fulltext_downloaded': it.fullTextDownloaded ? 1 : 0,
    'read_time': it.readTime,
    'word_count': it.wordCount,
    'word_count_full': it.wordCountFull,
    'block_time': it.blockTime,
  };
  return v;
}

export const FEED_ITEM_COLUMNS: string[] = [
  'guid', 'title', 'plain_title', 'plain_snippet', 'image_url', 'image_from_body', 'enclosure_link',
  'enclosure_type', 'author', 'pub_date', 'link', 'unread', 'notified', 'feed_id', 'first_synced_time',
  'primary_sort_time', 'pinned', 'bookmarked', 'fulltext_downloaded', 'read_time', 'word_count',
  'word_count_full', 'block_time',
];

/** 源 FEED_ITEM_COLUMNS_WITH_FEED（FeedItemWithFeed.kt），逐字 */
export const FEED_ITEM_COLUMNS_WITH_FEED: string = `
    feed_items.id AS id, guid, feed_items.title AS title,
    plain_title, plain_snippet, feed_items.image_url, enclosure_link, enclosure_type,
    author, pub_date, link, read_time, feeds.tag AS tag, feeds.id AS feed_id,
    feeds.title AS feed_title,
    feeds.custom_title AS feed_customtitle,
    feeds.url AS feed_url,
    feeds.fulltext_by_default AS fulltext_by_default,
    bookmarked,
    primary_sort_time,
    word_count,
    word_count_full
`;

export const readFeedItemWithFeed: RowMapper<FeedItemWithFeed> = (rs: relationalStore.ResultSet): FeedItemWithFeed => {
  const it: FeedItemWithFeed = new FeedItemWithFeed();
  it.id = colNum(rs, 'id', ID_UNSET);
  it.guid = colStr(rs, 'guid');
  it.title = colStr(rs, 'title');
  it.plainTitle = colStr(rs, 'plain_title');
  it.plainSnippet = colStr(rs, 'plain_snippet');
  it.thumbnailImage = colThumbnail(rs, 'image_url');
  it.enclosureLink = colStrOrNull(rs, 'enclosure_link');
  it.enclosureType = colStrOrNull(rs, 'enclosure_type');
  it.author = colStrOrNull(rs, 'author');
  it.pubDate = colPubDate(rs, 'pub_date');
  it.link = colStrOrNull(rs, 'link');
  it.tag = colStr(rs, 'tag');
  it.readTime = colInstantOrNull(rs, 'read_time');
  it.feedId = colNumOrNull(rs, 'feed_id');
  it.feedTitle = colStr(rs, 'feed_title');
  it.feedCustomTitle = colStr(rs, 'feed_customtitle');
  it.feedUrl = colUrl(rs, 'feed_url');
  it.fullTextByDefault = colBool(rs, 'fulltext_by_default');
  it.bookmarked = colBool(rs, 'bookmarked');
  it.primarySortTime = colInstant(rs, 'primary_sort_time');
  it.wordCount = colNum(rs, 'word_count');
  it.wordCountFull = colNum(rs, 'word_count_full');
  return it;
};

export const readPreviewItem: RowMapper<PreviewItem> = (rs: relationalStore.ResultSet): PreviewItem => {
  const p: PreviewItem = new PreviewItem();
  p.id = colNum(rs, 'id', ID_UNSET);
  p.guid = colStr(rs, 'guid');
  p.plainTitle = colStr(rs, 'plain_title');
  p.plainSnippet = colStr(rs, 'plain_snippet');
  p.image = colThumbnail(rs, 'image_url');
  p.enclosureLink = colStrOrNull(rs, 'enclosure_link');
  p.author = colStrOrNull(rs, 'author');
  p.pubDate = colPubDate(rs, 'pub_date');
  p.link = colStrOrNull(rs, 'link');
  p.tag = colStr(rs, 'tag');
  p.readTime = colInstantOrNull(rs, 'read_time');
  p.feedId = colNumOrNull(rs, 'feed_id');
  p.feedTitle = colStr(rs, 'feed_title');
  p.feedCustomTitle = colStr(rs, 'feed_customtitle');
  p.feedUrl = colUrl(rs, 'feed_url');
  p.feedOpenArticlesWith = colStr(rs, 'feed_open_articles_with');
  p.bookmarked = colBool(rs, 'bookmarked');
  p.feedImageUrl = colUrlOrNull(rs, 'feed_image_url');
  p.primarySortTime = colInstant(rs, 'primary_sort_time');
  p.wordCount = colNum(rs, 'word_count');
  p.wordCountFull = colNum(rs, 'word_count_full');
  p.fullTextByDefault = colBool(rs, 'fulltext_by_default');
  return p;
};

export const readFeedItemIdWithLink: RowMapper<FeedItemIdWithLink> = (rs: relationalStore.ResultSet): FeedItemIdWithLink =>
new FeedItemIdWithLink(colNum(rs, 'id', ID_UNSET), colStrOrNull(rs, 'link'));

export const readFeedItemForReadMark: RowMapper<FeedItemForReadMark> =
  (rs: relationalStore.ResultSet): FeedItemForReadMark => {
    const r: FeedItemForReadMark = new FeedItemForReadMark();
    r.id = colNum(rs, 'id', ID_UNSET);
    r.feedId = colNum(rs, 'feed_id', ID_UNSET);
    r.guid = colStr(rs, 'guid');
    r.feedUrl = colUrl(rs, 'feed_url');
    return r;
  };

/** `UPDATE t SET a = ?, b = ? ...` 片段 */
export function setClause(columns: string[]): string {
  return columns.map((c: string): string => `${c} = ?`).join(', ');
}

/** 按列序把 ValuesBucket 展开为参数数组 */
export function valuesInOrder(values: relationalStore.ValuesBucket, columns: string[]): relationalStore.ValueType[] {
  return columns.map((c: string): relationalStore.ValueType => {
    const v: relationalStore.ValueType | undefined = values[c];
    return v === undefined ? null : v;
  });
}
