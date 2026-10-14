/**
 * FeedFetcher.ets —— 源 model/FeedParser.kt 的抓取部分（站点元数据/feed 发现）+ RssLocalSync.syncFeed 的 HTTP 获取。
 *
 * - fetchFeed(url, forceNetwork)：getResponse（forceNetwork → max-age=60；userinfo → Basic 认证）；
 *   抛错 → FetchError；非 2xx → HttpError(code, message, retryAfterSeconds)；无 body → NoBody；
 *   否则按**重定向后的 URL**与 Content-Type 解析（字符集由解析器按 BOM/XML 声明/JSON 处理）。
 * - getSiteMetaData(url)：curl（只接受 text/plain、text/html，FS-A46）→ getSiteMetaDataInHtml：
 *   不含 `<head>` → NotHTML；rel=alternate 且带 href、type（atom/rss 子串或恰为 application/json）→ 绝对 URL（FS-A44）；
 *   youtube 页无 alternate 时用 data-channel-external-id 生成 feed（FS-A45）；图标取 apple-touch-icon/icon/shortcut icon 首个有 href 者（FS-A32）。
 * - findFeedUrls(initialUrl)：SearchFeed 的发现阶段（源 SearchFeedViewModel.searchForFeeds 第一段）。
 * - parseFeedUrl：见 core/parser/FeedMapping（feed_url 保留用户原始 URL，FS-A46）。
 */
import { Either, Left, Right } from '../util/Either';
import { JavaUrl } from '../util/JavaUrl';
import { relativeLinkIntoAbsolute, relativeLinkIntoAbsoluteOrThrow, sloppyLinkToStrictURLOrNull } from '../util/LinkUtils';
import { AlternateLink, ParsedFeed, SiteMetaData } from '../model/Parsed';
import { HttpClient } from '../net/HttpClient';
import { HttpResponse } from '../net/HttpMessages';
import { toError } from '../net/NetworkResult';
import { parseHtml, HtmlDocument, HtmlNode } from '../html/HtmlParser';
import { parseFeedHttpResponse, parseFeedUrl } from '../parser/FeedMapping';
import {
  curl, FeedParserError, FetchError, HttpError, MetaDataParseError, NoAlternateFeeds, NotHTML
} from '../parser/FeedParserError';
import { FeedDao } from '../db/FeedDao';

export { parseFeedUrl };

const LOG_TAG: string = 'FEEDER_FEEDPARSER';
export const YOUTUBE_CHANNEL_ID_ATTR: string = 'data-channel-external-id';
const YOUTUBE_CHANNELID_REGEX: string =
  '^https?://www\\.youtube\\.com/feeds/videos\\.xml\\?channel_id=UC([-_a-zA-Z0-9]{22})';

function clientOr(client: HttpClient | null): HttpClient {
  return client !== null ? client : HttpClient.main();
}

/**
 * 源 RssLocalSync.syncFeed 的获取段：getResponse → 成功且有 body 时以重定向后 URL 解析。
 */
export async function fetchFeed(url: string, forceNetwork: boolean,
  client: HttpClient | null = null): Promise<Either<FeedParserError, ParsedFeed>> {
  let response: HttpResponse;
  try {
    response = await clientOr(client).getResponse(url, forceNetwork);
  } catch (t) {
    return new Left<FeedParserError, ParsedFeed>(new FetchError(url, toError(t as Object)));
  }
  if (!response.isSuccessful()) {
    const retryAfter: number | null = response.retryAfterSeconds();
    if (retryAfter !== null) {
      console.debug(LOG_TAG, `${url}, Retry after: ${retryAfter}`);
    }
    return new Left<FeedParserError, ParsedFeed>(
      new HttpError(url, response.code, response.message, retryAfter));
  }
  // body 为 null → NoBody；否则 parseFeedResponse(response.request.url, body)
  return parseFeedHttpResponse(response);
}

// ============================================================ 站点元数据

/** 源 FeedParser.getSiteMetaData：curl 后解析 HTML */
export async function getSiteMetaData(url: JavaUrl,
  client: HttpClient | null = null): Promise<Either<FeedParserError, SiteMetaData>> {
  const html: Either<FeedParserError, string> = await curl(clientOr(client), url.toString());
  return html.flatMap<SiteMetaData>((text: string): Either<FeedParserError, SiteMetaData> =>
  getSiteMetaDataInHtml(url, text));
}

