/**
 * MarkdownToHtml.ets —— 源 ui/text/MarkdownToHtmlConverter.kt（jetbrains-markdown CommonMark → 自研 CommonMark 子集）。
 * 唯一用途：AI 摘要成功结果（Markdown → HTML → 富文本，源 ArticleViewModel.kt:741）；摘要错误信息不经此转换。
 *
 * 覆盖：ATX/Setext 标题、段落（软换行保留 '\n'，行尾两空格或反斜杠 → <br />）、分隔线、
 * 引用（可嵌套、惰性续行）、无序/有序列表（嵌套、紧凑/松散）、围栏/缩进代码块、HTML 块与行内 HTML 透传、
 * 行内：代码 span、强调/加粗（CommonMark 定界符算法，* 与 _）、行内链接/图片、自动链接、反斜杠转义、实体。
 * 未覆盖：引用式链接定义、表格等 GFM 扩展（原文按文本输出）。
 * 输出外层带 `<body>`（jetbrains HtmlGenerator 对 MARKDOWN_FILE 的渲染）。
 */
import { escText, renderInline } from './MarkdownInline';

const B_PARA: number = 1;
const B_HEADING: number = 2;
const B_HR: number = 3;
const B_CODE: number = 4;
const B_QUOTE: number = 5;
const B_LIST: number = 6;
const B_ITEM: number = 7;
const B_HTML: number = 8;

class MdBlock {
  type: number;
  lines: string[] = [];
  level: number = 0;
  info: string = '';
  children: MdBlock[] = [];
  ordered: boolean = false;
  start: number = 1;
  tight: boolean = true;

  constructor(type: number) {
    this.type = type;
  }
}

class ListMarker {
  ordered: boolean;
  bullet: string;
  start: number;
  contentIndent: number;
  rest: string;

  constructor(ordered: boolean, bullet: string, start: number, contentIndent: number, rest: string) {
    this.ordered = ordered;
    this.bullet = bullet;
    this.start = start;
    this.contentIndent = contentIndent;
    this.rest = rest;
  }
}

const RE_ATX: RegExp = new RegExp('^ {0,3}(#{1,6})(?:[ \\t]+|$)(.*)$');
const RE_HR: RegExp = new RegExp('^ {0,3}((\\*[ \\t]*){3,}|(-[ \\t]*){3,}|(_[ \\t]*){3,})$');
const RE_FENCE: RegExp = new RegExp('^( {0,3})(`{3,}|~{3,})(.*)$');
const RE_SETEXT: RegExp = new RegExp('^ {0,3}(=+|-+)[ \\t]*$');
const RE_BULLET: RegExp = new RegExp('^( {0,3})([-+*])([ \\t]+|$)(.*)$');
const RE_ORDERED: RegExp = new RegExp('^( {0,3})(\\d{1,9})([.)])([ \\t]+|$)(.*)$');
const RE_HTML_BLOCK: RegExp = new RegExp(
  '^ {0,3}(<!--|<\\/?(address|article|aside|blockquote|body|center|details|div|dl|fieldset|figcaption|figure|' +
    'footer|form|h[1-6]|header|hr|html|li|main|nav|ol|p|pre|section|table|tbody|td|tfoot|th|thead|tr|ul)(\\s|/?>|$))',
  'i');

function isBlank(line: string): boolean {
  return line.trim().length === 0;
}

function leadingSpaces(line: string): number {
  let n: number = 0;
  for (let i = 0; i < line.length; i++) {
    const c: string = line.charAt(i);
    if (c === ' ') {
      n++;
    } else if (c === '\t') {
      n += 4 - (n % 4);
    } else {
      break;
    }
  }
  return n;
}

/** 去掉至多 n 列前导空白 */
function stripIndent(line: string, n: number): string {
  let col: number = 0;
  let i: number = 0;
  while (i < line.length && col < n) {
    const c: string = line.charAt(i);
    if (c === ' ') {
      col++;
    } else if (c === '\t') {
      col += 4 - (col % 4);
    } else {
      break;
    }
    i++;
  }
  return line.substring(i);
}

