/**
 * SyncRestBodies —— 源 sync/RestBodies.kt + sync/Moshi.kt：Feeder Sync REST 报文体与 JSON 编解码（SY-A27/A28/A38/A39）。
 *
 * JSON 约定（源 Moshi + KotlinJsonAdapterFactory）：
 *  - 字段名 = camelCase 属性名；Instant ↔ epoch 毫秒整数；URL ↔ 字符串；null 值不输出（Moshi 默认 serializeNulls=false）。
 *  - 解析忽略未知字段；缺失字段取 Kotlin 默认值；必填字段（无默认值的非空属性）缺失/类型错 → 抛 SyncJsonDataException。
 *  - deviceId 为 Long：解析前把 `"deviceId": <整数>` 改写为字符串，保留超出 2^53 的精确值（DeviceIdRegistry 记录）。
 * EncryptedFeed.hashCode 逐位复刻 Kotlin data class / java List.hashCode（SY-A39）。
 */
import { JavaUrl } from '../../core/util/JavaUrl';
import {
  javaBooleanHashCode, javaInstantHashCode, javaListHashCode, javaStringHashCode, kotlinDataClassHashCode
} from '../../core/util/JavaHash';
import { Feed, OPEN_ARTICLE_WITH_APPLICATION_DEFAULT, EPOCH_MS } from '../../core/model/Feed';

export type JsonObj = Record<string, Object | null>;

/** com.squareup.moshi.JsonDataException / JsonEncodingException */
export class SyncJsonDataException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'JsonDataException';
  }
}

// ============================================================ deviceId 精确值

/** Long deviceId 的精确十进制串登记（number 键 → 原文）；用于请求头与路径 */
export class DeviceIdRegistry {
  private static exact: Map<number, string> = new Map<number, string>();
  private static persist: ((entries: Map<number, string>) => void) | null = null;

  static setPersister(cb: ((entries: Map<number, string>) => void) | null): void {
    DeviceIdRegistry.persist = cb;
  }

  static load(entries: Map<number, string>): void {
    entries.forEach((v: string, k: number) => {
      DeviceIdRegistry.exact.set(k, v);
    });
  }

  static register(exact: string): number {
    const n: number = Number(exact);
    if (!Number.isSafeInteger(n) && DeviceIdRegistry.exact.get(n) !== exact) {
      DeviceIdRegistry.exact.set(n, exact);
      const p: ((entries: Map<number, string>) => void) | null = DeviceIdRegistry.persist;
      if (p !== null) {
        p(DeviceIdRegistry.exact);
      }
    }
    return n;
  }

  /** Retrofit 对 Long 头/路径参数的 toString */
  static format(deviceId: number): string {
    const e: string | undefined = DeviceIdRegistry.exact.get(deviceId);
    if (e !== undefined) {
      return e;
    }
    return Math.trunc(deviceId).toFixed(0);
  }
}

function quoteLongField(text: string, field: string): string {
  return text.replace(new RegExp(`"${field}"\\s*:\\s*(-?[0-9]+)`, 'g'), `"${field}":"$1"`);
}

function parseRoot(text: string): JsonObj {
  let root: Object | null = null;
  try {
    root = JSON.parse(quoteLongField(text, 'deviceId')) as Object | null;
  } catch (e) {
    throw new SyncJsonDataException(`Malformed JSON: ${(e as Error).message}`);
  }
  if (!isObject(root)) {
    throw new SyncJsonDataException('Expected BEGIN_OBJECT');
  }
  return root as JsonObj;
}

function isObject(v: Object | null | undefined): boolean {
  return v !== null && v !== undefined && typeof v === 'object' && !Array.isArray(v);
}

function has(o: JsonObj, key: string): boolean {
  const v: Object | null | undefined = o[key];
  return v !== null && v !== undefined;
}

function reqStr(o: JsonObj, key: string): string {
  const v: Object | null | undefined = o[key];
  if (v === null || v === undefined) {
    throw new SyncJsonDataException(`Required value '${key}' missing`);
  }
  if (typeof v !== 'string') {
    throw new SyncJsonDataException(`Expected a string for '${key}'`);
  }
  return v as string;
}

function optStr(o: JsonObj, key: string, def: string): string {
  return has(o, key) ? reqStr(o, key) : def;
}

