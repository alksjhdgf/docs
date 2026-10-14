/**
 * MarkdownInline.ets —— MarkdownToHtml 的行内解析（CommonMark 子集）：代码 span、强调/加粗定界符算法、
 * 行内链接/图片、自动链接、行内 HTML 透传、反斜杠转义、实体、软/硬换行。
 */
import { isNamedEntity } from './HtmlEntities';

const PUNCT: string = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';

/** 文本 HTML 转义（& < > "） */
export function escText(text: string): string {
  return text.split('&').join('&amp;').split('<').join('&lt;').split('>').join('&gt;').split('"').join('&quot;');
}

class InlineNode {
  /** 已是 HTML 的文本，或定界符 */
  html: string = '';
  isDelim: boolean = false;
  ch: string = '';
  count: number = 0;
  origCount: number = 0;
  canOpen: boolean = false;
  canClose: boolean = false;
  openTags: string = '';
  closeTags: string = '';

  static text(html: string): InlineNode {
    const n: InlineNode = new InlineNode();
    n.html = html;
    return n;
  }
}

function isWs(c: string): boolean {
  return c === '' || c === ' ' || c === '\t' || c === '\n' || c === '\r' || c === '\f' || c === '\u00a0';
}

/** ASCII 标点 + 常见 Unicode 标点/符号区段（近似 CommonMark 的 Unicode punctuation） */
function isPunct(c: string): boolean {
  if (c === '') {
    return false;
  }
  if (PUNCT.indexOf(c) >= 0) {
    return true;
  }
  const code: number = c.charCodeAt(0);
  return (code >= 0xA1 && code <= 0xBF) || code === 0xD7 || code === 0xF7 || (code >= 0x2010 && code <= 0x2027) ||
    (code >= 0x2030 && code <= 0x205E) || (code >= 0x3001 && code <= 0x3003) || (code >= 0x3008 && code <= 0x3011) ||
    (code >= 0xFF01 && code <= 0xFF0F) || (code >= 0xFF1A && code <= 0xFF20);
}

const RE_AUTOLINK: RegExp = new RegExp('^<([a-zA-Z][a-zA-Z0-9+.\\-]{1,31}:[^<>\\s]*)>');
const RE_EMAIL: RegExp = new RegExp('^<([a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~\\-]+@[a-zA-Z0-9](?:[a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?' +
  '(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*)>');
const RE_INLINE_HTML: RegExp = new RegExp('^(<[a-zA-Z][a-zA-Z0-9\\-]*(?:\\s+[a-zA-Z_:][a-zA-Z0-9_.:\\-]*' +
  '(?:\\s*=\\s*(?:[^\\s"\'=<>`]+|\'[^\']*\'|"[^"]*"))?)*\\s*/?>|</[a-zA-Z][a-zA-Z0-9\\-]*\\s*>|<!--[\\s\\S]*?-->)');
const RE_ENTITY: RegExp = new RegExp('^&(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|([a-zA-Z][a-zA-Z0-9]{1,31}));');
const RE_LINK_TAIL: RegExp = new RegExp('^\\(\\s*(<[^<>\\n]*>|[^\\s()]*(?:\\([^\\s()]*\\)[^\\s()]*)*)' +
  '(?:\\s+("[^"]*"|\'[^\']*\'|\\([^()]*\\)))?\\s*\\)');

