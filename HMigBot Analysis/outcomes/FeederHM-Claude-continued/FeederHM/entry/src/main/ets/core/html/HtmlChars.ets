/**
 * HtmlChars.ets —— DOM 公用常量与字符/空白/转义工具（Jsoup StringUtil / Tag / Entities.escape 语义）。
 */

export const NODE_ELEMENT: number = 1;
export const NODE_TEXT: number = 3;
export const NODE_DATA: number = 4;
export const NODE_COMMENT: number = 8;
export const NODE_DOCUMENT: number = 9;

/** Jsoup Tag.isBlock 为 true 的已知标签（未知标签为行内） */
export const BLOCK_TAGS: Set<string> = new Set<string>([
  'html', 'head', 'body', 'frameset', 'script', 'noscript', 'style', 'meta', 'link', 'title', 'frame', 'noframes',
  'section', 'nav', 'aside', 'hgroup', 'header', 'footer', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'pre',
  'div', 'blockquote', 'hr', 'address', 'figure', 'figcaption', 'form', 'fieldset', 'ins', 'del', 'dl', 'dt', 'dd',
  'li', 'table', 'caption', 'thead', 'tfoot', 'tbody', 'colgroup', 'col', 'tr', 'th', 'td', 'video', 'audio',
  'canvas', 'details', 'menu', 'plaintext', 'template', 'article', 'main', 'svg', 'math', 'center', 'dir',
  'applet', 'marquee', 'listing', 'search'
]);

/** 空（void）元素：序列化时无结束标签 */
export const VOID_TAGS: Set<string> = new Set<string>([
  'area', 'base', 'basefont', 'bgsound', 'br', 'col', 'embed', 'frame', 'hr', 'img', 'input', 'keygen', 'link',
  'meta', 'param', 'source', 'track', 'wbr', 'menuitem'
]);

/** Jsoup 保留空白的标签（pre 及祖先 6 层内） */
export const PRESERVE_WS_TAGS: Set<string> = new Set<string>(['pre', 'textarea', 'plaintext', 'listing', 'xmp']);


/** 实际空白（Jsoup StringUtil.isActuallyWhitespace：含 NBSP） */
export function isActuallyWhitespace(c: number): boolean {
  return c === 32 || c === 9 || c === 10 || c === 12 || c === 13 || c === 160;
}

/** Jsoup StringUtil.isWhitespace（不含 NBSP） */
export function isHtmlWhitespace(c: number): boolean {
  return c === 32 || c === 9 || c === 10 || c === 12 || c === 13;
}

/** Jsoup StringUtil.appendNormalisedWhitespace（码点级，零宽空格/软连字符丢弃） */
export function appendNormalisedWhitespace(accum: string, s: string, stripLeading: boolean): string {
  let out: string = '';
  let lastWasWhite: boolean = false;
  let reachedNonWhite: boolean = false;
  for (let i = 0; i < s.length; i++) {
    const c: number = s.charCodeAt(i);
    if (isActuallyWhitespace(c)) {
      if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
        continue;
      }
      out += ' ';
      lastWasWhite = true;
    } else if (c !== 8203 && c !== 173) {
      out += s.charAt(i);
      lastWasWhite = false;
      reachedNonWhite = true;
    }
  }
  return accum + out;
}

export function lastCharIsWhitespace(s: string): boolean {
  return s.length > 0 && s.charCodeAt(s.length - 1) === 32;
}

/** Java String.trim（去首尾 <= ' '） */
export function javaTrim(s: string): string {
  let st: number = 0;
  let end: number = s.length;
  while (st < end && s.charCodeAt(st) <= 32) {
    st++;
  }
  while (end > st && s.charCodeAt(end - 1) <= 32) {
    end--;
  }
  return s.substring(st, end);
}

export function escapeHtmlText(s: string, inAttribute: boolean): string {
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const ch: string = s.charAt(i);
    if (ch === '&') {
      out += '&amp;';
    } else if (ch === '\u00a0') {
      out += '&nbsp;';
    } else if (ch === '<' && !inAttribute) {
      out += '&lt;';
    } else if (ch === '>' && !inAttribute) {
      out += '&gt;';
    } else if (ch === '"' && inAttribute) {
      out += '&quot;';
    } else {
      out += ch;
    }
  }
  return out;
}

/** Jsoup text() 的 StringBuilder 等价：分段累积 + 末字符缓存（避免对长串反复取末字符导致 O(n²)） */
export class TextAccum {
  private parts: string[] = [];
  size: number = 0;
  private last: number = -1;

  add(s: string): void {
    if (s.length > 0) {
      this.parts.push(s);
      this.size += s.length;
      this.last = s.charCodeAt(s.length - 1);
    }
  }

  /** ≙ lastCharIsWhitespace（仅 ' '） */
  endsWithSpace(): boolean {
    return this.last === 32;
  }

  /** 追加文本节点内容：pre 等保留原文，否则规整空白（Jsoup appendNormalisedText） */
  addText(data: string, preserve: boolean): void {
    if (preserve) {
      this.add(data);
    } else {
      this.add(appendNormalisedWhitespace('', data, this.endsWithSpace()));
    }
  }

  toString(): string {
    return this.parts.join('');
  }
}
