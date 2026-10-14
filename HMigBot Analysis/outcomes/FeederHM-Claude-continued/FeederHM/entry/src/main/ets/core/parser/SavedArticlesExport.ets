/**
 * SavedArticlesExport.ets —— 源 model/export/SavedArticlesExporter.kt + SavedArticlesImporter.kt（FP-A63..A67）。
 *
 * 导出：kotlinx Json { prettyPrint = true }（4 空格缩进、`"k": v`、空数组 `[]`、explicitNulls → 可空字段写 null；
 *       thumbnailImage 多态判别字段 `type` 在前，width/height 为 null（默认值）时省略）。
 * 导入：内容 trimStart 以 `{` 开头 → JSON（ignoreUnknownKeys，缺必填字段/类型不符即失败）；否则旧格式"每行一个链接"。
 * 纯逻辑（DB 访问经 SavedArticlesStore 注入；不依赖系统 Kit）。落盘/Toast 动作与 DB 实现见 OpmlActions.ets。
 */
import { Feed } from '../model/Feed';
import { FeedItem, FeedItemWithFeed } from '../model/FeedItem';
import {
  EnclosureImage,
  ImageFromHTML,
  MediaImage,
  THUMBNAIL_TYPE_ENCLOSURE_IMAGE,
  THUMBNAIL_TYPE_IMAGE_FROM_HTML,
  THUMBNAIL_TYPE_MEDIA_IMAGE,
  ThumbnailImage
} from '../model/Thumbnail';
import { JavaUrl, JavaZonedDateTime, instantParse, instantToString } from '../util/JavaCompat';
import { exportFileStamp } from './OpmlWriter';

export const SAVED_ARTICLES_EXPORT_FORMAT: string = 'feeder-saved-articles';
export const SAVED_ARTICLES_EXPORT_VERSION: number = 1;

// =====================================================================
// 数据类（源 @Serializable）
// =====================================================================

export class SavedArticleFeedExportItem {
  url: string = '';
  title: string = '';
  customTitle: string = '';
  tag: string = '';
  fullTextByDefault: boolean = false;
}

export class SavedArticleExportItem {
  link: string = '';
  guid: string = '';
  title: string = '';
  snippet: string = '';
  pubDate: string | null = null;
  primarySortTime: string = '';
  readTime: string | null = null;
  author: string | null = null;
  thumbnailImage: ThumbnailImage | null = null;
  enclosureLink: string | null = null;
  enclosureType: string | null = null;
  wordCount: number = 0;
  wordCountFull: number = 0;
  feed: SavedArticleFeedExportItem = new SavedArticleFeedExportItem();
}

export class SavedArticlesExport {
  format: string = SAVED_ARTICLES_EXPORT_FORMAT;
  version: number = SAVED_ARTICLES_EXPORT_VERSION;
  articles: SavedArticleExportItem[] = [];
}

/** 源 FeedItemWithFeed.toSavedArticleExportItem()：link 为 null → 跳过 */
export function toSavedArticleExportItem(it: FeedItemWithFeed): SavedArticleExportItem | null {
  if (it.link === null) {
    return null;
  }
  const a: SavedArticleExportItem = new SavedArticleExportItem();
  a.link = it.link;
  a.guid = it.guid;
  a.title = it.plainTitle;
  a.snippet = it.plainSnippet;
  a.pubDate = it.pubDate;
  a.primarySortTime = instantToString(it.primarySortTime);
  a.readTime = it.readTime === null ? null : instantToString(it.readTime);
  a.author = it.author;
  a.thumbnailImage = it.thumbnailImage;
  a.enclosureLink = it.enclosureLink;
  a.enclosureType = it.enclosureType;
  a.wordCount = it.wordCount;
  a.wordCountFull = it.wordCountFull;
  const f: SavedArticleFeedExportItem = new SavedArticleFeedExportItem();
  f.url = it.feedUrl;
  f.title = it.feedTitle;
  f.customTitle = it.feedCustomTitle;
  f.tag = it.tag;
  f.fullTextByDefault = it.fullTextByDefault;
  a.feed = f;
  return a;
}

