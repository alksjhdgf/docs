/**
 * HttpClient.ets —— 全工程唯一 HTTP 客户端（@kit.NetworkKit http）。
 * 源：FeederApplication.kt:119-205（OkHttpClient / 图片客户端拼装）、jsonfeed/OkHttpBuilderExtensions.kt（cachingHttpClient）、
 *     model/FeedParser.kt:345 OkHttpClient.getResponse（forceNetwork 与 userinfo Basic 认证）。
 *
 * 调用链（对应 OkHttp 的拦截器栈）：
 *   应用拦截器(config.interceptors) → [认证重试] → 缓存层(HttpDiskCache + CacheStrategy) → 网络拦截器(config.networkInterceptors) → 传输(@kit.NetworkKit)
 * 主客户端 HttpClient.main()：缓存 cacheDir/http 200MB；连接/读取超时各 30s；跟随重定向（FS-A14）；
 *   应用拦截器 []；网络拦截器 [UserAgent, RateLimited, ForceCacheOnSomeFailures, TooManyRequests]（源 FeederApplication.kt:126-129，APP-A71）。
 * 图片客户端 HttpClient.images()：独立缓存 cacheDir/http_image_cache 300MB（FS-A21）；
 *   应用拦截器 [OneImageRequestPerHost(Coil 层), AlwaysUseCacheIfPossible, ImageOnlyOnWifi]；网络拦截器同主客户端（newBuilder 继承，含 TooManyRequests）。
 * 使用前由应用初始化调用 HttpClient.init(new FilePathProvider(ctx.cacheDir, ctx.filesDir))；未 init 时无磁盘缓存。
 */
import { http } from '@kit.NetworkKit';
import { encodeUtf8Buffer } from '../util/TextCodec';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  basicCredentials,
  CacheControl,
  HttpHeaders,
  HttpRequest,
  HttpResponse,
  Interceptor,
  InterceptorChain,
  stripUserInfo
} from './HttpMessages';
import { HttpDiskCache } from './HttpCache';
import { computeCacheStrategy, combineHeaders, invalidatesCache, isCacheable } from './CacheStrategy';
import {
  AlwaysUseCacheIfPossibleRequestsInterceptor,
  ForceCacheOnSomeFailuresInterceptor,
  decodeDataUrl,
  ImageOnlyOnWifiInterceptor,
  isDataUrl,
  OneImageRequestPerHostInterceptor,
  RateLimitedInterceptor,
  TooManyRequestsInterceptor,
  UserAgentInterceptor
} from './Interceptors';
import { NetworkError, NetworkIOException, NetworkResult, NetworkSuccess, NetworkHttpError, toError } from './NetworkResult';
import { FilePathProvider } from '../util/Constants';
import { JavaUrl } from '../util/JavaUrl';
import { javaUrlDecode } from '../util/JavaCodec';

const LOG_TAG: string = 'FEEDER_HTTP';

export const MAIN_HTTP_CACHE_SIZE: number = 200 * 1024 * 1024;
export const IMAGE_HTTP_CACHE_SIZE: number = 300 * 1024 * 1024;
/** 源 FeederApplication.kt:185-189 Coil DiskCache：cacheDir/image_cache，maxSizeBytes 200MB（APP-A72） */
export const IMAGE_DISK_CACHE_SIZE: number = 200 * 1024 * 1024;
/** OkHttp 跟随重定向上限（RetryAndFollowUpInterceptor MAX_FOLLOW_UPS） */
const MAX_FOLLOW_UPS: number = 20;

export class HttpClientConfig {
  connectTimeoutMs: number = 30000;
  readTimeoutMs: number = 30000;
  followRedirects: boolean = true;
  /** @kit.NetworkKit 默认只收 5MB；放宽到其上限 100MB */
  maxResponseBytes: number = 100 * 1024 * 1024;
  /** 源 cachingHttpClient(trustAllCerts = true)：不校验证书链与主机名（自签名 feed 可用）→ remoteValidation 'skip' */
  trustAllCerts: boolean = true;
  cache: HttpDiskCache | null = null;
  interceptors: Interceptor[] = [];
  networkInterceptors: Interceptor[] = [];

