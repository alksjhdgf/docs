/**
 * ReadabilityCleaner.ets —— Readability 移植的共用工具：正则表、节点遍历、文本/链接密度、预处理（Preprocessor）、
 * 正文清理（prepArticle）、后处理（Postprocessor：相对 URL 绝对化、class 清理）。
 * 算法照 Mozilla Readability.js（readability4j 1.0.x 移植所基于的版本），DOM 为 core/html 自研 DOM。
 * 从 Readability.ets 拆出以满足单文件 ≤600 行。
 */
import { HtmlNode } from './HtmlNode';
import { HtmlDocument } from './HtmlDocument';
import { resolveUrl } from './HtmlUrl';

export const FLAG_STRIP_UNLIKELYS: number = 0x1;
export const FLAG_WEIGHT_CLASSES: number = 0x2;
export const FLAG_CLEAN_CONDITIONALLY: number = 0x4;

export const RE_UNLIKELY_CANDIDATES: RegExp = new RegExp(
  '-ad-|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|foot|header|legends|menu|related|remark|' +
    'replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|' +
    'yom-remote', 'i');
export const RE_OK_MAYBE_CANDIDATE: RegExp = new RegExp('and|article|body|column|main|shadow', 'i');
export const RE_POSITIVE: RegExp =
  new RegExp('article|body|content|entry|hentry|h-entry|main|page|pagination|post|text|blog|story', 'i');
export const RE_NEGATIVE: RegExp = new RegExp(
  'hidden|^hid$| hid$| hid |^hid |banner|combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|' +
    'outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|tool|widget', 'i');
export const RE_BYLINE: RegExp = new RegExp('byline|author|dateline|writtenby|p-author', 'i');
export const RE_VIDEOS: RegExp =
  new RegExp('\\/\\/(www\\.)?(dailymotion|youtube|youtube-nocookie|player\\.vimeo)\\.com', 'i');
export const RE_HAS_CONTENT: RegExp = new RegExp('\\S$');
const RE_SHARE: RegExp = new RegExp('share');
const RE_DISPLAY_NONE: RegExp = new RegExp('display\\s*:\\s*none', 'i');

export const DEFAULT_TAGS_TO_SCORE: Set<string> =
  new Set<string>(['section', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'td', 'pre']);
export const DIV_TO_P_ELEMS: Set<string> =
  new Set<string>(['a', 'blockquote', 'dl', 'div', 'img', 'ol', 'p', 'pre', 'table', 'ul', 'select']);
export const ALTER_TO_DIV_EXCEPTIONS: Set<string> = new Set<string>(['div', 'article', 'section', 'p']);
const PRESENTATIONAL_ATTRIBUTES: string[] = [
  'align', 'background', 'bgcolor', 'border', 'cellpadding', 'cellspacing', 'frame', 'hspace', 'rules', 'style',
  'valign', 'vspace'
];
const DEPRECATED_SIZE_ATTRIBUTE_ELEMS: Set<string> = new Set<string>(['table', 'th', 'td', 'hr', 'pre']);
const PHRASING_ELEMS: Set<string> = new Set<string>([
  'abbr', 'audio', 'b', 'bdo', 'br', 'button', 'cite', 'code', 'data', 'datalist', 'dfn', 'em', 'embed', 'i', 'img',
  'input', 'kbd', 'label', 'mark', 'math', 'meter', 'noscript', 'object', 'output', 'progress', 'q', 'ruby', 'samp',
  'script', 'select', 'small', 'span', 'strong', 'sub', 'sup', 'textarea', 'time', 'var', 'wbr'
]);
/** readability4j Postprocessor.CLASSES_TO_PRESERVE */
export const CLASSES_TO_PRESERVE: string[] = ['readability-styled', 'page'];
export const READABILITY_STYLED: string = 'readability-styled';

// ------------------------------------------------------------------------------------------- 遍历