function reqNum(o: JsonObj, key: string): number {
  const v: Object | null | undefined = o[key];
  if (v === null || v === undefined) {
    throw new SyncJsonDataException(`Required value '${key}' missing`);
  }
  if (typeof v === 'number') {
    return v as number;
  }
  if (typeof v === 'string') {
    const n: number = Number(v as string);
    if (!isNaN(n)) {
      return n;
    }
  }
  throw new SyncJsonDataException(`Expected a number for '${key}'`);
}

function optNum(o: JsonObj, key: string, def: number): number {
  return has(o, key) ? reqNum(o, key) : def;
}

function optBool(o: JsonObj, key: string, def: boolean): boolean {
  if (!has(o, key)) {
    return def;
  }
  const v: Object | null | undefined = o[key];
  if (typeof v !== 'boolean') {
    throw new SyncJsonDataException(`Expected a boolean for '${key}'`);
  }
  return v as boolean;
}

function reqArr(o: JsonObj, key: string): Object[] {
  const v: Object | null | undefined = o[key];
  if (v === null || v === undefined) {
    throw new SyncJsonDataException(`Required value '${key}' missing`);
  }
  if (!Array.isArray(v)) {
    throw new SyncJsonDataException(`Expected an array for '${key}'`);
  }
  return v as Object[];
}

function asObj(v: Object): JsonObj {
  if (!isObject(v)) {
    throw new SyncJsonDataException('Expected BEGIN_OBJECT');
  }
  return v as JsonObj;
}

/** URLAdapter.fromJson：new URL(value)；toJson：URL.toString() */
function reqUrl(o: JsonObj, key: string): string {
  return JavaUrl.parse(reqStr(o, key)).toString();
}

/** Long deviceId（字符串化后的精确值） */
function reqDeviceId(o: JsonObj, key: string): number {
  const v: Object | null | undefined = o[key];
  if (typeof v === 'string') {
    return DeviceIdRegistry.register(v as string);
  }
  return reqNum(o, key);
}

/** JSON 字符串字面量（对端只做 JSON 解析，转义差异不影响互通） */
function q(s: string): string {
  return JSON.stringify(s);
}

// ============================================================ 请求 / 响应体

export class CreateRequest {
  deviceName: string = '';

  toJson(): string {
    return `{"deviceName":${q(this.deviceName)}}`;
  }
}

export class JoinRequest {
  deviceName: string = '';

  toJson(): string {
    return `{"deviceName":${q(this.deviceName)}}`;
  }
}

export class JoinResponse {
  syncCode: string = '';
  deviceId: number = 0;

  static fromJson(text: string): JoinResponse {
    const o: JsonObj = parseRoot(text);
    const r: JoinResponse = new JoinResponse();
    r.syncCode = reqStr(o, 'syncCode');
    r.deviceId = reqDeviceId(o, 'deviceId');
    return r;
  }
}

export class DeviceMessage {
  deviceId: number = 0;
  deviceName: string = '';
}

export class DeviceListResponse {
  devices: DeviceMessage[] = [];

  static fromJson(text: string): DeviceListResponse {
    const o: JsonObj = parseRoot(text);
    const r: DeviceListResponse = new DeviceListResponse();
    for (const raw of reqArr(o, 'devices')) {
      const d: JsonObj = asObj(raw);
      const m: DeviceMessage = new DeviceMessage();
      m.deviceId = reqDeviceId(d, 'deviceId');
      m.deviceName = reqStr(d, 'deviceName');
      r.devices.push(m);
    }
    return r;
  }
}

export class EncryptedReadMark {
  /** Instant（epoch ms） */
  timestamp: number = EPOCH_MS;
  /** Of type ReadMarkContent */
  encrypted: string = '';
}

export class GetEncryptedReadMarksResponse {
  readMarks: EncryptedReadMark[] = [];

  static fromJson(text: string): GetEncryptedReadMarksResponse {
    const o: JsonObj = parseRoot(text);
    const r: GetEncryptedReadMarksResponse = new GetEncryptedReadMarksResponse();
    for (const raw of reqArr(o, 'readMarks')) {
      const m: JsonObj = asObj(raw);
      const e: EncryptedReadMark = new EncryptedReadMark();
      e.timestamp = reqNum(m, 'timestamp');
      e.encrypted = reqStr(m, 'encrypted');
      r.readMarks.push(e);
    }
    return r;
  }
}

export class SendEncryptedReadMarkRequest {
  encrypted: string = '';
}

