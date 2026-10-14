/**
 * 订阅源模型（源 db/room/Feed.kt、FeedForSettings.kt、FeedTitle.kt、model/FeedUnreadCount.kt）
 * 以及 Room TypeConverters 的等价物（源 db/room/Converters.kt）。
 *
 * 类型映射：Long→number；Instant→epoch 毫秒 number；java.net.URL→string（宽松规整）；
 * ZonedDateTime→Java `ZonedDateTime.toString()` 格式的 ISO 字符串（pub_date TEXT 列原样）。
 */
import { ID_UNSET } from './Enums';
import { ThumbnailImage } from './Thumbnail';

export const OPEN_ARTICLE_WITH_APPLICATION_DEFAULT: string = '';

/** Kotlin `URL("http://")` 的字符串形式，URL 字段默认值 / 宽松解析失败值 */
export const DEFAULT_URL: string = 'http://';

/** Instant.EPOCH */
export const EPOCH_MS: number = 0;

/** Kotlin CharSequence.isBlank() */
export function isBlankString(s: string | null): boolean {
  if (s === null) {
    return true;
  }
  return s.trim().length === 0;
}

export class Feed {
  id: number = ID_UNSET;
  title: string = '';
  customTitle: string = '';
  url: string = DEFAULT_URL;
  tag: string = '';
  notify: boolean = false;
  imageUrl: string | null = null;
  /** epoch ms */
  lastSync: number = EPOCH_MS;
  responseHash: number = 0;
  fullTextByDefault: boolean = false;
  openArticlesWith: string = OPEN_ARTICLE_WITH_APPLICATION_DEFAULT;
  alternateId: boolean = false;
  currentlySyncing: boolean = false;
  /** Only update this field when user modifies the feed（epoch ms） */
  whenModified: number = EPOCH_MS;
  /** epoch ms */
  siteFetched: number = EPOCH_MS;
  skipDuplicates: boolean = false;
  /** Time when feed is allowed to be synced again earliest, based on retry-after response header（epoch ms） */
  retryAfter: number = EPOCH_MS;
  summarizeOnOpen: boolean = false;
  fetchOgImages: boolean = false;
  blockRules: string = '';
  allowRules: string = '';

  get displayTitle(): string {
    return isBlankString(this.customTitle) ? this.title : this.customTitle;
  }

  /** Kotlin data class copy() */
  copy(): Feed {
    const f: Feed = new Feed();
    f.id = this.id;
    f.title = this.title;
    f.customTitle = this.customTitle;
    f.url = this.url;
    f.tag = this.tag;
    f.notify = this.notify;
    f.imageUrl = this.imageUrl;
    f.lastSync = this.lastSync;
    f.responseHash = this.responseHash;
    f.fullTextByDefault = this.fullTextByDefault;
    f.openArticlesWith = this.openArticlesWith;
    f.alternateId = this.alternateId;
    f.currentlySyncing = this.currentlySyncing;
    f.whenModified = this.whenModified;
    f.siteFetched = this.siteFetched;
    f.skipDuplicates = this.skipDuplicates;
    f.retryAfter = this.retryAfter;
    f.summarizeOnOpen = this.summarizeOnOpen;
    f.fetchOgImages = this.fetchOgImages;
    f.blockRules = this.blockRules;
    f.allowRules = this.allowRules;
    return f;
  }
}

/** 投影：id,title,notify */
export class FeedForSettings {
  id: number = ID_UNSET;
  title: string = '';
  notify: boolean = false;

  constructor(id: number = ID_UNSET, title: string = '', notify: boolean = false) {
    this.id = id;
    this.title = title;
    this.notify = notify;
  }
}

/** 投影：id,title,custom_title */
export class FeedTitle {
  id: number = ID_UNSET;
  title: string = '';
  customTitle: string = '';

  constructor(id: number = ID_UNSET, title: string = '', customTitle: string = '') {
    this.id = id;
    this.title = title;
    this.customTitle = customTitle;
  }

  get displayTitle(): string {
    return isBlankString(this.customTitle) ? this.title : this.customTitle;
  }
}

