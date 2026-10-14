/*
 * Theme — 源 ui/compose/theme/{Color.kt, Theme.kt, Dimensions.kt} 的鸿蒙实现。
 *  - 主题 ThemeOptions（DAY/NIGHT/E_INK/SYSTEM）+ 深色偏好（BLACK/DARK）+ 动态取色（鸿蒙无壁纸取色 → 固定配色）。
 *  - 颜色 token 放在 @ObservedV2 单例 FeederTheme.colors（@Trace），组件在 build 中读取 → 设置变化即重绘（UC-A20）。
 *  - 系统栏：edge-to-edge 由 fnd-app-init 开启全屏；本文件按主题设置状态栏/导航栏内容色（UC-A19）。
 *  - 响应式尺寸 Dimensions（phone/tablet，UC-A28），随窗口尺寸变化更新。
 * 入口：ThemeController.init(ctx) / attachWindow(win)（经 CommonWidgets.FeederUiBootstrap 统一调用）。
 */
import { common, ConfigurationConstant, Configuration, EnvironmentCallback, AbilityConstant } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { ThemeOptions, DarkThemePreferences } from '../../core/model/Enums';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { PREF_THEME, PREF_DARK_THEME, PREF_DYNAMIC_THEME } from '../../core/settings/SettingsKeys';
import { textStyle, M3Type, TypographyController } from './Typography';

// ------------------------------------------------------------------ 颜色常量（源 Color.kt）
export const GREEN_700: string = '#FF0B8043';
export const SWIPING_ITEM_TO_READ_COLOR: string = '#FFFF5252';
export const SWIPING_ITEM_TO_UNREAD_COLOR: string = '#FF1C9255';
/** 源 Theme.kt lightScrim argb(0xe6,FF,FF,FF) / darkScrim argb(0x80,1b,1b,1b)：导航栏遮罩 */
export const NAV_BAR_SCRIM_LIGHT: string = '#E6FFFFFF';
export const NAV_BAR_SCRIM_DARK: string = '#801B1B1B';
export const PURE_BLACK: string = '#FF000000';

/** M3 ColorScheme 全部 token（源未覆盖的 surfaceContainer* / outlineVariant / scrim 取 M3 基线默认值） */
export class ColorSchemeValues {
  primary: string = '';
  onPrimary: string = '';
  primaryContainer: string = '';
  onPrimaryContainer: string = '';
  secondary: string = '';
  onSecondary: string = '';
  secondaryContainer: string = '';
  onSecondaryContainer: string = '';
  tertiary: string = '';
  onTertiary: string = '';
  tertiaryContainer: string = '';
  onTertiaryContainer: string = '';
  error: string = '';
  errorContainer: string = '';
  onError: string = '';
  onErrorContainer: string = '';
  background: string = '';
  onBackground: string = '';
  surface: string = '';
  onSurface: string = '';
  surfaceVariant: string = '';
  onSurfaceVariant: string = '';
  outline: string = '';
  inverseOnSurface: string = '';
  inverseSurface: string = '';
  inversePrimary: string = '';
  surfaceTint: string = '';
  outlineVariant: string = '';
  scrim: string = '#FF000000';
  surfaceContainerLowest: string = '';
  surfaceContainerLow: string = '';
  surfaceContainer: string = '';
  surfaceContainerHigh: string = '';
  surfaceContainerHighest: string = '';

