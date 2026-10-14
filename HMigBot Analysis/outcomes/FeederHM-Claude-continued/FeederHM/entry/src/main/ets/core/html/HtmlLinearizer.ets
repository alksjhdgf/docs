/**
 * HtmlLinearizer.ets —— 源 model/html/HtmlLinearizer.kt：HTML（core/html 自研 DOM）→ LinearArticle（扁平块列表）。
 *
 * 构造 `new HtmlLinearizer(tooLargeText, openInBrowserText, articleLink)`；实例有可变状态
 * （元素/字符计数、截断标志、共享 LinearTextBuilder），**一次 linearize 一个实例**（调用方每次 new）。
 * - 只遍历 `<body>`；任何异常 → 空元素列表（HM-A01/A02）
 * - 限额 MAX_ELEMENTS=2000 / MAX_CHARS=100000，超限截断并追加 tooLarge + openInBrowser（带 articleLink 链接）两段（HM-A03/A04）
 * - 逐标签规则照源（见各 case 注释）；源码怪癖保真（isHiddenByCSS 子串判断、srcset 只按 ", " 切分、
 *   ol 的 start/value 忽略、标题内行内标签不产生注解、resolve 失败得到空 imgUri）。
 */
import { HtmlNode } from './HtmlNode';
import { HtmlDocument } from './HtmlDocument';
import { parseHtml } from './HtmlParser';
import {
  LinearArticle, LinearAudio, LinearAudioSource, LinearBlockQuote, LinearElement, LinearImage, LinearImageSource,
  LinearListItem, LinearTable, LinearTableBuilder, LinearTableCellItem, LinearTableCellItemType, LinearText,
  LinearTextAnnotation, LinearTextAnnotationBold, LinearTextAnnotationCode, LinearTextAnnotationData,
  LinearTextAnnotationFont, LinearTextAnnotationH1, LinearTextAnnotationH2, LinearTextAnnotationH3,
  LinearTextAnnotationH4, LinearTextAnnotationH5, LinearTextAnnotationH6, LinearTextAnnotationItalic,
  LinearTextAnnotationLink, LinearTextAnnotationMonospace, LinearTextAnnotationStrikethrough,
  LinearTextAnnotationSubscript, LinearTextAnnotationSuperscript, LinearTextAnnotationUnderline,
  LinearTextBlockStyle, LinearVideo, LinearVideoSource, shouldSoftWrap
} from './LinearArticle';
import {
  LinearTextBuilder, appendCorrectlyNormalizedWhiteSpace, appendOneNormalizedWhitespace, kotlinIsBlank
} from './LinearTextBuilder';
import {
  ListBuilderScope, allIds, ancestorImageCandidates, appendCorrectlyNormalizedWhiteSpaceRecursively,
  descendantImageCandidates, getImageSource, isHiddenByCSS, kotlinToIntOrNull, parseStyleDeclarations, stripHtml
} from './LinearizerHelpers';
import { Video, getVideo } from '../util/VideoTagHunter';

export { ListBuilderScope, stripHtml, resolveImageUrl, getImageSource } from './LinearizerHelpers';
export { LinearTextBuilder } from './LinearTextBuilder';

const LOG_TAG: string = 'FEEDER_LINEARIZER';

const HEADER_ANNOTATIONS: Map<string, LinearTextAnnotationData> = new Map<string, LinearTextAnnotationData>([
  ['h1', LinearTextAnnotationH1],
  ['h2', LinearTextAnnotationH2],
  ['h3', LinearTextAnnotationH3],
  ['h4', LinearTextAnnotationH4],
  ['h5', LinearTextAnnotationH5],
  ['h6', LinearTextAnnotationH6]
]);

