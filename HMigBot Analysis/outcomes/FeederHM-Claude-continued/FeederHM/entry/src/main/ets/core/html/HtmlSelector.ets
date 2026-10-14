/**
 * HtmlSelector.ets —— Jsoup CSS 选择器子集（作用于 core/html 自研 DOM）。
 *
 * 支持：
 *  - 简单选择器：`tag`、`*`、`#id`、`.class`（类名忽略大小写）、
 *    属性 `[a]`、`[^prefix]`、`[a=v]`、`[a!=v]`、`[a^=v]`、`[a$=v]`、`[a*=v]`、`[a~=regex]`
 *    （值可带单/双引号；= ^= $= *= 比较忽略大小写，`=` 两侧 trim —— 均照 Jsoup Evaluator）
 *  - 组合：后代（空白）、子代 `>`、相邻 `+`、兄弟 `~`；分组 `,`
 *  - 伪类：:not(s) :has(s) :contains(t) :containsOwn(t) :matches(re) :matchesOwn(re) :first-child
 *    :last-child :only-child :empty :root :nth-child(an+b|odd|even) :eq(n) :lt(n) :gt(n)
 * select(root, q) ≙ Jsoup Element.select：结果含 root 自身（若匹配），文档序，无重复。
 * 语法错误抛 SelectorParseError。
 */
import { HtmlNode } from './HtmlNode';
import { javaTrim } from './HtmlChars';

export class SelectorParseError extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = 'SelectorParseError';
  }
}

const K_TAG: number = 1;
const K_ANY: number = 2;
const K_ID: number = 3;
const K_CLASS: number = 4;
const K_ATTR: number = 5;
const K_ATTR_PREFIX: number = 6;
const K_PSEUDO: number = 7;

class SimpleSel {
  kind: number;
  name: string;
  op: string = '';
  value: string = '';
  regex: RegExp | null = null;
  sub: SelectorGroup | null = null;
  a: number = 0;
  b: number = 0;

  constructor(kind: number, name: string) {
    this.kind = kind;
    this.name = name;
  }
}

class Compound {
  parts: SimpleSel[] = [];
}

class Complex {
  compounds: Compound[] = [];
  /** combinators[i] 位于 compounds[i] 与 compounds[i+1] 之间：' ' '>' '+' '~' */
  combinators: string[] = [];
}

export class SelectorGroup {
  list: Complex[] = [];

