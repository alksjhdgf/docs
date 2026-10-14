/*
 * SettingsViewModel — 源 ui/compose/settings/SettingsViewModel.kt（SettingsViewModel / SettingsViewState /
 * UIFeedSettings / OpenAISettingsState / OpenAIModelsState / OpenAISettingsEvent）。
 *
 * - 源 42 路 combine → @ObservedV2 SettingsViewState；设置类字段从 SettingsStore 内存镜像同步拷贝
 *   （构造时即拷贝 → 首帧就是持久化值，不出现源占位默认造成的闪烁，ST-A29），之后订阅 SettingsStore.observe
 *   与 Room 流等价物（blocklist、feeds 通知设置）重拷贝。
 * - SettingsViewState 字段默认值逐字照源（showThumbnails=false、forceSingleColumn=true、font=SystemDefault 等
 *   与 Store 不一致的占位默认保留在类定义上），但页面从不渲染未初始化的占位态。
 * - applicationCoroutineScope 的写入（sync wifi/charging/frequency、block list 增删、applyBlocklist*、
 *   toggleNotifications）→ AppScope.launch（离开页面仍完成）。
 * - batteryOptimizationIgnoredFlow：resumeTime 变化时重查；鸿蒙公开 SDK 无"是否豁免电池优化"查询 → 降级（见 deviations）。
 * - OpenAI/翻译 API 状态与 OpenAISettingsSection 共享 OpenAISettingsVm 单例（两组互不影响，SS-A28）。
 * - 本地翻译语言对：TranslationModelsEditor（SS-A29）。
 */
import { AppScope } from '../../core/app/AppBootstrap';
import { FeedForSettings } from '../../core/model/Feed';
import {
  DarkThemePreferences, FeedItemStyle, ItemOpener, LinkOpener, SortingOptions, SwipeAsRead, SyncFrequency, ThemeOptions
} from '../../core/model/Enums';
import { FontSelection } from '../../core/repo/FontStore';
import { Repository } from '../../core/repo/Repository';
import { OpenAISettings, SettingsState } from '../../core/settings/SettingsModels';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { LanguagePairInfo } from '../translation/BergamotRegistry';
import { TranslationModelsEditor } from '../translation/TranslationModelsEditor';
import {
  canTranslateWithSettings, OpenAISectionType, OpenAISectionVmState, OpenAISettingsVm
} from '../openai/OpenAISettingsModel';
import { UIFeedSettings } from './SettingsOptions';

export { UIFeedSettings } from './SettingsOptions';

const LOG_TAG: string = 'FEEDER_SETTINGSVM';

/** 源 SettingsViewState（字段与默认值逐字照源） */
@ObservedV2
export class SettingsViewState {
  @Trace currentTheme: ThemeOptions = ThemeOptions.SYSTEM;
  @Trace darkThemePreference: DarkThemePreferences = DarkThemePreferences.BLACK;
  @Trace currentSorting: SortingOptions = SortingOptions.NEWEST_FIRST;
  @Trace showFab: boolean = true;
  @Trace feedItemStyle: FeedItemStyle = FeedItemStyle.CARD;
  @Trace blockList: string[] = [];
  @Trace applyBlocklistToSummaries: boolean = false;
  @Trace syncOnResume: boolean = false;
  @Trace syncOnlyOnWifi: boolean = false;
  @Trace syncOnlyWhenCharging: boolean = false;
  @Trace loadImageOnlyOnWifi: boolean = false;
  @Trace showThumbnails: boolean = false;
  @Trace maximumCountPerFeed: number = 100;
  @Trace itemOpener: ItemOpener = ItemOpener.READER;
  @Trace linkOpener: LinkOpener = LinkOpener.CUSTOM_TAB;
  @Trace syncFrequency: SyncFrequency = SyncFrequency.EVERY_1_HOURS;
  @Trace batteryOptimizationIgnored: boolean = false;
  @Trace swipeAsRead: SwipeAsRead = SwipeAsRead.ONLY_FROM_END;
  @Trace useDetectLanguage: boolean = true;
  @Trace useDynamicTheme: boolean = true;
  @Trace feedsSettings: UIFeedSettings[] = [];
  @Trace isMarkAsReadOnScroll: boolean = false;
  @Trace maxLines: number = 2;
  @Trace showOnlyTitle: boolean = false;
  @Trace isOpenAdjacent: boolean = true;
  /** 源 summaryAIState / translationApiState（OpenAISettingsState）：模型状态/编辑态由 OpenAISettingsVm 持有 */
  @Trace summaryAISettings: OpenAISettings = new OpenAISettings();
  @Trace translationApiSettings: OpenAISettings = new OpenAISettings();
  @Trace preferredTranslationLanguage: string = '';
  @Trace canTranslate: boolean = false;
  @Trace showReadingTime: boolean = false;
  @Trace showTitleUnreadCount: boolean = false;
  @Trace isOpenDrawerOnFab: boolean = false;
  @Trace translateArticlePreviewsByDefault: boolean = false;
  @Trace translateArticlesByDefault: boolean = false;
  @Trace translationModelPairs: LanguagePairInfo[] = [];
  @Trace font: FontSelection = FontSelection.SYSTEM_DEFAULT;
  @Trace isPagingMode: boolean = false;
  @Trace isAnimatedPaging: boolean = false;
  @Trace useInAppAudioPlayer: boolean = true;
  @Trace forceSingleColumn: boolean = true;
  @Trace applyBlocklistToLinks: boolean = false;

