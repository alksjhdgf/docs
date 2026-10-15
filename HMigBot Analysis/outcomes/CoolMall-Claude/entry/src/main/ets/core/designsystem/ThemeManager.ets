/**
 * ThemeManager — global theme state (source: core/common/manager/ThemePreferenceManager.kt +
 * core/designsystem/theme/Theme.kt AppTheme + Color.kt primary-derived gradients).
 *
 * - `mode` / `colorKey` / `primary` are @Trace, so any V2 component reading
 *   `ThemeManager.instance.primary` re-renders immediately on change (LAUNCH-A26, COM-A07).
 * - Persistence keys are verbatim from the source: `settings_theme_mode` / `settings_theme_color`
 *   (LAUNCH-A25, COM-A08); unknown/missing → follow_system / default.
 * - Dark/light is applied app-wide through ApplicationContext.setColorMode, so `$r('app.color.*')`
 *   tokens (resources/base + resources/dark) switch automatically (LAUNCH-A24, COM-A05).
 *   Dynamic color (Monet) is off, as in the source (LAUNCH-A28).
 *
 * Usage: EntryAbility.onCreate → KvStore.init(ctx) → ThemeManager.instance.init(ctx).
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { KvKeys, KvStore } from '../storage/KvStore';
import { LogUtils } from '../util/LogUtils';
import { ThemeMode, ThemePreference } from './ThemePreference';
import { ThemeColorKey, ThemeColorOption } from './ThemeColorOption';

const TAG: string = 'ThemeManager';

@ObservedV2
export class ThemeManager {
  static readonly instance: ThemeManager = new ThemeManager();

  /** Current theme mode: 'follow_system' | 'light' | 'dark' */
  @Trace mode: ThemeMode = ThemePreference.FOLLOW_SYSTEM;
  /** Current theme color storage key: default/purple/green/orange/red */
  @Trace colorKey: ThemeColorKey = ThemeColorOption.DEFAULT.storageValue;
  /** Current primary color '#RRGGBB' (MaterialTheme.colorScheme.primary equivalent) */
  @Trace primary: string = ThemeColorOption.DEFAULT.colorHex;
  /**
   * Whether the system itself is in dark mode. Seeded from the app context in init();
   * fnd-app-init should keep it fresh via onConfigurationUpdate → updateSystemColorMode().
   */
  @Trace systemDark: boolean = false;

  private appCtx: common.ApplicationContext | null = null;

  private constructor() {
  }

  /** Reads persisted mode/color and applies the color mode. Call once after KvStore.init. */
  init(ctx: common.Context): void {
    try {
      this.appCtx = ctx.getApplicationContext();
    } catch (e) {
      LogUtils.eTag(TAG, 'getApplicationContext failed: ' + JSON.stringify(e));
      this.appCtx = null;
    }
    this.mode = ThemePreference.fromStorage(
      KvStore.getString(KvKeys.SETTINGS_THEME_MODE, ThemePreference.FOLLOW_SYSTEM));
    const option: ThemeColorOption = ThemeColorOption.fromStorage(
      KvStore.getString(KvKeys.SETTINGS_THEME_COLOR, ThemeColorOption.DEFAULT.storageValue));
    this.colorKey = option.storageValue;
    this.primary = option.colorHex;
    this.readSystemColorMode(ctx);
    this.applyColorMode();
  }

  /** ThemePreferenceManager.updateThemeMode: no-op when unchanged; otherwise apply + persist. */
  setMode(mode: ThemeMode): void {
    if (this.mode === mode) {
      return;
    }
    this.mode = mode;
    this.applyColorMode();
    try {
      KvStore.putString(KvKeys.SETTINGS_THEME_MODE, mode);
    } catch (e) {
      LogUtils.eTag(TAG, 'persist theme mode failed: ' + JSON.stringify(e));
    }
  }

  /** ThemePreferenceManager.updateThemeColor: no-op when unchanged; primary switches immediately. */
  setColor(key: ThemeColorKey): void {
    if (this.colorKey === key) {
      return;
    }
    const option: ThemeColorOption = ThemeColorOption.fromStorage(key);
    this.colorKey = option.storageValue;
    this.primary = option.colorHex;
    try {
      KvStore.putString(KvKeys.SETTINGS_THEME_COLOR, option.storageValue);
    } catch (e) {
      LogUtils.eTag(TAG, 'persist theme color failed: ' + JSON.stringify(e));
    }
  }

  /** Current color option (currentThemeColor). */
  get colorOption(): ThemeColorOption {
    return ThemeColorOption.fromStorage(this.colorKey);
  }

  /** Effective dark state (mode resolved against the system setting). */
  get isDark(): boolean {
    if (this.mode === ThemePreference.DARK) {
      return true;
    }
    if (this.mode === ThemePreference.LIGHT) {
      return false;
    }
    return this.systemDark;
  }

  /** Color.kt GradientPrimaryStart: lerp(primary, white, 0.15). */
  get primaryGradientStart(): string {
    return ThemeManager.lerpHex(this.primary, '#FFFFFF', 0.15);
  }

  /** Color.kt GradientPrimaryEnd: lerp(primary, black, 0.15). */
  get primaryGradientEnd(): string {
    return ThemeManager.lerpHex(this.primary, '#000000', 0.15);
  }

  /** Primary with alpha (0..1) as '#AARRGGBB', for tinted backgrounds (Compose primary.copy(alpha)). */
  primaryWithAlpha(alpha: number): string {
    return ThemeManager.withAlpha(this.primary, alpha);
  }

  /**
   * Called by the ability's onConfigurationUpdate with the new system color mode.
   * Only meaningful while mode is follow_system (the app context then reports the system mode).
   */
  updateSystemColorMode(colorMode: ConfigurationConstant.ColorMode | undefined): void {
    if (this.mode !== ThemePreference.FOLLOW_SYSTEM) {
      return;
    }
    this.systemDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private readSystemColorMode(ctx: common.Context): void {
    try {
      const cfg = ctx.resourceManager.getConfigurationSync();
      this.systemDark = cfg.colorMode === resourceManager.ColorMode.DARK;
    } catch (e) {
      this.systemDark = false;
    }
  }

  private applyColorMode(): void {
    if (this.appCtx === null) {
      LogUtils.wTag(TAG, 'applyColorMode skipped: init(ctx) not called');
      return;
    }
    let cm: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.mode === ThemePreference.LIGHT) {
      cm = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (this.mode === ThemePreference.DARK) {
      cm = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      this.appCtx.setColorMode(cm);
    } catch (e) {
      LogUtils.eTag(TAG, 'setColorMode failed: ' + JSON.stringify(e));
    }
  }

  // ====================== color math ======================
  private static parseHex(hex: string): number[] {
    let h: string = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length === 8) {
      h = h.substring(2);
    }
    const v: number = parseInt(h, 16);
    if (isNaN(v)) {
      return [0, 0, 0];
    }
    return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  }

  private static toHex2(n: number): string {
    const c: number = Math.max(0, Math.min(255, Math.round(n)));
    const s: string = c.toString(16).toUpperCase();
    return s.length < 2 ? '0' + s : s;
  }

  /** Linear interpolation between two '#RRGGBB' colors → '#RRGGBB'. */
  static lerpHex(start: string, stop: string, fraction: number): string {
    const a: number[] = ThemeManager.parseHex(start);
    const b: number[] = ThemeManager.parseHex(stop);
    return '#' + ThemeManager.toHex2(a[0] + (b[0] - a[0]) * fraction) +
      ThemeManager.toHex2(a[1] + (b[1] - a[1]) * fraction) +
      ThemeManager.toHex2(a[2] + (b[2] - a[2]) * fraction);
  }

  /** '#RRGGBB' + alpha (0..1) → '#AARRGGBB'. */
  static withAlpha(hex: string, alpha: number): string {
    const rgb: number[] = ThemeManager.parseHex(hex);
    return '#' + ThemeManager.toHex2(alpha * 255) + ThemeManager.toHex2(rgb[0]) +
      ThemeManager.toHex2(rgb[1]) + ThemeManager.toHex2(rgb[2]);
  }
}
