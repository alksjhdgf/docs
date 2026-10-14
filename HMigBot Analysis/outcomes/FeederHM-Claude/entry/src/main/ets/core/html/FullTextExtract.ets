/**
 * FullTextExtract.ets —— 源 model/FullTextParser.kt 的纯函数部分（无文件/网络/数据库依赖，可在本地单测直接调用）：
 * parseFullArticle（Readability 抽取 + dir 注入）、findMetaCharset、detectCharset（ICU 统计探测）、toJavaCharset、解码。
 */
import { util } from '@kit.ArkTS';
import { decodeCharset, isPureCharset } from '../util/TextCodec';
import { CharsetMatch, detectAllCharsets } from './CharsetDetector';
import { Readability } from './Readability';
import { ReadabilityArticle } from './ReadabilityMetadata';

/** 源顶层 parseFullArticle(uri, html)：Readability 抽取；有 dir 时注入首个 `<html` */
export function parseFullArticle(uri: string, html: string): string | null {
  const article: ReadabilityArticle = new Readability(uri, html).parse();
  const dir: string | null = article.dir;
  // Ensure dir is set on the outermost element
  const fullHtml: string | null = article.contentWithUtf8Encoding;
  if (fullHtml === null) {
    return null;
  }
  if (dir !== null && dir.trim().length > 0) {
    const i: number = fullHtml.indexOf('<html');
    if (i >= 0) {
      return fullHtml.substring(0, i) + '<html dir="' + dir + '"' + fullHtml.substring(i + 5);
    }
  }
  return fullHtml;
}

// =============================================================================================
// 字符集
// =============================================================================================

enum HtmlParserState {
  INIT,
  TAG_START,
  TAG_NAME,
  TAG_NAME_POST,
  TAG_ATTR_NAME,
  TAG_ATTR_EQUALS,
  TAG_ATTR_QUOTE_START,
  TAG_ATTR_VALUE
}

function nextHtmlParseState(c: string, s: HtmlParserState): HtmlParserState {
  switch (s) {
    case HtmlParserState.INIT:
      return c === '<' ? HtmlParserState.TAG_START : HtmlParserState.INIT;
    case HtmlParserState.TAG_START:
      return c === ' ' || c === '/' ? HtmlParserState.TAG_START :
        (c === '>' ? HtmlParserState.INIT : HtmlParserState.TAG_NAME);
    case HtmlParserState.TAG_NAME:
      return c === ' ' ? HtmlParserState.TAG_NAME_POST : (c === '/' ? HtmlParserState.TAG_START :
        (c === '>' ? HtmlParserState.INIT : HtmlParserState.TAG_NAME));
    case HtmlParserState.TAG_NAME_POST:
      return c === ' ' ? HtmlParserState.TAG_NAME_POST : (c === '/' ? HtmlParserState.TAG_START :
        (c === '>' ? HtmlParserState.INIT : HtmlParserState.TAG_ATTR_NAME));
    case HtmlParserState.TAG_ATTR_NAME:
      return c === ' ' ? HtmlParserState.TAG_NAME_POST : (c === '/' ? HtmlParserState.TAG_START :
        (c === '>' ? HtmlParserState.INIT : (c === '=' ? HtmlParserState.TAG_ATTR_EQUALS : HtmlParserState.TAG_ATTR_NAME)));
    case HtmlParserState.TAG_ATTR_EQUALS:
      return c === ' ' ? HtmlParserState.TAG_ATTR_EQUALS : (c === '/' ? HtmlParserState.TAG_START :
        (c === '>' ? HtmlParserState.INIT : (c === '"' ? HtmlParserState.TAG_ATTR_QUOTE_START : HtmlParserState.TAG_START)));
    case HtmlParserState.TAG_ATTR_QUOTE_START:
      return c === '"' ? HtmlParserState.TAG_NAME_POST : HtmlParserState.TAG_ATTR_VALUE;
    case HtmlParserState.TAG_ATTR_VALUE:
      return c === '"' ? HtmlParserState.TAG_NAME_POST : HtmlParserState.TAG_ATTR_VALUE;
    default:
      return s;
  }
}

/**
 * 源 findMetaCharset（For sites which don't use UTF-8 like http://www.muhasebetr.com/rss/）：
 * 逐字节手写状态机（字节按有符号转 char），仅支持双引号属性值；返回第一个 meta charset /
 * content 中 `charset=` 之后到 ';' 的部分。
 */
