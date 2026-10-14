/**
 * Repository（源 archmodel/Repository.kt）：UI / 小组件 / 后台作业访问数据的唯一门面（模块级单例）。
 * - StateFlow → 同步快照 getter + observeXxx(cb)（立即回调当前值，返回反订阅函数）；
 * - Room Flow → DbNotifier 驱动的 observeQuery；Paging3 → PagedListHandle（参数变化时内部换新分页，flatMapLatest 等价）；
 * - JobScheduler（runOnceRssSync / runOnceSyncChainSendRead）与动态快捷方式 → RepositoryHooks 注入（见 RepoTypes）；
 * - runOnceBlocklistUpdate → 进程内直接重算（无网络要求，源作业 minLatency 1ms）。
 * 设置透传见基类 RepoSettings。同步链网络操作（join/leave/create/removeDevice/updateDeviceList）属 features/sync/SyncChain。
 */
import { common } from '@kit.AbilityKit';
import { EPOCH_MS, Feed, FeedForSettings, FeedTitle, FeedUnreadCount, isBlankString } from '../model/Feed';
import { FeedItemCursor, FeedItemWithFeed, FeedListItem } from '../model/FeedItem';
import {
  ID_ALL_FEEDS, ID_SAVED_ARTICLES, ID_UNSET, ItemOpener, PREF_VAL_OPEN_WITH_BROWSER, PREF_VAL_OPEN_WITH_CUSTOM_TAB,
  PREF_VAL_OPEN_WITH_READER, SortingOptions
} from '../model/Enums';
import { PrefsFeedListFilter, FeedListFilter } from '../settings/SettingsModels';
import * as K from '../settings/SettingsKeys';
import { setBlocklistChangedHook } from '../settings/SettingsHooks';
import { Either } from '../util/Either';
import {
  AddFontError, Article, FeedAndTag, FeedType, Listeners, PagedListCallback, PagedListHandle, RemoveFontError,
  RepositoryHooks, ScreenTitle
} from './RepoTypes';
import { RepoBackground } from './RepoBackground';
import { SessionStore } from './SessionStore';
import { DEFAULT_FONT, FontSelection, FontStore } from './FontStore';

export const FEEDER_NEWS_TITLE: string = 'Feeder News';
export const FEEDER_NEWS_URL: string = 'https://news.nononsenseapps.com/index.atom';

/** 源 emptyFeedListFilter（unread=true，其余 false → 条件 read_time is null） */
export const EMPTY_FEED_LIST_FILTER: FeedListFilter = PrefsFeedListFilter.of(false, false, false);

const LIST_ARG_KEYS: string[] = [K.PREF_LAST_FEED_ID, K.SETTING_KEY_MIN_READ_TIME, K.PREF_SORT, K.PREFS_FILTER_SAVED,
  K.PREFS_FILTER_RECENTLY_READ, K.PREFS_FILTER_READ];

/** 源 private data class FeedListArgs */
class FeedListArgs {
  feedId: number = ID_UNSET;
  tag: string = '';
  newestFirst: boolean = true;
  minReadTime: number = EPOCH_MS;
  filter: FeedListFilter = EMPTY_FEED_LIST_FILTER;
  search: string = '';

  get key(): string {
    const f: FeedListFilter = this.filter;
    return `${this.feedId}|${this.tag}|${this.newestFirst}|${this.minReadTime}|${f.unread}${f.saved}${f.recentlyRead}` +
      `${f.read}|${this.search}`;
  }
}

@ObservedV2
export class RepositoryState {
  /** 源 search: MutableStateFlow("")，仅内存（RP-A04） */
  @Trace search: string = '';
}

export class Repository extends RepoBackground {
  private static inst: Repository | null = null;

  readonly state: RepositoryState = new RepositoryState();
  readonly sessionStore: SessionStore = SessionStore.instance();
  readonly fontStore: FontStore = FontStore.instance();
  private readonly searchListeners: Listeners<string> = new Listeners<string>();
  private initPromise: Promise<void> | null = null;

  static instance(): Repository {
    if (Repository.inst === null) {
      Repository.inst = new Repository();
    }
    return Repository.inst as Repository;
  }

