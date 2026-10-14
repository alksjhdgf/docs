/**
 * FeedMapping.ets —— 源 model/FeedParser.kt 的解析入口与映射 + model/gofeed/GoFeedExtensions.kt 的 FeederGoItem。
 *
 * 入口：
 *  - parseFeed(body, url, contentType?)：≙ FeedParser.parseFeedResponse(Response)。请求 URL 先按 OkHttp HttpUrl 规整
 *    （scheme/host 小写、去默认端口、空路径补 "/"）；内容类型闸门：Content-Type 缺失/无法解析、主类型 text、
 *    子类型含 json 或 xml 时解析，否则 Left(UnsupportedContentType(mimeType = Content-Type 原串))。
 *  - parseFeedBody(url, body)：≙ parseFeedResponse(url: URL, body)（无闸门，URL 按 java.net.URL 原样）。
 *  - parseFeedHttpResponse(response)：body 为 null → Left(NoBody)；否则以 finalUrl 调 parseFeed。
 *  - parseFeedUrl(client, url)：抓取并解析，成功后 feed_url 覆盖为调用方原始 URL（保留 userinfo/query）。
 * 任何解析异常 → Left(RSSParseError(url, throwable))，不向上抛。
 * 非 feed 内容（如 HTML 页面）在格式探测阶段失败（根元素不是 rss/rdf/feed）→ RSSParseError；feed 发现（站点元数据）
 * 属 fnd-sync-engine。
 */
import { Either, Left } from '../util/Either';
import { JavaUri, JavaUrl } from '../util/JavaCompat';
import { relativeLinkIntoAbsolute } from '../util/LinkUtils';
import { plainContentOf, htmlToPlainText } from '../html/HtmlToPlainText';
import { ParsedArticle, ParsedAuthor, ParsedEnclosure, ParsedFeed } from '../model/Parsed';
import { ThumbnailImage } from '../model/Thumbnail';
import { HttpClient } from '../net/HttpClient';
import { HttpResponse, MediaType } from '../net/HttpMessages';
import { GoEnclosure, GoExtension, GoExtensions, GoFeed, GoItem, GoPerson, sortedKeys } from './GoFeed';
import { FeedXmlTokenizer } from './FeedXmlTokenizer';
import { decodeFeedBytes } from './FeedXmlText';
import { FeedParseException, findRoot } from './GoFeedShared';
import { parseRssFeed } from './XmlFeedParser';
import { parseAtomFeed } from './AtomFeedParser';
import { parseJsonFeed } from './JsonFeedParser';
import {
  bodyThumbnailOf,
  feedThumbnailOf,
  forEachExtension,
  kotlinToLongOrNull,
  nonNullEnclosures,
  selectThumbnail
} from './ThumbnailSelector';
import { curlAndOnResponse, FeedParserError, NoBody, RSSParseError, UnsupportedContentType } from './FeedParserError';

// ---------------------------------------------------------------- 格式探测与 GoFeed 解析

function isLeadingSkippable(c: number): boolean {
  // gofeed DetectFeedType：跳过空白与 BOM（0xFE 0xFF 0x00 0xEF 0xBB 0xBF）
  return c === 0x20 || c === 0x0D || c === 0x0A || c === 0x09 || c === 0xFEFF || c === 0xFE || c === 0xFF ||
    c === 0x00 || c === 0xEF || c === 0xBB || c === 0xBF;
}

/** ≙ gofeed Parser.Parse（经 gomobile 桥）：探测格式并解析为 GoFeed；失败抛 FeedParseException */
export function parseGoFeed(body: ArrayBuffer | string): GoFeed {
  const text: string = typeof body === 'string' ? body as string : decodeFeedBytes(body as ArrayBuffer);
  let i: number = 0;
  while (i < text.length && isLeadingSkippable(text.charCodeAt(i))) {
    i++;
  }
  const first: string = i < text.length ? text.charAt(i) : '';
  if (first === '<') {
    const tok: FeedXmlTokenizer = new FeedXmlTokenizer(text);
    const root: string = findRoot(tok);
    if (root === 'rss' || root === 'rdf') {
      return parseRssFeed(tok, root);
    }
    if (root === 'feed') {
      return parseAtomFeed(tok);
    }
  } else if (first === '{') {
    return parseJsonFeed(text.substring(i));
  }
  throw new FeedParseException('Failed to detect feed type');
}

// ---------------------------------------------------------------- FeederGoItem

