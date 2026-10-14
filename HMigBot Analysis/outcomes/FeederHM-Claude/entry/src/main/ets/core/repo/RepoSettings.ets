/**
 * RepoSettings — 源 Repository.kt 对 SettingsStore 的一对一透传（自 Repository.ets 拆出以满足 ≤600 行）。
 * StateFlow → 同步快照 getter（SettingsStore 内存缓存）；UI 绑定请直接读 SettingsStore.instance().state.xxx（@Trace），
 * 或用 observeSetting(key, cb)。带逻辑的透传（setMaxLines 下限、过滤联动、屏蔽词重算）也在此。
 */
import {
  DarkThemePreferences, FeedItemStyle, ItemOpener, LinkOpener, SortingOptions, SwipeAsRead, SyncFrequency, ThemeOptions
} from '../model/Enums';
import { SettingsStore } from '../settings/SettingsStore';
import { FeedListFilter, OpenAISettings, TranslationApiSettings } from '../settings/SettingsModels';

export class RepoSettings {
  protected readonly settings: SettingsStore = SettingsStore.instance();

  /** 订阅某个设置 key 的变化（参数为 SettingsKeys 中的 PREF_* 常量）；返回反订阅函数 */
  observeSetting(key: string, cb: () => void): () => void {
    return this.settings.observe((k: string) => {
      if (k === key) {
        cb();
      }
    });
  }

  get isArticleOpen(): boolean { return this.settings.isArticleOpen; }
  async setIsArticleOpen(open: boolean): Promise<void> { await this.settings.setIsArticleOpen(open); }

  get isMarkAsReadOnScroll(): boolean { return this.settings.isMarkAsReadOnScroll; }
  async setIsMarkAsReadOnScroll(v: boolean): Promise<void> { await this.settings.setIsMarkAsReadOnScroll(v); }

  get maxLines(): number { return this.settings.maxLines; }

  /** 源 setMaxLines(value.coerceAtLeast(1))（RP-A36） */
  async setMaxLines(v: number): Promise<void> {
    await this.settings.setMaxLines(Math.max(1, Math.trunc(v)));
  }

  get showOnlyTitle(): boolean { return this.settings.showOnlyTitle; }
  async setShowOnlyTitles(v: boolean): Promise<void> { await this.settings.setShowOnlyTitles(v); }

  get feedListFilter(): FeedListFilter { return this.settings.feedListFilter; }
  async setFeedListFilterSaved(v: boolean): Promise<void> { await this.settings.setFeedListFilterSaved(v); }

  /** RP-A17：关闭“最近已读”时同时关闭“已读” */
  async setFeedListFilterRecentlyRead(v: boolean): Promise<void> {
    await this.settings.setFeedListFilterRecentlyRead(v);
    if (!v) {
      await this.settings.setFeedListFilterRead(false);
    }
  }

  /** RP-A17：开启“已读”时同时开启“最近已读” */
  async setFeedListFilterRead(v: boolean): Promise<void> {
    await this.settings.setFeedListFilterRead(v);
    if (v) {
      await this.settings.setFeedListFilterRecentlyRead(true);
    }
  }

  get currentTheme(): ThemeOptions { return this.settings.currentTheme; }
  async setCurrentTheme(v: ThemeOptions): Promise<void> { await this.settings.setCurrentTheme(v); }

  get preferredDarkTheme(): DarkThemePreferences { return this.settings.darkThemePreference; }
  async setPreferredDarkTheme(v: DarkThemePreferences): Promise<void> { await this.settings.setDarkThemePreference(v); }

  get applyBlocklistToSummaries(): boolean { return this.settings.applyBlocklistToSummaries; }
  get applyBlocklistToLinks(): boolean { return this.settings.applyBlocklistToLinks; }

  get currentSorting(): SortingOptions { return this.settings.currentSorting; }
  async setCurrentSorting(v: SortingOptions): Promise<void> { await this.settings.setCurrentSorting(v); }

  get showFab(): boolean { return this.settings.showFab; }
  async setShowFab(v: boolean): Promise<void> { await this.settings.setShowFab(v); }

  get feedItemStyle(): FeedItemStyle { return this.settings.feedItemStyle; }
  async setFeedItemStyle(v: FeedItemStyle): Promise<void> { await this.settings.setFeedItemStyle(v); }

  get swipeAsRead(): SwipeAsRead { return this.settings.swipeAsRead; }
  async setSwipeAsRead(v: SwipeAsRead): Promise<void> { await this.settings.setSwipeAsRead(v); }

  get syncOnResume(): boolean { return this.settings.syncOnResume; }
  async setSyncOnResume(v: boolean): Promise<void> { await this.settings.setSyncOnResume(v); }

  get syncOnlyOnWifi(): boolean { return this.settings.syncOnlyOnWifi; }
  async setSyncOnlyOnWifi(v: boolean): Promise<void> { await this.settings.setSyncOnlyOnWifi(v); }

