/**
 * HtmlSpeech.ets —— 源 ui/compose/text/HtmlToAnnotatedString.kt + AnnotatedStringComposer.kt + HtmlComposer.kt
 * + AnnotatedString.kt（AnnotatedParagraphStringBuilder）+ HtmlToComposable.kt（空白规范化）的鸿蒙实现。
 *
 * HTML → 段落列表（List<AnnotatedString> 等价物 AnnotatedParagraph[]），用途：
 *  - TTS 朗读文本（ArticleViewModel / FeedViewModel 的朗读入口，HU-A39）；
 *  - AI 摘要显示（Markdown → HTML → 本函数 → RichText.AnnotatedParagraphList，HU-A38）。
 * 不是阅读器正文渲染（正文走 LinearArticle → ArticleBlocks）。
 *
 * 行为（照源，HU-A33..A37）：
 *  - p / h1–h6 / pre / code / blockquote / figure / img / 表格行 为段落边界；空段不产出；
 *    class=readability-styled 的 p 不分段；br → '\n'；
 *  - 可折叠空白（空格/Tab/LF/CR/FF/NBSP）折叠为一个空格，段首可折叠空白去除，ZWNJ 等不可见字符保留；pre 内原样；
 *  - ul → 每个 li 一段 `• ` 前缀；ol → `<i+1>. ` 前缀（源注释说 NBSP，实为普通空格 0x20，照字节保留）；
 *  - table → caption 一段，thead→tbody→tfoot 每个 tr 一段，末尾追加 "\n\n"；rt/rp/iframe/video 忽略；img 不朗读 alt；
 *  - strong/b 粗体、i/em/cite/dfn 斜体、tt/pre/code 等宽、sup/sub 上下标、u/font 无样式；
 *    a → string annotation（tag "URL"，值 abs:href，为空回退原 href）。
 *  - 段落 emit 后按 spanStack 重新 push 仍开着的样式/注解（跨段续接）。
 */
import { HtmlNode, parseHtml, HtmlDocument } from '../../core/html/HtmlParser';
import { isCollapsableWhiteSpaceCode, kotlinIsWhitespace } from '../../core/html/LinearTextBuilder';

// =============================================================================================
// 结果模型（AnnotatedString 等价物）
// =============================================================================================

/** 源 SpanStyle 在本区用到的种类 */
export enum AnnotatedSpanStyle {
  BOLD = 'Bold',
  ITALIC = 'Italic',
  MONOSPACE = 'Monospace',
  SUPERSCRIPT = 'Superscript',
  SUBSCRIPT = 'Subscript'
}

/** 源 AnnotatedString.Range<SpanStyle>：[start, end) */
export class AnnotatedStyleRange {
  readonly style: AnnotatedSpanStyle;
  readonly start: number;
  end: number;

  constructor(style: AnnotatedSpanStyle, start: number, end: number) {
    this.style = style;
    this.start = start;
    this.end = end;
  }
}

/** 源 AnnotatedString.Range<String>（string annotation）：[start, end) */
export class AnnotatedStringAnnotation {
  readonly tag: string;
  readonly value: string;
  readonly start: number;
  end: number;

  constructor(tag: string, value: string, start: number, end: number) {
    this.tag = tag;
    this.value = value;
    this.start = start;
    this.end = end;
  }
}

/** 链接注解 tag（源 withAnnotation("URL", …)） */
export const URL_ANNOTATION_TAG: string = 'URL';

/** 源 AnnotatedString（一个段落） */
export class AnnotatedParagraph {
  readonly text: string;
  readonly styles: AnnotatedStyleRange[];
  readonly annotations: AnnotatedStringAnnotation[];

  constructor(text: string, styles: AnnotatedStyleRange[], annotations: AnnotatedStringAnnotation[]) {
    this.text = text;
    this.styles = styles;
    this.annotations = annotations;
  }

  /** 源 AnnotatedString.getStringAnnotations(tag, start, end)：与 [start, end) 相交的注解 */
  getStringAnnotations(tag: string, start: number, end: number): AnnotatedStringAnnotation[] {
    const out: AnnotatedStringAnnotation[] = [];
    for (let i = 0; i < this.annotations.length; i++) {
      const a: AnnotatedStringAnnotation = this.annotations[i];
      if (a.tag === tag && intersect(start, end, a.start, a.end)) {
        out.push(a);
      }
    }
    return out;
  }