export class SendEncryptedReadMarkBulkRequest {
  items: SendEncryptedReadMarkRequest[] = [];

  toJson(): string {
    return `{"items":[${this.items.map((i: SendEncryptedReadMarkRequest): string => `{"encrypted":${q(i.encrypted)}}`)
      .join(',')}]}`;
  }
}

export class SendReadMarkResponse {
  timestamp: number = EPOCH_MS;

  static fromJson(text: string): SendReadMarkResponse {
    const o: JsonObj = parseRoot(text);
    const r: SendReadMarkResponse = new SendReadMarkResponse();
    r.timestamp = reqNum(o, 'timestamp');
    return r;
  }
}

export class ReadMarkContent {
  feedUrl: string = '';
  articleGuid: string = '';

  static of(feedUrl: string, articleGuid: string): ReadMarkContent {
    const c: ReadMarkContent = new ReadMarkContent();
    try {
      c.feedUrl = JavaUrl.parse(feedUrl).toString();
    } catch (e) {
      c.feedUrl = feedUrl;
    }
    c.articleGuid = articleGuid;
    return c;
  }

  toJson(): string {
    return `{"feedUrl":${q(this.feedUrl)},"articleGuid":${q(this.articleGuid)}}`;
  }

  /** Moshi fromJson：JSON 字面量 null → null */
  static fromJson(text: string): ReadMarkContent | null {
    if (text.trim() === 'null') {
      return null;
    }
    const o: JsonObj = parseRoot(text);
    const c: ReadMarkContent = new ReadMarkContent();
    c.feedUrl = reqUrl(o, 'feedUrl');
    c.articleGuid = reqStr(o, 'articleGuid');
    return c;
  }
}

export class UpdateFeedsRequest {
  contentHash: number = 0;
  /** Of type EncryptedFeeds */
  encrypted: string = '';

  toJson(): string {
    return `{"contentHash":${this.contentHash | 0},"encrypted":${q(this.encrypted)}}`;
  }
}

export class UpdateFeedsResponse {
  hash: number = 0;

  static fromJson(text: string): UpdateFeedsResponse {
    const o: JsonObj = parseRoot(text);
    const r: UpdateFeedsResponse = new UpdateFeedsResponse();
    r.hash = reqNum(o, 'hash') | 0;
    return r;
  }
}

export class GetFeedsResponse {
  hash: number = 0;
  /** Of type EncryptedFeeds */
  encrypted: string = '';

  static fromJson(text: string): GetFeedsResponse {
    const o: JsonObj = parseRoot(text);
    const r: GetFeedsResponse = new GetFeedsResponse();
    r.hash = reqNum(o, 'hash') | 0;
    r.encrypted = reqStr(o, 'encrypted');
    return r;
  }
}

// ============================================================ EncryptedFeed（SY-A38）

function urlHash(u: string | null): number {
  if (u === null) {
    return 0;
  }
  try {
    return JavaUrl.parse(u).javaHashCode();
  } catch (e) {
    return javaStringHashCode(u);
  }
}

export class EncryptedFeed {
  url: string = '';
  title: string = '';
  customTitle: string = '';
  tag: string = '';
  imageUrl: string | null = null;
  fullTextByDefault: boolean = false;
  openArticlesWith: string = OPEN_ARTICLE_WITH_APPLICATION_DEFAULT;
  alternateId: boolean = false;
  fetchOgImages: boolean = false;
  blockRules: string = '';
  allowRules: string = '';
  /** Instant（epoch ms） */
  whenModified: number = EPOCH_MS;

  /** Kotlin data class hashCode（字段声明顺序） */
  hashCode(): number {
    return kotlinDataClassHashCode([
      urlHash(this.url),
      javaStringHashCode(this.title),
      javaStringHashCode(this.customTitle),
      javaStringHashCode(this.tag),
      urlHash(this.imageUrl),
      javaBooleanHashCode(this.fullTextByDefault),
      javaStringHashCode(this.openArticlesWith),
      javaBooleanHashCode(this.alternateId),
      javaBooleanHashCode(this.fetchOgImages),
      javaStringHashCode(this.blockRules),
      javaStringHashCode(this.allowRules),
      javaInstantHashCode(this.whenModified),
    ]);
  }

