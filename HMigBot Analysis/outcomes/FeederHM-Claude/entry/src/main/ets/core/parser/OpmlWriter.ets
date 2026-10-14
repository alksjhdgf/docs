/**
 * OpmlWriter.ets —— 源 model/opml/OpmlWriter.kt（OPML 写出 DSL、escape/unescape/escapeAttribute、
 * OPML_FEEDER_NAMESPACE；FP-A46..A50，FP-A52 文件名）。
 * 纯逻辑（不依赖系统 Kit，可在本地单测中加载）；落盘/Toast/同步等动作见 OpmlActions.ets。
 * 另含系统保存器默认文件名（源 FeedScreen.kt:380/408）与打开器 MIME 列表（FeedScreen.kt:358/392）。
 */
import { Feed } from '../model/Feed';

export const OPML_FEEDER_NAMESPACE: string = 'https://nononsenseapps.com/feeder';

// =====================================================================
// escape / unescape（源 :88-125）
// =====================================================================

function replaceAllLiteral(s: string, search: string, replacement: string): string {
  return s.split(search).join(replacement);
}

/** 源 escape：& " ' < > → 实体（& 优先） */
export function escape(s: string): string {
  let r: string = replaceAllLiteral(s, '&', '&amp;');
  r = replaceAllLiteral(r, '"', '&quot;');
  r = replaceAllLiteral(r, '\'', '&apos;');
  r = replaceAllLiteral(r, '<', '&lt;');
  r = replaceAllLiteral(r, '>', '&gt;');
  return r;
}

/**
 * 源 escapeAttribute（仅 blockRules/allowRules）：escape 后 CRLF/CR→LF，LF→`&#10;`，TAB→`&#9;`，
 * 使属性值换行/制表在解析器的属性空白规整后仍能逐字还原。
 */
export function escapeAttribute(s: string): string {
  let r: string = escape(s);
  r = replaceAllLiteral(r, '\r\n', '\n');
  r = replaceAllLiteral(r, '\r', '\n');
  r = replaceAllLiteral(r, '\n', '&#10;');
  r = replaceAllLiteral(r, '\t', '&#9;');
  return r;
}

/** 源 unescape（&amp; 最后） */
export function unescape(s: string): string {
  let r: string = replaceAllLiteral(s, '&quot;', '"');
  r = replaceAllLiteral(r, '&apos;', '\'');
  r = replaceAllLiteral(r, '&lt;', '<');
  r = replaceAllLiteral(r, '&gt;', '>');
  r = replaceAllLiteral(r, '&amp;', '&');
  return r;
}

// =====================================================================
// OPML DSL（源 :127-333）：两空格缩进、属性按插入顺序、无子节点自闭合
// =====================================================================

export abstract class OpmlElement {
  abstract render(builder: string[], indent: string): void;
}

export class OpmlTextElement extends OpmlElement {
  readonly text: string;

  constructor(text: string) {
    super();
    this.text = text;
  }

  render(builder: string[], indent: string): void {
    builder.push(`${indent}${this.text}\n`);
  }
}

export class OpmlTag extends OpmlElement {
  readonly tagName: string;
  readonly children: OpmlElement[] = [];
  /** 插入有序（源 linkedMapOf）；同名再次赋值保留原位置 */
  readonly attributes: Map<string, string> = new Map<string, string>();

  constructor(tagName: string) {
    super();
    this.tagName = tagName;
  }

  setAttr(key: string, value: string): void {
    this.attributes.set(key, value);
  }

  render(builder: string[], indent: string): void {
    builder.push(`${indent}<${this.tagName}${this.renderAttributes()}`);
    if (this.children.length === 0) {
      builder.push('/>\n');
    } else {
      builder.push('>\n');
      for (const c of this.children) {
        c.render(builder, `${indent}  `);
      }
      builder.push(`${indent}</${this.tagName}>\n`);
    }
  }

  private renderAttributes(): string {
    let s: string = '';
    this.attributes.forEach((value: string, key: string) => {
      s += ` ${key}="${value}"`;
    });
    return s;
  }

  toString(): string {
    const builder: string[] = [];
    this.render(builder, '');
    return builder.join('');
  }
}

/** 源 BodyTag.outline(title, text = title, type, xmlUrl, init)：init（子节点/feeder 属性）先执行，再写 title/text/type/xmlUrl */
function outlineTag(title: string, text: string, type: string | null, xmlUrl: string | null,
  init: (o: OpmlTag) => void): OpmlTag {
  const o: OpmlTag = new OpmlTag('outline');
  init(o);
  o.setAttr('title', title);
  o.setAttr('text', text);
  if (type !== null) {
    o.setAttr('type', type);
  }
  if (xmlUrl !== null) {
    o.setAttr('xmlUrl', xmlUrl);
  }
  return o;
}

