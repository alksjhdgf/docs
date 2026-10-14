/**
 * RepoTypes — 仓储层公共类型与工具（自 Repository.ets 拆出以满足单文件 ≤600 行）。
 * 源：archmodel/Repository.kt 尾部（ScreenTitle/FeedType/Enclosure/Article/TextToDisplay）、archmodel/Errors.kt；
 * 另含 Flow/StateFlow 的等价物（Listeners）、Paging3 的等价物（PagedList / PagedListHandle）、
 * 以及反向依赖注入钩子（conventions §C：setXxxHook(cb)，未注册 no-op）。
 */
import { DbNotifier } from '../db/AppDatabase';
import { FeedItemWithFeed } from '../model/FeedItem';
import { ThumbnailImage } from '../model/Thumbnail';
import { ID_UNSET } from '../model/Enums';

// ============================================================ 源 Repository.kt 数据类型

/** 源 enum FeedType */
export enum FeedType {
  FEED = 'FEED',
  TAG = 'TAG',
  SAVED_ARTICLES = 'SAVED_ARTICLES',
  ALL_FEEDS = 'ALL_FEEDS',
}

/** 源 data class ScreenTitle（title 为 null 时 UI 显示通用名） */
export class ScreenTitle {
  readonly title: string | null;
  readonly type: FeedType;
  readonly unreadCount: number;

  constructor(title: string | null, type: FeedType, unreadCount: number) {
    this.title = title;
    this.type = type;
    this.unreadCount = unreadCount;
  }
}

/** 源 data class Enclosure */
export class Enclosure {
  readonly present: boolean;
  readonly link: string;
  readonly name: string;
  readonly type: string;

  constructor(present: boolean = false, link: string = '', name: string = '', type: string = '') {
    this.present = present;
    this.link = link;
    this.name = name;
    this.type = type;
  }

  /** 源扩展属性 Enclosure.isImage */
  get isImage(): boolean {
    return this.type.startsWith('image/');
  }
}

/** 源 data class Article(item: FeedItemWithFeed?)：item 为 null 时各字段取默认值 */
export class Article {
  readonly item: FeedItemWithFeed | null;
  readonly id: number;
  readonly link: string | null;
  readonly feedDisplayTitle: string;
  readonly title: string;
  readonly snippet: string;
  readonly enclosure: Enclosure;
  readonly author: string | null;
  /** 原始 pub_date（Java ZonedDateTime.toString() 串） */
  readonly pubDate: string | null;
  readonly feedId: number;
  readonly feedUrl: string | null;
  readonly bookmarked: boolean;
  readonly fullTextByDefault: boolean;
  readonly wordCount: number;
  readonly wordCountFull: number;
  readonly image: ThumbnailImage | null;

  constructor(item: FeedItemWithFeed | null) {
    this.item = item;
    if (item === null) {
      this.id = ID_UNSET;
      this.link = null;
      this.feedDisplayTitle = '';
      this.title = '';
      this.snippet = '';
      this.enclosure = new Enclosure(false);
      this.author = null;
      this.pubDate = null;
      this.feedId = ID_UNSET;
      this.feedUrl = null;
      this.bookmarked = false;
      this.fullTextByDefault = false;
      this.wordCount = 0;
      this.wordCountFull = 0;
      this.image = null;
      return;
    }
    this.id = item.id;
    this.link = item.link;
    this.feedDisplayTitle = item.feedDisplayTitle;
    this.title = item.plainTitle;
    this.snippet = item.plainSnippet;
    const encLink: string | null = item.enclosureLink;
    if (encLink !== null) {
      const encName: string | null = item.enclosureFilename;
      const encType: string | null = item.enclosureType;
      this.enclosure = new Enclosure(true, encLink, encName !== null ? encName : '', encType !== null ? encType : '');
    } else {
      this.enclosure = new Enclosure(false);
    }
    this.author = item.author;
    this.pubDate = item.pubDate;
    this.feedId = item.feedId !== null ? item.feedId : ID_UNSET;
    this.feedUrl = item.feedUrl;
    this.bookmarked = item.bookmarked;
    this.fullTextByDefault = item.fullTextByDefault;
    this.wordCount = item.wordCount;
    this.wordCountFull = item.wordCountFull;
    this.image = item.thumbnailImage;
  }
}