function isNotBlank(s: string | null): boolean {
  return s !== null && s.trim().length > 0;
}

/** 源 recursiveExtensionMediaDescription：收集 name 等于 description（忽略大小写）的扩展 value（含子孙） */
function recursiveExtensionMediaDescription(extension: GoExtension, out: string[]): void {
  if (extension.name !== null && extension.name.toLowerCase() === 'description' && extension.value !== null) {
    out.push(extension.value);
  }
  const children: Map<string, GoExtension[]> | null = extension.children;
  if (children !== null) {
    const keys: string[] = sortedKeys<GoExtension[]>(children);
    for (let i = 0; i < keys.length; i++) {
      const list: GoExtension[] = children.get(keys[i]) as GoExtension[];
      for (let j = 0; j < list.length; j++) {
        recursiveExtensionMediaDescription(list[j], out);
      }
    }
  }
}

/** 源 FeederGoItem：条目字段派生（惰性缓存） */
export class FeederGoItem {
  readonly goItem: GoItem;
  readonly feedAuthor: GoPerson | null;
  readonly feedBaseUrl: JavaUrl;
  private contentCache: string | null = null;
  private plainCache: string | null = null;
  private linkComputed: boolean = false;
  private linkCache: string | null = null;
  private feedThumbComputed: boolean = false;
  private feedThumbCache: ThumbnailImage | null = null;
  private thumbComputed: boolean = false;
  private thumbCache: ThumbnailImage | null = null;

  constructor(goItem: GoItem, feedAuthor: GoPerson | null, feedBaseUrl: JavaUrl) {
    this.goItem = goItem;
    this.feedAuthor = feedAuthor;
    this.feedBaseUrl = feedBaseUrl;
  }

  /** 标题经 HtmlToPlainTextConverter；源 title 为 null 则 null */
  get title(): string | null {
    return this.goItem.title !== null ? htmlToPlainText(this.goItem.title) : null;
  }

  /** content（可能含 HTML）：content → description → 扩展树中第一个 description 值 → "" */
  get content(): string {
    if (this.contentCache === null) {
      let result: string | null = null;
      if (isNotBlank(this.goItem.content)) {
        result = this.goItem.content;
      } else if (isNotBlank(this.goItem.description)) {
        result = this.goItem.description;
      } else {
        const found: string[] = [];
        forEachExtension(this.goItem.extensions, (e: GoExtension): void => {
          recursiveExtensionMediaDescription(e, found);
        });
        if (found.length > 0) {
          result = found[0];
        }
      }
      this.contentCache = result !== null ? result : '';
    }
    return this.contentCache;
  }

  get plainContent(): string {
    if (this.plainCache === null) {
      this.plainCache = plainContentOf(this.content);
    }
    return this.plainCache;
  }

  /** plainContent.take(200)（UTF-16 code unit） */
  get snippet(): string {
    return this.plainContent.substring(0, 200);
  }

  /** link；为 null 时仅当 guid 为可严格解析的绝对 http/https URI 才回退 guid；再按 feed URL 绝对化 */
  get link(): string | null {
    if (!this.linkComputed) {
      let rawLink: string | null = this.goItem.link;
      if (rawLink === null && this.goItem.guid !== null) {
        const guid: string = this.goItem.guid;
        let ok: boolean = false;
        try {
          const uri: JavaUri = JavaUri.parse(guid);
          ok = uri.isAbsolute() && (uri.scheme === 'http' || uri.scheme === 'https');
        } catch (e) {
          ok = false;
        }
        rawLink = ok ? guid : null;
      }
      this.linkCache = rawLink !== null ? relativeLinkIntoAbsolute(this.feedBaseUrl, rawLink) : null;
      this.linkComputed = true;
    }
    return this.linkCache;
  }

  get updated(): string | null {
    return this.goItem.updatedParsed;
  }

  get published(): string | null {
    return this.goItem.publishedParsed;
  }

  get author(): GoPerson | null {
    return this.goItem.author !== null ? this.goItem.author : this.feedAuthor;
  }

  /** (guid ?: link) 按 feed URL 绝对化（非法原样） */
  get guid(): string | null {
    const raw: string | null = this.goItem.guid !== null ? this.goItem.guid : this.goItem.link;
    return raw !== null ? relativeLinkIntoAbsolute(this.feedBaseUrl, raw) : null;
  }

  get categories(): string[] | null {
    return this.goItem.categories;
  }

