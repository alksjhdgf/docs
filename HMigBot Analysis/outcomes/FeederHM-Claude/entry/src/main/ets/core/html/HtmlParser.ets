/**
 * HtmlParser.ets —— 自研宽容 HTML 解析（替代 Jsoup.parse / TagSoup，全工程唯一入口）。
 *
 * parseHtml(html, baseUrl) ≙ Jsoup.parse(html, baseUrl)：
 *  - 结果文档恒含 html/head/body；`<html>/<body>` 标签属性合并进隐式元素（如 `<html dir="rtl">`）
 *  - Tokenizer：HTML5 命名/数字实体（Jsoup 规则：遗留实体可省分号、属性内 `&x=` 不解码）、
 *    属性名小写/重复取首个/无值为 ''、`<script>/<style>` 原文（DATA 节点）、textarea/title 为 RCDATA、
 *    注释、CDATA（作为文本）、DOCTYPE/处理指令丢弃；自闭合 `<x/>` 对任何元素生效（Jsoup 行为）
 *  - 树构建（HTML5 规则子集）：void 元素；块级起始标签隐式关闭 p；li/dd/dt/h1-6/option/a 互斥关闭；
 *    孤立 `</p>` 生成空 p；`</br>` → br；表格隐式 tbody/tr、单元格/行/分区隐式关闭、表内非表格内容寄养到表前；
 *    `<pre>/<listing>/<textarea>` 吞掉紧随的首个换行；`<base href>` 更新文档 baseUri
 *  - 格式元素错嵌套：活动格式元素列表 + 简化收养代理算法（省略内层 3 次上限与书签细节）+ 活动格式元素重建
 *  - 未实现：foreign content（svg/math 按普通元素处理，属性名小写）、frameset、select/template 插入模式细节。
 */
import { HtmlDocument } from './HtmlDocument';
import { isHtmlWhitespace } from './HtmlChars';
import { isAsciiLetter, unescapeEntities } from './HtmlEntities';
import { RAW_DATA_TAGS } from './HtmlTags';
import { TreeBuilder } from './HtmlTreeBuilder';

export { HtmlDocument } from './HtmlDocument';
export { HtmlNode } from './HtmlNode';
export {
  NODE_COMMENT,
  NODE_DATA,
  NODE_DOCUMENT,
  NODE_ELEMENT,
  NODE_TEXT,
  VOID_TAGS,
  appendNormalisedWhitespace,
  escapeHtmlText,
  isActuallyWhitespace,
  isHtmlWhitespace,
  javaTrim
} from './HtmlChars';
export { unescapeEntities } from './HtmlEntities';
export { resolveUrl } from './HtmlUrl';

const RAW_TEXT_TAGS: Set<string> = new Set<string>(['xmp', 'iframe', 'noembed', 'noframes']);
const RCDATA_TAGS: Set<string> = new Set<string>(['title', 'textarea']);

// ===================================================================================
// Tokenizer
// ===================================================================================

function isTagNameEnd(c: number): boolean {
  return isHtmlWhitespace(c) || c === 47 || c === 62;
}

/** 查找 `</tag` 后跟空白、'/' 或 '>' 的位置（不区分大小写），找不到返回 -1 */
function findEndTag(s: string, lower: string, tag: string, from: number): number {
  let i: number = lower.indexOf('</' + tag, from);
  while (i >= 0) {
    const after: number = i + 2 + tag.length;
    if (after >= s.length || isTagNameEnd(s.charCodeAt(after))) {
      return i;
    }
    i = lower.indexOf('</' + tag, i + 1);
  }
  return -1;
}

class Tokenizer {
  s: string;
  lower: string | null = null;
  pos: number = 0;
  tb: TreeBuilder;

  constructor(s: string, tb: TreeBuilder) {
    this.s = s;
    this.tb = tb;
  }

  private lowerText(): string {
    if (this.lower === null) {
      this.lower = this.s.toLowerCase();
    }
    return this.lower;
  }

