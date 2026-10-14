/**
 * HtmlNode.ets —— 自研 DOM（替代 Jsoup nodes.*，全工程唯一）。
 *
 * 一个类表示全部节点种类（nodeType 区分）：
 *  - ELEMENT：tag 为小写标签名，attrs 为属性（键小写，插入序，首个重复属性生效）
 *  - TEXT：data 为已解码文本（≙ Jsoup TextNode.getWholeText；CDATA 段也作为 TEXT）
 *  - DATA：script/style 原文（≙ Jsoup DataNode）
 *  - COMMENT：data 为注释内容
 *  - DOCUMENT：HtmlDocument（根）
 * 字段 children 为全部子节点（≙ Jsoup childNodes）；仅元素子节点用 elementChildren()（≙ Jsoup children()）。
 * text()/ownText()/wholeText()/attr('abs:x')/absUrl 语义照 Jsoup。
 */
import {
  BLOCK_TAGS,
  NODE_COMMENT,
  NODE_DATA,
  NODE_DOCUMENT,
  NODE_ELEMENT,
  NODE_TEXT,
  PRESERVE_WS_TAGS,
  VOID_TAGS,
  appendNormalisedWhitespace,
  escapeHtmlText,
  isHtmlWhitespace,
  javaTrim,
  TextAccum
} from './HtmlChars';
import { resolveUrl } from './HtmlUrl';

export type NodeVisitor = (node: HtmlNode, depth: number) => void;

export class HtmlNode {
  nodeType: number;
  /** 元素：小写标签名；其它：'#text' / '#data' / '#comment' / '#document' */
  tag: string;
  attrs: Map<string, string> = new Map<string, string>();
  children: HtmlNode[] = [];
  /** TEXT/DATA/COMMENT 的原文（TEXT 已实体解码） */
  data: string = '';
  parent: HtmlNode | null = null;
  /** 仅文档根使用：baseUri（HtmlDocument.location 的存储） */
  docLocation: string = '';

  constructor(nodeType: number, tag: string, data: string = '') {
    this.nodeType = nodeType;
    this.tag = tag;
    this.data = data;
  }

  static element(tag: string): HtmlNode {
    return new HtmlNode(NODE_ELEMENT, tag.toLowerCase());
  }

  static textNode(text: string): HtmlNode {
    return new HtmlNode(NODE_TEXT, '#text', text);
  }

  static dataNode(text: string): HtmlNode {
    return new HtmlNode(NODE_DATA, '#data', text);
  }

  static commentNode(text: string): HtmlNode {
    return new HtmlNode(NODE_COMMENT, '#comment', text);
  }

  isElement(): boolean {
    return this.nodeType === NODE_ELEMENT;
  }

  isText(): boolean {
    return this.nodeType === NODE_TEXT;
  }

  isData(): boolean {
    return this.nodeType === NODE_DATA;
  }

  isComment(): boolean {
    return this.nodeType === NODE_COMMENT;
  }

  tagName(): string {
    return this.tag;
  }

  nameIs(tag: string): boolean {
    return this.nodeType === NODE_ELEMENT && this.tag === tag;
  }

  /** Jsoup Tag.isBlock */
  isBlock(): boolean {
    return this.nodeType === NODE_ELEMENT && BLOCK_TAGS.has(this.tag);
  }

  hasAttr(key: string): boolean {
    const k: string = key.toLowerCase();
    if (k.startsWith('abs:')) {
      const real: string = k.substring(4);
      return this.attrs.has(real) && this.absUrl(real).length > 0;
    }
    return this.attrs.has(k);
  }

  /** Jsoup attr：缺失返回 ''；`abs:` 前缀返回绝对 URL（无法解析为 ''） */
  attr(key: string): string {
    const k: string = key.toLowerCase();
    const v: string | undefined = this.attrs.get(k);
    if (v !== undefined) {
      return v;
    }
    if (k.startsWith('abs:')) {
      return this.absUrl(k.substring(4));
    }
    return '';
  }

  setAttr(key: string, value: string): HtmlNode {
    this.attrs.set(key.toLowerCase(), value);
    return this;
  }

  removeAttr(key: string): HtmlNode {
    this.attrs.delete(key.toLowerCase());
    return this;
  }

  /** Jsoup Element.absUrl：属性缺失 → ''；否则按 baseUri 解析（StringUtil.resolve 语义） */
  absUrl(key: string): string {
    const v: string | undefined = this.attrs.get(key.toLowerCase());
    if (v === undefined) {
      return '';
    }
    return resolveUrl(this.baseUri(), v);
  }