  copy(): ColorSchemeValues {
    const c = new ColorSchemeValues();
    c.primary = this.primary; c.onPrimary = this.onPrimary;
    c.primaryContainer = this.primaryContainer; c.onPrimaryContainer = this.onPrimaryContainer;
    c.secondary = this.secondary; c.onSecondary = this.onSecondary;
    c.secondaryContainer = this.secondaryContainer; c.onSecondaryContainer = this.onSecondaryContainer;
    c.tertiary = this.tertiary; c.onTertiary = this.onTertiary;
    c.tertiaryContainer = this.tertiaryContainer; c.onTertiaryContainer = this.onTertiaryContainer;
    c.error = this.error; c.errorContainer = this.errorContainer;
    c.onError = this.onError; c.onErrorContainer = this.onErrorContainer;
    c.background = this.background; c.onBackground = this.onBackground;
    c.surface = this.surface; c.onSurface = this.onSurface;
    c.surfaceVariant = this.surfaceVariant; c.onSurfaceVariant = this.onSurfaceVariant;
    c.outline = this.outline; c.inverseOnSurface = this.inverseOnSurface;
    c.inverseSurface = this.inverseSurface; c.inversePrimary = this.inversePrimary;
    c.surfaceTint = this.surfaceTint; c.outlineVariant = this.outlineVariant; c.scrim = this.scrim;
    c.surfaceContainerLowest = this.surfaceContainerLowest; c.surfaceContainerLow = this.surfaceContainerLow;
    c.surfaceContainer = this.surfaceContainer; c.surfaceContainerHigh = this.surfaceContainerHigh;
    c.surfaceContainerHighest = this.surfaceContainerHighest;
    return c;
  }
}

function scheme(v: string[]): ColorSchemeValues {
  // 顺序：primary..surfaceTint（源 27 项）+ outlineVariant + 5 个 surfaceContainer
  const c = new ColorSchemeValues();
  c.primary = v[0]; c.onPrimary = v[1]; c.primaryContainer = v[2]; c.onPrimaryContainer = v[3];
  c.secondary = v[4]; c.onSecondary = v[5]; c.secondaryContainer = v[6]; c.onSecondaryContainer = v[7];
  c.tertiary = v[8]; c.onTertiary = v[9]; c.tertiaryContainer = v[10]; c.onTertiaryContainer = v[11];
  c.error = v[12]; c.errorContainer = v[13]; c.onError = v[14]; c.onErrorContainer = v[15];
  c.background = v[16]; c.onBackground = v[17]; c.surface = v[18]; c.onSurface = v[19];
  c.surfaceVariant = v[20]; c.onSurfaceVariant = v[21]; c.outline = v[22]; c.inverseOnSurface = v[23];
  c.inverseSurface = v[24]; c.inversePrimary = v[25]; c.surfaceTint = v[26]; c.outlineVariant = v[27];
  c.surfaceContainerLowest = v[28]; c.surfaceContainerLow = v[29]; c.surfaceContainer = v[30];
  c.surfaceContainerHigh = v[31]; c.surfaceContainerHighest = v[32];
  return c;
}

/** 源 md_theme_light_*（lightColorScheme 未给的 token 取 M3 浅色基线默认） */
export const LIGHT_COLORS: ColorSchemeValues = scheme([
  '#FF006D37', '#FFFFFFFF', '#FF93F8AE', '#FF00210C', '#FF506352', '#FFFFFFFF', '#FFD2E8D3', '#FF0E1F12',
  '#FF3A656E', '#FFFFFFFF', '#FFBDEAF5', '#FF001F25', '#FFBA1A1A', '#FFFFDAD6', '#FFFFFFFF', '#FF410002',
  '#FFFBFDF7', '#FF191C19', '#FFFBFDF7', '#FF191C19', '#FFDDE5DA', '#FF414941', '#FF717971', '#FFF0F1EC',
  '#FF2E312E', '#FF77DB93', '#FF006D37', '#FFCAC4D0',
  '#FFFFFFFF', '#FFF7F2FA', '#FFF3EDF7', '#FFECE6F0', '#FFE6E0E9',
]);

/** 源 md_theme_dark_*（darkColorScheme 未给的 token 取 M3 深色基线默认） */
export const DARK_COLORS: ColorSchemeValues = scheme([
  '#FF77DB93', '#FF00391A', '#FF005228', '#FF93F8AE', '#FFB7CCB8', '#FF223526', '#FF384B3C', '#FFD2E8D3',
  '#FFA2CED9', '#FF01363F', '#FF204D56', '#FFBDEAF5', '#FFFFB4AB', '#FF93000A', '#FF690005', '#FFFFDAD6',
  '#FF191C19', '#FFE1E3DE', '#FF191C19', '#FFE1E3DE', '#FF414941', '#FFC1C9BF', '#FF8B938A', '#FF191C19',
  '#FFE1E3DE', '#FF006D37', '#FF77DB93', '#FF49454F',
  '#FF0F0D13', '#FF1D1B20', '#FF211F26', '#FF2B2930', '#FF36343B',
]);

