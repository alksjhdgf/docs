/**
 * AtomFeedParser.ets —— gofeed Atom 0.3/1.0 解析器（atom.Parser）与 DefaultAtomTranslator，产出 GoFeed。
 *
 * 关键语义（照 gofeed）：
 *  - parseAtomText：取 innerxml 并 trim；含 CDATA → StripCDATA；否则按 type：text / text/* / (无 type 且无 mode)
 *    → DecodeEntities；含 xhtml → 去掉唯一包裹 div；html → 去掉唯一包裹 div 后 DecodeEntities（只解码一次）；
 *    其它 → 尝试 base64 解码，失败保留原文。
 *  - link 无 rel 视为 alternate；有 xml:base 时 href 按 base 解析。条目 link = 第一个 rel=alternate 的 href。
 *  - 条目无 published 时 published/publishedParsed 回退 updated；日期转 UTC。
 *  - Feed image = logo，否则 icon；作者取第一个 author。enclosure = rel=enclosure 的 link。
 * 偏差：gofeed 对 html/xhtml 内容在有 xml:base 时用 goquery 重写相对 URL 并重新序列化（resolveHTML），此处不做
 * （内容原样保留；Feeder 下游以条目链接为基准解析相对 URL）。stripWrappingDiv 以原文切片实现，不重新序列化。
 */
import { base64DecodeStrict, decodeUtf8 } from '../util/TextCodec';
import {
  emptyListToNull,
  emptyToNull,
  GoEnclosure,
  GoExtension,
  GoExtensions,
  GoFeed,
  GoImage,
  GoItem,
  GoPerson
} from './GoFeed';
import { FeedXmlTokenizer, XML_END_DOCUMENT, XML_END_TAG, XML_START_TAG } from './FeedXmlTokenizer';
import { resolveReference } from './FeedXmlText';
import { parsedUtcDateString } from './FeedDates';
import { decodeEntities, extensionsOrNull, goTrim, isExtension, parseExtension, parseText, stripCdata } from './GoFeedShared';

class AtomLink {
  href: string = '';
  rel: string = '';
  type: string = '';
  length: string = '';
}

class AtomPerson {
  name: string = '';
  email: string = '';
}

class AtomEntry {
  title: string = '';
  id: string = '';
  summary: string = '';
  content: string | null = null;
  updated: string = '';
  updatedParsed: string | null = null;
  published: string = '';
  publishedParsed: string | null = null;
  authors: AtomPerson[] = [];
  categories: string[] = [];
  links: AtomLink[] = [];
  rights: string = '';
  extensions: GoExtensions = new Map<string, Map<string, GoExtension[]>>();
}

class AtomFeedData {
  title: string = '';
  id: string = '';
  subtitle: string = '';
  updated: string = '';
  updatedParsed: string | null = null;
  links: AtomLink[] = [];
  authors: AtomPerson[] = [];
  categories: string[] = [];
  icon: string = '';
  logo: string = '';
  rights: string = '';
  generator: string = '';
  language: string = '';
  entries: AtomEntry[] = [];
  extensions: GoExtensions = new Map<string, Map<string, GoExtension[]>>();
}

/** goquery `body.Children()` 只有一个 div 时去壳：返回 div 前文本 + div 内部 + div 后文本（原文切片） */
export function stripWrappingDiv(content: string): string {
  const tok: FeedXmlTokenizer = new FeedXmlTokenizer(content);
  let topCount: number = 0;
  let isDiv: boolean = false;
  let openStart: number = -1;
  let openEnd: number = -1;
  let closeStart: number = -1;
  let closeEnd: number = -1;
  while (true) {
    const ev: number = tok.next();
    if (ev === XML_END_DOCUMENT) {
      break;
    }
    if (ev === XML_START_TAG && tok.depth() === 1) {
      topCount++;
      if (topCount === 1) {
        isDiv = tok.name.toLowerCase() === 'div';
        openStart = tok.tagStart;
        openEnd = tok.tagEnd;
      }
    } else if (ev === XML_END_TAG && tok.depth() === 0 && topCount === 1 && closeStart < 0) {
      closeStart = tok.tagStart;
      closeEnd = tok.tagEnd;
    }
  }
  if (topCount !== 1 || !isDiv || openStart < 0 || closeStart < openEnd) {
    return content;
  }
  return content.substring(0, openStart) + content.substring(openEnd, closeStart) + content.substring(closeEnd);
}

/** Go base64.StdEncoding.DecodeString（严格；忽略 \r \n）；失败返回 null */
function decodeBase64Strict(s: string): string | null {
  const clean: string = s.replace(new RegExp('[\\r\\n]', 'g'), '');
  if (clean.length % 4 !== 0 || !new RegExp('^[A-Za-z0-9+/]*={0,2}$').test(clean)) {
    return null;
  }
  const bytes: Uint8Array | null = base64DecodeStrict(clean);
  return bytes !== null ? decodeUtf8(bytes) : null;
}

