/**
 * FeedXmlText.ets —— Feed XML 分词器的文本层：Go encoding/xml 非严格模式的实体解码与换行规范化、
 * xml:base 解析（简化版 Go url.ResolveReference），以及 Feed 原始字节 → 字符串解码
 * （BOM 优先，其次 XML 声明的 encoding（WHATWG 语义：ISO-8859-1/ASCII 族按 windows-1252），默认 UTF-8）。
 */
import { decodeCharset } from '../util/TextCodec';
import { numericReference } from '../html/HtmlEntities';

export function isWs(c: number): boolean {
  return c === 0x20 || c === 0x09 || c === 0x0A || c === 0x0D;
}

export function isNameStart(c: number): boolean {
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c === 0x5F || c === 0x3A || c >= 0x80;
}

/** 名称结束符：空白、'/'、'>'、'='、'<'、引号 */
export function isNameEnd(c: number): boolean {
  return isWs(c) || c === 0x2F || c === 0x3E || c === 0x3D || c === 0x3C || c === 0x22 || c === 0x27;
}

/** `\r\n` / `\r` → `\n` */
export function normalizeNewlines(s: string): string {
  if (s.indexOf('\r') < 0) {
    return s;
  }
  return s.replace(new RegExp('\\r\\n?', 'g'), '\n');
}

/**
 * Go encoding/xml 非严格模式的字符数据实体解码：仅 amp/lt/gt/quot/apos 与数字引用；未知或非法原样保留。
 */
export function decodeXmlEntities(s: string): string {
  let amp: number = s.indexOf('&');
  if (amp < 0) {
    return s;
  }
  let out: string = '';
  let last: number = 0;
  while (amp >= 0) {
    const semi: number = s.indexOf(';', amp + 1);
    let replacement: string | null = null;
    if (semi > amp + 1 && semi - amp <= 12) {
      const name: string = s.substring(amp + 1, semi);
      replacement = xmlEntityValue(name);
    }
    if (replacement !== null) {
      out += s.substring(last, amp) + replacement;
      last = semi + 1;
      amp = s.indexOf('&', last);
    } else {
      amp = s.indexOf('&', amp + 1);
    }
  }
  return out + s.substring(last);
}

function xmlEntityValue(name: string): string | null {
  if (name === 'amp') {
    return '&';
  }
  if (name === 'lt') {
    return '<';
  }
  if (name === 'gt') {
    return '>';
  }
  if (name === 'quot') {
    return '"';
  }
  if (name === 'apos') {
    return '\'';
  }
  if (name.charAt(0) === '#') {
    let cp: number = NaN;
    if (name.length > 2 && name.charAt(1) === 'x') {
      if (new RegExp('^[0-9a-fA-F]+$').test(name.substring(2))) {
        cp = parseInt(name.substring(2), 16);
      }
    } else if (name.length > 1 && new RegExp('^[0-9]+$').test(name.substring(1))) {
      cp = parseInt(name.substring(1), 10);
    }
    if (isNaN(cp) || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) || (cp < 0x20 && cp !== 0x09 && cp !== 0x0A &&
      cp !== 0x0D)) {
      return null;
    }
    return String.fromCodePoint(cp);
  }
  return null;
}

/** 解析 xml:base（相对 parent）。仅做最小语义：绝对 → 原样；相对且 parent 绝对 → RFC3986 合并；否则原样。 */
export function resolveBase(parent: string | null, value: string): string {
  const v: string = value.trim();
  if (parent === null || new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:').test(v)) {
    return v;
  }
  return resolveReference(parent, v);
}

