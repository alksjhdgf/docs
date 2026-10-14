/**
 * FeedXmlTokenizer.ets —— Feed 解析用的宽容 XML 拉式分词器（替代 gofeed 依赖的 goxpp + Go encoding/xml 非严格模式）。
 *
 * 复刻的 Go 行为（Decoder.Strict = false + goxpp）：
 *  - 事件：START_TAG / END_TAG / TEXT / END_DOCUMENT；注释、处理指令、DOCTYPE 被跳过；CDATA 并入文本（不解码实体）。
 *  - 自闭合 `<a/>` 产生 START_TAG + END_TAG。
 *  - 实体：XML 五个预定义实体与数字字符引用被解码；未知实体 / 非法 `&` 原样保留（非严格模式）。
 *  - `\r\n` 与单独 `\r` 规范化为 `\n`（文本与属性值）。
 *  - 属性：无引号值、无值属性（值=属性名）均接受。
 *  - 命名空间：元素 space = 前缀绑定的命名空间 URL；前缀未声明时 space = 前缀本身；无前缀时取默认命名空间。
 *    `spaces`（goxpp Spaces）为全局累积的 URL → 前缀（前缀小写）映射。
 *  - xml:base 栈（goxpp BaseStack）。
 *  - 不匹配的结束标签：关闭栈顶直到同名元素（Go 非严格模式的 needClose 语义）。
 * 宽容扩展（Go 会报错使整个 feed 解析失败，此处继续）：栈中不存在的游离结束标签被忽略；文档提前结束时补齐结束标签；
 * 不能开始标签的裸 `<` 当作文本。
 */
import { decodeXmlEntities, isNameEnd, isNameStart, isWs, normalizeNewlines, resolveBase } from './FeedXmlText';

export const XML_START_DOCUMENT: number = 0;
export const XML_END_DOCUMENT: number = 1;
export const XML_START_TAG: number = 2;
export const XML_END_TAG: number = 3;
export const XML_TEXT: number = 4;

/** XML 命名空间（xml: 前缀） */
const XML_NS_URL: string = 'http://www.w3.org/XML/1998/namespace';

export class XmlAttr {
  prefix: string;
  local: string;
  /** 已翻译的命名空间（xmlns 声明为 "xmlns"） */
  space: string;
  value: string;

  constructor(prefix: string, local: string, space: string, value: string) {
    this.prefix = prefix;
    this.local = local;
    this.space = space;
    this.value = value;
  }
}

class ElementFrame {
  qname: string;
  /** 本元素声明的 前缀 → URL（默认命名空间前缀为 ''） */
  ns: Map<string, string> | null;
  /** 本元素 xml:base（已按父 base 解析）；未声明为 null */
  base: string | null;

  constructor(qname: string, ns: Map<string, string> | null, base: string | null) {
    this.qname = qname;
    this.ns = ns;
    this.base = base;
  }
}


export class FeedXmlTokenizer {
  private readonly src: string;
  private pos: number = 0;
  event: number = XML_START_DOCUMENT;
  /** 当前元素本地名 */
  name: string = '';
  prefix: string = '';
  /** 当前元素命名空间（goxpp p.Space） */
  space: string = '';
  attrs: XmlAttr[] = [];
  text: string = '';
  /** 当前标签 '<' 的位置（合成的结束标签：用于截取 innerxml 的结束位置） */
  tagStart: number = 0;
  /** 当前标签 '>' 之后的位置 */
  tagEnd: number = 0;
  /** goxpp Spaces：命名空间 URL → 前缀（小写） */
  readonly spaces: Map<string, string> = new Map<string, string>();
  private stack: ElementFrame[] = [];
  private pendingEnds: number = 0;
  private pendingEndStart: number = 0;
  private pendingEndEnd: number = 0;

  constructor(src: string) {
    this.src = src;
  }

  depth(): number {
    return this.stack.length;
  }