/** 简单行内标签 → 注解（strong/b、i/em/cite/dfn、tt、u、s、sup、sub、code） */
const INLINE_ANNOTATIONS: Map<string, LinearTextAnnotationData> = new Map<string, LinearTextAnnotationData>([
  ['strong', LinearTextAnnotationBold],
  ['b', LinearTextAnnotationBold],
  ['i', LinearTextAnnotationItalic],
  ['em', LinearTextAnnotationItalic],
  ['cite', LinearTextAnnotationItalic],
  ['dfn', LinearTextAnnotationItalic],
  ['tt', LinearTextAnnotationMonospace],
  ['u', LinearTextAnnotationUnderline],
  ['s', LinearTextAnnotationStrikethrough],
  ['sup', LinearTextAnnotationSuperscript],
  ['sub', LinearTextAnnotationSubscript],
  ['code', LinearTextAnnotationCode]
]);

const TABLE_ROW_ORDER: Map<string, number> = new Map<string, number>([
  ['thead', 0],
  ['tbody', 1],
  ['tr', 2],
  ['tfoot', 3]
]);

export class HtmlLinearizer {
  // UI memory use is the primary limit. Limits have been set by testing against https://grapheneos.org/releases
  // where the full page would cause an OOM. 100_000 chars is estimated at around 60 mins of reading time.
  static readonly MAX_ELEMENTS: number = 2000;
  static readonly MAX_CHARS: number = 100000;

  private readonly tooLargeText: string;
  private readonly openInBrowserText: string;
  private readonly articleLink: string;

  private linearTextBuilder: LinearTextBuilder = new LinearTextBuilder();
  private elementCount: number = 0;
  private truncated: boolean = false;
  private charCount: number = 0;

  constructor(tooLargeText: string, openInBrowserText: string, articleLink: string) {
    this.tooLargeText = tooLargeText;
    this.openInBrowserText = openInBrowserText;
    this.articleLink = articleLink;
  }

  linearize(html: string, baseUrl: string): LinearArticle {
    let elements: LinearElement[] = [];
    try {
      const doc: HtmlDocument = parseHtml(html, baseUrl);
      const body: HtmlNode | null = doc.body();
      if (body !== null) {
        elements = this.linearizeBody(body, baseUrl);
      }
    } catch (e) {
      console.error(LOG_TAG, 'htmlFormattingFailed', (e as Error).message);
      elements = [];
    }

    if (this.truncated) {
      elements.push(new LinearText(new Set<string>(), this.tooLargeText, LinearTextBlockStyle.TEXT, []));
      elements.push(new LinearText(new Set<string>(), this.openInBrowserText, LinearTextBlockStyle.TEXT, [
        new LinearTextAnnotation(new LinearTextAnnotationLink(this.articleLink), 0, this.openInBrowserText.length - 1)
      ]));
    }
    return new LinearArticle(elements);
  }

  private linearizeBody(body: HtmlNode, baseUrl: string): LinearElement[] {
    const scope: ListBuilderScope = new ListBuilderScope();
    this.asElement(scope, LinearTextBlockStyle.TEXT, (style: LinearTextBlockStyle) => {
      this.linearizeChildren(scope, body.children, baseUrl, style);
    });
    return scope.items;
  }

  private linearizeChildren(scope: ListBuilderScope, nodes: HtmlNode[], baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    for (let n = 0; n < nodes.length; n++) {
      if (this.truncated) {
        break;
      }
      const node: HtmlNode = nodes[n];
      if (node.isText()) {
        // Keep track of total text size for truncation
        this.charCount += node.data.length;
        if (shouldSoftWrap(blockStyle)) {
          appendCorrectlyNormalizedWhiteSpace(node.data, this.linearTextBuilder);
        } else {
          this.linearTextBuilder.append(node.data);
        }
      } else if (node.isElement()) {
        this.linearizeElement(scope, node, baseUrl, blockStyle);
      }
      // 其它节点（注释、script/style 原文）忽略
    }
  }