/** 源 getSiteMetaDataInHtml */
export function getSiteMetaDataInHtml(url: JavaUrl, html: string): Either<FeedParserError, SiteMetaData> {
  if (html.toLowerCase().indexOf('<head>') < 0) {
    // Probably a feed URL and not a page
    return new Left<FeedParserError, SiteMetaData>(new NotHTML(url.toString()));
  }
  return Either.catching<FeedParserError, SiteMetaData>(
    (t: Error): FeedParserError => {
      console.warn(LOG_TAG, `Error when fetching site metadata: ${t.message}`);
      return new MetaDataParseError(url.toString(), t);
    },
    (): SiteMetaData => new SiteMetaData(url.toString(), getAlternateFeedLinksInHtml(html, url),
      getFeedIconInHtml(html, url)));
}

/** Jsoup getElementsByAttributeValue(key, value)：值 trim 后忽略大小写相等（文档序，含根） */
function elementsByAttributeValue(root: HtmlNode, key: string, value: string): HtmlNode[] {
  const lower: string = value.trim().toLowerCase();
  return root.allElements().filter((e: HtmlNode): boolean =>
  e.hasAttr(key) && e.attr(key).trim().toLowerCase() === lower);
}

/** 源 getFeedIconInHtml：apple-touch-icon、icon、shortcut icon 中第一个有 href 的链接 */
export function getFeedIconInHtml(html: string, baseUrl: JavaUrl | null = null): string | null {
  const doc: HtmlDocument = parseHtml(html, baseUrl !== null ? baseUrl.toString() : '');
  const candidates: HtmlNode[] = elementsByAttributeValue(doc, 'rel', 'apple-touch-icon')
    .concat(elementsByAttributeValue(doc, 'rel', 'icon'))
    .concat(elementsByAttributeValue(doc, 'rel', 'shortcut icon'))
    .filter((e: HtmlNode): boolean => e.hasAttr('href'));
  for (let i = 0; i < candidates.length; i++) {
    const href: string = candidates[i].attr('href');
    if (baseUrl !== null) {
      return relativeLinkIntoAbsolute(baseUrl, href);
    }
    const strict: JavaUrl | null = sloppyLinkToStrictURLOrNull(href);
    if (strict !== null) {
      return strict.toString();
    }
  }
  return null;
}

function isFeedType(type: string): boolean {
  const t: string = type.toLowerCase();
  // Youtube for example has alternate links with application/json+oembed type.
  return t.indexOf('application/atom') >= 0 || t.indexOf('application/rss') >= 0 || t === 'application/json';
}

/** 源 getAlternateFeedLinksInHtml：Returns all alternate links in the HTML document pointing to feeds. */
export function getAlternateFeedLinksInHtml(html: string, baseUrl: JavaUrl | null = null): AlternateLink[] {
  const doc: HtmlDocument = parseHtml(html, '');
  const feeds: AlternateLink[] = [];
  const alternates: HtmlNode[] = elementsByAttributeValue(doc, 'rel', 'alternate')
    .filter((e: HtmlNode): boolean => e.hasAttr('href') && e.hasAttr('type'))
    .filter((e: HtmlNode): boolean => isFeedType(e.attr('type')))
    .filter((e: HtmlNode): boolean => {
      const l: string = e.attr('href').toLowerCase();
      try {
        if (baseUrl !== null) {
          relativeLinkIntoAbsoluteOrThrow(baseUrl, l);
        } else {
          JavaUrl.parse(l);
        }
        return true;
      } catch (err) {
        return false;
      }
    });
  for (let i = 0; i < alternates.length; i++) {
    const e: HtmlNode = alternates[i];
    if (baseUrl !== null) {
      try {
        feeds.push(new AlternateLink(relativeLinkIntoAbsoluteOrThrow(baseUrl, e.attr('href')).toString(),
          e.attr('type')));
      } catch (err) {
        // mapNotNull：丢弃
      }
    } else {
      const l: JavaUrl | null = sloppyLinkToStrictURLOrNull(e.attr('href'));
      if (l !== null) {
        feeds.push(new AlternateLink(l.toString(), e.attr('type')));
      }
    }
  }
  if (feeds.length > 0) {
    return feeds;
  }
  if (baseUrl !== null && (baseUrl.host === 'www.youtube.com' || baseUrl.host === 'youtube.com')) {
    return findFeedLinksForYoutube(doc);
  }
  return [];
}