  /** 当前作用域的 xml:base（goxpp BaseStack.Top），无则 null */
  currentBase(): string | null {
    for (let i = this.stack.length - 1; i >= 0; i--) {
      const b: string | null = this.stack[i].base;
      if (b !== null) {
        return b;
      }
    }
    return null;
  }

  /** goxpp Attribute(name)：按本地名查找（忽略前缀），未找到返回 '' */
  attribute(local: string): string {
    for (let i = 0; i < this.attrs.length; i++) {
      if (this.attrs[i].local === local) {
        return this.attrs[i].value;
      }
    }
    return '';
  }

  next(): number {
    if (this.pendingEnds > 0) {
      this.pendingEnds--;
      return this.emitEnd(this.pendingEndStart, this.pendingEndEnd);
    }
    if (this.event === XML_END_DOCUMENT) {
      return XML_END_DOCUMENT;
    }
    const src: string = this.src;
    const n: number = src.length;
    let textBuf: string = '';
    let hasText: boolean = false;
    while (true) {
      if (this.pos >= n) {
        if (hasText) {
          return this.emitText(textBuf);
        }
        if (this.stack.length > 0) {
          return this.emitEnd(n, n);
        }
        this.event = XML_END_DOCUMENT;
        return XML_END_DOCUMENT;
      }
      const lt: number = src.indexOf('<', this.pos);
      if (lt < 0 || lt > this.pos) {
        const end: number = lt < 0 ? n : lt;
        textBuf += decodeXmlEntities(normalizeNewlines(src.substring(this.pos, end)));
        hasText = true;
        this.pos = end;
        continue;
      }
      // src[pos] === '<'
      const c1: number = this.pos + 1 < n ? src.charCodeAt(this.pos + 1) : -1;
      if (c1 === 0x21) {
        if (src.startsWith('<!--', this.pos)) {
          const e: number = src.indexOf('-->', this.pos + 4);
          this.pos = e < 0 ? n : e + 3;
          continue;
        }
        if (src.startsWith('<![CDATA[', this.pos)) {
          const e: number = src.indexOf(']]>', this.pos + 9);
          const end: number = e < 0 ? n : e;
          textBuf += normalizeNewlines(src.substring(this.pos + 9, end));
          hasText = true;
          this.pos = e < 0 ? n : e + 3;
          continue;
        }
        this.pos = this.skipDirective(this.pos + 2);
        continue;
      }
      if (c1 === 0x3F) {
        const e: number = src.indexOf('?>', this.pos + 2);
        this.pos = e < 0 ? n : e + 2;
        continue;
      }
      if (c1 === 0x2F) {
        if (hasText) {
          return this.emitText(textBuf);
        }
        const r: number = this.readEndTag();
        if (r >= 0) {
          return r;
        }
        continue;
      }
      if (c1 >= 0 && isNameStart(c1)) {
        if (hasText) {
          return this.emitText(textBuf);
        }
        return this.readStartTag();
      }
      // 裸 '<'：当作文本
      textBuf += '<';
      hasText = true;
      this.pos++;
    }
  }

  /** 当前为 START_TAG：读到匹配的 END_TAG，返回原始内部 XML（Go `xml:",innerxml"`） */
  readInnerXml(): string {
    const startDepth: number = this.stack.length;
    const begin: number = this.tagEnd;
    while (true) {
      const ev: number = this.next();
      if (ev === XML_END_TAG && this.stack.length < startDepth) {
        return this.src.substring(begin, Math.max(begin, this.tagStart));
      }
      if (ev === XML_END_DOCUMENT) {
        return this.src.substring(begin);
      }
    }
  }

  /** goxpp Skip：当前为 START_TAG，跳过整个元素（含子孙） */
  skip(): void {
    const startDepth: number = this.stack.length;
    while (true) {
      const ev: number = this.next();
      if ((ev === XML_END_TAG && this.stack.length < startDepth) || ev === XML_END_DOCUMENT) {
        return;
      }
    }
  }