/** Readability _getNextNode：深度优先下一个元素（ignoreSelfAndKids 时跳过子树） */
export function getNextNode(node: HtmlNode, ignoreSelfAndKids: boolean = false): HtmlNode | null {
  if (!ignoreSelfAndKids) {
    const first: HtmlNode | null = node.firstElementChild();
    if (first !== null) {
      return first;
    }
  }
  const sib: HtmlNode | null = node.nextElementSibling();
  if (sib !== null) {
    return sib;
  }
  let n: HtmlNode | null = node.parent;
  while (n !== null && n.nextElementSibling() === null) {
    n = n.parent;
  }
  return n !== null ? n.nextElementSibling() : null;
}

/** Readability _removeAndGetNext */
export function removeAndGetNext(node: HtmlNode): HtmlNode | null {
  const next: HtmlNode | null = getNextNode(node, true);
  node.remove();
  return next;
}

/** 后代元素（不含自身，文档序） */
export function descendantsByTag(e: HtmlNode, tag: string): HtmlNode[] {
  return e.getElementsByTag(tag).filter((n: HtmlNode): boolean => n !== e);
}

/** readability4j removeNodes：倒序遍历 e.getElementsByTag(tag)（Jsoup：含自身），仍挂在树上且满足条件者移除 */
export function removeNodes(e: HtmlNode, tag: string, filter: ((n: HtmlNode) => boolean) | null): void {
  const nodes: HtmlNode[] = e.getElementsByTag(tag);
  for (let i = nodes.length - 1; i >= 0; i--) {
    const n: HtmlNode = nodes[i];
    if (n.parent !== null && (filter === null || filter(n))) {
      n.remove();
    }
  }
}

export function getNodeAncestors(node: HtmlNode, maxDepth: number = 0): HtmlNode[] {
  const all: HtmlNode[] = node.parents();
  return maxDepth > 0 ? all.slice(0, maxDepth) : all;
}

export function hasAncestorTag(node: HtmlNode, tagName: string, maxDepth: number = 3,
  filterFn: ((n: HtmlNode) => boolean) | null = null): boolean {
  let depth: number = 0;
  let n: HtmlNode = node;
  while (n.parent !== null && n.parent.isElement()) {
    if (maxDepth > 0 && depth > maxDepth) {
      return false;
    }
    const p: HtmlNode = n.parent;
    if (p.tagName() === tagName && (filterFn === null || filterFn(p))) {
      return true;
    }
    n = p;
    depth++;
  }
  return false;
}

// ------------------------------------------------------------------------------------------- 文本

/** readability4j getInnerText：Jsoup text()（已规整空白）并 trim */
export function getInnerText(e: HtmlNode, normalizeSpaces: boolean = true): string {
  const t: string = e.text().trim();
  return normalizeSpaces ? t.replace(new RegExp('\\s{2,}', 'g'), ' ') : t;
}

export function getCharCount(e: HtmlNode, s: string = ','): number {
  return getInnerText(e).split(s).length - 1;
}

export function getLinkDensity(element: HtmlNode): number {
  const textLength: number = getInnerText(element).length;
  if (textLength === 0) {
    return 0;
  }
  let linkLength: number = 0;
  const links: HtmlNode[] = element.getElementsByTag('a');
  for (let i = 0; i < links.length; i++) {
    linkLength += getInnerText(links[i]).length;
  }
  return linkLength / textLength;
}

export function isElementWithoutContent(node: HtmlNode): boolean {
  if (!node.isElement() || node.text().trim().length !== 0) {
    return false;
  }
  const kids: number = node.elementChildren().length;
  return kids === 0 || kids === descendantsByTag(node, 'br').length + descendantsByTag(node, 'hr').length;
}

export function hasSingleTagInsideElement(element: HtmlNode, tag: string): boolean {
  const kids: HtmlNode[] = element.elementChildren();
  if (kids.length !== 1 || kids[0].tagName() !== tag) {
    return false;
  }
  for (let i = 0; i < element.children.length; i++) {
    const c: HtmlNode = element.children[i];
    if (c.isText() && RE_HAS_CONTENT.test(c.data)) {
      return false;
    }
  }
  return true;
}

