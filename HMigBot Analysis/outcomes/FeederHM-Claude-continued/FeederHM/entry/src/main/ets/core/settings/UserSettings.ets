/*
 * UserSettings — 源 archmodel/SettingsStore.kt:772-838 的 OPML 导入/导出白名单（实数 51 项，逐项核对源 enum 常量；explore 文档写的 49 为误数），
 * getAllSettings()（SettingsStore.kt:630-638）与 setSetting()（model/opml/OPMLImporter.kt:43-162 的 saveSetting）。
 * 会话状态键（pref_last_feed_*、pref_widget_last_feed_*、pref_last_article_id、pref_is_article_open）不在白名单内。
 * 注意：OpenAI/翻译 API Key 在白名单内 → 明文进入 OPML 导出（照源行为）。
 */
import { SettingsStore } from './SettingsStore';
import { OpenAISettings } from './SettingsModels';
import { SettingsCodec, KotlinParse } from './SettingsKeys';

/** 枚举值 = 源 key 字面值（enum 初始化须为字面量，故此处与 SettingsKeys 逐字重复） */
export enum UserSettings {
  SETTING_ADDED_FEEDER_NEWS = 'pref_added_feeder_news',
  SETTING_THEME = 'pref_theme',
  SETTING_DARK_THEME = 'pref_dark_theme',
  SETTING_DYNAMIC_THEME = 'pref_dynamic_theme',
  SETTING_SORT = 'pref_sort',
  SETTING_SHOW_FAB = 'pref_show_fab',
  SETTING_FEED_ITEM_STYLE = 'pref_feed_item_style',
  SETTING_SWIPE_AS_READ = 'pref_swipe_as_read',
  SETTING_SYNC_ONLY_CHARGING = 'pref_sync_only_charging',
  SETTING_SYNC_ONLY_WIFI = 'pref_sync_only_wifi',
  SETTING_SYNC_FREQ = 'pref_sync_freq',
  SETTING_SYNC_ON_RESUME = 'pref_sync_on_resume',
  SETTING_IMG_ONLY_WIFI = 'pref_img_only_wifi',
  SETTING_IMG_SHOW_THUMBNAILS = 'pref_img_show_thumbnails',
  SETTING_DEFAULT_OPEN_ITEM_WITH = 'pref_default_open_item_with',
  SETTING_OPEN_LINKS_WITH = 'pref_open_links_with',
  SETTING_OPEN_ADJACENT = 'pref_open_adjacent',
  SETTING_USE_IN_APP_AUDIO_PLAYER = 'pref_use_in_app_audio_player',
  SETTING_PAGING_MODE = 'pref_paging_mode',
  SETTING_ANIMATED_PAGING = 'pref_animated_paging',
  SETTING_TEXT_SCALE = 'pref_body_text_scale',
  SETTING_IS_MARK_AS_READ_ON_SCROLL = 'pref_is_mark_as_read_on_scroll',
  SETTING_READALOUD_USE_DETECT_LANGUAGE = 'pref_readaloud_detect_lang',
  SETTING_MAX_LINES = 'pref_max_lines',
  SETTINGS_FILTER_SAVED = 'prefs_filter_saved',
  SETTINGS_FILTER_RECENTLY_READ = 'prefs_filter_recently_read',
  SETTINGS_FILTER_READ = 'prefs_filter_read',
  SETTINGS_LIST_SHOW_ONLY_TITLES = 'prefs_list_show_only_titles',
  SETTING_FONT = 'pref_font',
  SETTING_LIST_SHOW_READING_TIME = 'pref_show_reading_time',
  SETTING_OPEN_DRAWER_ON_FAB = 'pref_open_drawer_on_fab',
  SETTING_SHOW_TITLE_UNREAD_COUNT = 'pref_show_title_unread_count',
  SETTING_MAX_ITEM_COUNT_PER_FEED = 'pref_max_item_count_per_feed',
  SETTING_OPENAI_KEY = 'pref_openai_key',
  SETTING_OPENAI_MODEL_ID = 'pref_openai_model_id',
  SETTING_OPENAI_URL = 'pref_openai_url',
  SETTING_OPENAI_AZURE_VERSION = 'pref_openai_azure_version',
  SETTING_OPENAI_AZURE_DEPLOYMENT_ID = 'pref_openai_azure_deployment_id',
  SETTING_OPENAI_REQUEST_TIMEOUT_SECONDS = 'pref_openai_request_timeout_seconds',
  SETTING_BLOCKLIST_APPLY_TO_SUMMARIES = 'pref_blocklist_apply_to_summaries',
  SETTING_BLOCKLIST_APPLY_TO_LINKS = 'pref_blocklist_apply_to_links',
  SETTING_PREFERRED_TRANSLATION_LANGUAGE = 'pref_openai_translation_language',
  SETTING_TRANSLATION_API_KEY = 'pref_translation_api_key',
  SETTING_TRANSLATION_API_MODEL_ID = 'pref_translation_api_model_id',
  SETTING_TRANSLATION_API_URL = 'pref_translation_api_url',
  SETTING_TRANSLATION_API_AZURE_VERSION = 'pref_translation_api_azure_version',
  SETTING_TRANSLATION_API_AZURE_DEPLOYMENT_ID = 'pref_translation_api_azure_deployment_id',
  SETTING_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS = 'pref_translation_api_request_timeout_seconds',
  SETTING_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT = 'pref_translate_feed_cards_by_default',
  SETTING_TRANSLATE_ARTICLES_BY_DEFAULT = 'pref_translate_articles_by_default',
  SETTINGS_FORCE_SINGLE_COLUMN = 'pref_force_single_column'
}

