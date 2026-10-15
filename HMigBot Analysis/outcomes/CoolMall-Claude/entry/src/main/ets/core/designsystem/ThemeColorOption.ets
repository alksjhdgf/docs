/**
 * ThemeColorOption — selectable primary colors (source: core/common/config/ThemeColorOption.kt).
 * storageValue strings are persisted verbatim under KV key `settings_theme_color`.
 * The source leaves display names to the UI layer; `nameRes` is provided as a convenience and
 * points at the already-converted strings (settings_theme_color_*, COM-A06).
 */
export type ThemeColorKey = 'default' | 'purple' | 'green' | 'orange' | 'red';

export class ThemeColorOption {
  readonly storageValue: ThemeColorKey;
  /** '#RRGGBB' (source colorHex 0xFFRRGGBB, fully opaque) */
  readonly colorHex: string;
  readonly nameRes: Resource;

  constructor(storageValue: ThemeColorKey, colorHex: string, nameRes: Resource) {
    this.storageValue = storageValue;
    this.colorHex = colorHex;
    this.nameRes = nameRes;
  }

  static readonly DEFAULT: ThemeColorOption =
    new ThemeColorOption('default', '#465CFF', $r('app.string.settings_theme_color_default'));
  static readonly PURPLE: ThemeColorOption =
    new ThemeColorOption('purple', '#6831FF', $r('app.string.settings_theme_color_purple'));
  static readonly GREEN: ThemeColorOption =
    new ThemeColorOption('green', '#09BE4F', $r('app.string.settings_theme_color_green'));
  static readonly ORANGE: ThemeColorOption =
    new ThemeColorOption('orange', '#FFB703', $r('app.string.settings_theme_color_orange'));
  static readonly RED: ThemeColorOption =
    new ThemeColorOption('red', '#FF2B2B', $r('app.string.settings_theme_color_red'));

  /** All options in source enum order. */
  static readonly entries: ThemeColorOption[] = [
    ThemeColorOption.DEFAULT, ThemeColorOption.PURPLE, ThemeColorOption.GREEN,
    ThemeColorOption.ORANGE, ThemeColorOption.RED
  ];

  /** ThemeColorOption.fromStorage: unknown / missing value → DEFAULT. */
  static fromStorage(value: string | null | undefined): ThemeColorOption {
    for (const option of ThemeColorOption.entries) {
      if (option.storageValue === value) {
        return option;
      }
    }
    return ThemeColorOption.DEFAULT;
  }
}
