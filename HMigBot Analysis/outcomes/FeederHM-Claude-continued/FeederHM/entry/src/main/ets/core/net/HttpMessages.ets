/**
 * HttpMessages.ets —— HTTP 报文模型（OkHttp Request/Response/Headers/CacheControl/MediaType 的等价物）与拦截器契约。
 * 从 HttpClient.ets 拆出以避免 HttpClient ↔ HttpCache ↔ Interceptors 循环 import（单文件 ≤600 行）。
 */
import { base64Encode, decodeCharset } from '../util/TextCodec';

// ---------------------------------------------------------------- Headers

/** 有序多值头；名称一律存小写（HarmonyOS 侧约定 headers 小写），查找大小写不敏感。 */
export class HttpHeaders {
  private names: string[] = [];
  private vals: string[] = [];

  static of(pairs: string[][]): HttpHeaders {
    const h = new HttpHeaders();
    for (const p of pairs) {
      if (p.length >= 2) {
        h.add(p[0], p[1]);
      }
    }
    return h;
  }

  /** 最后一个同名值（OkHttp Headers.get 语义），无则 null */
  get(name: string): string | null {
    const n = name.toLowerCase();
    for (let i = this.names.length - 1; i >= 0; i--) {
      if (this.names[i] === n) {
        return this.vals[i];
      }
    }
    return null;
  }

  /** 全部同名值（OkHttp Headers.values） */
  values(name: string): string[] {
    const n = name.toLowerCase();
    const out: string[] = [];
    for (let i = 0; i < this.names.length; i++) {
      if (this.names[i] === n) {
        out.push(this.vals[i]);
      }
    }
    return out;
  }

  has(name: string): boolean {
    return this.get(name) !== null;
  }

  add(name: string, value: string): HttpHeaders {
    this.names.push(name.toLowerCase());
    this.vals.push(value);
    return this;
  }

  /** 替换全部同名值 */
  set(name: string, value: string): HttpHeaders {
    this.remove(name);
    return this.add(name, value);
  }

  remove(name: string): HttpHeaders {
    const n = name.toLowerCase();
    for (let i = this.names.length - 1; i >= 0; i--) {
      if (this.names[i] === n) {
        this.names.splice(i, 1);
        this.vals.splice(i, 1);
      }
    }
    return this;
  }

  size(): number {
    return this.names.length;
  }

  nameAt(i: number): string {
    return this.names[i];
  }

  valueAt(i: number): string {
    return this.vals[i];
  }

  /** 去重后的名称集合（小写，按首次出现顺序） */
  nameSet(): string[] {
    const out: string[] = [];
    for (const n of this.names) {
      if (out.indexOf(n) < 0) {
        out.push(n);
      }
    }
    return out;
  }

  /** 小写名 → 值（同名多值以 ", " 合并） */
  toMap(): Map<string, string> {
    const m = new Map<string, string>();
    for (let i = 0; i < this.names.length; i++) {
      const prev = m.get(this.names[i]);
      m.set(this.names[i], prev !== undefined ? prev + ', ' + this.vals[i] : this.vals[i]);
    }
    return m;
  }

  /** 给 @kit.NetworkKit http 的 header 选项 */
  toRecord(): Record<string, string> {
    const r: Record<string, string> = {};
    this.toMap().forEach((v: string, k: string) => {
      r[k] = v;
    });
    return r;
  }

  copy(): HttpHeaders {
    const h = new HttpHeaders();
    h.names = this.names.slice();
    h.vals = this.vals.slice();
    return h;
  }

  toString(): string {
    let s = '';
    for (let i = 0; i < this.names.length; i++) {
      s += `${this.names[i]}: ${this.vals[i]}\n`;
    }
    return s;
  }
}

// ---------------------------------------------------------------- CacheControl

/** OkHttp CacheControl：解析 Cache-Control 与 Pragma；toString 顺序照 OkHttp。秒数 -1 表示未设置。 */
export class CacheControl {
  static readonly INT_MAX: number = 2147483647;

  noCache: boolean = false;
  noStore: boolean = false;
  maxAgeSeconds: number = -1;
  sMaxAgeSeconds: number = -1;
  isPrivate: boolean = false;
  isPublic: boolean = false;
  mustRevalidate: boolean = false;
  maxStaleSeconds: number = -1;
  minFreshSeconds: number = -1;
  onlyIfCached: boolean = false;
  noTransform: boolean = false;
  immutable: boolean = false;

