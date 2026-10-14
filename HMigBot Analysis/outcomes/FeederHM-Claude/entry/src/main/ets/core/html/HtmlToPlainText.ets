/**
 * HtmlToPlainText.ets —— 源 ui/text/HtmlToPlainTextConverter.kt（TagSoup SAX → 自研 DOM 遍历事件）。
 * 用于条目标题、摘要片段（snippet）与字数估算。实例非线程安全，调用方每次 new（或用 htmlToPlainText）。
 *
 * 规则（照源）：
 *  - p/div/blockquote/h1-6 起止、br 结束 → ensureSpace（只补单个空格，不换行）
 *  - ul/ol：开头补换行；li 前缀 `"  " * (层数-1)` + (`N. ` | `* `)；li 结束补换行
 *  - strong/b/em/i/cite/dfn/a 只保留文字；script/style 内容丢弃
 *  - img 不输出文字，仅记录最后一张图的 alt（空白 → "IMG"）；全文为空时输出 `[alt]`
 *  - 文本中仅 ' ' 与 '\n' 参与折叠；结果 NBSP→空格并去首尾 (<= ' ') 字符
 */
import { HtmlDocument } from './HtmlDocument';
import { HtmlNode } from './HtmlNode';
import { NODE_DATA, NODE_ELEMENT, NODE_TEXT } from './HtmlChars';
import { parseHtml } from './HtmlParser';

class Listing {
  ordered: boolean;
  num: number = 1;

  constructor(ordered: boolean) {
    this.ordered = ordered;
  }
}

/** 源顶层函数 repeated(string, count)：count <= 0 返回 '' */
export function repeated(s: string, count: number): string {
  let out: string = '';
  for (let i = 0; i < count; i++) {
    out += s;
  }
  return out;
}

/** java.lang.Character.isWhitespace（BMP 内） */
function javaIsWhitespace(c: number): boolean {
  if (c === 0xA0 || c === 0x2007 || c === 0x202F) {
    return false;
  }
  if ((c >= 0x09 && c <= 0x0D) || (c >= 0x1C && c <= 0x20)) {
    return true;
  }
  return c === 0x1680 || (c >= 0x2000 && c <= 0x200A) || c === 0x2028 || c === 0x2029 || c === 0x205F ||
    c === 0x3000;
}

function isHeading(tag: string): boolean {
  return tag.length === 2 && tag.charAt(0) === 'h' && tag.charAt(1) >= '1' && tag.charAt(1) <= '6';
}

export class HtmlToPlainTextConverter {
  /** StringBuilder 等价：分段累积 + 末字符缓存（避免对长串反复 charAt 导致 O(n²)） */
  private parts: string[] = [];
  private size: number = 0;
  private last: string = '';
  private listings: Listing[] = [];
  private ignoreCount: number = 0;
  private lastImageAlt: string | null = null;

  /** Converts HTML into plain text */
  convert(source: string): string {
    this.parts = [];
    this.size = 0;
    this.last = '';
    this.listings = [];
    this.ignoreCount = 0;
    this.lastImageAlt = null;
    const doc: HtmlDocument = parseHtml(source, '');
    doc.traverse((node: HtmlNode, _d: number) => {
      if (node.nodeType === NODE_ELEMENT) {
        this.handleStartTag(node);
      } else if (node.nodeType === NODE_TEXT || node.nodeType === NODE_DATA) {
        this.characters(node.data);
      }
    }, (node: HtmlNode, _d: number) => {
      if (node.nodeType === NODE_ELEMENT) {
        this.handleEndTag(node.tag);
      }
    });
    this.endDocument();
    const replaced: string = this.parts.join('').split('\u00a0').join(' ');
    let st: number = 0;
    let end: number = replaced.length;
    while (st < end && replaced.charCodeAt(st) <= 32) {
      st++;
    }
    while (end > st && replaced.charCodeAt(end - 1) <= 32) {
      end--;
    }
    return replaced.substring(st, end);
  }

