/**
 * XmlFeedParser.ets —— gofeed RSS 0.9x/2.0 与 RSS 1.0(RDF) 解析器（rss.Parser）与 DefaultRSSTranslator，产出 GoFeed。
 * 公共层（ParseText/扩展解析等）见 GoFeedShared.ets；Atom 见 AtomFeedParser.ets；JSON Feed 见 JsonFeedParser.ets；
 * 格式探测与入口见 FeedMapping.parseGoFeed。输出遵守 Go json omitempty：空串/空数组 → null（见 GoFeed.ets）。
 */
import {
  emptyListToNull,
  emptyToNull,
  GoEnclosure,
  GoExtension,
  GoExtensions,
  GoFeed,
  GoImage,
  GoItem
} from './GoFeed';
import { FeedXmlTokenizer, XML_START_TAG } from './FeedXmlTokenizer';
import { parsedDateString, parsedUtcDateString } from './FeedDates';
import {
  extensionsOrNull,
  extFirst,
  extFirstAttr,
  extValues,
  isExtension,
  parseExtension,
  parseText,
  personFromText
} from './GoFeedShared';

// ---------------------------------------------------------------- RSS

class RssImage {
  url: string = '';
  title: string = '';
}

class RssItem {
  title: string = '';
  description: string = '';
  content: string = '';
  link: string = '';
  author: string = '';
  pubDate: string = '';
  pubDateParsed: string | null = null;
  guid: string | null = null;
  categories: string[] = [];
  enclosures: GoEnclosure[] = [];
  extensions: GoExtensions = new Map<string, Map<string, GoExtension[]>>();
}

class RssChannel {
  title: string = '';
  link: string = '';
  description: string = '';
  language: string = '';
  copyright: string = '';
  managingEditor: string = '';
  webMaster: string = '';
  pubDate: string = '';
  lastBuildDate: string = '';
  generator: string = '';
  categories: string[] = [];
  image: RssImage | null = null;
  items: RssItem[] = [];
  extensions: GoExtensions = new Map<string, Map<string, GoExtension[]>>();
  version: string = '';
}

function parseRssImage(tok: FeedXmlTokenizer): RssImage {
  const img: RssImage = new RssImage();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (name === 'url') {
      img.url = parseText(tok);
    } else if (name === 'title') {
      img.title = parseText(tok);
    } else {
      tok.skip();
    }
  }
  return img;
}

function parseRssItem(tok: FeedXmlTokenizer): RssItem {
  const item: RssItem = new RssItem();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (isExtension(tok)) {
      parseExtension(item.extensions, tok);
    } else if (name === 'title') {
      item.title = parseText(tok);
    } else if (name === 'description') {
      item.description = parseText(tok);
    } else if (name === 'encoded') {
      const prefix: string | undefined = tok.spaces.get(tok.space.trim());
      if (prefix === 'content') {
        item.content = parseText(tok);
      } else {
        tok.skip();
      }
    } else if (name === 'link') {
      item.link = parseText(tok);
    } else if (name === 'author') {
      item.author = parseText(tok);
    } else if (name === 'pubdate') {
      item.pubDate = parseText(tok);
      item.pubDateParsed = parsedUtcDateString(item.pubDate);
    } else if (name === 'enclosure') {
      const enc: GoEnclosure = new GoEnclosure(emptyToNull(tok.attribute('url')), emptyToNull(tok.attribute('length')),
        emptyToNull(tok.attribute('type')));
      tok.skip();
      item.enclosures.push(enc);
    } else if (name === 'guid') {
      item.guid = parseText(tok);
    } else if (name === 'category') {
      item.categories.push(parseText(tok));
    } else {
      tok.skip();
    }
  }
  return item;
}