  /** OkHttp CacheControl.parse(headers) */
  static parse(headers: HttpHeaders): CacheControl {
    const cc = new CacheControl();
    for (let i = 0; i < headers.size(); i++) {
      const name = headers.nameAt(i);
      if (name !== 'cache-control' && name !== 'pragma') {
        continue;
      }
      const value = headers.valueAt(i);
      let pos = 0;
      while (pos < value.length) {
        const tokenStart = pos;
        pos = CacheControl.indexOfAny(value, '=,;', pos);
        const directive = value.substring(tokenStart, pos).trim().toLowerCase();
        let parameter: string | null = null;
        if (pos === value.length || value.charAt(pos) === ',' || value.charAt(pos) === ';') {
          pos++;
        } else {
          pos++; // '='
          while (pos < value.length && (value.charAt(pos) === ' ' || value.charAt(pos) === '\t')) {
            pos++;
          }
          if (pos < value.length && value.charAt(pos) === '"') {
            pos++;
            const start = pos;
            const end = value.indexOf('"', pos);
            pos = end < 0 ? value.length : end;
            parameter = value.substring(start, pos);
            pos++;
          } else {
            const start = pos;
            pos = CacheControl.indexOfAny(value, ',;', pos);
            parameter = value.substring(start, pos).trim();
          }
        }
        CacheControl.applyDirective(cc, directive, parameter);
      }
    }
    return cc;
  }

  private static applyDirective(cc: CacheControl, directive: string, parameter: string | null): void {
    if (directive === 'no-cache') {
      cc.noCache = true;
    } else if (directive === 'no-store') {
      cc.noStore = true;
    } else if (directive === 'max-age') {
      cc.maxAgeSeconds = CacheControl.toNonNegativeInt(parameter, -1);
    } else if (directive === 's-maxage') {
      cc.sMaxAgeSeconds = CacheControl.toNonNegativeInt(parameter, -1);
    } else if (directive === 'private') {
      cc.isPrivate = true;
    } else if (directive === 'public') {
      cc.isPublic = true;
    } else if (directive === 'must-revalidate') {
      cc.mustRevalidate = true;
    } else if (directive === 'max-stale') {
      cc.maxStaleSeconds = CacheControl.toNonNegativeInt(parameter, CacheControl.INT_MAX);
    } else if (directive === 'min-fresh') {
      cc.minFreshSeconds = CacheControl.toNonNegativeInt(parameter, -1);
    } else if (directive === 'only-if-cached') {
      cc.onlyIfCached = true;
    } else if (directive === 'no-transform') {
      cc.noTransform = true;
    } else if (directive === 'immutable') {
      cc.immutable = true;
    }
  }

  private static indexOfAny(s: string, chars: string, from: number): number {
    for (let i = from; i < s.length; i++) {
      if (chars.indexOf(s.charAt(i)) >= 0) {
        return i;
      }
    }
    return s.length;
  }

  /** OkHttp toNonNegativeInt：非数字返回默认，超 Int 截到 INT_MAX，负数为 0 */
  private static toNonNegativeInt(s: string | null, defaultValue: number): number {
    if (s === null || !new RegExp('^-?\\d+$').test(s)) {
      return defaultValue;
    }
    const v = Number(s);
    if (v > CacheControl.INT_MAX) {
      return CacheControl.INT_MAX;
    }
    return v < 0 ? 0 : v;
  }

  /** 源 CacheControl.Builder().maxAge(seconds) */
  static maxAge(seconds: number): CacheControl {
    const cc = new CacheControl();
    cc.maxAgeSeconds = seconds;
    return cc;
  }

  /** OkHttp toString 指令顺序 */
  toString(): string {
    const parts: string[] = [];
    if (this.noCache) {
      parts.push('no-cache');
    }
    if (this.noStore) {
      parts.push('no-store');
    }
    if (this.maxAgeSeconds !== -1) {
      parts.push(`max-age=${this.maxAgeSeconds}`);
    }
    if (this.sMaxAgeSeconds !== -1) {
      parts.push(`s-maxage=${this.sMaxAgeSeconds}`);
    }
    if (this.isPrivate) {
      parts.push('private');
    }
    if (this.isPublic) {
      parts.push('public');
    }
    if (this.mustRevalidate) {
      parts.push('must-revalidate');
    }
    if (this.maxStaleSeconds !== -1) {
      parts.push(`max-stale=${this.maxStaleSeconds}`);
    }
    if (this.minFreshSeconds !== -1) {
      parts.push(`min-fresh=${this.minFreshSeconds}`);
    }
    if (this.onlyIfCached) {
      parts.push('only-if-cached');
    }
    if (this.noTransform) {
      parts.push('no-transform');
    }
    if (this.immutable) {
      parts.push('immutable');
    }
    return parts.join(', ');
  }
}