// =====================================================================
// kotlinx prettyPrint 编码
// =====================================================================

const INDENT: string = '    ';

class JsonObj {
  readonly keys: string[] = [];
  readonly values: string[] = [];

  /** value 为已编码 JSON 片段（嵌套对象以 render 传入当前层级生成） */
  put(key: string, encoded: string): JsonObj {
    this.keys.push(key);
    this.values.push(encoded);
    return this;
  }

  render(level: number): string {
    if (this.keys.length === 0) {
      return '{}';
    }
    const pad: string = INDENT.repeat(level + 1);
    const parts: string[] = [];
    for (let i = 0; i < this.keys.length; i++) {
      parts.push(`${pad}${JSON.stringify(this.keys[i])}: ${this.values[i]}`);
    }
    return '{\n' + parts.join(',\n') + '\n' + INDENT.repeat(level) + '}';
  }
}

function jStr(s: string | null): string {
  return s === null ? 'null' : JSON.stringify(s);
}

function thumbnailJson(t: ThumbnailImage | null, level: number): string {
  if (t === null) {
    return 'null';
  }
  const o: JsonObj = new JsonObj();
  o.put('type', JSON.stringify(t.type));
  o.put('url', JSON.stringify(t.url));
  if (t instanceof EnclosureImage) {
    o.put('length', `${(t as EnclosureImage).length}`);
  } else {
    if (t.width !== null) {
      o.put('width', `${t.width}`);
    }
    if (t.height !== null) {
      o.put('height', `${t.height}`);
    }
  }
  return o.render(level);
}

function articleJson(a: SavedArticleExportItem, level: number): string {
  const f: JsonObj = new JsonObj()
    .put('url', jStr(a.feed.url))
    .put('title', jStr(a.feed.title))
    .put('customTitle', jStr(a.feed.customTitle))
    .put('tag', jStr(a.feed.tag))
    .put('fullTextByDefault', `${a.feed.fullTextByDefault}`);
  const o: JsonObj = new JsonObj()
    .put('link', jStr(a.link))
    .put('guid', jStr(a.guid))
    .put('title', jStr(a.title))
    .put('snippet', jStr(a.snippet))
    .put('pubDate', jStr(a.pubDate))
    .put('primarySortTime', jStr(a.primarySortTime))
    .put('readTime', jStr(a.readTime))
    .put('author', jStr(a.author))
    .put('thumbnailImage', thumbnailJson(a.thumbnailImage, level + 1))
    .put('enclosureLink', jStr(a.enclosureLink))
    .put('enclosureType', jStr(a.enclosureType))
    .put('wordCount', `${a.wordCount}`)
    .put('wordCountFull', `${a.wordCountFull}`)
    .put('feed', f.render(level + 1));
  return o.render(level);
}

/** 编码整份导出（FP-A63） */
export function encodeSavedArticlesExport(export0: SavedArticlesExport): string {
  let articles: string = '[]';
  if (export0.articles.length > 0) {
    const pad: string = INDENT.repeat(2);
    const parts: string[] = export0.articles.map((a: SavedArticleExportItem): string => pad + articleJson(a, 2));
    articles = '[\n' + parts.join(',\n') + '\n' + INDENT + ']';
  }
  return new JsonObj()
    .put('format', jStr(export0.format))
    .put('version', `${export0.version}`)
    .put('articles', articles)
    .render(0);
}

/** 由 FeedItemDao.getBookmarkedItemsForExport()（bookmarked=1 且 link 非空，ORDER BY link）构造导出 */
export function buildSavedArticlesExport(items: FeedItemWithFeed[]): SavedArticlesExport {
  const e: SavedArticlesExport = new SavedArticlesExport();
  for (const it of items) {
    const a: SavedArticleExportItem | null = toSavedArticleExportItem(it);
    if (a !== null) {
      e.articles.push(a);
    }
  }
  return e;
}

// =====================================================================
// kotlinx 解码（ignoreUnknownKeys = true）
// =====================================================================

export class SerializationException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SerializationException';
  }
}

type JRec = Record<string, Object | null>;

