/**
 * HtmlUtils.ets —— 源 util/HtmlUtils.kt：正文首图提取、og:image / twitter:image 提取与抓取。
 *
 * fetchOgImage 的网络层以注入函数 OgHttpGet 提供（调用方用 core/net 的唯一 HttpClient 适配：
 * GET、跟随重定向、返回最终 URL / 状态码 / Content-Type / 响应体）。本文件不直接依赖网络 Kit。
 */
import { decodeUtf8 } from '../util/TextCodec';
import { ImageFromHTML, MediaImage } from '../model/Thumbnail';
import { HtmlDocument } from './HtmlDocument';
import { HtmlNode } from './HtmlNode';
import { javaTrim } from './HtmlChars';
import { parseHtml, unescapeEntities } from './HtmlParser';
import { select } from './HtmlSelector';

/** java.io.IOException 等价（fetchOgImage 非 2xx 时抛出） */
export class IOException extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = 'IOException';
  }
}

/** Kotlin String.toIntOrNull：可选 +/- 号 + 十进制数字，且在 Int 范围内 */
export function kotlinToIntOrNull(s: string): number | null {
  if (!new RegExp('^[+-]?[0-9]+$').test(s)) {
    return null;
  }
  const v: number = parseInt(s, 10);
  if (v > 2147483647 || v < -2147483648) {
    return null;
  }
  return v;
}

/** 跟踪像素判定：width 或 height 属性严格为 "1"（源 filterNot） */
export function isTrackingPixel(img: HtmlNode): boolean {
  return img.attr('width') === '1' || img.attr('height') === '1';
}

/** 社交分享图标（不区分大小写含 twitter_icon / facebook_icon） */
export function isSocialIconUrl(url: string): boolean {
  const lower: string = url.toLowerCase();
  return lower.indexOf('twitter_icon') >= 0 || lower.indexOf('facebook_icon') >= 0;
}

/**
 * 源 findFirstImageInHtml：先整体做一次实体反转义（inAttribute=true，使 `&lt;img ...&gt;` 也成为真标签），
 * 再解析；取第一个非跟踪像素、src 非空白、非社交图标的 img；src 按 baseUrl 绝对化（abs:src）。
 */
export function findFirstImageInHtml(text: string | null, baseUrl: string | null): ImageFromHTML | null {
  if (text === null) {
    return null;
  }
  const doc: HtmlDocument = parseHtml(unescapeEntities(text, true), baseUrl !== null ? baseUrl : '');
  const imgs: HtmlNode[] = doc.getElementsByTag('img');
  for (let i = 0; i < imgs.length; i++) {
    const img: HtmlNode = imgs[i];
    if (isTrackingPixel(img)) {
      continue;
    }
    const url: string = img.attr('abs:src');
    if (url.trim().length === 0 || isSocialIconUrl(url)) {
      continue;
    }
    return new ImageFromHTML(url, kotlinToIntOrNull(img.attr('width')), kotlinToIntOrNull(img.attr('height')));
  }
  return null;
}

/** 源 Element.metaImageUrl：content trim 后空白 → null；absUrl 为空时退回原值（trim 后） */
function metaImageUrl(el: HtmlNode): string | null {
  const rawUrl: string = javaTrim(el.attr('content'));
  if (rawUrl.trim().length === 0) {
    return null;
  }
  const abs: string = el.absUrl('content');
  return abs.trim().length === 0 ? rawUrl : abs;
}

function firstMetaUrl(doc: HtmlDocument, query: string): string | null {
  const metas: HtmlNode[] = select(doc, query);
  for (let i = 0; i < metas.length; i++) {
    const u: string | null = metaImageUrl(metas[i]);
    if (u !== null && u.trim().length > 0) {
      return u;
    }
  }
  return null;
}

/**
 * 源 extractOgImage：og:image 优先于 twitter:image；同 key 下 meta[property] 先于 meta[name]；
 * 属性值匹配忽略大小写；返回 MediaImage(url)（width/height null，fromBody=false）。
 */