export function findMetaCharset(html: Uint8Array): string | null {
  let state: HtmlParserState = HtmlParserState.INIT;
  let tagName: string = '';
  let attrName: string = '';
  let attrValue: string = '';
  for (let i = 0; i < html.length; i++) {
    const b: number = html[i];
    // b.toInt().toChar()：负字节 → 0xFF80..0xFFFF
    const ch: string = String.fromCharCode(b < 128 ? b : (0xFF00 | b));
    state = nextHtmlParseState(ch, state);
    switch (state) {
      case HtmlParserState.TAG_NAME:
        tagName += ch;
        break;
      case HtmlParserState.TAG_ATTR_NAME:
        attrName += ch;
        break;
      case HtmlParserState.TAG_ATTR_VALUE:
        attrValue += ch;
        break;
      case HtmlParserState.TAG_START:
        tagName = '';
        attrName = '';
        attrValue = '';
        break;
      case HtmlParserState.TAG_NAME_POST:
        // This is the state after a attribute has been parsed (but also before)
        if (tagName.toLowerCase() === 'meta') {
          const name: string = attrName.toLowerCase();
          if (name === 'content' && attrValue.indexOf('charset=') >= 0) {
            const after: string = attrValue.substring(attrValue.indexOf('charset=') + 8);
            const semi: number = after.indexOf(';');
            return semi >= 0 ? after.substring(0, semi) : after;
          } else if (name === 'charset') {
            return attrValue;
          }
        }
        attrName = '';
        attrValue = '';
        break;
      default:
        break;
    }
  }
  return null;
}

/**
 * 源 detectCharset（For sites which don't use UTF-8）：ICU CharsetDetector.setText(html).detectAll()，
 * 取第一个置信度 > 50 的候选名。ICU 统计探测由 CharsetDetector.ets 纯 ArkTS 实现。
 */
export function detectCharset(html: Uint8Array): string | null {
  const matches: CharsetMatch[] = detectAllCharsets(html);
  for (let i = 0; i < matches.length; i++) {
    if (matches[i].confidence > 50) {
      return matches[i].name;
    }
  }
  return null;
}

/** 源 toJavaCharset：GB2312→GBK、BIG5-HKSCS→Big5-HKSCS（"Shift-JIS" 分支在源中为死代码，Java 别名本就可用）；不支持抛错 */
export function toJavaCharset(name: string): string {
  const upper: string = name.toUpperCase();
  let label: string = name;
  if (upper === 'GB2312') {
    label = 'gbk';
  } else if (upper === 'BIG5-HKSCS') {
    label = 'big5-hkscs';
  }
  if (!isSupportedCharset(label)) {
    throw new Error('UnsupportedCharsetException: ' + name);
  }
  return label;
}

export function isSupportedCharset(label: string): boolean {
  if (label.trim().length === 0) {
    return false;
  }
  if (isPureCharset(label) || isUtf32Label(label)) {
    return true;
  }
  try {
    util.TextDecoder.create(label.toLowerCase(), { fatal: false, ignoreBOM: true });
    return true;
  } catch (e) {
    return false;
  }
}

/** String(bytes, charset)：不剥离 BOM（与 Java 一致），非法序列替换为 U+FFFD */
export function decodeWithCharset(bytes: Uint8Array, charset: string): string {
  if (isUtf32Label(charset)) {
    return decodeUtf32(bytes, charset.trim().toLowerCase() === 'utf-32le');
  }
  return decodeCharset(bytes, charset);
}

/** UTF-32（探测器可能给出；WHATWG TextDecoder 不支持，自行解码） */
function isUtf32Label(label: string): boolean {
  const l: string = label.trim().toLowerCase();
  return l === 'utf-32' || l === 'utf-32be' || l === 'utf-32le';
}

function decodeUtf32(bytes: Uint8Array, littleEndian: boolean): string {
  const parts: string[] = [];
  let chunk: number[] = [];
  const limit: number = bytes.length - (bytes.length % 4);
  for (let i = 0; i < limit; i += 4) {
    const cp: number = littleEndian ?
      ((bytes[i + 3] * 0x1000000) + (bytes[i + 2] << 16) + (bytes[i + 1] << 8) + bytes[i]) :
      ((bytes[i] * 0x1000000) + (bytes[i + 1] << 16) + (bytes[i + 2] << 8) + bytes[i + 3]);
    chunk.push(cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) ? 0xFFFD : cp);
    if (chunk.length >= 4096) {
      parts.push(String.fromCodePoint(...chunk));
      chunk = [];
    }
  }
  if (limit < bytes.length) {
    chunk.push(0xFFFD);
  }
  if (chunk.length > 0) {
    parts.push(String.fromCodePoint(...chunk));
  }
  return parts.join('');
}
