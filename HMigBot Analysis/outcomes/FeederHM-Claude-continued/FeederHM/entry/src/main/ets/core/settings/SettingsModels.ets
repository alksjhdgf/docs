/*
 * SettingsModels — SettingsStore 的数据类型与可观察镜像（自 SettingsStore.ets 拆出以满足单文件 ≤600 行）。
 * 源：archmodel/SettingsStore.kt（OpenAISettings、PrefsFeedListFilter、各 StateFlow 默认值）。
 */
import {
  ThemeOptions,
  DarkThemePreferences,
  SortingOptions,
  FeedItemStyle,
  SwipeAsRead,
  ItemOpener,
  LinkOpener,
  SyncFrequency,
  ID_UNSET
} from '../model/Enums';
import { DEFAULT_FONT_PATH } from './SettingsKeys';

/** 鸿蒙无 Material You 动态取色（源：SDK>=31 才生效）→ 生效值恒 false；存储值照常读写/导出 */
export const DYNAMIC_THEME_PLATFORM_SUPPORTED: boolean = false;

/** 源 FeedListFilter 接口（ui/compose/feedarticle） */
export interface FeedListFilter {
  readonly saved: boolean;
  readonly recentlyRead: boolean;
  readonly read: boolean;
  readonly unread: boolean;
}

/** 源 PrefsFeedListFilter：unread 恒 true（SettingsStore.kt:990-996）。不可变，变更时整体替换。 */
export class PrefsFeedListFilter implements FeedListFilter {
  saved: boolean = false;
  recentlyRead: boolean = true;
  read: boolean = true;
  readonly unread: boolean = true;

  static of(saved: boolean, recentlyRead: boolean, read: boolean): PrefsFeedListFilter {
    const f = new PrefsFeedListFilter();
    f.saved = saved;
    f.recentlyRead = recentlyRead;
    f.read = read;
    return f;
  }
}

/** 源 data class OpenAISettings（SettingsStore.kt:909-916）；不可变，copy 后整体替换 */
export class OpenAISettings {
  modelId: string = '';
  baseUrl: string = '';
  timeoutSeconds: number = 30;
  azureApiVersion: string = '';
  azureDeploymentId: string = '';
  key: string = '';

  copy(): OpenAISettings {
    const c = new OpenAISettings();
    c.modelId = this.modelId;
    c.baseUrl = this.baseUrl;
    c.timeoutSeconds = this.timeoutSeconds;
    c.azureApiVersion = this.azureApiVersion;
    c.azureDeploymentId = this.azureDeploymentId;
    c.key = this.key;
    return c;
  }

  equals(o: OpenAISettings): boolean {
    return this.modelId === o.modelId && this.baseUrl === o.baseUrl && this.timeoutSeconds === o.timeoutSeconds &&
      this.azureApiVersion === o.azureApiVersion && this.azureDeploymentId === o.azureDeploymentId && this.key === o.key;
  }
}

/** 源 typealias TranslationApiSettings = OpenAISettings */
export type TranslationApiSettings = OpenAISettings;

/** 设置的可观察内存镜像（UI 直接绑定 SettingsStore.instance().state.xxx） */
@ObservedV2
export class SettingsState {
  @Trace addedFeederNews: boolean = false;
  /** epoch ms；by design 不落盘 */
  @Trace minReadTime: number = Date.now();
  @Trace currentFeedId: number = ID_UNSET;
  @Trace currentFeedTag: string = '';
  @Trace currentWidgetFeedId: number = ID_UNSET;
  @Trace currentWidgetFeedTag: string = '';
  @Trace currentArticleId: number = ID_UNSET;
  @Trace isArticleOpen: boolean = false;
  @Trace isMarkAsReadOnScroll: boolean = false;
  @Trace maxLines: number = 2;
  @Trace showOnlyTitle: boolean = false;
  @Trace feedListFilter: PrefsFeedListFilter = PrefsFeedListFilter.of(false, true, true);
  @Trace currentTheme: ThemeOptions = ThemeOptions.SYSTEM;
  @Trace darkThemePreference: DarkThemePreferences = DarkThemePreferences.BLACK;
  @Trace currentSorting: SortingOptions = SortingOptions.NEWEST_FIRST;
  @Trace showFab: boolean = true;
  @Trace syncOnResume: boolean = false;
  @Trace syncOnlyOnWifi: boolean = false;
  @Trace syncOnlyWhenCharging: boolean = false;
  @Trace loadImageOnlyOnWifi: boolean = false;
  @Trace showThumbnails: boolean = true;
  @Trace useDetectLanguage: boolean = true;
  /** 生效值 = 存储值 && 平台支持动态取色（源：&& SDK>=31） */
  @Trace useDynamicTheme: boolean = DYNAMIC_THEME_PLATFORM_SUPPORTED;
  /** 存储原值（默认 true） */
  @Trace useDynamicThemePreference: boolean = true;
  @Trace textScale: number = 1.0;
  /** 字体路径：bundled/roboto_flex | system/default | fonts 目录下用户字体相对路径 */
  @Trace font: string = DEFAULT_FONT_PATH;
  @Trace maximumCountPerFeed: number = 100;
  @Trace itemOpener: ItemOpener = ItemOpener.READER;
  @Trace linkOpener: LinkOpener = LinkOpener.CUSTOM_TAB;
  @Trace openAdjacent: boolean = true;
  @Trace useInAppAudioPlayer: boolean = true;
  @Trace isPagingMode: boolean = false;
  @Trace isAnimatedPaging: boolean = false;
  @Trace showReadingTime: boolean = false;
  @Trace feedItemStyle: FeedItemStyle = FeedItemStyle.CARD;
  @Trace swipeAsRead: SwipeAsRead = SwipeAsRead.ONLY_FROM_END;
  @Trace applyBlocklistToSummaries: boolean = false;
  @Trace applyBlocklistToLinks: boolean = false;
  @Trace syncFrequency: SyncFrequency = SyncFrequency.EVERY_1_HOURS;
  @Trace openAiSettings: OpenAISettings = new OpenAISettings();
  @Trace translationApiSettings: OpenAISettings = new OpenAISettings();
  @Trace preferredTranslationLanguage: string = '';
  @Trace translateArticlePreviewsByDefault: boolean = false;
  @Trace translateArticlesByDefault: boolean = false;
  @Trace showTitleUnreadCount: boolean = false;
  @Trace openDrawerOnFab: boolean = false;
  @Trace forceSingleColumn: boolean = false;
}
