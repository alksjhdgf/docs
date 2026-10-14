/**
 * 文章条目模型（源 db/room/FeedItem.kt、FeedItemWithFeed.kt、FeedItemIdWithLink.kt、FeedItemForReadMark.kt、
 * ui/compose/feed/FeedItemCompact.kt 的 FeedListItem）。
 *
 * 时间：Instant → epoch ms number；pubDate(ZonedDateTime) → Java `ZonedDateTime.toString()` 串（见 JavaTime）。
 */
import { ID_UNSET, FeedItemStyle } from './Enums';
import { ThumbnailImage, ThumbnailImagePolicy } from './Thumbnail';
import { ParsedArticle, ParsedEnclosure, ParsedFeed, linkHost } from './Parsed';
import { DEFAULT_URL, EPOCH_MS, JavaTime, JavaUrl, ZonedDateTimeValue, isBlankString } from './Feed';

export const MAX_TITLE_LENGTH: number = 200;
export const MAX_SNIPPET_LENGTH: number = 200;

/** 源 HtmlLinearizer.MAX_CHARS（estimateWordCount 截断上限） */
export const WORD_COUNT_MAX_CHARS: number = 100000;

/** 源 FeedItemForFetching */
export interface FeedItemForFetching {
  id: number;
  link: string | null;
}

/** 键集游标（排序键 primary_sort_time, pub_date, id） */
export interface FeedItemCursor {
  /** epoch ms */
  primarySortTime: number;
  /** ZonedDateTime.toString() 串 */
  pubDate: string | null;
  id: number;
}

/** 源 ReadStatusFeedItem */
export interface ReadStatusFeedItem {
  id: number;
  feedId: number;
  guid: string;
  feedUrl: string;
}

/** HTML/文本 → 纯文本转换（源 HtmlToPlainTextConverter.convert；由 core/html 提供） */
export type PlainTextConverter = (html: string) => string;

/** Kotlin String.take(n)（按 UTF-16 单元） */
function take(s: string, n: number): string {
  return s.length <= n ? s : s.substring(0, n);
}

/** 源 enclosureFilename：URI(link).path 最后一段，空则 null */
export function enclosureFilenameOf(enclosureLink: string | null): string | null {
  if (enclosureLink === null) {
    return null;
  }
  // java.net.URI 解析失败 → 异常 → null
  if (!JavaUrl.looksLikeValidUri(enclosureLink)) {
    return null;
  }
  let fname: string | null = null;
  try {
    let path: string = enclosureLink;
    const schemeRe: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:');
    if (schemeRe.test(path)) {
      path = path.replace(schemeRe, '');
      if (!path.startsWith('/')) {
        // 不透明 URI（如 mailto:x）path 为 null → NPE → null
        return null;
      }
      if (path.startsWith('//')) {
        const slash: number = path.indexOf('/', 2);
        path = slash < 0 ? '' : path.substring(slash);
      }
    }
    const q: number = path.search(new RegExp('[?#]'));
    if (q >= 0) {
      path = path.substring(0, q);
    }
    const parts: string[] = path.split('/');
    fname = decodeURIComponent(parts[parts.length - 1]);
  } catch (e) {
    fname = null;
  }
  if (fname === null || fname.length === 0) {
    return null;
  }
  return fname;
}

/**
 * If language doesn't use spaces, then this function will try to return 0
 * This takes the max chars in HtmlLinearizer into account.
 */
export function estimateWordCount(plainText: string): number {
  const truncated: string = take(plainText, WORD_COUNT_MAX_CHARS);
  const charCount: number = truncated.length;
  // 源 db/room/FeedItem.kt:47 `"\s+".toRegex()` + :228 splitToSequence(...).count()：
  // java.util.regex 的 \s 未开 UNICODE_CHARACTER_CLASS 时仅 [ \t\n\x0B\f\r]，
  // U+3000/NBSP 等 Unicode 空白不算分隔（JS \s 会算，故显式字符类）。空串也计 1 段。
  const wordCount: number = truncated.split(new RegExp('[ \\t\\n\\u000B\\f\\r]+')).length;
  return charCount / wordCount < 15.0 ? wordCount : 0;
}

