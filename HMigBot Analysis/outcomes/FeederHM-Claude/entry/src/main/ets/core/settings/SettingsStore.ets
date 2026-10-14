/*
 * SettingsStore — 源 archmodel/SettingsStore.kt 的鸿蒙实现。
 * SharedPreferences(默认文件) → @kit.ArkData preferences 单文件；MutableStateFlow → @ObservedV2/@Trace 镜像（SettingsState）
 * + observe(cb) 订阅。语义：setter 先改内存（立即可见并通知），再 put + await flush() 落盘，最后触发副作用钩子。
 * 启动时只读不写：未写过的 key 不出现在存储中（getAllSettings 只导出写过的键，与源一致）。
 * minReadTime 从不落盘，进程启动=Date.now()。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
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
import * as K from './SettingsKeys';
import { SettingsCodec, KotlinParse } from './SettingsKeys';
import { fireSyncScheduleHook, fireBlocklistChanged } from './SettingsHooks';
import { getFontMetadata } from '../repo/FontStore';
// 数据类型（FeedListFilter/PrefsFeedListFilter/OpenAISettings/TranslationApiSettings/SettingsState）定义在 SettingsModels.ets
import {
  DYNAMIC_THEME_PLATFORM_SUPPORTED,
  PrefsFeedListFilter,
  OpenAISettings,
  TranslationApiSettings,
  SettingsState
} from './SettingsModels';

export type SettingsListener = (key: string) => void;

export class SettingsStore {
  static readonly DYNAMIC_THEME_SUPPORTED: boolean = DYNAMIC_THEME_PLATFORM_SUPPORTED;

  private static inst: SettingsStore | null = null;
  private static initPromise: Promise<void> | null = null;

  readonly state: SettingsState = new SettingsState();
  private prefs: preferences.Preferences | null = null;
  private fontsDir: string = '';
  private listeners: Array<SettingsListener> = [];

  static instance(): SettingsStore {
    if (SettingsStore.inst === null) {
      SettingsStore.inst = new SettingsStore();
    }
    return SettingsStore.inst as SettingsStore;
  }

  /** 打开 preferences 并把全部设置读入内存；幂等。未 init 前 getter 返回源默认值。 */
  static async init(ctx: common.Context): Promise<void> {
    if (SettingsStore.initPromise === null) {
      SettingsStore.initPromise = SettingsStore.instance().load(ctx).catch((e: Error) => {
        SettingsStore.initPromise = null;
        console.error(`SettingsStore: init failed: ${e?.message}`);
        throw e;
      });
    }
    return SettingsStore.initPromise as Promise<void>;
  }

  isInitialized(): boolean {
    return this.prefs !== null;
  }

  /** 订阅任一设置变化（参数为 PREF key；minReadTime 为 SETTING_KEY_MIN_READ_TIME）；返回反订阅函数 */
  observe(cb: SettingsListener): () => void {
    this.listeners.push(cb);
    return () => {
      const i = this.listeners.indexOf(cb);
      if (i >= 0) {
        this.listeners.splice(i, 1);
      }
    };
  }

  private async load(ctx: common.Context): Promise<void> {
    const opts: preferences.Options = { name: K.SETTINGS_PREFERENCES_NAME };
    this.prefs = await preferences.getPreferences(ctx, opts);
    this.fontsDir = `${ctx.filesDir}/${K.FONTS_DIR_NAME}`;
    const s = this.state;
    s.addedFeederNews = this.readBool(K.PREF_ADDED_FEEDER_NEWS, false);
    s.currentFeedId = this.readNum(K.PREF_LAST_FEED_ID, ID_UNSET);
    s.currentFeedTag = this.readStr(K.PREF_LAST_FEED_TAG, '');
    s.currentWidgetFeedId = this.readNum(K.PREF_LAST_WIDGET_FEED_ID, ID_UNSET);
    s.currentWidgetFeedTag = this.readStr(K.PREF_LAST_WIDGET_FEED_TAG, '');
    s.currentArticleId = this.readNum(K.PREF_LAST_ARTICLE_ID, ID_UNSET);
    s.isArticleOpen = this.readBool(K.PREF_IS_ARTICLE_OPEN, false);
    s.isMarkAsReadOnScroll = this.readBool(K.PREF_IS_MARK_AS_READ_ON_SCROLL, false);
    s.maxLines = this.readNum(K.PREF_MAX_LINES, 2);
    s.showOnlyTitle = this.readBool(K.PREF_LIST_SHOW_ONLY_TITLES, false);
    s.feedListFilter = PrefsFeedListFilter.of(
      this.readBool(K.PREFS_FILTER_SAVED, false),
      this.readBool(K.PREFS_FILTER_RECENTLY_READ, true),
      this.readBool(K.PREFS_FILTER_READ, true));
    s.currentTheme = SettingsCodec.themeFromString(this.readStr(K.PREF_THEME, 'SYSTEM'));
    s.darkThemePreference = SettingsCodec.darkThemeFromString(this.readStr(K.PREF_DARK_THEME, 'BLACK'));
    s.currentSorting = SettingsCodec.sortingFromString(this.readStr(K.PREF_SORT, 'NEWEST_FIRST'));
    s.showFab = this.readBool(K.PREF_SHOW_FAB, true);
    s.syncOnResume = this.readBool(K.PREF_SYNC_ON_RESUME, false);
    s.syncOnlyOnWifi = this.readBool(K.PREF_SYNC_ONLY_WIFI, false);
    s.syncOnlyWhenCharging = this.readBool(K.PREF_SYNC_ONLY_CHARGING, false);
    s.loadImageOnlyOnWifi = this.readBool(K.PREF_IMG_ONLY_WIFI, false);
    s.showThumbnails = this.readBool(K.PREF_IMG_SHOW_THUMBNAILS, true);
    s.useDetectLanguage = this.readBool(K.PREF_READALOUD_USE_DETECT_LANGUAGE, true);
    s.useDynamicThemePreference = this.readBool(K.PREF_DYNAMIC_THEME, true);
    s.useDynamicTheme = SettingsStore.DYNAMIC_THEME_SUPPORTED && s.useDynamicThemePreference;
    s.textScale = this.readNum(K.PREF_TEXT_SCALE, 1.0);
    s.font = this.resolveFontPath(this.readStr(K.PREF_FONT, K.DEFAULT_FONT_PATH));
    const maxCount = KotlinParse.toIntOrNull(this.readStr(K.PREF_MAX_ITEM_COUNT_PER_FEED, '100'));
    s.maximumCountPerFeed = maxCount === null ? 100 : maxCount;
    s.itemOpener = SettingsCodec.itemOpenerFromString(
      this.readStr(K.PREF_DEFAULT_OPEN_ITEM_WITH, K.PREF_VAL_OPEN_WITH_READER));
    s.linkOpener = SettingsCodec.linkOpenerFromString(
      this.readStr(K.PREF_OPEN_LINKS_WITH, K.PREF_VAL_OPEN_WITH_CUSTOM_TAB));
    s.openAdjacent = this.readBool(K.PREF_OPEN_ADJACENT, true);
    s.useInAppAudioPlayer = this.readBool(K.PREF_USE_IN_APP_AUDIO_PLAYER, true);
    s.isPagingMode = this.readBool(K.PREF_PAGING_MODE, false);
    s.isAnimatedPaging = this.readBool(K.PREF_ANIMATED_PAGING, false);
    s.showReadingTime = this.readBool(K.PREF_LIST_SHOW_READING_TIME, false);
    s.feedItemStyle = SettingsCodec.feedItemStyleFromString(this.readStr(K.PREF_FEED_ITEM_STYLE, 'CARD'));
    s.swipeAsRead = SettingsCodec.swipeAsReadFromString(this.readStr(K.PREF_SWIPE_AS_READ, 'ONLY_FROM_END'));
    s.applyBlocklistToSummaries = this.readBool(K.PREF_BLOCKLIST_APPLY_TO_SUMMARIES, false);
    s.applyBlocklistToLinks = this.readBool(K.PREF_BLOCKLIST_APPLY_TO_LINKS, false);
    s.syncFrequency = SettingsCodec.syncFrequencyFromString(this.readStr(K.PREF_SYNC_FREQ, '60'));
    s.openAiSettings = this.readApiSettings(K.PREF_OPENAI_KEY, K.PREF_OPENAI_MODEL_ID, K.PREF_OPENAI_URL,
      K.PREF_OPENAI_AZURE_VERSION, K.PREF_OPENAI_AZURE_DEPLOYMENT_ID, K.PREF_OPENAI_REQUEST_TIMEOUT_SECONDS);
    s.translationApiSettings = this.readApiSettings(K.PREF_TRANSLATION_API_KEY, K.PREF_TRANSLATION_API_MODEL_ID,
      K.PREF_TRANSLATION_API_URL, K.PREF_TRANSLATION_API_AZURE_VERSION, K.PREF_TRANSLATION_API_AZURE_DEPLOYMENT_ID,
      K.PREF_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS);
    s.preferredTranslationLanguage = this.readStr(K.PREF_PREFERRED_TRANSLATION_LANGUAGE, '');
    s.translateArticlePreviewsByDefault = this.readBool(K.PREF_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT, false);
    s.translateArticlesByDefault = this.readBool(K.PREF_TRANSLATE_ARTICLES_BY_DEFAULT, false);
    s.showTitleUnreadCount = this.readBool(K.PREF_SHOW_TITLE_UNREAD_COUNT, false);
    s.openDrawerOnFab = this.readBool(K.PREF_OPEN_DRAWER_ON_FAB, false);
    s.forceSingleColumn = this.readBool(K.PREF_FORCE_SINGLE_COLUMN, false);
  }

  // ---------------------------------------------------------------- getters（内存缓存）
  get addedFeederNews(): boolean { return this.state.addedFeederNews; }
  get minReadTime(): number { return this.state.minReadTime; }
  get currentFeedId(): number { return this.state.currentFeedId; }
  get currentFeedTag(): string { return this.state.currentFeedTag; }
  get currentWidgetFeedId(): number { return this.state.currentWidgetFeedId; }
  get currentWidgetFeedTag(): string { return this.state.currentWidgetFeedTag; }
  get currentArticleId(): number { return this.state.currentArticleId; }
  get isArticleOpen(): boolean { return this.state.isArticleOpen; }
  get isMarkAsReadOnScroll(): boolean { return this.state.isMarkAsReadOnScroll; }
  get maxLines(): number { return this.state.maxLines; }
  get showOnlyTitle(): boolean { return this.state.showOnlyTitle; }
  get feedListFilter(): PrefsFeedListFilter { return this.state.feedListFilter; }
  get currentTheme(): ThemeOptions { return this.state.currentTheme; }
  get darkThemePreference(): DarkThemePreferences { return this.state.darkThemePreference; }
  get currentSorting(): SortingOptions { return this.state.currentSorting; }
  get showFab(): boolean { return this.state.showFab; }
  get syncOnResume(): boolean { return this.state.syncOnResume; }
  get syncOnlyOnWifi(): boolean { return this.state.syncOnlyOnWifi; }
  get syncOnlyWhenCharging(): boolean { return this.state.syncOnlyWhenCharging; }
  get loadImageOnlyOnWifi(): boolean { return this.state.loadImageOnlyOnWifi; }
  get showThumbnails(): boolean { return this.state.showThumbnails; }
  get useDetectLanguage(): boolean { return this.state.useDetectLanguage; }
  get useDynamicTheme(): boolean { return this.state.useDynamicTheme; }
  get textScale(): number { return this.state.textScale; }
  get font(): string { return this.state.font; }
  get maximumCountPerFeed(): number { return this.state.maximumCountPerFeed; }
  get itemOpener(): ItemOpener { return this.state.itemOpener; }
  get linkOpener(): LinkOpener { return this.state.linkOpener; }
  get openAdjacent(): boolean { return this.state.openAdjacent; }
  get useInAppAudioPlayer(): boolean { return this.state.useInAppAudioPlayer; }
  get isPagingMode(): boolean { return this.state.isPagingMode; }
  get isAnimatedPaging(): boolean { return this.state.isAnimatedPaging; }
  get showReadingTime(): boolean { return this.state.showReadingTime; }
  get feedItemStyle(): FeedItemStyle { return this.state.feedItemStyle; }
  get swipeAsRead(): SwipeAsRead { return this.state.swipeAsRead; }
  get applyBlocklistToSummaries(): boolean { return this.state.applyBlocklistToSummaries; }
  get applyBlocklistToLinks(): boolean { return this.state.applyBlocklistToLinks; }
  get syncFrequency(): SyncFrequency { return this.state.syncFrequency; }
  get openAiSettings(): OpenAISettings { return this.state.openAiSettings; }
  get translationApiSettings(): OpenAISettings { return this.state.translationApiSettings; }
  get preferredTranslationLanguage(): string { return this.state.preferredTranslationLanguage; }
  get translateArticlePreviewsByDefault(): boolean { return this.state.translateArticlePreviewsByDefault; }
  get translateArticlesByDefault(): boolean { return this.state.translateArticlesByDefault; }
  get showTitleUnreadCount(): boolean { return this.state.showTitleUnreadCount; }
  get openDrawerOnFab(): boolean { return this.state.openDrawerOnFab; }
  get forceSingleColumn(): boolean { return this.state.forceSingleColumn; }

  // ---------------------------------------------------------------- setters（先改内存→通知→落盘 flush→钩子）
  async setAddedFeederNews(v: boolean): Promise<void> {
    this.state.addedFeederNews = v;
    await this.commit(K.PREF_ADDED_FEEDER_NEWS, v);
  }

  /** 不落盘（源 by design） */
  setMinReadTime(epochMs: number): void {
    this.state.minReadTime = epochMs;
    this.notify(K.SETTING_KEY_MIN_READ_TIME);
  }

  /** 仅当值变化才写，返回是否变化（源 SettingsStore.kt:67-80） */
  async setCurrentFeedAndTag(feedId: number, tag: string): Promise<boolean> {
    if (this.state.currentFeedId === feedId && this.state.currentFeedTag === tag) {
      return false;
    }
    this.state.currentFeedId = feedId;
    this.state.currentFeedTag = tag;
    this.notify(K.PREF_LAST_FEED_ID);
    await this.persistMany([K.PREF_LAST_FEED_ID, K.PREF_LAST_FEED_TAG], [feedId, tag]);
    return true;
  }

  async setCurrentWidgetFeedAndTag(feedId: number, tag: string): Promise<boolean> {
    if (this.state.currentWidgetFeedId === feedId && this.state.currentWidgetFeedTag === tag) {
      return false;
    }
    this.state.currentWidgetFeedId = feedId;
    this.state.currentWidgetFeedTag = tag;
    this.notify(K.PREF_LAST_WIDGET_FEED_ID);
    await this.persistMany([K.PREF_LAST_WIDGET_FEED_ID, K.PREF_LAST_WIDGET_FEED_TAG], [feedId, tag]);
    return true;
  }

  async setCurrentArticle(articleId: number): Promise<void> {
    this.state.currentArticleId = articleId;
    await this.commit(K.PREF_LAST_ARTICLE_ID, articleId);
  }

  async setIsArticleOpen(open: boolean): Promise<void> {
    this.state.isArticleOpen = open;
    await this.commit(K.PREF_IS_ARTICLE_OPEN, open);
  }

  async setIsMarkAsReadOnScroll(v: boolean): Promise<void> {
    this.state.isMarkAsReadOnScroll = v;
    await this.commit(K.PREF_IS_MARK_AS_READ_ON_SCROLL, v);
  }

  /** 源 Store 层：≤0 忽略（Store 不变）。Repository 层须先 Math.max(1, v)（RP-A36）。 */
  async setMaxLines(v: number): Promise<void> {
    if (v > 0) {
      this.state.maxLines = Math.trunc(v);
      await this.commit(K.PREF_MAX_LINES, Math.trunc(v));
    }
  }

  async setShowOnlyTitles(v: boolean): Promise<void> {
    this.state.showOnlyTitle = v;
    await this.commit(K.PREF_LIST_SHOW_ONLY_TITLES, v);
  }

  async setFeedListFilterSaved(v: boolean): Promise<void> {
    const f = this.state.feedListFilter;
    this.state.feedListFilter = PrefsFeedListFilter.of(v, f.recentlyRead, f.read);
    await this.commit(K.PREFS_FILTER_SAVED, v);
  }

  /** Store 层不含联动；联动（关 recentlyRead→关 read）见 setFeedListFilterRecentlyReadLinked */
  async setFeedListFilterRecentlyRead(v: boolean): Promise<void> {
    const f = this.state.feedListFilter;
    this.state.feedListFilter = PrefsFeedListFilter.of(f.saved, v, f.read);
    await this.commit(K.PREFS_FILTER_RECENTLY_READ, v);
  }

  async setFeedListFilterRead(v: boolean): Promise<void> {
    const f = this.state.feedListFilter;
    this.state.feedListFilter = PrefsFeedListFilter.of(f.saved, f.recentlyRead, v);
    await this.commit(K.PREFS_FILTER_READ, v);
  }

  /** 源 Repository.setFeedListFilterRecentlyRead（Repository.kt:185-191）：关闭时同时关闭 read */
  async setFeedListFilterRecentlyReadLinked(v: boolean): Promise<void> {
    await this.setFeedListFilterRecentlyRead(v);
    if (!v) {
      await this.setFeedListFilterRead(false);
    }
  }

  /** 源 Repository.setFeedListFilterRead（Repository.kt:193-199）：开启时同时开启 recentlyRead */
  async setFeedListFilterReadLinked(v: boolean): Promise<void> {
    await this.setFeedListFilterRead(v);
    if (v) {
      await this.setFeedListFilterRecentlyRead(true);
    }
  }

  async setCurrentTheme(v: ThemeOptions): Promise<void> {
    this.state.currentTheme = v;
    await this.commit(K.PREF_THEME, SettingsCodec.themeToPref(v));
  }

  async setDarkThemePreference(v: DarkThemePreferences): Promise<void> {
    this.state.darkThemePreference = v;
    await this.commit(K.PREF_DARK_THEME, SettingsCodec.darkThemeToPref(v));
  }

  async setCurrentSorting(v: SortingOptions): Promise<void> {
    this.state.currentSorting = v;
    await this.commit(K.PREF_SORT, SettingsCodec.sortingToPref(v));
  }

  async setShowFab(v: boolean): Promise<void> {
    this.state.showFab = v;
    await this.commit(K.PREF_SHOW_FAB, v);
  }

  async setSyncOnResume(v: boolean): Promise<void> {
    this.state.syncOnResume = v;
    await this.commit(K.PREF_SYNC_ON_RESUME, v);
  }

  async setSyncOnlyOnWifi(v: boolean): Promise<void> {
    this.state.syncOnlyOnWifi = v;
    await this.commit(K.PREF_SYNC_ONLY_WIFI, v);
    fireSyncScheduleHook(true);
  }

  async setSyncOnlyWhenCharging(v: boolean): Promise<void> {
    this.state.syncOnlyWhenCharging = v;
    await this.commit(K.PREF_SYNC_ONLY_CHARGING, v);
    fireSyncScheduleHook(true);
  }

  async setLoadImageOnlyOnWifi(v: boolean): Promise<void> {
    this.state.loadImageOnlyOnWifi = v;
    await this.commit(K.PREF_IMG_ONLY_WIFI, v);
  }

  async setShowThumbnails(v: boolean): Promise<void> {
    this.state.showThumbnails = v;
    await this.commit(K.PREF_IMG_SHOW_THUMBNAILS, v);
  }

  async setUseDetectLanguage(v: boolean): Promise<void> {
    this.state.useDetectLanguage = v;
    await this.commit(K.PREF_READALOUD_USE_DETECT_LANGUAGE, v);
  }

  /** 落盘原值；生效值 = v && 平台支持 */
  async setUseDynamicTheme(v: boolean): Promise<void> {
    this.state.useDynamicThemePreference = v;
    this.state.useDynamicTheme = v && SettingsStore.DYNAMIC_THEME_SUPPORTED;
    await this.commit(K.PREF_DYNAMIC_THEME, v);
  }

  async setTextScale(v: number): Promise<void> {
    this.state.textScale = v;
    await this.commit(K.PREF_TEXT_SCALE, v);
  }

  /** 存字体路径（源 FontSelection.serialize() = path） */
  async setFont(path: string): Promise<void> {
    this.state.font = path;
    await this.commit(K.PREF_FONT, path);
  }

  /** 以十进制字符串存储（源 "$value"） */
  async setMaxCountPerFeed(v: number): Promise<void> {
    const n = Math.trunc(v);
    this.state.maximumCountPerFeed = n;
    await this.commit(K.PREF_MAX_ITEM_COUNT_PER_FEED, `${n}`);
  }

  async setItemOpener(v: ItemOpener): Promise<void> {
    this.state.itemOpener = v;
    await this.commit(K.PREF_DEFAULT_OPEN_ITEM_WITH, SettingsCodec.itemOpenerToPref(v));
  }

  async setLinkOpener(v: LinkOpener): Promise<void> {
    this.state.linkOpener = v;
    await this.commit(K.PREF_OPEN_LINKS_WITH, SettingsCodec.linkOpenerToPref(v));
  }

  async setOpenAdjacent(v: boolean): Promise<void> {
    this.state.openAdjacent = v;
    await this.commit(K.PREF_OPEN_ADJACENT, v);
  }

  async setUseInAppAudioPlayer(v: boolean): Promise<void> {
    this.state.useInAppAudioPlayer = v;
    await this.commit(K.PREF_USE_IN_APP_AUDIO_PLAYER, v);
  }

  async setIsPagingMode(v: boolean): Promise<void> {
    this.state.isPagingMode = v;
    await this.commit(K.PREF_PAGING_MODE, v);
  }

  async setIsAnimatedPaging(v: boolean): Promise<void> {
    this.state.isAnimatedPaging = v;
    await this.commit(K.PREF_ANIMATED_PAGING, v);
  }

  async setShowReadingTime(v: boolean): Promise<void> {
    this.state.showReadingTime = v;
    await this.commit(K.PREF_LIST_SHOW_READING_TIME, v);
  }

  async setFeedItemStyle(v: FeedItemStyle): Promise<void> {
    this.state.feedItemStyle = v;
    await this.commit(K.PREF_FEED_ITEM_STYLE, SettingsCodec.feedItemStyleToPref(v));
  }

  async setSwipeAsRead(v: SwipeAsRead): Promise<void> {
    this.state.swipeAsRead = v;
    await this.commit(K.PREF_SWIPE_AS_READ, SettingsCodec.swipeAsReadToPref(v));
  }

  async setApplyBlocklistToSummaries(v: boolean): Promise<void> {
    this.state.applyBlocklistToSummaries = v;
    await this.commit(K.PREF_BLOCKLIST_APPLY_TO_SUMMARIES, v);
    fireBlocklistChanged();
  }

  async setApplyBlocklistToLinks(v: boolean): Promise<void> {
    this.state.applyBlocklistToLinks = v;
    await this.commit(K.PREF_BLOCKLIST_APPLY_TO_LINKS, v);
    fireBlocklistChanged();
  }

  async setSyncFrequency(v: SyncFrequency): Promise<void> {
    this.state.syncFrequency = v;
    await this.commit(K.PREF_SYNC_FREQ, SettingsCodec.syncFrequencyToPref(v));
    fireSyncScheduleHook(true);
  }

  async setOpenAiSettings(v: OpenAISettings): Promise<void> {
    this.state.openAiSettings = v.copy();
    this.notify(K.PREF_OPENAI_KEY);
    await this.persistMany([K.PREF_OPENAI_KEY, K.PREF_OPENAI_MODEL_ID, K.PREF_OPENAI_URL, K.PREF_OPENAI_AZURE_VERSION,
      K.PREF_OPENAI_AZURE_DEPLOYMENT_ID, K.PREF_OPENAI_REQUEST_TIMEOUT_SECONDS],
      [v.key, v.modelId, v.baseUrl, v.azureApiVersion, v.azureDeploymentId, Math.trunc(v.timeoutSeconds)]);
  }

  async setTranslationApiSettings(v: TranslationApiSettings): Promise<void> {
    this.state.translationApiSettings = v.copy();
    this.notify(K.PREF_TRANSLATION_API_KEY);
    await this.persistMany([K.PREF_TRANSLATION_API_KEY, K.PREF_TRANSLATION_API_MODEL_ID, K.PREF_TRANSLATION_API_URL,
      K.PREF_TRANSLATION_API_AZURE_VERSION, K.PREF_TRANSLATION_API_AZURE_DEPLOYMENT_ID,
      K.PREF_TRANSLATION_API_REQUEST_TIMEOUT_SECONDS],
      [v.key, v.modelId, v.baseUrl, v.azureApiVersion, v.azureDeploymentId, Math.trunc(v.timeoutSeconds)]);
  }

  async setPreferredTranslationLanguage(v: string): Promise<void> {
    this.state.preferredTranslationLanguage = v;
    await this.commit(K.PREF_PREFERRED_TRANSLATION_LANGUAGE, v);
  }

  async setTranslateArticlePreviewsByDefault(v: boolean): Promise<void> {
    this.state.translateArticlePreviewsByDefault = v;
    await this.commit(K.PREF_TRANSLATE_ARTICLE_PREVIEWS_BY_DEFAULT, v);
  }

  async setTranslateArticlesByDefault(v: boolean): Promise<void> {
    this.state.translateArticlesByDefault = v;
    await this.commit(K.PREF_TRANSLATE_ARTICLES_BY_DEFAULT, v);
  }

  async setShowTitleUnreadCount(v: boolean): Promise<void> {
    this.state.showTitleUnreadCount = v;
    await this.commit(K.PREF_SHOW_TITLE_UNREAD_COUNT, v);
  }

  async setOpenDrawerOnFab(v: boolean): Promise<void> {
    this.state.openDrawerOnFab = v;
    await this.commit(K.PREF_OPEN_DRAWER_ON_FAB, v);
  }

  async setForceSingleColumn(v: boolean): Promise<void> {
    this.state.forceSingleColumn = v;
    await this.commit(K.PREF_FORCE_SINGLE_COLUMN, v);
  }

  // ---------------------------------------------------------------- 导出/字体辅助（供 UserSettings 使用）

  /**
   * 已写入存储的 key 的值字符串化（等价源 sp.all[key].toString()）；未写过返回 null。
   * Float 键（pref_body_text_scale）按 Kotlin Float.toString（如 "1.0"）；其它数字按整数。
   */
  getStoredValueAsString(key: string): string | null {
    const p = this.prefs;
    if (p === null) {
      return null;
    }
    try {
      if (!p.hasSync(key)) {
        return null;
      }
      const v: preferences.ValueType = p.getSync(key, '');
      if (typeof v === 'boolean') {
        return (v as boolean) ? 'true' : 'false';
      }
      if (typeof v === 'number') {
        const n = v as number;
        return key === K.PREF_TEXT_SCALE ? KotlinParse.floatToString(n) : `${Math.trunc(n)}`;
      }
      if (typeof v === 'string') {
        return v as string;
      }
      return String(v);
    } catch (e) {
      console.error(`SettingsStore: read ${key} failed: ${(e as Error)?.message}`);
      return null;
    }
  }

  /**
   * 源 getFontSelectionFromPath(...) ?: defaultFont 的路径部分（TextSettingsViewModel.kt:212-230；
   * 调用方 SettingsStore.kt:323、OPMLImporter.kt:100-106）：内置路径原样；用户字体文件不存在或
   * parseTrueTypeFont 失败 → 默认 RobotoFlex（TS-A30）。
   */
  resolveFontPath(path: string): string {
    if (path === K.FONT_PATH_ROBOTO_FLEX || path === K.FONT_PATH_SYSTEM_DEFAULT) {
      return path;
    }
    if (this.fontsDir === '' || path === '') {
      return K.DEFAULT_FONT_PATH;
    }
    try {
      const full: string = `${this.fontsDir}/${path}`;
      if (!fs.accessSync(full)) {
        return K.DEFAULT_FONT_PATH;
      }
      return getFontMetadata(full) !== null ? path : K.DEFAULT_FONT_PATH;
    } catch (e) {
      return K.DEFAULT_FONT_PATH;
    }
  }

  // ---------------------------------------------------------------- 内部
  private notify(key: string): void {
    const snapshot = this.listeners.slice();
    for (const cb of snapshot) {
      try {
        cb(key);
      } catch (e) {
        console.error(`SettingsStore: listener failed: ${(e as Error)?.message}`);
      }
    }
  }

  private async commit(key: string, value: preferences.ValueType): Promise<void> {
    this.notify(key);
    await this.persistMany([key], [value]);
  }

  private async persistMany(keys: string[], values: preferences.ValueType[]): Promise<void> {
    const p = this.prefs;
    if (p === null) {
      console.warn(`SettingsStore: write before init, not persisted: ${keys.join(',')}`);
      return;
    }
    try {
      for (let i = 0; i < keys.length; i++) {
        p.putSync(keys[i], values[i]);
      }
      await p.flush();
    } catch (e) {
      console.error(`SettingsStore: persist ${keys.join(',')} failed: ${(e as Error)?.message}`);
    }
  }

  private readBool(key: string, def: boolean): boolean {
    const v = this.readRaw(key, def);
    return typeof v === 'boolean' ? (v as boolean) : def;
  }

  private readNum(key: string, def: number): number {
    const v = this.readRaw(key, def);
    return typeof v === 'number' && !Number.isNaN(v as number) ? (v as number) : def;
  }

  private readStr(key: string, def: string): string {
    const v = this.readRaw(key, def);
    return typeof v === 'string' ? (v as string) : def;
  }

  private readRaw(key: string, def: preferences.ValueType): preferences.ValueType {
    const p = this.prefs;
    if (p === null) {
      return def;
    }
    try {
      return p.getSync(key, def);
    } catch (e) {
      console.error(`SettingsStore: read ${key} failed: ${(e as Error)?.message}`);
      return def;
    }
  }

  private readApiSettings(keyK: string, modelK: string, urlK: string, azVerK: string, azDepK: string,
    timeoutK: string): OpenAISettings {
    const o = new OpenAISettings();
    o.key = this.readStr(keyK, '');
    o.modelId = this.readStr(modelK, '');
    o.baseUrl = this.readStr(urlK, '');
    o.azureApiVersion = this.readStr(azVerK, '');
    o.azureDeploymentId = this.readStr(azDepK, '');
    o.timeoutSeconds = this.readNum(timeoutK, 30);
    return o;
  }
}