export function escapeHtml(text: string): string {
  return text.split('&').join('&amp;').split('<').join('&lt;').split('>').join('&gt;')
    .split('"').join('&quot;').split('\'').join('&#39;');
}

function parseListMarker(line: string): ListMarker | null {
  if (RE_HR.test(line)) {
    return null;
  }
  const b: RegExpMatchArray | null = line.match(RE_BULLET);
  if (b !== null) {
    const spaces: number = b[3].length === 0 ? 1 : (b[3].length > 4 ? 1 : b[3].length);
    return new ListMarker(false, b[2], 1, b[1].length + 1 + spaces, b[3].length > 4 ? b[3].substring(1) + b[4] : b[4]);
  }
  const o: RegExpMatchArray | null = line.match(RE_ORDERED);
  if (o !== null) {
    const spaces: number = o[4].length === 0 ? 1 : (o[4].length > 4 ? 1 : o[4].length);
    return new ListMarker(true, o[3], parseInt(o[2], 10), o[1].length + o[2].length + 1 + spaces,
      o[4].length > 4 ? o[4].substring(1) + o[5] : o[5]);
  }
  return null;
}

/** 该行是否开始一个非段落块（用于结束段落 / 惰性续行判定） */
function startsBlock(line: string): boolean {
  if (RE_ATX.test(line) || RE_HR.test(line) || RE_FENCE.test(line) || RE_HTML_BLOCK.test(line)) {
    return true;
  }
  if (/* blockquote */ stripIndent(line, 3).startsWith('>') && leadingSpaces(line) < 4) {
    return true;
  }
  const m: ListMarker | null = parseListMarker(line);
  // 段落中只有 "1." 开头的有序列表与非空列表项能打断段落（CommonMark）
  return m !== null && m.rest.trim().length > 0 && (!m.ordered || m.start === 1);
}

class BlockParser {
  parse(lines: string[]): MdBlock[] {
    const out: MdBlock[] = [];
    let i: number = 0;
    while (i < lines.length) {
      const line: string = lines[i];
      if (isBlank(line)) {
        i++;
        continue;
      }
      const indent: number = leadingSpaces(line);
      if (indent >= 4) {
        const code: MdBlock = new MdBlock(B_CODE);
        while (i < lines.length && (isBlank(lines[i]) || leadingSpaces(lines[i]) >= 4)) {
          code.lines.push(stripIndent(lines[i], 4));
          i++;
        }
        while (code.lines.length > 0 && isBlank(code.lines[code.lines.length - 1])) {
          code.lines.pop();
        }
        out.push(code);
        continue;
      }
      const atx: RegExpMatchArray | null = line.match(RE_ATX);
      if (atx !== null) {
        const h: MdBlock = new MdBlock(B_HEADING);
        h.level = atx[1].length;
        h.lines.push(atx[2].replace(new RegExp('(^|[ \\t]+)#+[ \\t]*$'), '').trim());
        out.push(h);
        i++;
        continue;
      }
      if (RE_HR.test(line)) {
        out.push(new MdBlock(B_HR));
        i++;
        continue;
      }
      const fence: RegExpMatchArray | null = line.match(RE_FENCE);
      if (fence !== null && !(fence[2].charAt(0) === '`' && fence[3].indexOf('`') >= 0)) {
        i = this.parseFence(lines, i, fence, out);
        continue;
      }
      if (RE_HTML_BLOCK.test(line)) {
        const html: MdBlock = new MdBlock(B_HTML);
        while (i < lines.length && !isBlank(lines[i])) {
          html.lines.push(lines[i]);
          i++;
        }
        out.push(html);
        continue;
      }
      if (stripIndent(line, 3).startsWith('>')) {
        i = this.parseQuote(lines, i, out);
        continue;
      }
      if (parseListMarker(line) !== null) {
        i = this.parseList(lines, i, out);
        continue;
      }
      i = this.parseParagraph(lines, i, out);
    }
    return out;
  }

