/**
 * JsonFeedParser.ets —— gofeed JSON Feed 1.0/1.1 解析器（json.Parser）与 DefaultJSONTranslator，产出 GoFeed。
 *
 * 映射（照 gofeed）：title→title、description→description、home_page_url→link、feed_url→feedLink、
 * icon（否则 favicon）→image、author（否则 authors[0]）→author、language→language；
 * items[]：id→guid、url→link、title→title、summary→description、content_html（否则 content_text）→content、
 * image（否则 banner_image）→image、date_published/date_modified→published/updated（ParseDate 成功才有 *Parsed）、
 * author（否则 authors[0]）→author、tags→categories、attachments→enclosures{url, length=size_in_bytes, type=mime_type}。
 * 宽容差异：Go 对字段类型严格（如 id 为数字会令 json.Unmarshal 失败）；此处数字/布尔按字符串接受，其它错类型视为缺失。
 */
import { emptyListToNull, emptyToNull, GoEnclosure, GoFeed, GoImage, GoItem, GoPerson } from './GoFeed';
import { parsedDateString } from './FeedDates';
import { FeedParseException } from './GoFeedShared';

type JsonObj = Record<string, Object | null>;

function isObject(v: Object | null | undefined): boolean {
  return v !== null && v !== undefined && typeof v === 'object' && !Array.isArray(v);
}

function getStr(o: JsonObj, key: string): string {
  const v: Object | null | undefined = o[key];
  if (v === null || v === undefined) {
    return '';
  }
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number' || typeof v === 'boolean') {
    return `${v}`;
  }
  return '';
}

function getObj(o: JsonObj, key: string): JsonObj | null {
  const v: Object | null | undefined = o[key];
  return isObject(v) ? v as JsonObj : null;
}

function getArr(o: JsonObj, key: string): Object[] {
  const v: Object | null | undefined = o[key];
  if (v !== null && v !== undefined && Array.isArray(v)) {
    return v as Object[];
  }
  return [];
}

function toPerson(o: JsonObj | null): GoPerson | null {
  if (o === null) {
    return null;
  }
  return new GoPerson(emptyToNull(getStr(o, 'name')), null);
}

/** author，否则 authors 第一个对象 */
function firstAuthor(o: JsonObj): GoPerson | null {
  const a: GoPerson | null = toPerson(getObj(o, 'author'));
  if (a !== null) {
    return a;
  }
  const list: Object[] = getArr(o, 'authors');
  for (let i = 0; i < list.length; i++) {
    if (isObject(list[i])) {
      return toPerson(list[i] as JsonObj);
    }
  }
  return null;
}

function translateJsonItem(o: JsonObj): GoItem {
  const item: GoItem = new GoItem();
  item.guid = emptyToNull(getStr(o, 'id'));
  item.link = emptyToNull(getStr(o, 'url'));
  item.links = item.link !== null ? [item.link] : null;
  item.title = emptyToNull(getStr(o, 'title'));
  item.description = emptyToNull(getStr(o, 'summary'));
  const html: string = getStr(o, 'content_html');
  item.content = emptyToNull(html !== '' ? html : getStr(o, 'content_text'));
  const image: string = getStr(o, 'image');
  const banner: string = getStr(o, 'banner_image');
  if (image !== '') {
    item.image = new GoImage(image, null);
  } else if (banner !== '') {
    item.image = new GoImage(banner, null);
  }
  item.published = emptyToNull(getStr(o, 'date_published'));
  item.publishedParsed = parsedDateString(item.published);
  item.updated = emptyToNull(getStr(o, 'date_modified'));
  item.updatedParsed = parsedDateString(item.updated);
  item.author = firstAuthor(o);
  item.authors = item.author !== null ? [item.author] : null;
  const tags: Object[] = getArr(o, 'tags');
  const cats: string[] = [];
  for (let i = 0; i < tags.length; i++) {
    if (typeof tags[i] === 'string') {
      cats.push(tags[i] as string);
    }
  }
  item.categories = emptyListToNull(cats);
  const atts: Object[] = getArr(o, 'attachments');
  const encs: (GoEnclosure | null)[] = [];
  for (let i = 0; i < atts.length; i++) {
    if (!isObject(atts[i])) {
      continue;
    }
    const a: JsonObj = atts[i] as JsonObj;
    const sizeRaw: Object | null | undefined = a['size_in_bytes'];
    let length: string | null = null;
    if (typeof sizeRaw === 'number') {
      // Go: strconv.FormatInt(int64)，0 → "0"
      length = `${Math.trunc(sizeRaw as number)}`;
    }
    encs.push(new GoEnclosure(emptyToNull(getStr(a, 'url')), length, emptyToNull(getStr(a, 'mime_type'))));
  }
  item.enclosures = emptyListToNull(encs);
  return item;
}

/** JSON Feed 文本 → GoFeed；非法 JSON / 根非对象抛 FeedParseException */
export function parseJsonFeed(text: string): GoFeed {
  let root: Object | null = null;
  try {
    root = JSON.parse(text) as Object | null;
  } catch (e) {
    throw new FeedParseException(`Failed to parse JSON feed: ${(e as Error).message}`);
  }
  if (!isObject(root)) {
    throw new FeedParseException('JSON feed root is not an object');
  }
  const o: JsonObj = root as JsonObj;
  const feed: GoFeed = new GoFeed();
  feed.title = emptyToNull(getStr(o, 'title'));
  feed.description = emptyToNull(getStr(o, 'description'));
  feed.link = emptyToNull(getStr(o, 'home_page_url'));
  feed.feedLink = emptyToNull(getStr(o, 'feed_url'));
  const links: string[] = [];
  if (feed.link !== null) {
    links.push(feed.link);
  }
  if (feed.feedLink !== null) {
    links.push(feed.feedLink);
  }
  feed.links = emptyListToNull(links);
  const icon: string = getStr(o, 'icon');
  const favicon: string = getStr(o, 'favicon');
  if (icon !== '') {
    feed.image = new GoImage(icon, null);
  } else if (favicon !== '') {
    feed.image = new GoImage(favicon, null);
  }
  feed.author = firstAuthor(o);
  feed.authors = feed.author !== null ? [feed.author] : null;
  feed.language = emptyToNull(getStr(o, 'language'));
  const rawItems: Object[] = getArr(o, 'items');
  const items: (GoItem | null)[] = [];
  for (let i = 0; i < rawItems.length; i++) {
    if (isObject(rawItems[i])) {
      items.push(translateJsonItem(rawItems[i] as JsonObj));
    }
  }
  feed.items = emptyListToNull(items);
  feed.feedType = 'json';
  feed.feedVersion = emptyToNull(getStr(o, 'version'));
  return feed;
}
