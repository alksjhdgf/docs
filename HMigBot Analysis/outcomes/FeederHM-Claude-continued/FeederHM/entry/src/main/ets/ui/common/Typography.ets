/*
 * Typography — 源 ui/compose/theme/Typography.kt + utils/ProvideScaledText.kt 的鸿蒙实现。
 *  - M3 15 级字号表（MaterialTheme.typography 默认值），全部样式统一使用当前 sans 字体族（UC-A23）。
 *  - 字体选择：bundled/roboto_flex → 内置 Roboto Flex（rawfile/fonts/roboto_flex.ttf，registerFont）；
 *    system/default → 系统默认；用户字体 → filesDir/fonts/<path>（文件缺失或不是字体文件 → 回退 Roboto Flex，UC-A25）。
 *  - 等宽：Roboto Flex → 内置 Roboto Mono；其余 → 系统等宽（UC-A24）。
 *  - fontScale（textScale 设置）只作用于 ProvideScaledText 的区域：scaledStyle()/textStyle(spec, true)。
 *  - 字体状态为 @ObservedV2 单例 FeederTypography，组件 build 中读取 → 切换字体立即重绘（UC-A20）。
 */
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { getFontMetadata } from '../../core/repo/FontStore';
import {
  PREF_FONT,
  PREF_TEXT_SCALE,
  FONT_PATH_ROBOTO_FLEX,
  FONT_PATH_SYSTEM_DEFAULT,
  FONTS_DIR_NAME
} from '../../core/settings/SettingsKeys';

// ------------------------------------------------------------------ 字体族名
export const FAMILY_ROBOTO_FLEX: string = 'FeederRobotoFlex';
export const FAMILY_ROBOTO_MONO: string = 'FeederRobotoMono';
/** 鸿蒙系统默认无衬线字体族 */
export const FAMILY_SYSTEM_SANS: string = 'HarmonyOS Sans';
/** 系统等宽/衬线：交给系统字体回退（generic family 名） */
export const FAMILY_SYSTEM_MONO: string = 'monospace';
export const FAMILY_SYSTEM_SERIF: string = 'serif';
const USER_FAMILY_PREFIX: string = 'FeederUserFont_';

// ------------------------------------------------------------------ 字重（源 FontWeight 数值）
export const WEIGHT_LIGHT: number = 300;
export const WEIGHT_NORMAL: number = 400;
export const WEIGHT_MEDIUM: number = 500;
export const WEIGHT_BOLD: number = 700;
export const WEIGHT_BLACK: number = 900;

/** 源 titleFontWeight(unread)：未读 Black，已读 Normal（UC-A26） */
export function titleFontWeight(unread: boolean): number {
  return unread ? WEIGHT_BLACK : WEIGHT_NORMAL;
}

// ------------------------------------------------------------------ M3 字号表
export class TextStyleSpec {
  size: number = 14;
  lineHeight: number = 20;
  weight: number = WEIGHT_NORMAL;
  letterSpacing: number = 0;

  static of(size: number, lineHeight: number, weight: number, letterSpacing: number): TextStyleSpec {
    const s = new TextStyleSpec();
    s.size = size;
    s.lineHeight = lineHeight;
    s.weight = weight;
    s.letterSpacing = letterSpacing;
    return s;
  }

  withWeight(weight: number): TextStyleSpec {
    return TextStyleSpec.of(this.size, this.lineHeight, weight, this.letterSpacing);
  }
}