export function hasChildBlockElement(element: HtmlNode): boolean {
  for (let i = 0; i < element.children.length; i++) {
    const c: HtmlNode = element.children[i];
    if (c.isElement() && (DIV_TO_P_ELEMS.has(c.tagName()) || hasChildBlockElement(c))) {
      return true;
    }
  }
  return false;
}

export function isPhrasingContent(node: HtmlNode): boolean {
  if (node.isText()) {
    return true;
  }
  if (!node.isElement()) {
    return false;
  }
  const tag: string = node.tagName();
  if (PHRASING_ELEMS.has(tag)) {
    return true;
  }
  if (tag === 'a' || tag === 'del' || tag === 'ins') {
    for (let i = 0; i < node.children.length; i++) {
      if (!isPhrasingContent(node.children[i])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

export function isWhitespaceNode(node: HtmlNode): boolean {
  return (node.isText() && node.data.trim().length === 0) || node.nameIs('br');
}

export function isProbablyVisible(node: HtmlNode): boolean {
  return !RE_DISPLAY_NONE.test(node.attr('style')) && !node.hasAttr('hidden');
}

// ------------------------------------------------------------------------------------------- 预处理

/** readability4j Preprocessor.prepareDocument：去 script/noscript/style/注释、合并连续 br 为 p、font→span */
export function prepareDocument(doc: HtmlDocument): void {
  removeNodes(doc, 'script', null);
  removeNodes(doc, 'noscript', null);
  removeNodes(doc, 'style', null);
  const comments: HtmlNode[] = [];
  doc.traverse((n: HtmlNode, _d: number) => {
    if (n.isComment()) {
      comments.push(n);
    }
  });
  for (let i = 0; i < comments.length; i++) {
    comments[i].remove();
  }
  const body: HtmlNode | null = doc.body();
  if (body !== null) {
    replaceBrs(body);
  }
  const fonts: HtmlNode[] = doc.getElementsByTag('font');
  for (let i = 0; i < fonts.length; i++) {
    fonts[i].renameTag('span');
  }
}

function nextNonWhitespace(node: HtmlNode | null): HtmlNode | null {
  let next: HtmlNode | null = node;
  while (next !== null && !next.isElement() && next.isText() && next.data.trim().length === 0) {
    next = next.nextSibling();
  }
  return next;
}

/** 2 个及以上连续 `<br>`（中间空白忽略）替换为单个 `<p>`，其后的短语内容收入该 p */
function replaceBrs(elem: HtmlNode): void {
  const brs: HtmlNode[] = descendantsByTag(elem, 'br');
  for (let b = 0; b < brs.length; b++) {
    const br: HtmlNode = brs[b];
    if (br.parent === null) {
      continue;
    }
    let next: HtmlNode | null = nextNonWhitespace(br.nextSibling());
    let replaced: boolean = false;
    while (next !== null && next.nameIs('br')) {
      replaced = true;
      const brSibling: HtmlNode | null = next.nextSibling();
      next.remove();
      next = nextNonWhitespace(brSibling);
    }
    if (!replaced) {
      continue;
    }
    const p: HtmlNode = HtmlNode.element('p');
    br.replaceWith(p);
    next = p.nextSibling();
    while (next !== null) {
      if (next.nameIs('br')) {
        const nextElem: HtmlNode | null = nextNonWhitespace(next.nextSibling());
        if (nextElem !== null && nextElem.nameIs('br')) {
          break;
        }
      }
      if (!isPhrasingContent(next)) {
        break;
      }
      const sibling: HtmlNode | null = next.nextSibling();
      p.appendChild(next);
      next = sibling;
    }
    while (p.children.length > 0 && isWhitespaceNode(p.children[p.children.length - 1])) {
      p.children[p.children.length - 1].remove();
    }
    if (p.parent !== null && p.parent.nameIs('p')) {
      p.parent.renameTag('div');
    }
  }
}

// ------------------------------------------------------------------------------------------- 清理

export function cleanStyles(e: HtmlNode): void {
  if (!e.isElement() || e.tagName() === 'svg') {
    return;
  }
  const keepStyle: boolean = e.nameIs('p') && e.hasClass(READABILITY_STYLED);
  for (let i = 0; i < PRESENTATIONAL_ATTRIBUTES.length; i++) {
    if (keepStyle && PRESENTATIONAL_ATTRIBUTES[i] === 'style') {
      continue;
    }
    e.removeAttr(PRESENTATIONAL_ATTRIBUTES[i]);
  }
  if (DEPRECATED_SIZE_ATTRIBUTE_ELEMS.has(e.tagName())) {
    e.removeAttr('width');
    e.removeAttr('height');
  }
  const kids: HtmlNode[] = e.elementChildren();
  for (let i = 0; i < kids.length; i++) {
    cleanStyles(kids[i]);
  }
}

class RowCol {
  rows: number = 0;
  columns: number = 0;
}

function parseIntOr1(s: string): number {
  const v: number = parseInt(s, 10);
  return Number.isNaN(v) || v === 0 ? 1 : v;
}

function getRowAndColumnCount(table: HtmlNode): RowCol {
  const rc: RowCol = new RowCol();
  const trs: HtmlNode[] = table.getElementsByTag('tr');
  for (let i = 0; i < trs.length; i++) {
    rc.rows += parseIntOr1(trs[i].attr('rowspan'));
    let columnsInThisRow: number = 0;
    const cells: HtmlNode[] = trs[i].getElementsByTag('td');
    for (let j = 0; j < cells.length; j++) {
      columnsInThisRow += parseIntOr1(cells[j].attr('colspan'));
    }
    rc.columns = Math.max(rc.columns, columnsInThisRow);
  }
  return rc;
}

/** Readability _markDataTables：结果写入 dataTables 集合 */
export function markDataTables(root: HtmlNode, dataTables: Set<HtmlNode>): void {
  const tables: HtmlNode[] = root.getElementsByTag('table');
  for (let i = 0; i < tables.length; i++) {
    const table: HtmlNode = tables[i];
    if (table.attr('role') === 'presentation' || table.attr('datatable') === '0') {
      continue;
    }
    if (table.attr('summary').length > 0) {
      dataTables.add(table);
      continue;
    }
    const caption: HtmlNode[] = descendantsByTag(table, 'caption');
    if (caption.length > 0 && caption[0].children.length > 0) {
      dataTables.add(table);
      continue;
    }
    const dataTableDescendants: string[] = ['col', 'colgroup', 'tfoot', 'thead', 'th'];
    if (dataTableDescendants.some((tag: string): boolean => descendantsByTag(table, tag).length > 0)) {
      dataTables.add(table);
      continue;
    }
    if (descendantsByTag(table, 'table').length > 0) {
      continue;
    }
    const size: RowCol = getRowAndColumnCount(table);
    if (size.rows >= 10 || size.columns > 4 || size.rows * size.columns > 10) {
      dataTables.add(table);
    }
  }
}

/** Readability _clean：移除标签（object/embed/iframe 保留视频嵌入） */
export function cleanTag(e: HtmlNode, tag: string): void {
  const isEmbed: boolean = tag === 'object' || tag === 'embed' || tag === 'iframe';
  removeNodes(e, tag, (element: HtmlNode): boolean => {
    if (isEmbed) {
      const values: string[] = [];
      element.attrs.forEach((v: string, _k: string) => {
        values.push(v);
      });
      if (RE_VIDEOS.test(values.join('|'))) {
        return false;
      }
      if (RE_VIDEOS.test(element.html())) {
        return false;
      }
    }
    return true;
  });
}

/** Readability _cleanMatchedNodes */
export function cleanMatchedNodes(e: HtmlNode, re: RegExp): void {
  const endOfSearchMarkerNode: HtmlNode | null = getNextNode(e, true);
  let next: HtmlNode | null = getNextNode(e);
  while (next !== null && next !== endOfSearchMarkerNode) {
    if (re.test(next.attr('class') + ' ' + next.attr('id'))) {
      next = removeAndGetNext(next);
    } else {
      next = getNextNode(next);
    }
  }
}

export function cleanShareNodes(articleContent: HtmlNode): void {
  const kids: HtmlNode[] = articleContent.elementChildren();
  for (let i = 0; i < kids.length; i++) {
    cleanMatchedNodes(kids[i], RE_SHARE);
  }
}

/** 去掉无内容段落、p 前的 br */
export function removeExtraParagraphs(articleContent: HtmlNode): void {
  removeNodes(articleContent, 'p', (paragraph: HtmlNode): boolean => {
    const total: number = descendantsByTag(paragraph, 'img').length + descendantsByTag(paragraph, 'embed').length +
      descendantsByTag(paragraph, 'object').length + descendantsByTag(paragraph, 'iframe').length;
    return total === 0 && getInnerText(paragraph, false).length === 0;
  });
  const brs: HtmlNode[] = descendantsByTag(articleContent, 'br');
  for (let i = 0; i < brs.length; i++) {
    let next: HtmlNode | null = brs[i].nextSibling();
    while (next !== null && !next.isElement()) {
      if (next.isText() && next.data.trim().length > 0) {
        break;
      }
      next = next.nextSibling();
    }
    if (next !== null && next.nameIs('p')) {
      brs[i].remove();
    }
  }
}

// ------------------------------------------------------------------------------------------- 后处理

/** readability4j Postprocessor.fixRelativeUris：a[href]/img[src]（+ 懒加载 data-src）绝对化；javascript: 链接替换为文本 */
export function fixRelativeUris(articleContent: HtmlNode, baseUri: string): void {
  const toAbsolute = (uri: string): string => {
    if (uri.startsWith('#')) {
      return uri;
    }
    const abs: string = resolveUrl(baseUri, uri);
    return abs.length > 0 ? abs : uri;
  };
  const links: HtmlNode[] = articleContent.getElementsByTag('a');
  for (let i = 0; i < links.length; i++) {
    const link: HtmlNode = links[i];
    const href: string = link.attr('href');
    if (href.length === 0) {
      continue;
    }
    if (href.indexOf('javascript:') === 0) {
      link.replaceWith(HtmlNode.textNode(link.wholeText()));
    } else {
      link.setAttr('href', toAbsolute(href));
    }
  }
  const imgs: HtmlNode[] = articleContent.getElementsByTag('img');
  for (let i = 0; i < imgs.length; i++) {
    const keys: string[] = ['src', 'data-src', 'data-original'];
    for (let k = 0; k < keys.length; k++) {
      const v: string = imgs[i].attr(keys[k]);
      if (v.length > 0 && !v.startsWith('data:')) {
        imgs[i].setAttr(keys[k], toAbsolute(v));
      }
    }
  }
}

/** readability4j Postprocessor.cleanClasses：只保留 CLASSES_TO_PRESERVE 中的 class */
export function cleanClasses(node: HtmlNode): void {
  if (node.hasAttr('class')) {
    const kept: string[] = node.attr('class').split(new RegExp('\\s+'))
      .filter((cls: string): boolean => CLASSES_TO_PRESERVE.indexOf(cls) >= 0);
    if (kept.length > 0) {
      node.setAttr('class', kept.join(' '));
    } else {
      node.removeAttr('class');
    }
  }
  const kids: HtmlNode[] = node.elementChildren();
  for (let i = 0; i < kids.length; i++) {
    cleanClasses(kids[i]);
  }
}
