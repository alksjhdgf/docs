import { describe, it, expect } from '@ohos/hypium';
import { Converters, JavaTime, JavaUrl } from '../main/ets/core/model/Feed';
import { EnclosureImage, ImageFromHTML, MediaImage, ThumbnailImage } from '../main/ets/core/model/Thumbnail';
import {
  ItemOpener, LinkOpener, SyncFrequency, ThemeOptions, FeedItemStyle, SwipeAsRead,
  itemOpenerFromString, itemOpenerToStoredString, linkOpenerFromString, syncFrequencyFromString,
  syncFrequencyToStoredString, themeOptionsFromString, themeOptionsToStoredString, feedItemStyleToStoredString,
  swipeAsReadFromString
} from '../main/ets/core/model/Enums';
import { estimateWordCount } from '../main/ets/core/model/FeedItem';

export default function modelConvertersTest() {
  describe('fndModelConverters', () => {
    it('DB_A13_thumbnailJsonRoundTrip', 0, () => {
      expect(new ImageFromHTML('https://a/b.png', null, null).toJson())
        .assertEqual('{"type":"ImageFromHTML","url":"https://a/b.png"}');
      expect(new MediaImage('https://a/b.png', 10, 20).toJson())
        .assertEqual('{"type":"MediaImage","url":"https://a/b.png","width":10,"height":20}');
      expect(new EnclosureImage('https://a/b.png', 0).toJson())
        .assertEqual('{"type":"EnclosureImage","url":"https://a/b.png","length":0}');
      const back: ThumbnailImage | null = ThumbnailImage.fromJson('{"type":"MediaImage","url":"u","width":1}');
      expect(back instanceof MediaImage).assertTrue();
      expect(back !== null && back.width === 1 && back.height === null).assertTrue();
    });

    it('DB_A13_thumbnailLegacyUrl', 0, () => {
      const legacy: ThumbnailImage | null = Converters.thumbnailImageFromString('https://example.com/x.jpg');
      expect(legacy instanceof ImageFromHTML).assertTrue();
      expect(legacy !== null && legacy.url === 'https://example.com/x.jpg' && legacy.width === null).assertTrue();
      expect(Converters.thumbnailImageFromString('not a url')).assertNull();
      expect(Converters.thumbnailImageFromString('{"type":"Other","url":"u"}')).assertNull();
      expect(Converters.thumbnailImageFromString(null)).assertNull();
    });

    it('DB_A12_pubDateParse', 0, () => {
      expect(Converters.dateTimeFromString('2024-01-01T10:00:00+01:00')).assertEqual('2024-01-01T10:00+01:00');
      expect(Converters.dateTimeFromString('2024-01-01T10:00:00.500Z')).assertEqual('2024-01-01T10:00:00.500Z');
      expect(Converters.dateTimeFromString('2024-01-01T10:00+01:00[Europe/Paris]'))
        .assertEqual('2024-01-01T10:00+01:00[Europe/Paris]');
      expect(Converters.dateTimeFromString('2024-02-30T10:00Z')).assertNull();
      expect(Converters.dateTimeFromString('Mon, 01 Jan 2024')).assertNull();
      const v = JavaTime.parseZoned('1970-01-01T01:00+01:00');
      expect(v !== null && v.epochMs === 0).assertTrue();
      expect(JavaTime.formatUtcIso(1500)).assertEqual('1970-01-01T00:00:01.500Z');
    });

    it('DB_A11_A14_instantAndUrl', 0, () => {
      expect(Converters.instantFromLong(1234)).assertEqual(1234);
      expect(Converters.instantFromLong(null)).assertNull();
      expect(Converters.instantFromLong(Number.NaN)).assertNull();
      expect(Converters.urlFromString('google.com')).assertEqual('http://google.com');
      expect(Converters.urlFromString('https://x.org/feed')).assertEqual('https://x.org/feed');
      expect(Converters.urlFromString('')).assertEqual('http://');
      expect(JavaUrl.sloppyLinkToStrictURLNoThrows('foo:bar')).assertEqual('http://');
    });

    it('enumsStoredStrings', 0, () => {
      expect(themeOptionsToStoredString(ThemeOptions.E_INK)).assertEqual('e_ink');
      expect(themeOptionsFromString('night')).assertEqual(ThemeOptions.NIGHT);
      expect(themeOptionsFromString('SYSTEM')).assertEqual(ThemeOptions.SYSTEM);
      expect(feedItemStyleToStoredString(FeedItemStyle.COMPACT_CARD)).assertEqual('COMPACT_CARD');
      expect(swipeAsReadFromString('bogus')).assertEqual(SwipeAsRead.ONLY_FROM_END);
      expect(itemOpenerFromString('1')).assertEqual(ItemOpener.CUSTOM_TAB);
      expect(itemOpenerToStoredString(ItemOpener.CUSTOM_TAB)).assertEqual('3');
      expect(linkOpenerFromString('2')).assertEqual(LinkOpener.DEFAULT_BROWSER);
      expect(syncFrequencyFromString('60')).assertEqual(SyncFrequency.EVERY_1_HOURS);
      expect(syncFrequencyFromString('x')).assertEqual(SyncFrequency.MANUAL);
      expect(syncFrequencyToStoredString(SyncFrequency.MANUAL)).assertEqual('-1');
    });

    it('estimateWordCount', 0, () => {
      expect(estimateWordCount('hello world foo')).assertEqual(3);
      // 源 FeedItem.kt:47 Java \s = [ \t\n\x0B\f\r]：U+3000/NBSP 不分词
      expect(estimateWordCount('中文\u3000中文')).assertEqual(1);
      expect(estimateWordCount('a\u00A0b')).assertEqual(1);
      expect(estimateWordCount('a b')).assertEqual(2);
      expect(estimateWordCount('a\t\u000Bb\fc')).assertEqual(3);
      expect(estimateWordCount('これは日本語の文章でスペースがありませんので単語数はゼロ')).assertEqual(0);
    });
  });
}