  private linearizeElement(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    // Id is used for in-page links（在隐藏检查之前登记）
    this.linearTextBuilder.pushId(element.id());

    if (isHiddenByCSS(element)) {
      // Element is not supposed to be shown because javascript and/or tracking
      return;
    }

    const tag: string = element.tagName();
    const header: LinearTextAnnotationData | undefined = HEADER_ANNOTATIONS.get(tag);
    if (header !== undefined) {
      this.asElement(scope, blockStyle, (_s: LinearTextBlockStyle) => {
        this.withAnnotation(header, () => {
          appendCorrectlyNormalizedWhiteSpaceRecursively(element, this.linearTextBuilder);
        });
      });
      return;
    }
    const inline: LinearTextAnnotationData | undefined = INLINE_ANNOTATIONS.get(tag);
    if (inline !== undefined) {
      this.withAnnotation(inline, () => {
        this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
      });
      return;
    }

    switch (tag) {
      case 'p':
        // Readability4j inserts p-tags in divs for algorithmic purposes. They screw up formatting.
        if (element.hasClass('readability-styled')) {
          this.linearizeChildren(scope, element.children, baseUrl, LinearTextBlockStyle.TEXT);
          // We do need to enforce space after the paragraph though. Sometimes it's missing.
          appendOneNormalizedWhitespace(this.linearTextBuilder);
        } else {
          this.asElement(scope, blockStyle, (_s: LinearTextBlockStyle) => {
            this.linearizeChildren(scope, element.children, baseUrl, LinearTextBlockStyle.TEXT);
          });
        }
        break;
      case 'br':
        this.linearTextBuilder.append('\n');
        break;
      case 'span':
        this.linearizeSpan(scope, element, baseUrl, blockStyle);
        break;
      case 'font': {
        const face: string = element.attr('face');
        if (!kotlinIsBlank(face)) {
          this.withAnnotation(new LinearTextAnnotationFont(face), () => {
            this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
          });
        } else {
          this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
        }
        break;
      }
      case 'pre': {
        const preStyle: LinearTextBlockStyle = element.getElementsByTag('code').length > 0 ?
        LinearTextBlockStyle.CODE_BLOCK : LinearTextBlockStyle.PRE_FORMATTED;
        this.asElement(scope, preStyle, (s: LinearTextBlockStyle) => {
          this.withAnnotation(LinearTextAnnotationMonospace, () => {
            this.linearizeChildren(scope, element.children, baseUrl, s);
          });
        });
        break;
      }
      case 'blockquote':
        this.linearizeBlockQuote(scope, element, baseUrl, blockStyle);
        break;
      case 'a': {
        // abs:href will be blank for mailto: links
        const absHref: string = element.attr('abs:href');
        const href: string = kotlinIsBlank(absHref) ? element.attr('href') : absHref;
        this.withAnnotation(new LinearTextAnnotationLink(href), () => {
          this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
        });
        break;
      }
      case 'figcaption': {
        // If not inside figure then FullTextParsing just failed
        const parent: HtmlNode | null = element.parent;
        if (parent !== null && parent.nameIs('figure')) {
          this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
        }
        break;
      }
      case 'figure':
        this.linearizeFigure(scope, element, baseUrl, blockStyle);
        break;
      case 'img':
        this.linearizeImg(scope, element, baseUrl, blockStyle);
        break;
      case 'ul':
      case 'ol':
        this.linearizeList(scope, element, baseUrl, blockStyle);
        break;
      case 'td':
      case 'th':
        // If we end up here, that means the table has been optimized out. Treat as a div.
        this.asElement(scope, blockStyle, (_s: LinearTextBlockStyle) => {
          this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
        });
        break;
      case 'table':
        this.linearizeTable(scope, element, baseUrl, blockStyle);
        break;
      case 'rt':
      case 'rp':
        // Ruby text elements. Not supported.
        break;
      case 'audio':
        this.linearizeAudio(scope, element);
        break;
      case 'iframe':
        this.finalizeAndAddCurrentElement(scope, blockStyle);
        this.parseIframeVideo(scope, element);
        break;
      case 'video':
        this.linearizeVideo(scope, element);
        break;
      default:
        this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
        break;
    }
  }