// ---------------------------------------------------------------- MediaType

/** OkHttp MediaType：type/subtype 小写，charset 参数；toString 返回原串 */
export class MediaType {
  readonly type: string;
  readonly subtype: string;
  readonly charset: string | null;
  private readonly raw: string;

  private constructor(raw: string, type: string, subtype: string, charset: string | null) {
    this.raw = raw;
    this.type = type;
    this.subtype = subtype;
    this.charset = charset;
  }

  /** toMediaTypeOrNull：非法返回 null */
  static parse(s: string | null): MediaType | null {
    if (s === null) {
      return null;
    }
    const m = new RegExp('^\\s*([a-zA-Z0-9!#$%&\'*+.^_`{|}~-]+)/([a-zA-Z0-9!#$%&\'*+.^_`{|}~-]+)').exec(s);
    if (m === null) {
      return null;
    }
    let charset: string | null = null;
    const params = s.substring(m[0].length).split(';');
    for (const p of params) {
      const eq = p.indexOf('=');
      if (eq < 0) {
        continue;
      }
      const name = p.substring(0, eq).trim().toLowerCase();
      let value = p.substring(eq + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      if (name === 'charset' && value.length > 0) {
        charset = value;
      }
    }
    return new MediaType(s, m[1].toLowerCase(), m[2].toLowerCase(), charset);
  }

  toString(): string {
    return this.raw;
  }
}

// ---------------------------------------------------------------- Request

export class HttpRequest {
  url: string;
  method: string = 'GET';
  headers: HttpHeaders = new HttpHeaders();
  body: string | ArrayBuffer | null = null;

  constructor(url: string) {
    this.url = url;
  }

  static get(url: string): HttpRequest {
    return new HttpRequest(url);
  }

  header(name: string): string | null {
    return this.headers.get(name);
  }

  copy(): HttpRequest {
    const r = new HttpRequest(this.url);
    r.method = this.method;
    r.headers = this.headers.copy();
    r.body = this.body;
    return r;
  }

  /** newBuilder().header(name, value).build() */
  withHeader(name: string, value: string): HttpRequest {
    const r = this.copy();
    r.headers.set(name, value);
    return r;
  }

  /** newBuilder().cacheControl(cc).build()：空指令时移除 Cache-Control */
  withCacheControl(cc: CacheControl): HttpRequest {
    const r = this.copy();
    const v = cc.toString();
    if (v.length === 0) {
      r.headers.remove('Cache-Control');
    } else {
      r.headers.set('Cache-Control', v);
    }
    return r;
  }

  cacheControl(): CacheControl {
    return CacheControl.parse(this.headers);
  }

  /** request.url.host（小写；解析失败为空串） */
  host(): string {
    return hostOf(this.url);
  }
}

/** 取 URL 主机名（小写，去掉 userinfo/端口/IPv6 方括号保留），失败返回空串 */
export function hostOf(u: string): string {
  const m = new RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*://([^/?#]*)').exec(u);
  if (m === null) {
    return '';
  }
  let authority = m[1];
  const at = authority.lastIndexOf('@');
  if (at >= 0) {
    authority = authority.substring(at + 1);
  }
  if (authority.startsWith('[')) {
    const end = authority.indexOf(']');
    return (end > 0 ? authority.substring(0, end + 1) : authority).toLowerCase();
  }
  const colon = authority.indexOf(':');
  return (colon >= 0 ? authority.substring(0, colon) : authority).toLowerCase();
}

// ---------------------------------------------------------------- Response

export class HttpResponse {
  code: number = 0;
  message: string = '';
  /** 响应头（名称小写） */
  headers: HttpHeaders = new HttpHeaders();
  /** 原始字节；HEAD/无体时为空 ArrayBuffer；底层无结果时为 null */
  body: ArrayBuffer | null = null;
  /** 重定向后的最终 URL（源 response.request.url） */
  finalUrl: string = '';
  /** 产生本响应的请求（拦截器改写后的） */
  request: HttpRequest = new HttpRequest('');
  sentRequestAtMillis: number = 0;
  receivedResponseAtMillis: number = 0;
  /** 来自缓存（含 304 合并后的条目） */
  fromCache: boolean = false;
  /** 走过网络（条件请求 304 时 fromCache 与 networkUsed 同为 true） */
  networkUsed: boolean = false;