  toString(): string {
    return this.text;
  }
}

/** Compose AnnotatedString intersect 语义（含空区间端点相交） */
function intersect(lStart: number, lEnd: number, rStart: number, rEnd: number): boolean {
  return Math.max(lStart, rStart) < Math.min(lEnd, rEnd) ||
    ((lStart === lEnd || rStart === rEnd) && (lStart === rStart || (lStart <= rStart && rStart <= lEnd) ||
      (rStart <= lStart && lStart <= rEnd)));
}

/** 段落纯文本（TTS 逐段朗读用） */
export function annotatedParagraphTexts(paragraphs: AnnotatedParagraph[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < paragraphs.length; i++) {
    out.push(paragraphs[i].text);
  }
  return out;
}

// =============================================================================================
// AnnotatedParagraphStringBuilder（源 AnnotatedString.kt）
// =============================================================================================

const NBSP_CODE: number = 160;

class OpenItem {
  readonly isStyle: boolean;
  readonly styleRange: AnnotatedStyleRange | null;
  readonly annotation: AnnotatedStringAnnotation | null;

  constructor(styleRange: AnnotatedStyleRange | null, annotation: AnnotatedStringAnnotation | null) {
    this.isStyle = styleRange !== null;
    this.styleRange = styleRange;
    this.annotation = annotation;
  }
}

export class AnnotatedParagraphStringBuilder {
  private parts: string[] = [];
  private len: number = 0;
  /** 末两个 UTF-16 码元，最新在前（源 mLastTwoChars） */
  private lastTwo: number[] = [];
  private styleRanges: AnnotatedStyleRange[] = [];
  private stringAnnotations: AnnotatedStringAnnotation[] = [];
  private openStack: OpenItem[] = [];

  get length(): number {
    return this.len;
  }

  /** 源 endsWithWhitespace：空 → true；末字符为空白或 NBSP → true */
  get endsWithWhitespace(): boolean {
    if (this.lastTwo.length === 0) {
      return true;
    }
    const latest: number = this.lastTwo[0];
    return kotlinIsWhitespace(latest) || latest === NBSP_CODE;
  }

  get endsWithNonBreakingSpace(): boolean {
    if (this.lastTwo.length === 0) {
      return false;
    }
    return this.lastTwo[0] === NBSP_CODE;
  }

  /** 源 isEmpty()：lastTwoChars 为空（不是 length==0） */
  isEmpty(): boolean {
    return this.lastTwo.length === 0;
  }

  private pushMaxTwo(c: number): void {
    this.lastTwo.unshift(c);
    if (this.lastTwo.length > 2) {
      this.lastTwo.pop();
    }
  }

  append(text: string): void {
    if (text.length >= 2) {
      this.pushMaxTwo(text.charCodeAt(text.length - 2));
    }
    if (text.length > 0) {
      this.pushMaxTwo(text.charCodeAt(text.length - 1));
    }
    this.parts.push(text);
    this.len += text.length;
  }

  pushStyle(style: AnnotatedSpanStyle): number {
    const r: AnnotatedStyleRange = new AnnotatedStyleRange(style, this.len, -1);
    this.styleRanges.push(r);
    this.openStack.push(new OpenItem(r, null));
    return this.openStack.length - 1;
  }

  pushStringAnnotation(tag: string, value: string): number {
    const a: AnnotatedStringAnnotation = new AnnotatedStringAnnotation(tag, value, this.len, -1);
    this.stringAnnotations.push(a);
    this.openStack.push(new OpenItem(null, a));
    return this.openStack.length - 1;
  }

  /** 源 AnnotatedString.Builder.pop(index)：弹出 index 及其上方全部 */
  pop(index: number): void {
    if (index >= this.openStack.length) {
      throw new Error(index + ' should be less than ' + this.openStack.length);
    }
    while (this.openStack.length - 1 >= index) {
      const item: OpenItem = this.openStack.pop() as OpenItem;
      if (item.styleRange !== null) {
        item.styleRange.end = this.len;
      }
      if (item.annotation !== null) {
        item.annotation.end = this.len;
      }
    }
  }