/** 源 atom.Parser.parseAtomText（当前为 START_TAG） */
export function parseAtomText(tok: FeedXmlTokenizer): string {
  const lowerType: string = tok.attribute('type').toLowerCase();
  const lowerMode: string = tok.attribute('mode').toLowerCase();
  let result: string = goTrim(tok.readInnerXml());
  if (result.indexOf('<![CDATA[') >= 0) {
    return stripCdata(result);
  }
  if (lowerType === 'text' || lowerType.startsWith('text/') || (lowerType === '' && lowerMode === '')) {
    return decodeEntities(result);
  }
  if (lowerType.indexOf('xhtml') >= 0) {
    return stripWrappingDiv(result);
  }
  if (lowerType === 'html') {
    result = stripWrappingDiv(result);
    return decodeEntities(result);
  }
  const decoded: string | null = decodeBase64Strict(result);
  return decoded !== null ? decoded : result;
}

function parseAtomLink(tok: FeedXmlTokenizer): AtomLink {
  const l: AtomLink = new AtomLink();
  l.href = tok.attribute('href');
  l.type = tok.attribute('type');
  l.length = tok.attribute('length');
  l.rel = tok.attribute('rel');
  if (l.rel === '') {
    l.rel = 'alternate';
  }
  const base: string | null = tok.currentBase();
  tok.skip();
  if (l.href !== '' && base !== null) {
    l.href = resolveReference(base, l.href);
  }
  return l;
}

function parseAtomPerson(tok: FeedXmlTokenizer): AtomPerson {
  const p: AtomPerson = new AtomPerson();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (name === 'name') {
      p.name = parseAtomText(tok);
    } else if (name === 'email') {
      p.email = parseAtomText(tok);
    } else {
      tok.skip();
    }
  }
  return p;
}

function parseAtomCategory(tok: FeedXmlTokenizer): string {
  const term: string = tok.attribute('term');
  const label: string = tok.attribute('label');
  tok.skip();
  return term !== '' ? term : label;
}

function parseAtomEntry(tok: FeedXmlTokenizer): AtomEntry {
  const e: AtomEntry = new AtomEntry();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (isExtension(tok)) {
      parseExtension(e.extensions, tok);
    } else if (name === 'title') {
      e.title = parseAtomText(tok);
    } else if (name === 'id') {
      e.id = parseAtomText(tok);
    } else if (name === 'rights' || name === 'copyright') {
      e.rights = parseAtomText(tok);
    } else if (name === 'summary') {
      e.summary = parseAtomText(tok);
    } else if (name === 'updated' || name === 'modified') {
      e.updated = parseAtomText(tok);
      e.updatedParsed = parsedUtcDateString(e.updated);
    } else if (name === 'published' || name === 'issued') {
      e.published = parseAtomText(tok);
      e.publishedParsed = parsedUtcDateString(e.published);
    } else if (name === 'author') {
      e.authors.push(parseAtomPerson(tok));
    } else if (name === 'category') {
      e.categories.push(parseAtomCategory(tok));
    } else if (name === 'link') {
      e.links.push(parseAtomLink(tok));
    } else if (name === 'content') {
      e.content = parseAtomText(tok);
    } else {
      tok.skip();
    }
  }
  return e;
}

/** 源 atom.Parser.parseRoot（tok 位于根 START_TAG `feed`） */
function parseAtomRoot(tok: FeedXmlTokenizer): AtomFeedData {
  const f: AtomFeedData = new AtomFeedData();
  while (true) {
    const ev: number = tok.nextTag();
    if (ev !== XML_START_TAG) {
      break;
    }
    const name: string = tok.name.toLowerCase();
    if (isExtension(tok)) {
      parseExtension(f.extensions, tok);
    } else if (name === 'title') {
      f.title = parseAtomText(tok);
    } else if (name === 'id') {
      f.id = parseAtomText(tok);
    } else if (name === 'updated' || name === 'modified') {
      f.updated = parseAtomText(tok);
      f.updatedParsed = parsedUtcDateString(f.updated);
    } else if (name === 'subtitle' || name === 'tagline') {
      f.subtitle = parseAtomText(tok);
    } else if (name === 'link') {
      f.links.push(parseAtomLink(tok));
    } else if (name === 'generator') {
      f.generator = parseAtomText(tok);
    } else if (name === 'icon') {
      f.icon = parseText(tok);
    } else if (name === 'logo') {
      f.logo = parseText(tok);
    } else if (name === 'rights' || name === 'copyright') {
      f.rights = parseAtomText(tok);
    } else if (name === 'author') {
      f.authors.push(parseAtomPerson(tok));
    } else if (name === 'category') {
      f.categories.push(parseAtomCategory(tok));
    } else if (name === 'entry') {
      f.entries.push(parseAtomEntry(tok));
    } else {
      tok.skip();
    }
  }
  return f;
}