/** 源 UserSettings.entries（声明顺序）；共 51 项 */
export const ALL_USER_SETTINGS: UserSettings[] = [
  UserSettings.SETTING_ADDED_FEEDER_NEWS,
  UserSettings.SETTING_THEME,
  UserSettings.SETTING_DARK_THEME,
  UserSettings.SETTING_DYNAMIC_THEME,
  UserSettings.SETTING_SORT,
  UserSettings.SETTING_SHOW_FAB,
  UserSettings.SETTING_FEED_ITEM_STYLE,
  UserSettings.SETTING_SWIPE_AS_READ,
  UserSettings.SETTING_SYNC_ONLY_CHARGING,
  UserSettings.SETTING_SYNC_ONLY_WIFI,
  UserSettings.SETTING_SYNC_FREQ,
  UserSettings.SETTING_SYNC_ON_RESUME,
  UserSettings.SETTING_IMG_ONLY_WIFI,
  UserSettings.SETTING_IMG_SHOW_THUMBNAILS,
  UserSettings.SETTING_DEFAULT_OPEN_ITEM_WITH,
  UserSettings.SETTING_OPEN_LINKS_WITH,
  UserSettings.SETTING_OPEN_ADJACENT,
  UserSettings.SETTING_USE_IN_APP_AUDIO_PLAYER,
  UserSettings.SETTING_PAGING_MODE,
  UserSettings.SETTING_ANIMATED_PAGING,
  UserSettings.SETTING_TEXT_SCALE,
  UserSettings.SETTING_IS_MARK_AS_READ_ON_SCROLL,
  UserSettings.SETTING_READALOUD_USE_DETECT_LANGUAGE,
  UserSettings.SETTING_MAX_LINES,
  UserSettings.SETTINGS_FILTER_SAVED,
  UserSettings.SETTINGS_FILTER_RECENTLY_READ,
  UserSettings.SETTINGS_FILTER_READ,
  UserSettings.SETTINGS_LIST_SHOW_ONLY_TITLES,
  UserSettings.SETTING_FONT,
  UserSettings.SETTING_LIST_SHOW_READING_TIME,
  UserSettings.SETTING_OPEN_DRAWER_ON_FAB,
  UserSettings.SETTING_SHOW_TITLE_UNREAD_COUNT,
  UserSettings.SETTING_MAX_ITEM_COUNT_PER_FEED,
  UserSettings.SETTING_OPENAI_KEY,
  UserSettings.SETTING_OPENAI_MODEL_ID,
  UserSettings.SETTING_OPENAI_URL,
  UserSettings.SETTING_OPENAI_AZURE_VERSION,
  UserSettings.SETTING_OPENAI_AZURE_DEPLOYMENT_ID,
  UserSettings.SETTING_OPENAI_REQUEST_TIMEOUT_SECONDS,
  UserSettings.SETTING_BLOCKLIST_APPLY_TO_SUMMARIES,
  UserSettings.SETTING_BLOCKLIST_APPLY_TO_LINKS,
  UserSettings.SETTING_PREFERRED_TRANSLATION_LANGUAGE,
  UserSettings.SETTING_TRANSLATION_API_KEY,
  UserSettings.SETTING_TRANSLATION_API_MODEL_ID,
  UserSettings.SETTING_TRANSLATION_API_URL,
  UserSettings.SETTING_TRANSLATION_API_AZURE_VERSION,
  UserSettings.SETTING_TRANSLATION_API_AZURE_DEPLOYMENT_ID,
  UserSettings.SETTING_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS,
  UserSettings.SETTING_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT,
  UserSettings.SETTING_TRANSLATE_ARTICLES_BY_DEFAULT,
  UserSettings.SETTINGS_FORCE_SINGLE_COLUMN
];

