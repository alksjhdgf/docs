import { describe, it, expect } from '@ohos/hypium';
import { Feed } from '../main/ets/core/model/Feed';
import { FeedItem, FeedItemWithFeed } from '../main/ets/core/model/FeedItem';
import { EnclosureImage, ImageFromHTML, MediaImage } from '../main/ets/core/model/Thumbnail';
import {
  escape,
  escapeAttribute,
  opmlExportFileName,
  unescape,
  writeOpmlString
} from '../main/ets/core/parser/OpmlWriter';
import {
  OpmlError,
  OpmlFeedList,
  OpmlParsingError,
  OpmlPullParser,
  mergeBlocklistPatterns
} from '../main/ets/core/parser/OpmlParser';
import {
  SavedArticlesExport,
  SavedArticlesStore,
  buildSavedArticlesExport,
  decodeSavedArticlesExport,
  encodeSavedArticlesExport,
  importSavedArticlesContent,
  savedArticlesExportFileName
} from '../main/ets/core/parser/SavedArticlesExport';
import { Either } from '../main/ets/core/util/Either';
import {
  OPMLTEST_SAMPLE_FILE,
  OPMLTEST_SETTINGS,
  WRITER_EXPECTED_ESCAPED,
  WRITER_EXPECTED_WITH_SETTINGS,
  WRITER_TEST_SETTINGS,
  opmlFixture
} from './OpmlVectors';

function settingsMap(pairs: string[][]): Map<string, string> {
  const m: Map<string, string> = new Map<string, string>();
  for (const kv of pairs) {
    m.set(kv[0], kv[1]);
  }
  return m;
}

function feedOf(title: string, url: string, tag: string): Feed {
  const f: Feed = new Feed();
  f.id = 1;
  f.title = title;
  f.url = url;
  f.tag = tag;
  return f;
}

function writerFeed(tag: string, title: string, customTitle: string): Feed {
  const f: Feed = feedOf(title, 'http://example.com/rss.xml?format=feed&type=rss', tag);
  f.customTitle = customTitle;
  f.notify = true;
  f.imageUrl = 'https://example.com/feedImage';
  f.fullTextByDefault = true;
  f.openArticlesWith = 'reader';
  f.alternateId = true;
  f.fetchOgImages = false;
  return f;
}

function trimEnd(s: string): string {
  return s.replace(new RegExp('\\s+$'), '');
}

function findFirst(s: string, re: string): string | null {
  const m: RegExpMatchArray | null = s.match(new RegExp(re));
  return m === null ? null : m[0];
}

/** OPMLTest.createSampleFeeds */
function sampleFeeds(): Feed[] {
  const feeds: Feed[] = [];
  for (let i = 0; i <= 9; i++) {
    const f: Feed = new Feed();
    f.id = i + 1;
    f.url = `http://example.com/${i}/rss.xml`;
    f.title = `"${i}"`;
    f.customTitle = i === 0 ? '' : `custom "${i}"`;
    f.tag = i % 3 === 1 ? 'tag1' : (i % 3 === 2 ? 'tag2' : '');
    f.notify = i === 0;
    f.alternateId = i === 0;
    f.fullTextByDefault = i === 0;
    f.imageUrl = i === 0 ? 'https://example.com/feedImage.png' : null;
    f.openArticlesWith = i === 0 ? 'reader' : '';
    feeds.push(f);
  }
  return feeds;
}

/** FeedDao.loadTags（DISTINCT … COLLATE NOCASE）/ getFeedsByTitle（ORDER BY title）的内存等价 */
function tagsOf(feeds: Feed[]): string[] {
  const tags: string[] = [];
  for (const f of feeds) {
    if (tags.indexOf(f.tag) < 0) {
      tags.push(f.tag);
    }
  }
  return tags.sort((a: string, b: string): number => {
    const x: string = a.toLowerCase();
    const y: string = b.toLowerCase();
    return x < y ? -1 : (x > y ? 1 : 0);
  });
}

function feedsWithTag(feeds: Feed[], tag: string): Feed[] {
  return feeds.filter((f: Feed): boolean => f.tag === tag)
    .sort((a: Feed, b: Feed): number => a.title < b.title ? -1 : (a.title > b.title ? 1 : 0));
}

