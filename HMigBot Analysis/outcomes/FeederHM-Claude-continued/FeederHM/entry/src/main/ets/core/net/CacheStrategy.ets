/**
 * CacheStrategy.ets —— OkHttp CacheStrategy / CacheInterceptor 判定逻辑的纯函数移植（无 Kit 依赖，便于单测）。
 * 新鲜度、条件请求（ETag → If-None-Match；Last-Modified/Date → If-Modified-Since）、only-if-cached 收敛、304 头合并。
 */
import { HttpHeaders, HttpRequest, HttpResponse } from './HttpMessages';

// ---------------------------------------------------------------- 日期

/** HTTP 日期解析（RFC 1123 / RFC 850 / asctime）；失败 null */
export function parseHttpDate(s: string | null): number | null {
  if (s === null) {
    return null;
  }
  const t = Date.parse(s.trim());
  return isNaN(t) ? null : t;
}

/** RFC 1123 格式 */
export function formatHttpDate(ms: number): string {
  return new Date(ms).toUTCString();
}

// ---------------------------------------------------------------- 策略

export class CacheStrategy {
  networkRequest: HttpRequest | null = null;
  cacheResponse: HttpResponse | null = null;
}

/** OkHttp CacheStrategy.isCacheable */
export function isCacheable(response: HttpResponse, request: HttpRequest): boolean {
  const code = response.code;
  const cacheableByCode = code === 200 || code === 203 || code === 204 || code === 300 || code === 301 ||
    code === 404 || code === 405 || code === 410 || code === 414 || code === 501 || code === 308;
  if (!cacheableByCode) {
    if (code !== 302 && code !== 307) {
      return false;
    }
    // 302/307 仅在有显式过期信息时可缓存
    const rcc = response.cacheControl();
    if (response.header('expires') === null && rcc.maxAgeSeconds === -1 && !rcc.isPublic && !rcc.isPrivate) {
      return false;
    }
  }
  return !response.cacheControl().noStore && !request.cacheControl().noStore;
}

/** OkHttp HttpMethod.invalidatesCache */
export function invalidatesCache(method: string): boolean {
  return method === 'POST' || method === 'PATCH' || method === 'PUT' || method === 'DELETE' || method === 'MOVE';
}

function hasConditions(request: HttpRequest): boolean {
  return request.header('If-Modified-Since') !== null || request.header('If-None-Match') !== null;
}

/** OkHttp CacheStrategy.Factory.cacheResponseAge */
function cacheResponseAge(nowMillis: number, cached: HttpResponse): number {
  const servedDate = parseHttpDate(cached.header('date'));
  const apparentReceivedAge = servedDate !== null ? Math.max(0, cached.receivedResponseAtMillis - servedDate) : 0;
  const ageHeader = cached.header('age');
  const ageSeconds = ageHeader !== null && new RegExp('^\\d+$').test(ageHeader.trim()) ? Number(ageHeader.trim()) : -1;
  const receivedAge = ageSeconds !== -1 ? Math.max(apparentReceivedAge, ageSeconds * 1000) : apparentReceivedAge;
  const responseDuration = cached.receivedResponseAtMillis - cached.sentRequestAtMillis;
  const residentDuration = nowMillis - cached.receivedResponseAtMillis;
  return receivedAge + responseDuration + residentDuration;
}

/** OkHttp CacheStrategy.Factory.computeFreshnessLifetime */
function computeFreshnessLifetime(cached: HttpResponse): number {
  const rcc = cached.cacheControl();
  if (rcc.maxAgeSeconds !== -1) {
    return rcc.maxAgeSeconds * 1000;
  }
  const servedDate = parseHttpDate(cached.header('date'));
  const expires = parseHttpDate(cached.header('expires'));
  if (expires !== null) {
    const servedMillis = servedDate !== null ? servedDate : cached.receivedResponseAtMillis;
    const delta = expires - servedMillis;
    return delta > 0 ? delta : 0;
  }
  const lastModified = parseHttpDate(cached.header('last-modified'));
  if (lastModified !== null && cached.request.url.indexOf('?') < 0) {
    const servedMillis = servedDate !== null ? servedDate : cached.sentRequestAtMillis;
    const delta = servedMillis - lastModified;
    return delta > 0 ? Math.floor(delta / 10) : 0;
  }
  return 0;
}