  private append(text: string): void {
    if (text.length > 0) {
      this.parts.push(text);
      this.size += text.length;
      this.last = text.charAt(text.length - 1);
    }
  }

  private endDocument(): void {
    // See test mentioning XKCD
    if (this.size === 0 && this.lastImageAlt !== null) {
      this.append('[' + this.lastImageAlt + ']');
    }
  }

  private handleStartTag(el: HtmlNode): void {
    const tag: string = el.tag;
    if (tag === 'br') {
      // 换行在结束事件处理（TagSoup 对每个 <br> 都配对 </br>）
      return;
    }
    if (tag === 'p' || tag === 'div' || tag === 'blockquote' || isHeading(tag)) {
      this.ensureSpace();
    } else if (tag === 'ul') {
      this.startList(false);
    } else if (tag === 'ol') {
      this.startList(true);
    } else if (tag === 'li') {
      this.startLi();
    } else if (tag === 'style' || tag === 'script') {
      this.ignoreCount++;
    } else if (tag === 'img') {
      this.ensureSpace();
      const alt: string = el.attr('alt');
      this.lastImageAlt = alt.trim().length === 0 ? 'IMG' : alt;
    }
    // strong/b/em/cite/dfn/i/a：源处理函数为空（只保留文字）
  }

  private handleEndTag(tag: string): void {
    if (tag === 'br' || tag === 'p' || tag === 'div' || tag === 'blockquote' || isHeading(tag)) {
      this.ensureSpace();
    } else if (tag === 'ul' || tag === 'ol') {
      this.listings.pop();
    } else if (tag === 'li') {
      this.ensureNewline();
    } else if (tag === 'style' || tag === 'script') {
      this.ignoreCount--;
    }
  }

  private ensureNewline(): void {
    if (this.size > 0 && this.last !== '\n') {
      this.append('\n');
    }
  }

  private startList(ordered: boolean): void {
    // Start lists with linebreak
    this.ensureNewline();
    this.listings.push(new Listing(ordered));
  }

  private startLi(): void {
    this.append(repeated('  ', this.listings.length - 1));
    const top: Listing | null = this.listings.length > 0 ? this.listings[this.listings.length - 1] : null;
    if (top !== null && top.ordered) {
      this.append(`${top.num}. `);
      top.num = top.num + 1;
    } else {
      this.append('* ');
    }
  }

  private ensureSpace(): void {
    if (this.size !== 0) {
      const c: number = this.last.charCodeAt(0);
      // Non-breaking space (160) is not caught by trim or whitespace identification
      if (javaIsWhitespace(c) || c === 160) {
        return;
      }
      this.append(' ');
    }
  }

  private characters(text: string): void {
    if (this.ignoreCount > 0) {
      return;
    }
    // Ignore whitespace that immediately follows other whitespace; newlines count as spaces.
    let sb: string = '';
    for (let i = 0; i < text.length; i++) {
      const c: string = text.charAt(i);
      if (c === ' ' || c === '\n') {
        let prev: string;
        if (sb.length === 0) {
          prev = this.size === 0 ? '\n' : this.last;
        } else {
          prev = sb.charAt(sb.length - 1);
        }
        if (prev !== ' ' && prev !== '\n') {
          sb += ' ';
        }
      } else {
        sb += c;
      }
    }
    this.append(sb);
  }
}

/** 便捷入口：HtmlToPlainTextConverter().convert(html) */
export function htmlToPlainText(html: string): string {
  return new HtmlToPlainTextConverter().convert(html);
}

/**
 * 源 GoFeedExtensions.plainContent（HM-A53）：内容转纯文本为空白但原文含 "img" → "<image>"，
 * 避免条目只有图片时摘要为空。snippet = 结果取前 200 字符（调用方负责）。
 */
export function plainContentOf(content: string): string {
  const result: string = htmlToPlainText(content);
  if (result.trim().length === 0 && content.indexOf('img') >= 0) {
    return '<image>';
  }
  return result;
}
