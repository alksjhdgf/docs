/**
 * HtmlTreeBuilder.ets —— HTML5 树构建规则子集（HtmlParser 的 tokenizer 驱动；见 HtmlParser.ets 头注释）。
 */
import { HtmlNode } from './HtmlNode';
import { VOID_TAGS, isHtmlWhitespace } from './HtmlChars';
import { resolveUrl } from './HtmlUrl';
import { TreeBuilderBase, shallowClone } from './HtmlTreeBase';
import {
  CLOSES_P,
  FORMATTING,
  HEADINGS,
  MARKER_TAGS,
  NO_RECONSTRUCT,
  HEAD_TAGS,
  RAW_DATA_TAGS,
  SCOPE_DEFAULT,
  SCOPE_TABLE,
  SPECIAL,
  TABLE_ALLOWED,
  TABLE_CONTEXT,
  TABLE_SECTIONS
} from './HtmlTags';

export class TreeBuilder extends TreeBuilderBase {
  onText(textIn: string): void {
    let text: string = textIn;
    if (this.skipNewline) {
      this.skipNewline = false;
      if (text.startsWith('\r\n')) {
        text = text.substring(2);
      } else if (text.startsWith('\n')) {
        text = text.substring(1);
      }
    }
    if (text.length === 0) {
      return;
    }
    let allWs: boolean = true;
    for (let i = 0; i < text.length; i++) {
      if (!isHtmlWhitespace(text.charCodeAt(i))) {
        allWs = false;
        break;
      }
    }
    if (!this.inBody()) {
      if (allWs || (this.current() !== this.head && this.current() !== this.html)) {
        this.appendText(this.current(), text, false, null);
        return;
      }
      this.ensureBody();
    }
    if (!allWs && this.needsFoster(null)) {
      const table: HtmlNode | null = this.fosterTarget();
      if (table !== null && table.parent !== null) {
        this.appendText(table.parent, text, false, table);
        return;
      }
    }
    this.reconstruct();
    this.appendText(this.current(), text, false, null);
  }

  onRawText(text: string): void {
    this.skipNewline = false;
    this.appendText(this.current(), text, RAW_DATA_TAGS.has(this.current().tag), null);
  }

  onComment(text: string): void {
    this.skipNewline = false;
    this.current().appendChild(HtmlNode.commentNode(text));
  }

  /** 收养代理算法（简化：省略内层循环的 3 次上限与书签细节） */
  private adoption(tag: string): void {
    for (let outer = 0; outer < 8; outer++) {
      const fe: HtmlNode | null = this.afeFind(tag);
      if (fe === null) {
        this.genericEndTag(tag);
        return;
      }
      const fi: number = this.stack.indexOf(fe);
      if (fi < 0) {
        this.afeRemove(fe);
        return;
      }
      if (this.inScope(new Set<string>([tag]), SCOPE_DEFAULT, null) !== fe) {
        return;
      }
      let furthest: HtmlNode | null = null;
      for (let k = fi + 1; k < this.stack.length; k++) {
        if (SPECIAL.has(this.stack[k].tag)) {
          furthest = this.stack[k];
          break;
        }
      }
      if (furthest === null) {
        this.popTo(fe);
        this.afeRemove(fe);
        return;
      }
      const ca: HtmlNode = this.stack[fi - 1];
      let lastNode: HtmlNode = furthest;
      for (let k = this.stack.indexOf(furthest) - 1; k > fi; k--) {
        const node: HtmlNode = this.stack[k];
        const ai: number = this.afe.indexOf(node);
        if (ai < 0) {
          this.stack.splice(k, 1);
          continue;
        }
        const clone: HtmlNode = shallowClone(node);
        this.afe[ai] = clone;
        this.stack[k] = clone;
        clone.appendChild(lastNode);
        lastNode = clone;
      }
      ca.appendChild(lastNode);
      const newFe: HtmlNode = shallowClone(fe);
      const kids: HtmlNode[] = furthest.children.slice();
      for (let k = 0; k < kids.length; k++) {
        newFe.appendChild(kids[k]);
      }
      furthest.appendChild(newFe);
      this.afe[this.afe.indexOf(fe)] = newFe;
      this.stack.splice(this.stack.indexOf(fe), 1);
      this.stack.splice(this.stack.indexOf(furthest) + 1, 0, newFe);
    }
  }

  // ---------- 起始标签 ----------