  /**
   * 源 Repository init（构造副作用）。须在 SettingsStore.init 与 AppDatabase.init 之后调用（AppBootstrap）；幂等。
   * 注册屏蔽状态重算钩子（SettingsStore.setApplyBlocklistTo* 触发），扫描字体目录，首启加 Feeder News 源。
   */
  init(ctx: common.Context): Promise<void> {
    if (this.initPromise === null) {
      this.fontStore.init(ctx);
      setBlocklistChangedHook((): Promise<void> => this.runOnceBlocklistUpdate());
      this.initPromise = this.addFeederNewsIfInitialStart().catch((e: Error) => {
        console.error(`FEEDER_REPO: addFeederNews failed: ${e?.message}`);
      });
    }
    return this.initPromise as Promise<void>;
  }

  /** RP-A01：首启（addedFeederNews=false）订阅 Feeder News，置位并立即同步该源 */
  private async addFeederNewsIfInitialStart(): Promise<void> {
    if (this.settings.addedFeederNews) {
      return;
    }
    const feed: Feed = new Feed();
    feed.title = FEEDER_NEWS_TITLE;
    feed.url = FEEDER_NEWS_URL;
    const feedId: number = await this.feedStore.upsertFeed(feed);
    await this.settings.setAddedFeederNews(true);
    RepositoryHooks.runOnceRssSync(feedId, '', false, false);
  }

  // ================================================================ minReadTime / 当前源

  /** RP-A02：初值=进程启动时刻，不持久化 */
  get minReadTime(): number { return this.settings.minReadTime; }

  setMinReadTime(epochMs: number): void { this.settings.setMinReadTime(epochMs); }

  observeMinReadTime(cb: (epochMs: number) => void): () => void {
    const off: () => void = this.observeSetting(K.SETTING_KEY_MIN_READ_TIME, () => cb(this.settings.minReadTime));
    cb(this.settings.minReadTime);
    return off;
  }

  get currentFeedAndTag(): FeedAndTag {
    return new FeedAndTag(this.settings.currentFeedId, this.settings.currentFeedTag);
  }

  observeCurrentFeedAndTag(cb: (v: FeedAndTag) => void): () => void {
    const off: () => void = this.observeSetting(K.PREF_LAST_FEED_ID, () => cb(this.currentFeedAndTag));
    cb(this.currentFeedAndTag);
    return off;
  }

  get currentWidgetFeedAndTag(): FeedAndTag {
    return new FeedAndTag(this.settings.currentWidgetFeedId, this.settings.currentWidgetFeedTag);
  }

  observeCurrentWidgetFeedAndTag(cb: (v: FeedAndTag) => void): () => void {
    const off: () => void = this.observeSetting(K.PREF_LAST_WIDGET_FEED_ID, () => cb(this.currentWidgetFeedAndTag));
    cb(this.currentWidgetFeedAndTag);
    return off;
  }

  /** 源 getUnreadCount(feedId, tag)：minReadTime=now、空过滤、空搜索（即 read_time is null，未屏蔽）；RP-A20 */
  observeUnreadCount(feedId: number, tag: string, cb: (count: number) => void): () => void {
    return this.feedItemStore.observeFeedItemCountRaw(feedId, tag, Date.now(), EMPTY_FEED_LIST_FILTER, '', cb);
  }

  async getUnreadCount(feedId: number, tag: string = ''): Promise<number> {
    return await this.feedItemStore.getFeedItemCountRaw(feedId, tag, Date.now(), EMPTY_FEED_LIST_FILTER, '');
  }

  /** RP-A05/A02/A08：持久化当前 (feedId, tag)；变化时 minReadTime=now；feedId>0 时添加/上报动态快捷方式 */
  async setCurrentFeedAndTag(feedId: number, tag: string): Promise<void> {
    if (feedId > ID_UNSET) {
      this.feedStore.getDisplayTitle(feedId).then((title: string | null) => {
        RepositoryHooks.addDynamicShortcutToFeed(feedId, title !== null ? title : '');
      }).catch((e: Error) => {
        console.error(`FEEDER_REPO: shortcut title failed: ${e?.message}`);
      });
    }
    if (await this.settings.setCurrentFeedAndTag(feedId, tag)) {
      this.setMinReadTime(Date.now());
    }
  }

  async setCurrentWidgetFeedAndTag(feedId: number, tag: string): Promise<void> {
    await this.settings.setCurrentWidgetFeedAndTag(feedId, tag);
  }

  /** RP-A07 */
  async renameTag(oldTag: string, newTag: string): Promise<void> {
    await this.feedStore.renameTag(oldTag, newTag);
    const cur: FeedAndTag = this.currentFeedAndTag;
    if (cur.feedId === ID_UNSET && cur.tag === oldTag) {
      await this.setCurrentFeedAndTag(ID_UNSET, newTag);
    }
  }