  copy(): HttpClientConfig {
    const c = new HttpClientConfig();
    c.connectTimeoutMs = this.connectTimeoutMs;
    c.readTimeoutMs = this.readTimeoutMs;
    c.followRedirects = this.followRedirects;
    c.maxResponseBytes = this.maxResponseBytes;
    c.trustAllCerts = this.trustAllCerts;
    c.cache = this.cache;
    c.interceptors = this.interceptors.slice();
    c.networkInterceptors = this.networkInterceptors.slice();
    return c;
  }
}

type ChainTerminal = (request: HttpRequest) => Promise<HttpResponse>;

class RealChain implements InterceptorChain {
  private readonly interceptors: Interceptor[];
  private readonly index: number;
  private readonly req: HttpRequest;
  private readonly terminal: ChainTerminal;

  constructor(interceptors: Interceptor[], index: number, req: HttpRequest, terminal: ChainTerminal) {
    this.interceptors = interceptors;
    this.index = index;
    this.req = req;
    this.terminal = terminal;
  }

  request(): HttpRequest {
    return this.req;
  }

  proceed(request: HttpRequest): Promise<HttpResponse> {
    if (this.index >= this.interceptors.length) {
      return this.terminal(request);
    }
    const next = new RealChain(this.interceptors, this.index + 1, request, this.terminal);
    return this.interceptors[this.index].intercept(next);
  }
}

/** OkHttp authenticator / proxyAuthenticator（FS-A12）：401/407 时带 Basic 凭据重试；已带过对应头不再重试 */
export class BasicAuthInterceptor implements Interceptor {
  private readonly credentials: string;

  constructor(credentials: string) {
    this.credentials = credentials;
  }

  async intercept(chain: InterceptorChain): Promise<HttpResponse> {
    let request = chain.request();
    let response = await chain.proceed(request);
    for (let i = 0; i < MAX_FOLLOW_UPS; i++) {
      let next: HttpRequest | null = null;
      if (response.code === 401 && request.header('Authorization') === null) {
        next = request.withHeader('Authorization', this.credentials);
      } else if (response.code === 407 && request.header('Proxy-Authorization') === null) {
        next = request.withHeader('Proxy-Authorization', this.credentials);
      }
      if (next === null) {
        return response;
      }
      request = next;
      response = await chain.proceed(request);
    }
    return response;
  }
}

/** 原生遇 3xx 时不跟随：终止并以该 3xx 响应作为请求结果（由 HttpClient.transport 逐跳跟随） */
class RedirectStopper implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.REDIRECTION;

  async interceptorHandle(reqContext: http.HttpRequestContext, rspContext: http.HttpResponse): Promise<boolean> {
    return false;
  }
}

const REASON_PHRASES: Map<number, string> = new Map<number, string>([
  [200, 'OK'], [201, 'Created'], [202, 'Accepted'], [203, 'Non-Authoritative Information'], [204, 'No Content'],
  [206, 'Partial Content'], [300, 'Multiple Choices'], [301, 'Moved Permanently'], [302, 'Found'],
  [303, 'See Other'], [304, 'Not Modified'], [307, 'Temporary Redirect'], [308, 'Permanent Redirect'],
  [400, 'Bad Request'], [401, 'Unauthorized'], [403, 'Forbidden'], [404, 'Not Found'],
  [405, 'Method Not Allowed'], [406, 'Not Acceptable'], [407, 'Proxy Authentication Required'],
  [408, 'Request Timeout'], [410, 'Gone'], [414, 'URI Too Long'], [415, 'Unsupported Media Type'],
  [429, 'Too Many Requests'], [500, 'Internal Server Error'], [501, 'Not Implemented'], [502, 'Bad Gateway'],
  [503, 'Service Unavailable'], [504, 'Gateway Timeout']
]);

