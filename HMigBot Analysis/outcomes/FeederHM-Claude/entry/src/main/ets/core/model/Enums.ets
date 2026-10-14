/**
 * 设置相关枚举及其源存储字符串（源 archmodel/SettingsStore.kt:716-719,840-989）与 ID 哨兵（源 db/room/AppDatabase.kt:30-32）。
 *
 * 存储格式（逐字照源）：
 *  - ThemeOptions / DarkThemePreferences / SortingOptions：写入 `name.lowercase()`；读取 `valueOf(value.uppercase())`
 *  - FeedItemStyle / SwipeAsRead：写入 `name`（大写）；读取 `valueOf(value.uppercase())`
 *  - ItemOpener / LinkOpener：数字码 "0" 阅读器 / "1" WebView(旧，读为 CUSTOM_TAB) / "2" 浏览器 / "3" Custom Tab
 *  - SyncFrequency：写入分钟数字符串（"-1"/"15"/.../"1440"），读取按分钟匹配，失败 MANUAL
 * 枚举值字符串 = Kotlin 枚举常量名（`toString()`/`name` 语义）。
 */

// ---------------- ID 哨兵 ----------------
export const ID_UNSET: number = 0;
export const ID_ALL_FEEDS: number = -10;
export const ID_SAVED_ARTICLES: number = -20;

// ---------------- 打开方式码 ----------------
export const PREF_VAL_OPEN_WITH_READER: string = '0';
export const PREF_VAL_OPEN_WITH_WEBVIEW: string = '1';
export const PREF_VAL_OPEN_WITH_BROWSER: string = '2';
export const PREF_VAL_OPEN_WITH_CUSTOM_TAB: string = '3';

// ---------------- ThemeOptions ----------------
export enum ThemeOptions {
  DAY = 'DAY',
  NIGHT = 'NIGHT',
  E_INK = 'E_INK',
  SYSTEM = 'SYSTEM',
}

export const THEME_OPTIONS_VALUES: ThemeOptions[] = [
  ThemeOptions.DAY, ThemeOptions.NIGHT, ThemeOptions.E_INK, ThemeOptions.SYSTEM,
];

/** 源 strings.xml key（stringId） */
export function themeOptionsStringKey(value: ThemeOptions): string {
  switch (value) {
    case ThemeOptions.DAY:
      return 'theme_day';
    case ThemeOptions.NIGHT:
      return 'theme_night';
    case ThemeOptions.E_INK:
      return 'theme_e_ink';
    default:
      return 'theme_system';
  }
}

export function themeOptionsToStoredString(value: ThemeOptions): string {
  return value.toString().toLowerCase();
}

export function themeOptionsFromString(value: string): ThemeOptions {
  const up: string = value.toUpperCase();
  for (let i = 0; i < THEME_OPTIONS_VALUES.length; i++) {
    if (THEME_OPTIONS_VALUES[i].toString() === up) {
      return THEME_OPTIONS_VALUES[i];
    }
  }
  return ThemeOptions.SYSTEM;
}

// ---------------- DarkThemePreferences ----------------
export enum DarkThemePreferences {
  BLACK = 'BLACK',
  DARK = 'DARK',
}

export const DARK_THEME_PREFERENCES_VALUES: DarkThemePreferences[] = [
  DarkThemePreferences.BLACK, DarkThemePreferences.DARK,
];

export function darkThemePreferencesStringKey(value: DarkThemePreferences): string {
  return value === DarkThemePreferences.BLACK ? 'dark_theme_preference_black' : 'dark_theme_preference_dark';
}

export function darkThemePreferenceToStoredString(value: DarkThemePreferences): string {
  return value.toString().toLowerCase();
}

export function darkThemePreferenceFromString(value: string): DarkThemePreferences {
  const up: string = value.toUpperCase();
  for (let i = 0; i < DARK_THEME_PREFERENCES_VALUES.length; i++) {
    if (DARK_THEME_PREFERENCES_VALUES[i].toString() === up) {
      return DARK_THEME_PREFERENCES_VALUES[i];
    }
  }
  return DarkThemePreferences.BLACK;
}

// ---------------- SortingOptions ----------------
export enum SortingOptions {
  NEWEST_FIRST = 'NEWEST_FIRST',
  OLDEST_FIRST = 'OLDEST_FIRST',
}

export const SORTING_OPTIONS_VALUES: SortingOptions[] = [SortingOptions.NEWEST_FIRST, SortingOptions.OLDEST_FIRST];

export function sortingOptionsStringKey(value: SortingOptions): string {
  return value === SortingOptions.NEWEST_FIRST ? 'sort_newest_first' : 'sort_oldest_first';
}

export function sortingOptionsToStoredString(value: SortingOptions): string {
  return value.toString().toLowerCase();
}

