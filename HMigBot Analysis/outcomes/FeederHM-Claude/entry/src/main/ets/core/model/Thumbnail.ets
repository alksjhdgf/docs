/**
 * ThumbnailImage 判别联合（源 model/ThumbnailImage.kt + model/ThumbnailImagePolicy.kt）。
 *
 * 存储格式照源 kotlinx.serialization 默认 Json：
 *  - 判别字段 `type`，取值 `ImageFromHTML` / `EnclosureImage` / `MediaImage`
 *  - encodeDefaults=false：width/height 为 null（默认值）时不输出
 *  - ignoreUnknownKeys=false：出现未知键即解码失败
 * 旧数据为纯 URL 时读为 ImageFromHTML(url, null, null)；否则 null（源 db/room/Converters.kt:46-67）。
 *
 * URL should be absolute at all times.
 */

export const THUMBNAIL_TYPE_IMAGE_FROM_HTML: string = 'ImageFromHTML';
export const THUMBNAIL_TYPE_ENCLOSURE_IMAGE: string = 'EnclosureImage';
export const THUMBNAIL_TYPE_MEDIA_IMAGE: string = 'MediaImage';

/** java.net.URL 内置协议处理器（URL(String) 仅接受这些协议，其它抛 MalformedURLException） */
const JAVA_URL_PROTOCOLS: string[] = ['http', 'https', 'ftp', 'file', 'jar', 'mailto'];

const INT_MIN: number = -2147483648;
const INT_MAX: number = 2147483647;

export abstract class ThumbnailImage {
  /** kotlinx 判别值（`type` 字段） */
  readonly type: string;
  readonly url: string;
  readonly width: number | null;
  readonly height: number | null;
  readonly fromBody: boolean;

  protected constructor(type: string, url: string, width: number | null, height: number | null, fromBody: boolean) {
    this.type = type;
    this.url = url;
    this.width = width;
    this.height = height;
    this.fromBody = fromBody;
  }

  abstract equals(other: ThumbnailImage | null): boolean;

  abstract toJson(): string;

  abstract toString(): string;

  /** 源 Converters.stringFromThumbnailImage */
  static encode(value: ThumbnailImage | null): string | null {
    if (value === null) {
      return null;
    }
    return value.toJson();
  }

  /**
   * 源 Converters.thumbnailImageFromString：JSON 解码失败时把原串当 java.net.URL 解析，
   * 成功则 ImageFromHTML(url, null, null)，否则 null。
   */
  static fromJson(value: string | null): ThumbnailImage | null {
    if (value === null) {
      return null;
    }
    const decoded: ThumbnailImage | null = ThumbnailImage.decodeStrict(value);
    if (decoded !== null) {
      return decoded;
    }
    const legacy: string | null = ThumbnailImage.legacyJavaUrl(value);
    if (legacy !== null) {
      return new ImageFromHTML(legacy, null, null);
    }
    return null;
  }

  /** 严格 kotlinx 语义解码；任何不符返回 null */
  static decodeStrict(value: string): ThumbnailImage | null {
    let parsed: Object | null = null;
    try {
      parsed = JSON.parse(value) as Object | null;
    } catch (e) {
      return null;
    }
    if (parsed === null || parsed === undefined || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null;
    }
    const rec: Record<string, Object | null> = parsed as Record<string, Object | null>;
    const keys: string[] = Object.keys(rec);
    const typeVal: Object | null = rec['type'];
    if (typeVal === null || typeVal === undefined || typeof typeVal !== 'string') {
      return null;
    }
    const typeStr: string = typeVal as string;
    const urlVal: Object | null = rec['url'];
    if (urlVal === null || urlVal === undefined || typeof urlVal !== 'string') {
      return null;
    }
    const urlStr: string = urlVal as string;
    if (typeStr === THUMBNAIL_TYPE_ENCLOSURE_IMAGE) {
      if (!ThumbnailImage.onlyKeys(keys, ['type', 'url', 'length'])) {
        return null;
      }
      const lenVal: Object | null = rec['length'];
      if (lenVal === null || lenVal === undefined || typeof lenVal !== 'number' ||
        !Number.isInteger(lenVal as number)) {
        return null;
      }
      return new EnclosureImage(urlStr, lenVal as number);
    }
    if (typeStr !== THUMBNAIL_TYPE_IMAGE_FROM_HTML && typeStr !== THUMBNAIL_TYPE_MEDIA_IMAGE) {
      return null;
    }
    if (!ThumbnailImage.onlyKeys(keys, ['type', 'url', 'width', 'height'])) {
      return null;
    }
    const w: number | null = ThumbnailImage.optInt(rec, 'width');
    const h: number | null = ThumbnailImage.optInt(rec, 'height');
    if (ThumbnailImage.badInt(rec, 'width') || ThumbnailImage.badInt(rec, 'height')) {
      return null;
    }
    if (typeStr === THUMBNAIL_TYPE_IMAGE_FROM_HTML) {
      return new ImageFromHTML(urlStr, w, h);
    }
    return new MediaImage(urlStr, w, h);
  }