  private parseFence(lines: string[], start: number, fence: RegExpMatchArray, out: MdBlock[]): number {
    const code: MdBlock = new MdBlock(B_CODE);
    const indent: number = fence[1].length;
    const marker: string = fence[2];
    code.info = fence[3].trim();
    let i: number = start + 1;
    while (i < lines.length) {
      const l: string = lines[i];
      const t: string = stripIndent(l, 3);
      if (leadingSpaces(l) < 4 && t.startsWith(marker.charAt(0).repeat(marker.length)) &&
        t.replace(new RegExp('^[`~]+'), '').trim().length === 0 && t.charAt(0) === marker.charAt(0)) {
        i++;
        break;
      }
      code.lines.push(stripIndent(l, indent));
      i++;
    }
    out.push(code);
    return i;
  }

  private parseQuote(lines: string[], start: number, out: MdBlock[]): number {
    const inner: string[] = [];
    let i: number = start;
    let lastWasPara: boolean = false;
    while (i < lines.length) {
      const l: string = lines[i];
      const t: string = stripIndent(l, 3);
      if (leadingSpaces(l) < 4 && t.startsWith('>')) {
        let rest: string = t.substring(1);
        if (rest.startsWith(' ')) {
          rest = rest.substring(1);
        } else if (rest.startsWith('\t')) {
          rest = '  ' + rest.substring(1);
        }
        inner.push(rest);
        lastWasPara = !isBlank(rest) && !startsBlock(rest);
        i++;
      } else if (lastWasPara && !isBlank(l) && !startsBlock(l)) {
        inner.push(l); // 惰性续行
        i++;
      } else {
        break;
      }
    }
    const q: MdBlock = new MdBlock(B_QUOTE);
    q.children = this.parse(inner);
    out.push(q);
    return i;
  }

  private parseList(lines: string[], start: number, out: MdBlock[]): number {
    const first: ListMarker | null = parseListMarker(lines[start]);
    if (first === null) {
      return start + 1;
    }
    const list: MdBlock = new MdBlock(B_LIST);
    list.ordered = first.ordered;
    list.start = first.start;
    let i: number = start;
    let sawBlankBetween: boolean = false;
    while (i < lines.length) {
      const m: ListMarker | null = leadingSpaces(lines[i]) < 4 ? parseListMarker(lines[i]) : null;
      if (m === null || m.ordered !== first.ordered || m.bullet !== first.bullet) {
        break;
      }
      const itemLines: string[] = [m.rest];
      i++;
      let lastWasPara: boolean = m.rest.trim().length > 0;
      let pendingBlank: number = 0;
      while (i < lines.length) {
        const l: string = lines[i];
        if (isBlank(l)) {
          pendingBlank++;
          i++;
          continue;
        }
        if (leadingSpaces(l) >= m.contentIndent) {
          for (let k = 0; k < pendingBlank; k++) {
            itemLines.push('');
          }
          pendingBlank = 0;
          const stripped: string = stripIndent(l, m.contentIndent);
          itemLines.push(stripped);
          lastWasPara = !startsBlock(stripped);
          i++;
          continue;
        }
        if (pendingBlank === 0 && lastWasPara && !startsBlock(l) && parseListMarker(l) === null) {
          itemLines.push(l); // 惰性续行
          i++;
          continue;
        }
        break;
      }
      const item: MdBlock = new MdBlock(B_ITEM);
      item.children = this.parse(itemLines);
      let innerBlank: boolean = false;
      for (let k = 1; k < itemLines.length - 1; k++) {
        if (isBlank(itemLines[k]) && item.children.length > 1) {
          innerBlank = true;
        }
      }
      if (innerBlank) {
        list.tight = false;
      }
      list.children.push(item);
      if (pendingBlank > 0) {
        const next: ListMarker | null = i < lines.length && leadingSpaces(lines[i]) < 4 ? parseListMarker(lines[i]) : null;
        if (next !== null && next.ordered === first.ordered && next.bullet === first.bullet) {
          sawBlankBetween = true;
        } else {
          break; // 列表结束（其后的空行已被跳过，不影响后续块）
        }
      }
    }
    if (sawBlankBetween) {
      list.tight = false;
    }
    out.push(list);
    return i;
  }

