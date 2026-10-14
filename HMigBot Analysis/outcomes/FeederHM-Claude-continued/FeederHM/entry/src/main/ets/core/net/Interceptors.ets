/**
 * Interceptors.ets —— 源 model/*Interceptor.kt 与 FeederApplication.kt 图片客户端内联拦截器的 ArkTS 等价物。
 * 拦截器挂载位置由 HttpClient 决定（见 HttpClient.ets 顶部注释）。
 */
import { bundleManager } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';
import { CacheControl, HttpRequest, HttpResponse, Interceptor, InterceptorChain } from './HttpMessages';
import { base64DecodeStrict, decodeLatin1, encodeUtf8 } from '../util/TextCodec';
import { RateLimiter } from './RateLimiter';
import { SettingsStore } from '../settings/SettingsStore';
import { javaIntRem, javaStringHashCode } from '../util/JavaHash';

// ---------------------------------------------------------------- User-Agent（FS-A13）

/**
 * 源 UserAgentInterceptor.kt:24 字面量（FS-A13 要求逐字一致）。
 * 注：conventions §C 曾写"平台串改 HarmonyOS"，但台账无已裁定降级，按源字面量实现。
 */
export const USER_AGENT_PRODUCT: string = 'SpaceCowboys Android RSS Reader';

let cachedUserAgent: string | null = null;

/** 源 USER_AGENT_STRING = "SpaceCowboys Android RSS Reader / ${VERSION_NAME}(${VERSION_CODE})" */
export function userAgentString(): string {
  if (cachedUserAgent === null) {
    let versionName = '';
    let versionCode = 0;
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      versionName = info.versionName;
      versionCode = info.versionCode;
    } catch (e) {
      console.warn(`FEEDER_UA: bundle info unavailable: ${JSON.stringify(e)}`);
    }
    cachedUserAgent = `${USER_AGENT_PRODUCT} / ${versionName}(${versionCode})`;
  }
  return cachedUserAgent as string;
}

/** 源 UserAgentInterceptor（网络拦截器）：覆盖 User-Agent */
export class UserAgentInterceptor implements Interceptor {
  static readonly INSTANCE: UserAgentInterceptor = new UserAgentInterceptor();

  intercept(chain: InterceptorChain): Promise<HttpResponse> {
    return chain.proceed(chain.request().withHeader('User-Agent', userAgentString()));
  }
}

// ---------------------------------------------------------------- 限速（FS-A15）

/** 源 RateLimitedInterceptor（网络拦截器）：按 request.url.host 限速 */
export class RateLimitedInterceptor implements Interceptor {
  static readonly INSTANCE: RateLimitedInterceptor = new RateLimitedInterceptor();

  intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const request = chain.request();
    return RateLimiter.rateLimited<HttpResponse>(request.host(), () => chain.proceed(request));
  }
}

// ---------------------------------------------------------------- 4xx 强制缓存（FS-A16）

/** 源 ForceCacheOnSomeFailuresInterceptor（网络拦截器，位于缓存层之下，改写后的头会被缓存） */
export class ForceCacheOnSomeFailuresInterceptor implements Interceptor {
  static readonly INSTANCE: ForceCacheOnSomeFailuresInterceptor = new ForceCacheOnSomeFailuresInterceptor();

  async intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const response = await chain.proceed(chain.request());
    // 服务端已设 cache-control 时不覆盖
    if (response.headerValues('cache-control').length > 0) {
      return response;
    }
    if (response.code >= 400 && response.code <= 499) {
      console.debug(`FEEDER: cache-control forced for code ${response.code}`);
      const r = response.copy();
      r.headers.set('cache-control', 'max-age=3600');
      r.headers.remove('pragma');
      r.headers.remove('expires');
      r.headers.remove('x-cache');
      return r;
    }
    return response;
  }
}

// ---------------------------------------------------------------- 429（FS-A17）

/** onlyIfCached + maxStale(Int.MAX) + maxAge(Int.MAX) */
export function onlyIfCachedForever(): CacheControl {
  const cc = new CacheControl();
  cc.onlyIfCached = true;
  cc.maxStaleSeconds = CacheControl.INT_MAX;
  cc.maxAgeSeconds = CacheControl.INT_MAX;
  return cc;
}

/** Kotlin String.toIntOrNull */
function toIntOrNull(s: string | null): number | null {
  if (s === null || !new RegExp('^[+-]?\\d+$').test(s)) {
    return null;
  }
  const v = Number(s);
  return v > 2147483647 || v < -2147483648 ? null : v;
}

