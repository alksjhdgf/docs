/**
 * OpmlParser.ets —— 源 model/opml/OpmlPullParser.kt（OPML 读取 + 失败回退正则重写）、
 * model/OPMLParserHandler.kt、
 * OPMLImporter 的屏蔽词合并纯逻辑（FP-A53..A55、A58、A59）。落库与 importOpml 动作见 OpmlActions.ets。
 * 纯逻辑（不依赖系统 Kit，可在本地单测中加载）。
 *
 * 语义要点（照源，含既有怪癖）：
 *  - 整份解析完成后才落库：先逐个 saveFeed，再逐个 saveSetting，最后一次 saveBlocklistPatterns；任一异常 → Left
 *  - feeds/settings/blockList 是解析器实例字段：首轮失败时已收集的条目会保留到回退轮一并保存（源同）
 *  - title/tag/setting value/blocked pattern 在 XML 解码后再 unescape 一次（双重解码，源 R5）；blockRules/allowRules 不 unescape
 *  - 布尔属性仅忽略大小写的 "true" 为真；属性缺失用 Feed 默认值
 *  - 多层文件夹扁平化为最内层文件夹名
 */
import { decodeUtf8, encodeUtf8 } from '../util/TextCodec';
import { Feed } from '../model/Feed';
import { Either } from '../util/Either';
import { JavaUrl } from '../util/JavaCompat';
import { OPML_FEEDER_NAMESPACE, unescape } from './OpmlWriter';
import {
  OpmlXmlPullParser,
  XML_END_TAG,
  XML_START_TAG,
  XmlPullParserException
} from './OpmlXmlPullParser';

const TAG_SETTING: string = 'setting';
const TAG_OPML: string = 'opml';
const TAG_BODY: string = 'body';
const TAG_OUTLINE: string = 'outline';
const TAG_SETTINGS: string = 'settings';
const TAG_BLOCKED: string = 'blocked';
const ATTR_XMLURL: string = 'xmlUrl';
const ATTR_TITLE: string = 'title';
const ATTR_TEXT: string = 'text';
const ATTR_NOTIFY: string = 'notify';
const ATTR_FULL_TEXT_BY_DEFAULT: string = 'fullTextByDefault';
const ATTR_FLYM_RETRIEVE_FULL_TEXT: string = 'retrieveFullText';
const ATTR_ALTERNATE_ID: string = 'alternateId';
const ATTR_IMAGE_URL: string = 'imageUrl';
const ATTR_OPEN_ARTICLES_WITH: string = 'openArticlesWith';
const ATTR_FETCH_OG_IMAGES: string = 'fetchOgImages';
const ATTR_BLOCK_RULES: string = 'blockRules';
const ATTR_ALLOW_RULES: string = 'allowRules';

const LOG_TAG: string = 'FEEDER_OPMLPULL';

// =====================================================================
// 错误类型（源 OpmlError 密封类）
// =====================================================================

export abstract class OpmlError {
  readonly throwable: Error | null;

  constructor(throwable: Error | null) {
    this.throwable = throwable;
  }
}

export class OpmlUnknownError extends OpmlError {
  constructor(throwable: Error | null) {
    super(throwable);
  }
}

export class OpmlParsingError extends OpmlError {
  constructor(throwable: Error) {
    super(throwable);
  }
}

// =====================================================================
// OPMLParserHandler（源 model/OPMLParserHandler.kt）
// =====================================================================

export interface OPMLParserHandler {
  saveFeed(feed: Feed): Promise<void>;

  saveSetting(key: string, value: string): Promise<void>;

  saveBlocklistPatterns(patterns: string[]): Promise<void>;
}

/** Kotlin String.toBoolean()：仅忽略大小写的 "true" */
export function kotlinToBoolean(s: string): boolean {
  return s.toLowerCase() === 'true';
}

// =====================================================================
// OpmlPullParser
// =====================================================================

export class OpmlPullParser {
  private readonly opmlToDb: OPMLParserHandler;
  private readonly feeds: Feed[] = [];
  /** 插入有序；同 key 后者覆盖（源 mutableMapOf） */
  private readonly settings: Map<string, string> = new Map<string, string>();
  /** 插入有序去重（源 mutableSetOf） */
  private readonly blockList: string[] = [];
  private parser: OpmlXmlPullParser = new OpmlXmlPullParser('');

  constructor(opmlToDb: OPMLParserHandler) {
    this.opmlToDb = opmlToDb;
  }

  /** 源 parseInputStreamWithFallback：XML 解析失败则正则重写 outline 后再解析一次 */
  async parseBytesWithFallback(bytes: Uint8Array): Promise<Either<OpmlError, boolean>> {
    const first: Either<OpmlError, boolean> = await this.parseBytes(bytes);
    if (first.isRight()) {
      return first;
    }
    let rewritten: Uint8Array;
    try {
      const text: string = decodeUtf8(bytes);
      const fixed: string = text.replace(new RegExp('<outline.*?xmlUrl="([^"]+)".*?/>', 'g'),
        '<outline xmlUrl="$1" type="rss" />');
      rewritten = encodeUtf8(fixed);
    } catch (e) {
      return Either.left<OpmlError, boolean>(new OpmlUnknownError(e as Error));
    }
    return await this.parseBytes(rewritten);
  }

