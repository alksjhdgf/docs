import { describe, it, expect } from '@ohos/hypium';
import { feedDeepLink, formEncode, parseUri, ParsedUri, syncJoinDeepLink } from '../main/ets/core/app/RouteParams';
import {
  relativeLinkIntoAbsolute,
  relativeLinkIntoAbsoluteOrNull,
  relativeLinkIntoAbsoluteOrNullIfNotValid,
  relativeLinkIntoAbsoluteOrThrow,
  sloppyLinkToStrictURL,
  sloppyLinkToStrictURLNoThrows,
  sloppyLinkToStrictURLOrNull,
  urlHasNoAuthParams,
  urlHasNoQueryParams
} from '../main/ets/core/util/LinkUtils';
import { stripTrackingParameters } from '../main/ets/core/util/UrlCleaner';
import { Either, Left, Right } from '../main/ets/core/util/Either';
import { getVideo, Video } from '../main/ets/core/util/VideoTagHunter';
import {
  ARTICLES_DIR_NAME,
  blobFilePath,
  blobFullFilePath,
  DEEP_LINK_BASE_URI,
  DEEP_LINK_HOST,
  DEFAULT_MAX_ITEM_COUNT_PER_FEED,
  FilePathProvider,
  getStringNonNull,
  GITHUB_ISSUES_URL,
  KOFI_URL,
  PREF_MAX_ITEM_COUNT_PER_FEED
} from '../main/ets/core/util/Constants';
import {
  JavaUrl,
  JavaZonedDateTime,
  MalformedURLException,
  instantToString,
  javaLongHashCode,
  javaStringHashCode,
  zonedDateTimeToString
} from '../main/ets/core/util/JavaCompat';
import {
  HASH_VECTORS,
  RELATIVE_VECTORS,
  SLOPPY_VECTORS,
  STRIP_VECTORS,
  VIDEO_VECTORS,
  ZONED_VECTORS
} from './UtilVectors';

class ParseFailureError extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = 'ParseFailureError';
  }
}

function sloppyOrError(input: string): string | null {
  try {
    return sloppyLinkToStrictURL(input).toString();
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return null;
    }
    return 'UNEXPECTED:' + (e as Error).message;
  }
}