  /** 返回插入后是否仍在栈上（供 tokenizer 判断原文模式） */
  onStartTag(tagIn: string, attrs: Map<string, string>, selfClosing: boolean): boolean {
    this.skipNewline = false;
    const tag: string = tagIn === 'image' ? 'img' : tagIn;
    if (tag === 'html') {
      this.mergeAttrs(this.html, attrs);
      return false;
    }
    if (!this.inBody()) {
      if (tag === 'head') {
        this.mergeAttrs(this.head, attrs);
        return false;
      }
      if (HEAD_TAGS.has(tag)) {
        if (this.stack.indexOf(this.head) < 0) {
          this.stack.push(this.head);
        }
        return this.insertGeneric(tag, attrs, selfClosing);
      }
      if (tag === 'body' || tag === 'frameset') {
        this.ensureBody();
        if (this.body !== null) {
          this.mergeAttrs(this.body, attrs);
        }
        return false;
      }
      this.ensureBody();
    }
    if (tag === 'body') {
      if (this.body !== null) {
        this.mergeAttrs(this.body, attrs);
      }
      return false;
    }
    if (tag === 'head' || tag === 'frameset') {
      return false;
    }
    if (TABLE_ALLOWED.has(tag) && this.handleTableStart(tag, attrs)) {
      return this.current().tag === tag;
    }
    if (CLOSES_P.has(tag)) {
      this.closePIfInButtonScope();
    }
    if (HEADINGS.has(tag) && HEADINGS.has(this.current().tag)) {
      this.popOne();
    } else if (tag === 'li') {
      this.closeListItem(new Set<string>(['li']));
    } else if (tag === 'dd' || tag === 'dt') {
      this.closeListItem(new Set<string>(['dd', 'dt']));
    } else if (tag === 'a') {
      const open: HtmlNode | null = this.afeFind('a');
      if (open !== null) {
        this.adoption('a');
        this.afeRemove(open);
        const si: number = this.stack.indexOf(open);
        if (si >= 0) {
          this.stack.splice(si, 1);
        }
      }
    } else if (tag === 'button' || tag === 'nobr') {
      const open: HtmlNode | null = this.inScope(new Set<string>([tag]), SCOPE_DEFAULT, null);
      if (open !== null) {
        this.popTo(open);
      }
    } else if (tag === 'option' || tag === 'optgroup') {
      if (this.current().tag === 'option') {
        this.popOne();
      }
    } else if (tag === 'rb' || tag === 'rp' || tag === 'rt' || tag === 'rtc') {
      const cur: string = this.current().tag;
      if (cur === 'rb' || cur === 'rp' || cur === 'rt') {
        this.popOne();
      }
    }
    if (!CLOSES_P.has(tag) && !NO_RECONSTRUCT.has(tag)) {
      this.reconstruct();
    }
    const pushed: boolean = this.insertGeneric(tag, attrs, selfClosing);
    if (pushed && FORMATTING.has(tag)) {
      this.afe.push(this.current());
    } else if (pushed && MARKER_TAGS.has(tag)) {
      this.afe.push(null);
    }
    if (pushed && (tag === 'pre' || tag === 'listing' || tag === 'textarea')) {
      this.skipNewline = true;
    }
    return pushed;
  }

  private insertGeneric(tag: string, attrs: Map<string, string>, selfClosing: boolean): boolean {
    const push: boolean = !selfClosing && !VOID_TAGS.has(tag);
    const el: HtmlNode = this.insertElement(tag, attrs, push);
    if (tag === 'base' && !this.baseSeen) {
      const href: string = el.attr('href');
      if (href.length > 0) {
        this.baseSeen = true;
        const abs: string = resolveUrl(this.doc.location, href);
        if (abs.length > 0) {
          this.doc.location = abs;
        }
      }
    }
    return push;
  }

  private closeListItem(tags: Set<string>): void {
    for (let i = this.stack.length - 1; i >= 2; i--) {
      const n: HtmlNode = this.stack[i];
      if (tags.has(n.tag)) {
        this.popTo(n);
        return;
      }
      if (SPECIAL.has(n.tag) && n.tag !== 'address' && n.tag !== 'div' && n.tag !== 'p') {
        return;
      }
    }
  }