function firstLinkWithType(rel: string, links: AtomLink[]): AtomLink | null {
  for (let i = 0; i < links.length; i++) {
    if (links[i].rel === rel) {
      return links[i];
    }
  }
  return null;
}

function toPerson(p: AtomPerson): GoPerson {
  return new GoPerson(emptyToNull(p.name), emptyToNull(p.email));
}

function personsOrNull(list: AtomPerson[]): (GoPerson | null)[] | null {
  const out: (GoPerson | null)[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(toPerson(list[i]));
  }
  return emptyListToNull(out);
}

function linkHrefs(links: AtomLink[]): string[] | null {
  const out: string[] = [];
  for (let i = 0; i < links.length; i++) {
    if (links[i].href !== '') {
      out.push(links[i].href);
    }
  }
  return emptyListToNull(out);
}

function translateAtomEntry(e: AtomEntry): GoItem {
  const item: GoItem = new GoItem();
  item.title = emptyToNull(e.title);
  item.description = emptyToNull(e.summary);
  item.content = e.content !== null ? emptyToNull(e.content) : null;
  const alt: AtomLink | null = firstLinkWithType('alternate', e.links);
  item.link = alt !== null ? emptyToNull(alt.href) : null;
  item.links = linkHrefs(e.links);
  item.updated = emptyToNull(e.updated);
  item.updatedParsed = e.updatedParsed;
  item.published = emptyToNull(e.published !== '' ? e.published : e.updated);
  item.publishedParsed = e.publishedParsed !== null ? e.publishedParsed : e.updatedParsed;
  item.author = e.authors.length > 0 ? toPerson(e.authors[0]) : null;
  item.authors = personsOrNull(e.authors);
  item.guid = emptyToNull(e.id);
  const cats: string[] = [];
  for (let i = 0; i < e.categories.length; i++) {
    if (e.categories[i] !== '') {
      cats.push(e.categories[i]);
    }
  }
  item.categories = emptyListToNull(cats);
  const encs: (GoEnclosure | null)[] = [];
  for (let i = 0; i < e.links.length; i++) {
    const l: AtomLink = e.links[i];
    if (l.rel === 'enclosure') {
      encs.push(new GoEnclosure(emptyToNull(l.href), emptyToNull(l.length), emptyToNull(l.type)));
    }
  }
  item.enclosures = emptyListToNull(encs);
  item.extensions = extensionsOrNull(e.extensions);
  return item;
}

/** Atom：tok 已位于根 START_TAG `feed` */
export function parseAtomFeed(tok: FeedXmlTokenizer): GoFeed {
  const isAtom10: boolean = tok.space.trim() === 'http://www.w3.org/2005/Atom';
  const f: AtomFeedData = parseAtomRoot(tok);
  const feed: GoFeed = new GoFeed();
  feed.title = emptyToNull(f.title);
  feed.description = emptyToNull(f.subtitle);
  const alt: AtomLink | null = firstLinkWithType('alternate', f.links);
  feed.link = alt !== null ? emptyToNull(alt.href) : null;
  const self: AtomLink | null = firstLinkWithType('self', f.links);
  feed.feedLink = self !== null ? emptyToNull(self.href) : null;
  feed.links = linkHrefs(f.links);
  feed.updated = emptyToNull(f.updated);
  feed.updatedParsed = f.updatedParsed;
  feed.author = f.authors.length > 0 ? toPerson(f.authors[0]) : null;
  feed.authors = personsOrNull(f.authors);
  if (f.logo !== '') {
    feed.image = new GoImage(f.logo, null);
  } else if (f.icon !== '') {
    feed.image = new GoImage(f.icon, null);
  }
  feed.copyright = emptyToNull(f.rights);
  feed.generator = emptyToNull(f.generator);
  feed.categories = emptyListToNull(f.categories.filter((c: string): boolean => c !== ''));
  feed.extensions = extensionsOrNull(f.extensions);
  const items: (GoItem | null)[] = [];
  for (let i = 0; i < f.entries.length; i++) {
    items.push(translateAtomEntry(f.entries[i]));
  }
  feed.items = emptyListToNull(items);
  feed.feedType = 'atom';
  feed.feedVersion = isAtom10 ? '1.0' : '0.3';
  return feed;
}