/** androidx.compose.material3.Typography() 默认值（sp→fp 1:1） */
export class M3Type {
  static readonly displayLarge: TextStyleSpec = TextStyleSpec.of(57, 64, WEIGHT_NORMAL, -0.25);
  static readonly displayMedium: TextStyleSpec = TextStyleSpec.of(45, 52, WEIGHT_NORMAL, 0);
  static readonly displaySmall: TextStyleSpec = TextStyleSpec.of(36, 44, WEIGHT_NORMAL, 0);
  static readonly headlineLarge: TextStyleSpec = TextStyleSpec.of(32, 40, WEIGHT_NORMAL, 0);
  static readonly headlineMedium: TextStyleSpec = TextStyleSpec.of(28, 36, WEIGHT_NORMAL, 0);
  static readonly headlineSmall: TextStyleSpec = TextStyleSpec.of(24, 32, WEIGHT_NORMAL, 0);
  static readonly titleLarge: TextStyleSpec = TextStyleSpec.of(22, 28, WEIGHT_NORMAL, 0);
  static readonly titleMedium: TextStyleSpec = TextStyleSpec.of(16, 24, WEIGHT_MEDIUM, 0.15);
  static readonly titleSmall: TextStyleSpec = TextStyleSpec.of(14, 20, WEIGHT_MEDIUM, 0.1);
  static readonly bodyLarge: TextStyleSpec = TextStyleSpec.of(16, 24, WEIGHT_NORMAL, 0.5);
  static readonly bodyMedium: TextStyleSpec = TextStyleSpec.of(14, 20, WEIGHT_NORMAL, 0.25);
  static readonly bodySmall: TextStyleSpec = TextStyleSpec.of(12, 16, WEIGHT_NORMAL, 0.4);
  static readonly labelLarge: TextStyleSpec = TextStyleSpec.of(14, 20, WEIGHT_MEDIUM, 0.1);
  static readonly labelMedium: TextStyleSpec = TextStyleSpec.of(12, 16, WEIGHT_MEDIUM, 0.5);
  static readonly labelSmall: TextStyleSpec = TextStyleSpec.of(11, 16, WEIGHT_MEDIUM, 0.5);
}

/** 源语义样式：Feed 列表 title=titleMedium、snippet=titleSmall、日期/源名=labelMedium；TTS=titleMedium */
export class FeederTextStyles {
  static readonly feedListItemTitle: TextStyleSpec = M3Type.titleMedium;
  static readonly feedListItemSnippet: TextStyleSpec = M3Type.titleSmall;
  static readonly feedListItemFeedTitle: TextStyleSpec = M3Type.labelMedium;
  static readonly feedListItemDate: TextStyleSpec = M3Type.labelMedium;
  static readonly ttsPlayer: TextStyleSpec = M3Type.titleMedium;
}

// ------------------------------------------------------------------ 可观察字体状态
@ObservedV2
export class TypographyState {
  @Trace sansFamily: string = FAMILY_ROBOTO_FLEX;
  @Trace monoFamily: string = FAMILY_ROBOTO_MONO;
  @Trace serifFamily: string = FAMILY_SYSTEM_SERIF;
  /** 源 TypographySettings.fontScale（= textScale 设置） */
  @Trace fontScale: number = 1.0;
  /** 实际生效的字体路径（用户字体失效时为 bundled/roboto_flex） */
  @Trace effectiveFontPath: string = FONT_PATH_ROBOTO_FLEX;
  /** 字体注册代次：registerFont 成功后自增 → 依赖它的 build 重跑，修复"首帧先于字体注册"时回退系统字体不刷新 */
  @Trace fontEpoch: number = 0;
}

export const FeederTypography: TypographyState = new TypographyState();

/** 读当前 sans 字体族（在 build 中调用即建立依赖） */
export function sansFamily(): string {
  return FeederTypography.sansFamily;
}

export function monoFamily(): string {
  return FeederTypography.monoFamily;
}

/**
 * Text 样式修饰器：字号/行高/字重/字距/字体族（可选颜色、可选 textScale 缩放）。
 * 用法：Text(x).attributeModifier(textStyle(M3Type.titleMedium))
 * 工厂函数在 build 中读取 @Trace 字体状态 → 字体切换后重建修饰器并重新应用。
 */
export class TextStyleModifier implements AttributeModifier<TextAttribute> {
  spec: TextStyleSpec;
  family: string;
  scale: number;
  color: ResourceColor | null;

  constructor(spec: TextStyleSpec, family: string, scale: number, color: ResourceColor | null) {
    this.spec = spec;
    this.family = family;
    this.scale = scale;
    this.color = color;
  }

  applyNormalAttribute(instance: TextAttribute): void {
    instance.fontSize(this.spec.size * this.scale);
    instance.lineHeight(this.spec.lineHeight * this.scale);
    instance.fontWeight(this.spec.weight, { enableVariableFontWeight: true });
    instance.letterSpacing(this.spec.letterSpacing);
    instance.fontFamily(this.family);
    if (this.color !== null) {
      instance.fontColor(this.color as ResourceColor);
    }
  }
}