  run(): void {
    const s: string = this.s;
    const n: number = s.length;
    while (this.pos < n) {
      const lt: number = s.indexOf('<', this.pos);
      if (lt < 0) {
        this.tb.onText(unescapeEntities(s.substring(this.pos), false));
        this.pos = n;
        break;
      }
      if (lt > this.pos) {
        this.tb.onText(unescapeEntities(s.substring(this.pos, lt), false));
      }
      this.pos = lt;
      const c1: number = lt + 1 < n ? s.charCodeAt(lt + 1) : -1;
      if (isAsciiLetter(c1)) {
        this.startTag();
      } else if (c1 === 47) {
        const c2: number = lt + 2 < n ? s.charCodeAt(lt + 2) : -1;
        if (isAsciiLetter(c2)) {
          this.endTag();
        } else if (c2 === 62) {
          this.pos = lt + 3;
        } else if (c2 < 0) {
          this.tb.onText('</');
          this.pos = n;
        } else {
          this.bogusComment(lt + 2);
        }
      } else if (c1 === 33) {
        this.markupDeclaration();
      } else if (c1 === 63) {
        this.bogusComment(lt + 1);
      } else {
        this.tb.onText('<');
        this.pos = lt + 1;
      }
    }
  }

  private bogusComment(from: number): void {
    const gt: number = this.s.indexOf('>', from);
    const end: number = gt < 0 ? this.s.length : gt;
    this.tb.onComment(this.s.substring(from, end));
    this.pos = gt < 0 ? this.s.length : gt + 1;
  }

  private markupDeclaration(): void {
    const s: string = this.s;
    const p: number = this.pos;
    if (s.startsWith('<!--', p)) {
      if (s.startsWith('<!-->', p)) {
        this.tb.onComment('');
        this.pos = p + 5;
        return;
      }
      if (s.startsWith('<!--->', p)) {
        this.tb.onComment('');
        this.pos = p + 6;
        return;
      }
      const end: number = s.indexOf('-->', p + 4);
      if (end < 0) {
        this.tb.onComment(s.substring(p + 4));
        this.pos = s.length;
      } else {
        this.tb.onComment(s.substring(p + 4, end));
        this.pos = end + 3;
      }
      return;
    }
    if (s.startsWith('<![CDATA[', p)) {
      const end: number = s.indexOf(']]>', p + 9);
      const text: string = end < 0 ? s.substring(p + 9) : s.substring(p + 9, end);
      this.tb.onText(text);
      this.pos = end < 0 ? s.length : end + 3;
      return;
    }
    // DOCTYPE 等：丢弃至 '>'
    const gt: number = s.indexOf('>', p);
    this.pos = gt < 0 ? s.length : gt + 1;
  }

  private readName(): string {
    const s: string = this.s;
    const start: number = this.pos;
    while (this.pos < s.length && !isTagNameEnd(s.charCodeAt(this.pos))) {
      this.pos++;
    }
    return s.substring(start, this.pos).toLowerCase();
  }

  private skipWs(): void {
    while (this.pos < this.s.length && isHtmlWhitespace(this.s.charCodeAt(this.pos))) {
      this.pos++;
    }
  }