export function sortingOptionsFromString(value: string): SortingOptions {
  const up: string = value.toUpperCase();
  for (let i = 0; i < SORTING_OPTIONS_VALUES.length; i++) {
    if (SORTING_OPTIONS_VALUES[i].toString() === up) {
      return SORTING_OPTIONS_VALUES[i];
    }
  }
  return SortingOptions.NEWEST_FIRST;
}

// ---------------- ItemOpener ----------------
export enum ItemOpener {
  READER = 'READER',
  CUSTOM_TAB = 'CUSTOM_TAB',
  DEFAULT_BROWSER = 'DEFAULT_BROWSER',
}

export const ITEM_OPENER_VALUES: ItemOpener[] = [ItemOpener.READER, ItemOpener.CUSTOM_TAB, ItemOpener.DEFAULT_BROWSER];

export function itemOpenerStringKey(value: ItemOpener): string {
  switch (value) {
    case ItemOpener.READER:
      return 'open_in_reader';
    case ItemOpener.CUSTOM_TAB:
      return 'open_in_custom_tab';
    default:
      return 'open_in_default_browser';
  }
}

/** 源 setItemOpener：READER→"0"、CUSTOM_TAB→"3"、DEFAULT_BROWSER→"2" */
export function itemOpenerToStoredString(value: ItemOpener): string {
  switch (value) {
    case ItemOpener.READER:
      return PREF_VAL_OPEN_WITH_READER;
    case ItemOpener.CUSTOM_TAB:
      return PREF_VAL_OPEN_WITH_CUSTOM_TAB;
    default:
      return PREF_VAL_OPEN_WITH_BROWSER;
  }
}

/** 源 itemOpenerFromString："2"→浏览器；"1"/"3"→CUSTOM_TAB；其它→READER */
export function itemOpenerFromString(value: string): ItemOpener {
  if (value === PREF_VAL_OPEN_WITH_BROWSER) {
    return ItemOpener.DEFAULT_BROWSER;
  }
  if (value === PREF_VAL_OPEN_WITH_WEBVIEW || value === PREF_VAL_OPEN_WITH_CUSTOM_TAB) {
    return ItemOpener.CUSTOM_TAB;
  }
  return ItemOpener.READER;
}

// ---------------- LinkOpener ----------------
export enum LinkOpener {
  CUSTOM_TAB = 'CUSTOM_TAB',
  DEFAULT_BROWSER = 'DEFAULT_BROWSER',
}

export const LINK_OPENER_VALUES: LinkOpener[] = [LinkOpener.CUSTOM_TAB, LinkOpener.DEFAULT_BROWSER];

export function linkOpenerStringKey(value: LinkOpener): string {
  return value === LinkOpener.CUSTOM_TAB ? 'open_in_custom_tab' : 'open_in_default_browser';
}

/** 源 setLinkOpener：CUSTOM_TAB→"3"、DEFAULT_BROWSER→"2" */
export function linkOpenerToStoredString(value: LinkOpener): string {
  return value === LinkOpener.DEFAULT_BROWSER ? PREF_VAL_OPEN_WITH_BROWSER : PREF_VAL_OPEN_WITH_CUSTOM_TAB;
}

/** 源 linkOpenerFromString："2"→浏览器，其它→CUSTOM_TAB */
export function linkOpenerFromString(value: string): LinkOpener {
  return value === PREF_VAL_OPEN_WITH_BROWSER ? LinkOpener.DEFAULT_BROWSER : LinkOpener.CUSTOM_TAB;
}

// ---------------- SyncFrequency ----------------
/** 数值即源 `minutes` */
export enum SyncFrequency {
  MANUAL = -1,
  EVERY_15_MIN = 15,
  EVERY_30_MIN = 30,
  EVERY_1_HOURS = 60,
  EVERY_3_HOURS = 180,
  EVERY_6_HOURS = 360,
  EVERY_12_HOURS = 720,
  EVERY_DAY = 1440,
}

export const SYNC_FREQUENCY_VALUES: SyncFrequency[] = [
  SyncFrequency.MANUAL, SyncFrequency.EVERY_15_MIN, SyncFrequency.EVERY_30_MIN, SyncFrequency.EVERY_1_HOURS,
  SyncFrequency.EVERY_3_HOURS, SyncFrequency.EVERY_6_HOURS, SyncFrequency.EVERY_12_HOURS, SyncFrequency.EVERY_DAY,
];

export function syncFrequencyMinutes(value: SyncFrequency): number {
  return value as number;
}

/** Kotlin 枚举常量名 */
export function syncFrequencyName(value: SyncFrequency): string {
  switch (value) {
    case SyncFrequency.MANUAL:
      return 'MANUAL';
    case SyncFrequency.EVERY_15_MIN:
      return 'EVERY_15_MIN';
    case SyncFrequency.EVERY_30_MIN:
      return 'EVERY_30_MIN';
    case SyncFrequency.EVERY_1_HOURS:
      return 'EVERY_1_HOURS';
    case SyncFrequency.EVERY_3_HOURS:
      return 'EVERY_3_HOURS';
    case SyncFrequency.EVERY_6_HOURS:
      return 'EVERY_6_HOURS';
    case SyncFrequency.EVERY_12_HOURS:
      return 'EVERY_12_HOURS';
    default:
      return 'EVERY_DAY';
  }
}