/** 源 md_theme_eink_*：黑白高对比（lightColorScheme 基底） */
export const EINK_COLORS: ColorSchemeValues = scheme([
  '#FF000000', '#FFFFFFFF', '#FFFFFFFF', '#FF000000', '#FF000000', '#FFFFFFFF', '#FFFFFFFF', '#FF000000',
  '#FF000000', '#FFFFFFFF', '#FFFFFFFF', '#FF000000', '#FF000000', '#FFFFFFFF', '#FFFFFFFF', '#FF000000',
  '#FFFFFFFF', '#FF000000', '#FFFFFFFF', '#FF000000', '#FFFFFFFF', '#FF000000', '#FF717971', '#FFFFFFFF',
  '#FF2E312E', '#FFFFFFFF', '#FFFFFFFF', '#FFCAC4D0',
  '#FFFFFFFF', '#FFF7F2FA', '#FFF3EDF7', '#FFECE6F0', '#FFE6E0E9',
]);

// ------------------------------------------------------------------ 纯逻辑（可单测）
/** 源 Theme.kt getColorScheme/isDarkSystemIcons 的 dark 判定：DAY/E_INK=false，NIGHT=true，SYSTEM=系统 */
export function isDarkTheme(theme: ThemeOptions, systemDark: boolean): boolean {
  switch (theme) {
    case ThemeOptions.DAY:
    case ThemeOptions.E_INK:
      return false;
    case ThemeOptions.NIGHT:
      return true;
    default:
      return systemDark;
  }
}

/**
 * 源 ThemeOptions.getColorScheme：动态取色（平台支持且开启）> dark → darkColors > E_INK → eInk > light；
 * 最后 dark && BLACK → background = 纯黑。鸿蒙 dynamicSupported 恒 false（SettingsStore.DYNAMIC_THEME_SUPPORTED）。
 */
export function computeColorScheme(theme: ThemeOptions, darkPref: DarkThemePreferences, dynamicColors: boolean,
  systemDark: boolean, dynamicSupported: boolean): ColorSchemeValues {
  const dark = isDarkTheme(theme, systemDark);
  let base: ColorSchemeValues;
  if (dynamicSupported && dynamicColors) {
    // 鸿蒙无壁纸取色色板 API：此分支不可达（dynamicSupported=false）；保留结构以对齐源优先级。
    base = dark ? DARK_COLORS : LIGHT_COLORS;
  } else if (dark) {
    base = DARK_COLORS;
  } else if (theme === ThemeOptions.E_INK) {
    base = EINK_COLORS;
  } else {
    base = LIGHT_COLORS;
  }
  const result = base.copy();
  if (dark && darkPref === DarkThemePreferences.BLACK) {
    result.background = PURE_BLACK;
  }
  return result;
}

/** 状态栏/导航栏使用深色图标（= 非深色主题）；源 isDarkSystemIcons / isDarkNavIcons */
export function useDarkSystemIcons(theme: ThemeOptions, systemDark: boolean): boolean {
  return !isDarkTheme(theme, systemDark);
}

function parseArgb(c: string): number[] {
  let hex = c.startsWith('#') ? c.substring(1) : c;
  if (hex.length === 6) {
    hex = 'FF' + hex;
  }
  const n = parseInt(hex, 16);
  return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
}

function toHex2(n: number): string {
  const s = Math.round(Math.max(0, Math.min(255, n))).toString(16).toUpperCase();
  return s.length === 1 ? '0' + s : s;
}

/** over 以 alpha 叠加到 base 上（不透明结果） */
export function blendColors(base: string, over: string, alpha: number): string {
  const b = parseArgb(base);
  const o = parseArgb(over);
  return '#FF' + toHex2(b[1] + (o[1] - b[1]) * alpha) + toHex2(b[2] + (o[2] - b[2]) * alpha) +
    toHex2(b[3] + (o[3] - b[3]) * alpha);
}