  // ================================================================ 搜索 / 当前文章

  get search(): string { return this.state.search; }

  /** 源 searchFor(value) */
  searchFor(value: string): void {
    if (this.state.search === value) {
      return;
    }
    this.state.search = value;
    this.searchListeners.emit(value);
  }

  observeSearch(cb: (search: string) => void): () => void {
    const off: () => void = this.searchListeners.add(cb);
    cb(this.state.search);
    return off;
  }

  get currentArticleId(): number { return this.settings.currentArticleId; }

  async setCurrentArticle(articleId: number): Promise<void> { await this.settings.setCurrentArticle(articleId); }

  async getCurrentArticle(): Promise<FeedItemWithFeed | null> {
    return await this.feedItemStore.getArticle(this.settings.currentArticleId);
  }

  /** 源 getArticleFlow(itemId) */
  observeArticle(itemId: number, cb: (article: Article) => void): () => void {
    return this.feedItemStore.observeFeedItem(itemId, (item: FeedItemWithFeed | null) => cb(new Article(item)));
  }

  /** 源 currentArticle: Flow<Article>（跟随 currentArticleId） */
  observeCurrentArticle(cb: (article: Article) => void): () => void {
    let lastId: number = this.settings.currentArticleId;
    let inner: () => void = this.observeArticle(lastId, cb);
    const off: () => void = this.observeSetting(K.PREF_LAST_ARTICLE_ID, () => {
      const id: number = this.settings.currentArticleId;
      if (id !== lastId) {
        lastId = id;
        inner();
        inner = this.observeArticle(id, cb);
      }
    });
    return () => {
      off();
      inner();
    };
  }

  // ================================================================ 字体（RP-A38..A41）

  /** 源 font: StateFlow<FontSelection>（路径解析失败→默认 RobotoFlex） */
  get font(): FontSelection {
    const f: FontSelection | null = this.fontStore.getFontSelectionFromPath(this.settings.font);
    return f !== null ? f : DEFAULT_FONT;
  }

  async setFont(value: FontSelection): Promise<void> { await this.settings.setFont(value.serialize()); }

  get fontOptions(): FontSelection[] { return this.fontStore.fontOptions; }

  observeFontOptions(cb: (options: FontSelection[]) => void): () => void { return this.fontStore.observeFontOptions(cb); }

  /** 添加成功后自动设为当前字体；失败返回 Left(AddFontError)，不改变当前字体与列表 */
  async addFont(uri: string, displayName: string | null = null): Promise<Either<AddFontError, boolean>> {
    return await Either.catchingAsync<AddFontError, boolean>((e: Error): AddFontError => {
      console.error(`FEEDER_REPO: Failed to add user font: ${e?.message}`);
      return new AddFontError(e);
    }, async (): Promise<boolean> => {
      const userFont: FontSelection = await this.fontStore.addFont(uri, displayName);
      await this.setFont(userFont);
      return true;
    });
  }

  /** 仅对用户字体生效：先设为默认 RobotoFlex，再删文件并刷新列表；内置字体 no-op 返回 Right */
  async removeFont(font: FontSelection): Promise<Either<RemoveFontError, boolean>> {
    return await Either.catchingAsync<RemoveFontError, boolean>((e: Error): RemoveFontError => {
      console.error(`FEEDER_REPO: Failed to remove user font: ${e?.message}`);
      return new RemoveFontError(e);
    }, async (): Promise<boolean> => {
      if (font.isUserFont) {
        await this.setFont(DEFAULT_FONT);
        await this.fontStore.removeFont(font);
      }
      return true;
    });
  }

  // ================================================================ 会话态

  get resumeTime(): number { return this.sessionStore.resumeTime; }

  setResumeTime(epochMs: number): void { this.sessionStore.setResumeTime(epochMs); }

  get expandedTags(): Set<string> { return this.sessionStore.expandedTags; }

  toggleTagExpansion(tag: string): void { this.sessionStore.toggleTagExpansion(tag); }

  get syncWorkerRunning(): boolean { return this.sessionStore.syncWorkerRunning; }

  setSyncWorkerRunning(running: boolean): void { this.sessionStore.setSyncWorkerRunning(running); }

  get isSyncChainConfigured(): boolean { return RepositoryHooks.isSyncChainConfigured(); }

