/**
 * LinearizerHelpers.ets —— HtmlLinearizer 的纯函数部分（源 HtmlLinearizer.kt:820-1148 + HtmlToComposable.kt 的
 * stripHtml/ancestors）。从 HtmlLinearizer.ets 拆出以满足单文件 ≤600 行。
 * - getImageSource：srcset/data-responsive → data-img-url/data-src → abs:src → style background-image（HM-A26..A28）
 * - resolveImageUrl：源私有 resolve（java.net.URL + Jsoup 同款 workaround；失败返回 ""）
 * - allIds：自身 + 后代（先序，最多 100 个元素）的非空 id 集合（HM-A34/A35）
 */
import { HtmlNode } from './HtmlNode';
import { LinearElement, LinearImageSource } from './LinearArticle';
import { appendCorrectlyNormalizedWhiteSpace, kotlinIsBlank, kotlinIsWhitespace, LinearTextBuilder } from './LinearTextBuilder';
import { JavaUrl, MalformedURLException } from '../util/JavaCompat';

const LOG_TAG: string = 'FEEDER_LINEARIZER';

/** 源 ListBuilderScope<LinearElement> */
export class ListBuilderScope {
  readonly items: LinearElement[] = [];

  add(item: LinearElement): void {
    this.items.push(item);
  }
}

/** Kotlin String.trim()（Char.isWhitespace 语义） */
export function kotlinTrim(s: string): string {
  let start: number = 0;
  let end: number = s.length;
  while (start < end && kotlinIsWhitespace(s.charCodeAt(start))) {
    start++;
  }
  while (end > start && kotlinIsWhitespace(s.charCodeAt(end - 1))) {
    end--;
  }
  return s.substring(start, end);
}

/** Kotlin String.toIntOrNull()（十进制，可带 +/- 号，Int 范围） */
export function kotlinToIntOrNull(s: string): number | null {
  if (!new RegExp('^[+-]?[0-9]+$').test(s)) {
    return null;
  }
  const v: number = Number(s);
  if (!Number.isFinite(v) || v > 2147483647 || v < -2147483648) {
    return null;
  }
  return v;
}

/** Kotlin String.toFloat()（java.lang.Float.parseFloat，十六进制浮点除外）；非法抛 Error(NumberFormatException) */
export function kotlinToFloat(s: string): number {
  let start: number = 0;
  let end: number = s.length;
  while (start < end && s.charCodeAt(start) <= 32) {
    start++;
  }
  while (end > start && s.charCodeAt(end - 1) <= 32) {
    end--;
  }
  const t: string = s.substring(start, end);
  const m: RegExpExecArray | null =
    new RegExp('^([+-]?)(NaN|Infinity|(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?)[fFdD]?$').exec(t);
  if (m === null || (m[2] === 'NaN' || m[2] === 'Infinity') && t.length !== m[1].length + m[2].length) {
    throw new Error('NumberFormatException: For input string: "' + s + '"');
  }
  if (m[2] === 'NaN') {
    return NaN;
  }
  const v: number = m[2] === 'Infinity' ? Infinity : Number(m[2]);
  return m[1] === '-' ? -v : v;
}

/** Kotlin Float.toInt() */
function floatToInt(v: number): number {
  if (Number.isNaN(v)) {
    return 0;
  }
  if (v >= 2147483647) {
    return 2147483647;
  }
  if (v <= -2147483648) {
    return -2147483648;
  }
  return Math.trunc(v);
}

/** Kotlin substringBefore(delimiter)：未找到返回原串 */
function substringBefore(s: string, delimiter: string): string {
  const i: number = s.indexOf(delimiter);
  return i < 0 ? s : s.substring(0, i);
}

/** `style` 属性 → 声明 Map（split(";") → split(":", limit=2) → trim；后者覆盖前者，≙ associate） */
export function parseStyleDeclarations(style: string): Map<string, string> {
  const out: Map<string, string> = new Map<string, string>();
  const decls: string[] = style.split(';');
  for (let i = 0; i < decls.length; i++) {
    const colon: number = decls[i].indexOf(':');
    if (colon < 0) {
      continue;
    }
    out.set(kotlinTrim(decls[i].substring(0, colon)), kotlinTrim(decls[i].substring(colon + 1)));
  }
  return out;
}