  private startTag(): void {
    const s: string = this.s;
    const n: number = s.length;
    this.pos++;
    const tag: string = this.readName();
    const attrs: Map<string, string> = new Map<string, string>();
    let selfClosing: boolean = false;
    let closed: boolean = false;
    while (this.pos < n) {
      this.skipWs();
      if (this.pos >= n) {
        break;
      }
      const c: number = s.charCodeAt(this.pos);
      if (c === 62) {
        this.pos++;
        closed = true;
        break;
      }
      if (c === 47) {
        this.pos++;
        if (this.pos < n && s.charCodeAt(this.pos) === 62) {
          this.pos++;
          selfClosing = true;
          closed = true;
          break;
        }
        continue;
      }
      const nameStart: number = this.pos;
      this.pos++;
      while (this.pos < n) {
        const d: number = s.charCodeAt(this.pos);
        if (isHtmlWhitespace(d) || d === 47 || d === 62 || d === 61) {
          break;
        }
        this.pos++;
      }
      const attrName: string = s.substring(nameStart, this.pos).toLowerCase();
      this.skipWs();
      let value: string = '';
      if (this.pos < n && s.charCodeAt(this.pos) === 61) {
        this.pos++;
        this.skipWs();
        const q: number = this.pos < n ? s.charCodeAt(this.pos) : -1;
        if (q === 34 || q === 39) {
          const endQ: number = s.indexOf(q === 34 ? '"' : '\'', this.pos + 1);
          const vEnd: number = endQ < 0 ? n : endQ;
          value = unescapeEntities(s.substring(this.pos + 1, vEnd), true);
          this.pos = endQ < 0 ? n : endQ + 1;
        } else {
          const vStart: number = this.pos;
          while (this.pos < n && !isHtmlWhitespace(s.charCodeAt(this.pos)) && s.charCodeAt(this.pos) !== 62) {
            this.pos++;
          }
          value = unescapeEntities(s.substring(vStart, this.pos), true);
        }
      }
      if (attrName.length > 0 && !attrs.has(attrName)) {
        attrs.set(attrName, value);
      }
    }
    if (!closed) {
      return; // EOF 于标签内：丢弃该标签（HTML5）
    }
    const open: boolean = this.tb.onStartTag(tag, attrs, selfClosing);
    if (open) {
      this.rawContent(tag);
    }
  }

  /** script/style/xmp/iframe… 原文；title/textarea RCDATA（解实体）；plaintext 吃到结尾 */
  private rawContent(tag: string): void {
    const raw: boolean = RAW_DATA_TAGS.has(tag) || RAW_TEXT_TAGS.has(tag);
    const rc: boolean = RCDATA_TAGS.has(tag);
    if (tag === 'plaintext') {
      this.tb.onRawText(this.s.substring(this.pos));
      this.pos = this.s.length;
      return;
    }
    if (!raw && !rc) {
      return;
    }
    const end: number = findEndTag(this.s, this.lowerText(), tag, this.pos);
    const stop: number = end < 0 ? this.s.length : end;
    const content: string = this.s.substring(this.pos, stop);
    if (content.length > 0) {
      if (rc) {
        this.tb.onText(unescapeEntities(content, false));
      } else {
        this.tb.onRawText(content);
      }
    }
    this.pos = stop;
    if (end >= 0) {
      this.endTag();
    }
  }

  private endTag(): void {
    const s: string = this.s;
    this.pos += 2;
    const tag: string = this.readName();
    let quote: number = -1;
    while (this.pos < s.length) {
      const c: number = s.charCodeAt(this.pos);
      this.pos++;
      if (quote >= 0) {
        if (c === quote) {
          quote = -1;
        }
      } else if (c === 34 || c === 39) {
        quote = c;
      } else if (c === 62) {
        this.tb.onEndTag(tag);
        return;
      }
    }
  }
}

/** Jsoup.parse(html, baseUrl) 等价：宽容解析为文档（恒含 html/head/body） */
export function parseHtml(html: string, baseUrl: string = ''): HtmlDocument {
  const tb: TreeBuilder = new TreeBuilder(baseUrl);
  const tk: Tokenizer = new Tokenizer(html.indexOf('\u0000') >= 0 ? html.split('\u0000').join('') : html, tb);
  tk.run();
  return tb.finish();
}

/** Jsoup.parseBodyFragment 近似：片段内容全部进入 body（head 级标签也留在 body） */
export function parseBodyFragment(html: string, baseUrl: string = ''): HtmlDocument {
  const tb: TreeBuilder = new TreeBuilder(baseUrl);
  tb.ensureBody();
  const tk: Tokenizer = new Tokenizer(html, tb);
  tk.run();
  return tb.finish();
}