/**
 * 源 TooManyRequestsInterceptor：收到网络 429 后，在 Retry-After（缺失/非整数按 60）+1 秒窗口内，
 * 该主机的请求改为 only-if-cached（无缓存得 504）。
 * 照源挂为第 4 个网络拦截器（FeederApplication.kt:129，APP-A71）：位于缓存层之下，窗口内的 onlyIfCached
 * 与源一致只作为请求头发往服务器；网络拦截器只见网络响应，故仅网络 429 计时。
 */
export class TooManyRequestsInterceptor implements Interceptor {
  static readonly INSTANCE: TooManyRequestsInterceptor = new TooManyRequestsInterceptor();

  private tooManyResponses: Map<string, number> = new Map<string, number>();

  /** 主机当前是否处于 429 窗口 */
  isBlocked(host: string, now: number): boolean {
    const until = this.tooManyResponses.get(host);
    return until !== undefined && until > now;
  }

  blockedUntil(host: string): number | null {
    const until = this.tooManyResponses.get(host);
    return until !== undefined ? until : null;
  }

  async intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const request = chain.request();
    const host = request.host();
    const now = Date.now();
    if (this.isBlocked(host, now)) {
      console.info(`FEEDER_TOOMANY: Too many requests for ${host}, blocked until ${this.tooManyResponses.get(host)}`);
      return chain.proceed(request.withCacheControl(onlyIfCachedForever()));
    }
    // Drop the host
    this.tooManyResponses.delete(host);
    const response = await chain.proceed(request);
    if (response.code === 429 && response.networkUsed && !this.tooManyResponses.has(host)) {
      const parsed = toIntOrNull(response.header('Retry-After'));
      const retryAfterSeconds = parsed !== null ? parsed : 60;
      console.info(`FEEDER_TOOMANY: Too many requests for ${host}, will intercept for ${retryAfterSeconds} seconds`);
      this.tooManyResponses.set(host, now + (retryAfterSeconds + 1) * 1000);
    }
    return response;
  }

  resetForTest(): void {
    this.tooManyResponses.clear();
  }
}

// ---------------------------------------------------------------- 图片客户端（FS-A21 / FS-A22）

/** 源 AlwaysUseCacheIfPossibleRequestsInterceptor（应用拦截器）：maxStale 30 天 + maxAge 7 天 */
export class AlwaysUseCacheIfPossibleRequestsInterceptor implements Interceptor {
  static readonly INSTANCE: AlwaysUseCacheIfPossibleRequestsInterceptor = new AlwaysUseCacheIfPossibleRequestsInterceptor();

  intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const cc = new CacheControl();
    cc.maxStaleSeconds = 30 * 24 * 3600;
    cc.maxAgeSeconds = 7 * 24 * 3600;
    return chain.proceed(chain.request().withCacheControl(cc));
  }
}

/** 源 util/SystemUtils.kt currentlyUnmetered：isActiveNetworkMetered 取不到时按"非计费" */
export function currentlyUnmetered(): boolean {
  try {
    return !connection.isDefaultNetMeteredSync();
  } catch (e) {
    console.warn(`FEEDER: isDefaultNetMetered failed: ${JSON.stringify(e)}`);
    return true;
  }
}

/**
 * 源 FeederApplication.kt:166 图片客户端内联应用拦截器：
 * `!loadImageOnlyOnWifi || currentlyUnmetered` 时原样请求，否则 onlyIfCached（无缓存则 504）。
 */
export class ImageOnlyOnWifiInterceptor implements Interceptor {
  static readonly INSTANCE: ImageOnlyOnWifiInterceptor = new ImageOnlyOnWifiInterceptor();

  intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const request = chain.request();
    if (!SettingsStore.instance().loadImageOnlyOnWifi || currentlyUnmetered()) {
      return chain.proceed(request);
    }
    return chain.proceed(request.withCacheControl(onlyIfCachedForever()));
  }
}

/** 协程 Mutex 等价：FIFO 串行 */
export class AsyncMutex {
  private tail: Promise<void> = Promise.resolve();

  async withLock<T>(block: () => Promise<T>): Promise<T> {
    const prev = this.tail;
    let release: () => void = () => {
      console.debug('AsyncMutex: release before assign');
    };
    this.tail = new Promise<void>((resolve) => {
      release = () => {
        resolve();
      };
    });
    await prev;
    try {
      return await block();
    } finally {
      release();
    }
  }
}

/**
 * 源 OneImageRequestPerHostInterceptor（Coil 拦截器）：主机名 hashCode % 8 分桶（可为负，最多 15 把锁），
 * 同一把锁内同一时刻只发一个图片请求；非 http 开头（data: 等）与无主机不加锁。
 */
export class OneImageRequestPerHostInterceptor implements Interceptor {
  static readonly INSTANCE: OneImageRequestPerHostInterceptor = new OneImageRequestPerHostInterceptor();
  static readonly MAX_LOCKS: number = 8;