/** 源 enum TextToDisplay */
export enum TextToDisplay {
  CONTENT = 'CONTENT',
  LOADING_FULLTEXT = 'LOADING_FULLTEXT',
  FAILED_TO_LOAD_FULLTEXT = 'FAILED_TO_LOAD_FULLTEXT',
  FAILED_MISSING_BODY = 'FAILED_MISSING_BODY',
  FAILED_MISSING_LINK = 'FAILED_MISSING_LINK',
  FAILED_NOT_HTML = 'FAILED_NOT_HTML',
  FAILED_FULLTEXT_TOO_LARGE = 'FAILED_FULLTEXT_TOO_LARGE',
}

/** 源 archmodel/Errors.kt AddFontError */
export class AddFontError {
  readonly cause: Error;

  constructor(cause: Error) {
    this.cause = cause;
  }
}

/** 源 archmodel/Errors.kt RemoveFontError */
export class RemoveFontError {
  readonly cause: Error;

  constructor(cause: Error) {
    this.cause = cause;
  }
}

/** 源 Pair<Long, String>（当前源 + 标签） */
export class FeedAndTag {
  readonly feedId: number;
  readonly tag: string;

  constructor(feedId: number, tag: string) {
    this.feedId = feedId;
    this.tag = tag;
  }
}

// ============================================================ StateFlow 等价物

/** 简单监听器集合；emit 时逐个回调（异常只记日志） */
export class Listeners<T> {
  private cbs: ((value: T) => void)[] = [];

  add(cb: (value: T) => void): () => void {
    this.cbs.push(cb);
    return () => {
      const i: number = this.cbs.indexOf(cb);
      if (i >= 0) {
        this.cbs.splice(i, 1);
      }
    };
  }

  emit(value: T): void {
    const snapshot: ((value: T) => void)[] = this.cbs.slice();
    for (const cb of snapshot) {
      try {
        cb(value);
      } catch (e) {
        console.error(`Listeners: callback failed: ${(e as Error)?.message}`);
      }
    }
  }
}

// ============================================================ Paging3 等价物

export type PageLoader<T> = (limit: number, offset: number) => Promise<T[]>;
export type PagedListCallback<T> = (items: T[], endReached: boolean) => void;

/** 源 PagingConfig 子集 */
export class PagingConfig {
  readonly pageSize: number;
  readonly initialLoadSize: number;
  readonly prefetchDistance: number;

  constructor(pageSize: number, initialLoadSize: number, prefetchDistance: number) {
    this.pageSize = pageSize;
    this.initialLoadSize = initialLoadSize;
    this.prefetchDistance = prefetchDistance;
  }
}

/**
 * limit/offset 分页列表（Room PagingSource + Pager 的等价物）：
 * - start() 首次加载 initialLoadSize 条；
 * - loadMore() 追加 pageSize 条（UI onReachEnd 调用）；onItemAccessed(i) 按 prefetchDistance 预取；
 * - 订阅表任一变更（DbNotifier）→ 以「已加载条数」重查（Room 失效后重新分页的等价物），回调新快照。
 */
export class PagedList<T> {
  private readonly loader: PageLoader<T>;
  private readonly tables: string[];
  private readonly config: PagingConfig;
  private readonly cb: PagedListCallback<T>;
  private items: T[] = [];
  private endReached: boolean = false;
  private loading: boolean = false;
  private gen: number = 0;
  private disposed: boolean = false;
  private lastAccessed: number = -1;
  private offDb: (() => void) | null = null;

  constructor(loader: PageLoader<T>, tables: string[], config: PagingConfig, cb: PagedListCallback<T>) {
    this.loader = loader;
    this.tables = tables;
    this.config = config;
    this.cb = cb;
  }

  start(): void {
    if (this.offDb !== null || this.disposed) {
      return;
    }
    this.offDb = DbNotifier.onAny(this.tables, () => {
      this.refresh();
    });
    this.fetch(this.config.initialLoadSize, 0, false);
  }

  /** 当前快照 */
  snapshot(): T[] {
    return this.items.slice();
  }