  get enclosures(): GoEnclosure[] | null {
    return nonNullEnclosures(this.goItem);
  }

  get extensions(): GoExtensions | null {
    return this.goItem.extensions;
  }

  get feedThumbnail(): ThumbnailImage | null {
    if (!this.feedThumbComputed) {
      this.feedThumbCache = feedThumbnailOf(this.goItem, this.feedBaseUrl);
      this.feedThumbComputed = true;
    }
    return this.feedThumbCache;
  }

  get bodyThumbnail(): ThumbnailImage | null {
    return bodyThumbnailOf(this.content, this.feedBaseUrl, this.link);
  }

  get thumbnail(): ThumbnailImage | null {
    if (!this.thumbComputed) {
      this.thumbCache = selectThumbnail(this.feedThumbnail, (): ThumbnailImage | null => this.bodyThumbnail);
      this.thumbComputed = true;
    }
    return this.thumbCache;
  }
}

// ---------------------------------------------------------------- 映射

function asParsedAuthor(p: GoPerson): ParsedAuthor {
  return new ParsedAuthor(p.name, null, null);
}

function asParsedEnclosure(e: GoEnclosure): ParsedEnclosure {
  return new ParsedEnclosure(e.url, e.type, null, e.length !== null ? kotlinToLongOrNull(e.length) : null, null);
}

/** 源 FeederGoItem.asParsedArticle */
export function asParsedArticle(item: FeederGoItem): ParsedArticle {
  const a: ParsedArticle = new ParsedArticle(item.guid);
  a.url = item.link;
  a.external_url = null;
  a.title = item.title;
  a.content_html = item.content;
  a.content_text = item.plainContent;
  a.summary = item.snippet;
  const thumb: ThumbnailImage | null = item.thumbnail;
  a.image = thumb;
  a.date_published = item.published;
  a.date_modified = item.updated;
  const author: GoPerson | null = item.author;
  a.author = author !== null ? asParsedAuthor(author) : null;
  a.tags = item.categories;
  const encs: GoEnclosure[] | null = item.enclosures;
  a.attachments = encs !== null ? encs.map((e: GoEnclosure): ParsedEnclosure => asParsedEnclosure(e)) : null;
  a.hasFeedImage = thumb !== null && thumb.fromBody === false;
  return a;
}

/** 源 GoFeed.asFeed(url)：feed_url 恒为请求 URL（绝不采用 feed 内 self/feedLink） */
export function goFeedAsFeed(feed: GoFeed, url: JavaUrl): ParsedFeed {
  const pf: ParsedFeed = new ParsedFeed(feed.title, null);
  pf.home_page_url = feed.link !== null ? relativeLinkIntoAbsolute(url, feed.link) : null;
  // NEVER set the feed url to the feedLink in the feed. While the specs all say this is what should be done,
  // a huge amount of feeds are just misconfigured and the selfLink is not valid.
  pf.feed_url = url.toString();
  pf.description = feed.description;
  pf.user_comment = '';
  pf.next_url = '';
  pf.icon = feed.image !== null && feed.image.url !== null ? relativeLinkIntoAbsolute(url, feed.image.url) : null;
  pf.favicon = null;
  pf.author = feed.author !== null ? asParsedAuthor(feed.author) : null;
  pf.expired = null;
  if (feed.items !== null) {
    const items: ParsedArticle[] = [];
    for (let i = 0; i < feed.items.length; i++) {
      const it: GoItem | null = feed.items[i];
      if (it !== null) {
        items.push(asParsedArticle(new FeederGoItem(it, feed.author, url)));
      }
    }
    pf.items = items;
  }
  return pf;
}

/** ParsedFeed.copy() */
export function copyParsedFeed(f: ParsedFeed): ParsedFeed {
  const c: ParsedFeed = new ParsedFeed(f.title, f.items);
  c.home_page_url = f.home_page_url;
  c.feed_url = f.feed_url;
  c.description = f.description;
  c.user_comment = f.user_comment;
  c.next_url = f.next_url;
  c.icon = f.icon;
  c.favicon = f.favicon;
  c.author = f.author;
  c.expired = f.expired;
  return c;
}

// ---------------------------------------------------------------- 入口

function javaUrlString(url: string): string {
  try {
    return JavaUrl.parse(url).toString();
  } catch (e) {
    return url;
  }
}

/**
 * OkHttp HttpUrl.toString 的主要规整（近似）：scheme 与 host 小写、去掉默认端口、空路径补 "/"。
 * 不做百分号编码规范化；无法识别的串原样返回。
 */