export class FeedItem implements FeedItemForFetching, FeedItemCursor {
  id: number = ID_UNSET;
  guid: string = '';
  /** @deprecated This is never different from plainTitle（列 title） */
  title: string = '';
  plainTitle: string = '';
  plainSnippet: string = '';
  /** 列 image_url */
  thumbnailImage: ThumbnailImage | null = null;
  /** @deprecated 列 image_from_body（SQLite 无法 drop column） */
  imageFromBody: boolean = false;
  enclosureLink: string | null = null;
  enclosureType: string | null = null;
  author: string | null = null;
  /** 列 pub_date（TEXT，ZonedDateTime.toString()） */
  pubDate: string | null = null;
  link: string | null = null;
  /** @deprecated 列 unread（被 readTime 取代） */
  oldUnread: boolean = true;
  notified: boolean = false;
  feedId: number | null = null;
  /** epoch ms */
  firstSyncedTime: number = EPOCH_MS;
  /** epoch ms */
  primarySortTime: number = EPOCH_MS;
  /** @deprecated 列 pinned */
  oldPinned: boolean = false;
  bookmarked: boolean = false;
  fullTextDownloaded: boolean = false;
  /** epoch ms */
  readTime: number | null = null;
  wordCount: number = 0;
  wordCountFull: number = 0;
  /** epoch ms */
  blockTime: number | null = null;

  get unread(): boolean {
    return this.readTime === null;
  }

  get enclosureFilename(): string | null {
    return enclosureFilenameOf(this.enclosureLink);
  }

  get domain(): string | null {
    return linkHost(this.enclosureLink !== null ? this.enclosureLink : this.link);
  }

  /**
   * 源 updateFromParsedEntry。
   * @param toPlainText 源内部 `HtmlToPlainTextConverter().convert`，由调用方传入（core/html 提供）
   * @param nowMs 源 `clock`（默认 Clock.systemUTC()）
   */
  updateFromParsedEntry(entry: ParsedArticle, entryGuid: string, feed: ParsedFeed, toPlainText: PlainTextConverter,
    nowMs: number = Date.now()): void {
    const html: string = entry.content_html !== null ? entry.content_html :
      (entry.content_text !== null ? entry.content_text : '');
    const plainText: string = toPlainText(html);
    this.wordCount = estimateWordCount(plainText);

    const summarySrc: string = entry.summary !== null ? entry.summary :
      (entry.content_text !== null ? entry.content_text : plainText);
    const summary: string = take(summarySrc, MAX_SNIPPET_LENGTH);

    this.guid = entryGuid;
    if (entry.title !== null) {
      this.plainTitle = take(entry.title, MAX_TITLE_LENGTH);
    }
    this.title = this.plainTitle;
    this.plainSnippet = summary;

    this.thumbnailImage = ThumbnailImagePolicy.applyParsedEntryImage(this.thumbnailImage, entry.image);
    const attachments: ParsedEnclosure[] | null = entry.attachments;
    const firstEnclosure: ParsedEnclosure | null =
      attachments !== null && attachments.length > 0 ? attachments[0] : null;
    this.enclosureLink = firstEnclosure !== null ? firstEnclosure.url : null;
    const mime: string | null = firstEnclosure !== null ? firstEnclosure.mime_type : null;
    this.enclosureType = mime !== null ? mime.toLowerCase() : null;

    const entryAuthorName: string | null = entry.author !== null ? entry.author.name : null;
    const feedAuthorName: string | null = feed.author !== null ? feed.author.name : null;
    this.author = entryAuthorName !== null ? entryAuthorName : feedAuthorName;
    this.link = entry.url;

    const parsed: ZonedDateTimeValue | null = JavaTime.parseZoned(entry.date_published);
    if (parsed !== null) {
      // Allow an actual pubdate to be updated
      this.pubDate = parsed.iso;
    } else if (this.pubDate === null) {
      // If a pubdate is missing, then don't update if one is already set
      this.pubDate = JavaTime.nowUtcIso(nowMs);
    }
    const pub: ZonedDateTimeValue | null = JavaTime.parseZoned(this.pubDate);
    const pubMs: number = pub !== null ? pub.epochMs : this.firstSyncedTime;
    this.primarySortTime = Math.min(this.firstSyncedTime, pubMs);
  }

  /** Kotlin data class copy() */
  copy(): FeedItem {
    const c: FeedItem = new FeedItem();
    c.id = this.id;
    c.guid = this.guid;
    c.title = this.title;
    c.plainTitle = this.plainTitle;
    c.plainSnippet = this.plainSnippet;
    c.thumbnailImage = this.thumbnailImage;
    c.imageFromBody = this.imageFromBody;
    c.enclosureLink = this.enclosureLink;
    c.enclosureType = this.enclosureType;
    c.author = this.author;
    c.pubDate = this.pubDate;
    c.link = this.link;
    c.oldUnread = this.oldUnread;
    c.notified = this.notified;
    c.feedId = this.feedId;
    c.firstSyncedTime = this.firstSyncedTime;
    c.primarySortTime = this.primarySortTime;
    c.oldPinned = this.oldPinned;
    c.bookmarked = this.bookmarked;
    c.fullTextDownloaded = this.fullTextDownloaded;
    c.readTime = this.readTime;
    c.wordCount = this.wordCount;
    c.wordCountFull = this.wordCountFull;
    c.blockTime = this.blockTime;
    return c;
  }
}

