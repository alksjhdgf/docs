/*
 * SettingsKeys — 源 archmodel/SettingsStore.kt:645-770 与 util/PrefUtils.kt:8 的全部 PREF_* key 字面值（逐字照搬，大小写敏感），
 * 以及各设置的"源存储字符串"编解码（SettingsCodec）与 Kotlin 字符串解析语义（KotlinParse）。
 *
 * 存储格式（必须与源一致，保证 OPML <feeder:settings> 互导兼容）：
 *  - pref_theme / pref_dark_theme / pref_sort：枚举名小写（"system"/"black"/"newest_first"），读时 uppercase 再匹配
 *  - pref_feed_item_style / pref_swipe_as_read：枚举名大写（"CARD"/"ONLY_FROM_END"），读时 uppercase 再匹配
 *  - pref_default_open_item_with / pref_open_links_with：数字码 "0"/"1"/"2"/"3"
 *  - pref_sync_freq：分钟数字符串（"-1"/"15"/…/"1440"）
 *  - pref_max_item_count_per_feed：十进制字符串（"100"）
 */
import {
  ThemeOptions,
  DarkThemePreferences,
  SortingOptions,
  FeedItemStyle,
  SwipeAsRead,
  ItemOpener,
  LinkOpener,
  SyncFrequency
} from '../model/Enums';

/** Boolean：Feeder News 订阅源是否已添加 */
export const PREF_ADDED_FEEDER_NEWS: string = 'pref_added_feeder_news';

/** 会话/导航状态（不导出） */
export const PREF_LAST_FEED_TAG: string = 'pref_last_feed_tag';
export const PREF_LAST_FEED_ID: string = 'pref_last_feed_id';
export const PREF_LAST_WIDGET_FEED_TAG: string = 'pref_widget_last_feed_tag';
export const PREF_LAST_WIDGET_FEED_ID: string = 'pref_widget_last_feed_id';
export const PREF_LAST_ARTICLE_ID: string = 'pref_last_article_id';
export const PREF_IS_ARTICLE_OPEN: string = 'pref_is_article_open';

/** 主题 */
export const PREF_THEME: string = 'pref_theme';
export const PREF_DARK_THEME: string = 'pref_dark_theme';
export const PREF_DYNAMIC_THEME: string = 'pref_dynamic_theme';

/** 排序 */
export const PREF_SORT: string = 'pref_sort';

/** FAB */
export const PREF_SHOW_FAB: string = 'pref_show_fab';

export const PREF_FEED_ITEM_STYLE: string = 'pref_feed_item_style';
export const PREF_SWIPE_AS_READ: string = 'pref_swipe_as_read';

/** 屏蔽词 */
export const PREF_BLOCKLIST_APPLY_TO_SUMMARIES: string = 'pref_blocklist_apply_to_summaries';
export const PREF_BLOCKLIST_APPLY_TO_LINKS: string = 'pref_blocklist_apply_to_links';

/** 同步 */
export const PREF_SYNC_ONLY_CHARGING: string = 'pref_sync_only_charging';
export const PREF_SYNC_ONLY_WIFI: string = 'pref_sync_only_wifi';
export const PREF_SYNC_FREQ: string = 'pref_sync_freq';
export const PREF_SYNC_ON_RESUME: string = 'pref_sync_on_resume';

/** 图片 */
export const PREF_IMG_ONLY_WIFI: string = 'pref_img_only_wifi';
export const PREF_IMG_SHOW_THUMBNAILS: string = 'pref_img_show_thumbnails';

/** 阅读器 */
export const PREF_DEFAULT_OPEN_ITEM_WITH: string = 'pref_default_open_item_with';
export const PREF_OPEN_LINKS_WITH: string = 'pref_open_links_with';
export const PREF_OPEN_ADJACENT: string = 'pref_open_adjacent';
export const PREF_USE_IN_APP_AUDIO_PLAYER: string = 'pref_use_in_app_audio_player';

export const PREF_PAGING_MODE: string = 'pref_paging_mode';
export const PREF_ANIMATED_PAGING: string = 'pref_animated_paging';

export const PREF_VAL_OPEN_WITH_READER: string = '0';
export const PREF_VAL_OPEN_WITH_WEBVIEW: string = '1';
export const PREF_VAL_OPEN_WITH_BROWSER: string = '2';
export const PREF_VAL_OPEN_WITH_CUSTOM_TAB: string = '3';

export const PREF_TEXT_SCALE: string = 'pref_body_text_scale';
export const PREF_FONT: string = 'pref_font';

export const PREF_IS_MARK_AS_READ_ON_SCROLL: string = 'pref_is_mark_as_read_on_scroll';