/** 源 ui/compose/text/HtmlToComposable.kt stripHtml：去掉 `<...>` 区间（不解码实体） */
export function stripHtml(html: string): string {
  let result: string = '';
  let skipping: boolean = false;
  let runStart: number = 0;
  for (let i = 0; i < html.length; i++) {
    const ch: string = html.charAt(i);
    if (!skipping) {
      if (ch === '<') {
        result += html.substring(runStart, i);
        skipping = true;
      }
    } else if (ch === '>') {
      skipping = false;
      runStart = i + 1;
    }
  }
  if (!skipping && runStart < html.length) {
    result += html.substring(runStart);
  }
  return result;
}

/**
 * 源 allIds：自身 + 后代元素（先序）取前 100 个，非空 id 的集合。
 */
export function allIds(element: HtmlNode): Set<string> {
  const out: Set<string> = new Set<string>();
  const stack: HtmlNode[] = [element];
  let taken: number = 0;
  while (stack.length > 0 && taken < 100) {
    const n: HtmlNode = stack.pop() as HtmlNode;
    taken++;
    const id: string = n.id();
    if (id.length > 0) {
      out.add(id);
    }
    for (let i = n.children.length - 1; i >= 0; i--) {
      if (n.children[i].isElement()) {
        stack.push(n.children[i]);
      }
    }
  }
  return out;
}

function resolveAgainst(baseUrl: JavaUrl, relUrl: string): JavaUrl {
  // workaround: java resolves '//path/file + ?foo' to '//path/?foo', not '//path/file?foo' as desired
  let base: JavaUrl = baseUrl;
  let rel: string = relUrl;
  if (rel.startsWith('?')) {
    rel = base.path + rel;
  }
  // workaround: //example.com + ./foo = //example.com/./foo, not //example.com/foo
  if (rel.indexOf('.') === 0 && base.file.indexOf('/') !== 0) {
    base = JavaUrl.parse(base.protocol + '://' + base.host + (base.port !== -1 ? ':' + base.port : '') + '/' + base.file);
  }
  return JavaUrl.parse(rel, base);
}

/** 源私有 resolve(baseUrl, relUrl)：base 非法 → rel 自身作为绝对 URL；仍非法 → "" */
export function resolveImageUrl(baseUrl: string, relUrl: string): string {
  try {
    let base: JavaUrl | null = null;
    try {
      base = JavaUrl.parse(baseUrl);
    } catch (e) {
      if (!(e instanceof MalformedURLException)) {
        throw e as Error;
      }
    }
    if (base === null) {
      // the base is unsuitable, but the attribute/rel may be abs on its own, so try that
      return JavaUrl.parse(relUrl).toString();
    }
    return resolveAgainst(base, relUrl).toString();
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return '';
    }
    throw e as Error;
  }
}

function ifBlank(value: string, fallback: string): string {
  return kotlinIsBlank(value) ? fallback : value;
}

function backgroundImageOf(style: string): string {
  if (kotlinIsBlank(style)) {
    return '';
  }
  const decls: string[] = style.split(';');
  for (let i = 0; i < decls.length; i++) {
    const kv: string = kotlinTrim(decls[i]);
    const colon: number = kv.indexOf(':');
    if (colon < 0) {
      continue;
    }
    if (kotlinTrim(kv.substring(0, colon)) === 'background-image') {
      let value: string = kotlinTrim(kv.substring(colon + 1));
      if (value.startsWith('url(\'')) {
        value = value.substring(5);
      }
      if (value.endsWith('\')')) {
        value = value.substring(0, value.length - 2);
      }
      return value;
    }
  }
  return '';
}

function plainSource(url: string): LinearImageSource {
  return new LinearImageSource(url, null, null, null, null);
}

function sizedSource(url: string, width: number | null, height: number | null): LinearImageSource {
  if (width !== null && height !== null) {
    return new LinearImageSource(url, width > 0 ? width : null, height > 0 ? height : null, null, null);
  }
  return plainSource(url);
}

