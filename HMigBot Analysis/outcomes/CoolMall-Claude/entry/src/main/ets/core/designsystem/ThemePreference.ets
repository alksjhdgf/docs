/**
 * ThemePreference — app theme mode (source: core/common/config/ThemePreference.kt).
 * storageValue strings are persisted verbatim under KV key `settings_theme_mode`.
 */
export type ThemeMode = 'follow_system' | 'light' | 'dark';

export class ThemePreference {
  static readonly FOLLOW_SYSTEM: ThemeMode = 'follow_system';
  static readonly LIGHT: ThemeMode = 'light';
  static readonly DARK: ThemeMode = 'dark';

  /** All modes in source enum order (follow_system, light, dark). */
  static readonly entries: ThemeMode[] = [
    ThemePreference.FOLLOW_SYSTEM, ThemePreference.LIGHT, ThemePreference.DARK
  ];

  /** ThemePreference.fromStorage: unknown / missing value → FOLLOW_SYSTEM. */
  static fromStorage(value: string | null | undefined): ThemeMode {
    if (value === ThemePreference.LIGHT) {
      return ThemePreference.LIGHT;
    }
    if (value === ThemePreference.DARK) {
      return ThemePreference.DARK;
    }
    return ThemePreference.FOLLOW_SYSTEM;
  }
}