  isEndReached(): boolean {
    return this.endReached;
  }

  /** 重新加载（保持已加载条数） */
  refresh(): void {
    if (this.disposed) {
      return;
    }
    this.fetch(Math.max(this.items.length, this.config.initialLoadSize), 0, false);
  }

  loadMore(): void {
    if (this.disposed || this.loading || this.endReached) {
      return;
    }
    this.fetch(this.config.pageSize, this.items.length, true);
  }

  onItemAccessed(index: number): void {
    this.lastAccessed = Math.max(this.lastAccessed, index);
    this.maybePrefetch();
  }

  dispose(): void {
    this.disposed = true;
    if (this.offDb !== null) {
      this.offDb();
      this.offDb = null;
    }
  }

  private maybePrefetch(): void {
    if (this.lastAccessed >= 0 && this.lastAccessed + this.config.prefetchDistance >= this.items.length) {
      this.loadMore();
    }
  }

  private fetch(limit: number, offset: number, append: boolean): void {
    if (!append) {
      this.gen++;
    }
    const myGen: number = this.gen;
    this.loading = true;
    this.loader(limit, offset).then((res: T[]) => {
      if (this.disposed || myGen !== this.gen) {
        return;
      }
      this.loading = false;
      this.items = append ? this.items.concat(res) : res;
      this.endReached = res.length < limit;
      this.cb(this.items.slice(), this.endReached);
      if (append && !this.endReached) {
        this.maybePrefetch();
      }
    }).catch((e: Error) => {
      if (myGen === this.gen) {
        this.loading = false;
      }
      console.error(`PagedList: load failed: ${e?.message}`);
    });
  }
}

/**
 * flatMapLatest 的等价物：参数变化时以新 PagedList 替换旧的（旧的 dispose），对外句柄不变。
 */
export class PagedListHandle<T> {
  private current: PagedList<T> | null = null;
  private disposers: (() => void)[] = [];
  private disposed: boolean = false;

  /** 替换为新列表并启动 */
  replace(list: PagedList<T>): void {
    if (this.disposed) {
      list.dispose();
      return;
    }
    if (this.current !== null) {
      this.current.dispose();
    }
    this.current = list;
    list.start();
  }

  /** 句柄 dispose 时一并执行（如参数订阅的反订阅） */
  addDisposer(d: () => void): void {
    this.disposers.push(d);
  }

  loadMore(): void {
    if (this.current !== null) {
      this.current.loadMore();
    }
  }

  onItemAccessed(index: number): void {
    if (this.current !== null) {
      this.current.onItemAccessed(index);
    }
  }

  refresh(): void {
    if (this.current !== null) {
      this.current.refresh();
    }
  }

  snapshot(): T[] {
    return this.current !== null ? this.current.snapshot() : [];
  }

  dispose(): void {
    this.disposed = true;
    if (this.current !== null) {
      this.current.dispose();
      this.current = null;
    }
    for (const d of this.disposers) {
      d();
    }
    this.disposers = [];
  }
}

// ============================================================ 反向依赖钩子

/** 源 runOnceRssSync(di, feedId, feedTag, forceNetwork, triggeredByUser)；由 fnd-sync-engine 注册 */
export type RssSyncHook = (feedId: number, feedTag: string, forceNetwork: boolean,
  triggeredByUser: boolean) => Promise<void>;
/** 源 runOnceSyncChainSendRead(di)（内部自行判断同步链是否配置）；由 sync 切片注册 */
export type SyncChainSendReadHook = () => Promise<void>;
/** 源 syncClient.isConfigured；由 sync 切片注册 */
export type SyncChainConfiguredHook = () => boolean;
/** 源 addDynamicShortcutToFeed + reportShortcutToFeedUsed；由 fnd-platform 注册 */
export type AddShortcutHook = (feedId: number, label: string) => Promise<void>;
/** 源 AndroidSystemStore.removeDynamicShortcuts；由 fnd-platform 注册 */
export type RemoveShortcutsHook = (feedIds: number[]) => void;

class PendingRssSync {
  feedId: number = ID_UNSET;
  feedTag: string = '';
  forceNetwork: boolean = false;
  triggeredByUser: boolean = false;
}

