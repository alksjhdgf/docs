/**
 * RichText.ets —— 源 LinearArticleContent.kt 的 LinearTextContent / LinearText.toAnnotatedString（:616-639, :922-1048）、
 * ui/compose/text/Bidi.kt（WithBidiDeterminedLayoutDirection）、HtmlToComposable.kt（asFontFamily）、
 * 的鸿蒙实现。
 *
 * - LinearText + 注解 → Text { Span… }：注解边界切段，按注解顺序合并样式（后者覆盖同属性，≙ SpanStyle.merge）；
 *   Bold/Italic/Underline/Strikethrough/Superscript/Subscript（baselineOffset ±0.5em）/H1–H6（统一 headlineSmall，不分级）/
 *   Monospace 与 Font(face)（用户等宽/衬线/无衬线字体）/Code（非 CODE_BLOCK：surfaceVariant 背景 + 等宽）/
 *   Link（primary + 下划线，可点击，onLinkClick(href, index)）。
 * - 每段落按内容独立判方向（首个强方向字符；无强字符 → LTR）。
 * - 字号与行高 × fontScale（源 ProvideScaledText）；Text 可长按选择复制（copyOption）。
 * - 正文链接路由（锚点滚动 / 应用内播放器 / ActivityLauncher）在 ArticleLinks.ets（按单文件 ≤600 行拆出）。
 * - AnnotatedParagraphList：HtmlSpeech 段落逐段显示（AI 摘要卡片，段间距 8，链接不可点、无链接样式）。
 */
import { LengthMetrics } from '@kit.ArkUI';
import {
  LinearText,
  LinearTextAnnotation,
  LinearTextAnnotationKind,
  LinearTextAnnotationLink,
  LinearTextAnnotationFont,
  LinearTextBlockStyle
} from '../../core/html/LinearArticle';
import { FeederTheme } from './Theme';
import {
  FeederTypography,
  M3Type,
  TextStyleSpec,
  TextStyleModifier,
  WEIGHT_BOLD,
  WEIGHT_NORMAL,
  FAMILY_SYSTEM_MONO
} from './Typography';
import { AnnotatedParagraph, AnnotatedSpanStyle, AnnotatedStyleRange } from './HtmlSpeech';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

// =============================================================================================
// 链接点击回调契约
// =============================================================================================

/** 源 onLinkClick: (url: String, index: Int?) -> Unit */
export type ArticleLinkClick = (url: string, index: number | null) => void;

/**
 * 源链接锚点解析（LAC:978-985）：href 按 '#' split，段数 > 1 取最后一段查 idToIndex；否则 / 查不到 → null。
 * 注意：不区分同页/跨页（照源）。
 */
export function linkTargetIndex(href: string, idToIndex: Map<string, number>): number | null {
  const parts: string[] = href.split('#');
  if (parts.length > 1) {
    const v: number | undefined = idToIndex.get(parts[parts.length - 1]);
    return v === undefined ? null : v;
  }
  return null;
}

// =============================================================================================
// Bidi（源 Bidi.kt：java.text.Bidi(paragraph, DIRECTION_DEFAULT_LEFT_TO_RIGHT).baseIsLeftToRight()）
// =============================================================================================

function inRange(cp: number, lo: number, hi: number): boolean {
  return cp >= lo && cp <= hi;
}