/** 源 UserSettings.fromKey：key 忽略大小写匹配；未知返回 null */
export function userSettingFromKey(key: string): UserSettings | null {
  const lower = key.toLowerCase();
  for (const s of ALL_USER_SETTINGS) {
    if (s.toString().toLowerCase() === lower) {
      return s;
    }
  }
  return null;
}

/**
 * 源 SettingsStore.getAllSettings()：存储中**已写过**且在白名单内的键，值 toString()。
 * 返回 Map 按白名单声明顺序（源 sp.all 为无序 Map，顺序不承诺）。
 */
export function getAllSettings(): Map<string, string> {
  const store = SettingsStore.instance();
  const result = new Map<string, string>();
  for (const s of ALL_USER_SETTINGS) {
    const key = s.toString();
    const v = store.getStoredValueAsString(key);
    if (v !== null) {
      result.set(key, v);
    }
  }
  return result;
}

function boolOf(value: string): boolean {
  return KotlinParse.toBoolean(value);
}

/**
 * 源 OPMLImporter.saveSetting(key, value)：key 忽略大小写匹配白名单，未知 key 忽略（返回 false）。
 * 坏值回退：maxLines→(toIntOrNull ?: 1).coerceAtLeast(1)、textScale→1.0、maxCount→100、timeout→30、font 不存在→默认字体；
 * 枚举坏值按各 *FromString 回退（syncFreq→MANUAL）。
 */