/** 钩子注册表（模块级单例） */
export class RepositoryHooks {
  private static rssSync: RssSyncHook | null = null;
  private static pendingRss: PendingRssSync[] = [];
  private static sendRead: SyncChainSendReadHook | null = null;
  private static configured: SyncChainConfiguredHook | null = null;
  private static addShortcut: AddShortcutHook | null = null;
  private static removeShortcuts: RemoveShortcutsHook | null = null;

  /** 注册后立即补发注册前排队的同步请求（首启 Feeder News 可能早于同步引擎就绪） */
  static setRssSyncHook(cb: RssSyncHook | null): void {
    RepositoryHooks.rssSync = cb;
    if (cb !== null && RepositoryHooks.pendingRss.length > 0) {
      const pending: PendingRssSync[] = RepositoryHooks.pendingRss;
      RepositoryHooks.pendingRss = [];
      for (const p of pending) {
        RepositoryHooks.runOnceRssSync(p.feedId, p.feedTag, p.forceNetwork, p.triggeredByUser);
      }
    }
  }

  static setSyncChainSendReadHook(cb: SyncChainSendReadHook | null): void {
    RepositoryHooks.sendRead = cb;
  }

  static setSyncChainConfiguredHook(cb: SyncChainConfiguredHook | null): void {
    RepositoryHooks.configured = cb;
  }

  static setShortcutHooks(add: AddShortcutHook | null, remove: RemoveShortcutsHook | null): void {
    RepositoryHooks.addShortcut = add;
    RepositoryHooks.removeShortcuts = remove;
  }

  static runOnceRssSync(feedId: number, feedTag: string, forceNetwork: boolean, triggeredByUser: boolean): void {
    const cb: RssSyncHook | null = RepositoryHooks.rssSync;
    if (cb === null) {
      const p: PendingRssSync = new PendingRssSync();
      p.feedId = feedId;
      p.feedTag = feedTag;
      p.forceNetwork = forceNetwork;
      p.triggeredByUser = triggeredByUser;
      RepositoryHooks.pendingRss.push(p);
      return;
    }
    try {
      cb(feedId, feedTag, forceNetwork, triggeredByUser).catch((e: Error) => {
        console.error(`RepositoryHooks: rss sync failed: ${e?.message}`);
      });
    } catch (e) {
      console.error(`RepositoryHooks: rss sync threw: ${(e as Error)?.message}`);
    }
  }

  static isSyncChainConfigured(): boolean {
    const cb: SyncChainConfiguredHook | null = RepositoryHooks.configured;
    if (cb === null) {
      return false;
    }
    try {
      return cb();
    } catch (e) {
      return false;
    }
  }

  /** 源 runOnceSyncChainSendRead：未配置同步链直接返回 */
  static runOnceSyncChainSendRead(): void {
    const cb: SyncChainSendReadHook | null = RepositoryHooks.sendRead;
    if (cb === null || !RepositoryHooks.isSyncChainConfigured()) {
      return;
    }
    try {
      cb().catch((e: Error) => {
        console.error(`RepositoryHooks: send read failed: ${e?.message}`);
      });
    } catch (e) {
      console.error(`RepositoryHooks: send read threw: ${(e as Error)?.message}`);
    }
  }

  static addDynamicShortcutToFeed(feedId: number, label: string): void {
    const cb: AddShortcutHook | null = RepositoryHooks.addShortcut;
    if (cb === null) {
      return;
    }
    try {
      cb(feedId, label).catch((e: Error) => {
        console.error(`RepositoryHooks: add shortcut failed: ${e?.message}`);
      });
    } catch (e) {
      console.error(`RepositoryHooks: add shortcut threw: ${(e as Error)?.message}`);
    }
  }

  static removeDynamicShortcuts(feedIds: number[]): void {
    const cb: RemoveShortcutsHook | null = RepositoryHooks.removeShortcuts;
    if (cb === null) {
      return;
    }
    try {
      cb(feedIds);
    } catch (e) {
      console.error(`RepositoryHooks: remove shortcuts threw: ${(e as Error)?.message}`);
    }
  }
}