/** 源 FeedItemWithFeed（FEED_ITEM_COLUMNS_WITH_FEED 投影） */
export class FeedItemWithFeed implements FeedItemForFetching {
  id: number = ID_UNSET;
  guid: string = '';
  /** @deprecated This is never different from plainTitle */
  title: string = '';
  plainTitle: string = '';
  plainSnippet: string = '';
  thumbnailImage: ThumbnailImage | null = null;
  enclosureLink: string | null = null;
  enclosureType: string | null = null;
  author: string | null = null;
  pubDate: string | null = null;
  link: string | null = null;
  tag: string = '';
  /** epoch ms */
  readTime: number | null = null;
  feedId: number | null = null;
  feedTitle: string = '';
  feedCustomTitle: string = '';
  /** 源默认 sloppyLinkToStrictURLNoThrows("") = "http://" */
  feedUrl: string = DEFAULT_URL;
  fullTextByDefault: boolean = false;
  bookmarked: boolean = false;
  /** epoch ms */
  primarySortTime: number = EPOCH_MS;
  wordCount: number = 0;
  wordCountFull: number = 0;

  get feedDisplayTitle(): string {
    return isBlankString(this.feedCustomTitle) ? this.feedTitle : this.feedCustomTitle;
  }

  get enclosureFilename(): string | null {
    return enclosureFilenameOf(this.enclosureLink);
  }

  get domain(): string | null {
    return linkHost(this.enclosureLink !== null ? this.enclosureLink : this.link);
  }
}

/** 源 FeedItemIdWithLink */
export class FeedItemIdWithLink implements FeedItemForFetching {
  id: number = ID_UNSET;
  link: string | null = null;

  constructor(id: number = ID_UNSET, link: string | null = null) {
    this.id = id;
    this.link = link;
  }
}

/** 源 FeedItemForReadMark */
export class FeedItemForReadMark implements ReadStatusFeedItem {
  id: number = ID_UNSET;
  feedId: number = ID_UNSET;
  guid: string = '';
  feedUrl: string = DEFAULT_URL;
}

/** 源 ui/compose/feed/FeedItemCompact.kt FeedListItem（列表项 UI 模型，不可变） */
export class FeedListItem {
  readonly id: number;
  readonly title: string;
  readonly snippet: string;
  readonly feedTitle: string;
  readonly unread: boolean;
  /** 已格式化的显示日期 */
  readonly pubDate: string;
  readonly image: ThumbnailImage | null;
  readonly link: string | null;
  readonly bookmarked: boolean;
  readonly feedImageUrl: string | null;
  /** epoch ms */
  readonly primarySortTime: number;
  /** 原始 pub_date（ZonedDateTime.toString() 串） */
  readonly rawPubDate: string | null;
  readonly wordCount: number;

  constructor(id: number, title: string, snippet: string, feedTitle: string, unread: boolean, pubDate: string,
    image: ThumbnailImage | null, link: string | null, bookmarked: boolean, feedImageUrl: string | null,
    primarySortTime: number, rawPubDate: string | null, wordCount: number) {
    this.id = id;
    this.title = title;
    this.snippet = snippet;
    this.feedTitle = feedTitle;
    this.unread = unread;
    this.pubDate = pubDate;
    this.image = image;
    this.link = link;
    this.bookmarked = bookmarked;
    this.feedImageUrl = feedImageUrl;
    this.primarySortTime = primarySortTime;
    this.rawPubDate = rawPubDate;
    this.wordCount = wordCount;
  }

  get cursor(): FeedItemCursor {
    const c: FeedItemCursor = {
      primarySortTime: this.primarySortTime,
      pubDate: this.rawPubDate,
      id: this.id,
    };
    return c;
  }

  /** Used so lazylist/grid can re-use items. Type will depend on having images. */
  contentType(feedItemStyle: FeedItemStyle): string {
    return this.image !== null ? `${feedItemStyle.toString()}/image` : `${feedItemStyle.toString()}/other`;
  }
}