  /** 便于测试/内存内容：按 UTF-8 编码后走 parseBytesWithFallback */
  async parseTextWithFallback(text: string): Promise<Either<OpmlError, boolean>> {
    return await this.parseBytesWithFallback(encodeUtf8(text));
  }

  private async parseBytes(bytes: Uint8Array): Promise<Either<OpmlError, boolean>> {
    try {
      this.parser = OpmlXmlPullParser.fromBytes(bytes);
      this.parser.nextTag();
      this.readOpml();

      for (const feed of this.feeds) {
        await this.opmlToDb.saveFeed(feed);
      }
      const entries: string[][] = [];
      this.settings.forEach((value: string, key: string) => {
        entries.push([key, value]);
      });
      for (const kv of entries) {
        await this.opmlToDb.saveSetting(kv[0], kv[1]);
      }
      await this.opmlToDb.saveBlocklistPatterns(this.blockList.slice());
      return Either.right<OpmlError, boolean>(true);
    } catch (t) {
      const err: Error = t as Error;
      console.error(LOG_TAG, `OPML Import exploded: ${err?.message}`);
      if (t instanceof XmlPullParserException) {
        return Either.left<OpmlError, boolean>(new OpmlParsingError(err));
      }
      return Either.left<OpmlError, boolean>(new OpmlUnknownError(err));
    }
  }

  private attr(name: string): string | null {
    return this.parser.getAttributeValue(null, name);
  }

  private readOpml(): void {
    const p: OpmlXmlPullParser = this.parser;
    p.require(XML_START_TAG, null, TAG_OPML);
    while (p.next() !== XML_END_TAG) {
      if (p.eventType !== XML_START_TAG) {
        continue;
      }
      if (p.name === TAG_BODY) {
        this.readBody();
      } else {
        this.skip();
      }
    }
  }

  private readBody(): void {
    const p: OpmlXmlPullParser = this.parser;
    p.require(XML_START_TAG, null, TAG_BODY);
    while (p.next() !== XML_END_TAG) {
      if (p.eventType !== XML_START_TAG) {
        continue;
      }
      if (p.name === TAG_OUTLINE) {
        this.readOutline('');
      } else if (p.name === TAG_SETTINGS && p.namespace === OPML_FEEDER_NAMESPACE) {
        this.readSettings();
      } else {
        this.skip();
      }
    }
  }

  private readSettings(): void {
    const p: OpmlXmlPullParser = this.parser;
    p.require(XML_START_TAG, OPML_FEEDER_NAMESPACE, TAG_SETTINGS);
    while (p.next() !== XML_END_TAG) {
      if (p.eventType !== XML_START_TAG) {
        continue;
      }
      if (p.name === TAG_SETTING && p.namespace === OPML_FEEDER_NAMESPACE) {
        this.readSetting();
      } else if (p.name === TAG_BLOCKED && p.namespace === OPML_FEEDER_NAMESPACE) {
        this.readBlocked();
      } else {
        this.skip();
      }
    }
  }

  private readSetting(): void {
    this.parser.require(XML_START_TAG, OPML_FEEDER_NAMESPACE, TAG_SETTING);
    const key: string | null = this.attr('key');
    const value: string | null = this.attr('value');
    if (key !== null && value !== null) {
      this.settings.set(key, unescape(value));
    }
    this.skip();
  }

  private readBlocked(): void {
    this.parser.require(XML_START_TAG, OPML_FEEDER_NAMESPACE, TAG_BLOCKED);
    const pattern: string | null = this.attr('pattern');
    if (pattern !== null) {
      const v: string = unescape(pattern);
      if (this.blockList.indexOf(v) < 0) {
        this.blockList.push(v);
      }
    }
    this.skip();
  }

  private readOutline(parentOutlineTag: string): void {
    this.parser.require(XML_START_TAG, null, TAG_OUTLINE);
    const xmlUrl: string | null = this.attr(ATTR_XMLURL);
    if (xmlUrl !== null) {
      this.readOutlineAsRss(parentOutlineTag);
    } else {
      this.readOutlineAsTag();
    }
  }

  private titleOrText(): string {
    const t: string | null = this.attr(ATTR_TITLE);
    if (t !== null) {
      return unescape(t);
    }
    const x: string | null = this.attr(ATTR_TEXT);
    return unescape(x !== null ? x : '');
  }

  private readOutlineAsTag(): void {
    const p: OpmlXmlPullParser = this.parser;
    p.require(XML_START_TAG, null, TAG_OUTLINE);
    const tag: string = this.titleOrText();
    while (p.next() !== XML_END_TAG) {
      if (p.eventType !== XML_START_TAG) {
        continue;
      }
      if (p.name === TAG_OUTLINE) {
        this.readOutline(tag);
      } else {
        this.skip();
      }
    }
  }

  private boolAttr(ns: string | null, name: string): boolean | null {
    const v: string | null = this.parser.getAttributeValue(ns, name);
    return v === null ? null : kotlinToBoolean(v);
  }

