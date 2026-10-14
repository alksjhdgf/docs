/**
 * LinearTextAnnotation.ets —— 源 model/html/LinearTextAnnotation.kt + LinearTextBlockStyle（LinearStuff.kt:356）。
 * 注解闭区间 [start, end]，endExclusive = end + 1。（LinearArticle.ets 统一再导出）
 */
// =============================================================================================
// 文本块样式
// =============================================================================================

export enum LinearTextBlockStyle {
  TEXT = 'TEXT',
  PRE_FORMATTED = 'PRE_FORMATTED',
  CODE_BLOCK = 'CODE_BLOCK'
}

/** 源 LinearTextBlockStyle.shouldSoftWrap：仅 TEXT 软换行 */
export function shouldSoftWrap(style: LinearTextBlockStyle): boolean {
  return style === LinearTextBlockStyle.TEXT;
}

// =============================================================================================
// 文本注解（LinearTextAnnotation.kt）
// =============================================================================================

export enum LinearTextAnnotationKind {
  H1 = 'H1',
  H2 = 'H2',
  H3 = 'H3',
  H4 = 'H4',
  H5 = 'H5',
  H6 = 'H6',
  BOLD = 'Bold',
  ITALIC = 'Italic',
  MONOSPACE = 'Monospace',
  UNDERLINE = 'Underline',
  STRIKETHROUGH = 'Strikethrough',
  SUPERSCRIPT = 'Superscript',
  SUBSCRIPT = 'Subscript',
  FONT = 'Font',
  CODE = 'Code',
  LINK = 'Link'
}

/** 源 sealed interface LinearTextAnnotationData；data object 由下方常量单例表示 */
export class LinearTextAnnotationData {
  readonly kind: LinearTextAnnotationKind;

  constructor(kind: LinearTextAnnotationKind) {
    this.kind = kind;
  }

  isHeader(): boolean {
    return this.kind === LinearTextAnnotationKind.H1 || this.kind === LinearTextAnnotationKind.H2 ||
      this.kind === LinearTextAnnotationKind.H3 || this.kind === LinearTextAnnotationKind.H4 ||
      this.kind === LinearTextAnnotationKind.H5 || this.kind === LinearTextAnnotationKind.H6;
  }

  equals(other: LinearTextAnnotationData): boolean {
    return this.toString() === other.toString();
  }

  toString(): string {
    return this.kind;
  }
}

/** 源 data class LinearTextAnnotationLink(href) */
export class LinearTextAnnotationLink extends LinearTextAnnotationData {
  readonly href: string;

  constructor(href: string) {
    super(LinearTextAnnotationKind.LINK);
    this.href = href;
  }

  toString(): string {
    return 'Link(' + this.href + ')';
  }
}

/** 源 data class LinearTextAnnotationFont(face) */
export class LinearTextAnnotationFont extends LinearTextAnnotationData {
  readonly face: string;

  constructor(face: string) {
    super(LinearTextAnnotationKind.FONT);
    this.face = face;
  }

  toString(): string {
    return 'Font(' + this.face + ')';
  }
}

export const LinearTextAnnotationH1: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H1);
export const LinearTextAnnotationH2: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H2);
export const LinearTextAnnotationH3: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H3);
export const LinearTextAnnotationH4: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H4);
export const LinearTextAnnotationH5: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H5);
export const LinearTextAnnotationH6: LinearTextAnnotationData = new LinearTextAnnotationData(LinearTextAnnotationKind.H6);
export const LinearTextAnnotationBold: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.BOLD);
export const LinearTextAnnotationItalic: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.ITALIC);
export const LinearTextAnnotationMonospace: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.MONOSPACE);
export const LinearTextAnnotationUnderline: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.UNDERLINE);
export const LinearTextAnnotationStrikethrough: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.STRIKETHROUGH);
export const LinearTextAnnotationSuperscript: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.SUPERSCRIPT);
export const LinearTextAnnotationSubscript: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.SUBSCRIPT);
export const LinearTextAnnotationCode: LinearTextAnnotationData =
  new LinearTextAnnotationData(LinearTextAnnotationKind.CODE);

/** 源 data class LinearTextAnnotation(data, start 含, end 含) */
export class LinearTextAnnotation {
  readonly data: LinearTextAnnotationData;
  /** Inclusive start index */
  readonly start: number;
  /** Inclusive end index */
  end: number;

  constructor(data: LinearTextAnnotationData, start: number, end: number) {
    this.data = data;
    this.start = start;
    this.end = end;
  }

  get endExclusive(): number {
    return this.end + 1;
  }

  toString(): string {
    return this.data.toString() + ' ' + this.start + '..' + this.end;
  }
}