/** 简化版 Go url.ResolveReference（仅用于 xml:base / Atom link 解析） */
export function resolveReference(base: string, ref: string): string {
  if (new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:').test(ref)) {
    return ref;
  }
  const m: RegExpMatchArray | null = base.match(new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*:)?(//[^/?#]*)?([^?#]*)(\\?[^#]*)?'));
  if (m === null) {
    return ref;
  }
  const scheme: string = m[1] !== undefined ? m[1] : '';
  const authority: string = m[2] !== undefined ? m[2] : '';
  const path: string = m[3] !== undefined ? m[3] : '';
  const query: string = m[4] !== undefined ? m[4] : '';
  if (ref.startsWith('//')) {
    return scheme + ref;
  }
  if (ref.length === 0) {
    return scheme + authority + path + query;
  }
  if (ref.startsWith('#')) {
    return scheme + authority + path + query + ref;
  }
  if (ref.startsWith('?')) {
    return scheme + authority + path + ref;
  }
  let merged: string;
  if (ref.startsWith('/')) {
    merged = ref;
  } else {
    const slash: number = path.lastIndexOf('/');
    merged = (slash >= 0 ? path.substring(0, slash + 1) : (authority.length > 0 ? '/' : '')) + ref;
  }
  return scheme + authority + removeDotSegments(merged);
}

function removeDotSegments(pathWithRest: string): string {
  const cut: number = pathWithRest.search(new RegExp('[?#]'));
  const p: string = cut >= 0 ? pathWithRest.substring(0, cut) : pathWithRest;
  const rest: string = cut >= 0 ? pathWithRest.substring(cut) : '';
  const segs: string[] = p.split('/');
  const out: string[] = [];
  for (let i = 0; i < segs.length; i++) {
    const s: string = segs[i];
    if (s === '.') {
      if (i === segs.length - 1) {
        out.push('');
      }
      continue;
    }
    if (s === '..') {
      if (out.length > 1) {
        out.pop();
      }
      if (i === segs.length - 1) {
        out.push('');
      }
      continue;
    }
    out.push(s);
  }
  return out.join('/') + rest;
}

// ---------------------------------------------------------------- 字节解码

const WINDOWS_1252_LABELS: string[] = [
  'iso-8859-1', 'iso8859-1', 'iso_8859-1', 'iso88591', 'latin1', 'l1', 'us-ascii', 'ascii', 'windows-1252',
  'cp1252', 'x-cp1252', 'cp819', 'ibm819', 'iso-ir-100', 'csisolatin1', 'iso_8859-1:1987', 'ansi_x3.4-1968'
];

const UTF8_LABELS: string[] = ['utf-8', 'utf8', 'unicode-1-1-utf-8'];

/** windows-1252 解码（WHATWG：ISO-8859-1 标签按 windows-1252 处理） */
function decodeWindows1252(bytes: Uint8Array, offset: number): string {
  const parts: string[] = [];
  let chunk: string[] = [];
  for (let i = offset; i < bytes.length; i++) {
    const b: number = bytes[i];
    chunk.push(b >= 0x80 && b < 0xA0 ? numericReference(b) : String.fromCharCode(b));
    if (chunk.length >= 8192) {
      parts.push(chunk.join(''));
      chunk = [];
    }
  }
  parts.push(chunk.join(''));
  return parts.join('');
}

function decodeWith(label: string, bytes: Uint8Array): string {
  return decodeCharset(bytes, label);
}

/** 从文档开头的 XML 声明中读取 encoding（ASCII 视图）；无则 null */
export function declaredXmlEncoding(bytes: Uint8Array, offset: number): string | null {
  const limit: number = Math.min(bytes.length, offset + 1024);
  let head: string = '';
  for (let i = offset; i < limit; i++) {
    head += String.fromCharCode(bytes[i]);
  }
  const m: RegExpMatchArray | null =
    head.match(new RegExp('^\\s*<\\?xml[^>]*?\\sencoding\\s*=\\s*["\']([A-Za-z0-9._:\\-]+)["\']'));
  return m !== null ? m[1] : null;
}

/**
 * Feed 原始字节 → 字符串：BOM（UTF-8/UTF-16）优先；否则 XML 声明 encoding；默认 UTF-8。
 * ISO-8859-1 / ASCII 系标签按 windows-1252；UTF-8/UTF-16 纯实现；其它标签交给 util.TextDecoder，未知回落 UTF-8。
 */
export function decodeFeedBytes(buffer: ArrayBuffer): string {
  const bytes: Uint8Array = new Uint8Array(buffer);
  if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
    return decodeWith('utf-8', bytes.subarray(3));
  }
  if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
    return decodeWith('utf-16be', bytes.subarray(2));
  }
  if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
    return decodeWith('utf-16le', bytes.subarray(2));
  }
  const declared: string | null = declaredXmlEncoding(bytes, 0);
  if (declared !== null) {
    const label: string = declared.toLowerCase();
    if (WINDOWS_1252_LABELS.indexOf(label) >= 0) {
      return decodeWindows1252(bytes, 0);
    }
    if (UTF8_LABELS.indexOf(label) < 0) {
      return decodeWith(label, bytes);
    }
  }
  return decodeWith('utf-8', bytes);
}