  private parseParagraph(lines: string[], start: number, out: MdBlock[]): number {
    const p: MdBlock = new MdBlock(B_PARA);
    let i: number = start;
    p.lines.push(lines[i]);
    i++;
    while (i < lines.length) {
      const l: string = lines[i];
      if (isBlank(l)) {
        break;
      }
      const se: RegExpMatchArray | null = leadingSpaces(l) < 4 ? l.match(RE_SETEXT) : null;
      if (se !== null) {
        const h: MdBlock = new MdBlock(B_HEADING);
        h.level = se[1].charAt(0) === '=' ? 1 : 2;
        h.lines = p.lines;
        out.push(h);
        return i + 1;
      }
      if (startsBlock(l)) {
        break;
      }
      p.lines.push(l);
      i++;
    }
    out.push(p);
    return i;
  }
}

// ---------------------------------------------------------------- 渲染

function renderBlocks(blocks: MdBlock[], tight: boolean): string {
  let out: string = '';
  for (let i = 0; i < blocks.length; i++) {
    const b: MdBlock = blocks[i];
    if (b.type === B_PARA) {
      const text: string = b.lines.map((l: string) => l.replace(new RegExp('^[ \\t]+'), '')).join('\n')
        .replace(new RegExp('[ \\t]+$'), '');
      out += tight ? renderInline(text) : '<p>' + renderInline(text) + '</p>';
    } else if (b.type === B_HEADING) {
      const text: string = b.lines.map((l: string) => l.trim()).join('\n');
      out += `<h${b.level}>` + renderInline(text) + `</h${b.level}>`;
    } else if (b.type === B_HR) {
      out += '<hr />';
    } else if (b.type === B_CODE) {
      const lang: string = b.info.length > 0 ? ' class="language-' + escText(b.info.split(' ')[0]) + '"' : '';
      const body: string = b.lines.length > 0 ? b.lines.join('\n') + '\n' : '';
      out += '<pre><code' + lang + '>' + escText(body) + '</code></pre>';
    } else if (b.type === B_QUOTE) {
      out += '<blockquote>' + renderBlocks(b.children, false) + '</blockquote>';
    } else if (b.type === B_LIST) {
      const tagName: string = b.ordered ? 'ol' : 'ul';
      const startAttr: string = b.ordered && b.start !== 1 ? ` start="${b.start}"` : '';
      out += '<' + tagName + startAttr + '>';
      for (let k = 0; k < b.children.length; k++) {
        out += '<li>' + renderBlocks(b.children[k].children, b.tight) + '</li>';
      }
      out += '</' + tagName + '>';
    } else if (b.type === B_HTML) {
      out += b.lines.join('\n');
    }
  }
  return out;
}

export class MarkdownToHtmlConverter {
  /** Converts Markdown text to HTML；空白 → ''；失败 → HTML 转义原文 */
  convertToHtml(markdown: string): string {
    if (markdown.trim().length === 0) {
      return '';
    }
    try {
      const lines: string[] = markdown.split('\r\n').join('\n').split('\r').join('\n').split('\n');
      const blocks: MdBlock[] = new BlockParser().parse(lines);
      return '<body>' + renderBlocks(blocks, false) + '</body>';
    } catch (e) {
      // If Markdown processing fails, return the original text escaped for HTML
      return escapeHtml(markdown);
    }
  }

  /** Converts Markdown text to plain text：先转 HTML 再去标签（不解实体，照源） */
  convertToPlainText(markdown: string): string {
    if (markdown.trim().length === 0) {
      return '';
    }
    try {
      return this.convertToHtml(markdown).replace(new RegExp('<[^>]*>', 'g'), '');
    } catch (e) {
      return markdown.replace(new RegExp('\\*\\*(.*?)\\*\\*', 'g'), '$1')
        .replace(new RegExp('\\*(.*?)\\*', 'g'), '$1')
        .replace(new RegExp('`(.*?)`', 'g'), '$1');
    }
  }
}