export function textStyle(spec: TextStyleSpec, scaled?: boolean, color?: ResourceColor): TextStyleModifier {
  readFontEpoch();
  const scale = scaled === true ? FeederTypography.fontScale : 1.0;
  return new TextStyleModifier(spec, FeederTypography.sansFamily, scale, color === undefined ? null : color);
}

export function monoTextStyle(spec: TextStyleSpec, scaled?: boolean, color?: ResourceColor): TextStyleModifier {
  readFontEpoch();
  const scale = scaled === true ? FeederTypography.fontScale : 1.0;
  return new TextStyleModifier(spec, FeederTypography.monoFamily, scale, color === undefined ? null : color);
}

/** 在 build 中读取字体注册代次以建立依赖（字体晚于首帧注册时触发重建） */
export function readFontEpoch(): number {
  return FeederTypography.fontEpoch;
}

/**
 * Button 标签样式（源 M3 Button 文本 = MaterialTheme.typography.labelLarge，随所选字体）。
 * 用法：Button(x).attributeModifier(buttonLabelStyle())
 */
export class ButtonLabelModifier implements AttributeModifier<ButtonAttribute> {
  spec: TextStyleSpec;
  family: string;

  constructor(spec: TextStyleSpec, family: string) {
    this.spec = spec;
    this.family = family;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    instance.fontSize(this.spec.size);
    instance.fontWeight(this.spec.weight);
    instance.fontFamily(this.family);
  }
}

export function buttonLabelStyle(spec?: TextStyleSpec): ButtonLabelModifier {
  readFontEpoch();
  return new ButtonLabelModifier(spec === undefined ? M3Type.labelLarge : spec as TextStyleSpec,
    FeederTypography.sansFamily);
}

/**
 * TextInput 文字/占位样式（源 M3 TextField 文本 = typography.bodyLarge，随所选字体）。
 * 用法：TextInput(x).attributeModifier(textInputStyle())
 */
export class TextInputStyleModifier implements AttributeModifier<TextInputAttribute> {
  spec: TextStyleSpec;
  family: string;

  constructor(spec: TextStyleSpec, family: string) {
    this.spec = spec;
    this.family = family;
  }

  applyNormalAttribute(instance: TextInputAttribute): void {
    instance.fontSize(this.spec.size);
    instance.fontWeight(this.spec.weight);
    instance.fontFamily(this.family);
    instance.placeholderFont({ size: this.spec.size, weight: this.spec.weight, family: this.family });
  }
}

export function textInputStyle(spec?: TextStyleSpec): TextInputStyleModifier {
  readFontEpoch();
  return new TextInputStyleModifier(spec === undefined ? M3Type.bodyLarge : spec as TextStyleSpec,
    FeederTypography.sansFamily);
}

/** 源 ProvideScaledText：字号与行高乘 fontScale */
export function scaledSize(spec: TextStyleSpec): number {
  return spec.size * FeederTypography.fontScale;
}

export function scaledLineHeight(spec: TextStyleSpec): number {
  return spec.lineHeight * FeederTypography.fontScale;
}

// ------------------------------------------------------------------ 字体注册与解析
/** TrueType/OpenType/集合文件头：0x00010000、'OTTO'、'true'、'ttcf' */
export function looksLikeFontHeader(b0: number, b1: number, b2: number, b3: number): boolean {
  if (b0 === 0x00 && b1 === 0x01 && b2 === 0x00 && b3 === 0x00) {
    return true;
  }
  const tag = String.fromCharCode(b0, b1, b2, b3);
  return tag === 'OTTO' || tag === 'true' || tag === 'ttcf';
}

export function userFontFamilyName(path: string): string {
  return USER_FAMILY_PREFIX + path.replace(new RegExp('[^A-Za-z0-9_]', 'g'), '_');
}

export class TypographyController {
  private static fontsDir: string = '';
  private static registered: Set<string> = new Set<string>();
  /** 待注册（UIContext 就绪前登记）：族名 → 源 */
  private static pending: Map<string, string | Resource> = new Map<string, string | Resource>();
  private static ui: UIContext | null = null;
  private static unsubscribe: (() => void) | null = null;