  /** RP-A22：MAX(last_sync) 在最近 10 秒内（仅在 feeds 变化时重算，照源 mapLatest + distinctUntilChanged） */
  observeCurrentlySyncing(cb: (syncing: boolean) => void): () => void {
    let last: boolean | null = null;
    return this.feedStore.observeCurrentlySyncingLatestTimestamp((ts: number | null) => {
      const v: boolean = (ts !== null ? ts : EPOCH_MS) > Date.now() - 10000;
      if (v !== last) {
        last = v;
        cb(v);
      }
    });
  }

  // ================================================================ 列表

  private currentFeedListArgs(newestFirstFromSorting: boolean): FeedListArgs {
    const a: FeedListArgs = new FeedListArgs();
    a.feedId = this.settings.currentFeedId;
    a.tag = this.settings.currentFeedTag;
    a.minReadTime = a.feedId === ID_SAVED_ARTICLES ? EPOCH_MS : this.settings.minReadTime;
    a.newestFirst = newestFirstFromSorting ? this.settings.currentSorting === SortingOptions.NEWEST_FIRST : false;
    a.filter = this.settings.feedListFilter;
    a.search = this.state.search;
    return a;
  }

  /**
   * 源 getCurrentFeedListItems()（RP-A15）：当前源/标签、minReadTime、排序、过滤、搜索任一变化 → 换新分页重查；
   * 数据变化 → 同参数重查。UI：onReachEnd → handle.loadMore()；渲染第 i 项 → handle.onItemAccessed(i)；离开 → dispose()。
   */
  getCurrentFeedListItems(cb: PagedListCallback<FeedListItem>): PagedListHandle<FeedListItem> {
    const handle: PagedListHandle<FeedListItem> = new PagedListHandle<FeedListItem>();
    let lastKey: string = '';
    const rebuild = (): void => {
      const a: FeedListArgs = this.currentFeedListArgs(true);
      const key: string = a.key;
      if (key === lastKey) {
        return;
      }
      lastKey = key;
      handle.replace(this.feedItemStore.getPagedFeedItemsRaw(a.feedId, a.tag, a.minReadTime, a.newestFirst, a.filter,
        a.search, cb));
    };
    handle.addDisposer(this.settings.observe((k: string) => {
      if (LIST_ARG_KEYS.indexOf(k) >= 0) {
        rebuild();
      }
    }));
    handle.addDisposer(this.searchListeners.add((s: string) => rebuild()));
    rebuild();
    return handle;
  }

  /** 源 getCurrentFeedListVisibleItemCount()（不含排序） */
  observeCurrentFeedListVisibleItemCount(cb: (count: number) => void): () => void {
    let lastKey: string = '';
    let inner: () => void = () => {
    };
    const rebuild = (): void => {
      const a: FeedListArgs = this.currentFeedListArgs(false);
      if (a.key === lastKey) {
        return;
      }
      lastKey = a.key;
      inner();
      inner = this.feedItemStore.observeFeedItemCountRaw(a.feedId, a.tag, a.minReadTime, a.filter, a.search, cb);
    };
    const offSettings: () => void = this.settings.observe((k: string) => {
      if (LIST_ARG_KEYS.indexOf(k) >= 0) {
        rebuild();
      }
    });
    const offSearch: () => void = this.searchListeners.add((s: string) => rebuild());
    rebuild();
    return () => {
      offSettings();
      offSearch();
      inner();
    };
  }

  /** 源 getCurrentWidgetFeedListItems()（RP-A18） */
  observeCurrentWidgetFeedListItems(cb: (items: FeedListItem[]) => void): () => void {
    let cur: FeedAndTag = this.currentWidgetFeedAndTag;
    let inner: () => void = this.feedItemStore.observeWidgetFeedListItems(cur.feedId, cur.tag, cb);
    const off: () => void = this.observeSetting(K.PREF_LAST_WIDGET_FEED_ID, () => {
      cur = this.currentWidgetFeedAndTag;
      inner();
      inner = this.feedItemStore.observeWidgetFeedListItems(cur.feedId, cur.tag, cb);
    });
    return () => {
      off();
      inner();
    };
  }

  // ================================================================ 订阅源

  async getFeed(feedId: number): Promise<Feed | null> { return await this.feedStore.getFeed(feedId); }

  /** 源 getFeed(url: URL) */
  async getFeedByUrl(url: string): Promise<Feed | null> { return await this.feedStore.getFeedByUrl(url); }

  async saveFeed(feed: Feed): Promise<number> { return await this.feedStore.saveFeed(feed); }

  async upsertFeed(feedSql: Feed): Promise<number> { return await this.feedStore.upsertFeed(feedSql); }