export default function utilTest() {
  describe('fndUtilLinkUtils', () => {
    it('UT_A01_A03_sloppyVectors', 0, () => {
      for (let i = 0; i < SLOPPY_VECTORS.length; i++) {
        const v = SLOPPY_VECTORS[i];
        expect(sloppyOrError(v.input)).assertEqual(v.expected);
      }
    });

    it('UT_A01_blankMessage', 0, () => {
      let msg = '';
      try {
        sloppyLinkToStrictURL('');
      } catch (e) {
        msg = (e as Error).message;
      }
      expect(msg).assertEqual('String is blank');
    });

    it('UT_A04_orNull', 0, () => {
      expect(sloppyLinkToStrictURLOrNull('')).assertNull();
      expect(sloppyLinkToStrictURLOrNull('gemini://google.com')).assertNull();
      const ok = sloppyLinkToStrictURLOrNull('google.com');
      expect(ok !== null ? ok.toString() : '').assertEqual('http://google.com');
    });

    it('UT_A05_noThrows', 0, () => {
      expect(sloppyLinkToStrictURLNoThrows('gemini://x').toString()).assertEqual(JavaUrl.parse('http://').toString());
      expect(sloppyLinkToStrictURLNoThrows('gemini://x').protocol).assertEqual('http');
      expect(sloppyLinkToStrictURLNoThrows('https://a.com/b').toString()).assertEqual('https://a.com/b');
    });

    it('UT_A06_relativeVectors', 0, () => {
      for (let i = 0; i < RELATIVE_VECTORS.length; i++) {
        const v = RELATIVE_VECTORS[i];
        expect(relativeLinkIntoAbsoluteOrThrow(JavaUrl.parse(v.base), v.link).toString()).assertEqual(v.expected);
      }
    });

    it('UT_A07_relativeWrappers', 0, () => {
      const base = JavaUrl.parse('http://cowboy.com/a');
      expect(relativeLinkIntoAbsolute(base, 'gemini://x')).assertEqual('gemini://x');
      expect(relativeLinkIntoAbsolute(base, '/b')).assertEqual('http://cowboy.com/b');
      expect(relativeLinkIntoAbsoluteOrNull(base, null)).assertNull();
      expect(relativeLinkIntoAbsoluteOrNull(base, 'gemini://x')).assertEqual('gemini://x');
      expect(relativeLinkIntoAbsoluteOrNullIfNotValid(base, 'gemini://x')).assertNull();
      expect(relativeLinkIntoAbsoluteOrNullIfNotValid(base, null)).assertNull();
      const ok = relativeLinkIntoAbsoluteOrNullIfNotValid(base, 'c');
      expect(ok !== null ? ok.toString() : '').assertEqual('http://cowboy.com/c');
    });

    it('UT_A08_noQueryParams', 0, () => {
      expect(urlHasNoQueryParams(JavaUrl.parse('https://example.com/path'))).assertTrue();
      expect(urlHasNoQueryParams(JavaUrl.parse('https://example.com/path?foo=bar'))).assertFalse();
      expect(urlHasNoQueryParams(JavaUrl.parse('https://example.com/path?'))).assertTrue();
    });

    it('UT_A09_noAuthParams', 0, () => {
      expect(urlHasNoAuthParams(JavaUrl.parse('https://example.com/path'))).assertTrue();
      expect(urlHasNoAuthParams(JavaUrl.parse('https://user:pass@example.com/path'))).assertFalse();
      expect(urlHasNoAuthParams(JavaUrl.parse('https://@example.com/path'))).assertTrue();
    });
  });

  describe('fndUtilUrlCleaner', () => {
    it('UT_A10_A13_stripVectors', 0, () => {
      for (let i = 0; i < STRIP_VECTORS.length; i++) {
        const v = STRIP_VECTORS[i];
        expect(stripTrackingParameters(v.input)).assertEqual(v.expected);
      }
    });
  });

  describe('fndUtilEither', () => {
    it('UT_A39_catching', 0, () => {
      const failed = Either.catching<string, number>((t: Error): string => 'caught:' + t.message, (): number => {
        throw new ParseFailureError('boom');
      });
      expect(failed.isLeft()).assertTrue();
      expect(failed.leftOrNull()).assertEqual('caught:boom');
      const ok = Either.catching<string, number>((t: Error): string => t.message, (): number => 41);
      expect(ok.isRight()).assertTrue();
      expect(ok.map<number>((v: number): number => v + 1).getOrNull()).assertEqual(42);
    });

    it('UT_A39_mapFlatMapPassLeft', 0, () => {
      const l: Either<string, number> = new Left<string, number>('err');
      let called = false;
      const mapped = l.map<number>((v: number): number => {
        called = true;
        return v + 1;
      });
      const flat = l.flatMap<number>((v: number): Either<string, number> => {
        called = true;
        return new Right<string, number>(v);
      });
      expect(called).assertFalse();
      expect(mapped.leftOrNull()).assertEqual('err');
      expect(flat.leftOrNull()).assertEqual('err');
      const r: Either<string, number> = new Right<string, number>(1);
      expect(r.flatMap<number>((v: number): Either<string, number> => new Left<string, number>('x' + v))
        .leftOrNull()).assertEqual('x1');
      expect(r.fold<string>((a: string): string => a, (b: number): string => 'r' + b)).assertEqual('r1');
      expect(r.toString()).assertEqual('Either.Right(1)');
      expect(l.toString()).assertEqual('Either.Left(err)');
      expect(l.getOrElse((a: string): number => a.length)).assertEqual(3);
    });
  });

  describe('fndUtilVideoAndConstants', () => {
    it('UT_A22_getVideo', 0, () => {
      for (let i = 0; i < VIDEO_VECTORS.length; i++) {
        const v = VIDEO_VECTORS[i];
        const video: Video | null = getVideo(v.src);
        if (v.videoId === null) {
          expect(video).assertNull();
        } else {
          expect(video !== null).assertTrue();
          if (video !== null) {
            expect(video.src).assertEqual(v.src);
            expect(video.imageUrl).assertEqual('http://img.youtube.com/vi/' + v.videoId + '/hqdefault.jpg');
            expect(video.link).assertEqual('https://www.youtube.com/watch?v=' + v.videoId);
            expect(video.width).assertEqual(480);
            expect(video.height).assertEqual(360);
          }
        }
      }
      expect(getVideo(null)).assertNull();
    });

    it('UT_A35_A38_constants', 0, () => {
      expect(DEEP_LINK_HOST).assertEqual('feederapp.nononsenseapps.com');
      expect(DEEP_LINK_BASE_URI).assertEqual('https://feederapp.nononsenseapps.com');
      expect(GITHUB_ISSUES_URL).assertEqual('https://github.com/spacecowboy/feeder/issues');
      expect(KOFI_URL).assertEqual('https://ko-fi.com/spacecowboy');
      const fp = new FilePathProvider('/c', '/f');
      expect(fp.articleDir).assertEqual('/f/' + ARTICLES_DIR_NAME);
      expect(fp.fullArticleDir).assertEqual('/c/full_articles');
      expect(fp.fontsDir).assertEqual('/f/fonts');
      expect(fp.httpCacheDir).assertEqual('/c/http');
      expect(fp.imageCacheDir).assertEqual('/c/image_cache');
      expect(fp.httpImageCacheDir).assertEqual('/c/http_image_cache');
      expect(blobFilePath(5, fp.articleDir)).assertEqual('/f/articles/5.txt.gz');
      expect(blobFullFilePath(5, fp.fullArticleDir)).assertEqual('/c/full_articles/5.full.html.gz');
      expect(PREF_MAX_ITEM_COUNT_PER_FEED).assertEqual('pref_max_item_count_per_feed');
      expect(getStringNonNull(null, DEFAULT_MAX_ITEM_COUNT_PER_FEED)).assertEqual('100');
    });
  });

  describe('fndUtilJavaCompat', () => {
    it('stringHashCode', 0, () => {
      for (let i = 0; i < HASH_VECTORS.length; i++) {
        const v = HASH_VECTORS[i];
        expect(javaStringHashCode(v.input)).assertEqual(v.expected);
      }
      expect(javaStringHashCode(null)).assertEqual(0);
      expect(javaLongHashCode(5)).assertEqual(5);
      expect(javaLongHashCode(-1)).assertEqual(0);
      expect(javaLongHashCode(4294967296)).assertEqual(1);
    });

    it('zonedDateTimeToString', 0, () => {
      for (let i = 0; i < ZONED_VECTORS.length; i++) {
        const v = ZONED_VECTORS[i];
        expect(zonedDateTimeToString(v.epochMs, v.offsetSeconds, v.zoneId)).assertEqual(v.expected);
        expect(JavaZonedDateTime.parse(v.expected).toEpochMs()).assertEqual(v.epochMs);
        expect(JavaZonedDateTime.parse(v.expected).toString()).assertEqual(v.expected);
      }
      expect(JavaZonedDateTime.parseOrNull('2024-02-30T10:00Z')).assertNull();
      expect(JavaZonedDateTime.parseOrNull('2024-01-01T10:00')).assertNull();
      expect(instantToString(1704103230500)).assertEqual('2024-01-01T10:00:30.500Z');
      expect(instantToString(0)).assertEqual('1970-01-01T00:00:00Z');
    });

    // UT-A30：源 RssNotifications.kt:320 `deepLinkTag.urlEncode()` = URLEncoder.encode（表单编码）
    it('feedDeepLinkFormEncoding', 0, () => {
      expect(formEncode('a b&c/ä*~!')).assertEqual('a+b%26c%2F%C3%A4*%7E%21');
      expect(feedDeepLink(-10, 'My Tag')).assertEqual('https://feederapp.nononsenseapps.com/feed?id=-10&tag=My+Tag');
      expect(syncJoinDeepLink('abc', 'k+y/=')).assertEqual('https://feederapp.nononsenseapps.com/sync/join?sync_code=abc&key=k%2By%2F%3D');
      const u: ParsedUri | null = parseUri(feedDeepLink(5, 'My Tag+x'));
      expect(u !== null).assertTrue();
      if (u !== null) {
        expect(u.query.get('tag')).assertEqual('My Tag+x');
      }
    });
  });
}