export function extractOgImage(html: string, baseUrl: string): MediaImage | null {
  const doc: HtmlDocument = parseHtml(html, baseUrl);
  const candidates: string[] = ['og:image', 'twitter:image'];
  for (let i = 0; i < candidates.length; i++) {
    const property: string = candidates[i];
    let url: string | null = firstMetaUrl(doc, `meta[property="${property}"]`);
    if (url === null) {
      url = firstMetaUrl(doc, `meta[name="${property}"]`);
    }
    if (url !== null) {
      return new MediaImage(url);
    }
  }
  return null;
}

const READ_BUFFER_SIZE: number = 2048;
const MAX_HEAD_BYTES: number = 65536;
const HEAD_END_MARKER: string = '</head>';

/**
 * 源 streamHeadContent：按 2048 字符块累积，遇到 `</head>`（不区分大小写）截断到其后；
 * 累积超过 65536 字符即停止。输入为已按 UTF-8 解码的全文（实现差异：非流式；台账未登记）。
 */
export function streamHeadContent(text: string): string {
  let sb: string = '';
  let pos: number = 0;
  while (pos < text.length) {
    const chunk: string = text.substring(pos, pos + READ_BUFFER_SIZE);
    pos += chunk.length;
    sb += chunk;
    const idx: number = sb.toLowerCase().indexOf(HEAD_END_MARKER);
    if (idx >= 0) {
      return sb.substring(0, idx + HEAD_END_MARKER.length);
    }
    if (sb.length > MAX_HEAD_BYTES) {
      break;
    }
  }
  return sb;
}

/** fetchOgImage 所需的 HTTP 响应视图 */
export interface OgHttpResponse {
  /** HTTP 状态码 */
  code: number;
  /** 原始 Content-Type 头（无则 null） */
  contentType: string | null;
  /** 跟随重定向后的最终请求 URL（≙ OkHttp response.request.url） */
  finalUrl: string;
  /** 响应体原始字节 */
  body: ArrayBuffer;
}

/** 注入的 GET：须跟随重定向，并带上 headers */
export type OgHttpGet = (url: string, headers: Map<string, string>) => Promise<OgHttpResponse>;

/** OkHttp MediaType.subtype 是否为 html / xhtml+xml */
export function isHtmlContentType(contentType: string): boolean {
  const semi: number = contentType.indexOf(';');
  const mime: string = (semi >= 0 ? contentType.substring(0, semi) : contentType).trim().toLowerCase();
  const slash: number = mime.indexOf('/');
  if (slash < 0) {
    return true; // OkHttp toMediaTypeOrNull 解析失败 → contentType()==null → 继续解析
  }
  const subtype: string = mime.substring(slash + 1);
  return subtype === 'html' || subtype === 'xhtml+xml';
}

/**
 * 源 OkHttpClient.fetchOgImage：GET（Accept: text/html，跟随重定向）；非 2xx 抛 IOException；
 * Content-Type 存在且非 html/xhtml+xml → null；只读取到 </head>；以最终响应 URL 作为相对路径基准。
 */
export async function fetchOgImage(get: OgHttpGet, url: string): Promise<MediaImage | null> {
  const headers: Map<string, string> = new Map<string, string>();
  headers.set('Accept', 'text/html');
  const resp: OgHttpResponse = await get(url, headers);
  if (resp.code < 200 || resp.code > 299) {
    throw new IOException(`HTTP ${resp.code} fetching og:image for ${url}`);
  }
  if (resp.contentType !== null && !isHtmlContentType(resp.contentType)) {
    return null;
  }
  const full: string = decodeUtf8(new Uint8Array(resp.body));
  const headContent: string = streamHeadContent(full);
  if (headContent.trim().length === 0) {
    return null;
  }
  return extractOgImage(headContent, resp.finalUrl);
}
