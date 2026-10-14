/**
 * UtilVectors.ets —— fnd-util 单测向量（源 src/test/.../util/LinkUtilsKtTest.kt、UrlCleanerKtTest.kt
 * + 台账 UT-A01..A13/A22 + explore/util.md 记录的 JDK 实测边界）。纯数据。
 */

export interface StringPairVector {
  input: string;
  expected: string;
}

export interface SloppyVector {
  input: string;
  /** null = 期望抛 MalformedURLException */
  expected: string | null;
}

export interface RelativeVector {
  base: string;
  link: string;
  expected: string;
}

export interface HashVector {
  input: string;
  expected: number;
}

export interface ZonedVector {
  epochMs: number;
  offsetSeconds: number;
  zoneId: string | null;
  expected: string;
}

export interface VideoVector {
  src: string;
  /** null = 不识别 */
  videoId: string | null;
}

// UT-A01..A03（LinkUtilsKtTest + explore 实测）
export const SLOPPY_VECTORS: SloppyVector[] = [
  { input: 'https://google.com', expected: 'https://google.com' },
  { input: 'google.com', expected: 'http://google.com' },
  { input: 'gemini://google.com', expected: null },
  { input: '', expected: null },
  { input: '   ', expected: null },
  { input: 'localhost:8080/feed', expected: null },
  { input: 'feed://x.com/rss', expected: null },
  { input: '//example.com/x', expected: 'http:////example.com/x' },
  { input: 'HTTP://Example.com/A', expected: 'http://Example.com/A' },
  { input: 'example.com/path?q=1#frag', expected: 'http://example.com/path?q=1#frag' }
];

// UT-A06（LinkUtilsKtTest.testRelativeToAbsoluteWithFeedLinkAsBase + RFC 相对解析）
export const RELATIVE_VECTORS: RelativeVector[] = [
  { base: 'http://cowboy.com/feed.xml', link: '/bob.jpg', expected: 'http://cowboy.com/bob.jpg' },
  { base: 'http://cowboy.com/dir/feed.xml', link: 'bob.jpg', expected: 'http://cowboy.com/dir/bob.jpg' },
  { base: 'http://cowboy.com/a/b/feed.xml', link: '../bob.jpg', expected: 'http://cowboy.com/a/bob.jpg' },
  { base: 'http://cowboy.com/a/feed.xml', link: './bob.jpg', expected: 'http://cowboy.com/a/bob.jpg' },
  { base: 'https://cowboy.com/feed.xml', link: '//cdn.com/x.png', expected: 'https://cdn.com/x.png' },
  { base: 'http://cowboy.com/feed.xml', link: 'https://other.com/y', expected: 'https://other.com/y' },
  { base: 'http://cowboy.com/a/feed.xml?x=1', link: '?y=2', expected: 'http://cowboy.com/a/?y=2' },
  { base: 'http://cowboy.com/a/feed.xml?x=1', link: '#top', expected: 'http://cowboy.com/a/feed.xml?x=1#top' },
  { base: 'http://cowboy.com', link: 'bob.jpg', expected: 'http://cowboy.com/bob.jpg' }
];

// UT-A10..A13（UrlCleanerKtTest + 规则补充）
export const STRIP_VECTORS: StringPairVector[] = [
  { input: 'https://example.com/article?utm_source=rss&utm_medium=feed&id=123',
    expected: 'https://example.com/article?id=123' },
  { input: 'https://example.com/article?traffic_source=rss', expected: 'https://example.com/article' },
  { input: 'https://example.com/search?q=feeder&page=2', expected: 'https://example.com/search?q=feeder&page=2' },
  { input: 'https://example.com/article', expected: 'https://example.com/article' },
  { input: 'not a url', expected: 'not a url' },
  { input: 'https://example.com/a?UTM_source=x', expected: 'https://example.com/a?UTM_source=x' },
  { input: 'https://example.com/a?id=1&utm_campaign=x#sec', expected: 'https://example.com/a?id=1#sec' },
  { input: 'https://example.com/a?utm_x=1#sec', expected: 'https://example.com/a#sec' },
  { input: 'https://example.com/a?b=2&utm_x=1&a=1', expected: 'https://example.com/a?b=2&a=1' },
  { input: 'https://example.com/a?flag&utm_x=1', expected: 'https://example.com/a?flag' },
  { input: 'https://example.com/a?utm%5Fsource=1&k=v', expected: 'https://example.com/a?k=v' },
  // 源怪癖：保留值中的 %xx 经 URI 五参构造器被二次编码
  { input: 'https://example.com/a?x=a%20b&utm_source=rss', expected: 'https://example.com/a?x=a%2520b' }
];

// Java String.hashCode 已知值
export const HASH_VECTORS: HashVector[] = [
  { input: '', expected: 0 },
  { input: 'a', expected: 97 },
  { input: 'hello', expected: 99162322 },
  { input: 'Hello World', expected: -862545276 },
  { input: 'The quick brown fox jumps over the lazy dog', expected: -609428141 },
  { input: 'åäö', expected: 227383 },
  { input: '\ud83d\ude00 emoji', expected: -1572615351 }
];

// ZonedDateTime.toString
export const ZONED_VECTORS: ZonedVector[] = [
  { epochMs: 1704103200000, offsetSeconds: 3600, zoneId: null, expected: '2024-01-01T11:00+01:00' },
  { epochMs: 1704103200000, offsetSeconds: 3600, zoneId: 'Europe/Paris',
    expected: '2024-01-01T11:00+01:00[Europe/Paris]' },
  { epochMs: 1704103230500, offsetSeconds: 0, zoneId: null, expected: '2024-01-01T10:00:30.500Z' },
  { epochMs: 1704103201000, offsetSeconds: -18000, zoneId: null, expected: '2024-01-01T05:00:01-05:00' },
  { epochMs: 0, offsetSeconds: 0, zoneId: 'UTC', expected: '1970-01-01T00:00Z[UTC]' },
  { epochMs: 1704103200000, offsetSeconds: 19800, zoneId: null, expected: '2024-01-01T15:30+05:30' }
];

// UT-A22
export const VIDEO_VECTORS: VideoVector[] = [
  { src: 'www.youtube.com/embed/cjxnVO9RpaQ', videoId: 'cjxnVO9RpaQ' },
  { src: 'www.youtube.com/embed/cjxnVO9RpaQ?feature=oembed', videoId: 'cjxnVO9RpaQ' },
  { src: 'www.youtube.com/embed/cjxnVO9RpaQ/theoretical_crap', videoId: 'cjxnVO9RpaQ' },
  { src: 'www.youtube.com/embed/cjxnVO9RpaQ/crap?feature=oembed', videoId: 'cjxnVO9RpaQ' },
  { src: 'https://www.youtube-nocookie.com/embed/abc', videoId: null },
  { src: 'https://vimeo.com/123', videoId: null }
];
