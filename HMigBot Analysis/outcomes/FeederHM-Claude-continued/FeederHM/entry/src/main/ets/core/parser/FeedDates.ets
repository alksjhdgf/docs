/**
 * FeedDates.ets —— gofeed shared.ParseDate 的等价实现 + Go time.Time JSON 输出格式（RFC3339Nano）。
 *
 * gofeed 逐个尝试一长串 Go 布局（RFC822/RFC1123/RFC3339 及大量变体）。此处以等价的宽容语法解析：
 *  - ISO 8601 / RFC3339：`2006-01-02`、`2006-01-02T15:04[:05[.frac]]`、`2006-01-02 15:04:05`，后接可选时区
 *    （`Z`、`±hh:mm`、`±hhmm`、`±hh`、时区缩写），日期分隔符也接受 '/'。
 *  - RFC822/RFC1123 族：`[Mon,] 2 Jan 2006 15:04[:05] [zone]`（两位年、全称月、缺逗号、`-` 分隔均接受）。
 *  - UnixDate/ANSIC：`Mon Jan _2 15:04:05 [MST] 2006`。
 *  - `January 2, 2006 [15:04[:05] [PM]] [zone]`。
 * 无时区时按 UTC（Go time.Parse 语义）。时区缩写：gofeed 先以 time.Parse 得到零偏移的"虚构时区"，再尝试
 * time.LoadLocation(缩写)：只有 tz 数据库中存在的名字（EST/MST/HST/CET/EET/WET/MET/UTC/GMT…）才得到真实偏移，
 * 其余（EDT/PDT/CEST…）保持零偏移。
 */

const MONTHS: string[] = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const FULL_MONTHS: string[] = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september',
  'october', 'november', 'december'];

/** time.LoadLocation 能加载的缩写（tzdata 中的同名区）→ 标准偏移（秒） */
const LOADABLE_ZONES: Map<string, number> = new Map<string, number>([
  ['UTC', 0], ['UT', 0], ['GMT', 0], ['Z', 0], ['UCT', 0], ['ZULU', 0], ['UNIVERSAL', 0], ['GREENWICH', 0],
  ['EST', -5 * 3600], ['MST', -7 * 3600], ['HST', -10 * 3600], ['CET', 3600], ['MET', 3600], ['EET', 2 * 3600],
  ['WET', 0]
]);

/** Go time.Time：秒级 epoch + 小数秒数字串 + 偏移 */
export class GoTime {
  /** UTC epoch 秒（整数） */
  epochSeconds: number;
  /** 小数秒数字（不含点，最多 9 位，可为空） */
  fraction: string;
  /** 时区偏移（秒） */
  offsetSeconds: number;

  constructor(epochSeconds: number, fraction: string, offsetSeconds: number) {
    this.epochSeconds = epochSeconds;
    this.fraction = fraction;
    this.offsetSeconds = offsetSeconds;
  }

  /** time.UTC() */
  utc(): GoTime {
    return new GoTime(this.epochSeconds, this.fraction, 0);
  }

  epochMillis(): number {
    const ms: number = this.fraction.length > 0 ? Math.floor(Number('0.' + this.fraction) * 1000) : 0;
    return this.epochSeconds * 1000 + ms;
  }

  /** Go time.MarshalJSON（RFC3339Nano："2006-01-02T15:04:05.999999999Z07:00"） */
  toRfc3339Nano(): string {
    const local: number = this.epochSeconds + this.offsetSeconds;
    const days: number = Math.floor(local / 86400);
    const secOfDay: number = local - days * 86400;
    const ymd: number[] = civilFromDays(days);
    const hh: number = Math.floor(secOfDay / 3600);
    const mm: number = Math.floor((secOfDay % 3600) / 60);
    const ss: number = secOfDay % 60;
    let s: string = `${pad(ymd[0], 4)}-${pad(ymd[1], 2)}-${pad(ymd[2], 2)}T${pad(hh, 2)}:${pad(mm, 2)}:${pad(ss, 2)}`;
    let frac: string = this.fraction;
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    if (frac.length > 0) {
      s += '.' + frac;
    }
    if (this.offsetSeconds === 0) {
      return s + 'Z';
    }
    const sign: string = this.offsetSeconds < 0 ? '-' : '+';
    const abs: number = Math.abs(this.offsetSeconds);
    return s + `${sign}${pad(Math.floor(abs / 3600), 2)}:${pad(Math.floor((abs % 3600) / 60), 2)}`;
  }
}