async function writeFeeds(feeds: Feed[], settings: Map<string, string>, blocked: string[]): Promise<string> {
  return await writeOpmlString(settings, blocked, tagsOf(feeds),
    async (tag: string): Promise<Feed[]> => feedsWithTag(feeds, tag));
}

async function parseInto(text: string): Promise<OpmlFeedList> {
  const list: OpmlFeedList = new OpmlFeedList();
  const result: Either<OpmlError, boolean> = await new OpmlPullParser(list).parseTextWithFallback(text);
  expect(result.isRight()).assertTrue();
  return list;
}

function feedsArray(list: OpmlFeedList): Feed[] {
  const out: Feed[] = [];
  list.feeds.forEach((f: Feed) => {
    out.push(f);
  });
  return out;
}

function distinctTags(feeds: Feed[]): number {
  return tagsOf(feeds).length;
}

class FakeStore implements SavedArticlesStore {
  feedIds: Map<string, number> = new Map<string, number>();
  insertedFeeds: Feed[] = [];
  itemsByGuid: Map<string, FeedItem> = new Map<string, FeedItem>();
  itemsByLink: Map<string, FeedItem> = new Map<string, FeedItem>();
  bookmarkedIds: number[] = [];
  insertedItems: FeedItem[] = [];
  linkBatches: string[][] = [];

  async getFeedIdForUrl(url: string): Promise<number | null> {
    const v: number | undefined = this.feedIds.get(url);
    return v === undefined ? null : v;
  }

  async insertFeed(feed: Feed): Promise<number> {
    this.insertedFeeds.push(feed);
    const id: number = 100 + this.insertedFeeds.length;
    this.feedIds.set(feed.url, id);
    return id;
  }

  async loadFeedItem(guid: string, feedId: number): Promise<FeedItem | null> {
    const v: FeedItem | undefined = this.itemsByGuid.get(`${guid}|${feedId}`);
    return v === undefined ? null : v;
  }

  async loadFeedItemByLink(link: string): Promise<FeedItem | null> {
    const v: FeedItem | undefined = this.itemsByLink.get(link);
    return v === undefined ? null : v;
  }

  async setBookmarked(id: number, bookmarked: boolean): Promise<void> {
    if (bookmarked) {
      this.bookmarkedIds.push(id);
    }
  }

  async insertFeedItem(item: FeedItem): Promise<number> {
    this.insertedItems.push(item);
    return this.insertedItems.length;
  }

  async setBookmarkedByLinks(links: string[]): Promise<number> {
    this.linkBatches.push(links);
    return links.length;
  }
}

function savedItem(link: string): FeedItemWithFeed {
  const it: FeedItemWithFeed = new FeedItemWithFeed();
  it.id = 7;
  it.link = link;
  it.guid = 'guid-1';
  it.plainTitle = 'A "title"';
  it.plainSnippet = 'snip\nnet';
  it.pubDate = '2020-01-02T03:04:05Z';
  it.primarySortTime = 1577934245000;
  it.readTime = null;
  it.author = null;
  it.thumbnailImage = new ImageFromHTML('https://example.com/img.png', 10, null);
  it.enclosureLink = null;
  it.enclosureType = null;
  it.wordCount = 12;
  it.wordCountFull = 34;
  it.feedUrl = 'https://example.com/feed.xml';
  it.feedTitle = 'Feed';
  it.feedCustomTitle = '';
  it.tag = 'news';
  it.fullTextByDefault = true;
  return it;
}

