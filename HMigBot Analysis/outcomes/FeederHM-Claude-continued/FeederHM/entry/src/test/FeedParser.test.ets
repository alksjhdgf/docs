/**
 * FeedParser.test.ets —— 向量门 FeedParserGate。
 *
 * 移植源 androidTest/.../model/FeedParserTest.kt 中引用 FeedFixtures（≤150KB 样例）的断言，以及同文件内嵌 XML 常量用例、
 * test/.../model/gofeed/GoFeedExtensionsKtTest.kt 的全部用例。断言与期望值原样照源。
 *  - 源 readResource(...) 用例（字符串体，无内容类型闸门）→ parseFeedBody(url, body)
 *  - 源 bytesToResponse(...) 用例（HTTP 响应，Content-Type 默认 application/xml）→ parseFeed(body, url, contentType)
 * FeedFixtures 由生成器以 UTF-8 读入：ISO-8859-1 样例中的非 ASCII 字节已丢失（golem `größte` 断言无法移植，见 deviations）；
 * 超过 150KB 的样例（rsc/cowboy/cornucopia/nixers/londoner/morningpaper/geekpark/theguardian…）不入向量。
 * 末尾 "supplementary_" 前缀用例为本单元补充（非源断言），覆盖内容类型闸门 / Latin-1 字节解码 / JSON Feed。
 */
import { describe, it, expect } from '@ohos/hypium';
import { Either } from '../main/ets/core/util/Either';
import { JavaUrl } from '../main/ets/core/util/JavaCompat';
import { ParsedArticle, ParsedAuthor, ParsedEnclosure, ParsedFeed } from '../main/ets/core/model/Parsed';
import { ImageFromHTML, MediaImage, ThumbnailImage, thumbnailEquals } from '../main/ets/core/model/Thumbnail';
import { FeederGoItem, parseFeed, parseFeedBody } from '../main/ets/core/parser/FeedMapping';
import { FeedParserError } from '../main/ets/core/parser/FeedParserError';
import { GoExtension, GoExtensions, makeGoItem } from '../main/ets/core/parser/GoFeed';
import { feedFixture } from './FeedFixtures';
import {
  atomRelative,
  atomRelativeNoBase,
  atomWithHtmlEscapedContents,
  atomWithInvalidSelfLink,
  atomWithUnknownProtocol,
  rssBleepingComputer,
  rssWithHtmlEscapedDescription
} from './FeedParserVectors';

class GateFailure extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = 'GateFailure';
  }
}

/** 源 readResource + parseFeedResponse(URL, String) */
function fromResource(name: string, url: string): Either<FeedParserError, ParsedFeed> {
  return parseFeedBody(url, feedFixture(name));
}

/** 源 bytesToResponse(name, url, contentType = "application/xml") + parseFeedResponse(Response) */
function fromResponse(name: string, url: string, contentType: string | null = 'application/xml'):
  Either<FeedParserError, ParsedFeed> {
  return parseFeed(feedFixture(name), url, contentType);
}

/** getOrNull()!! */
function feedOf(e: Either<FeedParserError, ParsedFeed>): ParsedFeed {
  const f: ParsedFeed | null = e.getOrNull();
  if (f === null) {
    const l: FeedParserError | null = e.leftOrNull();
    throw new GateFailure(`Expected Right but got ${l !== null ? l.toString() : 'null'}`);
  }
  return f;
}

/** items!! */
function itemsOf(f: ParsedFeed): ParsedArticle[] {
  if (f.items === null) {
    throw new GateFailure('items is null');
  }
  return f.items;
}

function imageUrl(a: ParsedArticle): string | null {
  return a.image !== null ? a.image.url : null;
}

function startsWith(s: string | null, prefix: string): boolean {
  return s !== null && s.startsWith(prefix);
}

function contains(s: string | null, part: string): boolean {
  return s !== null && s.indexOf(part) >= 0;
}

function latin1Bytes(s: string): ArrayBuffer {
  const out: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    out[i] = s.charCodeAt(i) & 0xFF;
  }
  return out.buffer as ArrayBuffer;
}

const HNAPP_URL: string =
  'http://hnapp.com/rss?q=type%3Astory%20score%3E36%20-bitcoin%20-ethereum%20-cryptocurrency%20-blockchain%20-snowden%20-hiring%20-ask';