function pad(n: number, width: number): string {
  let s: string = `${Math.abs(n)}`;
  while (s.length < width) {
    s = '0' + s;
  }
  return n < 0 ? '-' + s : s;
}

/** Howard Hinnant days_from_civil */
export function daysFromCivil(y: number, m: number, d: number): number {
  const yy: number = m <= 2 ? y - 1 : y;
  const era: number = Math.floor(yy / 400);
  const yoe: number = yy - era * 400;
  const mp: number = (m + 9) % 12;
  const doy: number = Math.floor((153 * mp + 2) / 5) + d - 1;
  const doe: number = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}

/** Howard Hinnant civil_from_days → [y, m, d] */
export function civilFromDays(z0: number): number[] {
  const z: number = z0 + 719468;
  const era: number = Math.floor(z / 146097);
  const doe: number = z - era * 146097;
  const yoe: number = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const doy: number = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp: number = Math.floor((5 * doy + 2) / 153);
  const d: number = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const m: number = mp < 10 ? mp + 3 : mp - 9;
  const y: number = yoe + era * 400 + (m <= 2 ? 1 : 0);
  return [y, m, d];
}

function isLeap(y: number): boolean {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

function daysInMonth(y: number, m: number): number {
  const dm: number[] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return m === 2 && isLeap(y) ? 29 : dm[m - 1];
}

function monthIndex(name: string): number {
  const l: string = name.toLowerCase();
  for (let i = 0; i < 12; i++) {
    if (l === MONTHS[i] || l === FULL_MONTHS[i] || (l.length >= 3 && FULL_MONTHS[i].startsWith(l) && l.length <= 4)) {
      return i + 1;
    }
  }
  return 0;
}

/** Go 两位年：>= 69 → 19xx，否则 20xx */
function expandYear(y: string): number {
  const v: number = parseInt(y, 10);
  if (y.length <= 2) {
    return v >= 69 ? 1900 + v : 2000 + v;
  }
  return v;
}

/** 时区串 → 偏移秒；无法识别返回 null。空串 → 0（UTC）。 */
function parseZone(zoneRaw: string): number | null {
  let zone: string = zoneRaw.trim();
  // 去掉尾随的括号注释，如 "-0400 (EDT)"
  zone = zone.replace(new RegExp('\\s*\\([^)]*\\)\\s*$'), '').trim();
  if (zone.length === 0) {
    return 0;
  }
  const num: RegExpMatchArray | null = zone.match(new RegExp('^(?:(?:GMT|UTC|UT)\\s*)?([+-])(\\d{1,2}):?(\\d{2})?$', 'i'));
  if (num !== null) {
    const h: number = parseInt(num[2], 10);
    const mi: number = num[3] !== undefined ? parseInt(num[3], 10) : 0;
    if (h > 23 || mi > 59) {
      return null;
    }
    const v: number = h * 3600 + mi * 60;
    return num[1] === '-' ? -v : v;
  }
  if (new RegExp('^[A-Za-z]{1,6}$').test(zone)) {
    const known: number | undefined = LOADABLE_ZONES.get(zone.toUpperCase());
    // gofeed：LoadLocation 失败 → 保持 time.Parse 的零偏移虚构时区
    return known !== undefined ? known : 0;
  }
  return null;
}

function build(y: number, mo: number, d: number, h: number, mi: number, s: number, frac: string,
  offset: number): GoTime | null {
  if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo) || h > 23 || mi > 59 || s > 59) {
    return null;
  }
  const local: number = daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s;
  return new GoTime(local - offset, frac.length > 9 ? frac.substring(0, 9) : frac, offset);
}