export const PREF_MAX_LINES: string = 'pref_max_lines';

export const PREFS_FILTER_SAVED: string = 'prefs_filter_saved';
export const PREFS_FILTER_RECENTLY_READ: string = 'prefs_filter_recently_read';
export const PREFS_FILTER_READ: string = 'prefs_filter_read';

export const PREF_LIST_SHOW_ONLY_TITLES: string = 'prefs_list_show_only_titles';
export const PREF_LIST_SHOW_READING_TIME: string = 'pref_show_reading_time';
export const PREF_OPEN_DRAWER_ON_FAB: string = 'pref_open_drawer_on_fab';

/** 朗读 */
export const PREF_READALOUD_USE_DETECT_LANGUAGE: string = 'pref_readaloud_detect_lang';

/** OpenAI 集成 */
export const PREF_OPENAI_KEY: string = 'pref_openai_key';
export const PREF_OPENAI_MODEL_ID: string = 'pref_openai_model_id';
export const PREF_OPENAI_URL: string = 'pref_openai_url';
export const PREF_OPENAI_AZURE_VERSION: string = 'pref_openai_azure_version';
export const PREF_OPENAI_AZURE_DEPLOYMENT_ID: string = 'pref_openai_azure_deployment_id';
export const PREF_OPENAI_REQUEST_TIMEOUT_SECONDS: string = 'pref_openai_request_timeout_seconds';

/** 翻译（遗留 key 名为兼容旧 prefs 与 OPML，必须保留） */
export const PREF_PREFERRED_TRANSLATION_LANGUAGE: string = 'pref_openai_translation_language';
export const PREF_TRANSLATION_API_KEY: string = 'pref_translation_api_key';
export const PREF_TRANSLATION_API_MODEL_ID: string = 'pref_translation_api_model_id';
export const PREF_TRANSLATION_API_URL: string = 'pref_translation_api_url';
export const PREF_TRANSLATION_API_AZURE_VERSION: string = 'pref_translation_api_azure_version';
export const PREF_TRANSLATION_API_AZURE_DEPLOYMENT_ID: string = 'pref_translation_api_azure_deployment_id';
export const PREF_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS: string = 'pref_translation_api_request_timeout_seconds';

export const PREF_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT: string = 'pref_translate_feed_cards_by_default';
export const PREF_TRANSLATE_ARTICLES_BY_DEFAULT: string = 'pref_translate_articles_by_default';

/** 外观 */
export const PREF_SHOW_TITLE_UNREAD_COUNT: string = 'pref_show_title_unread_count';
export const PREF_FORCE_SINGLE_COLUMN: string = 'pref_force_single_column';

/** 数据库（源 util/PrefUtils.kt:8） */
export const PREF_MAX_ITEM_COUNT_PER_FEED: string = 'pref_max_item_count_per_feed';

/** 非持久伪 key：仅用于 SettingsStore.observe 回调区分 minReadTime 变化（minReadTime 从不落盘） */
export const SETTING_KEY_MIN_READ_TIME: string = 'minReadTime';

/** 字体路径（源 FontSelection.RobotoFlex.path / SystemDefault.path）；用户字体为 fonts 目录下相对路径 */
export const FONT_PATH_ROBOTO_FLEX: string = 'bundled/roboto_flex';
export const FONT_PATH_SYSTEM_DEFAULT: string = 'system/default';
/** 源 defaultFont = FontSelection.RobotoFlex */
export const DEFAULT_FONT_PATH: string = FONT_PATH_ROBOTO_FLEX;
/** 源 FilePathProvider.fontsDir = filesDir/fonts */
export const FONTS_DIR_NAME: string = 'fonts';

/** Android SharedPreferences 默认文件名等价物（PreferenceManager.getDefaultSharedPreferences） */
export const SETTINGS_PREFERENCES_NAME: string = 'com.nononsenseapps.feeder_preferences';

/**
 * Kotlin 标准库字符串解析语义（String.toBoolean / toIntOrNull / toLongOrNull / toFloatOrNull）与 Float.toString。
 */
export class KotlinParse {
  /** Kotlin String.toBoolean()：仅忽略大小写的 "true" 为 true */
  static toBoolean(value: string): boolean {
    return value.toLowerCase() === 'true';
  }

  /** Kotlin String.toIntOrNull()：可选符号 + 十进制数字，且在 Int 范围内 */
  static toIntOrNull(value: string): number | null {
    const re = new RegExp('^[+-]?[0-9]+$');
    if (!re.test(value)) {
      return null;
    }
    const n = Number(value);
    if (n < -2147483648 || n > 2147483647) {
      return null;
    }
    return n;
  }