export async function setSetting(key: string, value: string): Promise<boolean> {
  const st = SettingsStore.instance();
  const setting = userSettingFromKey(key);
  if (setting === null) {
    console.warn(`UserSettings: Unrecognized setting during import: ${key}`);
    return false;
  }
  switch (setting) {
    case UserSettings.SETTING_ADDED_FEEDER_NEWS:
      await st.setAddedFeederNews(boolOf(value));
      break;
    case UserSettings.SETTING_THEME:
      await st.setCurrentTheme(SettingsCodec.themeFromString(value));
      break;
    case UserSettings.SETTING_DARK_THEME:
      await st.setDarkThemePreference(SettingsCodec.darkThemeFromString(value));
      break;
    case UserSettings.SETTING_DYNAMIC_THEME:
      await st.setUseDynamicTheme(boolOf(value));
      break;
    case UserSettings.SETTING_SORT:
      await st.setCurrentSorting(SettingsCodec.sortingFromString(value));
      break;
    case UserSettings.SETTING_SHOW_FAB:
      await st.setShowFab(boolOf(value));
      break;
    case UserSettings.SETTING_FEED_ITEM_STYLE:
      await st.setFeedItemStyle(SettingsCodec.feedItemStyleFromString(value));
      break;
    case UserSettings.SETTING_SWIPE_AS_READ:
      await st.setSwipeAsRead(SettingsCodec.swipeAsReadFromString(value));
      break;
    case UserSettings.SETTING_SYNC_ONLY_CHARGING:
      await st.setSyncOnlyWhenCharging(boolOf(value));
      break;
    case UserSettings.SETTING_SYNC_ONLY_WIFI:
      await st.setSyncOnlyOnWifi(boolOf(value));
      break;
    case UserSettings.SETTING_SYNC_FREQ:
      await st.setSyncFrequency(SettingsCodec.syncFrequencyFromString(value));
      break;
    case UserSettings.SETTING_SYNC_ON_RESUME:
      await st.setSyncOnResume(boolOf(value));
      break;
    case UserSettings.SETTING_IMG_ONLY_WIFI:
      await st.setLoadImageOnlyOnWifi(boolOf(value));
      break;
    case UserSettings.SETTING_IMG_SHOW_THUMBNAILS:
      await st.setShowThumbnails(boolOf(value));
      break;
    case UserSettings.SETTING_DEFAULT_OPEN_ITEM_WITH:
      await st.setItemOpener(SettingsCodec.itemOpenerFromString(value));
      break;
    case UserSettings.SETTING_OPEN_LINKS_WITH:
      await st.setLinkOpener(SettingsCodec.linkOpenerFromString(value));
      break;
    case UserSettings.SETTING_TEXT_SCALE: {
      const f = KotlinParse.toFloatOrNull(value);
      await st.setTextScale(f === null ? 1.0 : f);
      break;
    }
    case UserSettings.SETTING_IS_MARK_AS_READ_ON_SCROLL:
      await st.setIsMarkAsReadOnScroll(boolOf(value));
      break;
    case UserSettings.SETTING_READALOUD_USE_DETECT_LANGUAGE:
      await st.setUseDetectLanguage(boolOf(value));
      break;
    case UserSettings.SETTING_MAX_LINES: {
      const n = KotlinParse.toIntOrNull(value);
      await st.setMaxLines(Math.max(1, n === null ? 1 : n));
      break;
    }
    case UserSettings.SETTINGS_FILTER_SAVED:
      await st.setFeedListFilterSaved(boolOf(value));
      break;
    case UserSettings.SETTINGS_FILTER_RECENTLY_READ:
      await st.setFeedListFilterRecentlyRead(boolOf(value));
      break;
    case UserSettings.SETTINGS_FILTER_READ:
      await st.setFeedListFilterRead(boolOf(value));
      break;
    case UserSettings.SETTINGS_LIST_SHOW_ONLY_TITLES:
      await st.setShowOnlyTitles(boolOf(value));
      break;
    case UserSettings.SETTING_OPEN_ADJACENT:
      await st.setOpenAdjacent(boolOf(value));
      break;
    case UserSettings.SETTING_USE_IN_APP_AUDIO_PLAYER:
      await st.setUseInAppAudioPlayer(boolOf(value));
      break;
    case UserSettings.SETTING_PAGING_MODE:
      await st.setIsPagingMode(boolOf(value));
      break;
    case UserSettings.SETTING_ANIMATED_PAGING:
      await st.setIsAnimatedPaging(boolOf(value));
      break;
    case UserSettings.SETTING_FONT:
      await st.setFont(st.resolveFontPath(value));
      break;
    case UserSettings.SETTING_LIST_SHOW_READING_TIME:
      await st.setShowReadingTime(boolOf(value));
      break;
    case UserSettings.SETTING_OPEN_DRAWER_ON_FAB:
      await st.setOpenDrawerOnFab(boolOf(value));
      break;
    case UserSettings.SETTING_SHOW_TITLE_UNREAD_COUNT:
      await st.setShowTitleUnreadCount(boolOf(value));
      break;
    case UserSettings.SETTINGS_FORCE_SINGLE_COLUMN:
      await st.setForceSingleColumn(boolOf(value));
      break;
    case UserSettings.SETTING_MAX_ITEM_COUNT_PER_FEED: {
      const n = KotlinParse.toIntOrNull(value);
      await st.setMaxCountPerFeed(n === null ? 100 : n);
      break;
    }
    case UserSettings.SETTING_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT:
      await st.setTranslateArticlePreviewsByDefault(boolOf(value));
      break;
    case UserSettings.SETTING_TRANSLATE_ARTICLES_BY_DEFAULT:
      await st.setTranslateArticlesByDefault(boolOf(value));
      break;
    case UserSettings.SETTING_OPENAI_KEY:
    case UserSettings.SETTING_OPENAI_MODEL_ID:
    case UserSettings.SETTING_OPENAI_URL:
    case UserSettings.SETTING_OPENAI_AZURE_VERSION:
    case UserSettings.SETTING_OPENAI_AZURE_DEPLOYMENT_ID:
    case UserSettings.SETTING_OPENAI_REQUEST_TIMEOUT_SECONDS: {
      const next = st.openAiSettings.copy();
      applyApiField(next, setting, value, true);
      await st.setOpenAiSettings(next);
      break;
    }
    case UserSettings.SETTING_PREFERRED_TRANSLATION_LANGUAGE:
      await st.setPreferredTranslationLanguage(value);
      break;
    case UserSettings.SETTING_TRANSLATION_API_KEY:
    case UserSettings.SETTING_TRANSLATION_API_MODEL_ID:
    case UserSettings.SETTING_TRANSLATION_API_URL:
    case UserSettings.SETTING_TRANSLATION_API_AZURE_VERSION:
    case UserSettings.SETTING_TRANSLATION_API_AZURE_DEPLOYMENT_ID:
    case UserSettings.SETTING_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS: {
      const next = st.translationApiSettings.copy();
      applyApiField(next, setting, value, false);
      await st.setTranslationApiSettings(next);
      break;
    }
    case UserSettings.SETTING_BLOCKLIST_APPLY_TO_SUMMARIES:
      await st.setApplyBlocklistToSummaries(boolOf(value));
      break;
    case UserSettings.SETTING_BLOCKLIST_APPLY_TO_LINKS:
      await st.setApplyBlocklistToLinks(boolOf(value));
      break;
    default:
      return false;
  }
  return true;
}