/** OkHttp CacheStrategy.Factory.compute()（含 only-if-cached 收敛） */
export function computeCacheStrategy(nowMillis: number, request: HttpRequest, cached: HttpResponse | null): CacheStrategy {
  const s = computeCandidate(nowMillis, request, cached);
  if (s.networkRequest !== null && request.cacheControl().onlyIfCached) {
    const none = new CacheStrategy();
    return none;
  }
  return s;
}

function computeCandidate(nowMillis: number, request: HttpRequest, cached: HttpResponse | null): CacheStrategy {
  const s = new CacheStrategy();
  s.networkRequest = request;
  if (cached === null || !isCacheable(cached, request)) {
    return s;
  }
  const requestCaching = request.cacheControl();
  if (requestCaching.noCache || hasConditions(request)) {
    return s;
  }
  const responseCaching = cached.cacheControl();
  const ageMillis = cacheResponseAge(nowMillis, cached);
  let freshMillis = computeFreshnessLifetime(cached);
  if (requestCaching.maxAgeSeconds !== -1) {
    freshMillis = Math.min(freshMillis, requestCaching.maxAgeSeconds * 1000);
  }
  const minFreshMillis = requestCaching.minFreshSeconds !== -1 ? requestCaching.minFreshSeconds * 1000 : 0;
  let maxStaleMillis = 0;
  if (!responseCaching.mustRevalidate && requestCaching.maxStaleSeconds !== -1) {
    maxStaleMillis = requestCaching.maxStaleSeconds * 1000;
  }
  if (!responseCaching.noCache && ageMillis + minFreshMillis < freshMillis + maxStaleMillis) {
    s.networkRequest = null;
    s.cacheResponse = cached;
    return s;
  }
  // 条件请求
  let conditionName: string;
  let conditionValue: string;
  const etag = cached.header('etag');
  const lastModifiedString = cached.header('last-modified');
  const servedDateString = cached.header('date');
  if (etag !== null) {
    conditionName = 'If-None-Match';
    conditionValue = etag;
  } else if (lastModifiedString !== null && parseHttpDate(lastModifiedString) !== null) {
    conditionName = 'If-Modified-Since';
    conditionValue = lastModifiedString;
  } else if (servedDateString !== null && parseHttpDate(servedDateString) !== null) {
    conditionName = 'If-Modified-Since';
    conditionValue = servedDateString;
  } else {
    return s;
  }
  s.networkRequest = request.withHeader(conditionName, conditionValue);
  s.cacheResponse = cached;
  return s;
}

/** OkHttp CacheInterceptor.combine：304 时合并缓存头与网络头 */
export function combineHeaders(cachedHeaders: HttpHeaders, networkHeaders: HttpHeaders): HttpHeaders {
  const result = new HttpHeaders();
  for (let i = 0; i < cachedHeaders.size(); i++) {
    const name = cachedHeaders.nameAt(i);
    const value = cachedHeaders.valueAt(i);
    if (name === 'warning' && value.startsWith('1')) {
      continue;
    }
    if (isContentSpecificHeader(name) || !isEndToEnd(name) || networkHeaders.get(name) === null) {
      result.add(name, value);
    }
  }
  for (let i = 0; i < networkHeaders.size(); i++) {
    const name = networkHeaders.nameAt(i);
    if (!isContentSpecificHeader(name) && isEndToEnd(name)) {
      result.add(name, networkHeaders.valueAt(i));
    }
  }
  return result;
}

function isEndToEnd(name: string): boolean {
  return name !== 'connection' && name !== 'keep-alive' && name !== 'proxy-authenticate' &&
    name !== 'proxy-authorization' && name !== 'te' && name !== 'trailers' && name !== 'transfer-encoding' &&
    name !== 'upgrade';
}

function isContentSpecificHeader(name: string): boolean {
  return name === 'content-length' || name === 'content-encoding' || name === 'content-type';
}

/** 响应 Vary 头的字段（小写；含 '*' 表示不可缓存，OkHttp Cache.hasVaryAll） */
export function varyFields(headers: HttpHeaders): string[] {
  const out: string[] = [];
  for (const v of headers.values('vary')) {
    for (const f of v.split(',')) {
      const t = f.trim().toLowerCase();
      if (t.length > 0 && out.indexOf(t) < 0) {
        out.push(t);
      }
    }
  }
  return out;
}