export function okHttpCanonicalUrl(url: string): string {
  const m: RegExpMatchArray | null = url.trim().match(new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*)://([^/?#]*)(.*)$'));
  if (m === null) {
    return url;
  }
  const scheme: string = m[1].toLowerCase();
  let authority: string = m[2];
  let rest: string = m[3];
  let userInfo: string = '';
  const at: number = authority.lastIndexOf('@');
  if (at >= 0) {
    userInfo = authority.substring(0, at + 1);
    authority = authority.substring(at + 1);
  }
  let host: string = authority;
  let port: string = '';
  if (authority.startsWith('[')) {
    const close: number = authority.indexOf(']');
    if (close > 0) {
      host = authority.substring(0, close + 1);
      const after: string = authority.substring(close + 1);
      port = after.startsWith(':') ? after.substring(1) : '';
    }
  } else {
    const colon: number = authority.lastIndexOf(':');
    if (colon >= 0) {
      host = authority.substring(0, colon);
      port = authority.substring(colon + 1);
    }
  }
  host = host.toLowerCase();
  if ((scheme === 'http' && port === '80') || (scheme === 'https' && port === '443')) {
    port = '';
  }
  if (rest.length === 0 || rest.startsWith('?') || rest.startsWith('#')) {
    rest = '/' + rest;
  }
  return `${scheme}://${userInfo}${host}${port !== '' ? ':' + port : ''}${rest}`;
}

/** ≙ parseFeedResponse(url: URL, body)：解析异常/空结果 → Left(RSSParseError)，不向上抛 */
export function parseFeedBody(url: string, body: ArrayBuffer | string): Either<FeedParserError, ParsedFeed> {
  const urlString: string = javaUrlString(url);
  return Either.catching<FeedParserError, ParsedFeed>(
    (t: Error): FeedParserError => new RSSParseError(t, urlString),
    (): ParsedFeed => {
      const base: JavaUrl = JavaUrl.parse(url);
      const goFeed: GoFeed = parseGoFeed(body);
      return goFeedAsFeed(goFeed, base);
    });
}

/**
 * 源 parseFeedResponse(Response) 的入口（spec 签名 parseFeed(body, url, contentType?)）：
 * url 为响应的请求 URL（重定向后），contentType 为响应 Content-Type（缺省/null 视为无）。
 */
export function parseFeed(body: ArrayBuffer | string, url: string,
  contentType?: string | null): Either<FeedParserError, ParsedFeed> {
  const requestUrl: string = okHttpCanonicalUrl(url);
  const mt: MediaType | null = MediaType.parse(contentType !== undefined ? contentType : null);
  const subType: string = mt !== null ? mt.subtype : '';
  if (mt === null || mt.type === 'text' || subType.indexOf('json') >= 0 || subType.indexOf('xml') >= 0) {
    return parseFeedBody(requestUrl, body);
  }
  return new Left<FeedParserError, ParsedFeed>(new UnsupportedContentType(javaUrlString(requestUrl), mt.toString()));
}

/** 源 parseFeedResponse(response)：body 为 null → Left(NoBody) */
export function parseFeedHttpResponse(response: HttpResponse): Either<FeedParserError, ParsedFeed> {
  const url: string = response.finalUrl.length > 0 ? response.finalUrl : response.request.url;
  if (response.body === null) {
    return new Left<FeedParserError, ParsedFeed>(new NoBody(okHttpCanonicalUrl(url)));
  }
  return parseFeed(response.body, url, response.header('content-type'));
}

/**
 * 源 FeedParser.parseFeedUrl：抓取并解析；成功后 feed_url 覆盖为调用方原始 URL
 * （Preserve original URL to maintain authentication data and/or tokens in query params）。
 */
export async function parseFeedUrl(client: HttpClient, url: string): Promise<Either<FeedParserError, ParsedFeed>> {
  const result: Either<FeedParserError, ParsedFeed> = await curlAndOnResponse<ParsedFeed>(client, url,
    async (response: HttpResponse): Promise<Either<FeedParserError, ParsedFeed>> => parseFeedHttpResponse(response));
  const original: string = javaUrlString(url);
  return result.map<ParsedFeed>((f: ParsedFeed): ParsedFeed => {
    const c: ParsedFeed = copyParsedFeed(f);
    c.feed_url = original;
    return c;
  });
}