/** 源 Feed.toOutline()（:247-262）：属性顺序 notify, imageUrl?, fullTextByDefault, openArticlesWith, alternateId, fetchOgImages, blockRules?, allowRules?, title, text, type, xmlUrl */
export function feedToOutline(feed: Feed): OpmlTag {
  const t: string = escape(feed.displayTitle);
  return outlineTag(t, t, 'rss', escape(feed.url), (o: OpmlTag): void => {
    o.setAttr('feeder:notify', `${feed.notify}`);
    if (feed.imageUrl !== null) {
      o.setAttr('feeder:imageUrl', escape(feed.imageUrl));
    }
    o.setAttr('feeder:fullTextByDefault', `${feed.fullTextByDefault}`);
    o.setAttr('feeder:openArticlesWith', feed.openArticlesWith);
    o.setAttr('feeder:alternateId', `${feed.alternateId}`);
    o.setAttr('feeder:fetchOgImages', `${feed.fetchOgImages}`);
    if (feed.blockRules.trim().length > 0) {
      o.setAttr('feeder:blockRules', escapeAttribute(feed.blockRules));
    }
    if (feed.allowRules.trim().length > 0) {
      o.setAttr('feeder:allowRules', escapeAttribute(feed.allowRules));
    }
  });
}

export type FeedsWithTag = (tag: string) => Promise<Feed[]>;

/**
 * 源 writeOutputStream 的文档构造部分：返回完整文件内容（`<?xml …?>\n` + opml 渲染）。
 * tags 次序由调用方给定（源 FeedDao.loadTags：DISTINCT tag ORDER BY tag COLLATE NOCASE，空 tag 在前）；
 * 每 tag 内 feed 由 feedsWithTag 给定（源 getFeedsByTitle：ORDER BY title）。
 */
export async function writeOpmlString(settings: Map<string, string>, blockedPatterns: string[], tags: string[],
  feedsWithTag: FeedsWithTag): Promise<string> {
  const opml: OpmlTag = new OpmlTag('opml');
  opml.setAttr('version', '1.1');
  opml.setAttr('xmlns:feeder', OPML_FEEDER_NAMESPACE);

  const head: OpmlTag = new OpmlTag('head');
  const title: OpmlTag = new OpmlTag('title');
  title.children.push(new OpmlTextElement('Feeder'));
  head.children.push(title);
  opml.children.push(head);

  const body: OpmlTag = new OpmlTag('body');
  for (const tag of tags) {
    const feeds: Feed[] = await feedsWithTag(tag);
    if (tag.length === 0) {
      for (const feed of feeds) {
        body.children.push(feedToOutline(feed));
      }
    } else {
      const escapedTag: string = escape(tag);
      body.children.push(outlineTag(escapedTag, escapedTag, null, null, (o: OpmlTag): void => {
        for (const feed of feeds) {
          o.children.push(feedToOutline(feed));
        }
      }));
    }
  }
  if (settings.size > 0 || blockedPatterns.length > 0) {
    const feederSettings: OpmlTag = new OpmlTag('feeder:settings');
    settings.forEach((prefValue: string, prefKey: string) => {
      const s: OpmlTag = new OpmlTag('feeder:setting');
      s.setAttr('key', prefKey);
      s.setAttr('value', escape(prefValue));
      feederSettings.children.push(s);
    });
    for (const blockedPattern of blockedPatterns) {
      const b: OpmlTag = new OpmlTag('feeder:blocked');
      b.setAttr('pattern', escape(blockedPattern));
      feederSettings.children.push(b);
    }
    body.children.push(feederSettings);
  }
  opml.children.push(body);

  return '<?xml version="1.0" encoding="UTF-8"?>\n' + opml.toString();
}

// =====================================================================
// 保存器默认文件名 / 打开器 MIME（源 FeedScreen.kt）
// =====================================================================

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** `<LocalDate.now()>-<LocalTime.now().toSecondOfDay()>`（本地时区） */
export function exportFileStamp(nowMs: number = Date.now()): string {
  const d: Date = new Date(nowMs);
  const date: string = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  const secondOfDay: number = d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds();
  return `${date}-${secondOfDay}`;
}

/** FP-A52：`feeder-export-<yyyy-MM-dd>-<当日秒数>.opml` */
export function opmlExportFileName(nowMs: number = Date.now()): string {
  return `feeder-export-${exportFileStamp(nowMs)}.opml`;
}

/** 源 CreateDocument("text/x-opml") */
export const OPML_EXPORT_MIME_TYPE: string = 'text/x-opml';
/** FP-A62：源 OpenDocument MIME 列表 */
export const OPML_IMPORT_MIME_TYPES: string[] = [
  'text/xml', 'text/x-opml', 'application/xml', 'application/json', 'application/octet-stream', '*/*'
];
/** 打开器建议后缀（DocumentViewPicker 以后缀过滤；源接受任意类型，故含 `.*`） */
export const OPML_IMPORT_SUFFIXES: string[] = ['.opml', '.xml', '.json', '.*'];