/** 强 RTL（BidiClass R / AL）：希伯来/阿拉伯/叙利亚/它拿/N'Ko 等区块，排除其中的 NSM 组合符与 AN/EN 数字 */
function isStrongRtl(cp: number): boolean {
  const inBlock: boolean = inRange(cp, 0x0590, 0x08FF) || inRange(cp, 0xFB1D, 0xFDFF) || inRange(cp, 0xFE70, 0xFEFF) ||
    inRange(cp, 0x10800, 0x10FFF) || inRange(cp, 0x1E800, 0x1EFFF);
  if (!inBlock) {
    return false;
  }
  if (inRange(cp, 0x0591, 0x05BD) || cp === 0x05BF || inRange(cp, 0x05C1, 0x05C2) || inRange(cp, 0x05C4, 0x05C5) ||
    cp === 0x05C7) {
    return false; // 希伯来点符（NSM）
  }
  if (inRange(cp, 0x0600, 0x0605) || inRange(cp, 0x0610, 0x061A) || inRange(cp, 0x064B, 0x066C) || cp === 0x0670 ||
    inRange(cp, 0x06D6, 0x06DC) || inRange(cp, 0x06DF, 0x06E4) || inRange(cp, 0x06E7, 0x06E8) ||
    inRange(cp, 0x06EA, 0x06ED) || inRange(cp, 0x06F0, 0x06F9) || inRange(cp, 0x08D3, 0x08FF)) {
    return false; // 阿拉伯数字（AN/EN）与组合符（NSM）
  }
  return true;
}

/** 强 LTR（BidiClass L）近似：拉丁/希腊/西里尔/亚美尼亚/印度系/东南亚/格鲁吉亚/CJK/假名/谚文等字母区块 */
function isStrongLtr(cp: number): boolean {
  if (cp < 0x80) {
    return inRange(cp, 0x41, 0x5A) || inRange(cp, 0x61, 0x7A);
  }
  if (cp === 0xAA || cp === 0xB5 || cp === 0xBA) {
    return true;
  }
  if (inRange(cp, 0xC0, 0x2AF)) {
    return cp !== 0xD7 && cp !== 0xF7;
  }
  if (inRange(cp, 0x2B0, 0x36F)) {
    return false; // 修饰字母/组合附加符
  }
  if (inRange(cp, 0x370, 0x58F)) {
    return !inRange(cp, 0x483, 0x489) && cp !== 0x37E && cp !== 0x387;
  }
  if (inRange(cp, 0x900, 0x1FFF)) {
    return !inRange(cp, 0x1AB0, 0x1AFF) && !inRange(cp, 0x1DC0, 0x1DFF);
  }
  if (inRange(cp, 0x2000, 0x2BFF) || inRange(cp, 0x2E00, 0x2E7F) || inRange(cp, 0x3000, 0x303F)) {
    return false; // 标点/符号/箭头/CJK 标点
  }
  if (inRange(cp, 0x2C00, 0x2DFF) || inRange(cp, 0x2E80, 0x2FFF) || inRange(cp, 0x3040, 0xD7FF) ||
    inRange(cp, 0xF900, 0xFB1C)) {
    return true;
  }
  if (inRange(cp, 0xFF21, 0xFF3A) || inRange(cp, 0xFF41, 0xFF5A) || inRange(cp, 0xFF66, 0xFFDC)) {
    return true;
  }
  if (cp >= 0x10000) {
    return !inRange(cp, 0x1F000, 0x1FFFF) && !isStrongRtl(cp);
  }
  return false;
}

/**
 * 段落基础方向：首个强方向字符（Unicode 规则 P2/P3）；强 R/AL → RTL；强 L → LTR；
 * 数字/标点/空白/组合符等弱或中性字符跳过；无强字符 → LTR（DIRECTION_DEFAULT_LEFT_TO_RIGHT）。
 * java.text.Bidi 的完整 BidiClass 表无鸿蒙等价，这里按 Unicode 区块近似。
 */
export function bidiBaseIsLeftToRight(paragraph: string): boolean {
  let i: number = 0;
  while (i < paragraph.length) {
    const cp: number = paragraph.codePointAt(i) as number;
    i += cp > 0xFFFF ? 2 : 1;
    if (cp === 0x200F || cp === 0x061C) {
      return false; // RLM / ALM
    }
    if (cp === 0x200E) {
      return true; // LRM
    }
    if (isStrongRtl(cp)) {
      return false;
    }
    if (isStrongLtr(cp)) {
      return true;
    }
  }
  return true;
}

