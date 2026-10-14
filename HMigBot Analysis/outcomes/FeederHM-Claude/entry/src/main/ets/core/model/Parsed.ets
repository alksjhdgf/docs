/**
 * 解析结果模型（源 model/ParsedFeed.kt、ParsedArticle.kt、ParsedEnclosure.kt、ParsedAuthor.kt、SiteMetaData.kt、
 * PreviewItem.kt）。字段名照源 JSON-Feed 风格（snake_case）保留。
 */
import { ID_UNSET } from './Enums';
import { ThumbnailImage } from './Thumbnail';
import { DEFAULT_URL, EPOCH_MS, JavaUrl, isBlankString } from './Feed';

export class ParsedAuthor {
  name: string | null = null;
  url: string | null = null;
  avatar: string | null = null;

  constructor(name: string | null = null, url: string | null = null, avatar: string | null = null) {
    this.name = name;
    this.url = url;
    this.avatar = avatar;
  }
}

export class ParsedEnclosure {
  url: string | null = null;
  mime_type: string | null = null;
  title: string | null = null;
  size_in_bytes: number | null = null;
  duration_in_seconds: number | null = null;

  constructor(url: string | null, mime_type: string | null = null, title: string | null = null,
    size_in_bytes: number | null = null, duration_in_seconds: number | null = null) {
    this.url = url;
    this.mime_type = mime_type;
    this.title = title;
    this.size_in_bytes = size_in_bytes;
    this.duration_in_seconds = duration_in_seconds;
  }
}

/** 源 ParsedArticle（data class，全部可选字段默认 null；构造后逐字段赋值） */
export class ParsedArticle {
  id: string | null = null;
  url: string | null = null;
  external_url: string | null = null;
  title: string | null = null;
  content_html: string | null = null;
  content_text: string | null = null;
  summary: string | null = null;
  image: ThumbnailImage | null = null;
  date_published: string | null = null;
  date_modified: string | null = null;
  author: ParsedAuthor | null = null;
  tags: string[] | null = null;
  attachments: ParsedEnclosure[] | null = null;
  hasFeedImage: boolean = false;

  constructor(id: string | null = null) {
    this.id = id;
  }
}

/** 源 ParsedFeed */
export class ParsedFeed {
  title: string | null = null;
  home_page_url: string | null = null;
  feed_url: string | null = null;
  description: string | null = null;
  user_comment: string | null = null;
  next_url: string | null = null;
  icon: string | null = null;
  favicon: string | null = null;
  author: ParsedAuthor | null = null;
  expired: boolean | null = null;
  items: ParsedArticle[] | null = null;

  constructor(title: string | null = null, items: ParsedArticle[] | null = null) {
    this.title = title;
    this.items = items;
  }
}

/** 源 AlternateLink */
export class AlternateLink {
  /** java.net.URL → string */
  link: string = DEFAULT_URL;
  type: string = '';

  constructor(link: string, type: string) {
    this.link = link;
    this.type = type;
  }
}

/** 源 SiteMetaData */
export class SiteMetaData {
  /** java.net.URL → string */
  url: string = DEFAULT_URL;
  alternateFeedLinks: AlternateLink[] = [];
  feedImage: string | null = null;

  constructor(url: string, alternateFeedLinks: AlternateLink[], feedImage: string | null) {
    this.url = url;
    this.alternateFeedLinks = alternateFeedLinks;
    this.feedImage = feedImage;
  }
}

/** 源 PREVIEW_COLUMNS（model/PreviewItem.kt:19-26），逐字 */
export const PREVIEW_COLUMNS: string = `
    feed_items.id AS id, guid, plain_title, plain_snippet, feed_items.image_url, enclosure_link,
    author, pub_date, link, read_time, feeds.tag AS tag, feeds.id AS feed_id, feeds.title AS feed_title,
    feeds.custom_title as feed_customtitle, feeds.url AS feed_url,
    feeds.open_articles_with AS feed_open_articles_with, bookmarked,
    feeds.image_url as feed_image_url, primary_sort_time, word_count, word_count_full,
    feeds.fulltext_by_default as fulltext_by_default
`;

/** 源 PreviewItem（列表预览投影） */
export class PreviewItem {
  id: number = ID_UNSET;
  guid: string = '';
  plainTitle: string = '';
  plainSnippet: string = '';
  /** 列 image_url */
  image: ThumbnailImage | null = null;
  enclosureLink: string | null = null;
  author: string | null = null;
  /** 列 pub_date（ZonedDateTime.toString() 串） */
  pubDate: string | null = null;
  link: string | null = null;
  tag: string = '';
  /** epoch ms */
  readTime: number | null = null;
  feedId: number | null = null;
  feedTitle: string = '';
  feedCustomTitle: string = '';
  feedUrl: string = DEFAULT_URL;
  feedOpenArticlesWith: string = '';
  bookmarked: boolean = false;
  feedImageUrl: string | null = null;
  /** epoch ms */
  primarySortTime: number = EPOCH_MS;
  wordCount: number = 0;
  wordCountFull: number = 0;
  fullTextByDefault: boolean = false;

  get feedDisplayTitle(): string {
    return isBlankString(this.feedCustomTitle) ? this.feedTitle : this.feedCustomTitle;
  }

  get domain(): string | null {
    return linkHost(this.enclosureLink !== null ? this.enclosureLink : this.link);
  }

  get bestWordCount(): number {
    return this.fullTextByDefault ? this.wordCountFull : this.wordCount;
  }
}

/**
 * 源 `String?.host()`：java.net.URI(l).host，异常或无 host 返回 null。
 * 近似 java.net.URI：服务器型 authority 才有 host（含 '_' 等非法主机名字符时 host 为 null）；不做大小写规整。
 */
export function linkHost(link: string | null): string | null {
  if (link === null || !JavaUrl.looksLikeValidUri(link)) {
    return null;
  }
  const re: RegExp = new RegExp('^(?:[a-zA-Z][a-zA-Z0-9+.\\-]*:)?//([^/?#]*)');
  const m: RegExpMatchArray | null = link.match(re);
  if (m === null) {
    return null;
  }
  let authority: string = m[1];
  const at: number = authority.lastIndexOf('@');
  if (at >= 0) {
    authority = authority.substring(at + 1);
  }
  if (authority.startsWith('[')) {
    const close: number = authority.indexOf(']');
    if (close < 0) {
      return null;
    }
    return authority.substring(0, close + 1);
  }
  const colon: number = authority.lastIndexOf(':');
  const hostPart: string = colon >= 0 ? authority.substring(0, colon) : authority;
  if (colon >= 0) {
    const port: string = authority.substring(colon + 1);
    if (!new RegExp('^[0-9]*$').test(port)) {
      return null;
    }
  }
  if (hostPart.length === 0) {
    return null;
  }
  const ipv4: RegExp = new RegExp('^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$');
  if (ipv4.test(hostPart)) {
    return hostPart;
  }
  const hostname: RegExp = new RegExp(
    '^(?:[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?\\.)*[A-Za-z](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?\\.?$');
  if (!hostname.test(hostPart)) {
    return null;
  }
  return hostPart;
}