export function syncFrequencyStringKey(value: SyncFrequency): string {
  switch (value) {
    case SyncFrequency.MANUAL:
      return 'sync_option_manually';
    case SyncFrequency.EVERY_15_MIN:
      return 'sync_option_every_15min';
    case SyncFrequency.EVERY_30_MIN:
      return 'sync_option_every_30min';
    case SyncFrequency.EVERY_1_HOURS:
      return 'sync_option_every_hour';
    case SyncFrequency.EVERY_3_HOURS:
      return 'sync_option_every_3_hours';
    case SyncFrequency.EVERY_6_HOURS:
      return 'sync_option_every_6_hours';
    case SyncFrequency.EVERY_12_HOURS:
      return 'sync_option_every_12_hours';
    default:
      return 'sync_option_every_day';
  }
}

/** 源 setSyncFrequency：`"${value.minutes}"` */
export function syncFrequencyToStoredString(value: SyncFrequency): string {
  return `${value as number}`;
}

/** 源 syncFrequencyFromString：按 Kotlin `String.toLongOrNull()` 匹配分钟数，失败 MANUAL */
export function syncFrequencyFromString(value: string): SyncFrequency {
  const re: RegExp = new RegExp('^[+-]?[0-9]+$');
  if (!re.test(value)) {
    return SyncFrequency.MANUAL;
  }
  const n: number = Number.parseInt(value, 10);
  for (let i = 0; i < SYNC_FREQUENCY_VALUES.length; i++) {
    if ((SYNC_FREQUENCY_VALUES[i] as number) === n) {
      return SYNC_FREQUENCY_VALUES[i];
    }
  }
  return SyncFrequency.MANUAL;
}

// ---------------- FeedItemStyle ----------------
export enum FeedItemStyle {
  CARD = 'CARD',
  COMPACT_CARD = 'COMPACT_CARD',
  COMPACT = 'COMPACT',
  SUPER_COMPACT = 'SUPER_COMPACT',
}

export const FEED_ITEM_STYLE_VALUES: FeedItemStyle[] = [
  FeedItemStyle.CARD, FeedItemStyle.COMPACT_CARD, FeedItemStyle.COMPACT, FeedItemStyle.SUPER_COMPACT,
];

export function feedItemStyleStringKey(value: FeedItemStyle): string {
  switch (value) {
    case FeedItemStyle.CARD:
      return 'feed_item_style_card';
    case FeedItemStyle.COMPACT_CARD:
      return 'feed_item_style_compact_card';
    case FeedItemStyle.COMPACT:
      return 'feed_item_style_compact';
    default:
      return 'feed_item_style_super_compact';
  }
}

/** 源 setFeedItemStyle：写 `value.name`（大写） */
export function feedItemStyleToStoredString(value: FeedItemStyle): string {
  return value.toString();
}

export function feedItemStyleFromString(value: string): FeedItemStyle {
  const up: string = value.toUpperCase();
  for (let i = 0; i < FEED_ITEM_STYLE_VALUES.length; i++) {
    if (FEED_ITEM_STYLE_VALUES[i].toString() === up) {
      return FEED_ITEM_STYLE_VALUES[i];
    }
  }
  return FeedItemStyle.CARD;
}

// ---------------- SwipeAsRead ----------------
export enum SwipeAsRead {
  DISABLED = 'DISABLED',
  ONLY_FROM_END = 'ONLY_FROM_END',
  FROM_ANYWHERE = 'FROM_ANYWHERE',
}

export const SWIPE_AS_READ_VALUES: SwipeAsRead[] = [
  SwipeAsRead.DISABLED, SwipeAsRead.ONLY_FROM_END, SwipeAsRead.FROM_ANYWHERE,
];

export function swipeAsReadStringKey(value: SwipeAsRead): string {
  switch (value) {
    case SwipeAsRead.DISABLED:
      return 'disabled';
    case SwipeAsRead.ONLY_FROM_END:
      return 'only_from_end';
    default:
      return 'from_anywhere';
  }
}

/** 源 setSwipeAsRead：写 `value.name`（大写） */
export function swipeAsReadToStoredString(value: SwipeAsRead): string {
  return value.toString();
}

export function swipeAsReadFromString(value: string): SwipeAsRead {
  const up: string = value.toUpperCase();
  for (let i = 0; i < SWIPE_AS_READ_VALUES.length; i++) {
    if (SWIPE_AS_READ_VALUES[i].toString() === up) {
      return SWIPE_AS_READ_VALUES[i];
    }
  }
  return SwipeAsRead.ONLY_FROM_END;
}