function asRecord(v: Object | null | undefined, what: string): JRec {
  if (v === null || v === undefined || typeof v !== 'object' || Array.isArray(v)) {
    throw new SerializationException(`Expected JsonObject for ${what}`);
  }
  return v as JRec;
}

function has(rec: JRec, key: string): boolean {
  return Object.keys(rec).indexOf(key) >= 0;
}

function missing(key: string, type: string): SerializationException {
  return new SerializationException(
    `Field '${key}' is required for type with serial name '${type}', but it was missing`);
}

function reqStr(rec: JRec, key: string, type: string): string {
  if (!has(rec, key)) {
    throw missing(key, type);
  }
  const v: Object | null = rec[key];
  if (typeof v !== 'string') {
    throw new SerializationException(`Expected string literal for '${key}' in '${type}'`);
  }
  return v as string;
}

function reqStrOrNull(rec: JRec, key: string, type: string): string | null {
  if (!has(rec, key)) {
    throw missing(key, type);
  }
  const v: Object | null = rec[key];
  if (v === null) {
    return null;
  }
  if (typeof v !== 'string') {
    throw new SerializationException(`Expected string literal for '${key}' in '${type}'`);
  }
  return v as string;
}

function intOf(v: Object | null, key: string, max: number): number {
  if (typeof v !== 'number' || !Number.isInteger(v as number) || Math.abs(v as number) > max) {
    throw new SerializationException(`Expected integer for '${key}'`);
  }
  return v as number;
}

function reqInt(rec: JRec, key: string, type: string): number {
  if (!has(rec, key)) {
    throw missing(key, type);
  }
  return intOf(rec[key], key, 2147483648);
}

function reqBool(rec: JRec, key: string, type: string): boolean {
  if (!has(rec, key)) {
    throw missing(key, type);
  }
  const v: Object | null = rec[key];
  if (typeof v !== 'boolean') {
    throw new SerializationException(`Expected boolean for '${key}' in '${type}'`);
  }
  return v as boolean;
}

function optIntOrNull(rec: JRec, key: string): number | null {
  if (!has(rec, key) || rec[key] === null) {
    return null;
  }
  return intOf(rec[key], key, 2147483648);
}

function decodeThumbnail(v: Object | null): ThumbnailImage | null {
  if (v === null) {
    return null;
  }
  const rec: JRec = asRecord(v, 'ThumbnailImage');
  if (!has(rec, 'type')) {
    throw new SerializationException('Class discriminator was missing and no default serializers were registered');
  }
  const type: string = reqStr(rec, 'type', 'ThumbnailImage');
  if (type === THUMBNAIL_TYPE_ENCLOSURE_IMAGE) {
    const url: string = reqStr(rec, 'url', type);
    if (!has(rec, 'length')) {
      throw missing('length', type);
    }
    return new EnclosureImage(url, intOf(rec['length'], 'length', Number.MAX_SAFE_INTEGER));
  }
  if (type === THUMBNAIL_TYPE_IMAGE_FROM_HTML) {
    return new ImageFromHTML(reqStr(rec, 'url', type), optIntOrNull(rec, 'width'), optIntOrNull(rec, 'height'));
  }
  if (type === THUMBNAIL_TYPE_MEDIA_IMAGE) {
    return new MediaImage(reqStr(rec, 'url', type), optIntOrNull(rec, 'width'), optIntOrNull(rec, 'height'));
  }
  throw new SerializationException(`Serializer for subclass '${type}' is not found in the polymorphic scope`);
}

