/**
 * HTTP client (source: core/network/di/NetworkModule.kt + interceptor/AuthInterceptor.kt)
 *
 * - BASE_URL https://mall.dusksnow.top/app/ (DATA-A01), JSON in / JSON out, unknown fields ignored.
 * - connect/read timeouts 10s; one retry on connection failure (DATA-A02, OkHttp retryOnConnectionFailure).
 * - Header `Authorization: <raw token>` only when a non-blank token exists (DATA-A03). The token comes
 *   from a provider registered by fnd-data (`HttpClient.setTokenProvider`) to avoid a reverse dependency
 *   on core/data.
 * - Every call resolves (never rejects) to a NetworkResponse envelope (DATA-A04). Network/transport
 *   exceptions and unparsable bodies become `code = -1, message = '网络请求失败'`; non-2xx HTTP status
 *   becomes `code = <status>, message = 'HTTP <status>'` (Retrofit HttpException equivalent).
 * - No 401 interception / auto logout (source has none, DATA-A05).
 */
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NetworkResponse } from '../model/Response';
import { LogUtils } from '../util/LogUtils';

/** Token provider: returns the raw token, or '' when not logged in */
export type TokenProvider = () => string;

export class HttpClient {
  /** Base URL (source BuildConfig.BASE_URL, same for dev/prod flavors) */
  static readonly BASE_URL: string = 'https://mall.dusksnow.top/app/';
  /** Timeout of the main API client in ms (source 10s connect/read/write) */
  static readonly TIMEOUT_MS: number = 10000;
  /** Code used for transport-level failures (no HTTP response / unparsable body) */
  static readonly NETWORK_ERROR_CODE: number = -1;
  /** Message used for transport-level failures (source fallback text) */
  static readonly NETWORK_ERROR_MESSAGE: string = '网络请求失败';

  private static readonly TAG: string = 'HttpClient';
  /** BusinessError codes treated as connection failures worth one retry (resolve host / connect) */
  private static readonly RETRY_CODES: number[] = [2300006, 2300007];

  private static tokenProvider: TokenProvider | null = null;

  /** Register the token provider (called once by fnd-data / AppState) */
  static setTokenProvider(provider: TokenProvider | null): void {
    HttpClient.tokenProvider = provider;
  }

  /** Current raw token ('' when none or provider failed) */
  static currentToken(): string {
    const provider = HttpClient.tokenProvider;
    if (provider === null) {
      return '';
    }
    try {
      const t = provider();
      return t === null || t === undefined ? '' : t;
    } catch (e) {
      return '';
    }
  }

  /** GET `BASE_URL + path` with optional query parameters */
  static get<T>(path: string, query?: Map<string, string>): Promise<NetworkResponse<T>> {
    let url = HttpClient.BASE_URL + path;
    if (query !== undefined && query !== null && query.size > 0) {
      const parts: string[] = [];
      query.forEach((value: string, key: string) => {
        parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
      });
      url = url + (url.includes('?') ? '&' : '?') + parts.join('&');
    }
    return HttpClient.execute<T>(http.RequestMethod.GET, url, undefined);
  }

  /** POST `BASE_URL + path` with an optional JSON body (serialized with JSON.stringify) */
  static post<T>(path: string, body?: Object): Promise<NetworkResponse<T>> {
    const url = HttpClient.BASE_URL + path;
    const payload: string | undefined = (body === undefined || body === null) ? undefined : JSON.stringify(body);
    return HttpClient.execute<T>(http.RequestMethod.POST, url, payload);
  }

  /** Build a failure envelope */
  static failure<T>(code: number, message: string): NetworkResponse<T> {
    const r = new NetworkResponse<T>();
    r.data = null;
    r.code = code;
    r.message = message;
    return r;
  }

  private static buildHeader(hasBody: boolean): Record<string, string> {
    const header: Record<string, string> = {
      'Accept': 'application/json'
    };
    if (hasBody) {
      header['Content-Type'] = 'application/json; charset=utf-8';
    }
    const token = HttpClient.currentToken();
    if (token.trim().length > 0) {
      header['Authorization'] = token;
    }
    return header;
  }

  private static async execute<T>(method: http.RequestMethod, url: string,
    payload: string | undefined): Promise<NetworkResponse<T>> {
    let attempt = 0;
    while (true) {
      attempt++;
      const client = http.createHttp();
      try {
        const options: http.HttpRequestOptions = {
          method: method,
          header: HttpClient.buildHeader(payload !== undefined),
          connectTimeout: HttpClient.TIMEOUT_MS,
          readTimeout: HttpClient.TIMEOUT_MS,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false
        };
        if (payload !== undefined) {
          options.extraData = payload;
        }
        const resp: http.HttpResponse = await client.request(url, options);
        if (LogUtils.isDebug()) {
          LogUtils.dTag(HttpClient.TAG, `${method} ${url} -> ${resp.responseCode}`);
        }
        return HttpClient.parseResponse<T>(resp);
      } catch (e) {
        const err = e as BusinessError;
        const code: number = (err !== null && err !== undefined && typeof err.code === 'number') ? err.code : 0;
        LogUtils.eTag(HttpClient.TAG, `${method} ${url} failed: code=${code} ${err?.message ?? ''}`);
        if (attempt < 2 && HttpClient.RETRY_CODES.includes(code)) {
          continue;
        }
        return HttpClient.failure<T>(HttpClient.NETWORK_ERROR_CODE, HttpClient.NETWORK_ERROR_MESSAGE);
      } finally {
        client.destroy();
      }
    }
  }

  private static parseResponse<T>(resp: http.HttpResponse): NetworkResponse<T> {
    const status: number = resp.responseCode as number;
    if (status < 200 || status >= 300) {
      return HttpClient.failure<T>(status, `HTTP ${status}`);
    }
    let text = '';
    if (typeof resp.result === 'string') {
      text = resp.result as string;
    } else if (resp.result !== null && resp.result !== undefined) {
      text = JSON.stringify(resp.result);
    }
    try {
      const parsed = JSON.parse(text) as NetworkResponse<T>;
      if (parsed === null || parsed === undefined || typeof (parsed as Object) !== 'object') {
        LogUtils.eTag(HttpClient.TAG, 'response body is not a JSON object');
        return HttpClient.failure<T>(HttpClient.NETWORK_ERROR_CODE, HttpClient.NETWORK_ERROR_MESSAGE);
      }
      const r = new NetworkResponse<T>();
      // Source defaults: data = null, code = 1000, message = null
      r.data = (parsed.data === undefined) ? null : parsed.data;
      r.code = (parsed.code === undefined || parsed.code === null) ? NetworkResponse.SUCCESS_CODE : Number(parsed.code);
      r.message = (parsed.message === undefined) ? null : parsed.message;
      return r;
    } catch (e) {
      LogUtils.eTag(HttpClient.TAG, `JSON parse error: ${(e as Error)?.message ?? ''}`);
      return HttpClient.failure<T>(HttpClient.NETWORK_ERROR_CODE, HttpClient.NETWORK_ERROR_MESSAGE);
    }
  }
}