  private linearizeSpan(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    const style: Map<string, string> = parseStyleDeclarations(element.attr('style'));
    const maybeBold: LinearTextAnnotationData | null =
      style.get('font-weight') === 'bold' ? LinearTextAnnotationBold : null;
    const fontStyle: string | undefined = style.get('font-style');
    const maybeItalic: LinearTextAnnotationData | null =
      (fontStyle === 'italic' || fontStyle === 'oblique') ? LinearTextAnnotationItalic : null;
    this.withAnnotation(maybeBold, () => {
      this.withAnnotation(maybeItalic, () => {
        this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
      });
    });
  }

  private linearizeBlockQuote(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);

    const citeAttr: string = element.attr('cite');
    const cite: string | null = kotlinIsBlank(citeAttr) ? null : citeAttr;
    // This is not correct. If the blockquote contains elements which will split the blockquote,
    // then ids will be duplicated. This won't crash but in-page links will go to the wrong element
    const ids: Set<string> = allIds(element);

    // Text should be collected into LinearBlockQuote; other types should be added separately
    const inner: ListBuilderScope = new ListBuilderScope();
    this.asElement(inner, LinearTextBlockStyle.TEXT, (_s: LinearTextBlockStyle) => {
      this.linearizeChildren(inner, element.children, baseUrl, LinearTextBlockStyle.TEXT);
    });

