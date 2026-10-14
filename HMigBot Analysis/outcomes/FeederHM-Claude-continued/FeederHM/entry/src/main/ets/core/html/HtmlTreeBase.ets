/**
 * HtmlTreeBase.ets —— 树构建器基础：打开元素栈、活动格式元素列表、作用域判定、插入与表格寄养。
 */
import { HtmlDocument } from './HtmlDocument';
import { HtmlNode } from './HtmlNode';
import { NODE_DATA, NODE_TEXT } from './HtmlChars';
import { MARKER_TAGS, SCOPE_DEFAULT, TABLE_ALLOWED, TABLE_CONTEXT } from './HtmlTags';

export function shallowClone(el: HtmlNode): HtmlNode {
  const c: HtmlNode = HtmlNode.element(el.tag);
  el.attrs.forEach((v: string, k: string) => {
    c.attrs.set(k, v);
  });
  return c;
}

export class TreeBuilderBase {
  doc: HtmlDocument;
  html: HtmlNode;
  head: HtmlNode;
  body: HtmlNode | null = null;
  stack: HtmlNode[] = [];
  skipNewline: boolean = false;
  baseSeen: boolean = false;
  /** 活动格式元素列表（null = marker） */
  afe: (HtmlNode | null)[] = [];

  constructor(baseUrl: string) {
    this.doc = new HtmlDocument(baseUrl);
    this.html = HtmlNode.element('html');
    this.doc.appendChild(this.html);
    this.head = HtmlNode.element('head');
    this.html.appendChild(this.head);
    this.stack = [this.html, this.head];
  }

  current(): HtmlNode {
    return this.stack[this.stack.length - 1];
  }

  inBody(): boolean {
    return this.body !== null;
  }

  ensureBody(): void {
    if (this.body === null) {
      this.body = HtmlNode.element('body');
      this.html.appendChild(this.body);
      this.stack = [this.html, this.body];
    }
  }

  finish(): HtmlDocument {
    this.ensureBody();
    return this.doc;
  }

  // ---------- 插入 ----------

  protected appendText(target: HtmlNode, text: string, data: boolean, beforeNode: HtmlNode | null): void {
    const kids: HtmlNode[] = target.children;
    const idx: number = beforeNode === null ? kids.length : kids.indexOf(beforeNode);
    const prev: HtmlNode | null = idx > 0 ? kids[idx - 1] : null;
    const type: number = data ? NODE_DATA : NODE_TEXT;
    if (prev !== null && prev.nodeType === type) {
      prev.data += text;
      return;
    }
    const node: HtmlNode = data ? HtmlNode.dataNode(text) : HtmlNode.textNode(text);
    target.insertChild(idx < 0 ? kids.length : idx, node);
  }

  /** 表格寄养：插入到栈中最近的 table 之前 */
  protected fosterTarget(): HtmlNode | null {
    for (let i = this.stack.length - 1; i >= 0; i--) {
      if (this.stack[i].tag === 'table') {
        return this.stack[i];
      }
    }
    return null;
  }

  protected insertNode(node: HtmlNode, foster: boolean): void {
    if (foster) {
      const table: HtmlNode | null = this.fosterTarget();
      if (table !== null && table.parent !== null) {
        table.before(node);
        return;
      }
    }
    this.current().appendChild(node);
  }

  protected needsFoster(tag: string | null): boolean {
    const cur: HtmlNode = this.current();
    if (!TABLE_CONTEXT.has(cur.tag)) {
      return false;
    }
    return tag === null || !TABLE_ALLOWED.has(tag);
  }

  // ---------- 栈工具 ----------

  protected inScope(tags: Set<string>, boundary: Set<string>, extra: string | null): HtmlNode | null {
    for (let i = this.stack.length - 1; i >= 0; i--) {
      const t: string = this.stack[i].tag;
      if (tags.has(t)) {
        return this.stack[i];
      }
      if (boundary.has(t) || (extra !== null && (t === extra || (extra === 'list' && (t === 'ol' || t === 'ul'))))) {
        return null;
      }
    }
    return null;
  }

  protected inScopeOne(tag: string, boundary: Set<string>, extra: string | null): boolean {
    return this.inScope(new Set<string>([tag]), boundary, extra) !== null;
  }

  /** 弹出栈顶；弹出 td/th/caption 等 marker 元素时清理活动格式列表到 marker */
  protected popOne(): HtmlNode {
    const top: HtmlNode = this.stack[this.stack.length - 1];
    this.stack.pop();
    if (MARKER_TAGS.has(top.tag)) {
      while (this.afe.length > 0) {
        const e: HtmlNode | null = this.afe[this.afe.length - 1];
        this.afe.pop();
        if (e === null) {
          break;
        }
      }
    }
    return top;
  }

  /** 弹栈直到（含）node；不弹 html/body */
  protected popTo(node: HtmlNode): void {
    while (this.stack.length > 2) {
      if (this.popOne() === node) {
        return;
      }
    }
  }

  protected popUntilTag(tags: Set<string>): void {
    while (this.stack.length > 2) {
      if (tags.has(this.popOne().tag)) {
        return;
      }
    }
  }

  /** 重建活动格式元素（HTML5 §13.2.4.3） */
  protected reconstruct(): void {
    const n: number = this.afe.length;
    if (n === 0) {
      return;
    }
    const last: HtmlNode | null = this.afe[n - 1];
    if (last === null || this.stack.indexOf(last) >= 0) {
      return;
    }
    let i: number = n - 1;
    while (i > 0) {
      const prev: HtmlNode | null = this.afe[i - 1];
      if (prev === null || this.stack.indexOf(prev) >= 0) {
        break;
      }
      i--;
    }
    for (let j = i; j < n; j++) {
      const old: HtmlNode | null = this.afe[j];
      if (old !== null) {
        const clone: HtmlNode = shallowClone(old);
        this.insertNode(clone, this.needsFoster(clone.tag));
        this.stack.push(clone);
        this.afe[j] = clone;
      }
    }
  }

  protected afeFind(tag: string): HtmlNode | null {
    for (let i = this.afe.length - 1; i >= 0; i--) {
      const e: HtmlNode | null = this.afe[i];
      if (e === null) {
        return null;
      }
      if (e.tag === tag) {
        return e;
      }
    }
    return null;
  }

  protected afeRemove(el: HtmlNode): void {
    const i: number = this.afe.indexOf(el);
    if (i >= 0) {
      this.afe.splice(i, 1);
    }
  }

  protected closePIfInButtonScope(): void {
    const p: HtmlNode | null = this.inScope(new Set<string>(['p']), SCOPE_DEFAULT, 'button');
    if (p !== null) {
      this.popTo(p);
    }
  }

  protected clearToContext(tags: Set<string>): void {
    while (this.stack.length > 2 && !tags.has(this.current().tag)) {
      this.popOne();
    }
  }

  protected insertElement(tag: string, attrs: Map<string, string>, push: boolean): HtmlNode {
    const el: HtmlNode = HtmlNode.element(tag);
    attrs.forEach((v: string, k: string) => {
      el.attrs.set(k, v);
    });
    this.insertNode(el, this.inBody() && this.needsFoster(tag));
    if (push) {
      this.stack.push(el);
    }
    return el;
  }

  protected mergeAttrs(target: HtmlNode, attrs: Map<string, string>): void {
    attrs.forEach((v: string, k: string) => {
      if (!target.attrs.has(k)) {
        target.attrs.set(k, v);
      }
    });
  }
}
