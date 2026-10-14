/**
 * GoFeedShared.ets —— gofeed internal/shared 的移植：ParseText / DecodeEntities / StripCDATA / 扩展元素解析
 * （IsExtension / ParseExtension）/ ParseNameAddress / FindRoot，供 RSS（XmlFeedParser）与 Atom（AtomFeedParser）共用。
 * 宽容差异（Go 会令整个 feed 解析失败，此处不失败）：DecodeEntities 遇未知/截断实体原样保留。
 */
import { emptyToNull, GoExtension, GoExtensions, GoPerson } from './GoFeed';
import { FeedXmlTokenizer, XML_END_DOCUMENT, XML_END_TAG, XML_START_TAG, XML_TEXT, XmlAttr } from './FeedXmlTokenizer';

const CDATA_START: string = '<![CDATA[';
const CDATA_END: string = ']]>';

/** 解析失败（≙ gofeed 返回的 error） */
export class FeedParseException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FeedParseException';
  }
}

/** 规范前缀（gofeed prefixForNamespace 先查规范表，再查文档声明，最后用 space 本身） */
const CANONICAL_NAMESPACES: Map<string, string> = new Map<string, string>([
  ['http://purl.org/dc/elements/1.1/', 'dc'],
  ['http://purl.org/dc/terms/', 'dcterms'],
  ['http://www.itunes.com/dtds/podcast-1.0.dtd', 'itunes'],
  ['http://search.yahoo.com/mrss/', 'media'],
  ['http://purl.org/rss/1.0/modules/content/', 'content']
]);

// ---------------------------------------------------------------- shared

/**
 * 源 shared.DecodeEntities：仅五个预定义实体与数字引用（`&#x` 小写 x 才按十六进制）。
 * Go 遇未知实体/截断实体/非法数字引用返回 error；此处宽容：原样保留该 '&'。
 */
export function decodeEntities(str: string): string {
  let amp: number = str.indexOf('&');
  if (amp < 0) {
    return str;
  }
  let out: string = '';
  let last: number = 0;
  while (amp >= 0) {
    const semi: number = str.indexOf(';', amp + 1);
    let rep: string | null = null;
    if (semi > amp) {
      const name: string = str.substring(amp + 1, semi);
      rep = goEntity(name);
    }
    if (rep !== null) {
      out += str.substring(last, amp) + rep;
      last = semi + 1;
      amp = str.indexOf('&', last);
    } else {
      amp = str.indexOf('&', amp + 1);
    }
  }
  return out + str.substring(last);
}

function goEntity(name: string): string | null {
  if (name.length > 0 && name.charAt(0) === '#') {
    let digits: string;
    let base: number;
    if (name.length > 1 && name.charAt(1) === 'x') {
      digits = name.substring(2);
      base = 16;
    } else {
      digits = name.substring(1);
      base = 10;
    }
    const ok: boolean = base === 16 ? new RegExp('^[0-9a-fA-F]+$').test(digits) : new RegExp('^[0-9]+$').test(digits);
    if (!ok) {
      return null;
    }
    const v: number = parseInt(digits, base);
    if (v > 0xFFFFFFFF) {
      return null;
    }
    // Go WriteRune：非法码点写 U+FFFD
    if (v > 0x10FFFF || (v >= 0xD800 && v <= 0xDFFF)) {
      return '�';
    }
    return String.fromCodePoint(v);
  }
  switch (name) {
    case 'lt':
      return '<';
    case 'gt':
      return '>';
    case 'quot':
      return '"';
    case 'apos':
      return '\'';
    case 'amp':
      return '&';
    default:
      return null;
  }
}

/** 源 shared.StripCDATA：CDATA 内容原样，CDATA 之外的部分经 DecodeEntities */
export function stripCdata(str: string): string {
  let out: string = '';
  let curr: number = 0;
  while (curr < str.length) {
    const start: number = str.indexOf(CDATA_START, curr);
    if (start < 0) {
      return out + decodeEntities(str.substring(curr));
    }
    const end: number = str.indexOf(CDATA_END, start);
    if (end < 0) {
      return out + decodeEntities(str.substring(curr));
    }
    out += decodeEntities(str.substring(curr, start));
    out += str.substring(start + CDATA_START.length, end);
    curr = end + CDATA_END.length;
  }
  return out;
}

/** Go strings.TrimSpace */
export function goTrim(s: string): string {
  return s.trim();
}

/** 源 shared.ParseText：取元素原始 innerxml、trim；含 CDATA → StripCDATA，否则 DecodeEntities */
export function parseText(tok: FeedXmlTokenizer): string {
  const result: string = goTrim(tok.readInnerXml());
  if (result.indexOf(CDATA_START) >= 0) {
    return stripCdata(result);
  }
  return decodeEntities(result);
}

/** 源 shared.IsExtension */
export function isExtension(tok: FeedXmlTokenizer): boolean {
  const space: string = tok.space.trim();
  const prefix: string | undefined = tok.spaces.get(space);
  if (prefix !== undefined) {
    return !(prefix === '' || prefix === 'rss' || prefix === 'rdf' || prefix === 'content');
  }
  return tok.space !== '';
}