    let acc: LinearElement[] = [];
    for (let i = 0; i < inner.items.length; i++) {
      const item: LinearElement = inner.items[i];
      if (item instanceof LinearText) {
        acc.push(item);
      } else {
        if (acc.length > 0) {
          this.addLimited(scope, new LinearBlockQuote(ids, cite, acc));
        }
        this.addLimited(scope, item);
        acc = [];
      }
    }
    if (acc.length > 0) {
      this.addLimited(scope, new LinearBlockQuote(ids, cite, acc));
    }
  }

  private linearizeFigure(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);

    // Some sites put youtube iframes inside figures
    const iframes: HtmlNode[] = element.getElementsByTag('iframe');
    if (iframes.length > 0) {
      this.parseIframeVideo(scope, iframes[0]);
      return;
    }
    const ids: Set<string> = allIds(element);
    // Wordpress likes nested figures to get images side by side
    let imageCandidates: LinearImageSource[] | null = descendantImageCandidates(element, baseUrl);
    if (imageCandidates === null) {
      // Arstechnica has its own ideas about how to structure things
      imageCandidates = ancestorImageCandidates(element, baseUrl);
    }
    if (imageCandidates === null) {
      return;
    }
    const closest: string | null = this.linearTextBuilder.findClosestLink();
    const link: string | null = closest !== null && !kotlinIsBlank(closest) ? closest : null;

    const inner: ListBuilderScope = new ListBuilderScope();
    this.asElement(inner, LinearTextBlockStyle.TEXT, (s: LinearTextBlockStyle) => {
      this.linearizeChildren(inner, element.children, baseUrl, s);
    });
    let caption: LinearText | null = null;
    for (let i = 0; i < inner.items.length; i++) {
      const it: LinearElement = inner.items[i];
      // Stuffing non-text inside a caption is not supported
      if (it instanceof LinearText && !kotlinIsBlank((it as LinearText).text)) {
        caption = it as LinearText;
        break;
      }
    }
    this.addLimited(scope, new LinearImage(ids, imageCandidates, caption, link));
  }

  private linearizeImg(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);

    const ids: Set<string> = allIds(element);
    const candidates: LinearImageSource[] = getImageSource(baseUrl, element);
    if (candidates.length === 0) {
      return;
    }
    const captionText: string = stripHtml(element.attr('alt'));
    // 源把 builder 的活集合作为 caption ids（之后被 clear 修改）；此处取当前快照（差异，台账未登记）
    const caption: LinearText | null = kotlinIsBlank(captionText) ? null :
      new LinearText(new Set<string>(this.linearTextBuilder.ids), captionText, LinearTextBlockStyle.TEXT, []);
    const closest: string | null = this.linearTextBuilder.findClosestLink();
    const link: string | null = closest !== null && !kotlinIsBlank(closest) ? closest : null;
    this.addLimited(scope, new LinearImage(ids, candidates, caption, link));
  }

  private linearizeList(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);

    const ordered: boolean = element.tagName() === 'ol';
    const children: HtmlNode[] = element.elementChildren();
    let index: number = 0;
    for (let i = 0; i < children.length; i++) {
      const listItem: HtmlNode = children[i];
      if (listItem.tagName() !== 'li') {
        continue;
      }
      const inner: ListBuilderScope = new ListBuilderScope();
      this.asElement(inner, blockStyle, (s: LinearTextBlockStyle) => {
        this.linearizeChildren(inner, listItem.children, baseUrl, s);
      });
      const item: LinearListItem = new LinearListItem(allIds(listItem), ordered ? index + 1 : null, inner.items);
      index++;
      if (item.isNotEmpty()) {
        this.addLimited(scope, item);
      }
    }
  }

  private linearizeTable(scope: ListBuilderScope, element: HtmlNode, baseUrl: string,
    blockStyle: LinearTextBlockStyle): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);

    // This can also be auto, but for tables that's equivalent to LTR probably
    const leftToRight: boolean = element.attrInHierarchy('dir') !== 'rtl';
    const ids: Set<string> = allIds(element);

    const sections: HtmlNode[] = element.elementChildren().filter((c: HtmlNode): boolean => TABLE_ROW_ORDER.has(c.tagName()));
    const order: number[] = sections.map((c: HtmlNode): number => TABLE_ROW_ORDER.get(c.tagName()) as number);
    const idx: number[] = sections.map((_c: HtmlNode, i: number): number => i);
    // sortedBy 稳定排序
    idx.sort((a: number, b: number): number => order[a] !== order[b] ? order[a] - order[b] : a - b);
    const rows: HtmlNode[] = [];
    for (let i = 0; i < idx.length; i++) {
      const child: HtmlNode = sections[idx[i]];
      if (child.tagName() === 'tr') {
        rows.push(child);
      } else {
        const trs: HtmlNode[] = child.elementChildren();
        for (let j = 0; j < trs.length; j++) {
          if (trs[j].tagName() === 'tr') {
            rows.push(trs[j]);
          }
        }
      }
    }

    let colCount: number = 0;
    for (let i = 0; i < rows.length; i++) {
      const count: number = HtmlLinearizer.cellsOf(rows[i]).length;
      if (i === 0 || count > colCount) {
        colCount = count;
      }
    }

    // If there is only a single row, or a single column, then don't bother with a table
    if (colCount === 1 || rows.length === 1) {
      this.linearizeChildren(scope, element.children, baseUrl, blockStyle);
      return;
    }
    const table: LinearTable = LinearTable.build(ids, leftToRight, (b: LinearTableBuilder) => {
      for (let r = 0; r < rows.length; r++) {
        b.newRow();
        const cells: HtmlNode[] = HtmlLinearizer.cellsOf(rows[r]);
        for (let c = 0; c < cells.length; c++) {
          const cell: HtmlNode = cells[c];
          const inner: ListBuilderScope = new ListBuilderScope();
          this.asElement(inner, blockStyle, (s: LinearTextBlockStyle) => {
            this.linearizeChildren(inner, cell.children, baseUrl, s);
          });
          b.add(new LinearTableCellItem(
            cell.tagName() === 'th' ? LinearTableCellItemType.HEADER : LinearTableCellItemType.DATA,
            HtmlLinearizer.spanAttr(cell, 'colspan'),
            HtmlLinearizer.spanAttr(cell, 'rowspan'),
            inner.items
          ));
        }
      }
    });
    this.addLimited(scope, table);
  }

  private static cellsOf(row: HtmlNode): HtmlNode[] {
    return row.elementChildren().filter((c: HtmlNode): boolean => c.tagName() === 'td' || c.tagName() === 'th');
  }

  /** `toIntOrNull()?.coerceAtLeast(-1) ?: 1` */
  private static spanAttr(cell: HtmlNode, key: string): number {
    const v: number | null = kotlinToIntOrNull(cell.attr(key));
    return v === null ? 1 : Math.max(v, -1);
  }

  private linearizeAudio(scope: ListBuilderScope, element: HtmlNode): void {
    const sources: LinearAudioSource[] = [];
    const tags: HtmlNode[] = element.getElementsByTag('source');
    for (let i = 0; i < tags.length; i++) {
      const src: string = tags[i].attr('abs:src');
      if (!kotlinIsBlank(src)) {
        const type: string = tags[i].attr('type');
        sources.push(new LinearAudioSource(src, kotlinIsBlank(type) ? null : type));
      }
    }
    if (sources.length > 0) {
      this.addLimited(scope, new LinearAudio(allIds(element), sources));
    }
  }

  private linearizeVideo(scope: ListBuilderScope, element: HtmlNode): void {
    const width: number | null = kotlinToIntOrNull(element.attr('width'));
    const height: number | null = kotlinToIntOrNull(element.attr('height'));
    const sources: LinearVideoSource[] = [];
    const tags: HtmlNode[] = element.getElementsByTag('source');
    for (let i = 0; i < tags.length; i++) {
      const src: string = tags[i].attr('abs:src');
      if (!kotlinIsBlank(src)) {
        const type: string = tags[i].attr('type');
        sources.push(new LinearVideoSource(src, src, null,
          width !== null && width > 0 ? width : null,
          height !== null && height > 0 ? height : null,
          kotlinIsBlank(type) ? null : type));
      }
    }
    if (sources.length > 0) {
      this.addLimited(scope, new LinearVideo(allIds(element), sources));
    }
  }

  private parseIframeVideo(scope: ListBuilderScope, element: HtmlNode): void {
    const width: number | null = kotlinToIntOrNull(element.attr('width'));
    const height: number | null = kotlinToIntOrNull(element.attr('height'));
    const absSrc: string = element.attr('abs:src');
    const video: Video | null = getVideo(kotlinIsBlank(absSrc) ? null : absSrc);
    if (video === null) {
      return;
    }
    const w: number | null = width !== null && width > 0 ? width : (video.width > 0 ? video.width : null);
    const h: number | null = height !== null && height > 0 ? height : (video.height > 0 ? video.height : null);
    this.addLimited(scope, new LinearVideo(allIds(element), [
      new LinearVideoSource(video.src, video.link, video.imageUrl, w, h, null)
    ]));
  }

  private addLimited(scope: ListBuilderScope, element: LinearElement): void {
    if (this.truncated) {
      return;
    }
    this.elementCount++;
    if (this.elementCount > HtmlLinearizer.MAX_ELEMENTS || this.charCount > HtmlLinearizer.MAX_CHARS) {
      this.truncated = true;
      console.warn(LOG_TAG,
        `LinearArticle limits reached. Elements: ${this.elementCount}, Chars: ${this.charCount}. Truncating...`);
      return;
    }
    scope.add(element);
  }

  private finalizeAndAddCurrentElement(scope: ListBuilderScope, blockStyle: LinearTextBlockStyle): void {
    if (this.linearTextBuilder.isNotEmpty()) {
      this.addLimited(scope, this.linearTextBuilder.toLinearText(blockStyle));
      this.linearTextBuilder.clearKeepingSpans();
    }
  }

  private asElement(scope: ListBuilderScope, blockStyle: LinearTextBlockStyle,
    block: (blockStyle: LinearTextBlockStyle) => void): void {
    this.finalizeAndAddCurrentElement(scope, blockStyle);
    block(blockStyle);
    this.finalizeAndAddCurrentElement(scope, blockStyle);
  }

  /** null 时不加注解（span 样式便利） */
  private withAnnotation(annotationData: LinearTextAnnotationData | null, block: () => void): void {
    if (annotationData === null) {
      block();
      return;
    }
    const i: number = this.linearTextBuilder.push(annotationData);
    try {
      block();
    } finally {
      this.linearTextBuilder.popTo(i);
    }
  }
}