  baseUri(): string {
    const r: HtmlNode = this.root();
    return r.nodeType === NODE_DOCUMENT ? r.docLocation : '';
  }

  /** 最顶层祖先（解析产物为文档根） */
  root(): HtmlNode {
    let n: HtmlNode = this;
    while (n.parent !== null) {
      n = n.parent;
    }
    return n;
  }

  id(): string {
    return this.attr('id');
  }

  className(): string {
    return javaTrim(this.attr('class'));
  }

  classNames(): string[] {
    const out: string[] = [];
    const parts: string[] = this.attr('class').split(new RegExp('[ \\t\\n\\r\\f]+'));
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0 && out.indexOf(parts[i]) < 0) {
        out.push(parts[i]);
      }
    }
    return out;
  }

  /** Jsoup hasClass：忽略大小写 */
  hasClass(cls: string): boolean {
    const want: string = cls.toLowerCase();
    const names: string[] = this.classNames();
    for (let i = 0; i < names.length; i++) {
      if (names[i].toLowerCase() === want) {
        return true;
      }
    }
    return false;
  }

  /** 沿祖先链取第一个非空属性（Linearizer attrInHierarchy 用） */
  attrInHierarchy(key: string): string {
    let n: HtmlNode | null = this;
    while (n !== null) {
      if (n.isElement()) {
        const v: string = n.attr(key);
        if (v.length > 0) {
          return v;
        }
      }
      n = n.parent;
    }
    return '';
  }

  elementChildren(): HtmlNode[] {
    const out: HtmlNode[] = [];
    for (let i = 0; i < this.children.length; i++) {
      if (this.children[i].nodeType === NODE_ELEMENT) {
        out.push(this.children[i]);
      }
    }
    return out;
  }

  siblingIndex(): number {
    return this.parent === null ? 0 : this.parent.children.indexOf(this);
  }

  elementSiblingIndex(): number {
    return this.parent === null ? 0 : this.parent.elementChildren().indexOf(this);
  }

  nextSibling(): HtmlNode | null {
    if (this.parent === null) {
      return null;
    }
    const i: number = this.siblingIndex();
    return i + 1 < this.parent.children.length ? this.parent.children[i + 1] : null;
  }

  previousSibling(): HtmlNode | null {
    if (this.parent === null) {
      return null;
    }
    const i: number = this.siblingIndex();
    return i > 0 ? this.parent.children[i - 1] : null;
  }

  nextElementSibling(): HtmlNode | null {
    let n: HtmlNode | null = this.nextSibling();
    while (n !== null && !n.isElement()) {
      n = n.nextSibling();
    }
    return n;
  }

  previousElementSibling(): HtmlNode | null {
    let n: HtmlNode | null = this.previousSibling();
    while (n !== null && !n.isElement()) {
      n = n.previousSibling();
    }
    return n;
  }

  firstElementChild(): HtmlNode | null {
    for (let i = 0; i < this.children.length; i++) {
      if (this.children[i].isElement()) {
        return this.children[i];
      }
    }
    return null;
  }

  /** 祖先元素（由近到远，不含 document） */
  parents(): HtmlNode[] {
    const out: HtmlNode[] = [];
    let n: HtmlNode | null = this.parent;
    while (n !== null && n.isElement()) {
      out.push(n);
      n = n.parent;
    }
    return out;
  }

  /** 迭代式深度优先遍历（head 先序、tail 后序），避免深层嵌套栈溢出 */
  traverse(head: NodeVisitor, tail: NodeVisitor | null = null): void {
    const stack: HtmlNode[] = [this];
    const depths: number[] = [0];
    const visited: boolean[] = [false];
    while (stack.length > 0) {
      const top: number = stack.length - 1;
      const node: HtmlNode = stack[top];
      const depth: number = depths[top];
      if (!visited[top]) {
        visited[top] = true;
        head(node, depth);
        for (let i = node.children.length - 1; i >= 0; i--) {
          stack.push(node.children[i]);
          depths.push(depth + 1);
          visited.push(false);
        }
      } else {
        stack.pop();
        depths.pop();
        visited.pop();
        if (tail !== null) {
          tail(node, depth);
        }
      }
    }
  }

  /** 自身及全部后代元素（文档序） */
  allElements(): HtmlNode[] {
    const out: HtmlNode[] = [];
    this.traverse((n: HtmlNode, _d: number) => {
      if (n.isElement()) {
        out.push(n);
      }
    });
    return out;
  }

  /** Jsoup getElementsByTag（含自身） */
  getElementsByTag(tag: string): HtmlNode[] {
    const want: string = tag.toLowerCase();
    const out: HtmlNode[] = [];
    this.traverse((n: HtmlNode, _d: number) => {
      if (n.isElement() && n.tag === want) {
        out.push(n);
      }
    });
    return out;
  }

  getElementsByClass(cls: string): HtmlNode[] {
    const out: HtmlNode[] = [];
    this.traverse((n: HtmlNode, _d: number) => {
      if (n.isElement() && n.hasClass(cls)) {
        out.push(n);
      }
    });
    return out;
  }

  getElementById(idValue: string): HtmlNode | null {
    const all: HtmlNode[] = this.allElements();
    for (let i = 0; i < all.length; i++) {
      if (all[i].attr('id') === idValue) {
        return all[i];
      }
    }
    return null;
  }

  /** Jsoup TextNode.isBlank */
  isBlank(): boolean {
    for (let i = 0; i < this.data.length; i++) {
      if (!isHtmlWhitespace(this.data.charCodeAt(i))) {
        return false;
      }
    }
    return true;
  }

  /** 文本节点的父链 6 层内是否有 pre 等（Jsoup Element.preserveWhitespace） */
  static preserveWhitespace(node: HtmlNode | null): boolean {
    let n: HtmlNode | null = node;
    let i: number = 0;
    while (n !== null && i < 6) {
      if (n.isElement() && PRESERVE_WS_TAGS.has(n.tag)) {
        return true;
      }
      n = n.parent;
      i++;
    }
    return false;
  }

  /** Jsoup Element.text()：后代文本规整空白，块元素/br 处补空格，结果 trim（迭代遍历，按下标取兄弟） */
  text(): string {
    if (this.nodeType === NODE_TEXT) {
      return javaTrim(appendNormalisedWhitespace('', this.data, false));
    }
    const acc: TextAccum = new TextAccum();
    const nodes: HtmlNode[] = [this];
    const idx: number[] = [0];
    while (nodes.length > 0) {
      const top: number = nodes.length - 1;
      const node: HtmlNode = nodes[top];
      const i: number = idx[top];
      if (i < node.children.length) {
        idx[top] = i + 1;
        const child: HtmlNode = node.children[i];
        if (child.nodeType === NODE_TEXT) {
          acc.addText(child.data, HtmlNode.preserveWhitespace(child.parent));
        } else if (child.nodeType === NODE_ELEMENT) {
          if (acc.size > 0 && (child.isBlock() || child.tag === 'br') && !acc.endsWithSpace()) {
            acc.add(' ');
          }
          nodes.push(child);
          idx.push(0);
        }
        continue;
      }
      nodes.pop();
      idx.pop();
      if (top > 0 && node.isBlock()) {
        const p: HtmlNode = nodes[top - 1];
        const ni: number = idx[top - 1];
        const next: HtmlNode | null = ni < p.children.length ? p.children[ni] : null;
        if (next !== null && (next.nodeType === NODE_TEXT || (next.isElement() && !next.isBlock())) &&
          !acc.endsWithSpace()) {
          acc.add(' ');
        }
      }
    }
    return javaTrim(acc.toString());
  }

  /** Jsoup Element.ownText()：仅直接子文本节点（br 补空格） */
  ownText(): string {
    const acc: TextAccum = new TextAccum();
    for (let i = 0; i < this.children.length; i++) {
      const c: HtmlNode = this.children[i];
      if (c.nodeType === NODE_TEXT) {
        acc.addText(c.data, HtmlNode.preserveWhitespace(c.parent));
      } else if (c.nameIs('br') && !acc.endsWithSpace()) {
        acc.add(' ');
      }
    }
    return javaTrim(acc.toString());
  }

  /** Jsoup wholeText()：后代文本原样拼接（不规整空白；br → '\n'） */
  wholeText(): string {
    if (this.nodeType !== NODE_ELEMENT && this.nodeType !== NODE_DOCUMENT) {
      return this.data;
    }
    let accum: string = '';
    this.traverse((node: HtmlNode, _d: number) => {
      if (node.nodeType === NODE_TEXT) {
        accum += node.data;
      } else if (node.nameIs('br')) {
        accum += '\n';
      }
    });
    return accum;
  }

  hasText(): boolean {
    let found: boolean = false;
    this.traverse((node: HtmlNode, _d: number) => {
      if (!found && node.nodeType === NODE_TEXT && !node.isBlank()) {
        found = true;
      }
    });
    return found;
  }

  appendChild(child: HtmlNode): HtmlNode {
    child.remove();
    child.parent = this;
    this.children.push(child);
    return this;
  }

  prependChild(child: HtmlNode): HtmlNode {
    return this.insertChild(0, child);
  }

  insertChild(index: number, child: HtmlNode): HtmlNode {
    child.remove();
    child.parent = this;
    const i: number = Math.max(0, Math.min(index, this.children.length));
    this.children.splice(i, 0, child);
    return this;
  }

  /** 从父节点移除自身 */
  remove(): void {
    if (this.parent !== null) {
      const i: number = this.parent.children.indexOf(this);
      if (i >= 0) {
        this.parent.children.splice(i, 1);
      }
      this.parent = null;
    }
  }

  replaceWith(other: HtmlNode): void {
    const p: HtmlNode | null = this.parent;
    if (p === null) {
      return;
    }
    const i: number = this.siblingIndex();
    this.remove();
    p.insertChild(i, other);
  }

  before(other: HtmlNode): void {
    const p: HtmlNode | null = this.parent;
    if (p !== null) {
      other.remove();
      p.insertChild(this.siblingIndex(), other);
    }
  }

  after(other: HtmlNode): void {
    const p: HtmlNode | null = this.parent;
    if (p !== null) {
      other.remove();
      p.insertChild(this.siblingIndex() + 1, other);
    }
  }

  /** 用子节点替换自身；返回第一个子节点 */
  unwrap(): HtmlNode | null {
    const p: HtmlNode | null = this.parent;
    if (p === null) {
      return null;
    }
    const first: HtmlNode | null = this.children.length > 0 ? this.children[0] : null;
    let idx: number = this.siblingIndex();
    const kids: HtmlNode[] = this.children.slice();
    this.remove();
    for (let i = 0; i < kids.length; i++) {
      p.insertChild(idx, kids[i]);
      idx++;
    }
    return first;
  }

  empty(): HtmlNode {
    const kids: HtmlNode[] = this.children.slice();
    for (let i = 0; i < kids.length; i++) {
      kids[i].parent = null;
    }
    this.children = [];
    return this;
  }

  renameTag(tag: string): HtmlNode {
    this.tag = tag.toLowerCase();
    return this;
  }

  /** Jsoup Element.text(String)：清空并放入单个文本节点 */
  setText(text: string): HtmlNode {
    this.empty();
    return this.appendChild(HtmlNode.textNode(text));
  }

  /** 深拷贝（不含 parent） */
  clone(): HtmlNode {
    const c: HtmlNode = new HtmlNode(this.nodeType, this.tag, this.data);
    this.attrs.forEach((v: string, k: string) => {
      c.attrs.set(k, v);
    });
    for (let i = 0; i < this.children.length; i++) {
      const cc: HtmlNode = this.children[i].clone();
      cc.parent = c;
      c.children.push(cc);
    }
    return c;
  }

  outerHtml(): string {
    let out: string = '';
    this.traverse((node: HtmlNode, _d: number) => {
      out += HtmlNode.openHtml(node);
    }, (node: HtmlNode, _d: number) => {
      if (node.nodeType === NODE_ELEMENT && !VOID_TAGS.has(node.tag)) {
        out += '</' + node.tag + '>';
      }
    });
    return out;
  }

  /** 内部 HTML */
  html(): string {
    let out: string = '';
    for (let i = 0; i < this.children.length; i++) {
      out += this.children[i].outerHtml();
    }
    return out;
  }

  private static openHtml(node: HtmlNode): string {
    if (node.nodeType === NODE_TEXT) {
      const p: HtmlNode | null = node.parent;
      if (p !== null && p.isElement() && (p.tag === 'textarea' || p.tag === 'plaintext')) {
        return node.data;
      }
      return escapeHtmlText(node.data, false);
    }
    if (node.nodeType === NODE_DATA) {
      return node.data;
    }
    if (node.nodeType === NODE_COMMENT) {
      return '<!--' + node.data + '-->';
    }
    if (node.nodeType !== NODE_ELEMENT) {
      return '';
    }
    let s: string = '<' + node.tag;
    node.attrs.forEach((v: string, k: string) => {
      s += ' ' + k + '="' + escapeHtmlText(v, true) + '"';
    });
    return s + '>';
  }

  toString(): string {
    return this.outerHtml();
  }
}