  toAnnotatedParagraph(): AnnotatedParagraph {
    const text: string = this.parts.join('');
    const styles: AnnotatedStyleRange[] = [];
    for (let i = 0; i < this.styleRanges.length; i++) {
      const r: AnnotatedStyleRange = this.styleRanges[i];
      styles.push(new AnnotatedStyleRange(r.style, r.start, r.end < 0 ? this.len : r.end));
    }
    const anns: AnnotatedStringAnnotation[] = [];
    for (let i = 0; i < this.stringAnnotations.length; i++) {
      const a: AnnotatedStringAnnotation = this.stringAnnotations[i];
      anns.push(new AnnotatedStringAnnotation(a.tag, a.value, a.start, a.end < 0 ? this.len : a.end));
    }
    return new AnnotatedParagraph(text, styles, anns);
  }
}

// =============================================================================================
// HtmlParser / AnnotatedStringComposer（源 HtmlComposer.kt + AnnotatedStringComposer.kt）
// =============================================================================================

/** 源 sealed class Span（本区只有 SpanWithStyle / SpanWithAnnotation 有生产者） */
class SpanEntry {
  readonly style: AnnotatedSpanStyle | null;
  readonly tag: string;
  readonly annotation: string;

  constructor(style: AnnotatedSpanStyle | null, tag: string, annotation: string) {
    this.style = style;
    this.tag = tag;
    this.annotation = annotation;
  }
}

export class AnnotatedStringComposer {
  private spanStack: SpanEntry[] = [];
  /** 身份会在 emit 后变化——块内不要缓存引用 */
  private builder: AnnotatedParagraphStringBuilder = new AnnotatedParagraphStringBuilder();
  readonly result: AnnotatedParagraph[] = [];

  get endsWithWhitespace(): boolean {
    return this.builder.endsWithWhitespace;
  }

  isEmpty(): boolean {
    return this.builder.isEmpty();
  }

  append(text: string): void {
    this.builder.append(text);
  }

  appendCodePoint(codePoint: number): void {
    this.builder.append(String.fromCodePoint(codePoint));
  }

  /** 返回是否产出了段落 */
  emitParagraph(): boolean {
    // List items emit dots and non-breaking space. Don't newline after that
    if (this.builder.isEmpty() || this.builder.endsWithNonBreakingSpace) {
      return false;
    }
    this.result.push(this.builder.toAnnotatedParagraph());
    this.resetAfterEmit();
    return true;
  }

  appendTable(block: () => void): void {
    this.emitParagraph();
    block();
  }

  private resetAfterEmit(): void {
    this.builder = new AnnotatedParagraphStringBuilder();
    for (let i = 0; i < this.spanStack.length; i++) {
      const span: SpanEntry = this.spanStack[i];
      if (span.style !== null) {
        this.builder.pushStyle(span.style);
      } else {
        this.builder.pushStringAnnotation(span.tag, span.annotation);
      }
    }
  }

  withParagraph(block: () => void): void {
    this.emitParagraph();
    block();
    this.emitParagraph();
  }

  withStyle(style: AnnotatedSpanStyle, block: () => void): void {
    this.spanStack.push(new SpanEntry(style, '', ''));
    const index: number = this.builder.pushStyle(style);
    try {
      block();
    } finally {
      this.builder.pop(index);
      this.spanStack.pop();
    }
  }

  withAnnotation(tag: string, annotation: string, block: () => void): void {
    this.spanStack.push(new SpanEntry(null, tag, annotation));
    const index: number = this.builder.pushStringAnnotation(tag, annotation);
    try {
      block();
    } finally {
      this.builder.pop(index);
      this.spanStack.pop();
    }
  }
}

// =============================================================================================
// 空白规范化（源 HtmlToComposable.kt）
// =============================================================================================

/**
 * 源 TextNode.appendCorrectlyNormalizedWhiteSpace：按码点遍历原始文本（不用 text() 以保留 ZWNJ 等不可见字符），
 * 空 builder 且 stripLeading 时丢弃可折叠空白；可折叠空白折叠为一个空格（已以空白结尾则不加）。
 */
export function appendCorrectlyNormalizedWhiteSpace(wholeText: string, composer: AnnotatedStringComposer,
  stripLeading: boolean): void {
  let i: number = 0;
  while (i < wholeText.length) {
    const cp: number = wholeText.codePointAt(i) as number;
    i += cp > 0xFFFF ? 2 : 1;
    if (composer.isEmpty() && stripLeading && isCollapsableWhiteSpaceCode(cp)) {
      continue;
    }
    if (isCollapsableWhiteSpaceCode(cp)) {
      if (!composer.endsWithWhitespace) {
        composer.append(' ');
      }
    } else {
      composer.appendCodePoint(cp);
    }
  }
}