/** OpenAI / 翻译 API 单字段导入（timeout 坏值→30） */
function applyApiField(target: OpenAISettings, setting: UserSettings, value: string, openAi: boolean): void {
  const keyK = openAi ? UserSettings.SETTING_OPENAI_KEY : UserSettings.SETTING_TRANSLATION_API_KEY;
  const modelK = openAi ? UserSettings.SETTING_OPENAI_MODEL_ID : UserSettings.SETTING_TRANSLATION_API_MODEL_ID;
  const urlK = openAi ? UserSettings.SETTING_OPENAI_URL : UserSettings.SETTING_TRANSLATION_API_URL;
  const verK = openAi ? UserSettings.SETTING_OPENAI_AZURE_VERSION : UserSettings.SETTING_TRANSLATION_API_AZURE_VERSION;
  const depK = openAi ? UserSettings.SETTING_OPENAI_AZURE_DEPLOYMENT_ID :
    UserSettings.SETTING_TRANSLATION_API_AZURE_DEPLOYMENT_ID;
  const toK = openAi ? UserSettings.SETTING_OPENAI_REQUEST_TIMEOUT_SECONDS :
    UserSettings.SETTING_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS;
  if (setting === keyK) {
    target.key = value;
  } else if (setting === modelK) {
    target.modelId = value;
  } else if (setting === urlK) {
    target.baseUrl = value;
  } else if (setting === verK) {
    target.azureApiVersion = value;
  } else if (setting === depK) {
    target.azureDeploymentId = value;
  } else if (setting === toK) {
    const n = KotlinParse.toIntOrNull(value);
    target.timeoutSeconds = n === null ? 30 : n;
  }
}