function findFeedLinksForYoutube(doc: HtmlDocument): AlternateLink[] {
  const body: HtmlNode | null = doc.body();
  if (body === null) {
    return [];
  }
  const withAttr: HtmlNode[] = body.allElements().filter((e: HtmlNode): boolean => e.hasAttr(YOUTUBE_CHANNEL_ID_ATTR));
  if (withAttr.length === 0) {
    return [];
  }
  const channelId: string = withAttr[0].attr(YOUTUBE_CHANNEL_ID_ATTR);
  return [new AlternateLink(JavaUrl.parse(`https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`).toString(),
    'atom')];
}

// ============================================================ 发现（SearchFeed）

/** findFeedUrls 结果：站点元数据（或错误）+ 候选 feed URL 序列（每项 Right(url) 或 Left(错误)） */
export class FeedUrlCandidates {
  siteMetaData: Either<FeedParserError, SiteMetaData>;
  candidates: Either<FeedParserError, string>[] = [];

  constructor(siteMetaData: Either<FeedParserError, SiteMetaData>) {
    this.siteMetaData = siteMetaData;
  }
}

/** HttpError 带 Retry-After 时，同主机所有源一并延后（源 SearchFeedViewModel.handleHttpError） */
export async function handleHttpErrorRetryAfter(error: FeedParserError): Promise<void> {
  if (!(error instanceof HttpError)) {
    return;
  }
  const seconds: number | null = (error as HttpError).retryAfterSeconds;
  if (seconds === null) {
    return;
  }
  try {
    const host: string = JavaUrl.parse(error.url).host;
    await FeedDao.setRetryAfterForFeedsWithBaseUrl(host, Date.now() + seconds * 1000);
  } catch (e) {
    console.warn(LOG_TAG, `Failed to set retry-after: ${(e as Error).message}`);
  }
}

/**
 * 源 SearchFeedViewModel.searchForFeeds 的发现段：
 * - 站点元数据成功：逐个 alternate 链接；youtube channel feed 另加 UULF/UUSH/UULV 播放列表 feed；无 alternate → Left(NoAlternateFeeds)。
 * - 失败：HttpError 处理 Retry-After，然后把初始 URL 本身作为候选（可能直接就是 feed）。
 * 候选的逐个解析由调用方用 parseFeedUrl 完成。
 */
export async function findFeedUrls(initialUrl: JavaUrl, client: HttpClient | null = null): Promise<FeedUrlCandidates> {
  const meta: Either<FeedParserError, SiteMetaData> = await getSiteMetaData(initialUrl, client);
  const result: FeedUrlCandidates = new FeedUrlCandidates(meta);
  const md: SiteMetaData | null = meta.getOrNull();
  if (md !== null) {
    const re: RegExp = new RegExp(YOUTUBE_CHANNELID_REGEX);
    for (let i = 0; i < md.alternateFeedLinks.length; i++) {
      const link: string = md.alternateFeedLinks[i].link;
      result.candidates.push(new Right<FeedParserError, string>(link));
      const m: RegExpMatchArray | null = link.match(re);
      if (m !== null && m[1] !== undefined) {
        const channelId: string = m[1];
        result.candidates.push(new Right<FeedParserError, string>(
          `https://www.youtube.com/feeds/videos.xml?playlist_id=UULF${channelId}`));
        result.candidates.push(new Right<FeedParserError, string>(
          `https://www.youtube.com/feeds/videos.xml?playlist_id=UUSH${channelId}`));
        result.candidates.push(new Right<FeedParserError, string>(
          `https://www.youtube.com/feeds/videos.xml?playlist_id=UULV${channelId}`));
      }
    }
    if (md.alternateFeedLinks.length === 0) {
      result.candidates.push(new Left<FeedParserError, string>(new NoAlternateFeeds(initialUrl.toString())));
    }
  } else {
    const err: FeedParserError | null = meta.leftOrNull();
    if (err !== null) {
      await handleHttpErrorRetryAfter(err);
    }
    result.candidates.push(new Right<FeedParserError, string>(initialUrl.toString()));
  }
  return result;
}