/** 源 Element.appendCorrectlyNormalizedWhiteSpaceRecursively：只取后代文本节点 */
export function appendCorrectlyNormalizedWhiteSpaceRecursively(element: HtmlNode, composer: AnnotatedStringComposer,
  stripLeading: boolean): void {
  for (let i = 0; i < element.children.length; i++) {
    const child: HtmlNode = element.children[i];
    if (child.isText()) {
      appendCorrectlyNormalizedWhiteSpace(child.wholeText(), composer, stripLeading);
    } else if (child.isElement()) {
      appendCorrectlyNormalizedWhiteSpaceRecursively(child, composer, stripLeading);
    }
  }
}

// =============================================================================================
// HTML → 段落（源 HtmlToAnnotatedString.kt）
// =============================================================================================

/**
 * 源 htmlToAnnotatedString(InputStream, baseUrl)：Jsoup.parse(stream, null, baseUrl)。
 * 鸿蒙侧调用方先把字节解码为字符串（编码探测属调用方/读文件处），本函数以 baseUrl 解析相对链接。
 */
export function htmlToAnnotatedString(html: string, baseUrl: string): AnnotatedParagraph[] {
  return formatBody(parseHtml(html, baseUrl), baseUrl);
}

/** 源 htmlStringToAnnotatedString(html, baseUrl="")：Jsoup.parse(html)（不带 baseUri，相对 abs:href 为空回退原 href） */
export function htmlStringToAnnotatedString(html: string, baseUrl: string = ''): AnnotatedParagraph[] {
  return formatBody(parseHtml(html), baseUrl);
}

function formatBody(doc: HtmlDocument, baseUrl: string): AnnotatedParagraph[] {
  const body: HtmlNode | null = doc.body();
  if (body === null) {
    return [];
  }
  const composer: AnnotatedStringComposer = new AnnotatedStringComposer();
  appendTextChildren(composer, body.children, false, baseUrl);
  composer.emitParagraph();
  return composer.result;
}

function isHeaderTag(tag: string): boolean {
  return tag === 'h1' || tag === 'h2' || tag === 'h3' || tag === 'h4' || tag === 'h5' || tag === 'h6';
}

function tableSectionOrder(tag: string): number {
  if (tag === 'thead') {
    return 0;
  }
  if (tag === 'tbody') {
    return 1;
  }
  if (tag === 'tfoot') {
    return 10;
  }
  return 2;
}

function childrenWithTag(element: HtmlNode, tag: string): HtmlNode[] {
  const out: HtmlNode[] = [];
  const kids: HtmlNode[] = element.elementChildren();
  for (let i = 0; i < kids.length; i++) {
    if (kids[i].tagName() === tag) {
      out.push(kids[i]);
    }
  }
  return out;
}

function appendTable(c: AnnotatedStringComposer, element: HtmlNode, baseUrl: string): void {
  c.appendTable(() => {
    // optionally a caption element, colgroups, thead, tbody* or tr+, tfoot
    const captions: HtmlNode[] = childrenWithTag(element, 'caption');
    for (let i = 0; i < captions.length; i++) {
      appendTextChildren(c, captions[i].children, false, baseUrl);
      c.emitParagraph();
    }
    const sections: HtmlNode[] = [];
    const kids: HtmlNode[] = element.elementChildren();
    for (let i = 0; i < kids.length; i++) {
      const t: string = kids[i].tagName();
      if (t === 'thead' || t === 'tbody' || t === 'tfoot') {
        sections.push(kids[i]);
      }
    }
    // Kotlin sortedBy 为稳定排序；插入排序保持稳定
    const sorted: HtmlNode[] = [];
    for (let i = 0; i < sections.length; i++) {
      const order: number = tableSectionOrder(sections[i].tagName());
      let pos: number = sorted.length;
      while (pos > 0 && tableSectionOrder(sorted[pos - 1].tagName()) > order) {
        pos--;
      }
      sorted.splice(pos, 0, sections[i]);
    }
    for (let s = 0; s < sorted.length; s++) {
      const rows: HtmlNode[] = childrenWithTag(sorted[s], 'tr');
      for (let r = 0; r < rows.length; r++) {
        appendTextChildren(c, rows[r].children, false, baseUrl);
        c.emitParagraph();
      }
    }
    // This is just for TTS so newlines are fine
    c.append('\n\n');
  });
}