  /** SettingsStore.init 之后调用；幂等 */
  static init(ctx: common.Context): void {
    TypographyController.fontsDir = `${ctx.filesDir}/${FONTS_DIR_NAME}`;
    TypographyController.register(FAMILY_ROBOTO_FLEX, $rawfile('fonts/roboto_flex.ttf'));
    TypographyController.register(FAMILY_ROBOTO_MONO, $rawfile('fonts/roboto_mono_variable_wght.ttf'));
    if (TypographyController.unsubscribe === null) {
      TypographyController.unsubscribe = SettingsStore.instance().observe((key: string) => {
        if (key === PREF_FONT || key === PREF_TEXT_SCALE) {
          TypographyController.refresh();
        }
      });
    }
    TypographyController.refresh();
  }

  static refresh(): void {
    const s = SettingsStore.instance();
    FeederTypography.fontScale = s.textScale;
    TypographyController.applyFontPath(s.font);
  }

  /** 源 ProvideTypographySettings 的字体分派 + getMonoFontFamily */
  static applyFontPath(path: string): void {
    if (path === FONT_PATH_SYSTEM_DEFAULT) {
      FeederTypography.sansFamily = FAMILY_SYSTEM_SANS;
      FeederTypography.monoFamily = FAMILY_SYSTEM_MONO;
      FeederTypography.effectiveFontPath = path;
      return;
    }
    if (path !== FONT_PATH_ROBOTO_FLEX && path !== '') {
      const family = TypographyController.registerUserFont(path);
      if (family !== null) {
        FeederTypography.sansFamily = family as string;
        FeederTypography.monoFamily = FAMILY_SYSTEM_MONO;
        FeederTypography.effectiveFontPath = path;
        return;
      }
      console.warn(`Typography: user font unusable, falling back to Roboto Flex: ${path}`);
    }
    FeederTypography.sansFamily = FAMILY_ROBOTO_FLEX;
    FeederTypography.monoFamily = FAMILY_ROBOTO_MONO;
    FeederTypography.effectiveFontPath = FONT_PATH_ROBOTO_FLEX;
  }

  /** windowStage.loadContent 完成后调用：用 UIContext.getFont().registerFont 注册全部登记的字体 */
  static attachUIContext(ui: UIContext): void {
    TypographyController.ui = ui;
    TypographyController.pending.forEach((src: string | Resource, family: string) => {
      TypographyController.doRegister(family, src);
    });
    TypographyController.pending.clear();
  }

  /**
   * 源 SettingsStore.kt:323 / TextSettingsViewModel.kt:212-230 getFontSelectionFromPath：文件存在且
   * parseTrueTypeFont 成功 → 注册并返回族名；否则 null（调用方回退 RobotoFlex，TS-A20/A28）。
   */
  private static registerUserFont(path: string): string | null {
    if (TypographyController.fontsDir === '') {
      return null;
    }
    const full = `${TypographyController.fontsDir}/${path}`;
    try {
      if (!fs.accessSync(full)) {
        console.error(`FontSelection: Font file does not exist: ${path}`);
        return null;
      }
    } catch (e) {
      console.error(`Typography: cannot read user font ${path}: ${JSON.stringify(e)}`);
      return null;
    }
    if (getFontMetadata(full) === null) {
      console.error(`FontSelection: Error parsing font file: ${path}`);
      return null;
    }
    const family = userFontFamilyName(path);
    TypographyController.register(family, `file://${full}`);
    return family;
  }

  private static register(family: string, src: string | Resource): void {
    if (TypographyController.registered.has(family)) {
      return;
    }
    if (TypographyController.ui === null) {
      TypographyController.pending.set(family, src);
      return;
    }
    TypographyController.doRegister(family, src);
  }

  private static doRegister(family: string, src: string | Resource): void {
    const ui = TypographyController.ui;
    if (ui === null || TypographyController.registered.has(family)) {
      return;
    }
    try {
      ui.getFont().registerFont({ familyName: family, familySrc: src });
      TypographyController.registered.add(family);
      // 已构建的文字可能在注册前以该族名回退为系统字体：自增代次触发依赖它的 build 重建
      FeederTypography.fontEpoch = FeederTypography.fontEpoch + 1;
    } catch (e) {
      console.error(`Typography: registerFont ${family} failed: ${JSON.stringify(e)}`);
    }
  }
}