/** 源 model/FeedUnreadCount.kt（抽屉计数投影；列 display_title/image_url/unread_count） */
export class FeedUnreadCount {
  id: number = ID_UNSET;
  displayTitle: string = '';
  tag: string = '';
  imageUrl: string | null = null;
  unreadCount: number = 0;
  expanded: boolean = false;
}

// =====================================================================
// ZonedDateTime（Java ISO_ZONED_DATE_TIME 解析 + toString 复刻）
// =====================================================================

export class ZonedDateTimeValue {
  /** Java ZonedDateTime.toString() 规范串（入库 pub_date 原样） */
  iso: string = '';
  /** toInstant().toEpochMilli() */
  epochMs: number = 0;
}

const DAYS_IN_MONTH: number[] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function pad(n: number, width: number): string {
  let s: string = `${n}`;
  while (s.length < width) {
    s = '0' + s;
  }
  return s;
}

function isLeap(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

export class JavaTime {
  /** ZonedDateTime.parse(text)；不合法返回 null（源 Converters.dateTimeFromString 吞异常） */
  static parseZoned(text: string | null): ZonedDateTimeValue | null {
    if (text === null) {
      return null;
    }
    const re: RegExp = new RegExp(
      '^([0-9]{4}|[+-][0-9]{4,9})-([0-9]{2})-([0-9]{2})[Tt]([0-9]{2}):([0-9]{2})' +
        '(?::([0-9]{2})(?:\\.([0-9]{0,9}))?)?' +
        '([Zz]|[+-][0-9]{2}:[0-9]{2}(?::[0-9]{2})?)' +
        '(?:\\[([A-Za-z0-9~/._+\\-:]+)\\])?$');
    const m: RegExpMatchArray | null = text.match(re);
    if (m === null) {
      return null;
    }
    const year: number = Number.parseInt(m[1], 10);
    const month: number = Number.parseInt(m[2], 10);
    const day: number = Number.parseInt(m[3], 10);
    const hour: number = Number.parseInt(m[4], 10);
    const minute: number = Number.parseInt(m[5], 10);
    const second: number = m[6] !== undefined && m[6] !== null ? Number.parseInt(m[6], 10) : 0;
    let nano: number = 0;
    if (m[7] !== undefined && m[7] !== null && m[7].length > 0) {
      let frac: string = m[7];
      while (frac.length < 9) {
        frac = frac + '0';
      }
      nano = Number.parseInt(frac, 10);
    }
    if (month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59 || day < 1) {
      return null;
    }
    let maxDay: number = DAYS_IN_MONTH[month - 1];
    if (month === 2 && isLeap(year)) {
      maxDay = 29;
    }
    if (day > maxDay) {
      return null;
    }
    const offsetSeconds: number | null = JavaTime.parseOffset(m[8]);
    if (offsetSeconds === null) {
      return null;
    }
    let zoneSuffix: string = '';
    const zoneRaw: string | undefined = m[9];
    if (zoneRaw !== undefined && zoneRaw !== null && zoneRaw.length > 0) {
      const zoneAsOffset: number | null = JavaTime.parseOffset(zoneRaw);
      if (zoneAsOffset !== null) {
        // ZoneId.of("+01:00") 是 ZoneOffset：zone==offset 时 toString 不带 [..]
        if (zoneAsOffset !== offsetSeconds) {
          return null;
        }
      } else {
        zoneSuffix = `[${zoneRaw}]`;
      }
    }
    const v: ZonedDateTimeValue = new ZonedDateTimeValue();
    v.iso = JavaTime.formatLocal(year, month, day, hour, minute, second, nano) +
      JavaTime.formatOffset(offsetSeconds) + zoneSuffix;
    v.epochMs = JavaTime.toEpochMs(year, month, day, hour, minute, second, nano, offsetSeconds);
    return v;
  }

  /** ZonedDateTime.now(Clock.systemUTC()).toString()（毫秒精度） */
  static nowUtcIso(nowMs: number = Date.now()): string {
    return JavaTime.formatUtcIso(nowMs);
  }

  /** Instant(ms) 在 UTC 下的 ZonedDateTime.toString() */
  static formatUtcIso(ms: number): string {
    const d: Date = new Date(ms);
    const msPart: number = ((ms % 1000) + 1000) % 1000;
    return JavaTime.formatLocal(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate(), d.getUTCHours(),
      d.getUTCMinutes(), d.getUTCSeconds(), msPart * 1000000) + 'Z';
  }

  /** 'Z'/'z' 或 ±HH:MM[:SS] → 偏移秒；非法 null（Java 偏移上限 ±18:00） */
  static parseOffset(s: string): number | null {
    if (s === 'Z' || s === 'z') {
      return 0;
    }
    const re: RegExp = new RegExp('^([+-])([0-9]{2}):([0-9]{2})(?::([0-9]{2}))?$');
    const m: RegExpMatchArray | null = s.match(re);
    if (m === null) {
      return null;
    }
    const h: number = Number.parseInt(m[2], 10);
    const mi: number = Number.parseInt(m[3], 10);
    const se: number = m[4] !== undefined && m[4] !== null ? Number.parseInt(m[4], 10) : 0;
    if (h > 18 || mi > 59 || se > 59) {
      return null;
    }
    const total: number = h * 3600 + mi * 60 + se;
    if (total > 18 * 3600) {
      return null;
    }
    return m[1] === '-' ? -total : total;
  }

  /** ZoneOffset.toString() */
  static formatOffset(totalSeconds: number): string {
    if (totalSeconds === 0) {
      return 'Z';
    }
    const abs: number = Math.abs(totalSeconds);
    const h: number = Math.floor(abs / 3600);
    const mi: number = Math.floor((abs % 3600) / 60);
    const se: number = abs % 60;
    let s: string = (totalSeconds < 0 ? '-' : '+') + pad(h, 2) + ':' + pad(mi, 2);
    if (se !== 0) {
      s += ':' + pad(se, 2);
    }
    return s;
  }

  /** LocalDateTime.toString() */
  static formatLocal(year: number, month: number, day: number, hour: number, minute: number, second: number,
    nano: number): string {
    let ys: string;
    const absYear: number = Math.abs(year);
    if (absYear < 1000) {
      ys = (year < 0 ? '-' : '') + pad(absYear, 4);
    } else {
      ys = (year > 9999 ? '+' : (year < 0 ? '-' : '')) + `${absYear}`;
    }
    let s: string = ys + '-' + pad(month, 2) + '-' + pad(day, 2) + 'T' + pad(hour, 2) + ':' + pad(minute, 2);
    if (second > 0 || nano > 0) {
      s += ':' + pad(second, 2);
      if (nano > 0) {
        if (nano % 1000000 === 0) {
          s += '.' + pad(nano / 1000000 + 1000, 4).substring(1);
        } else if (nano % 1000 === 0) {
          s += '.' + pad(nano / 1000 + 1000000, 7).substring(1);
        } else {
          s += '.' + pad(nano + 1000000000, 10).substring(1);
        }
      }
    }
    return s;
  }

  static toEpochMs(year: number, month: number, day: number, hour: number, minute: number, second: number,
    nano: number, offsetSeconds: number): number {
    const d: Date = new Date(0);
    d.setUTCFullYear(year, month - 1, day);
    d.setUTCHours(hour, minute, second, Math.floor(nano / 1000000));
    return d.getTime() - offsetSeconds * 1000;
  }
}

// =====================================================================
// java.net.URL 宽松规整（源 util/LinkUtils.kt sloppyLinkToStrictURLNoThrows）
// =====================================================================

const JAVA_URL_PROTOCOLS: string[] = ['http', 'https', 'ftp', 'file', 'jar', 'mailto'];

export class JavaUrl {
  /** java.net.URL 构造时去掉首尾 <= ' ' 的字符 */
  static javaTrim(value: string): string {
    return ThumbnailImage.javaTrim(value);
  }

  static schemeOf(text: string): string | null {
    const re: RegExp = new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*):');
    const m: RegExpMatchArray | null = text.match(re);
    return m === null ? null : m[1].toLowerCase();
  }

  /** `URL(text)` 是否成功（近似：已知协议即接受；Java URL 本身对其余部分非常宽松）；成功返回 toString() */
  static strictOrNull(text: string): string | null {
    const t: string = JavaUrl.javaTrim(text);
    const scheme: string | null = JavaUrl.schemeOf(t);
    if (scheme === null || JAVA_URL_PROTOCOLS.indexOf(scheme) < 0) {
      return null;
    }
    return t;
  }

  /** java.net.URI(text) 是否能解析（近似：不含 RFC2396 非法字符、% 后跟两位十六进制） */
  static looksLikeValidUri(text: string): boolean {
    if (text.length === 0) {
      return true;
    }
    const illegal: RegExp = new RegExp('[\\s"<>`{}|\\\\^\\u0000-\\u001f\\u007f]');
    if (illegal.test(text)) {
      return false;
    }
    const badPercent: RegExp = new RegExp('%(?![0-9A-Fa-f]{2})');
    return !badPercent.test(text);
  }

  /**
   * 源 sloppyLinkToStrictURL：空白抛错；URL(url) 成功即用；否则 URI 绝对→toURL（未知协议抛错）；
   * 否则补 `http://`。抛错时返回 null。
   */
  static sloppyLinkToStrictURLOrNull(url: string): string | null {
    if (isBlankString(url)) {
      return null;
    }
    const strict: string | null = JavaUrl.strictOrNull(url);
    if (strict !== null) {
      return strict;
    }
    const t: string = JavaUrl.javaTrim(url);
    if (JavaUrl.looksLikeValidUri(t) && JavaUrl.schemeOf(t) !== null) {
      // URI 绝对但协议不被 java.net.URL 支持 → MalformedURLException
      return null;
    }
    return 'http://' + t;
  }

  /** 源 sloppyLinkToStrictURLNoThrows：失败返回 URL("http://") */
  static sloppyLinkToStrictURLNoThrows(url: string): string {
    const r: string | null = JavaUrl.sloppyLinkToStrictURLOrNull(url);
    return r === null ? DEFAULT_URL : r;
  }
}

