/*
 * SettingsOptions — Settings 页下拉菜单的选项清单、本地化文案映射与副标题格式化（纯逻辑，可单测）。
 * 源：ui/compose/settings/Settings.kt
 *   - :468 Theme 菜单（SYSTEM, DAY, NIGHT, E_INK 此顺序）、:504 Dark theme（BLACK, DARK）
 *   - :592 SyncFrequency.entries、:627 Max items（50/100/200/500/1000）、:670 Sort、:696 FeedItemStyle.entries、
 *     :708 Max lines 1..10、:724 SwipeAsRead.entries、:772 ItemOpener、:789 LinkOpener
 *   - :1236 ListDialogSetting 副标题 `joinToString(" ", limit = 5)`
 *   - :1336 NotificationsSetting 副标题 `filter{notify}.map{title}.take(4).joinToString(", ", limit = 3)`
 *   - :111 formatFileSize（复用 openai/DownloadedModelsSection.formatFileSize）
 * Option 包装类 toString() = 本地化名（SettingsStore.kt:840-906 stringId）→ 这里用 label: ResourceStr。
 */
import {
  DarkThemePreferences, FeedItemStyle, ItemOpener, LinkOpener, SortingOptions, SwipeAsRead, SyncFrequency,
  SYNC_FREQUENCY_VALUES, FEED_ITEM_STYLE_VALUES, SWIPE_AS_READ_VALUES, ThemeOptions
} from '../../core/model/Enums';
import { formatFileSize } from '../openai/DownloadedModelsSection';

/** 下拉菜单单项：key 用于比较当前值（源 `value == currentValue`），label 为显示文本 */
export class MenuOption {
  optionKey: string = '';
  label: ResourceStr = '';

  constructor(optionKey: string, label: ResourceStr) {
    this.optionKey = optionKey;
    this.label = label;
  }
}

// ------------------------------------------------------------------ 文案映射（$r 只接受字面量 → 逐项 switch）

export function themeLabel(v: ThemeOptions): Resource {
  switch (v) {
    case ThemeOptions.DAY:
      return $r('app.string.theme_day');
    case ThemeOptions.NIGHT:
      return $r('app.string.theme_night');
    case ThemeOptions.E_INK:
      return $r('app.string.theme_e_ink');
    default:
      return $r('app.string.theme_system');
  }
}

export function darkThemeLabel(v: DarkThemePreferences): Resource {
  return v === DarkThemePreferences.DARK ? $r('app.string.dark_theme_preference_dark') :
  $r('app.string.dark_theme_preference_black');
}

export function sortingLabel(v: SortingOptions): Resource {
  return v === SortingOptions.OLDEST_FIRST ? $r('app.string.sort_oldest_first') : $r('app.string.sort_newest_first');
}

export function syncFrequencyLabel(v: SyncFrequency): Resource {
  switch (v) {
    case SyncFrequency.MANUAL:
      return $r('app.string.sync_option_manually');
    case SyncFrequency.EVERY_15_MIN:
      return $r('app.string.sync_option_every_15min');
    case SyncFrequency.EVERY_30_MIN:
      return $r('app.string.sync_option_every_30min');
    case SyncFrequency.EVERY_1_HOURS:
      return $r('app.string.sync_option_every_hour');
    case SyncFrequency.EVERY_3_HOURS:
      return $r('app.string.sync_option_every_3_hours');
    case SyncFrequency.EVERY_6_HOURS:
      return $r('app.string.sync_option_every_6_hours');
    case SyncFrequency.EVERY_12_HOURS:
      return $r('app.string.sync_option_every_12_hours');
    default:
      return $r('app.string.sync_option_every_day');
  }
}

export function feedItemStyleLabel(v: FeedItemStyle): Resource {
  switch (v) {
    case FeedItemStyle.COMPACT_CARD:
      return $r('app.string.feed_item_style_compact_card');
    case FeedItemStyle.COMPACT:
      return $r('app.string.feed_item_style_compact');
    case FeedItemStyle.SUPER_COMPACT:
      return $r('app.string.feed_item_style_super_compact');
    default:
      return $r('app.string.feed_item_style_card');
  }
}

export function swipeAsReadLabel(v: SwipeAsRead): Resource {
  switch (v) {
    case SwipeAsRead.DISABLED:
      return $r('app.string.disabled');
    case SwipeAsRead.FROM_ANYWHERE:
      return $r('app.string.from_anywhere');
    default:
      return $r('app.string.only_from_end');
  }
}