  /** 表格相关起始标签；返回 true 表示已处理 */
  private handleTableStart(tag: string, attrs: Map<string, string>): boolean {
    const inTable: boolean = this.inScopeOne('table', SCOPE_TABLE, null);
    if (tag === 'table') {
      if (TABLE_CONTEXT.has(this.current().tag) || this.current().tag === 'caption') {
        this.popUntilTag(new Set<string>(['table']));
      } else {
        this.closePIfInButtonScope();
      }
      this.insertElement('table', attrs, true);
      return true;
    }
    if (!inTable) {
      if (tag === 'caption' || tag === 'colgroup' || tag === 'col' || TABLE_SECTIONS.has(tag) || tag === 'tr' ||
        tag === 'td' || tag === 'th') {
        return true; // 表外的表格结构标签被忽略（HTML5 / Jsoup）
      }
      return false;
    }
    if (!TABLE_CONTEXT.has(this.current().tag) && tag !== 'td' && tag !== 'th' && tag !== 'tr' &&
      !TABLE_SECTIONS.has(tag) && tag !== 'caption' && tag !== 'colgroup' && tag !== 'col') {
      return false;
    }
    if (tag === 'caption' || tag === 'colgroup') {
      this.clearToContext(new Set<string>(['table']));
      this.insertElement(tag, attrs, true);
      if (tag === 'caption') {
        this.afe.push(null);
      }
      return true;
    }
    if (tag === 'col') {
      if (this.current().tag !== 'colgroup') {
        this.clearToContext(new Set<string>(['table']));
        this.insertElement('colgroup', new Map<string, string>(), true);
      }
      this.insertElement('col', attrs, false);
      return true;
    }
    if (TABLE_SECTIONS.has(tag)) {
      this.clearToContext(new Set<string>(['table']));
      this.insertElement(tag, attrs, true);
      return true;
    }
    if (tag === 'tr') {
      if (this.inScope(new Set<string>(['td', 'th']), SCOPE_TABLE, null) !== null) {
        this.popUntilTag(new Set<string>(['td', 'th']));
      }
      this.clearToContext(new Set<string>(['tbody', 'thead', 'tfoot', 'table']));
      if (this.current().tag === 'table') {
        this.insertElement('tbody', new Map<string, string>(), true);
      }
      this.insertElement('tr', attrs, true);
      return true;
    }
    if (tag === 'td' || tag === 'th') {
      if (this.inScope(new Set<string>(['td', 'th']), SCOPE_TABLE, null) !== null) {
        this.popUntilTag(new Set<string>(['td', 'th']));
      }
      this.clearToContext(new Set<string>(['tr', 'tbody', 'thead', 'tfoot', 'table']));
      if (this.current().tag === 'table') {
        this.insertElement('tbody', new Map<string, string>(), true);
      }
      if (this.current().tag !== 'tr') {
        this.insertElement('tr', new Map<string, string>(), true);
      }
      this.insertElement(tag, attrs, true);
      this.afe.push(null);
      return true;
    }
    return false;
  }

  // ---------- 结束标签 ----------

  onEndTag(tagIn: string): void {
    this.skipNewline = false;
    const tag: string = tagIn === 'image' ? 'img' : tagIn;
    if (!this.inBody()) {
      if (tag === 'head') {
        const i: number = this.stack.indexOf(this.head);
        if (i >= 0) {
          this.stack.splice(i);
        }
        return;
      }
      if (this.current() !== this.head && this.current().tag === tag && this.current() !== this.html) {
        this.popOne();
        return;
      }
      if (tag !== 'br' && tag !== 'p') {
        return;
      }
      this.ensureBody();
    }
    if (tag === 'body' || tag === 'html' || tag === 'head') {
      return;
    }
    if (tag === 'br') {
      this.onStartTag('br', new Map<string, string>(), false);
      return;
    }
    if (tag === 'p') {
      const p: HtmlNode | null = this.inScope(new Set<string>(['p']), SCOPE_DEFAULT, 'button');
      if (p === null) {
        this.insertElement('p', new Map<string, string>(), false);
      } else {
        this.popTo(p);
      }
      return;
    }
    let scoped: HtmlNode | null = null;
    if (tag === 'li') {
      scoped = this.inScope(new Set<string>(['li']), SCOPE_DEFAULT, 'list');
    } else if (HEADINGS.has(tag)) {
      scoped = this.inScope(HEADINGS, SCOPE_DEFAULT, null);
    } else if (TABLE_CONTEXT.has(tag) || tag === 'td' || tag === 'th' || tag === 'caption' || tag === 'colgroup') {
      scoped = this.inScope(new Set<string>([tag]), SCOPE_TABLE, null);
    } else if (FORMATTING.has(tag)) {
      this.adoption(tag);
      return;
    } else if (CLOSES_P.has(tag) || MARKER_TAGS.has(tag) || tag === 'button') {
      scoped = this.inScope(new Set<string>([tag]), SCOPE_DEFAULT, null);
    } else {
      this.genericEndTag(tag);
      return;
    }
    if (scoped !== null) {
      this.popTo(scoped);
    }
  }

  /** "any other end tag"：自栈顶找同名元素，途中遇 special 元素则忽略 */
  private genericEndTag(tag: string): void {
    for (let i = this.stack.length - 1; i >= 2; i--) {
      const n: HtmlNode = this.stack[i];
      if (n.tag === tag) {
        this.popTo(n);
        return;
      }
      if (SPECIAL.has(n.tag)) {
        return;
      }
    }
  }
}
