/**
 * LinearTextBuilder.ets —— 源 model/html/LinearTextBuilder.kt：带注解栈的文本构建器 + 空白规整工具。
 * （从 HtmlLinearizer.ets 拆出以满足单文件 ≤600 行。）
 *
 * - push 记录 start；pop 设 end = text.lastIndex（闭区间）；
 * - toLinearText：trimEnd（Kotlin Char.isWhitespace 语义）并把注解夹到新长度内，非法注解丢弃；
 * - clearKeepingSpans：清空文本与已完成注解，仍打开的注解 start 重置为 0（跨块延续行内样式，HM-A15）；
 * - endsWithWhitespace：空 builder 视为以空白结尾（行首空白被吃掉）。
 * 下标均为 UTF-16 code unit（与 Kotlin String 一致）。
 */
import {
  LinearText,
  LinearTextAnnotation,
  LinearTextAnnotationData,
  LinearTextAnnotationLink,
  LinearTextBlockStyle
} from './LinearArticle';

export const SPACE_CODE: number = 32;
const TAB_CODE: number = 9;
const LINE_FEED_CODE: number = 10;
const CARRIAGE_RETURN_CODE: number = 13;
// 12 is form feed
const FORM_FEED_CODE: number = 12;
// 160 is &nbsp; (non-breaking space). Not in the spec but expected.
const NON_BREAKING_SPACE_CODE: number = 160;

/** 源 isCollapsableWhiteSpaceCode */
export function isCollapsableWhiteSpaceCode(c: number): boolean {
  return c === SPACE_CODE || c === TAB_CODE || c === LINE_FEED_CODE || c === CARRIAGE_RETURN_CODE ||
    c === FORM_FEED_CODE || c === NON_BREAKING_SPACE_CODE;
}

/** Kotlin Char.isWhitespace()：Character.isWhitespace || Character.isSpaceChar */
export function kotlinIsWhitespace(c: number): boolean {
  if ((c >= 0x09 && c <= 0x0D) || (c >= 0x1C && c <= 0x20)) {
    return true;
  }
  return c === 0xA0 || c === 0x1680 || (c >= 0x2000 && c <= 0x200A) || c === 0x2028 || c === 0x2029 ||
    c === 0x202F || c === 0x205F || c === 0x3000;
}

/** Kotlin String.trimEnd() */
export function kotlinTrimEnd(s: string): string {
  let end: number = s.length;
  while (end > 0 && kotlinIsWhitespace(s.charCodeAt(end - 1))) {
    end--;
  }
  return end === s.length ? s : s.substring(0, end);
}

/** Kotlin String.isBlank() */
export function kotlinIsBlank(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    if (!kotlinIsWhitespace(s.charCodeAt(i))) {
      return false;
    }
  }
  return true;
}

class MutableRange {
  item: LinearTextAnnotationData;
  start: number;
  end: number | null;

  constructor(item: LinearTextAnnotationData, start: number, end: number | null = null) {
    this.item = item;
    this.start = start;
    this.end = end;
  }
}

export class LinearTextBuilder {
  private text: string = '';
  private annotations: MutableRange[] = [];
  private annotationsStack: MutableRange[] = [];
  private lastCodePoint: number | null = null;
  private idsInternal: Set<string> = new Set<string>();

  /** 注意：返回内部集合（只读使用）；需要快照时自行复制 */
  get ids(): Set<string> {
    return this.idsInternal;
  }

  get length(): number {
    return this.text.length;
  }

  get endsWithWhitespace(): boolean {
    return isCollapsableWhiteSpaceCode(this.lastCodePoint !== null ? this.lastCodePoint : SPACE_CODE);
  }

  pushId(id: string): void {
    if (!kotlinIsBlank(id)) {
      this.idsInternal.add(id);
    }
  }

  append(text: string): void {
    if (text.length > 0) {
      // codePointBefore(length)：仅用于空白判定/非空判定，取末个 code unit 等价
      this.lastCodePoint = text.charCodeAt(text.length - 1);
    }
    this.text += text;
  }