/** M3 surfaceColorAtElevation：alpha = (4.5 * ln(elevation + 1) + 2) / 100 的 surfaceTint 叠加 */
export function surfaceAtElevation(c: ColorSchemeValues, elevationDp: number): string {
  if (elevationDp <= 0) {
    return c.surface;
  }
  const alpha = (4.5 * Math.log(elevationDp + 1) + 2) / 100;
  return blendColors(c.surface, c.surfaceTint, alpha);
}

// ------------------------------------------------------------------ 响应式尺寸（源 Dimensions.kt）
export class Dimensions {
  navIconMargin: number = 16;
  gutter: number = 16;
  margin: number = 16;
  maxContentWidth: number = 600;
  maxReaderWidth: number = 600;
  /** 非 null 时阅读器图片约束宽高比（TV 专用，鸿蒙不启用） */
  imageAspectRatioInReader: number | null = null;
  layoutColumns: number = 4;
  feedScreenColumns: number = 1;

  hasImageAspectRatioInReader(): boolean {
    return this.imageAspectRatioInReader !== null;
  }
}

export function phoneDimensions(): Dimensions {
  return new Dimensions();
}

export function tabletDimensions(windowWidthVp: number): Dimensions {
  const columns = windowWidthVp > 1360 ? 4 : (windowWidthVp > 1028 ? 3 : 2);
  const d = new Dimensions();
  d.maxContentWidth = Math.min(840, windowWidthVp);
  d.maxReaderWidth = Math.min(640, windowWidthVp);
  d.navIconMargin = 32;
  d.margin = 32;
  d.gutter = 32;
  d.layoutColumns = columns * 4;
  d.feedScreenColumns = columns;
  return d;
}

/** M3 WindowSizeClass：宽 <600 Compact；高 <480 Compact */
export const COMPACT_WIDTH_LIMIT_VP: number = 600;
export const COMPACT_HEIGHT_LIMIT_VP: number = 480;

/** 源 ProvideDimens：宽度 Compact → phone；否则高度 Compact → phone；否则 tablet(宽) */
export function selectDimensions(widthVp: number, heightVp: number): Dimensions {
  if (widthVp < COMPACT_WIDTH_LIMIT_VP) {
    return phoneDimensions();
  }
  if (heightVp < COMPACT_HEIGHT_LIMIT_VP) {
    return phoneDimensions();
  }
  return tabletDimensions(widthVp);
}

// ------------------------------------------------------------------ 可观察主题状态
@ObservedV2
export class ThemeState {
  @Trace isDark: boolean = false;
  @Trace systemDark: boolean = false;
  @Trace currentTheme: ThemeOptions = ThemeOptions.SYSTEM;
  @Trace colors: ColorSchemeValues = LIGHT_COLORS.copy();
  /** 顶栏滚动后的容器色（surfaceColorAtElevation(3.dp)） */
  @Trace scrolledBarColor: string = surfaceAtElevation(LIGHT_COLORS, 3);
  @Trace dimens: Dimensions = phoneDimensions();
  @Trace windowWidthVp: number = 360;
  @Trace windowHeightVp: number = 780;
}

/** 全局主题单例：UI 直接读 FeederTheme.colors.xxx / FeederTheme.dimens.xxx */
export const FeederTheme: ThemeState = new ThemeState();

export class ThemeController {
  private static ctx: common.UIAbilityContext | null = null;
  private static win: window.Window | null = null;
  private static unsubscribe: (() => void) | null = null;
  private static envCallbackId: number = -1;
  private static lastAppColorMode: number = -2;