  /** Kotlin String.toLongOrNull()（number 精度内） */
  static toLongOrNull(value: string): number | null {
    const re = new RegExp('^[+-]?[0-9]+$');
    if (!re.test(value)) {
      return null;
    }
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return null;
    }
    return n;
  }

  /** Kotlin String.toFloatOrNull()（Java Float.parseFloat 可接受格式的近似：小数/指数/可选 f/F/d/D 后缀/NaN/Infinity） */
  static toFloatOrNull(value: string): number | null {
    const re = new RegExp('^[+-]?(NaN|Infinity|(([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?[fFdD]?))$');
    if (!re.test(value)) {
      return null;
    }
    let s = value;
    const last = s.charAt(s.length - 1);
    if (last === 'f' || last === 'F' || last === 'd' || last === 'D') {
      s = s.substring(0, s.length - 1);
    }
    const n = Number(s);
    return Math.fround(n);
  }

  /** Kotlin Float.toString()：最短可还原 float 表示，整数补 ".0"（textScale 等 Float 设置导出用） */
  static floatToString(v: number): string {
    if (Number.isNaN(v)) {
      return 'NaN';
    }
    if (v === Number.POSITIVE_INFINITY) {
      return 'Infinity';
    }
    if (v === Number.NEGATIVE_INFINITY) {
      return '-Infinity';
    }
    const f = Math.fround(v);
    let s = '';
    for (let p = 1; p <= 9; p++) {
      const candidate = Number(f.toPrecision(p));
      if (Math.fround(candidate) === f) {
        s = String(candidate);
        break;
      }
    }
    if (s === '') {
      s = String(f);
    }
    if (s.indexOf('e') < 0 && s.indexOf('.') < 0 && s.indexOf('N') < 0) {
      s = s + '.0';
    }
    return s;
  }
}

/**
 * 源 SettingsStore.kt:932-988 的 *FromString 解析函数与 setter 内的存储编码，逐项照源。
 * 用 switch 显式映射枚举成员，不依赖 core/model/Enums 内部取值表示。
 */
export class SettingsCodec {
  // ---- ThemeOptions：存小写名，读 uppercase 后 valueOf，失败→SYSTEM
  static themeFromString(value: string): ThemeOptions {
    switch (value.toUpperCase()) {
      case 'DAY':
        return ThemeOptions.DAY;
      case 'NIGHT':
        return ThemeOptions.NIGHT;
      case 'E_INK':
        return ThemeOptions.E_INK;
      case 'SYSTEM':
        return ThemeOptions.SYSTEM;
      default:
        return ThemeOptions.SYSTEM;
    }
  }

  static themeToPref(value: ThemeOptions): string {
    switch (value) {
      case ThemeOptions.DAY:
        return 'day';
      case ThemeOptions.NIGHT:
        return 'night';
      case ThemeOptions.E_INK:
        return 'e_ink';
      default:
        return 'system';
    }
  }

  // ---- DarkThemePreferences：存小写名，失败→BLACK
  static darkThemeFromString(value: string): DarkThemePreferences {
    switch (value.toUpperCase()) {
      case 'BLACK':
        return DarkThemePreferences.BLACK;
      case 'DARK':
        return DarkThemePreferences.DARK;
      default:
        return DarkThemePreferences.BLACK;
    }
  }

  static darkThemeToPref(value: DarkThemePreferences): string {
    switch (value) {
      case DarkThemePreferences.DARK:
        return 'dark';
      default:
        return 'black';
    }
  }

  // ---- SortingOptions：存小写名，失败→NEWEST_FIRST
  static sortingFromString(value: string): SortingOptions {
    switch (value.toUpperCase()) {
      case 'NEWEST_FIRST':
        return SortingOptions.NEWEST_FIRST;
      case 'OLDEST_FIRST':
        return SortingOptions.OLDEST_FIRST;
      default:
        return SortingOptions.NEWEST_FIRST;
    }
  }

  static sortingToPref(value: SortingOptions): string {
    switch (value) {
      case SortingOptions.OLDEST_FIRST:
        return 'oldest_first';
      default:
        return 'newest_first';
    }
  }

  // ---- FeedItemStyle：存大写名，读 uppercase，失败→CARD
  static feedItemStyleFromString(value: string): FeedItemStyle {
    switch (value.toUpperCase()) {
      case 'CARD':
        return FeedItemStyle.CARD;
      case 'COMPACT_CARD':
        return FeedItemStyle.COMPACT_CARD;
      case 'COMPACT':
        return FeedItemStyle.COMPACT;
      case 'SUPER_COMPACT':
        return FeedItemStyle.SUPER_COMPACT;
      default:
        return FeedItemStyle.CARD;
    }
  }