  /**
   * Applies the given annotation to any appended text until a corresponding pop is called.
   * @returns the index of the pushed annotation
   */
  push(annotation: LinearTextAnnotationData): number {
    const r: MutableRange = new MutableRange(annotation, this.text.length);
    this.annotations.push(r);
    this.annotationsStack.push(r);
    return this.annotationsStack.length - 1;
  }

  /** Ends the style or annotation that was added via a push operation before. */
  pop(): void {
    if (this.annotationsStack.length === 0) {
      throw new Error('No annotation to pop');
    }
    const item: MutableRange = this.annotationsStack.pop() as MutableRange;
    item.end = this.text.length - 1;
  }

  /** Ends the annotation up to and including the push that returned the given index. */
  popTo(index: number): void {
    if (index < 0 || index >= this.annotationsStack.length) {
      throw new Error('No annotation at index ' + index + ': annotations size ' + this.annotationsStack.length);
    }
    while (this.annotationsStack.length - 1 >= index) {
      this.pop();
    }
  }

  toLinearText(blockStyle: LinearTextBlockStyle): LinearText {
    // Chop of possible ending whitespace - looks bad in code blocks for instance
    const trimmed: string = kotlinTrimEnd(this.text);
    const lastIndex: number = trimmed.length - 1;
    const result: LinearTextAnnotation[] = [];
    for (let i = 0; i < this.annotations.length; i++) {
      const it: MutableRange = this.annotations[i];
      const start: number = Math.min(it.start, lastIndex);
      const end: number = Math.min(it.end !== null ? it.end : this.text.length - 1, lastIndex);
      if (start < 0 || end < 0 || start > end) {
        // This can happen if the link encloses an image for example
        continue;
      }
      result.push(new LinearTextAnnotation(it.item, start, end));
    }
    // Copy the set to avoid modifications
    return new LinearText(new Set<string>(this.idsInternal), trimmed, blockStyle, result);
  }

  /** Clears the text and resets annotations to start at the beginning */
  clearKeepingSpans(): void {
    this.idsInternal.clear();
    this.text = '';
    this.lastCodePoint = null;
    // Get rid of completed annotations
    this.annotations = [];
    for (let i = 0; i < this.annotationsStack.length; i++) {
      const it: MutableRange = this.annotationsStack[i];
      it.start = 0;
      it.end = null;
      this.annotations.push(it);
    }
  }

  findClosestLink(): string | null {
    for (let i = this.annotationsStack.length - 1; i >= 0; i--) {
      const item: LinearTextAnnotationData = this.annotationsStack[i].item;
      if (item instanceof LinearTextAnnotationLink) {
        return (item as LinearTextAnnotationLink).href;
      }
    }
    return null;
  }

  isEmpty(): boolean {
    return this.lastCodePoint === null;
  }

  isNotEmpty(): boolean {
    return !this.isEmpty();
  }
}

/**
 * 源 TextNode.appendCorrectlyNormalizedWhiteSpace：可折叠空白（空格/\t/\n/\r/FF/NBSP）→ 单个空格，
 * 前一字符为空白则丢弃；其它字符原样（保留 ZWNJ 等不可见字符，不得用 text()）。
 */
export function appendCorrectlyNormalizedWhiteSpace(wholeText: string, builder: LinearTextBuilder): void {
  let out: string = '';
  let endsWs: boolean = builder.endsWithWhitespace;
  let runStart: number = 0;
  for (let i = 0; i < wholeText.length; i++) {
    const c: number = wholeText.charCodeAt(i);
    if (isCollapsableWhiteSpaceCode(c)) {
      if (i > runStart) {
        out += wholeText.substring(runStart, i);
      }
      runStart = i + 1;
      if (!endsWs) {
        out += ' ';
        endsWs = true;
      }
    } else {
      endsWs = false;
    }
  }
  if (runStart < wholeText.length) {
    out += wholeText.substring(runStart);
  }
  if (out.length > 0) {
    builder.append(out);
  }
}

/** 源 appendOneNormalizedWhitespace */
export function appendOneNormalizedWhitespace(builder: LinearTextBuilder): void {
  if (!builder.endsWithWhitespace) {
    builder.append(' ');
  }
}