/** JSON → SavedArticlesExport（不校验 format/version，由 importSavedArticlesExport 校验） */
export function decodeSavedArticlesExport(content: string): SavedArticlesExport {
  let parsed: Object | null = null;
  try {
    parsed = JSON.parse(content) as Object | null;
  } catch (e) {
    throw new SerializationException(`Unexpected JSON token: ${(e as Error)?.message}`);
  }
  const root: JRec = asRecord(parsed, 'SavedArticlesExport');
  const T: string = 'com.nononsenseapps.feeder.model.export.SavedArticlesExport';
  const out: SavedArticlesExport = new SavedArticlesExport();
  out.format = reqStr(root, 'format', T);
  out.version = reqInt(root, 'version', T);
  if (!has(root, 'articles')) {
    throw missing('articles', T);
  }
  const arr: Object | null = root['articles'];
  if (arr === null || !Array.isArray(arr)) {
    throw new SerializationException('Expected JsonArray for articles');
  }
  const IT: string = 'com.nononsenseapps.feeder.model.export.SavedArticleExportItem';
  const FT: string = 'com.nononsenseapps.feeder.model.export.SavedArticleFeedExportItem';
  for (const raw of (arr as Object[])) {
    const r: JRec = asRecord(raw, IT);
    const a: SavedArticleExportItem = new SavedArticleExportItem();
    a.link = reqStr(r, 'link', IT);
    a.guid = reqStr(r, 'guid', IT);
    a.title = reqStr(r, 'title', IT);
    a.snippet = reqStr(r, 'snippet', IT);
    a.pubDate = reqStrOrNull(r, 'pubDate', IT);
    a.primarySortTime = reqStr(r, 'primarySortTime', IT);
    a.readTime = reqStrOrNull(r, 'readTime', IT);
    a.author = reqStrOrNull(r, 'author', IT);
    if (!has(r, 'thumbnailImage')) {
      throw missing('thumbnailImage', IT);
    }
    a.thumbnailImage = decodeThumbnail(r['thumbnailImage']);
    a.enclosureLink = reqStrOrNull(r, 'enclosureLink', IT);
    a.enclosureType = reqStrOrNull(r, 'enclosureType', IT);
    a.wordCount = reqInt(r, 'wordCount', IT);
    a.wordCountFull = reqInt(r, 'wordCountFull', IT);
    if (!has(r, 'feed')) {
      throw missing('feed', IT);
    }
    const fr: JRec = asRecord(r['feed'], FT);
    const f: SavedArticleFeedExportItem = new SavedArticleFeedExportItem();
    f.url = reqStr(fr, 'url', FT);
    f.title = reqStr(fr, 'title', FT);
    f.customTitle = reqStr(fr, 'customTitle', FT);
    f.tag = reqStr(fr, 'tag', FT);
    f.fullTextByDefault = reqBool(fr, 'fullTextByDefault', FT);
    a.feed = f;
    out.articles.push(a);
  }
  return out;
}

// =====================================================================
// 导入逻辑（DB 访问可注入，便于测试）
// =====================================================================

export interface SavedArticlesStore {
  getFeedIdForUrl(url: string): Promise<number | null>;

  insertFeed(feed: Feed): Promise<number>;

  loadFeedItem(guid: string, feedId: number): Promise<FeedItem | null>;

  loadFeedItemByLink(link: string): Promise<FeedItem | null>;

  setBookmarked(id: number, bookmarked: boolean): Promise<void>;

  insertFeedItem(item: FeedItem): Promise<number>;

  setBookmarkedByLinks(links: string[]): Promise<number>;
}

function ifBlank(s: string, alt: string): string {
  return s.trim().length === 0 ? alt : s;
}

/** 源 FeedDao.resolveFeedId：feed.url 非法 → null；按 url 找不到则新建 */
async function resolveFeedId(store: SavedArticlesStore, feed: SavedArticleFeedExportItem): Promise<number | null> {
  let feedUrl: string;
  try {
    feedUrl = JavaUrl.parse(feed.url).toString();
  } catch (e) {
    return null;
  }
  const existing: number | null = await store.getFeedIdForUrl(feedUrl);
  if (existing !== null) {
    return existing;
  }
  const f: Feed = new Feed();
  f.title = feed.title;
  f.customTitle = feed.customTitle;
  f.url = feedUrl;
  f.tag = feed.tag;
  f.fullTextByDefault = feed.fullTextByDefault;
  return await store.insertFeed(f);
}

function parseInstantOrNull(v: string | null): number | null {
  if (v === null) {
    return null;
  }
  try {
    return instantParse(v);
  } catch (e) {
    return null;
  }
}