export function paragraphDirection(paragraph: string): Direction {
  return bidiBaseIsLeftToRight(paragraph) ? Direction.Ltr : Direction.Rtl;
}

// =============================================================================================
// 文本基础样式（源 ProvideTextStyle / LocalTextStyle 链）
// =============================================================================================

/** 主题颜色角色（build 中解析为当前主题色 → 切换主题即重绘） */
export enum ColorRole {
  ON_BACKGROUND = 0,
  ON_SURFACE = 1,
  ON_SURFACE_VARIANT = 2,
  PRIMARY = 3,
  TERTIARY = 4
}

export function colorOfRole(role: ColorRole): string {
  const c = FeederTheme.colors;
  switch (role) {
    case ColorRole.ON_SURFACE:
      return c.onSurface;
    case ColorRole.ON_SURFACE_VARIANT:
      return c.onSurfaceVariant;
    case ColorRole.PRIMARY:
      return c.primary;
    case ColorRole.TERTIARY:
      return c.tertiary;
    default:
      return c.onBackground;
  }
}

/** 段落文本的基础样式（≙ 当前 LocalTextStyle：字号表 + 字重覆盖 + 颜色角色） */
export class ArticleTextStyle {
  spec: TextStyleSpec = M3Type.bodyLarge;
  /** < 0 → 用 spec.weight */
  weight: number = -1;
  colorRole: ColorRole = ColorRole.ON_BACKGROUND;

  static of(spec: TextStyleSpec, weight: number, colorRole: ColorRole): ArticleTextStyle {
    const s: ArticleTextStyle = new ArticleTextStyle();
    s.spec = spec;
    s.weight = weight;
    s.colorRole = colorRole;
    return s;
  }

  effectiveWeight(): number {
    return this.weight >= 0 ? this.weight : this.spec.weight;
  }

  withWeight(weight: number): ArticleTextStyle {
    return ArticleTextStyle.of(this.spec, weight, this.colorRole);
  }

  withColor(role: ColorRole): ArticleTextStyle {
    return ArticleTextStyle.of(this.spec, this.weight, role);
  }

  key(): string {
    return this.spec.size + '/' + this.spec.lineHeight + '/' + this.effectiveWeight() + '/' + this.colorRole;
  }
}

/** 正文默认：bodyLarge + onBackground（源 ColumnArticleContent 的 ProvideTextStyle） */
export const ARTICLE_BODY_STYLE: ArticleTextStyle = ArticleTextStyle.of(M3Type.bodyLarge, -1, ColorRole.ON_BACKGROUND);

// =============================================================================================
// 注解 → 段（源 LinearText.toAnnotatedString）
// =============================================================================================

/** 源 String.asFontFamily(typographySettings)：monospace/serif/sans-serif（忽略大小写）→ 用户字体；其他 → null */
export function faceAsFontFamily(face: string): string | null {
  const f: string = face.toLowerCase();
  if (f === 'monospace') {
    return FeederTypography.monoFamily;
  }
  if (f === 'serif') {
    return FeederTypography.serifFamily;
  }
  if (f === 'sans-serif') {
    return FeederTypography.sansFamily;
  }
  return null;
}

/** 文本段：同一组样式覆盖的连续区间；null 字段 = 继承 Text 基础样式 */
export class RichSegment {
  text: string = '';
  start: number = 0;
  end: number = 0;
  weight: number | null = null;
  italic: boolean = false;
  /** 未缩放的绝对字号（H1–H6 = headlineSmall.size）；null = 基础字号 */
  size: number | null = null;
  letterSpacing: number | null = null;
  family: string | null = null;
  decoration: TextDecorationType = TextDecorationType.None;
  codeBackground: boolean = false;
  /** 1 = 上标，-1 = 下标，0 = 无 */
  baseline: number = 0;
  href: string | null = null;

  signature(): string {
    return this.start + ':' + this.end + ':' + String(this.weight) + ':' + this.italic + ':' + String(this.size) + ':' +
      String(this.family) + ':' + this.decoration + ':' + this.codeBackground + ':' + this.baseline + ':' +
      String(this.href);
  }
}