  static feedItemStyleToPref(value: FeedItemStyle): string {
    switch (value) {
      case FeedItemStyle.COMPACT_CARD:
        return 'COMPACT_CARD';
      case FeedItemStyle.COMPACT:
        return 'COMPACT';
      case FeedItemStyle.SUPER_COMPACT:
        return 'SUPER_COMPACT';
      default:
        return 'CARD';
    }
  }

  // ---- SwipeAsRead：存大写名，失败→ONLY_FROM_END
  static swipeAsReadFromString(value: string): SwipeAsRead {
    switch (value.toUpperCase()) {
      case 'DISABLED':
        return SwipeAsRead.DISABLED;
      case 'ONLY_FROM_END':
        return SwipeAsRead.ONLY_FROM_END;
      case 'FROM_ANYWHERE':
        return SwipeAsRead.FROM_ANYWHERE;
      default:
        return SwipeAsRead.ONLY_FROM_END;
    }
  }

  static swipeAsReadToPref(value: SwipeAsRead): string {
    switch (value) {
      case SwipeAsRead.DISABLED:
        return 'DISABLED';
      case SwipeAsRead.FROM_ANYWHERE:
        return 'FROM_ANYWHERE';
      default:
        return 'ONLY_FROM_END';
    }
  }

  // ---- ItemOpener："2"→DEFAULT_BROWSER；"1"(旧 webview)/"3"→CUSTOM_TAB；其它→READER
  static itemOpenerFromString(value: string): ItemOpener {
    if (value === PREF_VAL_OPEN_WITH_BROWSER) {
      return ItemOpener.DEFAULT_BROWSER;
    }
    if (value === PREF_VAL_OPEN_WITH_WEBVIEW || value === PREF_VAL_OPEN_WITH_CUSTOM_TAB) {
      return ItemOpener.CUSTOM_TAB;
    }
    return ItemOpener.READER;
  }

  static itemOpenerToPref(value: ItemOpener): string {
    switch (value) {
      case ItemOpener.CUSTOM_TAB:
        return PREF_VAL_OPEN_WITH_CUSTOM_TAB;
      case ItemOpener.DEFAULT_BROWSER:
        return PREF_VAL_OPEN_WITH_BROWSER;
      default:
        return PREF_VAL_OPEN_WITH_READER;
    }
  }

  // ---- LinkOpener："2"→DEFAULT_BROWSER，其它→CUSTOM_TAB
  static linkOpenerFromString(value: string): LinkOpener {
    if (value === PREF_VAL_OPEN_WITH_BROWSER) {
      return LinkOpener.DEFAULT_BROWSER;
    }
    return LinkOpener.CUSTOM_TAB;
  }

  static linkOpenerToPref(value: LinkOpener): string {
    switch (value) {
      case LinkOpener.DEFAULT_BROWSER:
        return PREF_VAL_OPEN_WITH_BROWSER;
      default:
        return PREF_VAL_OPEN_WITH_CUSTOM_TAB;
    }
  }

  // ---- SyncFrequency：分钟数；toLongOrNull 后精确匹配，无法识别→MANUAL（注意：不是默认 60）
  static syncFrequencyFromString(value: string): SyncFrequency {
    const minutes = KotlinParse.toLongOrNull(value);
    if (minutes === null) {
      return SyncFrequency.MANUAL;
    }
    switch (minutes) {
      case 15:
        return SyncFrequency.EVERY_15_MIN;
      case 30:
        return SyncFrequency.EVERY_30_MIN;
      case 60:
        return SyncFrequency.EVERY_1_HOURS;
      case 180:
        return SyncFrequency.EVERY_3_HOURS;
      case 360:
        return SyncFrequency.EVERY_6_HOURS;
      case 720:
        return SyncFrequency.EVERY_12_HOURS;
      case 1440:
        return SyncFrequency.EVERY_DAY;
      default:
        return SyncFrequency.MANUAL;
    }
  }

  /** SyncFrequency.minutes（MANUAL=-1） */
  static syncFrequencyMinutes(value: SyncFrequency): number {
    switch (value) {
      case SyncFrequency.EVERY_15_MIN:
        return 15;
      case SyncFrequency.EVERY_30_MIN:
        return 30;
      case SyncFrequency.EVERY_1_HOURS:
        return 60;
      case SyncFrequency.EVERY_3_HOURS:
        return 180;
      case SyncFrequency.EVERY_6_HOURS:
        return 360;
      case SyncFrequency.EVERY_12_HOURS:
        return 720;
      case SyncFrequency.EVERY_DAY:
        return 1440;
      default:
        return -1;
    }
  }

  static syncFrequencyToPref(value: SyncFrequency): string {
    return `${SettingsCodec.syncFrequencyMinutes(value)}`;
  }
}
