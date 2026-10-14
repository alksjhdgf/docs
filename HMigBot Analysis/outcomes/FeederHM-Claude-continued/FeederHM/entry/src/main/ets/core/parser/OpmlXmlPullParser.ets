/**
 * OpmlXmlPullParser.ets —— android.util.Xml.newPullParser()（KXmlParser，FEATURE_PROCESS_NAMESPACES=true，非 relaxed）
 * 在 OPML 读取所需范围内的等价物（源 OpmlPullParser.kt 只用 next/nextTag/require/name/namespace/getAttributeValue）。
 *
 * 选择自研而非 `@kit.ArkTS` xml.XmlPullParser：后者无命名空间解析（属性只给 `prefix:name` 原名）、
 * 对坏文档不抛错（源回退正则修复依赖"解析失败"信号）。本实现照 KXmlParser 严格模式：
 *  - 未定义实体 / 未终止实体 / 裸 `&` / 属性值内 `<` / 未加引号或无值属性 / 重复属性 / 未绑定前缀 /
 *    结束标签不匹配 / 文档提前结束 / 根前非空白文本 → 抛 XmlPullParserException
 *  - 属性值内字面 TAB/LF/CR（CRLF 视为一个）规整为空格；字符引用 `&#10;` `&#9;` 原样保留（FP-A49 往返）
 *  - `getAttributeValue(null, n)` 匹配任意命名空间下本地名为 n 的第一个属性（KXmlParser 行为）
 *  - 编码：BOM（UTF-8/UTF-16）或 XML 声明 encoding，缺省 UTF-8（KXmlParser setInput(stream, null) 自动探测）
 * 惰性逐事件读取：根元素结束后的内容不会被读取（源 readOpml 返回后不再 next）。
 */
import { decodeCharset } from '../util/TextCodec';

export const XML_START_DOCUMENT: number = 0;
export const XML_END_DOCUMENT: number = 1;
export const XML_START_TAG: number = 2;
export const XML_END_TAG: number = 3;
export const XML_TEXT: number = 4;

const XML_NS: string = 'http://www.w3.org/XML/1998/namespace';

export class XmlPullParserException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'XmlPullParserException';
  }
}

class XmlAttr {
  qname: string = '';
  localName: string = '';
  prefix: string | null = null;
  namespace: string = '';
  value: string = '';
}

class OpenElement {
  qname: string = '';
  localName: string = '';
  namespace: string = '';
  /** 本元素声明的前缀绑定（含 '' 默认命名空间） */
  bindings: Map<string, string> = new Map<string, string>();
}

function isWs(c: string): boolean {
  return c === ' ' || c === '\t' || c === '\n' || c === '\r';
}

function isNameChar(c: string): boolean {
  if (c.length === 0) {
    return false;
  }
  return !(isWs(c) || c === '/' || c === '>' || c === '<' || c === '=' || c === '"' || c === '\'' || c === '&' ||
    c === '?' || c === '!');
}

export class OpmlXmlPullParser {
  private readonly src: string;
  private pos: number = 0;
  private stack: OpenElement[] = [];
  private pendingEnd: boolean = false;
  private attrs: XmlAttr[] = [];

  eventType: number = XML_START_DOCUMENT;
  /** 当前标签本地名（START_TAG/END_TAG） */
  name: string = '';
  /** 当前标签命名空间 URI（无则 ''） */
  namespace: string = '';
  text: string = '';

  constructor(text: string) {
    this.src = text.length > 0 && text.charCodeAt(0) === 0xfeff ? text.substring(1) : text;
  }

  /** 按 BOM / XML 声明解码字节 */
  static fromBytes(bytes: Uint8Array): OpmlXmlPullParser {
    return new OpmlXmlPullParser(OpmlXmlPullParser.decode(bytes));
  }