  private inProgressHosts: Map<number, AsyncMutex> = new Map<number, AsyncMutex>();

  /** 锁桶号：host.hashCode() % MAX_LOCKS（Java 取余） */
  static bucketOf(host: string): number {
    return javaIntRem(javaStringHashCode(host), OneImageRequestPerHostInterceptor.MAX_LOCKS);
  }

  /** 对任意图片加载过程加锁（供不经 HttpClient 的图片管线复用） */
  withLock<T>(url: string, block: () => Promise<T>): Promise<T> {
    if (!url.startsWith('http')) {
      return block();
    }
    const host = new HttpRequest(url).host();
    if (host.length === 0) {
      return block();
    }
    const bucket = OneImageRequestPerHostInterceptor.bucketOf(host);
    let mutex = this.inProgressHosts.get(bucket);
    if (mutex === undefined) {
      mutex = new AsyncMutex();
      this.inProgressHosts.set(bucket, mutex);
    }
    console.debug(`FEEDER_IMAGE: Loading image [${host}] ${url}`);
    return (mutex as AsyncMutex).withLock<T>(block);
  }

  intercept(chain: InterceptorChain): Promise<HttpResponse> {
    const request = chain.request();
    return this.withLock<HttpResponse>(request.url, () => chain.proceed(request));
  }
}

// ---------------------------------------------------------------- data: 图片（FS-A22：不加锁，但照常加载）

/** 是否 data: URL（RFC 2397，scheme 大小写不敏感） */
export function isDataUrl(url: string): boolean {
  return url.length >= 5 && url.substring(0, 5).toLowerCase() === 'data:';
}

function isHexChar(c: string): boolean {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/** 百分号解码为字节（非转义字符按 UTF-8 编码；'+' 不当空格） */
function percentDecodeToBytes(s: string): Uint8Array {
  const out: number[] = [];
  let runStart = 0;
  const flush = (end: number): void => {
    if (end > runStart) {
      const b = encodeUtf8(s.substring(runStart, end));
      for (let k = 0; k < b.length; k++) {
        out.push(b[k]);
      }
    }
  };
  let i = 0;
  while (i < s.length) {
    if (s.charAt(i) === '%' && i + 2 < s.length && isHexChar(s.charAt(i + 1)) && isHexChar(s.charAt(i + 2))) {
      flush(i);
      out.push(parseInt(s.substring(i + 1, i + 3), 16));
      i += 3;
      runStart = i;
    } else {
      i++;
    }
  }
  flush(s.length);
  return new Uint8Array(out);
}

/**
 * 解码 data: URL（data:[<mediatype>][;base64],<data>）为合成 200 响应（Coil 对 data: 的加载等价物）；
 * 格式非法返回 null。base64 容忍空白、URL-safe 字母表与缺失填充。
 */
export function decodeDataUrl(url: string): HttpResponse | null {
  if (!isDataUrl(url)) {
    return null;
  }
  const comma = url.indexOf(',');
  if (comma < 0) {
    return null;
  }
  let meta = url.substring(5, comma);
  const payload = url.substring(comma + 1);
  let isBase64 = false;
  const lastSemi = meta.lastIndexOf(';');
  if (lastSemi >= 0 && meta.substring(lastSemi + 1).trim().toLowerCase() === 'base64') {
    isBase64 = true;
    meta = meta.substring(0, lastSemi);
  }
  const raw = percentDecodeToBytes(payload);
  let bytes: Uint8Array;
  if (isBase64) {
    let b64 = decodeLatin1(raw).replace(new RegExp('\\s+', 'g'), '')
      .replace(new RegExp('-', 'g'), '+').replace(new RegExp('_', 'g'), '/');
    while (b64.length % 4 !== 0) {
      b64 += '=';
    }
    const decoded = base64DecodeStrict(b64);
    if (decoded === null) {
      return null;
    }
    bytes = decoded;
  } else {
    bytes = raw;
  }
  const mediaType = meta.trim();
  const r = new HttpResponse();
  r.code = 200;
  r.message = 'OK';
  r.headers.set('content-type', mediaType.length > 0 && mediaType.indexOf('/') > 0 ? mediaType : 'text/plain;charset=US-ASCII');
  const body = new ArrayBuffer(bytes.length);
  new Uint8Array(body).set(bytes);
  r.body = body;
  r.finalUrl = url;
  r.request = new HttpRequest(url);
  r.sentRequestAtMillis = Date.now();
  r.receivedResponseAtMillis = r.sentRequestAtMillis;
  r.fromCache = false;
  r.networkUsed = false;
  return r;
}