  toJson(): string {
    let s: string = `{"url":${q(this.url)},"title":${q(this.title)},"customTitle":${q(this.customTitle)},` +
      `"tag":${q(this.tag)}`;
    if (this.imageUrl !== null) {
      s += `,"imageUrl":${q(this.imageUrl)}`;
    }
    s += `,"fullTextByDefault":${this.fullTextByDefault},"openArticlesWith":${q(this.openArticlesWith)},` +
      `"alternateId":${this.alternateId},"fetchOgImages":${this.fetchOgImages},"blockRules":${q(this.blockRules)},` +
      `"allowRules":${q(this.allowRules)},"whenModified":${Math.trunc(this.whenModified)}}`;
    return s;
  }

  static fromJsonObj(o: JsonObj): EncryptedFeed {
    const f: EncryptedFeed = new EncryptedFeed();
    f.url = reqUrl(o, 'url');
    f.title = optStr(o, 'title', '');
    f.customTitle = optStr(o, 'customTitle', '');
    f.tag = optStr(o, 'tag', '');
    f.imageUrl = has(o, 'imageUrl') ? reqUrl(o, 'imageUrl') : null;
    f.fullTextByDefault = optBool(o, 'fullTextByDefault', false);
    f.openArticlesWith = optStr(o, 'openArticlesWith', OPEN_ARTICLE_WITH_APPLICATION_DEFAULT);
    f.alternateId = optBool(o, 'alternateId', false);
    f.fetchOgImages = optBool(o, 'fetchOgImages', false);
    f.blockRules = optStr(o, 'blockRules', '');
    f.allowRules = optStr(o, 'allowRules', '');
    f.whenModified = optNum(o, 'whenModified', EPOCH_MS);
    return f;
  }

  /** 源 EncryptedFeed.updateFeedCopy(feed)：覆盖 12 个同步字段，其余保留 */
  updateFeedCopy(feed: Feed): Feed {
    const f: Feed = feed.copy();
    f.url = this.url;
    f.title = this.title;
    f.customTitle = this.customTitle;
    f.tag = this.tag;
    f.imageUrl = this.imageUrl;
    f.fullTextByDefault = this.fullTextByDefault;
    f.openArticlesWith = this.openArticlesWith;
    f.alternateId = this.alternateId;
    f.fetchOgImages = this.fetchOgImages;
    f.blockRules = this.blockRules;
    f.allowRules = this.allowRules;
    f.whenModified = this.whenModified;
    return f;
  }
}

/** 源 Feed.toEncryptedFeed() */
export function toEncryptedFeed(feed: Feed): EncryptedFeed {
  const e: EncryptedFeed = new EncryptedFeed();
  e.url = feed.url;
  e.title = feed.title;
  e.customTitle = feed.customTitle;
  e.tag = feed.tag;
  e.imageUrl = feed.imageUrl;
  e.fullTextByDefault = feed.fullTextByDefault;
  e.openArticlesWith = feed.openArticlesWith;
  e.alternateId = feed.alternateId;
  e.fetchOgImages = feed.fetchOgImages;
  e.blockRules = feed.blockRules;
  e.allowRules = feed.allowRules;
  e.whenModified = feed.whenModified;
  return e;
}

export class EncryptedFeeds {
  feeds: EncryptedFeed[] = [];

  toJson(): string {
    return `{"feeds":[${this.feeds.map((f: EncryptedFeed): string => f.toJson()).join(',')}]}`;
  }

  static fromJson(text: string): EncryptedFeeds | null {
    if (text.trim() === 'null') {
      return null;
    }
    const o: JsonObj = parseRoot(text);
    const r: EncryptedFeeds = new EncryptedFeeds();
    for (const raw of reqArr(o, 'feeds')) {
      r.feeds.push(EncryptedFeed.fromJsonObj(asObj(raw)));
    }
    return r;
  }
}

/** java List<EncryptedFeed>.hashCode() */
export function encryptedFeedsListHash(feeds: EncryptedFeed[]): number {
  return javaListHashCode(feeds.map((f: EncryptedFeed): number => f.hashCode()));
}

/** 源 Any.asWeakETagValue()：`W/"<value>"` */
export function asWeakETagValue(value: number): string {
  return `W/"${value}"`;
}

/** URL.equals 语义的比较（主机名忽略大小写、默认端口等价）；无法解析时回落字符串相等 */
export function urlEquals(a: string, b: string): boolean {
  if (a === b) {
    return true;
  }
  try {
    return JavaUrl.parse(a).equals(JavaUrl.parse(b));
  } catch (e) {
    return false;
  }
}