function appendElement(c: AnnotatedStringComposer, element: HtmlNode, preFormatted: boolean, baseUrl: string): void {
  const tag: string = element.tagName();
  if (tag === 'p') {
    c.emitParagraph();
    // Readability4j inserts p-tags in divs for algorithmic purposes. They screw up formatting.
    if (element.hasClass('readability-styled')) {
      appendTextChildren(c, element.children, false, baseUrl);
    } else {
      c.withParagraph(() => {
        appendTextChildren(c, element.children, false, baseUrl);
      });
    }
    c.emitParagraph();
  } else if (tag === 'br') {
    c.append('\n');
  } else if (isHeaderTag(tag)) {
    c.emitParagraph();
    c.withParagraph(() => {
      appendCorrectlyNormalizedWhiteSpaceRecursively(element, c, c.endsWithWhitespace);
    });
    c.emitParagraph();
  } else if (tag === 'strong' || tag === 'b') {
    c.withStyle(AnnotatedSpanStyle.BOLD, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'i' || tag === 'em' || tag === 'cite' || tag === 'dfn') {
    c.withStyle(AnnotatedSpanStyle.ITALIC, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'tt') {
    c.withStyle(AnnotatedSpanStyle.MONOSPACE, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'u' || tag === 'font') {
    appendTextChildren(c, element.children, false, baseUrl);
  } else if (tag === 'sup') {
    c.withStyle(AnnotatedSpanStyle.SUPERSCRIPT, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'sub') {
    c.withStyle(AnnotatedSpanStyle.SUBSCRIPT, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'pre') {
    c.emitParagraph();
    c.withStyle(AnnotatedSpanStyle.MONOSPACE, () => {
      appendTextChildren(c, element.children, true, baseUrl);
    });
    c.emitParagraph();
  } else if (tag === 'code') {
    c.emitParagraph();
    c.withStyle(AnnotatedSpanStyle.MONOSPACE, () => {
      appendTextChildren(c, element.children, preFormatted, baseUrl);
    });
    c.emitParagraph();
  } else if (tag === 'blockquote') {
    c.emitParagraph();
    c.withParagraph(() => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
    c.emitParagraph();
  } else if (tag === 'a') {
    // abs:href will be blank for mailto: links
    const abs: string = element.attr('abs:href');
    const href: string = abs.trim().length === 0 ? element.attr('href') : abs;
    c.withAnnotation(URL_ANNOTATION_TAG, href, () => {
      appendTextChildren(c, element.children, false, baseUrl);
    });
  } else if (tag === 'figure' || tag === 'img') {
    c.emitParagraph();
  } else if (tag === 'ul') {
    const items: HtmlNode[] = childrenWithTag(element, 'li');
    for (let i = 0; i < items.length; i++) {
      const li: HtmlNode = items[i];
      c.withParagraph(() => {
        // 源注释写 "no break space"，实际字节为普通空格
        c.append('• ');
        appendTextChildren(c, li.children, false, baseUrl);
      });
    }
  } else if (tag === 'ol') {
    const items: HtmlNode[] = childrenWithTag(element, 'li');
    for (let i = 0; i < items.length; i++) {
      const li: HtmlNode = items[i];
      const n: number = i + 1;
      c.withParagraph(() => {
        c.append(n + '. ');
        appendTextChildren(c, li.children, false, baseUrl);
      });
    }
  } else if (tag === 'table') {
    appendTable(c, element, baseUrl);
  } else if (tag === 'rt' || tag === 'rp' || tag === 'iframe' || tag === 'video') {
    // Ruby 注音 / iframe / video：TTS 不需要，忽略
  } else {
    appendTextChildren(c, element.children, preFormatted, baseUrl);
  }
}

function appendTextChildren(c: AnnotatedStringComposer, nodes: HtmlNode[], preFormatted: boolean,
  baseUrl: string): void {
  for (let i = 0; i < nodes.length; i++) {
    const node: HtmlNode = nodes[i];
    if (node.isText()) {
      if (preFormatted) {
        c.append(node.wholeText());
      } else {
        appendCorrectlyNormalizedWhiteSpace(node.wholeText(), c, c.endsWithWhitespace);
      }
    } else if (node.isElement()) {
      appendElement(c, node, preFormatted, baseUrl);
    }
    // DataNode（script/style 原文）与注释：源 when 只处理 TextNode / Element，忽略
  }
}
