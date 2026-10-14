/**
 * JavaTime.ets —— java.time 在本工程所需子集：
 *  - ZonedDateTime.toString()（DB 列 feed_items.pub_date 的 TEXT 格式，参与游标/排序字典序比较）
 *  - ZonedDateTime.parse(ISO_ZONED_DATE_TIME)（DB 读回；失败 → null 由调用方决定）
 *  - Instant 与 epoch 毫秒互转、Instant.toString()/parse（ISO_INSTANT）
 * 时区规则：本实现不含 tzdb，命名时区（如 [Europe/Paris]）只做原样保留，不按规则校正偏移。
 */
import { DateTimeParseException } from './JavaCodec';

function pad(v: number, width: number): string {
  let s = String(Math.abs(Math.trunc(v)));
  while (s.length < width) {
    s = '0' + s;
  }
  return s;
}

function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}

function floorMod(a: number, b: number): number {
  return a - Math.floor(a / b) * b;
}

/** LocalDate.toString 的年份部分 */
function formatYear(year: number): string {
  if (Math.abs(year) < 1000) {
    return (year < 0 ? '-' : '') + pad(year, 4);
  }
  if (year > 9999) {
    return '+' + String(year);
  }
  return String(year);
}

/** LocalTime.toString 的秒/纳秒部分（秒与纳秒均为 0 时省略） */
function formatSecondsAndNanos(second: number, nano: number, forceSeconds: boolean): string {
  if (!forceSeconds && second === 0 && nano === 0) {
    return '';
  }
  let s = ':' + pad(second, 2);
  if (nano > 0) {
    if (nano % 1000000 === 0) {
      s += '.' + String(nano / 1000000 + 1000).substring(1);
    } else if (nano % 1000 === 0) {
      s += '.' + String(nano / 1000 + 1000000).substring(1);
    } else {
      s += '.' + String(nano + 1000000000).substring(1);
    }
  }
  return s;
}

/** ZoneOffset.toString：0 → "Z"，否则 ±HH:MM[:SS] */
export function zoneOffsetToString(offsetSeconds: number): string {
  if (offsetSeconds === 0) {
    return 'Z';
  }
  const abs = Math.abs(offsetSeconds);
  const hours = Math.floor(abs / 3600);
  const minutes = Math.floor(abs / 60) % 60;
  const seconds = abs % 60;
  let s = (offsetSeconds < 0 ? '-' : '+') + pad(hours, 2) + ':' + pad(minutes, 2);
  if (seconds !== 0) {
    s += ':' + pad(seconds, 2);
  }
  return s;
}

/** 以 UTC 字段格式化 LocalDateTime（epochSecond 为本地墙钟秒） */
function formatLocalDateTime(localEpochSecond: number, nano: number, forceSeconds: boolean): string {
  const d = new Date(localEpochSecond * 1000);
  return formatYear(d.getUTCFullYear()) + '-' + pad(d.getUTCMonth() + 1, 2) + '-' + pad(d.getUTCDate(), 2) +
    'T' + pad(d.getUTCHours(), 2) + ':' + pad(d.getUTCMinutes(), 2) +
    formatSecondsAndNanos(d.getUTCSeconds(), nano, forceSeconds);
}

/** 墙钟字段 → 本地 epoch 秒（避开 Date.UTC 对 0..99 年的 1900 偏移） */
function localFieldsToEpochSecond(year: number, month: number, day: number, hour: number, minute: number,
  second: number): number {
  const d = new Date(0);
  d.setUTCFullYear(year, month - 1, day);
  d.setUTCHours(hour, minute, second, 0);
  return Math.floor(d.getTime() / 1000);
}

function daysInMonth(year: number, month: number): number {
  const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
  const table: number[] = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return table[month - 1];
}

/** 当前进程时区在该时刻的偏移（秒），供 ZonedDateTime.now(systemDefault) 的等价构造。 */
export function localOffsetSeconds(epochMs: number): number {
  return -new Date(epochMs).getTimezoneOffset() * 60;
}

export class JavaZonedDateTime {
  epochSecond: number = 0;
  nanoOfSecond: number = 0;
  offsetSeconds: number = 0;
  /** 区域 ID（如 "Europe/Paris"、"UTC"）；null 表示 zone == offset */
  zoneId: string | null = null;

  static ofEpochMs(epochMs: number, offsetSeconds: number, zoneId: string | null = null): JavaZonedDateTime {
    const z = new JavaZonedDateTime();
    z.epochSecond = floorDiv(epochMs, 1000);
    z.nanoOfSecond = floorMod(epochMs, 1000) * 1000000;
    z.offsetSeconds = offsetSeconds;
    z.zoneId = zoneId;
    return z;
  }

  toEpochMs(): number {
    return this.epochSecond * 1000 + Math.floor(this.nanoOfSecond / 1000000);
  }

  /** ZonedDateTime.toString：LocalDateTime + offset + ("[zone]" 当 zone != offset) */
  toString(): string {
    const offsetId = zoneOffsetToString(this.offsetSeconds);
    let s = formatLocalDateTime(this.epochSecond + this.offsetSeconds, this.nanoOfSecond, false) + offsetId;
    if (this.zoneId !== null && this.zoneId !== offsetId) {
      s += '[' + this.zoneId + ']';
    }
    return s;
  }