  get syncOnlyWhenCharging(): boolean { return this.settings.syncOnlyWhenCharging; }
  async setSyncOnlyWhenCharging(v: boolean): Promise<void> { await this.settings.setSyncOnlyWhenCharging(v); }

  get loadImageOnlyOnWifi(): boolean { return this.settings.loadImageOnlyOnWifi; }
  async setLoadImageOnlyOnWifi(v: boolean): Promise<void> { await this.settings.setLoadImageOnlyOnWifi(v); }

  get showThumbnails(): boolean { return this.settings.showThumbnails; }
  async setShowThumbnails(v: boolean): Promise<void> { await this.settings.setShowThumbnails(v); }

  get useDetectLanguage(): boolean { return this.settings.useDetectLanguage; }
  async setUseDetectLanguage(v: boolean): Promise<void> { await this.settings.setUseDetectLanguage(v); }

  get useDynamicTheme(): boolean { return this.settings.useDynamicTheme; }
  async setUseDynamicTheme(v: boolean): Promise<void> { await this.settings.setUseDynamicTheme(v); }

  get textScale(): number { return this.settings.textScale; }
  async setTextScale(v: number): Promise<void> { await this.settings.setTextScale(v); }

  get maximumCountPerFeed(): number { return this.settings.maximumCountPerFeed; }
  async setMaxCountPerFeed(v: number): Promise<void> { await this.settings.setMaxCountPerFeed(v); }

  get itemOpener(): ItemOpener { return this.settings.itemOpener; }
  async setItemOpener(v: ItemOpener): Promise<void> { await this.settings.setItemOpener(v); }

  get linkOpener(): LinkOpener { return this.settings.linkOpener; }
  async setLinkOpener(v: LinkOpener): Promise<void> { await this.settings.setLinkOpener(v); }

  get useInAppAudioPlayer(): boolean { return this.settings.useInAppAudioPlayer; }
  async setUseInAppAudioPlayer(v: boolean): Promise<void> { await this.settings.setUseInAppAudioPlayer(v); }

  get syncFrequency(): SyncFrequency { return this.settings.syncFrequency; }
  async setSyncFrequency(v: SyncFrequency): Promise<void> { await this.settings.setSyncFrequency(v); }

  get openAISettings(): OpenAISettings { return this.settings.openAiSettings; }
  async setOpenAiSettings(v: OpenAISettings): Promise<void> { await this.settings.setOpenAiSettings(v); }

  get translationApiSettings(): TranslationApiSettings { return this.settings.translationApiSettings; }
  async setTranslationApiSettings(v: TranslationApiSettings): Promise<void> {
    await this.settings.setTranslationApiSettings(v);
  }

  get preferredTranslationLanguage(): string { return this.settings.preferredTranslationLanguage; }
  async setPreferredTranslationLanguage(v: string): Promise<void> {
    await this.settings.setPreferredTranslationLanguage(v);
  }

  get translateArticlePreviewsByDefault(): boolean { return this.settings.translateArticlePreviewsByDefault; }
  async setTranslateArticlePreviewsByDefault(v: boolean): Promise<void> {
    await this.settings.setTranslateArticlePreviewsByDefault(v);
  }

  get translateArticlesByDefault(): boolean { return this.settings.translateArticlesByDefault; }
  async setTranslateArticlesByDefault(v: boolean): Promise<void> { await this.settings.setTranslateArticlesByDefault(v); }

  get showTitleUnreadCount(): boolean { return this.settings.showTitleUnreadCount; }
  async setShowTitleUnreadCount(v: boolean): Promise<void> { await this.settings.setShowTitleUnreadCount(v); }

  get isOpenDrawerOnFab(): boolean { return this.settings.openDrawerOnFab; }
  async setOpenDrawerOnFab(v: boolean): Promise<void> { await this.settings.setOpenDrawerOnFab(v); }

  get forceSingleColumn(): boolean { return this.settings.forceSingleColumn; }
  async setForceSingleColumn(v: boolean): Promise<void> { await this.settings.setForceSingleColumn(v); }

  get isOpenAdjacent(): boolean { return this.settings.openAdjacent; }
  async setOpenAdjacent(v: boolean): Promise<void> { await this.settings.setOpenAdjacent(v); }

  get isPagingMode(): boolean { return this.settings.isPagingMode; }
  async setIsPagingMode(v: boolean): Promise<void> { await this.settings.setIsPagingMode(v); }

  get isAnimatedPaging(): boolean { return this.settings.isAnimatedPaging; }
  async setIsAnimatedPaging(v: boolean): Promise<void> { await this.settings.setIsAnimatedPaging(v); }

  get showReadingTime(): boolean { return this.settings.showReadingTime; }
  async setShowReadingTime(v: boolean): Promise<void> { await this.settings.setShowReadingTime(v); }
}