  static decode(bytes: Uint8Array): string {
    let label: string = 'utf-8';
    let start: number = 0;
    if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
      start = 3;
    } else if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
      label = 'utf-16be';
      start = 2;
    } else if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
      label = 'utf-16le';
      start = 2;
    } else {
      let head: string = '';
      const n: number = Math.min(bytes.length, 256);
      for (let i = 0; i < n; i++) {
        head += String.fromCharCode(bytes[i]);
      }
      const m: RegExpMatchArray | null =
        head.match(new RegExp('^\\s*<\\?xml[^>]*?encoding\\s*=\\s*["\']([A-Za-z0-9._:\\-]+)["\']'));
      if (m !== null) {
        label = m[1].toLowerCase();
      }
    }
    const data: Uint8Array = bytes.subarray(start);
    return decodeCharset(data, label);
  }

  get depth(): number {
    return this.stack.length;
  }

  private fail(msg: string): XmlPullParserException {
    return new XmlPullParserException(`${msg} (position:${this.pos})`);
  }

  private resolve(prefix: string): string | null {
    if (prefix === 'xml') {
      return XML_NS;
    }
    for (let i = this.stack.length - 1; i >= 0; i--) {
      const v: string | undefined = this.stack[i].bindings.get(prefix);
      if (v !== undefined) {
        return v;
      }
    }
    return prefix.length === 0 ? '' : null;
  }

  getAttributeCount(): number {
    return this.eventType === XML_START_TAG ? this.attrs.length : -1;
  }

  /** KXmlParser.getAttributeValue：namespace 为 null 时匹配任意命名空间 */
  getAttributeValue(ns: string | null, attrName: string): string | null {
    if (this.eventType !== XML_START_TAG) {
      return null;
    }
    for (const a of this.attrs) {
      if (a.localName === attrName && (ns === null || a.namespace === ns)) {
        return a.value;
      }
    }
    return null;
  }

  require(type: number, ns: string | null, tagName: string | null): void {
    if (type !== this.eventType || (ns !== null && ns !== this.namespace) ||
      (tagName !== null && tagName !== this.name)) {
      throw this.fail(`expected event ${type} ${ns ?? ''}:${tagName ?? ''} but was ${this.eventType} ${this.name}`);
    }
  }

  /** next() 后跳过空白 TEXT；必须落在 START_TAG/END_TAG */
  nextTag(): number {
    let t: number = this.next();
    if (t === XML_TEXT && this.text.trim().length === 0) {
      t = this.next();
    }
    if (t !== XML_START_TAG && t !== XML_END_TAG) {
      throw this.fail('unexpected type');
    }
    return t;
  }

  next(): number {
    this.text = '';
    if (this.pendingEnd) {
      this.pendingEnd = false;
      this.attrs = [];
      this.eventType = XML_END_TAG;
      this.stack.pop();
      return this.eventType;
    }
    if (this.eventType === XML_END_TAG) {
      this.attrs = [];
    }
    const src: string = this.src;
    while (true) {
      if (this.pos >= src.length) {
        if (this.stack.length > 0) {
          throw this.fail('Unexpected EOF');
        }
        this.eventType = XML_END_DOCUMENT;
        return this.eventType;
      }
      if (src.charAt(this.pos) === '<') {
        if (src.startsWith('<?', this.pos)) {
          const end: number = src.indexOf('?>', this.pos + 2);
          if (end < 0) {
            throw this.fail('Unterminated processing instruction');
          }
          this.pos = end + 2;
          continue;
        }
        if (src.startsWith('<!--', this.pos)) {
          const end: number = src.indexOf('-->', this.pos + 4);
          if (end < 0) {
            throw this.fail('Unterminated comment');
          }
          this.pos = end + 3;
          continue;
        }
        if (src.startsWith('<![CDATA[', this.pos)) {
          const end: number = src.indexOf(']]>', this.pos + 9);
          if (end < 0 || this.stack.length === 0) {
            throw this.fail('Unexpected CDATA');
          }
          this.text = src.substring(this.pos + 9, end);
          this.pos = end + 3;
          this.eventType = XML_TEXT;
          return this.eventType;
        }
        if (src.startsWith('<!', this.pos)) {
          this.skipDeclaration();
          continue;
        }
        if (src.startsWith('</', this.pos)) {
          return this.readEndTag();
        }
        return this.readStartTag();
      }
      const lt: number = src.indexOf('<', this.pos);
      const end: number = lt < 0 ? src.length : lt;
      const raw: string = src.substring(this.pos, end);
      const decoded: string = this.decodeEntities(raw, false);
      this.pos = end;
      if (this.stack.length === 0) {
        if (decoded.trim().length > 0) {
          throw this.fail('Text not allowed outside root element');
        }
        continue;
      }
      this.text = decoded;
      this.eventType = XML_TEXT;
      return this.eventType;
    }
  }

  private skipDeclaration(): void {
    // <!DOCTYPE …[ … ]> 或其它 <! 声明
    let bracket: number = 0;
    let quote: string = '';
    let i: number = this.pos + 2;
    const src: string = this.src;
    while (i < src.length) {
      const c: string = src.charAt(i);
      if (quote.length > 0) {
        if (c === quote) {
          quote = '';
        }
      } else if (c === '"' || c === '\'') {
        quote = c;
      } else if (c === '[') {
        bracket++;
      } else if (c === ']') {
        bracket--;
      } else if (c === '>' && bracket <= 0) {
        this.pos = i + 1;
        return;
      }
      i++;
    }
    throw this.fail('Unterminated declaration');
  }

  private readName(): string {
    const start: number = this.pos;
    while (this.pos < this.src.length && isNameChar(this.src.charAt(this.pos))) {
      this.pos++;
    }
    if (this.pos === start) {
      throw this.fail('name expected');
    }
    return this.src.substring(start, this.pos);
  }

  private skipWs(): void {
    while (this.pos < this.src.length && isWs(this.src.charAt(this.pos))) {
      this.pos++;
    }
  }

  private readEndTag(): number {
    this.pos += 2;
    const qname: string = this.readName();
    this.skipWs();
    if (this.src.charAt(this.pos) !== '>') {
      throw this.fail('expected >');
    }
    this.pos++;
    const top: OpenElement | undefined = this.stack[this.stack.length - 1];
    if (top === undefined || top.qname !== qname) {
      throw this.fail(`expected: /${top === undefined ? '' : top.qname} read: ${qname}`);
    }
    this.name = top.localName;
    this.namespace = top.namespace;
    this.attrs = [];
    this.eventType = XML_END_TAG;
    this.stack.pop();
    return this.eventType;
  }

  private readStartTag(): number {
    this.pos++;
    const qname: string = this.readName();
    const el: OpenElement = new OpenElement();
    el.qname = qname;
    const attrs: XmlAttr[] = [];
    let selfClosing: boolean = false;
    while (true) {
      const hadWs: boolean = this.pos < this.src.length && isWs(this.src.charAt(this.pos));
      this.skipWs();
      if (this.pos >= this.src.length) {
        throw this.fail('Unexpected EOF in start tag');
      }
      const c: string = this.src.charAt(this.pos);
      if (c === '>') {
        this.pos++;
        break;
      }
      if (c === '/') {
        if (this.src.charAt(this.pos + 1) !== '>') {
          throw this.fail('expected />');
        }
        this.pos += 2;
        selfClosing = true;
        break;
      }
      if (!hadWs) {
        throw this.fail('whitespace required between attributes');
      }
      const an: string = this.readName();
      this.skipWs();
      if (this.src.charAt(this.pos) !== '=') {
        throw this.fail(`Attr.value missing f. ${an}`);
      }
      this.pos++;
      this.skipWs();
      const q: string = this.src.charAt(this.pos);
      if (q !== '"' && q !== '\'') {
        throw this.fail('attr value delimiter missing!');
      }
      const close: number = this.src.indexOf(q, this.pos + 1);
      if (close < 0) {
        throw this.fail('Unterminated attribute value');
      }
      const rawValue: string = this.src.substring(this.pos + 1, close);
      if (rawValue.indexOf('<') >= 0) {
        throw this.fail('Illegal: "<" inside attribute value');
      }
      this.pos = close + 1;
      for (const existing of attrs) {
        if (existing.qname === an) {
          throw this.fail(`Duplicate attribute: ${an}`);
        }
      }
      const a: XmlAttr = new XmlAttr();
      a.qname = an;
      a.value = this.decodeEntities(rawValue, true);
      attrs.push(a);
    }

    // 命名空间声明
    const kept: XmlAttr[] = [];
    for (const a of attrs) {
      if (a.qname === 'xmlns') {
        el.bindings.set('', a.value);
      } else if (a.qname.startsWith('xmlns:')) {
        el.bindings.set(a.qname.substring(6), a.value);
      } else {
        kept.push(a);
      }
    }
    this.stack.push(el);
    for (const a of kept) {
      const idx: number = a.qname.indexOf(':');
      if (idx >= 0) {
        a.prefix = a.qname.substring(0, idx);
        a.localName = a.qname.substring(idx + 1);
        const ns: string | null = this.resolve(a.prefix);
        if (ns === null) {
          throw this.fail(`Undefined Prefix: ${a.prefix} in ${qname}`);
        }
        a.namespace = ns;
      } else {
        a.localName = a.qname;
        a.namespace = '';
      }
    }
    const eidx: number = qname.indexOf(':');
    if (eidx >= 0) {
      const prefix: string = qname.substring(0, eidx);
      const ns: string | null = this.resolve(prefix);
      if (ns === null) {
        throw this.fail(`undefined prefix: ${prefix}`);
      }
      el.localName = qname.substring(eidx + 1);
      el.namespace = ns;
    } else {
      el.localName = qname;
      const def: string | null = this.resolve('');
      el.namespace = def === null ? '' : def;
    }
    this.attrs = kept;
    this.name = el.localName;
    this.namespace = el.namespace;
    this.eventType = XML_START_TAG;
    this.pendingEnd = selfClosing;
    return this.eventType;
  }

  /** 解码实体与字符引用；attr=true 时先把字面 TAB/CR/LF（CRLF 合一）规整为空格 */
  private decodeEntities(raw: string, attr: boolean): string {
    let s: string = raw;
    if (attr) {
      s = s.split('\r\n').join(' ').replace(new RegExp('[\\t\\n\\r]', 'g'), ' ');
    } else {
      s = s.split('\r\n').join('\n').split('\r').join('\n');
    }
    if (s.indexOf('&') < 0) {
      return s;
    }
    let out: string = '';
    let i: number = 0;
    while (i < s.length) {
      const c: string = s.charAt(i);
      if (c !== '&') {
        out += c;
        i++;
        continue;
      }
      const semi: number = s.indexOf(';', i + 1);
      if (semi < 0) {
        throw this.fail('unterminated entity ref');
      }
      const ent: string = s.substring(i + 1, semi);
      if (ent === 'amp') {
        out += '&';
      } else if (ent === 'lt') {
        out += '<';
      } else if (ent === 'gt') {
        out += '>';
      } else if (ent === 'quot') {
        out += '"';
      } else if (ent === 'apos') {
        out += '\'';
      } else if (ent.startsWith('#x') || ent.startsWith('#X')) {
        out += this.codePoint(ent.substring(2), 16);
      } else if (ent.startsWith('#')) {
        out += this.codePoint(ent.substring(1), 10);
      } else {
        throw this.fail(`unresolved: &${ent};`);
      }
      i = semi + 1;
    }
    return out;
  }

  private codePoint(digits: string, radix: number): string {
    const re: RegExp = radix === 16 ? new RegExp('^[0-9A-Fa-f]+$') : new RegExp('^[0-9]+$');
    if (!re.test(digits)) {
      throw this.fail(`invalid character reference: ${digits}`);
    }
    const cp: number = parseInt(digits, radix);
    if (!Number.isFinite(cp) || cp > 0x10ffff) {
      throw this.fail(`invalid character reference: ${digits}`);
    }
    return String.fromCodePoint(cp);
  }
}