function parseRssChannel(tok: FeedXmlTokenizer): RssChannel {
  const ch: RssChannel = new RssChannel();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (isExtension(tok)) {
      parseExtension(ch.extensions, tok);
    } else if (name === 'title') {
      ch.title = parseText(tok);
    } else if (name === 'description') {
      ch.description = parseText(tok);
    } else if (name === 'link') {
      ch.link = parseText(tok);
    } else if (name === 'language') {
      ch.language = parseText(tok);
    } else if (name === 'copyright') {
      ch.copyright = parseText(tok);
    } else if (name === 'managingeditor') {
      ch.managingEditor = parseText(tok);
    } else if (name === 'webmaster') {
      ch.webMaster = parseText(tok);
    } else if (name === 'pubdate') {
      ch.pubDate = parseText(tok);
    } else if (name === 'lastbuilddate') {
      ch.lastBuildDate = parseText(tok);
    } else if (name === 'generator') {
      ch.generator = parseText(tok);
    } else if (name === 'category') {
      ch.categories.push(parseText(tok));
    } else if (name === 'image') {
      ch.image = parseRssImage(tok);
    } else if (name === 'item') {
      ch.items.push(parseRssItem(tok));
    } else {
      tok.skip();
    }
  }
  return ch;
}

/** 源 rss.Parser.parseRoot：根为 rss 或 rdf（tok 位于根 START_TAG） */
function parseRssRoot(tok: FeedXmlTokenizer, rootName: string): RssChannel {
  const version: string = rootName === 'rdf' ? '1.0' : tok.attribute('version');
  let channel: RssChannel | null = null;
  let image: RssImage | null = null;
  const items: RssItem[] = [];
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    if (isExtension(tok)) {
      tok.skip();
      continue;
    }
    const name: string = tok.name.toLowerCase();
    if (name === 'channel') {
      channel = parseRssChannel(tok);
    } else if (name === 'item') {
      items.push(parseRssItem(tok));
    } else if (name === 'image') {
      image = parseRssImage(tok);
    } else {
      tok.skip();
    }
  }
  const ch: RssChannel = channel !== null ? channel : new RssChannel();
  for (let i = 0; i < items.length; i++) {
    ch.items.push(items[i]);
  }
  if (image !== null) {
    ch.image = image;
  }
  ch.version = version;
  return ch;
}

function firstOrEmpty(list: string[]): string {
  return list.length > 0 ? list[0] : '';
}

/** DefaultRSSTranslator：条目 */
function translateRssItem(it: RssItem): GoItem {
  const ext: GoExtensions = it.extensions;
  const item: GoItem = new GoItem();
  const dcTitle: string[] = extValues(ext, 'dc', 'title');
  item.title = emptyToNull(it.title.length > 0 ? it.title : firstOrEmpty(dcTitle));
  const dcDesc: string[] = extValues(ext, 'dc', 'description');
  item.description = emptyToNull(it.description.length > 0 ? it.description : firstOrEmpty(dcDesc));
  item.content = emptyToNull(it.content);
  item.link = emptyToNull(it.link);
  item.links = it.link.length > 0 ? [it.link] : null;
  const dcDate: string[] = extValues(ext, 'dc', 'date');
  if (it.pubDate.length > 0) {
    item.published = it.pubDate;
  } else if (dcDate.length > 0) {
    item.published = emptyToNull(dcDate[0]);
  }
  if (it.pubDateParsed !== null) {
    item.publishedParsed = it.pubDateParsed;
  } else if (dcDate.length > 0) {
    item.publishedParsed = parsedDateString(dcDate[0]);
  }
  // translateItemAuthor：author → dc:author → dc:creator → itunes:author
  const dcAuthor: string[] = extValues(ext, 'dc', 'author');
  const dcCreator: string[] = extValues(ext, 'dc', 'creator');
  const itunesAuthor: string = extFirst(ext, 'itunes', 'author');
  if (it.author.length > 0) {
    item.author = personFromText(it.author);
  } else if (dcAuthor.length > 0) {
    item.author = personFromText(dcAuthor[0]);
  } else if (dcCreator.length > 0) {
    item.author = personFromText(dcCreator[0]);
  } else if (itunesAuthor.length > 0) {
    item.author = personFromText(itunesAuthor);
  }
  item.authors = item.author !== null ? [item.author] : null;
  item.guid = it.guid !== null ? emptyToNull(it.guid) : null;
  const itunesImage: string = extFirstAttr(ext, 'itunes', 'image', 'href');
  if (itunesImage.length > 0) {
    item.image = new GoImage(itunesImage, null);
  }
  const cats: string[] = [];
  for (let i = 0; i < it.categories.length; i++) {
    cats.push(it.categories[i]);
  }
  const keywords: string = extFirst(ext, 'itunes', 'keywords');
  if (keywords.length > 0) {
    const parts: string[] = keywords.split(',');
    for (let i = 0; i < parts.length; i++) {
      cats.push(parts[i].trim());
    }
  }
  const subjects: string[] = extValues(ext, 'dc', 'subject');
  for (let i = 0; i < subjects.length; i++) {
    cats.push(subjects[i]);
  }
  item.categories = emptyListToNull(cats);
  const encs: (GoEnclosure | null)[] = [];
  for (let i = 0; i < it.enclosures.length; i++) {
    encs.push(it.enclosures[i]);
  }
  item.enclosures = emptyListToNull(encs);
  item.extensions = extensionsOrNull(ext);
  return item;
}