function applyAnnotation(seg: RichSegment, ann: LinearTextAnnotation, blockStyle: LinearTextBlockStyle): void {
  const data = ann.data;
  switch (data.kind) {
    case LinearTextAnnotationKind.BOLD:
      seg.weight = WEIGHT_BOLD;
      break;
    case LinearTextAnnotationKind.FONT: {
      const fam: string | null = faceAsFontFamily((data as LinearTextAnnotationFont).face);
      if (fam !== null) {
        seg.family = fam;
      }
      break;
    }
    case LinearTextAnnotationKind.H1:
    case LinearTextAnnotationKind.H2:
    case LinearTextAnnotationKind.H3:
    case LinearTextAnnotationKind.H4:
    case LinearTextAnnotationKind.H5:
    case LinearTextAnnotationKind.H6:
      // headlineSmall.toSpanStyle()：字号/字重/字距/字体族（不分级）
      seg.size = M3Type.headlineSmall.size;
      seg.weight = M3Type.headlineSmall.weight;
      seg.letterSpacing = M3Type.headlineSmall.letterSpacing;
      seg.family = FeederTypography.sansFamily;
      break;
    case LinearTextAnnotationKind.ITALIC:
      seg.italic = true;
      break;
    case LinearTextAnnotationKind.LINK:
      seg.href = (data as LinearTextAnnotationLink).href;
      break;
    case LinearTextAnnotationKind.MONOSPACE:
      seg.family = FeederTypography.monoFamily;
      break;
    case LinearTextAnnotationKind.CODE:
      // Code blocks are already styled on the block level
      if (blockStyle !== LinearTextBlockStyle.CODE_BLOCK) {
        seg.codeBackground = true;
        seg.family = FeederTypography.monoFamily;
      }
      break;
    case LinearTextAnnotationKind.SUBSCRIPT:
      seg.baseline = -1;
      break;
    case LinearTextAnnotationKind.SUPERSCRIPT:
      seg.baseline = 1;
      break;
    case LinearTextAnnotationKind.UNDERLINE:
      seg.decoration = TextDecorationType.Underline;
      break;
    case LinearTextAnnotationKind.STRIKETHROUGH:
      seg.decoration = TextDecorationType.LineThrough;
      break;
    default:
      break;
  }
}

/** 把 LinearText 按注解边界切段并合并样式（链接样式最后叠加：primary + 下划线） */
export function buildRichSegments(linearText: LinearText): RichSegment[] {
  const text: string = linearText.text;
  const len: number = text.length;
  if (len === 0) {
    return [];
  }
  const bounds: Set<number> = new Set<number>([0, len]);
  const anns: LinearTextAnnotation[] = linearText.annotations;
  for (let i = 0; i < anns.length; i++) {
    bounds.add(Math.max(0, Math.min(len, anns[i].start)));
    bounds.add(Math.max(0, Math.min(len, anns[i].endExclusive)));
  }
  const points: number[] = [];
  bounds.forEach((b: number) => {
    points.push(b);
  });
  points.sort((a: number, b: number): number => a - b);
  const out: RichSegment[] = [];
  for (let p = 0; p + 1 < points.length; p++) {
    const s: number = points[p];
    const e: number = points[p + 1];
    if (e <= s) {
      continue;
    }
    const seg: RichSegment = new RichSegment();
    seg.start = s;
    seg.end = e;
    seg.text = text.substring(s, e);
    for (let i = 0; i < anns.length; i++) {
      if (anns[i].start <= s && anns[i].endExclusive >= e) {
        applyAnnotation(seg, anns[i], linearText.blockStyle);
      }
    }
    if (seg.href !== null) {
      seg.decoration = TextDecorationType.Underline;
    }
    out.push(seg);
  }
  return out;
}

