/**
 * FeedViewModel — 源 ui/compose/feedarticle/FeedViewModel.kt（FeedScreenViewState 由 32 个流 combine 而成）。
 * 鸿蒙：@ObservedV2 状态对象，按字段拆分（@Trace），设置项直接读 SettingsStore.state（@Trace），避免整体重渲染。
 *  - 列表：Repository.getCurrentFeedListItems（Paging3 等价物；feed/tag、minReadTime、排序、筛选、搜索变化 → 换新分页）；
 *  - 筛选/排序/已读/收藏/删除/改名/同步：一律经 Repository / SyncScheduler（写操作不绑页面生命周期，等价 ApplicationCoroutineScope）；
 *  - 菜单/筛选菜单/搜索栏开关存 SavedStateHandle（键 toolbarMenuVisible / filterMenuVisible / searchBarVisible，FD-A51）；
 *  - 滚动标已读（FD-A45）：可见≥90% 持续 500ms 记“看过”，滚出屏幕时标已读；未满 500ms 即离开 → 取消。
 */
import { FeedListItem } from '../../core/model/FeedItem';
import { FeedTitle } from '../../core/model/Feed';
import { ID_SAVED_ARTICLES, ID_UNSET, ItemOpener } from '../../core/model/Enums';
import { Repository } from '../../core/repo/Repository';
import { FeedAndTag, FeedType, PagedListHandle, ScreenTitle } from '../../core/repo/RepoTypes';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { FeedListFilter, SettingsState } from '../../core/settings/SettingsModels';
import { SyncStatus } from '../../core/sync/SyncStatus';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { SavedStateHandle, SavedStateRegistry } from '../../core/platform/LayoutAdapt';
import { FeedCardTranslations } from '../translation/FeedCardTranslations';
import { FeedItemsDataSource } from './FeedListSource';

const LOG_TAG: string = 'FEEDER_FEEDVM';
const SAVED_STATE_SCOPE: string = 'FeedViewModel';
const KEY_TOOLBAR_MENU_VISIBLE: string = 'toolbarMenuVisible';
const KEY_FILTER_MENU_VISIBLE: string = 'filterMenuVisible';
const KEY_SEARCH_BAR_VISIBLE: string = 'searchBarVisible';
/** 源 FeedScreen.kt:1153：手动下拉后 5s 无论如何清除刷新标志 */
export const MANUAL_REFRESH_TIMEOUT_MS: number = 5000;
/** 源 REQUIRED_VISIBLE_TIME_FOR_MARK_AS_READ */
export const REQUIRED_VISIBLE_TIME_FOR_MARK_AS_READ: number = 500;
/** 源 trackVisibility(0.9f) */
export const MARK_AS_READ_VISIBLE_THRESHOLD: number = 0.9;