/** 源 getImageSource（HtmlLinearizer.kt:820）；解析中途抛错则返回已收集部分 */
export function getImageSource(baseUrl: string, element: HtmlNode): LinearImageSource[] {
  const absSrc: string = element.attr('abs:src');
  const dataImgUrl: string = ifBlank(element.attr('data-img-url'), element.attr('data-src'));
  const srcSet: string = ifBlank(element.attr('srcset'), element.attr('data-responsive'));
  // Can be set on divs - see ArsTechnica
  const backgroundImage: string = backgroundImageOf(element.attr('style'));

  const result: LinearImageSource[] = [];
  try {
    const items: string[] = srcSet.split(', ');
    for (let i = 0; i < items.length; i++) {
      const candidate: string[] = kotlinTrim(items[i]).split(new RegExp('[ \\t\\n\\x0B\\f\\r]+')).slice(0, 2)
        .map((x: string): string => kotlinTrim(x));
      if (kotlinIsBlank(candidate[0])) {
        continue;
      }
      if (candidate.length === 1) {
        result.push(plainSource(resolveImageUrl(baseUrl, candidate[0])));
        continue;
      }
      const descriptor: string = candidate[candidate.length - 1];
      const lower: string = descriptor.toLowerCase();
      if (lower.endsWith('w')) {
        const width: number = kotlinToFloat(substringBefore(descriptor, 'w'));
        if (width < 0) {
          continue;
        }
        const w: number = floatToInt(width);
        result.push(new LinearImageSource(resolveImageUrl(baseUrl, candidate[0]), null, null, null, w > 0 ? w : null));
      } else if (lower.endsWith('x')) {
        const density: number = kotlinToFloat(substringBefore(descriptor, 'x'));
        if (density < 0) {
          continue;
        }
        result.push(new LinearImageSource(resolveImageUrl(baseUrl, candidate[0]), null, null,
          density > 0 ? density : null, null));
      }
    }

    const width: number | null = kotlinToIntOrNull(element.attr('width'));
    const height: number | null = kotlinToIntOrNull(element.attr('height'));

    if (!kotlinIsBlank(dataImgUrl)) {
      result.push(sizedSource(resolveImageUrl(baseUrl, dataImgUrl), width, height));
    }
    if (!kotlinIsBlank(absSrc)) {
      // inline data images can't be resolved, the result is an empty string
      const url: string = absSrc.startsWith('data:') ? absSrc : resolveImageUrl(baseUrl, absSrc);
      result.push(sizedSource(url, width, height));
    }
    if (!kotlinIsBlank(backgroundImage)) {
      result.push(plainSource(resolveImageUrl(baseUrl, backgroundImage)));
    }
  } catch (e) {
    console.debug(LOG_TAG, 'Failed to parse image source', (e as Error).message);
  }
  return result;
}

function distinctCandidates(nodes: HtmlNode[], baseUrl: string): LinearImageSource[] | null {
  const seen: Set<string> = new Set<string>();
  const out: LinearImageSource[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const sources: LinearImageSource[] = getImageSource(baseUrl, nodes[i]);
    for (let j = 0; j < sources.length; j++) {
      if (!seen.has(sources[j].imgUri)) {
        seen.add(sources[j].imgUri);
        out.push(sources[j]);
      }
    }
  }
  return out.length > 0 ? out : null;
}

/** 后代 img 与 class=image 元素的全部候选（按 URL 去重）；无则 null */
export function descendantImageCandidates(element: HtmlNode, baseUrl: string): LinearImageSource[] | null {
  // Arstechnica is weird and has images inside divs inside figures
  return distinctCandidates(element.getElementsByTag('img').concat(element.getElementsByClass('image')), baseUrl);
}

/** 带 data-src / data-responsive 的祖先的全部候选（按 URL 去重）；无则 null */
export function ancestorImageCandidates(element: HtmlNode, baseUrl: string): LinearImageSource[] | null {
  // Arstechnica is weird and places image details in list items which themselves contain the figure
  return distinctCandidates(element.parents()
    .filter((it: HtmlNode): boolean => it.hasAttr('data-src') || it.hasAttr('data-responsive')), baseUrl);
}

/** 源 isHiddenByCSS：style 同时含子串 `display:` 与 `none` */
export function isHiddenByCSS(element: HtmlNode): boolean {
  const style: string = element.attr('style');
  return style.indexOf('display:') >= 0 && style.indexOf('none') >= 0;
}

/** 源 Element.appendCorrectlyNormalizedWhiteSpaceRecursively（标题文本收集；行内标签不产生注解） */
export function appendCorrectlyNormalizedWhiteSpaceRecursively(element: HtmlNode, builder: LinearTextBuilder): void {
  for (let i = 0; i < element.children.length; i++) {
    const child: HtmlNode = element.children[i];
    if (child.isText()) {
      appendCorrectlyNormalizedWhiteSpace(child.data, builder);
    } else if (child.isElement()) {
      appendCorrectlyNormalizedWhiteSpaceRecursively(child, builder);
    }
  }
}