  /** 在 SettingsStore.init 之后调用；幂等 */
  static init(ctx: common.UIAbilityContext): void {
    ThemeController.ctx = ctx;
    FeederTheme.systemDark = ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (ThemeController.unsubscribe === null) {
      ThemeController.unsubscribe = SettingsStore.instance().observe((key: string) => {
        if (key === PREF_THEME || key === PREF_DARK_THEME || key === PREF_DYNAMIC_THEME) {
          ThemeController.recompute();
        }
      });
    }
    if (ThemeController.envCallbackId < 0) {
      const cb: EnvironmentCallback = {
        onConfigurationUpdated(config: Configuration): void {
          ThemeController.onSystemConfiguration(config);
        },
        onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
          console.debug(`ThemeController: memory level ${level}`);
        }
      };
      try {
        ThemeController.envCallbackId = ctx.getApplicationContext().on('environment', cb);
      } catch (e) {
        console.error(`ThemeController: subscribe environment failed: ${JSON.stringify(e)}`);
      }
    }
    ThemeController.recompute();
  }

  /** onWindowStageCreate 拿到主窗口后调用：设置系统栏内容色、订阅窗口尺寸 */
  static attachWindow(win: window.Window, densityPixels: number): void {
    ThemeController.win = win;
    try {
      const rect = win.getWindowProperties().windowRect;
      ThemeController.onWindowSizePx(rect.width, rect.height, densityPixels);
      win.on('windowSizeChange', (size: window.Size) => {
        ThemeController.onWindowSizePx(size.width, size.height, densityPixels);
      });
    } catch (e) {
      console.error(`ThemeController: window size failed: ${JSON.stringify(e)}`);
    }
    ThemeController.applySystemBars();
  }

  static detachWindow(): void {
    const w = ThemeController.win;
    if (w !== null) {
      try {
        w.off('windowSizeChange');
      } catch (e) {
        console.error(`ThemeController: off windowSizeChange failed: ${JSON.stringify(e)}`);
      }
    }
    ThemeController.win = null;
  }

  static onWindowSizePx(widthPx: number, heightPx: number, densityPixels: number): void {
    const d = densityPixels > 0 ? densityPixels : 1;
    const w = widthPx / d;
    const h = heightPx / d;
    FeederTheme.windowWidthVp = w;
    FeederTheme.windowHeightVp = h;
    FeederTheme.dimens = selectDimensions(w, h);
  }

  /** 系统深浅色变化：仅在跟随系统时采信（强制 DAY/NIGHT 时应用 colorMode 被覆盖） */
  static onSystemConfiguration(config: Configuration): void {
    if (config.colorMode === undefined || config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      return;
    }
    if (SettingsStore.instance().currentTheme !== ThemeOptions.SYSTEM) {
      return;
    }
    const dark = config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (dark !== FeederTheme.systemDark) {
      FeederTheme.systemDark = dark;
      ThemeController.recompute();
    }
  }

  static recompute(): void {
    const s = SettingsStore.instance();
    const theme = s.currentTheme;
    ThemeController.applyAppColorMode(theme);
    const colors = computeColorScheme(theme, s.darkThemePreference, s.useDynamicTheme, FeederTheme.systemDark,
      SettingsStore.DYNAMIC_THEME_SUPPORTED);
    FeederTheme.currentTheme = theme;
    FeederTheme.isDark = isDarkTheme(theme, FeederTheme.systemDark);
    FeederTheme.colors = colors;
    FeederTheme.scrolledBarColor = surfaceAtElevation(colors, 3);
    ThemeController.applySystemBars();
  }

  /** 让系统组件（Toggle/TextInput/系统弹窗）随应用主题：DAY/E_INK 浅、NIGHT 深、SYSTEM 不设置 */
  private static applyAppColorMode(theme: ThemeOptions): void {
    const ctx = ThemeController.ctx;
    if (ctx === null) {
      return;
    }
    let mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (theme === ThemeOptions.NIGHT) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (theme === ThemeOptions.DAY || theme === ThemeOptions.E_INK) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    const previous = ThemeController.lastAppColorMode;
    if (previous === (mode as number)) {
      return;
    }
    ThemeController.lastAppColorMode = mode as number;
    if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET && previous >= 0) {
      // 从强制模式回到跟随系统：若系统值与强制值相同则不会收到配置变化事件，先按强制值假设，事件到达后再纠正
      FeederTheme.systemDark = previous === (ConfigurationConstant.ColorMode.COLOR_MODE_DARK as number);
    }
    try {
      ctx.getApplicationContext().setColorMode(mode);
    } catch (e) {
      console.error(`ThemeController: setColorMode failed: ${JSON.stringify(e)}`);
    }
  }

  /** 源 enableEdgeToEdge：状态栏透明；DAY/E_INK 深色图标、NIGHT 浅色图标、SYSTEM 随系统；导航栏 scrim 同源 */
  static applySystemBars(): void {
    const w = ThemeController.win;
    if (w === null) {
      return;
    }
    const darkIcons = useDarkSystemIcons(FeederTheme.currentTheme, FeederTheme.systemDark);
    const props: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      statusBarContentColor: darkIcons ? '#FF000000' : '#FFFFFFFF',
      navigationBarColor: darkIcons ? NAV_BAR_SCRIM_LIGHT : NAV_BAR_SCRIM_DARK,
      navigationBarContentColor: darkIcons ? '#FF000000' : '#FFFFFFFF'
    };
    w.setWindowSystemBarProperties(props).catch((e: Error) => {
      console.error(`ThemeController: setWindowSystemBarProperties failed: ${e?.message}`);
    });
  }
}