export function itemOpenerLabel(v: ItemOpener): Resource {
  switch (v) {
    case ItemOpener.CUSTOM_TAB:
      return $r('app.string.open_in_custom_tab');
    case ItemOpener.DEFAULT_BROWSER:
      return $r('app.string.open_in_default_browser');
    default:
      return $r('app.string.open_in_reader');
  }
}

export function linkOpenerLabel(v: LinkOpener): Resource {
  return v === LinkOpener.DEFAULT_BROWSER ? $r('app.string.open_in_default_browser') :
  $r('app.string.open_in_custom_tab');
}

// ------------------------------------------------------------------ 选项清单（顺序逐字照源）

/** ST-A06：System、Day、Night、E Ink（Settings.kt:472-477，与枚举声明顺序不同） */
export const THEME_MENU_VALUES: ThemeOptions[] = [
  ThemeOptions.SYSTEM, ThemeOptions.DAY, ThemeOptions.NIGHT, ThemeOptions.E_INK
];

/** ST-A08：Black、Dark */
export const DARK_THEME_MENU_VALUES: DarkThemePreferences[] = [DarkThemePreferences.BLACK, DarkThemePreferences.DARK];

/** ST-A25 */
export const SORTING_MENU_VALUES: SortingOptions[] = [SortingOptions.NEWEST_FIRST, SortingOptions.OLDEST_FIRST];

/** ST-A31 */
export const ITEM_OPENER_MENU_VALUES: ItemOpener[] = [ItemOpener.READER, ItemOpener.CUSTOM_TAB, ItemOpener.DEFAULT_BROWSER];
export const LINK_OPENER_MENU_VALUES: LinkOpener[] = [LinkOpener.CUSTOM_TAB, LinkOpener.DEFAULT_BROWSER];

/** ST-A21 */
export const MAX_ITEMS_PER_FEED_VALUES: number[] = [50, 100, 200, 500, 1000];

/** ST-A27 */
export const MAX_LINES_VALUES: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

export function themeMenuOptions(): MenuOption[] {
  return THEME_MENU_VALUES.map((v: ThemeOptions) => new MenuOption(v.toString(), themeLabel(v)));
}

export function darkThemeMenuOptions(): MenuOption[] {
  return DARK_THEME_MENU_VALUES.map((v: DarkThemePreferences) => new MenuOption(v.toString(), darkThemeLabel(v)));
}

/** ST-A18：SyncFrequency.entries 顺序 */
export function syncFrequencyMenuOptions(): MenuOption[] {
  return SYNC_FREQUENCY_VALUES.map((v: SyncFrequency) => new MenuOption(`${v as number}`, syncFrequencyLabel(v)));
}

export function sortingMenuOptions(): MenuOption[] {
  return SORTING_MENU_VALUES.map((v: SortingOptions) => new MenuOption(v.toString(), sortingLabel(v)));
}

/** ST-A26：FeedItemStyle.entries 顺序 */
export function feedItemStyleMenuOptions(): MenuOption[] {
  return FEED_ITEM_STYLE_VALUES.map((v: FeedItemStyle) => new MenuOption(v.toString(), feedItemStyleLabel(v)));
}

/** ST-A28：SwipeAsRead.entries 顺序 */
export function swipeAsReadMenuOptions(): MenuOption[] {
  return SWIPE_AS_READ_VALUES.map((v: SwipeAsRead) => new MenuOption(v.toString(), swipeAsReadLabel(v)));
}

export function itemOpenerMenuOptions(): MenuOption[] {
  return ITEM_OPENER_MENU_VALUES.map((v: ItemOpener) => new MenuOption(v.toString(), itemOpenerLabel(v)));
}

export function linkOpenerMenuOptions(): MenuOption[] {
  return LINK_OPENER_MENU_VALUES.map((v: LinkOpener) => new MenuOption(v.toString(), linkOpenerLabel(v)));
}

/** Int 型菜单直接显示数字（源 MenuSetting<Int> 的 toString） */
export function intMenuOptions(values: number[]): MenuOption[] {
  return values.map((n: number) => new MenuOption(`${n}`, `${n}`));
}

export function syncFrequencyFromKey(optionKey: string): SyncFrequency {
  for (let i = 0; i < SYNC_FREQUENCY_VALUES.length; i++) {
    if (`${SYNC_FREQUENCY_VALUES[i] as number}` === optionKey) {
      return SYNC_FREQUENCY_VALUES[i];
    }
  }
  return SyncFrequency.EVERY_1_HOURS;
}