  /** el 是否匹配（root 为 select 的作用根，后代组合子最多上溯到 root） */
  matches(root: HtmlNode, el: HtmlNode): boolean {
    for (let i = 0; i < this.list.length; i++) {
      const cx: Complex = this.list[i];
      if (matchComplex(root, el, cx, cx.compounds.length - 1)) {
        return true;
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------- 解析

const CACHE: Map<string, SelectorGroup> = new Map<string, SelectorGroup>();

class QueryParser {
  q: string;
  pos: number = 0;

  constructor(q: string) {
    this.q = q;
  }

  private peek(): string {
    return this.pos < this.q.length ? this.q.charAt(this.pos) : '';
  }

  private skipWs(): boolean {
    const start: number = this.pos;
    while (this.pos < this.q.length && ' \t\n\r\f'.indexOf(this.q.charAt(this.pos)) >= 0) {
      this.pos++;
    }
    return this.pos > start;
  }

  private ident(): string {
    const start: number = this.pos;
    while (this.pos < this.q.length) {
      const c: string = this.q.charAt(this.pos);
      if (' \t\n\r\f.#[]():,>+~=!^$*|\'"'.indexOf(c) >= 0) {
        break;
      }
      this.pos++;
    }
    return this.q.substring(start, this.pos);
  }

  /** 读取平衡括号内容（已越过 '('） */
  private balanced(): string {
    let depth: number = 1;
    const start: number = this.pos;
    let quote: string = '';
    while (this.pos < this.q.length) {
      const c: string = this.q.charAt(this.pos);
      if (quote.length > 0) {
        if (c === quote) {
          quote = '';
        }
      } else if (c === '\'' || c === '"') {
        quote = c;
      } else if (c === '(') {
        depth++;
      } else if (c === ')') {
        depth--;
        if (depth === 0) {
          const out: string = this.q.substring(start, this.pos);
          this.pos++;
          return out;
        }
      }
      this.pos++;
    }
    throw new SelectorParseError('Unbalanced parentheses in ' + this.q);
  }

  parseGroup(): SelectorGroup {
    const g: SelectorGroup = new SelectorGroup();
    this.skipWs();
    while (this.pos < this.q.length) {
      g.list.push(this.parseComplex());
      this.skipWs();
      if (this.peek() === ',') {
        this.pos++;
        this.skipWs();
      } else if (this.pos < this.q.length) {
        throw new SelectorParseError('Unexpected token in ' + this.q + ' at ' + this.pos);
      }
    }
    if (g.list.length === 0) {
      throw new SelectorParseError('Empty selector');
    }
    return g;
  }

  private parseComplex(): Complex {
    const cx: Complex = new Complex();
    cx.compounds.push(this.parseCompound());
    while (this.pos < this.q.length) {
      const hadWs: boolean = this.skipWs();
      const c: string = this.peek();
      if (c === ',' || c === '') {
        break;
      }
      let comb: string = ' ';
      if (c === '>' || c === '+' || c === '~') {
        comb = c;
        this.pos++;
        this.skipWs();
      } else if (!hadWs) {
        throw new SelectorParseError('Unexpected token in ' + this.q + ' at ' + this.pos);
      }
      cx.combinators.push(comb);
      cx.compounds.push(this.parseCompound());
    }
    return cx;
  }

  private parseCompound(): Compound {
    const cp: Compound = new Compound();
    const c0: string = this.peek();
    if (c0 === '*') {
      this.pos++;
      cp.parts.push(new SimpleSel(K_ANY, '*'));
    } else if (c0 !== '' && '.#[:'.indexOf(c0) < 0) {
      let name: string = this.ident();
      if (this.peek() === '|') {
        this.pos++;
        name = name + ':' + this.ident();
      }
      if (name.length === 0) {
        throw new SelectorParseError('Expected tag in ' + this.q + ' at ' + this.pos);
      }
      cp.parts.push(new SimpleSel(K_TAG, name.toLowerCase()));
    }
    while (this.pos < this.q.length) {
      const c: string = this.peek();
      if (c === '#') {
        this.pos++;
        cp.parts.push(new SimpleSel(K_ID, this.ident()));
      } else if (c === '.') {
        this.pos++;
        cp.parts.push(new SimpleSel(K_CLASS, this.ident().toLowerCase()));
      } else if (c === '[') {
        this.pos++;
        cp.parts.push(this.parseAttr());
      } else if (c === ':') {
        this.pos++;
        cp.parts.push(this.parsePseudo());
      } else {
        break;
      }
    }
    if (cp.parts.length === 0) {
      throw new SelectorParseError('Expected selector in ' + this.q + ' at ' + this.pos);
    }
    return cp;
  }

  private parseAttr(): SimpleSel {
    this.skipWs();
    let prefix: boolean = false;
    if (this.peek() === '^') {
      prefix = true;
      this.pos++;
    }
    const name: string = this.ident().toLowerCase();
    this.skipWs();
    if (prefix) {
      this.expect(']');
      return new SimpleSel(K_ATTR_PREFIX, name);
    }
    const sel: SimpleSel = new SimpleSel(K_ATTR, name);
    const c: string = this.peek();
    if (c === ']') {
      this.pos++;
      return sel;
    }
    if (c === '=') {
      sel.op = '=';
      this.pos++;
    } else if ('!^$*~'.indexOf(c) >= 0 && this.q.charAt(this.pos + 1) === '=') {
      sel.op = c + '=';
      this.pos += 2;
    } else {
      throw new SelectorParseError('Bad attribute selector in ' + this.q);
    }
    this.skipWs();
    let value: string = '';
    const q: string = this.peek();
    if (q === '"' || q === '\'') {
      const end: number = this.q.indexOf(q, this.pos + 1);
      if (end < 0) {
        throw new SelectorParseError('Unterminated string in ' + this.q);
      }
      value = this.q.substring(this.pos + 1, end);
      this.pos = end + 1;
    } else {
      const end: number = this.q.indexOf(']', this.pos);
      if (end < 0) {
        throw new SelectorParseError('Unterminated attribute selector in ' + this.q);
      }
      value = this.q.substring(this.pos, end).trim();
      this.pos = end;
    }
    this.skipWs();
    this.expect(']');
    if (sel.op === '~=') {
      sel.regex = new RegExp(value);
    } else if (sel.op === '=' || sel.op === '!=') {
      sel.value = javaTrim(value).toLowerCase();
    } else {
      sel.value = value.toLowerCase();
    }
    return sel;
  }

  private expect(c: string): void {
    if (this.peek() !== c) {
      throw new SelectorParseError('Expected ' + c + ' in ' + this.q + ' at ' + this.pos);
    }
    this.pos++;
  }

  private parsePseudo(): SimpleSel {
    const name: string = this.ident().toLowerCase();
    const sel: SimpleSel = new SimpleSel(K_PSEUDO, name);
    let arg: string = '';
    if (this.peek() === '(') {
      this.pos++;
      arg = this.balanced().trim();
    }
    if (name === 'not' || name === 'has' || name === 'is') {
      sel.sub = compileSelector(arg);
    } else if (name === 'contains' || name === 'containsown') {
      sel.value = unquote(arg).toLowerCase();
    } else if (name === 'matches' || name === 'matchesown') {
      sel.regex = new RegExp(unquote(arg));
    } else if (name === 'eq' || name === 'lt' || name === 'gt') {
      sel.a = parseInt(arg, 10);
    } else if (name === 'nth-child' || name === 'nth-last-child') {
      parseNth(arg, sel);
    } else if (['first-child', 'last-child', 'only-child', 'empty', 'root'].indexOf(name) < 0) {
      throw new SelectorParseError('Unsupported pseudo selector :' + name);
    }
    return sel;
  }
}

function unquote(s: string): string {
  if (s.length >= 2 && (s.startsWith('"') || s.startsWith('\'')) && s.charAt(s.length - 1) === s.charAt(0)) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

function parseNth(argIn: string, sel: SimpleSel): void {
  const arg: string = argIn.replace(new RegExp('\\s+', 'g'), '').toLowerCase();
  if (arg === 'odd') {
    sel.a = 2;
    sel.b = 1;
    return;
  }
  if (arg === 'even') {
    sel.a = 2;
    sel.b = 0;
    return;
  }
  const m: RegExpMatchArray | null = arg.match(new RegExp('^([+-]?\\d*)n([+-]\\d+)?$'));
  if (m !== null) {
    const as: string = m[1];
    sel.a = as === '' || as === '+' ? 1 : (as === '-' ? -1 : parseInt(as, 10));
    sel.b = m[2] !== undefined && m[2] !== null ? parseInt(m[2], 10) : 0;
    return;
  }
  if (new RegExp('^[+-]?\\d+$').test(arg)) {
    sel.a = 0;
    sel.b = parseInt(arg, 10);
    return;
  }
  throw new SelectorParseError('Could not parse nth-index ' + argIn);
}

/** 编译（带缓存）选择器 */
export function compileSelector(query: string): SelectorGroup {
  const cached: SelectorGroup | undefined = CACHE.get(query);
  if (cached !== undefined) {
    return cached;
  }
  const g: SelectorGroup = new QueryParser(query).parseGroup();
  if (CACHE.size > 256) {
    CACHE.clear();
  }
  CACHE.set(query, g);
  return g;
}

// ---------------------------------------------------------------- 匹配

function matchComplex(root: HtmlNode, el: HtmlNode, cx: Complex, idx: number): boolean {
  if (!matchCompound(root, el, cx.compounds[idx])) {
    return false;
  }
  if (idx === 0) {
    return true;
  }
  const comb: string = cx.combinators[idx - 1];
  if (comb === '>') {
    const p: HtmlNode | null = el.parent;
    return p !== null && p.isElement() && matchComplex(root, p, cx, idx - 1);
  }
  if (comb === ' ') {
    let p: HtmlNode | null = el.parent;
    while (p !== null && p.isElement()) {
      if (matchComplex(root, p, cx, idx - 1)) {
        return true;
      }
      if (p === root) {
        break;
      }
      p = p.parent;
    }
    return false;
  }
  if (comb === '+') {
    const prev: HtmlNode | null = el.previousElementSibling();
    return prev !== null && matchComplex(root, prev, cx, idx - 1);
  }
  let prev: HtmlNode | null = el.previousElementSibling();
  while (prev !== null) {
    if (matchComplex(root, prev, cx, idx - 1)) {
      return true;
    }
    prev = prev.previousElementSibling();
  }
  return false;
}

function matchCompound(root: HtmlNode, el: HtmlNode, cp: Compound): boolean {
  for (let i = 0; i < cp.parts.length; i++) {
    if (!matchSimple(root, el, cp.parts[i])) {
      return false;
    }
  }
  return true;
}

function hasAttrPrefix(el: HtmlNode, prefix: string): boolean {
  let found: boolean = false;
  el.attrs.forEach((_v: string, k: string) => {
    if (k.startsWith(prefix)) {
      found = true;
    }
  });
  return found;
}

function matchAttr(el: HtmlNode, s: SimpleSel): boolean {
  if (!el.hasAttr(s.name)) {
    return false;
  }
  const v: string = el.attr(s.name);
  if (s.op === '') {
    return true;
  }
  if (s.op === '=') {
    return javaTrim(v).toLowerCase() === s.value;
  }
  if (s.op === '!=') {
    return javaTrim(v).toLowerCase() !== s.value;
  }
  if (s.op === '^=') {
    return v.toLowerCase().startsWith(s.value);
  }
  if (s.op === '$=') {
    return v.toLowerCase().endsWith(s.value);
  }
  if (s.op === '*=') {
    return v.toLowerCase().indexOf(s.value) >= 0;
  }
  return s.regex !== null && s.regex.test(v);
}

function nthMatches(a: number, b: number, pos: number): boolean {
  if (a === 0) {
    return pos === b;
  }
  return (pos - b) * a >= 0 && (pos - b) % a === 0;
}

function matchPseudo(root: HtmlNode, el: HtmlNode, s: SimpleSel): boolean {
  const n: string = s.name;
  if (n === 'not') {
    return s.sub !== null && !s.sub.matches(root, el);
  }
  if (n === 'is') {
    return s.sub !== null && s.sub.matches(root, el);
  }
  if (n === 'has') {
    const sub: SelectorGroup | null = s.sub;
    if (sub === null) {
      return false;
    }
    const all: HtmlNode[] = el.allElements();
    for (let i = 1; i < all.length; i++) {
      if (sub.matches(el, all[i])) {
        return true;
      }
    }
    return false;
  }
  if (n === 'contains') {
    return el.text().toLowerCase().indexOf(s.value) >= 0;
  }
  if (n === 'containsown') {
    return el.ownText().toLowerCase().indexOf(s.value) >= 0;
  }
  if (n === 'matches') {
    return s.regex !== null && s.regex.test(el.text());
  }
  if (n === 'matchesown') {
    return s.regex !== null && s.regex.test(el.ownText());
  }
  if (n === 'root') {
    return el.parent !== null && !el.parent.isElement();
  }
  if (n === 'empty') {
    for (let i = 0; i < el.children.length; i++) {
      const c: HtmlNode = el.children[i];
      if (c.isElement() || (c.isText() && c.data.length > 0)) {
        return false;
      }
    }
    return true;
  }
  const p: HtmlNode | null = el.parent;
  if (p === null || !p.isElement()) {
    return false;
  }
  const sibs: HtmlNode[] = p.elementChildren();
  const idx: number = sibs.indexOf(el);
  if (n === 'first-child') {
    return idx === 0;
  }
  if (n === 'last-child') {
    return idx === sibs.length - 1;
  }
  if (n === 'only-child') {
    return sibs.length === 1;
  }
  if (n === 'eq') {
    return idx === s.a;
  }
  if (n === 'lt') {
    return idx < s.a;
  }
  if (n === 'gt') {
    return idx > s.a;
  }
  if (n === 'nth-child') {
    return nthMatches(s.a, s.b, idx + 1);
  }
  if (n === 'nth-last-child') {
    return nthMatches(s.a, s.b, sibs.length - idx);
  }
  return false;
}

function matchSimple(root: HtmlNode, el: HtmlNode, s: SimpleSel): boolean {
  if (s.kind === K_ANY) {
    return true;
  }
  if (s.kind === K_TAG) {
    return el.tag === s.name;
  }
  if (s.kind === K_ID) {
    return el.attr('id') === s.name;
  }
  if (s.kind === K_CLASS) {
    return el.hasClass(s.name);
  }
  if (s.kind === K_ATTR) {
    return matchAttr(el, s);
  }
  if (s.kind === K_ATTR_PREFIX) {
    return hasAttrPrefix(el, s.name);
  }
  return matchPseudo(root, el, s);
}

// ---------------------------------------------------------------- 入口

/** Jsoup Element.select(query)：root 及其后代中匹配的元素（文档序） */
export function select(root: HtmlNode, query: string): HtmlNode[] {
  const g: SelectorGroup = compileSelector(query);
  const out: HtmlNode[] = [];
  root.traverse((node: HtmlNode, _d: number) => {
    if (node.isElement() && g.matches(root, node)) {
      out.push(node);
    }
  });
  return out;
}

/** Jsoup Element.selectFirst */
export function selectFirst(root: HtmlNode, query: string): HtmlNode | null {
  const g: SelectorGroup = compileSelector(query);
  const all: HtmlNode[] = root.allElements();
  for (let i = 0; i < all.length; i++) {
    if (g.matches(root, all[i])) {
      return all[i];
    }
  }
  return null;
}

/** Jsoup Element.is(query) */
export function matchesSelector(el: HtmlNode, query: string): boolean {
  return compileSelector(query).matches(el, el);
}

/** Jsoup Element.closest(query)：自身或最近的匹配祖先 */
export function closest(el: HtmlNode, query: string): HtmlNode | null {
  const g: SelectorGroup = compileSelector(query);
  let n: HtmlNode | null = el;
  while (n !== null && n.isElement()) {
    if (g.matches(n, n)) {
      return n;
    }
    n = n.parent;
  }
  return null;
}