function toRequestMethod(method: string): http.RequestMethod {
  switch (method) {
    case 'POST':
      return http.RequestMethod.POST;
    case 'PUT':
      return http.RequestMethod.PUT;
    case 'DELETE':
      return http.RequestMethod.DELETE;
    case 'HEAD':
      return http.RequestMethod.HEAD;
    case 'OPTIONS':
      return http.RequestMethod.OPTIONS;
    default:
      return http.RequestMethod.GET;
  }
}

export class HttpClient {
  private static mainCache: HttpDiskCache | null = null;
  private static imageCache: HttpDiskCache | null = null;
  private static coilDiskCache: HttpDiskCache | null = null;
  private static mainClient: HttpClient | null = null;
  private static imageClient: HttpClient | null = null;

  readonly config: HttpClientConfig;

  constructor(config: HttpClientConfig) {
    this.config = config;
  }

  /** 应用初始化时调用：建立主/图片磁盘缓存（FS-A14 200MB / FS-A21 300MB）。幂等。 */
  static init(paths: FilePathProvider): void {
    if (HttpClient.mainCache !== null && HttpClient.mainCache.directory === paths.httpCacheDir) {
      return;
    }
    HttpClient.mainCache = new HttpDiskCache(paths.httpCacheDir, MAIN_HTTP_CACHE_SIZE);
    HttpClient.imageCache = new HttpDiskCache(paths.httpImageCacheDir, IMAGE_HTTP_CACHE_SIZE);
    HttpClient.coilDiskCache = new HttpDiskCache(paths.imageCacheDir, IMAGE_DISK_CACHE_SIZE);
    HttpClient.mainClient = null;
    HttpClient.imageClient = null;
  }

  /** 图片加载器自身的磁盘缓存（≙ Coil DiskCache，位于 HTTP 层之上；未 init 时为 null） */
  static imageDiskCache(): HttpDiskCache | null {
    return HttpClient.coilDiskCache;
  }

  /** 源 bind<OkHttpClient>() 单例 */
  static main(): HttpClient {
    if (HttpClient.mainClient === null) {
      const c = new HttpClientConfig();
      c.cache = HttpClient.mainCache;
      // APP-A71：源 FeederApplication.kt:126-129 全部为 addNetworkInterceptor，顺序 UA → RateLimited → ForceCache → TooManyRequests
      c.interceptors = [];
      c.networkInterceptors = [
        UserAgentInterceptor.INSTANCE,
        RateLimitedInterceptor.INSTANCE,
        ForceCacheOnSomeFailuresInterceptor.INSTANCE,
        TooManyRequestsInterceptor.INSTANCE
      ];
      HttpClient.mainClient = new HttpClient(c);
    }
    return HttpClient.mainClient as HttpClient;
  }

  /** 源 ImageLoader 使用的 okHttpClient（主客户端 newBuilder + 独立缓存 + 应用拦截器）+ Coil OneImageRequestPerHost */
  static images(): HttpClient {
    if (HttpClient.imageClient === null) {
      const c = HttpClient.main().config.copy();
      c.cache = HttpClient.imageCache;
      c.interceptors = [
        OneImageRequestPerHostInterceptor.INSTANCE,
        AlwaysUseCacheIfPossibleRequestsInterceptor.INSTANCE,
        ImageOnlyOnWifiInterceptor.INSTANCE
      ];
      HttpClient.imageClient = new HttpClient(c);
    }
    return HttpClient.imageClient as HttpClient;
  }

  /** OkHttpClient.newBuilder()：复制配置 */
  newConfig(): HttpClientConfig {
    return this.config.copy();
  }

  /** 追加应用拦截器（位于已有应用拦截器之后、缓存层之前），返回新客户端 */
  withInterceptor(interceptor: Interceptor): HttpClient {
    const c = this.config.copy();
    c.interceptors.push(interceptor);
    return new HttpClient(c);
  }

  /** Call.execute()：IO 失败抛 NetworkIOException；任何 HTTP 状态码都正常返回 */
  execute(request: HttpRequest): Promise<HttpResponse> {
    const cacheTerminal: ChainTerminal = (r: HttpRequest) => this.cacheLayer(r);
    return new RealChain(this.config.interceptors, 0, request, cacheTerminal).proceed(request);
  }