export function themeFromKey(optionKey: string): ThemeOptions {
  for (let i = 0; i < THEME_MENU_VALUES.length; i++) {
    if (THEME_MENU_VALUES[i].toString() === optionKey) {
      return THEME_MENU_VALUES[i];
    }
  }
  return ThemeOptions.SYSTEM;
}

export function darkThemeFromKey(optionKey: string): DarkThemePreferences {
  return optionKey === DarkThemePreferences.DARK.toString() ? DarkThemePreferences.DARK : DarkThemePreferences.BLACK;
}

export function sortingFromKey(optionKey: string): SortingOptions {
  return optionKey === SortingOptions.OLDEST_FIRST.toString() ? SortingOptions.OLDEST_FIRST :
  SortingOptions.NEWEST_FIRST;
}

export function feedItemStyleFromKey(optionKey: string): FeedItemStyle {
  for (let i = 0; i < FEED_ITEM_STYLE_VALUES.length; i++) {
    if (FEED_ITEM_STYLE_VALUES[i].toString() === optionKey) {
      return FEED_ITEM_STYLE_VALUES[i];
    }
  }
  return FeedItemStyle.CARD;
}

export function swipeAsReadFromKey(optionKey: string): SwipeAsRead {
  for (let i = 0; i < SWIPE_AS_READ_VALUES.length; i++) {
    if (SWIPE_AS_READ_VALUES[i].toString() === optionKey) {
      return SWIPE_AS_READ_VALUES[i];
    }
  }
  return SwipeAsRead.ONLY_FROM_END;
}

export function itemOpenerFromKey(optionKey: string): ItemOpener {
  for (let i = 0; i < ITEM_OPENER_MENU_VALUES.length; i++) {
    if (ITEM_OPENER_MENU_VALUES[i].toString() === optionKey) {
      return ITEM_OPENER_MENU_VALUES[i];
    }
  }
  return ItemOpener.READER;
}

export function linkOpenerFromKey(optionKey: string): LinkOpener {
  return optionKey === LinkOpener.DEFAULT_BROWSER.toString() ? LinkOpener.DEFAULT_BROWSER : LinkOpener.CUSTOM_TAB;
}

// ------------------------------------------------------------------ 副标题格式化

/**
 * Kotlin `Iterable.joinToString(separator, limit = n)`（truncated = "..."）：
 * 超过 limit 个元素时，前 limit 个后接 separator + "..."。
 */
export function joinToStringLimited(values: string[], separator: string, limit: number): string {
  let out = '';
  let count = 0;
  for (let i = 0; i < values.length; i++) {
    count++;
    if (count > 1) {
      out += separator;
    }
    if (limit < 0 || count <= limit) {
      out += values[i];
    } else {
      break;
    }
  }
  if (limit >= 0 && count > limit) {
    out += '...';
  }
  return out;
}

/** Kotlin `List<String>.sorted()`：按 UTF-16 码元自然序 */
export function sortedStrings(values: string[]): string[] {
  return values.slice().sort((a: string, b: string): number => a < b ? -1 : (a > b ? 1 : 0));
}

/** ST-A13：`Filters` 副标题 = 已排序过滤词以空格连接，最多 5 个，超出追加 `...` */
export function blockListSubtitle(sortedBlockList: string[]): string {
  return joinToStringLimited(sortedBlockList, ' ', 5);
}

/** 源 UIFeedSettings(feedId, title, notify) */
export class UIFeedSettings {
  feedId: number = 0;
  feedTitle: string = '';
  notify: boolean = false;

  constructor(feedId: number, feedTitle: string, notify: boolean) {
    this.feedId = feedId;
    this.feedTitle = feedTitle;
    this.notify = notify;
  }
}

/** ST-A09（权限已授予分支）：已开启通知的订阅标题 `, ` 连接，最多 3 个，第 4 个存在时追加 `...` */
export function notifySubtitle(items: UIFeedSettings[]): string {
  const titles: string[] = [];
  for (let i = 0; i < items.length && titles.length < 4; i++) {
    if (items[i].notify) {
      titles.push(items[i].feedTitle);
    }
  }
  return joinToStringLimited(titles, ', ', 3);
}

/** ST-A39：源 formatFileSize（≥1 MiB 一位小数 MB；≥1 KiB 整数 KB；否则 `<n> B`） */
export function formatModelSize(bytes: number): string {
  return formatFileSize(bytes);
}