/** Span 样式修饰器（只在可点击分支额外绑 onClick） */
class RichSpanModifier implements AttributeModifier<SpanAttribute> {
  seg: RichSegment;
  baseSize: number;
  baseWeight: number;
  baseLetterSpacing: number;
  baseFamily: string;
  baseColor: string;

  constructor(seg: RichSegment, baseSize: number, baseWeight: number, baseLetterSpacing: number, baseFamily: string,
    baseColor: string) {
    this.seg = seg;
    this.baseSize = baseSize;
    this.baseWeight = baseWeight;
    this.baseLetterSpacing = baseLetterSpacing;
    this.baseFamily = baseFamily;
    this.baseColor = baseColor;
  }

  applyNormalAttribute(instance: SpanAttribute): void {
    const seg: RichSegment = this.seg;
    const size: number = seg.size !== null ? seg.size : this.baseSize;
    const color: string = seg.href !== null ? FeederTheme.colors.primary : this.baseColor;
    instance.fontSize(size);
    instance.fontWeight(seg.weight !== null ? seg.weight : this.baseWeight);
    instance.fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal);
    instance.fontFamily(seg.family !== null ? seg.family : this.baseFamily);
    instance.fontColor(color);
    instance.letterSpacing(seg.letterSpacing !== null ? seg.letterSpacing : this.baseLetterSpacing);
    instance.decoration({ type: seg.decoration, color: color });
    if (seg.codeBackground) {
      instance.textBackgroundStyle({ color: FeederTheme.colors.surfaceVariant, radius: 0 });
    }
    if (seg.baseline !== 0) {
      instance.baselineOffset(LengthMetrics.fp(seg.baseline * size * 0.5));
    }
  }
}

// =============================================================================================
// LinearTextContent（源 LinearTextContent）
// =============================================================================================

/**
 * 段落文本。fillWidth=true 时宽度撑满（RTL 段落右对齐可见）；表格单元格内为 false（单元格按内容定宽）。
 * softWrap=false（代码块）时不撑满，由外层横向 Scroll 提供无界宽度。
 */
@ComponentV2
export struct LinearTextContent {
  @Param linearText: LinearText = new LinearText(new Set<string>(), '', LinearTextBlockStyle.TEXT);
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param textStyle: ArticleTextStyle = ARTICLE_BODY_STYLE;
  @Param softWrap: boolean = true;
  @Param fillWidth: boolean = true;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:LinearTextContent ' + url + ' ' + String(index));
  };

  private baseModifier(): TextStyleModifier {
    const st: ArticleTextStyle = this.textStyle;
    return new TextStyleModifier(st.spec.withWeight(st.effectiveWeight()), FeederTypography.sansFamily,
      FeederTypography.fontScale, colorOfRole(st.colorRole));
  }

  private spanModifier(seg: RichSegment): RichSpanModifier {
    const st: ArticleTextStyle = this.textStyle;
    return new RichSpanModifier(seg, st.spec.size * FeederTypography.fontScale, st.effectiveWeight(),
      st.spec.letterSpacing, FeederTypography.sansFamily, colorOfRole(st.colorRole));
  }

  private clickLink(href: string): void {
    this.onLinkClick(href, linkTargetIndex(href, this.idToIndex));
  }

  build() {
    Text() {
      ForEach(buildRichSegments(this.linearText), (seg: RichSegment) => {
        if (seg.href !== null) {
          Span(seg.text)
            .attributeModifier(this.spanModifier(seg))
            .onClick(() => {
              this.clickLink(seg.href as string);
            })
        } else {
          Span(seg.text)
            .attributeModifier(this.spanModifier(seg))
        }
      }, (seg: RichSegment, i: number) => i + '|' + seg.signature() + '|' + seg.text)
    }
    .attributeModifier(this.baseModifier())
    .direction(paragraphDirection(this.linearText.text))
    .textAlign(TextAlign.Start)
    .copyOption(CopyOptions.LocalDevice)
    .editMenuOptions(new FeederEditMenuOptions((): string => this.linearText.text))
    .width(this.fillWidth && this.softWrap ? '100%' : 'auto')
  }
}