// ------------------------------------------------------------------ SensibleTopAppBar（源 theme/SensibleTopAppBar.kt）
/** 首个强方向字符决定段落方向（源 WithBidiDeterminedLayoutDirection）：RTL 字母表 → Rtl，其余字母 → Ltr */
export function isRtlText(text: string): boolean {
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if ((c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF)) {
      return true;
    }
    const isLatinOrOther = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c >= 0x00C0;
    if (isLatinOrOther) {
      return false;
    }
  }
  return false;
}

@ComponentV2
export struct SensibleTopAppBar {
  @Param titleText: string = '';
  /** 列表已滚动（源 scrolledContainerColor = surfaceColorAtElevation(3.dp)） */
  @Param scrolled: boolean = false;
  /** 状态栏避让高度（vp，来自 AppStorageV2 AvoidArea.top） */
  @Param topInset: number = 0;
  @BuilderParam navigationIconBuilder: () => void = emptyBuilder;
  @BuilderParam actionsBuilder: () => void = emptyBuilder;

  build() {
    Row() {
      this.navigationIconBuilder()
      Text(this.titleText)
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .direction(isRtlText(this.titleText) ? Direction.Rtl : Direction.Ltr)
        .textAlign(TextAlign.Start)
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      Row() {
        this.actionsBuilder()
      }
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(64 + this.topInset)
    .padding({ top: this.topInset, left: 4, right: 4 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.scrolled ? FeederTheme.scrolledBarColor : FeederTheme.colors.background)
  }
}

@Builder
function emptyBuilder() {
}

let cachedDensity: number = 0;

/** 屏幕像素密度（px/vp） */
export function screenDensity(): number {
  if (cachedDensity <= 0) {
    try {
      cachedDensity = display.getDefaultDisplaySync().densityPixels;
    } catch (e) {
      cachedDensity = 1;
    }
  }
  return cachedDensity > 0 ? cachedDensity : 1;
}

// ================================================================== UI 启动入口（fnd-app-init 调用）
export class FeederUiBootstrap {
  /** SettingsStore.init 完成后：主题/字体状态与设置、系统深浅色同步 */
  static init(ctx: common.UIAbilityContext): void {
    ThemeController.init(ctx);
    TypographyController.init(ctx);
  }

  /** onWindowStageCreate 取得主窗口后：系统栏内容色、窗口尺寸 → 响应式尺寸 */
  static attachWindow(win: window.Window): void {
    ThemeController.attachWindow(win, screenDensity());
  }

  /** windowStage.loadContent 成功回调中：注册内置/用户字体（需 UIContext） */
  static onContentLoaded(win: window.Window): void {
    try {
      TypographyController.attachUIContext(win.getUIContext());
    } catch (e) {
      console.error(`FeederUiBootstrap: getUIContext failed: ${JSON.stringify(e)}`);
    }
  }
}