  /** 源 summaryAIState（OpenAISettingsState：modelsResult / isEditMode / showModelsError） */
  get summaryAIState(): OpenAISectionVmState {
    return OpenAISettingsVm.instance().summary;
  }

  /** 源 translationApiState */
  get translationApiState(): OpenAISectionVmState {
    return OpenAISettingsVm.instance().translation;
  }
}

/** 源 OpenAISettingsEvent（sealed interface）→ kind + 载荷 */
export enum OpenAISettingsEventKind {
  UpdateSettings = 'UpdateSettings',
  LoadModels = 'LoadModels',
  SwitchEditMode = 'SwitchEditMode',
  ShowModelsError = 'ShowModelsError'
}

export class OpenAISettingsEvent {
  readonly kind: OpenAISettingsEventKind;
  readonly settings: OpenAISettings;
  readonly flag: boolean;

  constructor(kind: OpenAISettingsEventKind, settings: OpenAISettings, flag: boolean) {
    this.kind = kind;
    this.settings = settings;
    this.flag = flag;
  }

  static updateSettings(settings: OpenAISettings): OpenAISettingsEvent {
    return new OpenAISettingsEvent(OpenAISettingsEventKind.UpdateSettings, settings, false);
  }

  static loadModels(settings: OpenAISettings): OpenAISettingsEvent {
    return new OpenAISettingsEvent(OpenAISettingsEventKind.LoadModels, settings, false);
  }

  static switchEditMode(enabled: boolean): OpenAISettingsEvent {
    return new OpenAISettingsEvent(OpenAISettingsEventKind.SwitchEditMode, new OpenAISettings(), enabled);
  }

  static showModelsError(show: boolean): OpenAISettingsEvent {
    return new OpenAISettingsEvent(OpenAISettingsEventKind.ShowModelsError, new OpenAISettings(), show);
  }
}

/**
 * 源 PowerManager.isIgnoringBatteryOptimizations(packageName)。
 * 鸿蒙公开 SDK 无应用侧"是否已豁免省电/待机管控"查询（deviceStandby 豁免名单为系统 API），恒 false → 副标题 `On`。
 */
export function isIgnoringBatteryOptimizations(): boolean {
  return false;
}

/** 源 SettingsViewModel.kt:363 canTranslate（SS-A27） */
export function computeCanTranslate(translationSettings: OpenAISettings, preferredLanguage: string): boolean {
  return canTranslateWithSettings(translationSettings, preferredLanguage);
}

function errMsg(e: Error): string {
  return e?.message ?? '';
}

@ObservedV2
export class SettingsViewModel {
  @Trace viewState: SettingsViewState = new SettingsViewState();
  readonly modelsEditor: TranslationModelsEditor;
  private readonly repository: Repository = Repository.instance();
  private readonly store: SettingsStore = SettingsStore.instance();
  private unsubscribers: Array<() => void> = [];
  private started: boolean = false;

  constructor(modelsEditor: TranslationModelsEditor | null = null) {
    this.modelsEditor = modelsEditor !== null ? modelsEditor : new TranslationModelsEditor();
    // 首帧即持久化值（ST-A29）
    this.refreshFromStore();
    this.viewState.batteryOptimizationIgnored = isIgnoringBatteryOptimizations();
  }