  isSuccessful(): boolean {
    return this.code >= 200 && this.code < 300;
  }

  isRedirect(): boolean {
    return this.code === 300 || this.code === 301 || this.code === 302 || this.code === 303 ||
      this.code === 307 || this.code === 308;
  }

  header(name: string): string | null {
    return this.headers.get(name);
  }

  headerValues(name: string): string[] {
    return this.headers.values(name);
  }

  /** 小写名 → 值 */
  headerMap(): Map<string, string> {
    return this.headers.toMap();
  }

  contentType(): MediaType | null {
    return MediaType.parse(this.headers.get('content-type'));
  }

  cacheControl(): CacheControl {
    return CacheControl.parse(this.headers);
  }

  /**
   * 源 RssLocalSync.kt:596 Response.retryAfterSeconds：所有 retry-after 头取最大，非整数按 3600；无头为 null（FS-A18）。
   */
  retryAfterSeconds(): number | null {
    const vs = this.headers.values('retry-after');
    if (vs.length === 0) {
      return null;
    }
    let max = -Infinity;
    for (const v of vs) {
      const t = v.trim();
      const n = new RegExp('^[+-]?\\d+$').test(t) ? Number(t) : 3600;
      if (n > max) {
        max = n;
      }
    }
    return max;
  }

  /** body.bytes() */
  bytes(): Uint8Array {
    return this.body !== null ? new Uint8Array(this.body) : new Uint8Array(0);
  }

  /**
   * body.string()：BOM 优先，其次 charset 参数（或 Content-Type 的 charset），默认 UTF-8；未知字符集回落 UTF-8。
   */
  text(charset?: string): string {
    return decodeBytes(this.bytes(), charset !== undefined ? charset : this.contentTypeCharset());
  }

  private contentTypeCharset(): string | null {
    const ct = this.contentType();
    return ct !== null ? ct.charset : null;
  }

  copy(): HttpResponse {
    const r = new HttpResponse();
    r.code = this.code;
    r.message = this.message;
    r.headers = this.headers.copy();
    r.body = this.body;
    r.finalUrl = this.finalUrl;
    r.request = this.request;
    r.sentRequestAtMillis = this.sentRequestAtMillis;
    r.receivedResponseAtMillis = this.receivedResponseAtMillis;
    r.fromCache = this.fromCache;
    r.networkUsed = this.networkUsed;
    return r;
  }
}

/** 按 BOM / 声明字符集解码字节（OkHttp readString(charset = bom ?: declared ?: UTF_8)） */
export function decodeBytes(bytes: Uint8Array, declared: string | null): string {
  let label = declared !== null && declared.length > 0 ? declared : 'utf-8';
  let offset = 0;
  if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
    label = 'utf-8';
    offset = 3;
  } else if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
    label = 'utf-16be';
    offset = 2;
  } else if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
    label = 'utf-16le';
    offset = 2;
  }
  const data = offset > 0 ? bytes.subarray(offset) : bytes;
  return decodeCharset(data, label);
}

// ---------------------------------------------------------------- 认证辅助（FS-A12）

/** okhttp3.Credentials.basic(user, pass)：ISO-8859-1 编码（不可映射字符为 '?'）后 Base64 */
export function basicCredentials(username: string, password: string): string {
  const s = username + ':' + password;
  const bytes = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    bytes[i] = c <= 0xFF ? c : 0x3F;
  }
  return 'Basic ' + base64Encode(bytes);
}

/** 去掉 URL 中的 userinfo（交给传输层的 URL 不带凭据，凭据只在质询后经 Authorization 发送） */
export function stripUserInfo(url: string): string {
  const m = new RegExp('^([a-zA-Z][a-zA-Z0-9+.-]*://)([^/?#]*)').exec(url);
  if (m === null) {
    return url;
  }
  const at = m[2].lastIndexOf('@');
  if (at < 0) {
    return url;
  }
  return m[1] + m[2].substring(at + 1) + url.substring(m[0].length);
}

// ---------------------------------------------------------------- Interceptor contract

/** OkHttp Interceptor.Chain */
export interface InterceptorChain {
  request(): HttpRequest;

  proceed(request: HttpRequest): Promise<HttpResponse>;
}

/** OkHttp Interceptor */
export interface Interceptor {
  intercept(chain: InterceptorChain): Promise<HttpResponse>;
}