  async toggleNotifications(feedId: number, value: boolean): Promise<void> {
    await this.feedStore.toggleNotifications(feedId, value);
  }

  observeFeedNotificationSettings(cb: (feeds: FeedForSettings[]) => void): () => void {
    return this.feedStore.observeFeedForSettings(cb);
  }

  /** RP-A06/A08：删除；移除对应快捷方式；当前选中被删 → 切到全部 */
  async deleteFeeds(feedIds: number[]): Promise<void> {
    await this.feedStore.deleteFeeds(feedIds);
    RepositoryHooks.removeDynamicShortcuts(feedIds);
    if (feedIds.indexOf(this.settings.currentFeedId) >= 0) {
      await this.setCurrentFeedAndTag(ID_ALL_FEEDS, '');
    }
  }

  /** 源 deleteFeed(url)：同步链用，仅删行 */
  async deleteFeed(url: string): Promise<void> { await this.feedStore.deleteFeedByUrl(url); }

  async getFeedsOrderedByUrl(): Promise<Feed[]> { return await this.feedStore.getFeedsOrderedByUrl(); }

  observeAllTags(cb: (tags: string[]) => void): () => void { return this.feedStore.observeAllTags(cb); }

  async getAllTags(): Promise<string[]> { return await this.feedStore.getAllTags(); }

  /** 源 getPagedNavDrawerItems()（RP-A21）：expandedTags 变化 → 换新分页 */
  getPagedNavDrawerItems(cb: PagedListCallback<FeedUnreadCount>): PagedListHandle<FeedUnreadCount> {
    const handle: PagedListHandle<FeedUnreadCount> = new PagedListHandle<FeedUnreadCount>();
    handle.addDisposer(this.sessionStore.observeExpandedTags((tags: Set<string>) => {
      handle.replace(this.feedStore.getPagedNavDrawerItems(tags, cb));
    }));
    return handle;
  }

  /** 源 getUnreadBookmarksCount：收藏视图计数（实为未屏蔽收藏总数，不论已读） */
  observeUnreadBookmarksCount(cb: (count: number) => void): () => void {
    return this.feedItemStore.observeFeedItemCountRaw(ID_SAVED_ARTICLES, '', EPOCH_MS, EMPTY_FEED_LIST_FILTER, '', cb);
  }

  observeCurrentlyVisibleFeedTitles(cb: (titles: FeedTitle[]) => void): () => void {
    let inner: () => void = () => {
    };
    const off: () => void = this.observeCurrentFeedAndTag((v: FeedAndTag) => {
      inner();
      inner = this.feedStore.observeFeedTitles(v.feedId, v.tag, cb);
    });
    return () => {
      off();
      inner();
    };
  }

  // ================================================================ 标题

  private async buildScreenTitle(feedId: number, tag: string, type: FeedType, unread: number): Promise<ScreenTitle> {
    let title: string | null = null;
    if (feedId > ID_UNSET) {
      title = await this.feedStore.getDisplayTitle(feedId);
    } else if (!isBlankString(tag)) {
      title = tag;
    }
    return new ScreenTitle(title, type, unread);
  }

  private observeTitle(feedId: number, tag: string, type: FeedType, cb: (t: ScreenTitle) => void): () => void {
    let seq: number = 0;
    return this.observeUnreadCount(feedId, tag, (count: number) => {
      seq++;
      const mine: number = seq;
      this.buildScreenTitle(feedId, tag, type, count).then((t: ScreenTitle) => {
        if (mine === seq) {
          cb(t);
        }
      }).catch((e: Error) => console.error(`FEEDER_REPO: screen title failed: ${e?.message}`));
    });
  }

  /** 源 getScreenTitleForFeedOrTag：类型按 feedId（0→TAG、-10→ALL_FEEDS、-20→SAVED_ARTICLES、其余 FEED） */
  observeScreenTitleForFeedOrTag(feedId: number, tag: string, cb: (t: ScreenTitle) => void): () => void {
    let type: FeedType = FeedType.FEED;
    if (feedId === ID_UNSET) {
      type = FeedType.TAG;
    } else if (feedId === ID_ALL_FEEDS) {
      type = FeedType.ALL_FEEDS;
    } else if (feedId === ID_SAVED_ARTICLES) {
      type = FeedType.SAVED_ARTICLES;
    }
    return this.observeTitle(feedId, tag, type, cb);
  }