export default function opmlTest() {
  describe('OpmlGate', () => {
    // ---------------- OpmlWriterKtTest ----------------
    it('escapeAndUnescape', 0, () => {
      const original: string = 'A "feeditem" with id \'9\' > 0 & < 10';
      const escaped: string = escape(original);
      expect(unescape(escaped)).assertEqual(original);
      expect(escape(unescape(escaped))).assertEqual(escaped);
    });

    it('shouldEscapeStrings', 0, async (done: Function) => {
      const out: string = await writeOpmlString(new Map<string, string>(), [], ['quoted "tag"'],
        async (tag: string): Promise<Feed[]> => [writerFeed(tag, 'A "feeditem" with id \'9\' > 0 & < 10',
          'A custom "title" with id \'9\' > 0 & < 1e')]);
      expect(trimEnd(out)).assertEqual(WRITER_EXPECTED_ESCAPED);
      done();
    });

    it('writesRulesWithNewlinesEncodedAsCharacterReferences', 0, async (done: Function) => {
      const out: string = await writeOpmlString(new Map<string, string>(), [], ['news'],
        async (tag: string): Promise<Feed[]> => {
          const f: Feed = feedOf('title', 'http://example.com/rss.xml', tag);
          f.blockRules = 'Title=(?i)sponsored\r\nURL=ads & "tracking"';
          f.allowRules = 'Tag=(?i)linux';
          return [f];
        });
      expect(findFirst(out, 'feeder:blockRules="[^"]*"'))
        .assertEqual('feeder:blockRules="Title=(?i)sponsored&#10;URL=ads &amp; &quot;tracking&quot;"');
      expect(findFirst(out, 'feeder:allowRules="[^"]*"')).assertEqual('feeder:allowRules="Tag=(?i)linux"');
      done();
    });

    it('writesRulesWithTabsEncodedAsCharacterReferences', 0, async (done: Function) => {
      const out: string = await writeOpmlString(new Map<string, string>(), [], ['news'],
        async (tag: string): Promise<Feed[]> => {
          const f: Feed = feedOf('title', 'http://example.com/rss.xml', tag);
          f.blockRules = 'Content=Price:\tfree';
          return [f];
        });
      expect(findFirst(out, 'feeder:blockRules="[^"]*"')).assertEqual('feeder:blockRules="Content=Price:&#9;free"');
      expect(escapeAttribute('a\rb')).assertEqual('a&#10;b');
      done();
    });

    it('doesNotWriteRuleAttributesWhenRulesAreEmpty', 0, async (done: Function) => {
      const out: string = await writeOpmlString(new Map<string, string>(), [], ['news'],
        async (tag: string): Promise<Feed[]> => [feedOf('title', 'http://example.com/rss.xml', tag)]);
      expect(out.indexOf('feeder:blockRules') >= 0).assertFalse();
      expect(out.indexOf('feeder:allowRules') >= 0).assertFalse();
      done();
    });

    it('exportsSettings', 0, async (done: Function) => {
      const out: string = await writeOpmlString(settingsMap(WRITER_TEST_SETTINGS),
        ['foo', 'break "xml id \'9\' > 0 & < 10'], ['news'],
        async (tag: string): Promise<Feed[]> => [writerFeed(tag, 'title', 'customTitle')]);
      expect(trimEnd(out)).assertEqual(WRITER_EXPECTED_WITH_SETTINGS);
      done();
    });

    // ---------------- OPMLTest ----------------
    it('testWrite', 0, async (done: Function) => {
      const out: string = await writeFeeds(sampleFeeds(), settingsMap(OPMLTEST_SETTINGS), ['foo']);
      expect(out.trim()).assertEqual(OPMLTEST_SAMPLE_FILE);
      done();
    });

    it('testReadAndSettings', 0, async (done: Function) => {
      const list: OpmlFeedList = await parseInto(OPMLTEST_SAMPLE_FILE);
      const feeds: Feed[] = feedsArray(list);
      expect(feeds.length).assertEqual(10);
      for (const feed of feeds) {
        const i: number = parseInt(feed.url.split('/')[3]);
        expect(feed.url).assertEqual(`http://example.com/${i}/rss.xml`);
        if (i === 0) {
          expect(feed.title).assertEqual('"0"');
          expect(feed.customTitle).assertEqual('"0"');
          expect(feed.notify).assertTrue();
          expect(feed.alternateId).assertTrue();
          expect(feed.fullTextByDefault).assertTrue();
          expect(feed.openArticlesWith).assertEqual('reader');
          expect(feed.imageUrl).assertEqual('https://example.com/feedImage.png');
        } else {
          expect(feed.title).assertEqual(`custom "${i}"`);
          expect(feed.customTitle).assertEqual(feed.title);
          expect(feed.imageUrl).assertNull();
        }
        expect(feed.tag).assertEqual(i % 3 === 1 ? 'tag1' : (i % 3 === 2 ? 'tag2' : ''));
      }
      expect(list.settings.size).assertEqual(OPMLTEST_SETTINGS.length);
      for (const kv of OPMLTEST_SETTINGS) {
        expect(list.settings.get(kv[0])).assertEqual(kv[1]);
      }
      expect(list.blockList.length).assertEqual(1);
      expect(list.blockList[0]).assertEqual('foo');
      done();
    });

    it('testReadBadFile', 0, async (done: Function) => {
      const list: OpmlFeedList = new OpmlFeedList();
      const result: Either<OpmlError, boolean> =
        await new OpmlPullParser(list).parseTextWithFallback('This is just some bullshit in the file\n');
      expect(result.isLeft()).assertTrue();
      expect(result.leftOrNull() instanceof OpmlParsingError).assertTrue();
      expect(list.feeds.size).assertEqual(0);
      done();
    });

    it('multiLineRulesRoundTripThroughOpml', 0, async (done: Function) => {
      const blockRules: string = 'Title=(?i)sponsored\nURL=ads & "tracking"';
      const allowRules: string = 'Tag=(?i)linux\nAuthor=Bob';
      const f: Feed = feedOf('rules', 'http://example.com/rules.xml', 'rules');
      f.blockRules = blockRules;
      f.allowRules = allowRules;
      const out: string = await writeFeeds([f], new Map<string, string>(), []);
      const feeds: Feed[] = feedsArray(await parseInto(out));
      expect(feeds.length).assertEqual(1);
      expect(feeds[0].blockRules).assertEqual(blockRules);
      expect(feeds[0].allowRules).assertEqual(allowRules);
      done();
    });

    it('literalWhitespaceInAttributeIsNormalized', 0, async (done: Function) => {
      const feeds: Feed[] = feedsArray(await parseInto(
        '<opml xmlns:feeder="https://nononsenseapps.com/feeder"><body>' +
          '<outline xmlUrl="http://a.com/rss" feeder:blockRules="a\nb\tc"/></body></opml>'));
      expect(feeds[0].blockRules).assertEqual('a b c');
      done();
    });

    it('antennaPodOPMLImports', 0, async (done: Function) => {
      const feeds: Feed[] = feedsArray(await parseInto(opmlFixture('antennapod-feeds.opml')));
      expect(feeds.length).assertEqual(8);
      expect(distinctTags(feeds)).assertEqual(1);
      const expected: Map<string, string> = new Map<string, string>();
      expected.set('http://aliceisntdead.libsyn.com/rss', 'Alice Isn\'t Dead');
      expected.set('http://feeds.soundcloud.com/users/soundcloud:users:154104768/sounds.rss', 'Invisible City');
      expected.set('http://feeds.feedburner.com/PodCastle_Main', 'PodCastle');
      expected.set('http://www.artofstorytellingshow.com/podcast/storycast.xml', 'The Art of Storytelling with Brother Wolf');
      expected.set('http://feeds.feedburner.com/TheCleansed', 'The Cleansed: A Post-Apocalyptic Saga');
      expected.set('http://media.signumuniversity.org/tolkienprof/feed', 'The Tolkien Professor');
      expected.set('http://nightvale.libsyn.com/rss', 'Welcome to Night Vale');
      expected.set('http://withinthewires.libsyn.com/rss', 'Within the Wires');
      for (const feed of feeds) {
        expect(feed.tag).assertEqual('');
        expect(expected.get(feed.url)).assertEqual(feed.title);
      }
      done();
    });

    it('flymOPMLImports', 0, async (done: Function) => {
      const feeds: Feed[] = feedsArray(await parseInto(opmlFixture('Flym_auto_backup.opml')));
      expect(feeds.length).assertEqual(11);
      expect(distinctTags(feeds)).assertEqual(4);
      // [url, tag, customTitle, fullTextByDefault]
      const rows: string[][] = [
        ['http://www.smbc-comics.com/rss.php', 'black humor', 'SMBC', 'false'],
        ['http://www.deathbulge.com/rss.xml', 'black humor', 'Deathbulge', 'true'],
        ['http://www.sandraandwoo.com/gaia/feed/', 'comics', 'Gaia', 'false'],
        ['http://replaycomic.com/feed/', 'comics', 'Replay', 'true'],
        ['http://www.cuttimecomic.com/rss.php', 'comics', 'Cut Time', 'false'],
        ['http://www.commitstrip.com/feed/', 'comics', 'Commit strip', 'true'],
        ['http://www.sandraandwoo.com/feed/', 'comics', 'Sandra and Woo', 'false'],
        ['http://www.awakencomic.com/rss.php', 'comics', 'Awaken', 'true'],
        ['http://www.questionablecontent.net/QCRSS.xml', 'comics', 'Questionable Content', 'false'],
        ['https://www.archlinux.org/feeds/news/', 'Tech', 'Arch news', 'false'],
        ['https://grisebouille.net/feed/', 'Political humour', 'Grisebouille', 'true']
      ];
      for (const feed of feeds) {
        const row: string[] | undefined = rows.find((r: string[]): boolean => r[0] === feed.url);
        expect(row !== undefined).assertTrue();
        if (row !== undefined) {
          expect(feed.tag).assertEqual(row[1]);
          expect(feed.customTitle).assertEqual(row[2]);
          expect(feed.fullTextByDefault).assertEqual(row[3] === 'true');
        }
      }
      done();
    });

    it('rssGuardOPMLImports', 0, async (done: Function) => {
      // [url, tag, customTitle]（源 when 分支：未命中的 url 不断言）
      const rows: string[][] = [
        ['http://www.les-trois-sagesses.org/rss-articles.xml', 'Religion', 'Les trois sagesses'],
        ['http://www.avrildeperthuis.com/feed/', 'Amis', 'avril de perthuis'],
        ['http://www.fashioningtech.com/profiles/blog/feed?xn_auth=no', 'Actu Geek',
          'Everyone\'s Blog Posts - Fashioning Technology'],
        ['http://feeds2.feedburner.com/ChartPorn', 'Graphs', 'Chart Porn'],
        ['http://www.mosqueedeparis.net/index.php?format=feed&amp;type=atom', 'Religion', 'Mosquee de Paris'],
        ['http://sourceforge.net/projects/stuntrally/rss', 'Mainstream update', 'Stunt Rally'],
        ['http://www.mairie6.lyon.fr/cs/Satellite?Thematique=&TypeContenu=Actualite&pagename=RSSFeed&site=Mairie6', '',
          'Actualités']
      ];
      for (const name of ['rssguard_1.opml', 'rssguard_2.opml']) {
        const feeds: Feed[] = feedsArray(await parseInto(opmlFixture(name)));
        expect(feeds.length).assertEqual(30);
        expect(distinctTags(feeds)).assertEqual(6);
        for (const feed of feeds) {
          const row: string[] | undefined = rows.find((r: string[]): boolean => r[0] === feed.url);
          if (row !== undefined) {
            expect(feed.tag).assertEqual(row[1]);
            expect(feed.customTitle).assertEqual(row[2]);
          }
        }
      }
      done();
    });

    it('importPlenaryProgramming', 0, async (done: Function) => {
      expect(feedsArray(await parseInto(opmlFixture('Programming.opml'))).length).assertEqual(50);
      done();
    });

    it('testExportThenImport', 0, async (done: Function) => {
      const feeds: Feed[] = [
        feedOf('ExportThenImport', 'https://example.com/exportthenimport', ''),
        feedOf('So are > brackets', 'https://example.com/lt', ''),
        feedOf('So are < brackets', 'https://example.com/gt', '')
      ];
      const out: string = await writeFeeds(feeds, new Map<string, string>(), []);
      expect((await parseInto(out)).feeds.size).assertEqual(3);
      done();
    });

    // ---------------- 解析细节（FP-A53..A55、A59） ----------------
    it('parserDetails', 0, async (done: Function) => {
      const xml: string = '<?xml version="1.0"?><opml version="1.1" xmlns:f="https://nononsenseapps.com/feeder"><body>' +
        '<outline text="Outer"><outline title="Inner">' +
        '<outline text="Only text" xmlUrl="http://a.com/1" f:notify="TRUE" f:imageUrl="not a url"/>' +
        '<outline title="" xmlUrl="http://a.com/2" f:notify="yes" retrieveFullText="True"/>' +
        '</outline></outline>' +
        '<outline title="Bad" xmlUrl="not a url"/>' +
        '<outline title="&amp;lt;b&amp;gt;" xmlUrl="http://a.com/3" f:fullTextByDefault="false" retrieveFullText="true"/>' +
        '<f:settings><f:setting key="k" value="&amp;lt;"/><f:blocked pattern="x"/><f:blocked pattern="x"/></f:settings>' +
        '</body></opml>';
      const list: OpmlFeedList = await parseInto(xml);
      const feeds: Feed[] = feedsArray(list);
      expect(feeds.length).assertEqual(3);
      expect(feeds[0].title).assertEqual('Only text');
      expect(feeds[0].tag).assertEqual('Inner');
      expect(feeds[0].notify).assertTrue();
      expect(feeds[0].imageUrl).assertNull();
      expect(feeds[1].title).assertEqual('http://a.com/2');
      expect(feeds[1].customTitle).assertEqual('');
      expect(feeds[1].notify).assertFalse();
      expect(feeds[1].fullTextByDefault).assertTrue();
      expect(feeds[2].title).assertEqual('<b>');
      expect(feeds[2].tag).assertEqual('');
      expect(feeds[2].fullTextByDefault).assertFalse();
      expect(list.settings.get('k')).assertEqual('<');
      expect(list.blockList.length).assertEqual(1);
      done();
    });

    it('fallbackRegexRewrite', 0, async (done: Function) => {
      const bad: string = '<opml><body>\n<outline title="a &nbsp; b" xmlUrl="http://x.com/rss" />\n' +
        '<outline title="c" text="c" xmlUrl="http://y.com/rss"/>\n</body></opml>';
      const feeds: Feed[] = feedsArray(await parseInto(bad));
      expect(feeds.length).assertEqual(2);
      expect(feeds[0].url).assertEqual('http://x.com/rss');
      expect(feeds[0].title).assertEqual('http://x.com/rss');
      done();
    });

    it('handlesBlockedPatterns', 0, () => {
      const added: string[] = mergeBlocklistPatterns(['foo', 'existing', 'foo', 'injection break\';', '', ' '],
        ['existing']);
      expect(added.length).assertEqual(2);
      expect(added[0]).assertEqual('foo');
      expect(added[1]).assertEqual('injection break\';');
    });

    it('exportFileNames', 0, () => {
      const re: RegExp = new RegExp('^feeder-export-\\d{4}-\\d{2}-\\d{2}-\\d{1,5}\\.opml$');
      expect(re.test(opmlExportFileName())).assertTrue();
      const re2: RegExp = new RegExp('^feeder-saved-articles-\\d{4}-\\d{2}-\\d{2}-\\d{1,5}\\.json$');
      expect(re2.test(savedArticlesExportFileName())).assertTrue();
    });

    // ---------------- 收藏文章导出/导入（FP-A63..A65） ----------------
    it('savedArticlesEncodeEmpty', 0, () => {
      expect(encodeSavedArticlesExport(buildSavedArticlesExport([]))).assertEqual(
        '{\n    "format": "feeder-saved-articles",\n    "version": 1,\n    "articles": []\n}');
    });

    it('savedArticlesEncodeDecodeRoundTrip', 0, () => {
      const noLink: FeedItemWithFeed = savedItem('x');
      noLink.link = null;
      const json: string = encodeSavedArticlesExport(buildSavedArticlesExport([savedItem('https://e.com/a'), noLink]));
      expect(json.indexOf('        {\n            "link": "https://e.com/a",\n            "guid": "guid-1",') > 0)
        .assertTrue();
      expect(json.indexOf('"thumbnailImage": {\n                "type": "ImageFromHTML",\n' +
        '                "url": "https://example.com/img.png",\n                "width": 10\n            },') > 0)
        .assertTrue();
      expect(json.indexOf('"primarySortTime": "2020-01-02T03:04:05Z"') > 0).assertTrue();
      expect(json.indexOf('"readTime": null') > 0).assertTrue();
      const back: SavedArticlesExport = decodeSavedArticlesExport(json);
      expect(back.articles.length).assertEqual(1);
      expect(back.articles[0].title).assertEqual('A "title"');
      expect(back.articles[0].snippet).assertEqual('snip\nnet');
      expect(back.articles[0].feed.tag).assertEqual('news');
      expect(back.articles[0].feed.fullTextByDefault).assertTrue();
      expect(back.articles[0].thumbnailImage instanceof ImageFromHTML).assertTrue();
    });

    it('savedArticlesImportJson', 0, async (done: Function) => {
      const json: string = '  {"format":"feeder-saved-articles","version":1,"extra":1,"articles":[' +
        '{"link":"https://e.com/new","guid":"","title":"t","snippet":"s","pubDate":"2020-01-02T03:04:05Z",' +
        '"primarySortTime":"bad","readTime":null,"author":null,' +
        '"thumbnailImage":{"type":"EnclosureImage","url":"https://e.com/i.jpg","length":5},' +
        '"enclosureLink":null,"enclosureType":null,"wordCount":1,"wordCountFull":2,"unknown":true,' +
        '"feed":{"url":"https://e.com/feed","title":"F","customTitle":"C","tag":"T","fullTextByDefault":true}},' +
        '{"link":"https://e.com/old","guid":"g","title":"t","snippet":"s","pubDate":null,' +
        '"primarySortTime":"2021-01-01T00:00:00Z","readTime":null,"author":"a","thumbnailImage":null,' +
        '"enclosureLink":null,"enclosureType":null,"wordCount":0,"wordCountFull":0,' +
        '"feed":{"url":"not a url","title":"","customTitle":"","tag":"","fullTextByDefault":false}}]}';
      const store: FakeStore = new FakeStore();
      const old: FeedItem = new FeedItem();
      old.id = 55;
      store.itemsByLink.set('https://e.com/old', old);
      await importSavedArticlesContent(store, json, 1000);
      expect(store.insertedFeeds.length).assertEqual(1);
      expect(store.insertedFeeds[0].customTitle).assertEqual('C');
      expect(store.insertedFeeds[0].tag).assertEqual('T');
      expect(store.insertedFeeds[0].fullTextByDefault).assertTrue();
      expect(store.insertedItems.length).assertEqual(1);
      const it0: FeedItem = store.insertedItems[0];
      expect(it0.guid).assertEqual('https://e.com/new');
      expect(it0.notified).assertTrue();
      expect(it0.bookmarked).assertTrue();
      expect(it0.feedId).assertEqual(101);
      expect(it0.primarySortTime).assertEqual(1577934245000);
      expect(it0.firstSyncedTime).assertEqual(1577934245000);
      expect(it0.thumbnailImage instanceof EnclosureImage).assertTrue();
      expect(store.bookmarkedIds.length).assertEqual(1);
      expect(store.bookmarkedIds[0]).assertEqual(55);
      done();
    });

    it('savedArticlesImportRejectsWrongFormatAndVersion', 0, async (done: Function) => {
      let failures: number = 0;
      for (const json of ['{"format":"other","version":1,"articles":[]}',
        '{"format":"feeder-saved-articles","version":2,"articles":[]}',
        '{"format":"feeder-saved-articles","version":1}']) {
        try {
          await importSavedArticlesContent(new FakeStore(), json);
        } catch (e) {
          failures++;
        }
      }
      expect(failures).assertEqual(3);
      done();
    });

    it('savedArticlesImportLegacyLinks', 0, async (done: Function) => {
      const store: FakeStore = new FakeStore();
      await importSavedArticlesContent(store, ' https://a\r\n\nhttps://b\rhttps://a\n  \n');
      expect(store.linkBatches.length).assertEqual(1);
      expect(store.linkBatches[0].join(',')).assertEqual('https://a,https://b');
      expect(store.insertedItems.length).assertEqual(0);
      done();
    });

    it('savedArticlesMediaImageDecode', 0, () => {
      const e: SavedArticlesExport = decodeSavedArticlesExport('{"format":"f","version":1,"articles":[' +
        '{"link":"l","guid":"g","title":"t","snippet":"s","pubDate":null,"primarySortTime":"p","readTime":null,' +
        '"author":null,"thumbnailImage":{"url":"u","type":"MediaImage","height":3},"enclosureLink":null,' +
        '"enclosureType":null,"wordCount":0,"wordCountFull":0,' +
        '"feed":{"url":"u","title":"","customTitle":"","tag":"","fullTextByDefault":false}}]}');
      const t: MediaImage = e.articles[0].thumbnailImage as MediaImage;
      expect(t instanceof MediaImage).assertTrue();
      expect(t.height).assertEqual(3);
      expect(t.width).assertNull();
    });
  });
}