/** 页面提供的导航/外部打开能力（源 openArticle 的 lambda 参数） */
export class FeedNavigator {
  navigateToArticle: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:navigateToArticle:FeedNavigator ${itemId}`);
  };
  openInCustomTab: (link: string) => void = (link: string) => {
    console.info(`TODO:openInCustomTab:FeedNavigator ${link}`);
  };
  openInBrowser: (link: string) => void = (link: string) => {
    console.info(`TODO:openInBrowser:FeedNavigator ${link}`);
  };
  toast: (message: Resource) => void = (message: Resource) => {
    console.info(`TODO:toast:FeedNavigator ${message.id}`);
  };
}

function savedBool(h: SavedStateHandle, key: string): boolean {
  const v: Object | undefined = h.get(key);
  return v !== undefined && v !== null && (v as boolean) === true;
}

@ObservedV2
export class FeedViewModel {
  /** 源 currentFeedOrTag */
  @Trace currentFeedId: number = ID_UNSET;
  @Trace currentTag: string = '';
  /** 源 feedScreenTitle（初值 ("", ALL_FEEDS, 0)） */
  @Trace feedScreenTitle: ScreenTitle = new ScreenTitle('', FeedType.ALL_FEEDS, 0);
  /** 源 visibleFeeds（编辑/删除对话框） */
  @Trace visibleFeeds: FeedTitle[] = [];
  /** 源 haveVisibleFeedItems：初值 true，避免数据加载前闪空态（FD-A35） */
  @Trace haveVisibleFeedItems: boolean = true;
  /** 源 currentlySyncing = syncWorkerRunning && 最近同步在 10s 内（FD-A34） */
  @Trace currentlySyncing: boolean = false;
  /** 源 manuallyTriggeredRefresh（rememberSaveable） */
  @Trace manuallyTriggeredRefresh: boolean = false;
  /** 源 repository.search（内存） */
  @Trace search: string = '';
  @Trace showToolbarMenu: boolean = false;
  @Trace showFilterMenu: boolean = false;
  @Trace searchBarShown: boolean = false;
  /** 已加载条目数（LazyForEach 外的布局判断用） */
  @Trace itemCount: number = 0;
  /** 每次递增 → 列表/网格滚回顶部（FD-A22 / FD-A44） */
  @Trace scrollToTopRequest: number = 0;
  /** 卡片翻译代数（源 translatedFeedCards.generation） */
  @Trace translationGeneration: number = 0;

  readonly settings: SettingsState = SettingsStore.instance().state;
  readonly dataSource: FeedItemsDataSource = new FeedItemsDataSource();
  /** 源 translatedFeedCards + translationModelDownloadProgress（翻译单元实现，FD-A49/A50） */
  @Trace translations: FeedCardTranslations = new FeedCardTranslations();
  private readonly repo: Repository = Repository.instance();
  private readonly savedState: SavedStateHandle = SavedStateRegistry.handle(SAVED_STATE_SCOPE);
  private handle: PagedListHandle<FeedListItem> | null = null;
  private disposers: (() => void)[] = [];
  private rawItems: FeedListItem[] = [];
  private refreshTimer: number = -1;
  private visibleTimers: Map<number, number> = new Map<number, number>();
  private wasVisible: Set<number> = new Set<number>();
  /** 当前在屏（已组合）的条目 id（翻译配置变化后重译用） */
  private shownIds: Set<number> = new Set<number>();
  private started: boolean = false;

  constructor() {
    this.showToolbarMenu = savedBool(this.savedState, KEY_TOOLBAR_MENU_VISIBLE);
    this.showFilterMenu = savedBool(this.savedState, KEY_FILTER_MENU_VISIBLE);
    this.searchBarShown = savedBool(this.savedState, KEY_SEARCH_BAR_VISIBLE);
  }

  // ================================================================ 派生状态

  get feedKey(): string {
    return `${this.currentFeedId}|${this.currentTag}`;
  }

  /** 源 FeedOrTag.isFeed */
  get isFeed(): boolean {
    return this.currentFeedId > ID_UNSET;
  }

  /** 源 FeedOrTag.isSavedArticles */
  get isSavedArticles(): boolean {
    return this.currentFeedId === ID_SAVED_ARTICLES;
  }

  get filter(): FeedListFilter {
    return this.settings.feedListFilter;
  }

  /** 源 searchBarVisible || search.isNotEmpty()（FD-A13） */
  get searchBarVisible(): boolean {
    return this.searchBarShown || this.search.length > 0;
  }

  /** 源 isRefreshing = manuallyTriggeredRefresh || currentlySyncing */
  get isRefreshing(): boolean {
    return this.manuallyTriggeredRefresh || this.currentlySyncing;
  }

  /** 源 showFab = haveVisibleFeedItems && pref_show_fab */
  get showFab(): boolean {
    return this.haveVisibleFeedItems && this.settings.showFab;
  }

  /** 源 Rename tag 显示条件：title.type == TAG && !isFeed */
  get showRenameTag(): boolean {
    return this.feedScreenTitle.type === FeedType.TAG && !this.isFeed;
  }

  // ================================================================ 生命周期

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.handle = this.repo.getCurrentFeedListItems((items: FeedListItem[], endReached: boolean) => {
      this.rawItems = items;
      this.publish();
    });
    this.disposers.push(this.repo.observeCurrentFeedAndTag((v: FeedAndTag) => {
      this.currentFeedId = v.feedId;
      this.currentTag = v.tag;
    }));
    this.disposers.push(this.repo.observeScreenTitleForCurrentFeedOrTag((t: ScreenTitle) => {
      this.feedScreenTitle = t;
    }));
    this.disposers.push(this.repo.observeCurrentlyVisibleFeedTitles((titles: FeedTitle[]) => {
      this.visibleFeeds = titles;
    }));
    this.disposers.push(this.repo.observeCurrentFeedListVisibleItemCount((count: number) => {
      this.haveVisibleFeedItems = count > 0;
    }));
    this.disposers.push(this.repo.observeSearch((s: string) => {
      this.search = s;
    }));
    this.disposers.push(SyncStatus.observeFeedRefreshing((v: boolean) => {
      this.currentlySyncing = v;
      // 源 LaunchedEffect(currentlySyncing)：同步开始 → 清手动刷新标志
      if (v && this.manuallyTriggeredRefresh) {
        this.setManualRefresh(false);
      }
    }));
    // 源 combine(translateArticlePreviewsByDefault, translationApiSettings, preferredLanguage)：配置变化清空已译重译
    this.translations.start();
  }

  /** 已译卡片变化（缓存命中/翻译完成/配置变化清空）→ 重新合并显示（源 TranslatedFeedCards.merge） */
  @Monitor('translations.entries', 'translations.generation')
  onTranslationsChanged(monitor: IMonitor): void {
    const generationChanged: boolean = this.translationGeneration !== this.translations.generation;
    this.translationGeneration = this.translations.generation;
    this.publish();
    if (generationChanged) {
      // 源 LaunchedEffect(item.id, title, snippet, generation)：新一代对当前在屏卡片重新发起翻译
      for (const it of this.rawItems) {
        if (this.shownIds.has(it.id)) {
          this.translations.translateFeedCardIfNeeded(it);
        }
      }
    }
  }

  dispose(): void {
    this.flushVisibilityMarks();
    if (this.handle !== null) {
      this.handle.dispose();
      this.handle = null;
    }
    for (const d of this.disposers) {
      d();
    }
    this.disposers = [];
    this.translations.stop();
    this.setManualRefresh(false);
    this.started = false;
  }

  private publish(): void {
    const merged: FeedListItem[] = this.rawItems.map((it: FeedListItem): FeedListItem => this.translations.merge(it));
    this.itemCount = merged.length;
    this.dataSource.setItems(merged);
  }

  /** 列表渲染第 i 项（Paging 预取）+ 卡片翻译触发（源 LaunchedEffect(...) { onTranslateFeedCard }） */
  onItemShown(index: number): void {
    if (this.handle !== null) {
      this.handle.onItemAccessed(index);
    }
    if (index >= 0 && index < this.rawItems.length) {
      this.shownIds.add(this.rawItems[index].id);
      this.translations.translateFeedCardIfNeeded(this.rawItems[index]);
    }
  }

  loadMore(): void {
    if (this.handle !== null) {
      this.handle.loadMore();
    }
  }

  // ================================================================ 菜单 / 搜索（SavedState）

  setToolbarMenuVisible(visible: boolean): void {
    this.savedState.set(KEY_TOOLBAR_MENU_VISIBLE, visible);
    this.showToolbarMenu = visible;
  }

  setFilterMenuVisible(visible: boolean): void {
    this.savedState.set(KEY_FILTER_MENU_VISIBLE, visible);
    this.showFilterMenu = visible;
  }

  setSearchBarVisible(visible: boolean): void {
    this.savedState.set(KEY_SEARCH_BAR_VISIBLE, visible);
    this.searchBarShown = visible;
  }

  /** 源 searchCallback → repository.searchFor（FD-A11/A14：仅内存） */
  searchFor(value: string): void {
    this.repo.searchFor(value);
  }

  /** 源 Cancel search / Esc：收起并清空（FD-A12） */
  cancelSearch(): void {
    this.setSearchBarVisible(false);
    this.searchFor('');
  }

  // ================================================================ 筛选（FD-A15..A17）

  setFilterSaved(value: boolean): void {
    this.repo.setFeedListFilterSaved(value).catch((e: Error) => this.logError('setFeedListFilterSaved', e));
  }

  setFilterRecentlyRead(value: boolean): void {
    this.repo.setFeedListFilterRecentlyRead(value).catch((e: Error) => this.logError('setFeedListFilterRecentlyRead', e));
  }

  setFilterRead(value: boolean): void {
    this.repo.setFeedListFilterRead(value).catch((e: Error) => this.logError('setFeedListFilterRead', e));
  }

  // ================================================================ 写操作（源 applicationCoroutineScope.launch）

  /** FD-A21 */
  markAllAsRead(): void {
    const cur: FeedAndTag = this.repo.currentFeedAndTag;
    this.repo.markAllAsReadInFeedOrTag(cur.feedId, cur.tag).catch((e: Error) => this.logError('markAllAsRead', e));
  }

  /** FD-A48 */
  markAsUnread(itemId: number): void {
    this.repo.markAsUnread(itemId).catch((e: Error) => this.logError('markAsUnread', e));
  }

  /** FD-A48 */
  markAsRead(itemId: number): void {
    this.repo.markAsReadAndNotified(itemId).catch((e: Error) => this.logError('markAsRead', e));
  }

  /** FD-A26 */
  deleteFeeds(feedIds: number[]): void {
    this.repo.deleteFeeds(feedIds).catch((e: Error) => this.logError('deleteFeeds', e));
  }

  /** FD-A27 */
  renameTag(oldTag: string, newTag: string): void {
    this.repo.renameTag(oldTag, newTag).catch((e: Error) => this.logError('renameTag', e));
  }

  setBookmarked(itemId: number, bookmarked: boolean): void {
    this.repo.setBookmarked(itemId, bookmarked).catch((e: Error) => this.logError('setBookmarked', e));
  }

  /** 源 FeedDestination：参数 id/tag 非默认时设为当前（否则沿用上次 pref_last_feed_id/tag） */
  setCurrentFeedAndTag(feedId: number, tag: string): void {
    this.repo.setCurrentFeedAndTag(feedId, tag).catch((e: Error) => this.logError('setCurrentFeedAndTag', e));
  }

  // ================================================================ 同步 / 刷新

  /** 源 requestImmediateSyncOfCurrentFeedOrTag（下拉刷新，FD-A33） */
  requestImmediateSyncOfCurrentFeedOrTag(): void {
    this.setManualRefresh(true);
    const cur: FeedAndTag = this.repo.currentFeedAndTag;
    SyncScheduler.syncNow(cur.feedId, cur.tag, true, true).catch((e: Error) => this.logError('syncNow', e));
  }

  /** 源 requestImmediateSyncOfAll（菜单 Sync feeds，FD-A22）+ 滚回顶部 */
  requestImmediateSyncOfAll(): void {
    SyncScheduler.syncNow(ID_UNSET, '', true, true).catch((e: Error) => this.logError('syncNow(all)', e));
    this.requestScrollToTop();
  }

  requestScrollToTop(): void {
    this.scrollToTopRequest++;
  }

  private setManualRefresh(v: boolean): void {
    if (this.refreshTimer !== -1) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = -1;
    }
    this.manuallyTriggeredRefresh = v;
    if (v) {
      // 源 LaunchedEffect(manuallyTriggeredRefresh) { delay(5_000); false }：防无限转圈
      this.refreshTimer = setTimeout(() => {
        this.refreshTimer = -1;
        this.manuallyTriggeredRefresh = false;
      }, MANUAL_REFRESH_TIMEOUT_MS);
    }
  }

  // ================================================================ 打开条目（FD-A40 / FD-A41）

  private openInReader(itemId: number, nav: FeedNavigator): void {
    // 源 setCurrentArticle：setCurrentArticle + setIsArticleOpen(true)（内存先行）
    this.repo.setCurrentArticle(itemId).catch((e: Error) => this.logError('setCurrentArticle', e));
    this.repo.setIsArticleOpen(true).catch((e: Error) => this.logError('setIsArticleOpen', e));
    nav.navigateToArticle(itemId);
  }

  async openArticle(itemId: number, nav: FeedNavigator): Promise<void> {
    try {
      const opener: ItemOpener = await this.repo.getArticleOpener(itemId);
      const link: string | null = await this.repo.getLink(itemId);
      if (opener === ItemOpener.CUSTOM_TAB && link !== null) {
        nav.openInCustomTab(link);
      } else if (opener === ItemOpener.DEFAULT_BROWSER && link !== null) {
        nav.openInBrowser(link);
      } else {
        this.openInReader(itemId, nav);
      }
    } catch (e) {
      this.logError('openArticle', e as Error);
    }
    this.markAsRead(itemId);
  }

  openArticleInReader(itemId: number, nav: FeedNavigator): void {
    this.openInReader(itemId, nav);
    this.markAsRead(itemId);
  }

  async openArticleInCustomTab(itemId: number, nav: FeedNavigator): Promise<void> {
    try {
      const link: string | null = await this.repo.getLink(itemId);
      if (link !== null) {
        nav.openInCustomTab(link);
      } else {
        nav.toast($r('app.string.no_article_link_custom_tab'));
      }
    } catch (e) {
      this.logError('openArticleInCustomTab', e as Error);
    }
    this.markAsRead(itemId);
  }

  async openArticleInBrowser(itemId: number, nav: FeedNavigator): Promise<void> {
    try {
      const link: string | null = await this.repo.getLink(itemId);
      if (link !== null) {
        nav.openInBrowser(link);
      } else {
        nav.toast($r('app.string.no_article_link_browser'));
      }
    } catch (e) {
      this.logError('openArticleInBrowser', e as Error);
    }
    this.markAsRead(itemId);
  }

  // ================================================================ 滚动标已读（FD-A45）

  /**
   * 条目可见比例变化（ListItem/FlowItem.onVisibleAreaChange([0, 0.9])）。
   * ≥0.9 → 起 500ms 计时，到时记“看过”（filter.unread 恒真，源 else 分支不可达但照搬）；
   * 比例回到 0（滚出屏幕）→ 未到时取消；已“看过”则标已读。
   */
  onItemVisibility(item: FeedListItem, ratio: number): void {
    const id: number = item.id;
    if (id === ID_UNSET) {
      return;
    }
    if (ratio <= 0) {
      this.onItemGone(id);
      return;
    }
    if (!this.settings.isMarkAsReadOnScroll || !item.unread) {
      return;
    }
    if (ratio >= MARK_AS_READ_VISIBLE_THRESHOLD && !this.visibleTimers.has(id) && !this.wasVisible.has(id)) {
      const timer: number = setTimeout(() => {
        this.visibleTimers.delete(id);
        if (this.filter.unread) {
          this.wasVisible.add(id);
        } else {
          this.markAsRead(id);
        }
      }, REQUIRED_VISIBLE_TIME_FOR_MARK_AS_READ);
      this.visibleTimers.set(id, timer);
    }
  }

  /** 条目离开屏幕/被回收（源 DisposableEffect.onDispose） */
  onItemGone(itemId: number): void {
    this.shownIds.delete(itemId);
    const timer: number | undefined = this.visibleTimers.get(itemId);
    if (timer !== undefined) {
      clearTimeout(timer);
      this.visibleTimers.delete(itemId);
    }
    if (this.wasVisible.has(itemId)) {
      this.wasVisible.delete(itemId);
      this.markAsRead(itemId);
    }
  }

  /** 列表离开组合（换 feed / 页面销毁）：已“看过”的全部标已读，未到时的取消 */
  flushVisibilityMarks(): void {
    this.visibleTimers.forEach((timer: number) => {
      clearTimeout(timer);
    });
    this.visibleTimers.clear();
    const ids: number[] = Array.from(this.wasVisible);
    this.wasVisible.clear();
    for (const id of ids) {
      this.markAsRead(id);
    }
  }

  private logError(op: string, e: Error): void {
    console.error(`${LOG_TAG}: ${op} failed: ${e?.message}`);
  }
}