  /** 结果化执行：不抛异常 */
  async fetch(request: HttpRequest): Promise<NetworkResult<HttpResponse>> {
    try {
      const resp = await this.execute(request);
      if (resp.isSuccessful()) {
        return new NetworkSuccess<HttpResponse>(resp);
      }
      return new NetworkHttpError<HttpResponse>(resp.code, resp.message, resp.finalUrl, resp.retryAfterSeconds());
    } catch (e) {
      return new NetworkError<HttpResponse>(toError(e as Object), request.url);
    }
  }

  get(url: string, headers?: Map<string, string>): Promise<HttpResponse> {
    return this.execute(HttpClient.build(url, 'GET', null, null, headers));
  }

  post(url: string, body: string | ArrayBuffer, contentType: string | null, headers?: Map<string, string>): Promise<HttpResponse> {
    return this.execute(HttpClient.build(url, 'POST', body, contentType, headers));
  }

  put(url: string, body: string | ArrayBuffer, contentType: string | null, headers?: Map<string, string>): Promise<HttpResponse> {
    return this.execute(HttpClient.build(url, 'PUT', body, contentType, headers));
  }

  deleteRequest(url: string, headers?: Map<string, string>): Promise<HttpResponse> {
    return this.execute(HttpClient.build(url, 'DELETE', null, null, headers));
  }

  private static build(url: string, method: string, body: string | ArrayBuffer | null, contentType: string | null,
    headers?: Map<string, string>): HttpRequest {
    const r = new HttpRequest(url);
    r.method = method;
    r.body = body;
    if (headers !== undefined) {
      headers.forEach((v: string, k: string) => {
        r.headers.set(k, v);
      });
    }
    if (contentType !== null) {
      r.headers.set('Content-Type', contentType);
    }
    return r;
  }

  /**
   * 源 OkHttpClient.getResponse(url, forceNetwork)（FeedParser.kt:345）：
   * - forceNetwork：Cache-Control: max-age=60（条件请求，但 1 分钟内的缓存仍命中）（FS-A11）；
   * - URL 含非空白 userinfo：用户名/密码分别 URLDecoder.decode 后，401/407 时以 Basic 认证重试（FS-A12）。
   * IO 失败抛 NetworkIOException；URL 非法抛 MalformedURLException（由 JavaUrl.parse）。
   */
  async getResponse(url: string, forceNetwork: boolean = false): Promise<HttpResponse> {
    const parsed = JavaUrl.parse(url);
    let client: HttpClient = this;
    let target = url;
    const userInfo = parsed.userInfo;
    if (userInfo !== null && userInfo.trim().length > 0) {
      const parts = userInfo.split(':');
      const user = parts[0];
      const pass = parts.length > 1 ? parts[1] : '';
      const credentials = basicCredentials(javaUrlDecode(user), javaUrlDecode(pass));
      client = this.withInterceptor(new BasicAuthInterceptor(credentials));
      target = stripUserInfo(url);
    }
    let request = HttpRequest.get(target);
    if (forceNetwork) {
      // Set a low max age to perform a conditional request, but preventing spamming the server
      request = request.withCacheControl(CacheControl.maxAge(60));
    }
    return client.execute(request);
  }

  /**
   * 图片获取（应走 HttpClient.images()）。data: URL 不经网络、不加主机锁，直接解码为合成 200 响应（照源 Coil
   * 对 data: 的正常加载；FS-A22）；格式非法或其他非 http(s) scheme 返回 NetworkError。
   */
  async fetchImage(url: string): Promise<NetworkResult<HttpResponse>> {
    if (isDataUrl(url)) {
      const decoded = decodeDataUrl(url);
      if (decoded === null) {
        return new NetworkError<HttpResponse>(new Error(`Malformed data url: ${url.substring(0, 32)}`), url);
      }
      return new NetworkSuccess<HttpResponse>(decoded);
    }
    if (!url.startsWith('http')) {
      return new NetworkError<HttpResponse>(new Error(`Not an http(s) image url: ${url.substring(0, 32)}`), url);
    }
    return this.fetch(HttpRequest.get(url));
  }