/** DefaultRSSTranslator：Feed */
function translateRss(ch: RssChannel, version: string): GoFeed {
  const ext: GoExtensions = ch.extensions;
  const feed: GoFeed = new GoFeed();
  feed.title = emptyToNull(ch.title.length > 0 ? ch.title : firstOrEmpty(extValues(ext, 'dc', 'title')));
  feed.description = emptyToNull(ch.description.length > 0 ? ch.description : extFirst(ext, 'itunes', 'summary'));
  feed.link = emptyToNull(ch.link);
  feed.links = ch.link.length > 0 ? [ch.link] : null;
  feed.updated = emptyToNull(ch.lastBuildDate);
  feed.updatedParsed = parsedUtcDateString(ch.lastBuildDate);
  feed.published = emptyToNull(ch.pubDate);
  feed.publishedParsed = parsedUtcDateString(ch.pubDate);
  const dcAuthor: string[] = extValues(ext, 'dc', 'author');
  const dcCreator: string[] = extValues(ext, 'dc', 'creator');
  const itunesAuthor: string = extFirst(ext, 'itunes', 'author');
  if (ch.managingEditor.length > 0) {
    feed.author = personFromText(ch.managingEditor);
  } else if (ch.webMaster.length > 0) {
    feed.author = personFromText(ch.webMaster);
  } else if (dcAuthor.length > 0) {
    feed.author = personFromText(dcAuthor[0]);
  } else if (dcCreator.length > 0) {
    feed.author = personFromText(dcCreator[0]);
  } else if (itunesAuthor.length > 0) {
    feed.author = personFromText(itunesAuthor);
  }
  feed.authors = feed.author !== null ? [feed.author] : null;
  feed.language = emptyToNull(ch.language);
  if (ch.image !== null) {
    feed.image = new GoImage(emptyToNull(ch.image.url), emptyToNull(ch.image.title));
  } else {
    const itunesImage: string = extFirstAttr(ext, 'itunes', 'image', 'href');
    if (itunesImage.length > 0) {
      feed.image = new GoImage(itunesImage, null);
    }
  }
  feed.copyright = emptyToNull(ch.copyright);
  feed.generator = emptyToNull(ch.generator);
  feed.categories = emptyListToNull(ch.categories);
  feed.extensions = extensionsOrNull(ext);
  const items: (GoItem | null)[] = [];
  for (let i = 0; i < ch.items.length; i++) {
    items.push(translateRssItem(ch.items[i]));
  }
  feed.items = emptyListToNull(items);
  feed.feedType = 'rss';
  feed.feedVersion = emptyToNull(version);
  return feed;
}

/** RSS / RDF：tok 已位于根 START_TAG（rootName 为小写本地名 rss / rdf） */
export function parseRssFeed(tok: FeedXmlTokenizer, rootName: string): GoFeed {
  const ch: RssChannel = parseRssRoot(tok, rootName);
  return translateRss(ch, ch.version);
}