  /**
   * ZonedDateTime.parse(text)（ISO_ZONED_DATE_TIME）：
   * yyyy-MM-ddTHH:mm[:ss[.f{0,9}]] + (Z | ±HH[:MM[:SS]]) + 可选 [zone]；T/Z 大小写不敏感。失败抛 DateTimeParseException。
   */
  static parse(text: string): JavaZonedDateTime {
    const re = new RegExp('^([+-]?\\d{4,9})-(\\d{2})-(\\d{2})[Tt](\\d{2}):(\\d{2})(?::(\\d{2})(?:\\.(\\d{0,9}))?)?' +
      '([Zz]|[+-]\\d{2}(?::\\d{2}(?::\\d{2})?)?)(?:\\[([^\\]]+)\\])?$');
    const m = re.exec(text);
    if (m === null) {
      throw new DateTimeParseException('Text \'' + text + '\' could not be parsed', text);
    }
    const yearText = m[1];
    if (yearText.length > 4 && !(yearText.startsWith('+') || yearText.startsWith('-'))) {
      throw new DateTimeParseException('Text \'' + text + '\' could not be parsed at index 0', text);
    }
    const year = Number(yearText);
    const month = Number(m[2]);
    const day = Number(m[3]);
    const hour = Number(m[4]);
    const minute = Number(m[5]);
    const secText: string | undefined = m[6];
    const second = secText !== undefined ? Number(secText) : 0;
    let nano = 0;
    const frac: string | undefined = m[7];
    if (frac !== undefined && frac.length > 0) {
      let f = frac;
      while (f.length < 9) {
        f = f + '0';
      }
      nano = Number(f);
    }
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month) || hour > 23 || minute > 59 ||
      second > 59) {
      throw new DateTimeParseException('Text \'' + text + '\' could not be parsed: Invalid date/time', text);
    }
    const offText = m[8];
    let offsetSeconds = 0;
    if (offText !== 'Z' && offText !== 'z') {
      const sign = offText.charAt(0) === '-' ? -1 : 1;
      const digits = offText.substring(1).split(':').join('');
      const oh = Number(digits.substring(0, 2));
      const om = digits.length >= 4 ? Number(digits.substring(2, 4)) : 0;
      const os = digits.length >= 6 ? Number(digits.substring(4, 6)) : 0;
      if (oh > 18 || om > 59 || os > 59 || (oh === 18 && (om > 0 || os > 0))) {
        throw new DateTimeParseException('Text \'' + text + '\' could not be parsed: Zone offset out of range',
          text);
      }
      offsetSeconds = sign * (oh * 3600 + om * 60 + os);
    }
    const z = new JavaZonedDateTime();
    z.epochSecond = localFieldsToEpochSecond(year, month, day, hour, minute, second) - offsetSeconds;
    z.nanoOfSecond = nano;
    z.offsetSeconds = offsetSeconds;
    const zone: string | undefined = m[9];
    z.zoneId = zone !== undefined ? zone : null;
    return z;
  }

  static parseOrNull(text: string | null): JavaZonedDateTime | null {
    if (text === null) {
      return null;
    }
    try {
      return JavaZonedDateTime.parse(text);
    } catch (e) {
      return null;
    }
  }
}

/** ZonedDateTime.ofInstant(Instant.ofEpochMilli(epochMs), zone).toString()；offsetSeconds 为该时刻的偏移（秒）。 */
export function zonedDateTimeToString(epochMs: number, offsetSeconds: number, zoneId: string | null = null): string {
  return JavaZonedDateTime.ofEpochMs(epochMs, offsetSeconds, zoneId).toString();
}

// ---------------- Instant ----------------

/** Instant.ofEpochMilli(ms) —— 工程内 Instant 一律用 epoch 毫秒 number 表示，此函数为语义标注（恒等）。 */
export function instantOfEpochMilli(epochMs: number): number {
  return epochMs;
}

/** Instant.toEpochMilli() —— 恒等（见 instantOfEpochMilli） */
export function instantToEpochMilli(instantMs: number): number {
  return instantMs;
}

/** Instant.ofEpochSecond(s) → epoch 毫秒 */
export function instantOfEpochSecond(epochSecond: number): number {
  return epochSecond * 1000;
}

/** Instant.getEpochSecond() */
export function instantEpochSecond(epochMs: number): number {
  return floorDiv(epochMs, 1000);
}

/** Instant.toString()（ISO_INSTANT：恒输出秒，小数按 3/6/9 位分组，UTC 'Z'） */
export function instantToString(epochMs: number): string {
  const sec = floorDiv(epochMs, 1000);
  const nano = floorMod(epochMs, 1000) * 1000000;
  return formatLocalDateTime(sec, nano, true) + 'Z';
}

/** Instant.parse(text)（ISO_INSTANT，接受任意偏移并换算到 UTC）→ epoch 毫秒；失败抛 DateTimeParseException。 */
export function instantParse(text: string): number {
  return JavaZonedDateTime.parse(text).toEpochMs();
}

/** Instant.now() */
export function instantNow(): number {
  return Date.now();
}

/** Instant.minusMinutes（源 util/Time.kt） */
export function instantMinusMinutes(epochMs: number, minutes: number): number {
  return epochMs - minutes * 60000;
}