  /** 源 shared.NextTag：跳过文本，返回下一个 START_TAG / END_TAG / END_DOCUMENT */
  nextTag(): number {
    while (true) {
      const ev: number = this.next();
      if (ev === XML_START_TAG || ev === XML_END_TAG || ev === XML_END_DOCUMENT) {
        return ev;
      }
    }
  }

  private emitText(text: string): number {
    this.event = XML_TEXT;
    this.text = text;
    return XML_TEXT;
  }

  private emitEnd(start: number, end: number): number {
    const frame: ElementFrame | undefined = this.stack.pop();
    this.event = XML_END_TAG;
    this.tagStart = start;
    this.tagEnd = end;
    this.attrs = [];
    if (frame !== undefined) {
      this.setNameFromQName(frame.qname, false);
    }
    return XML_END_TAG;
  }

  private skipDirective(from: number): number {
    const src: string = this.src;
    let depth: number = 0;
    let i: number = from;
    while (i < src.length) {
      const c: number = src.charCodeAt(i);
      if (c === 0x5B) {
        depth++;
      } else if (c === 0x5D) {
        depth--;
      } else if (c === 0x3E && depth <= 0) {
        return i + 1;
      }
      i++;
    }
    return src.length;
  }

  /** 读取结束标签；返回事件，或 -1 表示被忽略（游离结束标签） */
  private readEndTag(): number {
    const src: string = this.src;
    const start: number = this.pos;
    let i: number = this.pos + 2;
    while (i < src.length && !isNameEnd(src.charCodeAt(i))) {
      i++;
    }
    const qname: string = src.substring(this.pos + 2, i);
    const gt: number = src.indexOf('>', i);
    const end: number = gt < 0 ? src.length : gt + 1;
    this.pos = end;
    const local: string = localOf(qname);
    let idx: number = -1;
    for (let k = this.stack.length - 1; k >= 0; k--) {
      if (localOf(this.stack[k].qname) === local) {
        idx = k;
        break;
      }
    }
    if (idx < 0) {
      return -1;
    }
    const count: number = this.stack.length - idx;
    this.pendingEnds = count - 1;
    this.pendingEndStart = start;
    this.pendingEndEnd = end;
    return this.emitEnd(start, end);
  }

  private readStartTag(): number {
    const src: string = this.src;
    const n: number = src.length;
    const start: number = this.pos;
    let i: number = this.pos + 1;
    while (i < n && !isNameEnd(src.charCodeAt(i))) {
      i++;
    }
    const qname: string = src.substring(this.pos + 1, i);
    const rawAttrs: string[] = [];
    let selfClosing: boolean = false;
    while (true) {
      while (i < n && isWs(src.charCodeAt(i))) {
        i++;
      }
      if (i >= n) {
        break;
      }
      const c: number = src.charCodeAt(i);
      if (c === 0x3E) {
        i++;
        break;
      }
      if (c === 0x2F) {
        if (i + 1 < n && src.charCodeAt(i + 1) === 0x3E) {
          selfClosing = true;
          i += 2;
          break;
        }
        i++;
        continue;
      }
      if (c === 0x3C) {
        // 标签未闭合就遇到下一个 '<'：在此结束本标签
        break;
      }
      const ns: number = i;
      while (i < n && !isNameEnd(src.charCodeAt(i))) {
        i++;
      }
      if (i === ns) {
        i++;
        continue;
      }
      const aname: string = src.substring(ns, i);
      let j: number = i;
      while (j < n && isWs(src.charCodeAt(j))) {
        j++;
      }
      let value: string = aname;
      if (j < n && src.charCodeAt(j) === 0x3D) {
        j++;
        while (j < n && isWs(src.charCodeAt(j))) {
          j++;
        }
        const q: number = j < n ? src.charCodeAt(j) : -1;
        if (q === 0x22 || q === 0x27) {
          const close: number = src.indexOf(String.fromCharCode(q), j + 1);
          const ve: number = close < 0 ? n : close;
          value = src.substring(j + 1, ve);
          i = close < 0 ? n : close + 1;
        } else {
          let k: number = j;
          while (k < n && !isWs(src.charCodeAt(k)) && src.charCodeAt(k) !== 0x3E) {
            k++;
          }
          value = src.substring(j, k);
          i = k;
        }
        value = decodeXmlEntities(normalizeNewlines(value));
      }
      rawAttrs.push(aname);
      rawAttrs.push(value);
    }
    this.pos = i;
    this.tagStart = start;
    this.tagEnd = i;
    return this.pushElement(qname, rawAttrs, selfClosing);
  }