function num(s: string | undefined): number {
  return s === undefined || s.length === 0 ? 0 : parseInt(s, 10);
}

function str(s: string | undefined): string {
  return s === undefined ? '' : s;
}

function to24h(h: number, ampm: string): number {
  const a: string = ampm.toLowerCase();
  if (a === 'pm' && h < 12) {
    return h + 12;
  }
  if (a === 'am' && h === 12) {
    return 0;
  }
  return h;
}

const ISO_RE: RegExp = new RegExp(
  '^(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})(?:[Tt ]+(\\d{1,2}):(\\d{2})(?::(\\d{2})(?:[.,](\\d+))?)?)?\\s*(.*)$');
const RFC822_RE: RegExp = new RegExp(
  '^(?:[A-Za-z]+\\.?,?\\s*)?(\\d{1,2})[\\s\\-]+([A-Za-z]+)\\.?,?[\\s\\-]+(\\d{2,4}),?(?:[\\sT]+(\\d{1,2}):(\\d{1,2})(?::(\\d{1,2})(?:\\.(\\d+))?)?)?\\s*(.*)$');
const UNIX_RE: RegExp = new RegExp(
  '^[A-Za-z]+,?\\s+([A-Za-z]+)\\s+(\\d{1,2}),?\\s+(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s+(?:(.+?)\\s+)?(\\d{4})$');
const MONTH_FIRST_RE: RegExp = new RegExp(
  '^(?:[A-Za-z]+,?\\s+)?([A-Za-z]+)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})(?:,?\\s+(?:at\\s+)?(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s*([AaPp][Mm])?)?\\s*(.*)$');

/**
 * 源 gofeed shared.ParseDate：失败返回 null（Go 返回 error）。
 */
export function parseFeedDate(ds: string | null): GoTime | null {
  if (ds === null) {
    return null;
  }
  const d: string = ds.trim();
  if (d.length === 0) {
    return null;
  }
  let m: RegExpMatchArray | null = d.match(ISO_RE);
  if (m !== null) {
    const off: number | null = parseZone(str(m[8]));
    if (off === null) {
      return null;
    }
    return build(num(m[1]), num(m[2]), num(m[3]), num(m[4]), num(m[5]), num(m[6]), str(m[7]), off);
  }
  m = d.match(RFC822_RE);
  if (m !== null) {
    const mo: number = monthIndex(m[2]);
    const off: number | null = parseZone(str(m[8]));
    if (mo > 0 && off !== null) {
      return build(expandYear(m[3]), mo, num(m[1]), num(m[4]), num(m[5]), num(m[6]), str(m[7]), off);
    }
  }
  m = d.match(UNIX_RE);
  if (m !== null) {
    const mo: number = monthIndex(m[1]);
    const off: number | null = parseZone(str(m[6]));
    if (mo > 0 && off !== null) {
      return build(num(m[7]), mo, num(m[2]), num(m[3]), num(m[4]), num(m[5]), '', off);
    }
  }
  m = d.match(MONTH_FIRST_RE);
  if (m !== null) {
    const mo: number = monthIndex(m[1]);
    const off: number | null = parseZone(str(m[8]));
    if (mo > 0 && off !== null) {
      const h: number = m[7] !== undefined ? to24h(num(m[4]), m[7]) : num(m[4]);
      return build(num(m[3]), mo, num(m[2]), h, num(m[5]), num(m[6]), '', off);
    }
  }
  return null;
}

/** RSS pubDate / Atom updated|published：ParseDate 成功则转 UTC 并输出 JSON 时间串 */
export function parsedUtcDateString(ds: string | null): string | null {
  const t: GoTime | null = parseFeedDate(ds);
  return t !== null ? t.utc().toRfc3339Nano() : null;
}

/** dc:date / JSON Feed：ParseDate 成功则保留原偏移输出 */
export function parsedDateString(ds: string | null): string | null {
  const t: GoTime | null = parseFeedDate(ds);
  return t !== null ? t.toRfc3339Nano() : null;
}