  private readOutlineAsRss(tag: string): void {
    const p: OpmlXmlPullParser = this.parser;
    p.require(XML_START_TAG, null, TAG_OUTLINE);
    const feedTitle: string = this.titleOrText();
    let feedUrl: string | null = null;
    try {
      const parsedUrlOrUri: string | null = this.attr(ATTR_XMLURL);
      feedUrl = JavaUrl.parse(parsedUrlOrUri !== null ? parsedUrlOrUri : '').toString();
    } catch (e) {
      // Feed URL is REQUIRED, so don't try to add feeds without valid URLs
      console.error(LOG_TAG, `Bad url on feed [${feedTitle}] in OPML: ${(e as Error)?.message}`);
    }
    if (feedUrl !== null) {
      const feed: Feed = new Feed();
      // Ensure not both are empty string: title will get replaced on sync
      feed.title = feedTitle.trim().length === 0 ? feedUrl : feedTitle;
      feed.customTitle = feedTitle;
      feed.tag = tag;
      feed.url = feedUrl;

      const notify: boolean | null = this.boolAttr(OPML_FEEDER_NAMESPACE, ATTR_NOTIFY);
      if (notify !== null) {
        feed.notify = notify;
      }
      let fullText: boolean | null = this.boolAttr(OPML_FEEDER_NAMESPACE, ATTR_FULL_TEXT_BY_DEFAULT);
      if (fullText === null) {
        // Support Flym's value for this
        fullText = this.boolAttr(null, ATTR_FLYM_RETRIEVE_FULL_TEXT);
      }
      if (fullText !== null) {
        feed.fullTextByDefault = fullText;
      }
      const alternateId: boolean | null = this.boolAttr(OPML_FEEDER_NAMESPACE, ATTR_ALTERNATE_ID);
      if (alternateId !== null) {
        feed.alternateId = alternateId;
      }
      const openWith: string | null = p.getAttributeValue(OPML_FEEDER_NAMESPACE, ATTR_OPEN_ARTICLES_WITH);
      if (openWith !== null) {
        feed.openArticlesWith = openWith;
      }
      const ogImages: boolean | null = this.boolAttr(OPML_FEEDER_NAMESPACE, ATTR_FETCH_OG_IMAGES);
      if (ogImages !== null) {
        feed.fetchOgImages = ogImages;
      }
      // Not run through unescape() - the parser already resolves entities and character references
      const blockRules: string | null = p.getAttributeValue(OPML_FEEDER_NAMESPACE, ATTR_BLOCK_RULES);
      if (blockRules !== null) {
        feed.blockRules = blockRules;
      }
      const allowRules: string | null = p.getAttributeValue(OPML_FEEDER_NAMESPACE, ATTR_ALLOW_RULES);
      if (allowRules !== null) {
        feed.allowRules = allowRules;
      }
      const imageUrl: string | null = p.getAttributeValue(OPML_FEEDER_NAMESPACE, ATTR_IMAGE_URL);
      if (imageUrl !== null) {
        try {
          feed.imageUrl = JavaUrl.parse(imageUrl).toString();
        } catch (e) {
          console.error(LOG_TAG, `Invalid imageUrl [${imageUrl}] on feed [${feedTitle}] in OPML`);
          feed.imageUrl = null;
        }
      }
      this.feeds.push(feed);
    }
    this.skip();
  }

  private skip(): void {
    const p: OpmlXmlPullParser = this.parser;
    if (p.eventType !== XML_START_TAG) {
      throw new Error('IllegalStateException');
    }
    let depth: number = 1;
    while (depth !== 0) {
      const t: number = p.next();
      if (t === XML_END_TAG) {
        depth--;
      } else if (t === XML_START_TAG) {
        depth++;
      }
    }
  }
}

// =====================================================================
// 屏蔽词合并（源 OPMLImporter.saveBlocklistPatterns 的纯逻辑部分）
// =====================================================================

/** 过滤空白、已存在、重复后返回需逐个 add 的屏蔽词（保持输入顺序）。FP-A58 */
export function mergeBlocklistPatterns(patterns: string[], existingPatterns: string[]): string[] {
  const out: string[] = [];
  for (const p of patterns) {
    if (p.trim().length === 0 || existingPatterns.indexOf(p) >= 0 || out.indexOf(p) >= 0) {
      continue;
    }
    out.push(p);
  }
  return out;
}

/** 收集型 handler（源 androidTest OpmlFeedList；导入屏预览也可用）：按 url 去重保留最后一次 */
export class OpmlFeedList implements OPMLParserHandler {
  readonly feeds: Map<string, Feed> = new Map<string, Feed>();
  readonly settings: Map<string, string> = new Map<string, string>();
  readonly blockList: string[] = [];

  async saveFeed(feed: Feed): Promise<void> {
    this.feeds.set(feed.url, feed);
  }

  async saveSetting(key: string, value: string): Promise<void> {
    this.settings.set(key, value);
  }

  async saveBlocklistPatterns(patterns: string[]): Promise<void> {
    for (const p of patterns) {
      this.blockList.push(p);
    }
  }
}