/** 源 SavedArticleExportItem.toFeedItem(feedId) */
export function savedArticleToFeedItem(a: SavedArticleExportItem, feedId: number | null,
  nowMs: number = Date.now()): FeedItem {
  const pub: JavaZonedDateTime | null = JavaZonedDateTime.parseOrNull(a.pubDate);
  const primary: number | null = parseInstantOrNull(a.primarySortTime);
  const sortTime: number = primary !== null ? primary : (pub !== null ? pub.toEpochMs() : nowMs);
  const item: FeedItem = new FeedItem();
  item.guid = ifBlank(a.guid, a.link);
  item.plainTitle = a.title;
  item.plainSnippet = a.snippet;
  item.thumbnailImage = a.thumbnailImage;
  item.enclosureLink = a.enclosureLink;
  item.enclosureType = a.enclosureType;
  item.author = a.author;
  item.pubDate = pub !== null ? pub.toString() : null;
  item.link = a.link;
  item.notified = true;
  item.feedId = feedId;
  item.firstSyncedTime = sortTime;
  item.primarySortTime = sortTime;
  item.bookmarked = true;
  item.readTime = parseInstantOrNull(a.readTime);
  item.wordCount = a.wordCount;
  item.wordCountFull = a.wordCountFull;
  return item;
}

/** 源 importSavedArticlesExport：format/version 校验失败抛 IllegalArgumentException 等价错误 */
export async function importSavedArticlesExport(store: SavedArticlesStore, export0: SavedArticlesExport,
  nowMs: number = Date.now()): Promise<void> {
  if (export0.format !== SAVED_ARTICLES_EXPORT_FORMAT) {
    throw new Error(`Unsupported saved articles export format: ${export0.format}`);
  }
  if (export0.version !== SAVED_ARTICLES_EXPORT_VERSION) {
    throw new Error(`Unsupported saved articles export version: ${export0.version}`);
  }
  for (const article of export0.articles) {
    const feedId: number | null = await resolveFeedId(store, article.feed);
    let existing: FeedItem | null = null;
    if (feedId !== null) {
      existing = await store.loadFeedItem(ifBlank(article.guid, article.link), feedId);
    }
    if (existing === null) {
      existing = await store.loadFeedItemByLink(article.link);
    }
    if (existing !== null) {
      await store.setBookmarked(existing.id, true);
    } else {
      await store.insertFeedItem(savedArticleToFeedItem(article, feedId, nowMs));
    }
  }
}

/** 源 importLegacySavedArticleLinks：按行 trim、去空、去重，每 500 条标记收藏（只标记已存在条目） */
export async function importLegacySavedArticleLinks(store: SavedArticlesStore, content: string): Promise<void> {
  const links: string[] = [];
  for (const line of content.split(new RegExp('\\r\\n|\\n|\\r'))) {
    const t: string = line.trim();
    if (t.length > 0 && links.indexOf(t) < 0) {
      links.push(t);
    }
  }
  for (let i = 0; i < links.length; i += 500) {
    await store.setBookmarkedByLinks(links.slice(i, i + 500));
  }
}

/** 内容分派（FP-A64）：trimStart 以 `{` 开头 → JSON，否则旧格式 */
export async function importSavedArticlesContent(store: SavedArticlesStore, content: string,
  nowMs: number = Date.now()): Promise<void> {
  if (content.trimStart().startsWith('{')) {
    await importSavedArticlesExport(store, decodeSavedArticlesExport(content), nowMs);
  } else {
    await importLegacySavedArticleLinks(store, content);
  }
}

// =====================================================================
// 保存器默认文件名 / 打开器 MIME（源 FeedScreen.kt:392/408）
// =====================================================================

/** FP-A67：`feeder-saved-articles-<yyyy-MM-dd>-<当日秒数>.json` */
export function savedArticlesExportFileName(nowMs: number = Date.now()): string {
  return `feeder-saved-articles-${exportFileStamp(nowMs)}.json`;
}

export const SAVED_ARTICLES_EXPORT_MIME_TYPE: string = 'application/json';
export const SAVED_ARTICLES_IMPORT_MIME_TYPES: string[] = ['text/plain', 'application/octet-stream', '*/*'];
