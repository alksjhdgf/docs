import { describe, it, expect } from '@ohos/hypium';
import {
  basicCredentials,
  CacheControl,
  HttpHeaders,
  HttpRequest,
  HttpResponse,
  hostOf,
  MediaType,
  stripUserInfo
} from '../main/ets/core/net/HttpMessages';
import { combineHeaders, computeCacheStrategy, isCacheable } from '../main/ets/core/net/CacheStrategy';
import { RateLimiter } from '../main/ets/core/net/RateLimiter';

function cachedResponse(url: string, code: number, headers: string[][], receivedAt: number): HttpResponse {
  const r = new HttpResponse();
  r.code = code;
  r.headers = HttpHeaders.of(headers);
  r.request = HttpRequest.get(url);
  r.finalUrl = url;
  r.sentRequestAtMillis = receivedAt;
  r.receivedResponseAtMillis = receivedAt;
  r.body = new ArrayBuffer(0);
  r.fromCache = true;
  return r;
}

export default function netTest() {
  describe('NetGate', () => {
    it('cacheControlParseAndToString', 0, () => {
      const cc = CacheControl.parse(HttpHeaders.of([['Cache-Control', 'public, max-age=60, max-stale, no-transform']]));
      expect(cc.isPublic).assertTrue();
      expect(cc.maxAgeSeconds).assertEqual(60);
      expect(cc.maxStaleSeconds).assertEqual(2147483647);
      expect(cc.noTransform).assertTrue();
      expect(CacheControl.maxAge(60).toString()).assertEqual('max-age=60');
      const img = new CacheControl();
      img.maxStaleSeconds = 30 * 24 * 3600;
      img.maxAgeSeconds = 7 * 24 * 3600;
      expect(img.toString()).assertEqual('max-age=604800, max-stale=2592000');
    });

    it('forceNetworkMaxAge60UsesFreshCacheOnly', 0, () => {
      const now = 1000000000000;
      const url = 'https://example.com/feed.xml';
      const cached = cachedResponse(url, 200, [['etag', '"abc"'], ['cache-control', 'max-age=3600']], now - 30 * 1000);
      // 30s 内：max-age=60 仍命中缓存
      const hit = computeCacheStrategy(now, HttpRequest.get(url).withCacheControl(CacheControl.maxAge(60)), cached);
      expect(hit.networkRequest === null).assertTrue();
      // 2 分钟后：条件请求带 If-None-Match
      const old = cachedResponse(url, 200, [['etag', '"abc"'], ['cache-control', 'max-age=3600']], now - 120 * 1000);
      const cond = computeCacheStrategy(now, HttpRequest.get(url).withCacheControl(CacheControl.maxAge(60)), old);
      expect(cond.networkRequest !== null).assertTrue();
      expect((cond.networkRequest as HttpRequest).header('If-None-Match')).assertEqual('"abc"');
      expect(cond.cacheResponse !== null).assertTrue();
    });

    it('onlyIfCachedWithoutCacheGivesNothing', 0, () => {
      const req = HttpRequest.get('https://a.com/x').withHeader('Cache-Control', 'max-age=2147483647, only-if-cached, max-stale=2147483647');
      const s = computeCacheStrategy(Date.now(), req, null);
      expect(s.networkRequest === null && s.cacheResponse === null).assertTrue();
    });

    it('forced4xxCacheIsCacheableFor404', 0, () => {
      const r = cachedResponse('https://a.com/favicon.ico', 404, [['cache-control', 'max-age=3600']], Date.now());
      expect(isCacheable(r, r.request)).assertTrue();
      const r429 = cachedResponse('https://a.com/x', 429, [['cache-control', 'max-age=3600']], Date.now());
      expect(isCacheable(r429, r429.request)).assertFalse();
    });

    it('combineHeaders304', 0, () => {
      const c = combineHeaders(HttpHeaders.of([['content-type', 'text/xml'], ['etag', '"a"']]),
        HttpHeaders.of([['etag', '"b"'], ['content-type', 'text/plain']]));
      expect(c.get('content-type')).assertEqual('text/xml');
      expect(c.get('etag')).assertEqual('"b"');
    });

    it('retryAfterSecondsMaxAndFallback', 0, () => {
      const r = new HttpResponse();
      r.headers = HttpHeaders.of([['Retry-After', '30'], ['retry-after', '120']]);
      expect(r.retryAfterSeconds()).assertEqual(120);
      r.headers = HttpHeaders.of([['retry-after', 'Wed, 21 Oct 2015 07:28:00 GMT']]);
      expect(r.retryAfterSeconds()).assertEqual(3600);
      r.headers = new HttpHeaders();
      expect(r.retryAfterSeconds() === null).assertTrue();
    });

    it('basicCredentialsAndUserInfo', 0, () => {
      expect(basicCredentials('user', 'pass')).assertEqual('Basic dXNlcjpwYXNz');
      expect(stripUserInfo('https://u:p@example.com:8080/a?b#c')).assertEqual('https://example.com:8080/a?b#c');
      expect(hostOf('https://u:p@Example.COM:8080/a')).assertEqual('example.com');
    });

    it('mediaTypeParse', 0, () => {
      const m = MediaType.parse('application/rss+xml; charset="ISO-8859-1"') as MediaType;
      expect(m.type).assertEqual('application');
      expect(m.subtype).assertEqual('rss+xml');
      expect(m.charset).assertEqual('ISO-8859-1');
      expect(MediaType.parse('garbage') === null).assertTrue();
    });

    it('rateLimiterSleepRange', 0, () => {
      expect(RateLimiter.DELAY_MS).assertEqual(333);
      for (let i = 0; i < 50; i++) {
        const t = RateLimiter.randomSleepTime(100);
        expect(t >= 100 && t < 200).assertTrue();
      }
    });
  });
}