function prefixForNamespace(space: string, tok: FeedXmlTokenizer): string {
  const canonical: string | undefined = CANONICAL_NAMESPACES.get(space);
  if (canonical !== undefined) {
    return canonical;
  }
  const declared: string | undefined = tok.spaces.get(space);
  if (declared !== undefined) {
    return declared;
  }
  return space;
}

/** 源 shared.parseExtensionElement：当前为 START_TAG */
function parseExtensionElement(tok: FeedXmlTokenizer): GoExtension {
  const e: GoExtension = new GoExtension(tok.name, '', new Map<string, string>(), new Map<string, GoExtension[]>());
  const attrs: XmlAttr[] = tok.attrs;
  for (let i = 0; i < attrs.length; i++) {
    (e.attrs as Map<string, string>).set(attrs[i].local, attrs[i].value);
  }
  let value: string = '';
  while (true) {
    const ev: number = tok.next();
    if (ev === XML_END_TAG || ev === XML_END_DOCUMENT) {
      break;
    }
    if (ev === XML_START_TAG) {
      const child: GoExtension = parseExtensionElement(tok);
      const children: Map<string, GoExtension[]> = e.children as Map<string, GoExtension[]>;
      const key: string = child.name !== null ? child.name : '';
      const list: GoExtension[] | undefined = children.get(key);
      if (list === undefined) {
        children.set(key, [child]);
      } else {
        list.push(child);
      }
    } else if (ev === XML_TEXT) {
      value += tok.text;
    }
  }
  e.value = goTrim(value);
  return e;
}

/** 源 shared.ParseExtension：解析当前扩展元素并并入 extensions[prefix][name] */
export function parseExtension(extensions: GoExtensions, tok: FeedXmlTokenizer): void {
  const prefix: string = prefixForNamespace(tok.space, tok);
  const name: string = tok.name;
  const result: GoExtension = parseExtensionElement(tok);
  let byName: Map<string, GoExtension[]> | undefined = extensions.get(prefix);
  if (byName === undefined) {
    byName = new Map<string, GoExtension[]>();
    extensions.set(prefix, byName);
  }
  const list: GoExtension[] | undefined = byName.get(name);
  if (list === undefined) {
    byName.set(name, [result]);
  } else {
    list.push(result);
  }
}

/** extensions[prefix][name] 的全部 value */
export function extValues(extensions: GoExtensions, prefix: string, name: string): string[] {
  const byName: Map<string, GoExtension[]> | undefined = extensions.get(prefix);
  if (byName === undefined) {
    return [];
  }
  const list: GoExtension[] | undefined = byName.get(name);
  if (list === undefined) {
    return [];
  }
  const out: string[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(list[i].value !== null ? list[i].value as string : '');
  }
  return out;
}

/** iTunes 字符串字段：首个扩展的 value */
export function extFirst(extensions: GoExtensions, prefix: string, name: string): string {
  const v: string[] = extValues(extensions, prefix, name);
  return v.length > 0 ? v[0] : '';
}

/** itunes:image 取 href 属性 */
export function extFirstAttr(extensions: GoExtensions, prefix: string, name: string, attr: string): string {
  const byName: Map<string, GoExtension[]> | undefined = extensions.get(prefix);
  if (byName === undefined) {
    return '';
  }
  const list: GoExtension[] | undefined = byName.get(name);
  if (list === undefined || list.length === 0 || list[0].attrs === null) {
    return '';
  }
  const v: string | undefined = (list[0].attrs as Map<string, string>).get(attr);
  return v !== undefined ? v : '';
}

/** 源 shared.ParseNameAddress → [name, address]（未匹配均为空串） */
export function parseNameAddress(text: string): string[] {
  if (text.length === 0) {
    return ['', ''];
  }
  let m: RegExpMatchArray | null = text.match(new RegExp('^([^@]+@[^\\s]+)\\s+\\(([^@]+)\\)$'));
  if (m !== null) {
    return [m[2], m[1]];
  }
  m = text.match(new RegExp('^([^@]+)\\s+\\(([^@]+@[^)]+)\\)$'));
  if (m !== null) {
    return [m[1], m[2]];
  }
  m = text.match(new RegExp('^([^@()]+)$'));
  if (m !== null) {
    return [m[1], ''];
  }
  m = text.match(new RegExp('^([^@()]+@[^@()]+)$'));
  if (m !== null) {
    return ['', m[1]];
  }
  return ['', ''];
}

/** ParseNameAddress → GoPerson（Go 侧 &Person{} 总是非 nil；空字段 omitempty → null） */
export function personFromText(text: string): GoPerson {
  const na: string[] = parseNameAddress(text);
  return new GoPerson(emptyToNull(na[0]), emptyToNull(na[1]));
}

/** extensions 为空 → null（omitempty） */
export function extensionsOrNull(ext: GoExtensions): GoExtensions | null {
  return ext.size > 0 ? ext : null;
}

/** 找到根元素（shared.FindRoot），返回其小写本地名；无则抛错 */
export function findRoot(tok: FeedXmlTokenizer): string {
  while (true) {
    const ev: number = tok.next();
    if (ev === XML_START_TAG) {
      return tok.name.toLowerCase();
    }
    if (ev === XML_END_DOCUMENT) {
      throw new FeedParseException('Failed to find root node before document end.');
    }
  }
}