  /**
   * java.net.URL(String) 是否接受：去首尾空白（<= ' '），需要已知协议。
   * 返回 URL.toString()（Java 不做规范化，等于去空白后的原串），失败 null。
   */
  static legacyJavaUrl(value: string): string | null {
    const trimmed: string = ThumbnailImage.javaTrim(value);
    const schemeRe: RegExp = new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*):');
    const m: RegExpMatchArray | null = trimmed.match(schemeRe);
    if (m === null) {
      return null;
    }
    const scheme: string = m[1].toLowerCase();
    if (JAVA_URL_PROTOCOLS.indexOf(scheme) < 0) {
      return null;
    }
    return trimmed;
  }

  static javaTrim(value: string): string {
    let start: number = 0;
    let end: number = value.length;
    while (start < end && value.charCodeAt(start) <= 32) {
      start++;
    }
    while (end > start && value.charCodeAt(end - 1) <= 32) {
      end--;
    }
    return value.substring(start, end);
  }

  private static onlyKeys(keys: string[], allowed: string[]): boolean {
    for (let i = 0; i < keys.length; i++) {
      if (allowed.indexOf(keys[i]) < 0) {
        return false;
      }
    }
    return true;
  }

  private static optInt(rec: Record<string, Object | null>, key: string): number | null {
    const v: Object | null = rec[key];
    if (v === null || v === undefined || typeof v !== 'number') {
      return null;
    }
    return v as number;
  }

  private static badInt(rec: Record<string, Object | null>, key: string): boolean {
    const v: Object | null = rec[key];
    if (v === null || v === undefined) {
      return false;
    }
    if (typeof v !== 'number') {
      return true;
    }
    const n: number = v as number;
    return !Number.isInteger(n) || n < INT_MIN || n > INT_MAX;
  }

  static numOrNull(v: number | null): string {
    return v === null ? 'null' : `${v}`;
  }
}

export class ImageFromHTML extends ThumbnailImage {
  constructor(url: string, width: number | null = null, height: number | null = null) {
    super(THUMBNAIL_TYPE_IMAGE_FROM_HTML, url, width, height, true);
  }

  equals(other: ThumbnailImage | null): boolean {
    if (other instanceof ImageFromHTML) {
      return this.url === other.url && this.width === other.width && this.height === other.height;
    }
    return false;
  }

  toJson(): string {
    return encodeWithSize(THUMBNAIL_TYPE_IMAGE_FROM_HTML, this.url, this.width, this.height);
  }

  toString(): string {
    return `ImageFromHTML(url='${this.url}', width=${ThumbnailImage.numOrNull(this.width)}, height=${ThumbnailImage.numOrNull(this.height)}, fromBody=${this.fromBody})`;
  }
}

export class EnclosureImage extends ThumbnailImage {
  /** Number of bytes of images, zero if not known */
  readonly length: number;

  constructor(url: string, length: number) {
    super(THUMBNAIL_TYPE_ENCLOSURE_IMAGE, url, null, null, false);
    this.length = length;
  }

  /** 源 equals 只比较 url/width/height（width/height 恒为 null），不比较 length */
  equals(other: ThumbnailImage | null): boolean {
    if (other instanceof EnclosureImage) {
      return this.url === other.url;
    }
    return false;
  }

  toJson(): string {
    return `{"type":${JSON.stringify(THUMBNAIL_TYPE_ENCLOSURE_IMAGE)},"url":${JSON.stringify(this.url)},"length":${this.length}}`;
  }

  toString(): string {
    return `EnclosureImage(url='${this.url}', width=null, height=null, fromBody=${this.fromBody})`;
  }
}

export class MediaImage extends ThumbnailImage {
  constructor(url: string, width: number | null = null, height: number | null = null) {
    super(THUMBNAIL_TYPE_MEDIA_IMAGE, url, width, height, false);
  }

  equals(other: ThumbnailImage | null): boolean {
    if (other instanceof MediaImage) {
      return this.url === other.url && this.width === other.width && this.height === other.height;
    }
    return false;
  }

  toJson(): string {
    return encodeWithSize(THUMBNAIL_TYPE_MEDIA_IMAGE, this.url, this.width, this.height);
  }

  toString(): string {
    return `MediaImage(url='${this.url}', width=${ThumbnailImage.numOrNull(this.width)}, height=${ThumbnailImage.numOrNull(this.height)}, fromBody=${this.fromBody})`;
  }
}

/** kotlinx 默认 Json：类型判别在前，属性按声明顺序，等于默认值(null)的属性省略 */
function encodeWithSize(type: string, url: string, w: number | null, h: number | null): string {
  let s: string = `{"type":${JSON.stringify(type)},"url":${JSON.stringify(url)}`;
  if (w !== null) {
    s += `,"width":${w}`;
  }
  if (h !== null) {
    s += `,"height":${h}`;
  }
  return s + '}';
}

/** 两个可空缩略图相等（源 Kotlin `==`） */
export function thumbnailEquals(a: ThumbnailImage | null, b: ThumbnailImage | null): boolean {
  if (a === null || b === null) {
    return a === null && b === null;
  }
  return a.equals(b);
}

/**
 * Centralized rules for picking an article thumbnail across feed parsing and
 * optional article-page metadata enrichment.（源 model/ThumbnailImagePolicy.kt）
 */
export class ThumbnailImagePolicy {
  /**
   * Feed-provided non-body images are authoritative. If a previous sync already
   * upgraded the item to a non-body image, keep it unless the feed now provides
   * its own non-body image. Body-derived images are treated as fallback only.
   */
  static applyParsedEntryImage(current: ThumbnailImage | null, incoming: ThumbnailImage | null): ThumbnailImage | null {
    if (incoming !== null && !incoming.fromBody) {
      return incoming;
    }
    if (current !== null && !current.fromBody) {
      return current;
    }
    return incoming;
  }

  static shouldFetchOgImage(current: ThumbnailImage | null, articleUrl: string | null, hasFeedImage: boolean): boolean {
    const blank: boolean = articleUrl === null || articleUrl.trim().length === 0;
    return !blank && !hasFeedImage && (current === null || current.fromBody);
  }

  static applyOgImage(current: ThumbnailImage | null, ogImage: ThumbnailImage | null): ThumbnailImage | null {
    if (current !== null && !current.fromBody) {
      return current;
    }
    if (ogImage !== null) {
      return ogImage;
    }
    return current;
  }
}