export function renderInline(text: string): string {
  const nodes: InlineNode[] = [];
  let buf: string = '';
  let i: number = 0;
  const flush = (): void => {
    if (buf.length > 0) {
      nodes.push(InlineNode.text(buf));
      buf = '';
    }
  };
  while (i < text.length) {
    const c: string = text.charAt(i);
    if (c === '\\' && i + 1 < text.length) {
      const n: string = text.charAt(i + 1);
      if (n === '\n') {
        buf += '<br />\n';
        i += 2;
        continue;
      }
      if (PUNCT.indexOf(n) >= 0) {
        buf += escText(n);
        i += 2;
        continue;
      }
    }
    if (c === '`') {
      let run: number = 0;
      while (i + run < text.length && text.charAt(i + run) === '`') {
        run++;
      }
      const ticks: string = '`'.repeat(run);
      let j: number = text.indexOf(ticks, i + run);
      while (j >= 0 && j + run < text.length && text.charAt(j + run) === '`') {
        let k: number = j;
        while (k < text.length && text.charAt(k) === '`') {
          k++;
        }
        j = text.indexOf(ticks, k);
      }
      if (j >= 0) {
        let code: string = text.substring(i + run, j).split('\n').join(' ');
        if (code.length > 2 && code.startsWith(' ') && code.endsWith(' ') && code.trim().length > 0) {
          code = code.substring(1, code.length - 1);
        }
        buf += '<code>' + escText(code) + '</code>';
        i = j + run;
      } else {
        buf += ticks;
        i += run;
      }
      continue;
    }
    if (c === '*' || c === '_') {
      flush();
      let run: number = 0;
      while (i + run < text.length && text.charAt(i + run) === c) {
        run++;
      }
      const before: string = i > 0 ? text.charAt(i - 1) : '';
      const after: string = i + run < text.length ? text.charAt(i + run) : '';
      const left: boolean = !isWs(after) && (!isPunct(after) || isWs(before) || isPunct(before));
      const right: boolean = !isWs(before) && (!isPunct(before) || isWs(after) || isPunct(after));
      const d: InlineNode = new InlineNode();
      d.isDelim = true;
      d.ch = c;
      d.count = run;
      d.origCount = run;
      d.canOpen = c === '*' ? left : left && (!right || isPunct(before));
      d.canClose = c === '*' ? right : right && (!left || isPunct(after));
      nodes.push(d);
      i += run;
      continue;
    }
    if ((c === '!' && text.charAt(i + 1) === '[') || c === '[') {
      const img: boolean = c === '!';
      const open: number = img ? i + 1 : i;
      const close: number = findBracket(text, open);
      if (close > 0) {
        const tail: RegExpMatchArray | null = text.substring(close + 1).match(RE_LINK_TAIL);
        if (tail !== null) {
          let dest: string = tail[1];
          if (dest.startsWith('<')) {
            dest = dest.substring(1, dest.length - 1);
          }
          const label: string = text.substring(open + 1, close);
          const titleAttr: string = tail[2] !== undefined && tail[2] !== null && tail[2].length > 0 ?
            ' title="' + escText(tail[2].substring(1, tail[2].length - 1)) + '"' : '';
          if (img) {
            buf += '<img src="' + escText(dest) + '" alt="' + escText(label) + '"' + titleAttr + ' />';
          } else {
            buf += '<a href="' + escText(dest) + '"' + titleAttr + '>' + renderInline(label) + '</a>';
          }
          i = close + 1 + tail[0].length;
          continue;
        }
      }
    }
    if (c === '<') {
      const rest: string = text.substring(i);
      const al: RegExpMatchArray | null = rest.match(RE_AUTOLINK);
      if (al !== null) {
        buf += '<a href="' + escText(al[1]) + '">' + escText(al[1]) + '</a>';
        i += al[0].length;
        continue;
      }
      const em: RegExpMatchArray | null = rest.match(RE_EMAIL);
      if (em !== null) {
        buf += '<a href="mailto:' + escText(em[1]) + '">' + escText(em[1]) + '</a>';
        i += em[0].length;
        continue;
      }
      const tag: RegExpMatchArray | null = rest.match(RE_INLINE_HTML);
      if (tag !== null) {
        buf += tag[0];
        i += tag[0].length;
        continue;
      }
    }
    if (c === '&') {
      const ent: RegExpMatchArray | null = text.substring(i).match(RE_ENTITY);
      if (ent !== null && (ent[1] === undefined || ent[1] === null || isNamedEntity(ent[1]))) {
        buf += ent[0];
        i += ent[0].length;
        continue;
      }
    }
    if (c === '\n') {
      // 行尾两个以上空格 → 硬换行
      let k: number = buf.length;
      while (k > 0 && buf.charAt(k - 1) === ' ') {
        k--;
      }
      const hard: boolean = buf.length - k >= 2;
      buf = buf.substring(0, k) + (hard ? '<br />\n' : '\n');
      i++;
      while (i < text.length && text.charAt(i) === ' ') {
        i++;
      }
      continue;
    }
    buf += escText(c);
    i++;
  }
  flush();
  processEmphasis(nodes);
  let out: string = '';
  for (let k = 0; k < nodes.length; k++) {
    const n: InlineNode = nodes[k];
    out += n.isDelim ? n.ch.repeat(n.count) + n.openTags + n.closeTags : n.html;
  }
  return out;
}

function findBracket(text: string, open: number): number {
  let depth: number = 0;
  for (let i = open; i < text.length; i++) {
    const c: string = text.charAt(i);
    if (c === '\\') {
      i++;
    } else if (c === '[') {
      depth++;
    } else if (c === ']') {
      depth--;
      if (depth === 0) {
        return i;
      }
    }
  }
  return -1;
}

/** CommonMark "process emphasis"：自左向右找 closer，向左找可配对 opener */
function processEmphasis(nodes: InlineNode[]): void {
  let ci: number = 0;
  while (ci < nodes.length) {
    const closer: InlineNode = nodes[ci];
    if (!closer.isDelim || !closer.canClose || closer.count === 0) {
      ci++;
      continue;
    }
    let oi: number = ci - 1;
    let found: boolean = false;
    while (oi >= 0) {
      const op: InlineNode = nodes[oi];
      if (op.isDelim && op.ch === closer.ch && op.canOpen && op.count > 0) {
        const odd: boolean = (op.canClose || closer.canOpen) && (op.origCount + closer.origCount) % 3 === 0 &&
          !(op.origCount % 3 === 0 && closer.origCount % 3 === 0);
        if (!odd) {
          found = true;
          break;
        }
      }
      oi--;
    }
    if (!found) {
      if (!closer.canOpen) {
        closer.canClose = false;
      }
      ci++;
      continue;
    }
    const opener: InlineNode = nodes[oi];
    const n: number = opener.count >= 2 && closer.count >= 2 ? 2 : 1;
    const tag: string = n === 2 ? 'strong' : 'em';
    opener.count -= n;
    closer.count -= n;
    opener.openTags = '<' + tag + '>' + opener.openTags;
    closer.closeTags = closer.closeTags + '</' + tag + '>';
    for (let k = oi + 1; k < ci; k++) {
      if (nodes[k].isDelim) {
        nodes[k].canOpen = false;
        nodes[k].canClose = false;
      }
    }
    if (closer.count === 0) {
      ci++;
    }
  }
  // closer 的字面剩余字符应在关闭标签之后输出
  for (let k = 0; k < nodes.length; k++) {
    const d: InlineNode = nodes[k];
    if (d.isDelim && d.closeTags.length > 0) {
      d.html = d.closeTags + d.ch.repeat(d.count);
      d.isDelim = false;
      if (d.openTags.length > 0) {
        d.html += d.openTags;
      }
    }
  }
}