// =====================================================================
// Room TypeConverters 等价物（源 db/room/Converters.kt）
// =====================================================================

export class Converters {
  /** DB-A12：pub_date TEXT → 规范 ISO 串；不可解析读为 null */
  static dateTimeFromString(value: string | null): string | null {
    const v: ZonedDateTimeValue | null = JavaTime.parseZoned(value);
    return v === null ? null : v.iso;
  }

  /** DB-A12：入库原样（模型内已是 ZonedDateTime.toString() 串） */
  static stringFromDateTime(value: string | null): string | null {
    return value;
  }

  /** DB-A14 */
  static stringFromURL(value: string | null): string | null {
    return value;
  }

  /** DB-A14：读取宽松解析为合法 URL，不抛错 */
  static urlFromString(value: string | null): string | null {
    if (value === null) {
      return null;
    }
    return JavaUrl.sloppyLinkToStrictURLNoThrows(value);
  }

  /** DB-A11：epoch 毫秒；异常（非有限数/超出 Instant 范围）读为 null */
  static instantFromLong(value: number | null): number | null {
    if (value === null || value === undefined || !Number.isFinite(value)) {
      return null;
    }
    return Math.trunc(value);
  }

  /** DB-A11 */
  static longFromInstant(value: number | null): number | null {
    return value;
  }

  /** DB-A13 */
  static stringFromThumbnailImage(value: ThumbnailImage | null): string | null {
    return ThumbnailImage.encode(value);
  }

  /** DB-A13：JSON → 判别联合；旧值纯 URL → ImageFromHTML(宽高未知)；否则 null */
  static thumbnailImageFromString(value: string | null): ThumbnailImage | null {
    return ThumbnailImage.fromJson(value);
  }
}