  // ------------------------------------------------------------ 缓存层（OkHttp CacheInterceptor）

  private async cacheLayer(request: HttpRequest): Promise<HttpResponse> {
    const cache = this.config.cache;
    const candidate = cache !== null ? await cache.get(request) : null;
    const strategy = computeCacheStrategy(Date.now(), request, candidate);
    const networkRequest = strategy.networkRequest;
    const cacheResponse = strategy.cacheResponse;

    if (networkRequest === null && cacheResponse === null) {
      const r = new HttpResponse();
      r.code = 504;
      r.message = 'Unsatisfiable Request (only-if-cached)';
      r.body = new ArrayBuffer(0);
      r.finalUrl = request.url;
      r.request = request;
      r.sentRequestAtMillis = -1;
      r.receivedResponseAtMillis = Date.now();
      return r;
    }
    if (networkRequest === null) {
      const hit = (cacheResponse as HttpResponse).copy();
      hit.request = request;
      return hit;
    }

    const networkResponse = await this.networkChain(networkRequest);

    if (cacheResponse !== null && networkResponse.code === 304) {
      const combined = cacheResponse.copy();
      combined.headers = combineHeaders(cacheResponse.headers, networkResponse.headers);
      combined.sentRequestAtMillis = networkResponse.sentRequestAtMillis;
      combined.receivedResponseAtMillis = networkResponse.receivedResponseAtMillis;
      combined.request = networkResponse.request;
      combined.fromCache = true;
      combined.networkUsed = true;
      if (cache !== null) {
        await cache.put(combined);
      }
      combined.request = request;
      return combined;
    }

    if (cache !== null) {
      const promisesBody = networkResponse.request.method !== 'HEAD' && networkResponse.code !== 204 &&
        networkResponse.code !== 304 && !(networkResponse.code >= 100 && networkResponse.code < 200);
      if (promisesBody && isCacheable(networkResponse, networkRequest)) {
        await cache.put(networkResponse);
      }
      if (invalidatesCache(networkRequest.method)) {
        await cache.remove(networkRequest.url);
      }
    }
    return networkResponse;
  }

  private networkChain(request: HttpRequest): Promise<HttpResponse> {
    const transport: ChainTerminal = (r: HttpRequest) => this.transport(r);
    return new RealChain(this.config.networkInterceptors, 0, request, transport).proceed(request);
  }

  // ------------------------------------------------------------ 传输（@kit.NetworkKit http）

  /**
   * 源 OkHttp RetryAndFollowUpInterceptor 的跟随语义：最多 20 次跟随；301/302/303 且非 GET/HEAD 改 GET 并去 body
   * （307/308 保留方法与 body）；跨主机去 Authorization；最终 URL = 最后一跳请求 URL（源 response.request.url）。
   * 不用 @kit.NetworkKit 原生跟随：实测 http→https 301 跟随后 ARRAY_BUFFER 结果只剩末段（8172 字节），正文被截断
   * （与是否挂 REDIRECTION 拦截器无关），故逐跳以 maxRedirects=0 发出、自行跟随。
   */
  private async transport(request: HttpRequest): Promise<HttpResponse> {
    let current: HttpRequest = request;
    for (let followUps = 0; ; followUps++) {
      const r: HttpResponse = await this.transportOnce(current);
      r.finalUrl = current.url;
      if (!this.config.followRedirects || !r.isRedirect()) {
        return r;
      }
      const location: string | null = r.header('location');
      if (location === null || location.trim().length === 0) {
        return r;
      }
      let from: JavaUrl;
      let to: JavaUrl;
      try {
        from = JavaUrl.parse(current.url);
        to = JavaUrl.parse(location.trim(), from);
      } catch (e) {
        return r;
      }
      if (to.protocol !== 'http' && to.protocol !== 'https') {
        return r;
      }
      if (followUps + 1 > MAX_FOLLOW_UPS) {
        throw new NetworkIOException(`Too many follow-up requests: ${followUps + 1}`, request.url, -1);
      }
      const next: HttpRequest = current.copy();
      next.url = to.toString();
      const keepMethod: boolean = r.code === 307 || r.code === 308;
      if (!keepMethod && current.method !== 'GET' && current.method !== 'HEAD') {
        next.method = 'GET';
        next.body = null;
        next.headers.remove('Content-Type');
        next.headers.remove('Content-Length');
        next.headers.remove('Transfer-Encoding');
      }
      if (from.host.toLowerCase() !== to.host.toLowerCase()) {
        next.headers.remove('Authorization');
      }
      current = next;
    }
  }