// =============================================================================================
// AnnotatedParagraph 显示（AI 摘要：源 ArticleScreen.SummarySection，HU-A38）
// =============================================================================================

export class ParagraphSegment {
  text: string = '';
  bold: boolean = false;
  italic: boolean = false;
  mono: boolean = false;
  baseline: number = 0;
}

/** AnnotatedParagraph → 段（Bold/Italic/Monospace(系统等宽)/上下标；URL 注解无样式不可点） */
export function paragraphSegments(p: AnnotatedParagraph): ParagraphSegment[] {
  const len: number = p.text.length;
  if (len === 0) {
    return [];
  }
  const bounds: Set<number> = new Set<number>([0, len]);
  for (let i = 0; i < p.styles.length; i++) {
    bounds.add(Math.max(0, Math.min(len, p.styles[i].start)));
    bounds.add(Math.max(0, Math.min(len, p.styles[i].end)));
  }
  const points: number[] = [];
  bounds.forEach((b: number) => {
    points.push(b);
  });
  points.sort((a: number, b: number): number => a - b);
  const out: ParagraphSegment[] = [];
  for (let k = 0; k + 1 < points.length; k++) {
    const s: number = points[k];
    const e: number = points[k + 1];
    if (e <= s) {
      continue;
    }
    const seg: ParagraphSegment = new ParagraphSegment();
    seg.text = p.text.substring(s, e);
    for (let i = 0; i < p.styles.length; i++) {
      const r: AnnotatedStyleRange = p.styles[i];
      if (r.start <= s && r.end >= e) {
        if (r.style === AnnotatedSpanStyle.BOLD) {
          seg.bold = true;
        } else if (r.style === AnnotatedSpanStyle.ITALIC) {
          seg.italic = true;
        } else if (r.style === AnnotatedSpanStyle.MONOSPACE) {
          seg.mono = true;
        } else if (r.style === AnnotatedSpanStyle.SUPERSCRIPT) {
          seg.baseline = 1;
        } else if (r.style === AnnotatedSpanStyle.SUBSCRIPT) {
          seg.baseline = -1;
        }
      }
    }
    out.push(seg);
  }
  return out;
}

/**
 * 段落列表（源 SummarySection Result 分支：Column(padding 8) 内逐段 Text，非末段 bottom padding 8）。
 * 卡片外框（OutlinedCard）与加载态由使用方（AI 摘要单元）提供。文字：bodyLarge（不缩放）+ onSurface。
 */
@ComponentV2
export struct AnnotatedParagraphList {
  @Param paragraphs: AnnotatedParagraph[] = [];

  build() {
    Column() {
      ForEach(this.paragraphs, (p: AnnotatedParagraph, index: number) => {
        Text() {
          ForEach(paragraphSegments(p), (seg: ParagraphSegment) => {
            Span(seg.text)
              .fontWeight(seg.bold ? WEIGHT_BOLD : WEIGHT_NORMAL)
              .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
              .fontFamily(seg.mono ? FAMILY_SYSTEM_MONO : FeederTypography.sansFamily)
              .baselineOffset(LengthMetrics.fp(seg.baseline * M3Type.bodyLarge.size * 0.5))
          }, (seg: ParagraphSegment, i: number) => i + '|' + seg.bold + seg.italic + seg.mono + seg.baseline + '|' +
          seg.text)
        }
        .attributeModifier(new TextStyleModifier(M3Type.bodyLarge, FeederTypography.sansFamily, 1.0,
          FeederTheme.colors.onSurface))
        .direction(paragraphDirection(p.text))
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(new FeederEditMenuOptions((): string => p.text))
        .width('100%')
        .padding({ bottom: index < this.paragraphs.length - 1 ? 8 : 0 })
      }, (p: AnnotatedParagraph, index: number) => index + '|' + p.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(8)
  }
}