  /** RP-A19/A20：主界面标题（跟随当前源/标签） */
  observeScreenTitleForCurrentFeedOrTag(cb: (t: ScreenTitle) => void): () => void {
    let inner: () => void = () => {
    };
    const off: () => void = this.observeCurrentFeedAndTag((v: FeedAndTag) => {
      let type: FeedType = FeedType.FEED;
      if (!isBlankString(v.tag)) {
        type = FeedType.TAG;
      } else if (v.feedId === ID_UNSET || v.feedId === ID_ALL_FEEDS) {
        type = FeedType.ALL_FEEDS;
      } else if (v.feedId === ID_SAVED_ARTICLES) {
        type = FeedType.SAVED_ARTICLES;
      }
      inner();
      inner = this.observeTitle(v.feedId, v.tag, type, cb);
    });
    return () => {
      off();
      inner();
    };
  }

  // ================================================================ 已读 / 收藏

  async setBookmarked(itemId: number, bookmarked: boolean): Promise<void> {
    await this.feedItemStore.setBookmarked(itemId, bookmarked);
  }

  async markAsNotified(itemIds: number[]): Promise<void> { await this.feedItemStore.markAsNotified(itemIds); }

  /** RP-A23/A24 */
  async markAsReadAndNotified(itemId: number, readTimeBeforeMinReadTime: boolean = false): Promise<void> {
    const minReadTimeValue: number = this.settings.minReadTime;
    if (readTimeBeforeMinReadTime && minReadTimeValue > EPOCH_MS) {
      // If read time is not EPOCH, one second before so swipe can get rid of it
      await this.feedItemStore.markAsReadAndNotifiedAndOverwriteReadTime(itemId, minReadTimeValue - 1000);
    } else {
      await this.feedItemStore.markAsReadAndNotified(itemId);
    }
    RepositoryHooks.runOnceSyncChainSendRead();
  }

  /** RP-A25 */
  async markAsUnread(itemId: number): Promise<void> {
    await this.feedItemStore.markAsUnread(itemId);
    await this.syncRemoteStore.setNotSynced(itemId);
  }

  /** RP-A27 */
  async markAllAsReadInFeedOrTag(feedId: number, tag: string): Promise<void> {
    if (feedId > ID_UNSET) {
      await this.feedItemStore.markAllAsReadInFeed(feedId);
    } else if (!isBlankString(tag)) {
      await this.feedItemStore.markAllAsReadInTag(tag);
    } else {
      await this.feedItemStore.markAllAsRead();
    }
    RepositoryHooks.runOnceSyncChainSendRead();
    this.setMinReadTime(Date.now());
  }

  /** RP-A28：列表中位于游标之上的条目 */
  async markBeforeAsRead(cursor: FeedItemCursor, feedId: number, tag: string): Promise<void> {
    await this.feedItemStore.markAsReadRaw(feedId, tag, this.settings.feedListFilter, this.state.search,
      this.settings.minReadTime, SortingOptions.NEWEST_FIRST !== this.settings.currentSorting, cursor);
    RepositoryHooks.runOnceSyncChainSendRead();
  }

  /** RP-A28：列表中位于游标之下的条目 */
  async markAfterAsRead(cursor: FeedItemCursor, feedId: number, tag: string): Promise<void> {
    await this.feedItemStore.markAsReadRaw(feedId, tag, this.settings.feedListFilter, this.state.search,
      this.settings.minReadTime, SortingOptions.NEWEST_FIRST === this.settings.currentSorting, cursor);
    RepositoryHooks.runOnceSyncChainSendRead();
  }

  async shouldDisplayFullTextForItemByDefault(itemId: number): Promise<boolean> {
    return await this.feedItemStore.getFullTextByDefault(itemId);
  }

  async getLink(itemId: number): Promise<string | null> { return await this.feedItemStore.getLink(itemId); }

  /** RP-A32：源设置 "2"→浏览器、"3"→自定义标签页、"0"→阅读器，其他回落全局 itemOpener */
  async getArticleOpener(itemId: number): Promise<ItemOpener> {
    const v: string | null = await this.feedItemStore.getArticleOpener(itemId);
    if (v === PREF_VAL_OPEN_WITH_BROWSER) {
      return ItemOpener.DEFAULT_BROWSER;
    } else if (v === PREF_VAL_OPEN_WITH_CUSTOM_TAB) {
      return ItemOpener.CUSTOM_TAB;
    } else if (v === PREF_VAL_OPEN_WITH_READER) {
      return ItemOpener.READER;
    }
    return this.settings.itemOpener;
  }
}