  private pushElement(qname: string, rawAttrs: string[], selfClosing: boolean): number {
    let nsDecl: Map<string, string> | null = null;
    for (let k = 0; k < rawAttrs.length; k += 2) {
      const an: string = rawAttrs[k];
      const av: string = rawAttrs[k + 1];
      if (an === 'xmlns') {
        if (nsDecl === null) {
          nsDecl = new Map<string, string>();
        }
        nsDecl.set('', av);
        this.spaces.set(av.trim(), '');
      } else if (an.startsWith('xmlns:')) {
        const p: string = an.substring(6);
        if (nsDecl === null) {
          nsDecl = new Map<string, string>();
        }
        nsDecl.set(p, av);
        this.spaces.set(av.trim(), p.trim().toLowerCase());
      }
    }
    const frame: ElementFrame = new ElementFrame(qname, nsDecl, null);
    this.stack.push(frame);
    const attrs: XmlAttr[] = [];
    for (let k = 0; k < rawAttrs.length; k += 2) {
      const an: string = rawAttrs[k];
      const colon: number = an.indexOf(':');
      let p: string = '';
      let local: string = an;
      if (colon > 0 && colon < an.length - 1) {
        p = an.substring(0, colon);
        local = an.substring(colon + 1);
      }
      let space: string = '';
      if (p === 'xmlns') {
        space = 'xmlns';
      } else if (p === 'xml') {
        space = XML_NS_URL;
      } else if (p.length > 0) {
        const u: string | null = this.lookupNs(p);
        space = u !== null ? u : p;
      }
      attrs.push(new XmlAttr(p, local, space, rawAttrs[k + 1]));
      if (space === XML_NS_URL && local === 'base') {
        frame.base = resolveBase(this.parentBase(), rawAttrs[k + 1]);
      }
    }
    this.attrs = attrs;
    this.setNameFromQName(qname, true);
    this.event = XML_START_TAG;
    if (selfClosing) {
      this.pendingEnds = 1;
      this.pendingEndStart = this.tagEnd;
      this.pendingEndEnd = this.tagEnd;
    }
    return XML_START_TAG;
  }

  private parentBase(): string | null {
    for (let i = this.stack.length - 2; i >= 0; i--) {
      const b: string | null = this.stack[i].base;
      if (b !== null) {
        return b;
      }
    }
    return null;
  }

  private lookupNs(prefix: string): string | null {
    for (let i = this.stack.length - 1; i >= 0; i--) {
      const m: Map<string, string> | null = this.stack[i].ns;
      if (m !== null) {
        const v: string | undefined = m.get(prefix);
        if (v !== undefined) {
          return v;
        }
      }
    }
    return null;
  }

  private setNameFromQName(qname: string, translate: boolean): void {
    const colon: number = qname.indexOf(':');
    if (colon > 0 && colon < qname.length - 1) {
      this.prefix = qname.substring(0, colon);
      this.name = qname.substring(colon + 1);
    } else {
      this.prefix = '';
      this.name = qname;
    }
    if (!translate) {
      return;
    }
    if (this.prefix.length > 0) {
      if (this.prefix === 'xml') {
        this.space = XML_NS_URL;
        return;
      }
      const u: string | null = this.lookupNs(this.prefix);
      this.space = u !== null ? u : this.prefix;
    } else {
      const d: string | null = this.lookupNs('');
      this.space = d !== null ? d : '';
    }
  }
}

function localOf(qname: string): string {
  const colon: number = qname.indexOf(':');
  return colon > 0 && colon < qname.length - 1 ? qname.substring(colon + 1) : qname;
}