  /** 源 init：loadDownloadedLanguagePairs + combine.collect */
  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.loadDownloadedLanguagePairs();
    this.unsubscribers.push(this.store.observe((key: string) => {
      this.refreshFromStore();
    }));
    this.unsubscribers.push(this.repository.observeBlockList((patterns: string[]) => {
      this.viewState.blockList = patterns;
    }));
    this.unsubscribers.push(this.repository.observeFeedNotificationSettings((feeds: FeedForSettings[]) => {
      this.viewState.feedsSettings = feeds.map((f: FeedForSettings) => new UIFeedSettings(f.id, f.title, f.notify));
    }));
    // 源 batteryOptimizationIgnoredFlow = resumeTime.map{...}
    this.unsubscribers.push(this.repository.sessionStore.observeResumeTime((epochMs: number) => {
      this.refreshBatteryOptimization();
    }));
  }

  stop(): void {
    const subs = this.unsubscribers;
    this.unsubscribers = [];
    subs.forEach((u: () => void) => {
      try {
        u();
      } catch (e) {
        console.warn(`${LOG_TAG}: unsubscribe failed ${errMsg(e as Error)}`);
      }
    });
    this.started = false;
  }

  /** 页面回到前台（源 resumeTime 发射）时调用 */
  refreshBatteryOptimization(): void {
    this.viewState.batteryOptimizationIgnored = isIgnoringBatteryOptimizations();
  }

  /** 把 SettingsStore 镜像拷入 viewState（等价源 combine 的设置类参数） */
  refreshFromStore(): void {
    const s: SettingsState = this.store.state;
    const v = this.viewState;
    v.currentTheme = s.currentTheme;
    v.darkThemePreference = s.darkThemePreference;
    v.currentSorting = s.currentSorting;
    v.showFab = s.showFab;
    v.syncOnResume = s.syncOnResume;
    v.syncOnlyOnWifi = s.syncOnlyOnWifi;
    v.syncOnlyWhenCharging = s.syncOnlyWhenCharging;
    v.loadImageOnlyOnWifi = s.loadImageOnlyOnWifi;
    v.showThumbnails = s.showThumbnails;
    v.maximumCountPerFeed = s.maximumCountPerFeed;
    v.itemOpener = s.itemOpener;
    v.linkOpener = s.linkOpener;
    v.syncFrequency = s.syncFrequency;
    v.feedItemStyle = s.feedItemStyle;
    v.swipeAsRead = s.swipeAsRead;
    v.applyBlocklistToSummaries = s.applyBlocklistToSummaries;
    v.useDetectLanguage = s.useDetectLanguage;
    v.useDynamicTheme = s.useDynamicTheme;
    v.isMarkAsReadOnScroll = s.isMarkAsReadOnScroll;
    v.maxLines = s.maxLines;
    v.showOnlyTitle = s.showOnlyTitle;
    v.isOpenAdjacent = s.openAdjacent;
    v.showReadingTime = s.showReadingTime;
    v.showTitleUnreadCount = s.showTitleUnreadCount;
    v.summaryAISettings = s.openAiSettings;
    v.translationApiSettings = s.translationApiSettings;
    v.preferredTranslationLanguage = s.preferredTranslationLanguage;
    v.canTranslate = computeCanTranslate(s.translationApiSettings, s.preferredTranslationLanguage);
    v.isOpenDrawerOnFab = s.openDrawerOnFab;
    v.translateArticlePreviewsByDefault = s.translateArticlePreviewsByDefault;
    v.translateArticlesByDefault = s.translateArticlesByDefault;
    v.font = this.repository.font;
    v.isPagingMode = s.isPagingMode;
    v.isAnimatedPaging = s.isAnimatedPaging;
    v.useInAppAudioPlayer = s.useInAppAudioPlayer;
    v.forceSingleColumn = s.forceSingleColumn;
    v.applyBlocklistToLinks = s.applyBlocklistToLinks;
  }

  /** 同步直调的 setter：store 镜像在 setter 首个 await 前已更新 → 立刻重拷贝，UI 不等落盘 */
  private direct(name: string, p: Promise<void>): void {
    this.refreshFromStore();
    p.catch((e: Error) => {
      console.error(`${LOG_TAG}: ${name} failed ${errMsg(e)}`);
    });
  }

  /** applicationCoroutineScope.launch 等价 */
  private appScope(name: string, task: () => Promise<void>): void {
    AppScope.launch(`settings.${name}`, task);
    this.refreshFromStore();
  }

  setCurrentTheme(value: ThemeOptions): void {
    this.direct('setCurrentTheme', this.repository.setCurrentTheme(value));
  }

  setPreferredDarkTheme(value: DarkThemePreferences): void {
    this.direct('setPreferredDarkTheme', this.repository.setPreferredDarkTheme(value));
  }

  setCurrentSorting(value: SortingOptions): void {
    this.direct('setCurrentSorting', this.repository.setCurrentSorting(value));
  }

  setShowFab(value: boolean): void {
    this.direct('setShowFab', this.repository.setShowFab(value));
  }

  setSyncOnResume(value: boolean): void {
    this.direct('setSyncOnResume', this.repository.setSyncOnResume(value));
  }

  /** ST-A19：store setter 内触发 schedulePeriodicRssSync(replace = true) */
  setSyncOnlyOnWifi(value: boolean): void {
    this.appScope('setSyncOnlyOnWifi', () => this.repository.setSyncOnlyOnWifi(value));
  }

  setSyncOnlyWhenCharging(value: boolean): void {
    this.appScope('setSyncOnlyWhenCharging', () => this.repository.setSyncOnlyWhenCharging(value));
  }

  setLoadImageOnlyOnWifi(value: boolean): void {
    this.direct('setLoadImageOnlyOnWifi', this.repository.setLoadImageOnlyOnWifi(value));
  }

  setShowThumbnails(value: boolean): void {
    this.direct('setShowThumbnails', this.repository.setShowThumbnails(value));
  }

  setUseDetectLanguage(value: boolean): void {
    this.direct('setUseDetectLanguage', this.repository.setUseDetectLanguage(value));
  }

  setUseDynamicTheme(value: boolean): void {
    this.direct('setUseDynamicTheme', this.repository.setUseDynamicTheme(value));
  }

  setMaxCountPerFeed(value: number): void {
    this.direct('setMaxCountPerFeed', this.repository.setMaxCountPerFeed(value));
  }

  setItemOpener(value: ItemOpener): void {
    this.direct('setItemOpener', this.repository.setItemOpener(value));
  }

  setLinkOpener(value: LinkOpener): void {
    this.direct('setLinkOpener', this.repository.setLinkOpener(value));
  }

  setUseInAppAudioPlayer(value: boolean): void {
    this.direct('setUseInAppAudioPlayer', this.repository.setUseInAppAudioPlayer(value));
  }

  /** ST-A19：重排周期同步（MANUAL → 取消） */
  setSyncFrequency(value: SyncFrequency): void {
    this.appScope('setSyncFrequency', () => this.repository.setSyncFrequency(value));
  }

  setFeedItemStyle(value: FeedItemStyle): void {
    this.direct('setFeedItemStyle', this.repository.setFeedItemStyle(value));
  }

  /** ST-A15：空白忽略、小写去空格、重复忽略、之后重算屏蔽状态（Repository.addBlocklistPattern） */
  addToBlockList(value: string): void {
    this.appScope('addToBlockList', () => this.repository.addBlocklistPattern(value));
  }

  removeFromBlockList(value: string): void {
    this.appScope('removeFromBlockList', () => this.repository.removeBlocklistPattern(value));
  }

  setApplyBlocklistToSummaries(value: boolean): void {
    this.appScope('setApplyBlocklistToSummaries', () => this.repository.setApplyBlocklistToSummaries(value));
  }

  setApplyBlocklistToLinks(value: boolean): void {
    this.appScope('setApplyBlocklistToLinks', () => this.repository.setApplyBlocklistToLinks(value));
  }

  toggleNotifications(feedId: number, value: boolean): void {
    // 乐观更新对话框行（DB 通知随后到达重查）
    this.viewState.feedsSettings = this.viewState.feedsSettings.map((f: UIFeedSettings) =>
    f.feedId === feedId ? new UIFeedSettings(f.feedId, f.feedTitle, value) : f);
    this.appScope('toggleNotifications', () => this.repository.toggleNotifications(feedId, value));
  }

  setSwipeAsRead(value: SwipeAsRead): void {
    this.direct('setSwipeAsRead', this.repository.setSwipeAsRead(value));
  }

  setIsMarkAsReadOnScroll(value: boolean): void {
    this.direct('setIsMarkAsReadOnScroll', this.repository.setIsMarkAsReadOnScroll(value));
  }

  setMaxLines(value: number): void {
    this.direct('setMaxLines', this.repository.setMaxLines(value));
  }

  setShowOnlyTitles(value: boolean): void {
    this.direct('setShowOnlyTitles', this.repository.setShowOnlyTitles(value));
  }

  setIsOpenAdjacent(value: boolean): void {
    this.direct('setIsOpenAdjacent', this.repository.setOpenAdjacent(value));
  }

  setShowReadingTime(value: boolean): void {
    this.direct('setShowReadingTime', this.repository.setShowReadingTime(value));
  }

  setShowTitleUnreadCount(value: boolean): void {
    this.direct('setShowTitleUnreadCount', this.repository.setShowTitleUnreadCount(value));
  }

  setOpenDrawerOnFab(value: boolean): void {
    this.direct('setOpenDrawerOnFab', this.repository.setOpenDrawerOnFab(value));
  }

  setTranslateArticlePreviewsByDefault(value: boolean): void {
    this.direct('setTranslateArticlePreviewsByDefault', this.repository.setTranslateArticlePreviewsByDefault(value));
  }

  setTranslateArticlesByDefault(value: boolean): void {
    this.direct('setTranslateArticlesByDefault', this.repository.setTranslateArticlesByDefault(value));
  }

  setIsPagingMode(value: boolean): void {
    this.direct('setIsPagingMode', this.repository.setIsPagingMode(value));
  }

  setForceSingleColumn(value: boolean): void {
    this.direct('setForceSingleColumn', this.repository.setForceSingleColumn(value));
  }

  setIsAnimatedPaging(value: boolean): void {
    this.direct('setIsAnimatedPaging', this.repository.setIsAnimatedPaging(value));
  }

  setPreferredTranslationLanguage(value: string): void {
    this.direct('setPreferredTranslationLanguage', this.repository.setPreferredTranslationLanguage(value));
  }

  // ---------------------------------------------------------------- OpenAI / 翻译 API（SS-A28）

  onSummaryOpenAISettingsEvent(event: OpenAISettingsEvent): void {
    this.handleOpenAISettingsEvent(OpenAISectionType.Summary, event);
  }

  onTranslationApiSettingsEvent(event: OpenAISettingsEvent): void {
    this.handleOpenAISettingsEvent(OpenAISectionType.Translation, event);
  }

  private handleOpenAISettingsEvent(section: OpenAISectionType, event: OpenAISettingsEvent): void {
    const st: OpenAISectionVmState = OpenAISettingsVm.instance().stateOf(section);
    switch (event.kind) {
      case OpenAISettingsEventKind.LoadModels:
        // Loading → Success(ids) / Error(message) / None（缺 token、缺 Azure 版本/部署 id）
        st.loadModels(event.settings);
        break;
      case OpenAISettingsEventKind.UpdateSettings:
        if (section === OpenAISectionType.Summary) {
          this.direct('setOpenAiSettings', this.repository.setOpenAiSettings(event.settings));
        } else {
          this.direct('setTranslationApiSettings', this.repository.setTranslationApiSettings(event.settings));
        }
        break;
      case OpenAISettingsEventKind.SwitchEditMode:
        st.isEditMode = event.flag;
        break;
      default:
        st.showModelsError = event.flag;
        break;
    }
  }

  // ---------------------------------------------------------------- 本地翻译语言对（SS-A29）

  loadDownloadedLanguagePairs(): void {
    this.modelsEditor.load().then(() => {
      this.viewState.translationModelPairs = this.modelsEditor.downloaded;
    }).catch((e: Error) => {
      console.warn(`${LOG_TAG}: load language pairs failed ${errMsg(e)}`);
    });
  }

  async deleteLanguagePair(sourceLanguage: string, targetLanguage: string): Promise<void> {
    await this.modelsEditor.deleteLanguagePair(sourceLanguage, targetLanguage);
    this.viewState.translationModelPairs = this.modelsEditor.downloaded;
  }

  async deleteAllLanguagePairs(): Promise<void> {
    await this.modelsEditor.deleteAllLanguagePairs();
    this.viewState.translationModelPairs = [];
  }
}