  private async transportOnce(request: HttpRequest): Promise<HttpResponse> {
    const httpRequest = http.createHttp();
    const sentAt = Date.now();
    const options: http.HttpRequestOptions = {
      method: toRequestMethod(request.method),
      header: request.headers.toRecord(),
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      connectTimeout: this.config.connectTimeoutMs,
      readTimeout: this.config.readTimeoutMs,
      maxLimit: this.config.maxResponseBytes
    };
    if (request.body !== null) {
      options.extraData = request.body;
    }
    if (this.config.trustAllCerts) {
      options.remoteValidation = 'skip';
    }
    // 重定向由 transport() 逐跳跟随（见其注释）：REDIRECTION 拦截器返回 false 终止原生跟随并把该 3xx 响应作为结果返回
    // （maxRedirects=0 不可用：遇 3xx 直接报 "The number of redirections reaches the maximum allowed"）
    try {
      const interceptorChain = new http.HttpInterceptorChain();
      if (!(interceptorChain.addChain([new RedirectStopper()]) && interceptorChain.apply(httpRequest))) {
        console.warn(`${LOG_TAG}: redirect stopper not applied`);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: redirect stopper unavailable: ${JSON.stringify(e)}`);
    }
    try {
      const raw = await httpRequest.request(request.url, options);
      const r = new HttpResponse();
      r.code = raw.responseCode as number;
      r.request = request;
      r.sentRequestAtMillis = sentAt;
      r.receivedResponseAtMillis = Date.now();
      r.networkUsed = true;
      r.fromCache = false;
      let statusMessage: string | null = null;
      const headerObj = raw.header as Record<string, Object>;
      if (headerObj !== null && headerObj !== undefined) {
        for (const k of Object.keys(headerObj)) {
          const status = new RegExp('^HTTP/\\S+\\s+\\d{3}\\s*(.*)$').exec(k);
          if (status !== null) {
            statusMessage = status[1].trim();
            continue;
          }
          const v = headerObj[k];
          if (Array.isArray(v)) {
            for (const item of (v as Object[])) {
              r.headers.add(k, String(item));
            }
          } else if (v !== null && v !== undefined) {
            r.headers.add(k, String(v));
          }
        }
      }
      const reason = REASON_PHRASES.get(r.code);
      r.message = statusMessage !== null ? statusMessage : (reason !== undefined ? reason : '');
      const result = raw.result;
      if (result instanceof ArrayBuffer) {
        r.body = result as ArrayBuffer;
      } else if (typeof result === 'string') {
        r.body = encodeUtf8Buffer(result as string);
      } else {
        r.body = null;
      }
      r.finalUrl = request.url;
      return r;
    } catch (e) {
      const err = e as BusinessError;
      const code = err !== null && err !== undefined && typeof err.code === 'number' ? err.code : -1;
      const msg = err !== null && err !== undefined && err.message !== undefined ? err.message : String(e);
      console.warn(`${LOG_TAG}: ${request.method} ${request.url} failed: ${code} ${msg}`);
      throw new NetworkIOException(msg, request.url, code);
    } finally {
      httpRequest.destroy();
    }
  }

  /** 清空本客户端的磁盘缓存 */
  async clearCache(): Promise<void> {
    const cache = this.config.cache;
    if (cache !== null) {
      await cache.evictAll();
    }
  }
}

/** 取响应头（小写名 → 值）的便捷函数 */
export function headersToMap(h: HttpHeaders): Map<string, string> {
  return h.toMap();
}