export default function feedParserTest() {
  describe('FeedParserGate', () => {
    // ------------------------------------------------ FeedParserTest.kt：fixture 用例

    it('canParseUkrnet', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> = fromResource('rss_ukrnet.xml',
        'https://suspilne.media/rss/ukrnet.rss');
      const l: FeedParserError | null = feed.leftOrNull();
      if (l !== null && l.throwable !== null) {
        throw l.throwable;
      }
      const f: ParsedFeed | null = feed.getOrNull();
      expect(f !== null && f.items !== null ? f.items.length : -1).assertEqual(20);
    });

    it('anime2youHasThumbnails', 0, () => {
      const item: ParsedArticle = itemsOf(feedOf(fromResource('rss_anime2you.xml', 'https://www.anime2you.de/feed/')))[0];
      const expected: ImageFromHTML = new ImageFromHTML('https://img.anime2you.de/2023/12/jujutsu-kaisen-6.jpg', 700, 350);
      expect(thumbnailEquals(expected, item.image)).assertTrue();
    });

    it('dcCreatorEndsUpAsAuthor', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('openstreetmap.xml', 'http://https://www.openstreetmap.org/diary/rss')))[0];
      const author: ParsedAuthor | null = item.author;
      expect(author !== null ? author.name : null).assertEqual('0235');
      expect(author !== null ? author.url : 'x').assertNull();
      expect(author !== null ? author.avatar : 'x').assertNull();
    });

    it('htmlAtomContentGetsUnescaped', 0, () => {
      const item: ParsedArticle = itemsOf(feedOf(fromResource('atom_hnapp.xml', HNAPP_URL)))[0];
      expect(item.title).assertEqual('37 – Spectre Mitigations in Microsoft\'s C/C++ Compiler');
      expect(item.content_text).assertEqual('37 points, 1 comment');
      expect(item.content_html)
        .assertEqual('<p>37 points, <a href="https://news.ycombinator.com/item?id=16381978">1 comment</a></p>');
    });

    it('enclosedImageIsUsedAsThumbnail', 0, () => {
      const item: ParsedArticle = itemsOf(feedOf(fromResource('rss_lemonde.xml', 'http://www.lemonde.fr/rss/une.xml')))[0];
      expect(imageUrl(item)).assertEqual(
        'http://s1.lemde.fr/image/2018/02/11/644x322/5255112_3_a8dc_martin-fourcade_02be61d126b2da39d977b2e1902c819a.jpg');
    });

    it('parsesYoutubeMediaInfo', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('atom_youtube.xml', 'http://www.youtube.com/feeds/videos.xml')))[0];
      expect(item.title).assertEqual('Can You Observe a Typical Universe?');
      expect(imageUrl(item)).assertEqual('https://i2.ytimg.com/vi/q-6oU3jXAho/hqdefault.jpg');
      expect(startsWith(item.content_text, 'Sign Up on Patreon to get access to the Space Time Discord!')).assertTrue();
    });

    it('parsesPeertubeMediaInfo', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('rss_peertube.xml', 'https://framatube.org/feeds/videos.xml')))[0];
      expect(item.title).assertEqual('1.4. Et les réseaux sociaux ?');
      expect(imageUrl(item))
        .assertEqual('https://framatube.org/static/thumbnails/ed5c048d-01f3-4ceb-97db-6e278de512b0.jpg');
      expect(startsWith(item.content_text, 'MOOC CHATONS#1 - Internet')).assertTrue();
    });

    it('parsesYahooMediaRss', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('rss_mediarss.xml', 'https://rutube.ru/mrss/video/person/11234072/')))[0];
      expect(item.title).assertEqual('Камеди Клаб: «3 сентября»');
      expect(imageUrl(item))
        .assertEqual('https://pic.rutubelist.ru/video/93/24/93245691f0e18d063da5fa5cd60fa6de.jpg?size=l');
    });

    it('parsesYahooMediaRss2', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('rss_myanimelist.xml', 'https://myanimelist.net/rss/news.xml')))[0];
      expect(imageUrl(item)).assertEqual(
        'https://cdn.myanimelist.net/s/common/uploaded_files/1664092688-dd34666e64d7ae624e6e2c70087c181f.jpeg');
    });

    it('encodingTestWithSmileys', 0, () => {
      const item: ParsedArticle =
        itemsOf(feedOf(fromResource('rss_lawnchair.xml', 'https://nitter.weiler.rocks/lawnchairapp/rss')))[0];
      expect(contains(item.content_html, '😍🤩')).assertTrue();
    });

    it('emptySlashCommentsDontCrashParsing', 0, () => {
      // 源同名用例的第二条断言（content_text 含 "größte"）依赖 ISO-8859-1 原始字节，fixture 已丢失该信息 → deviations
      const feed: Either<FeedParserError, ParsedFeed> =
        fromResponse('empty_slash_comment.xml', 'https://rss.golem.de/rss.php?feed=RSS2.0');
      const f: ParsedFeed | null = feed.getOrNull();
      expect(f !== null && f.items !== null ? f.items.length : -1).assertEqual(1);
    });

    it('correctAlternateLinkInAtomIsUsedForUrl', 0, () => {
      const f: ParsedFeed = feedOf(fromResponse('atom_utdelningsseglaren.xml',
        'http://utdelningsseglaren.blogspot.com/feeds/posts/default'));
      expect(itemsOf(f)[0].url).assertEqual('http://utdelningsseglaren.blogspot.com/2017/12/tips-pa-6-podcasts.html');
    });

    it('relativeFeedLinkInRssIsMadeAbsolute', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> = fromResponse('rss_lineageos.xml', 'https://lineageos.org/feed.xml');
      expect(feed.isRight()).assertTrue();
      const f: ParsedFeed = feedOf(feed);
      expect(f.home_page_url).assertEqual('https://lineageos.org/');
      expect(f.feed_url).assertEqual('https://lineageos.org/feed.xml');
      expect(itemsOf(f)[0].id).assertEqual('https://lineageos.org/Changelog-16');
      expect(itemsOf(f)[0].url).assertEqual('https://lineageos.org/Changelog-16/');
      expect(imageUrl(itemsOf(f)[0])).assertEqual('https://lineageos.org/images/2018-02-25/lineageos-15.1-hero.png');
    });

    it('nixos', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> = fromResponse('rss_nixos.xml', 'http://nixos.org/news-rss.xml');
      expect(feed.isRight()).assertTrue();
      const f: ParsedFeed = feedOf(feed);
      expect(f.feed_url).assertEqual('http://nixos.org/news-rss.xml');
      expect(itemsOf(f).length).assertEqual(99);
      const first: ParsedArticle = itemsOf(f)[0];
      expect(imageUrl(first)).assertEqual('https://nixos.org/logo/nixos-logo-18.09-jellyfish-lores.png');
      expect(first.title).assertEqual('NixOS 18.09 released');
    });

    it('cyklist', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> =
        fromResponse('rss_cyklistbloggen.xml', 'http://www.cyklistbloggen.se/feed/');
      expect(feed.isRight()).assertTrue();
      const f: ParsedFeed = feedOf(feed);
      expect(f.feed_url).assertEqual('http://www.cyklistbloggen.se/feed/');
      expect(itemsOf(f).length).assertEqual(10);
      const first: ParsedArticle = itemsOf(f)[0];
      expect(imageUrl(first))
        .assertEqual('http://www.cyklistbloggen.se/wp-content/uploads/2014/01/Danviksklippan-skyltad.jpg');
      expect(first.title).assertEqual('Ingen ombyggning av Danvikstull');
      // Make sure character 160 (non-breaking space) is trimmed
      expect(first.summary).assertEqual('För mer än tre år sedan aviserade dåvarande Allians-styrda Stockholms Stad att man äntligen skulle bredda den extremt smala passagen på pendlingsstråket vid Danvikstull: I smalaste passagen är gångdel');
    });

    it('testSlashdot', 0, () => {
      const f: ParsedFeed =
        feedOf(fromResponse('rdf_slashdot.xml', 'https://rss.slashdot.org/Slashdot/slashdotMain'));
      expect(f.home_page_url).assertEqual('https://slashdot.org/');
      expect(f.feed_url).assertEqual('https://rss.slashdot.org/Slashdot/slashdotMain');
      expect(itemsOf(f).length).assertEqual(15);
      const item: ParsedArticle = itemsOf(f)[0];
      expect(f.icon).assertEqual('https://a.fsdn.com/sd/topics/topicslashdot.gif');
      expect(item.url).assertEqual('https://yro.slashdot.org/story/24/03/02/071229/ransomware-attack-hampers-prescription-drug-sales-at-90-of-us-pharmacies?utm_source=rss1.0mainlinkanon&utm_medium=feed');
      expect(item.title).assertEqual('Ransomware Attack Hampers Prescription Drug Sales at 90% of US Pharmacies');
      expect(item.summary).assertEqual('"A ransomware gang once thought to have been crippled by law enforcement has snarled prescription processing for millions of Americans over the past week..." reports the Washington Post. "The hackers ');
      expect(item.image).assertNull();
    });

    it('noLinkShouldBeNull', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> = fromResponse('rss_anon.xml', 'http://ANON.com/rss');
      const f: ParsedFeed = feedOf(feed);
      expect(f.home_page_url).assertEqual('http://ANON.com/sub');
      expect(f.feed_url).assertEqual('http://anon.com/rss');
      expect(f.title).assertEqual('ANON');
      expect(f.description).assertEqual('ANON');
      expect(itemsOf(f).length).assertEqual(1);
      const item: ParsedArticle = itemsOf(f)[0];
      expect(item.url).assertNull();
      expect(item.title).assertEqual('ANON');
      expect(item.content_text).assertEqual('ANON');
      expect(item.content_html).assertEqual('ANON');
      expect(item.summary).assertEqual('ANON');
    });

    it('golem2ShouldBeParsedDespiteEmptySlashComments', 0, () => {
      const f: ParsedFeed | null = fromResponse('rss_golem_2.xml', 'https://rss.golem.de/rss.php?feed=RSS2.0').getOrNull();
      expect(f !== null ? f.title : null).assertEqual('Golem.de');
    });

    it('diskuse', 0, () => {
      const entry: ParsedArticle =
        itemsOf(feedOf(fromResponse('rss_diskuse.xml', 'https://diskuse.jakpsatweb.cz/rss2.php?topic=173233')))[0];
      expect(entry.title).assertEqual('Kajman, O této diskusi: test <pre> in <description> and <b>bold</b> in title');
    });

    it('contentTypeHtmlIsNotUnescapedTwice', 0, () => {
      const items: ParsedArticle[] =
        itemsOf(feedOf(fromResponse('atom_content_type_html.xml', 'http://www.zoocoop.com/contentoob/o1.atom')));
      expect(items.length).assertEqual(1);
      const item: ParsedArticle = items[0];
      expect(contains(item.content_html, ' <pre><code class="language-R">obs.lon <- ncvar_get(nc.obs, \'lon\')'))
        .assertFalse();
      expect(contains(item.content_html, ' <pre><code class="language-R">obs.lon &lt;- ncvar_get(nc.obs, \'lon\')'))
        .assertTrue();
    });

    // ------------------------------------------------ FeedParserTest.kt：内嵌常量用例

    it('relativeLinksAreMadeAbsoluteAtom', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> =
        parseFeedBody('http://cowboyprogrammer.org/feed.atom', atomRelative);
      expect(feed.isRight()).assertTrue();
      expect(feedOf(feed).feed_url).assertEqual('http://cowboyprogrammer.org/feed.atom');
    });

    it('relativeLinksAreMadeAbsoluteAtomNoBase', 0, () => {
      const feed: Either<FeedParserError, ParsedFeed> =
        parseFeedBody('http://cowboyprogrammer.org/feed.atom', atomRelativeNoBase);
      expect(feed.isRight()).assertTrue();
      expect(feedOf(feed).feed_url).assertEqual('http://cowboyprogrammer.org/feed.atom');
    });

    it('escapedRssDescriptionIsProperlyUnescaped', 0, () => {
      const items: ParsedArticle[] = itemsOf(feedOf(parseFeedBody('http://cowboyprogrammer.org',
        rssWithHtmlEscapedDescription)));
      expect(items.length).assertEqual(1);
      expect(imageUrl(items[0])).assertEqual('http://cowboyprogrammer.org/hello.jpg&cached=true');
      expect(items[0].content_html).assertEqual('<img src="hello.jpg&amp;cached=true">');
    });

    it('escapedAtomContentIsProperlyUnescaped', 0, () => {
      const items: ParsedArticle[] =
        itemsOf(feedOf(parseFeedBody('http://cowboyprogrammer.org', atomWithHtmlEscapedContents)));
      const text: ParsedArticle = items[0];
      expect(imageUrl(text)).assertEqual('http://cowboyprogrammer.org/hello.jpg&cached=true');
      expect(text.content_html).assertEqual('<img src="hello.jpg&amp;cached=true">');
      const html: ParsedArticle = items[1];
      expect(imageUrl(html)).assertEqual('http://cowboyprogrammer.org/hello.jpg&cached=true');
      expect(html.content_html).assertEqual('<img src="hello.jpg&amp;cached=true">');
      const xhtml: ParsedArticle = items[2];
      expect(imageUrl(xhtml)).assertEqual('http://cowboyprogrammer.org/hello.jpg&cached=true');
      expect(contains(xhtml.content_html, '<img src="hello.jpg&amp;cached=true"/>')).assertTrue();
    });

    it('selfLinkIsNotUpdated', 0, () => {
      const f: ParsedFeed = feedOf(parseFeedBody('http://cowboyprogrammer.org', atomWithInvalidSelfLink));
      expect(f.feed_url).assertEqual('http://cowboyprogrammer.org');
    });

    it('timestampsAreParsedWithCorrectTimezone', 0, () => {
      const f: ParsedFeed = feedOf(parseFeedBody('https://www.bleepingcomputer.com/feed/', rssBleepingComputer));
      // Thu, 14 Mar 2024 14:08:43 -0400"
      expect(itemsOf(f)[0].date_published).assertEqual('2024-03-14T18:08:43Z');
    });

    it('handlesUnknownProtocols', 0, () => {
      const f: ParsedFeed | null = parseFeedBody('https://gemini.circumlunar.space', atomWithUnknownProtocol).getOrNull();
      expect(f !== null && f.items !== null ? f.items.length : -1).assertEqual(8);
    });

    // ------------------------------------------------ GoFeedExtensionsKtTest.kt

    it('descriptionWithOnlyImageDoesNotReturnBlankSummaryAndGetsImageSet', 0, () => {
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const html: string = '  <img src=\'http://google.com/image.png\' alt=\'An image\'/> ';
      const item: FeederGoItem = new FeederGoItem(makeGoItem(`${baseUrl.toString()}/id`, '', html, html), null, baseUrl);
      expect(thumbnailEquals(item.thumbnail, new ImageFromHTML('http://google.com/image.png', null, null))).assertTrue();
      expect(item.snippet).assertEqual('[An image]');
    });

    it('linkFallsBackToGuidWhenGuidIsUrl', 0, () => {
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const item: FeederGoItem = new FeederGoItem(makeGoItem('https://example.com/article/123', null, null, null, null),
        null, baseUrl);
      expect(item.link).assertEqual('https://example.com/article/123');
    });

    it('linkDoesNotFallBackToGuidWhenGuidIsNonHttpUri', 0, () => {
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const item: FeederGoItem = new FeederGoItem(makeGoItem('urn:uuid:some-non-url-id'), null, baseUrl);
      expect(item.link).assertNull();
    });

    it('linkDoesNotFallBackToGuidWhenGuidIsInvalidUri', 0, () => {
      // Double ## makes the fragment contain a bare '#', which is invalid in RFC 3986
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const item: FeederGoItem = new FeederGoItem(makeGoItem('http://example.com/sub/##'), null, baseUrl);
      expect(item.link).assertNull();
    });

    it('linkIsPreferredOverGuidWhenBothPresent', 0, () => {
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const item: FeederGoItem = new FeederGoItem(makeGoItem('https://example.com/guid', null, null, null,
        'https://example.com/link'), null, baseUrl);
      expect(item.link).assertEqual('https://example.com/link');
    });

    it('feedThumbnailCandidateIsPreservedEvenWhenBodyFallbackIsChosen', 0, () => {
      const baseUrl: JavaUrl = JavaUrl.parse('http://test.com');
      const imageUrlStr: string = 'https://example.com/feed.jpg';
      const html: string = `<img src='${imageUrlStr}' alt='Article image'/>`;
      const attrs: Map<string, string> = new Map<string, string>();
      attrs.set('url', imageUrlStr);
      const byName: Map<string, GoExtension[]> = new Map<string, GoExtension[]>();
      byName.set('content', [new GoExtension('content', null, attrs, null)]);
      const extensions: GoExtensions = new Map<string, Map<string, GoExtension[]>>();
      extensions.set('media', byName);
      const item: FeederGoItem = new FeederGoItem(makeGoItem(`${baseUrl.toString()}/id`, null, html, html, null,
        extensions), null, baseUrl);
      const feedThumb: ThumbnailImage | null = item.feedThumbnail;
      expect(thumbnailEquals(feedThumb, new MediaImage(imageUrlStr))).assertTrue();
      expect(thumbnailEquals(item.thumbnail, new ImageFromHTML(imageUrlStr))).assertTrue();
    });

    // ------------------------------------------------ 补充用例（非源断言）

    it('supplementary_contentTypeGate', 0, () => {
      const video: Either<FeedParserError, ParsedFeed> = fromResponse('rss_anon.xml', 'https://foo.bar/video.mp4',
        'video/mp4');
      expect(video.isLeft()).assertTrue();
      const l: FeedParserError | null = video.leftOrNull();
      expect(l !== null && l.description.indexOf('video/mp4') >= 0).assertTrue();
      expect(fromResponse('rss_anon.xml', 'https://foo.bar/feed.xml', null).isRight()).assertTrue();
      expect(fromResponse('rss_anon.xml', 'https://foo.bar/feed.xml', 'text/html').isRight()).assertTrue();
      // HTML 页面：格式探测失败 → RSSParseError（Left，不抛）
      const html: Either<FeedParserError, ParsedFeed> = fromResponse('nixos.html', 'https://nixos.org/', 'text/html');
      expect(html.isLeft()).assertTrue();
      const hl: FeedParserError | null = html.leftOrNull();
      expect(hl !== null ? hl.kind : '').assertEqual('RSSParseError');
    });

    it('supplementary_latin1BytesAreDecodedByXmlDeclaration', 0, () => {
      const xmlText: string = '<?xml version="1.0" encoding="ISO-8859-1"?><rss version="2.0"><channel><title>t</title>' +
        '<item><title>x</title><description>Die größte Sache<slash:comments/></description></item>' +
        '</channel></rss>';
      const f: ParsedFeed = feedOf(parseFeed(latin1Bytes(xmlText), 'https://example.com/rss', 'application/xml'));
      expect(itemsOf(f).length).assertEqual(1);
      expect(contains(itemsOf(f)[0].content_text, 'größte')).assertTrue();
    });

    it('supplementary_jsonFeed', 0, () => {
      const json: string = '{"version":"https://jsonfeed.org/version/1","title":"J","home_page_url":"https://j.org/",' +
        '"feed_url":"https://j.org/other.json","icon":"/icon.png","author":{"name":"Me"},"items":[' +
        '{"id":"1","url":"/a","title":"A &amp; B","content_html":"<p>Hi</p>","date_published":"2024-03-14T14:08:43-04:00",' +
        '"attachments":[{"url":"https://j.org/a.mp3","mime_type":"audio/mpeg","size_in_bytes":123}]},' +
        '{"id":"2","url":"https://j.org/b","content_text":"plain"}]}';
      const f: ParsedFeed = feedOf(parseFeed(json, 'https://j.org/feed.json', 'application/feed+json'));
      expect(f.title).assertEqual('J');
      expect(f.home_page_url).assertEqual('https://j.org/');
      expect(f.feed_url).assertEqual('https://j.org/feed.json');
      expect(f.icon).assertEqual('https://j.org/icon.png');
      expect(f.author !== null ? f.author.name : null).assertEqual('Me');
      const items: ParsedArticle[] = itemsOf(f);
      expect(items.length).assertEqual(2);
      expect(items[0].id).assertEqual('https://j.org/1');
      expect(items[0].url).assertEqual('https://j.org/a');
      expect(items[0].title).assertEqual('A & B');
      expect(items[0].content_text).assertEqual('Hi');
      expect(items[0].date_published).assertEqual('2024-03-14T14:08:43-04:00');
      const att: ParsedEnclosure[] | null = items[0].attachments;
      expect(att !== null ? att.length : -1).assertEqual(1);
      expect(att !== null ? att[0].size_in_bytes : null).assertEqual(123);
      expect(att !== null ? att[0].mime_type : null).assertEqual('audio/mpeg');
      const second: ParsedArticle = items[1];
      expect(second.content_html).assertEqual('plain');
      const secondAuthor: ParsedAuthor | null = second.author;
      expect(secondAuthor !== null ? secondAuthor.name : null).assertEqual('Me');
    });
  });
}
