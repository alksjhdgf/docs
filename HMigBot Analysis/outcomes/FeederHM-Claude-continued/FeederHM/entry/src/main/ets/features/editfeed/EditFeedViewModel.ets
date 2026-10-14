/**
 * EditFeedViewModel —— 源 ui/compose/editfeed/{EditFeedScreen.kt#EditFeedScreenState, CreateFeedScreenViewModel.kt,
 * EditFeedScreenViewModel.kt}。
 *
 *  - EditFeedViewModel：表单状态（源 EditFeedScreenState），字段照源 mutableSavedStateOf 语义写入 SavedStateHandle
 *    （键名=源属性名），进程重建经 SavedStateRegistry 恢复（EF-A42）；URL 每次写入重算 isNotValidUrl/isOkToSave
 *    （源 isValidUrlOrUri = `URL(value)` 不抛），规则每次写入重算首个错误（EF-A31，不阻断保存）。
 *  - CreateFeedViewModel（EF-A24/A35）：导航参数 feedUrl/feedTitle 作为 SavedState 初值；defaultTitle=feedTitle 参数；
 *    保存 → 新建 Feed（title=customTitle=Title 框，whenModified=now，imageUrl=sloppyLinkToStrictURLOrNull(feedImage)）
 *    → 非用户触发的一次性同步 → action(feedId)。
 *  - EditFeedScreenViewModel（EF-A41/A43）：按 feedId 读库预填（SavedState 已有的键不覆盖）；保存 → 以表单值覆盖，
 *    与原记录完全相同则不写库不同步；否则 whenModified=max(now, 原值+1ms) 后写库并同步；action(原 feed.id)。
 */
import { AddFeedParam } from '../../core/app/RouteParams';
import { ID_UNSET } from '../../core/model/Enums';
import { Feed } from '../../core/model/Feed';
import { PREF_VAL_OPEN_WITH_BROWSER, PREF_VAL_OPEN_WITH_CUSTOM_TAB, PREF_VAL_OPEN_WITH_READER,
  PREF_VAL_OPEN_WITH_WEBVIEW } from '../../core/settings/SettingsKeys';
import { SavedStateHandle, SavedStateRegistry } from '../../core/platform/LayoutAdapt';
import { ArticleRuleError, ArticleRuleSet } from '../../core/sync/ArticleFilterRules';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { Repository } from '../../core/repo/Repository';
import { JavaUrl } from '../../core/util/JavaUrl';
import { sloppyLinkToStrictURLOrNull } from '../../core/util/LinkUtils';

const LOG_TAG: string = 'EditFeedViewModel';

/** SavedStateHandle 键（逐字照源属性名） */
export const KEY_FEED_URL: string = 'feedUrl';
export const KEY_FEED_TITLE: string = 'feedTitle';
export const KEY_FEED_TAG: string = 'feedTag';
export const KEY_FULL_TEXT_BY_DEFAULT: string = 'fullTextByDefault';
export const KEY_SKIP_DUPLICATES: string = 'skipDuplicates';
export const KEY_NOTIFY: string = 'notify';
export const KEY_ARTICLE_OPENER: string = 'articleOpener';
export const KEY_ALTERNATE_ID: string = 'alternateId';
export const KEY_SUMMARIZE_ON_OPEN: string = 'summarizeOnOpen';
export const KEY_FETCH_OG_IMAGES: string = 'fetchOgImages';
export const KEY_BLOCK_RULES: string = 'blockRules';
export const KEY_ALLOW_RULES: string = 'allowRules';

/** 源 isValidUrlOrUri：`URL(value)` 不抛即合法（java.net.URL 语义，缺协议/未知协议/空串均非法） */
export function isValidUrlOrUri(value: string): boolean {
  try {
    JavaUrl.parse(value);
    return true;
  } catch (e) {
    return false;
  }
}

/** 源 ArticleRuleSet.parse(value).errors.firstOrNull() */
export function firstRuleError(text: string): ArticleRuleError | null {
  const errors: ArticleRuleError[] = ArticleRuleSet.parse(text).errors;
  return errors.length > 0 ? errors[0] : null;
}

/** 源 LeftContent.filteredTags：非空白且以当前输入开头（忽略大小写）；顺序沿用 allTags（库内 NOCASE 排序） */
export function filterTagSuggestions(allTags: string[], typed: string): string[] {
  const prefix: string = typed.toLowerCase();
  return allTags.filter((tag: string): boolean => tag.trim().length > 0 && tag.toLowerCase().startsWith(prefix));
}

/** java.net.URL 相等（Android：主机名忽略大小写，不做 DNS）；任一不可解析时退化为字符串相等 */
function sameUrl(a: string, b: string): boolean {
  try {
    return JavaUrl.parse(a).equals(JavaUrl.parse(b));
  } catch (e) {
    return a === b;
  }
}

/** Kotlin data class Feed.equals 等价（全部字段） */
export function feedsEqual(a: Feed, b: Feed): boolean {
  return a.id === b.id && a.title === b.title && a.customTitle === b.customTitle && sameUrl(a.url, b.url) &&
    a.tag === b.tag && a.notify === b.notify && a.imageUrl === b.imageUrl && a.lastSync === b.lastSync &&
    a.responseHash === b.responseHash && a.fullTextByDefault === b.fullTextByDefault &&
    a.openArticlesWith === b.openArticlesWith && a.alternateId === b.alternateId &&
    a.currentlySyncing === b.currentlySyncing && a.whenModified === b.whenModified &&
    a.siteFetched === b.siteFetched && a.skipDuplicates === b.skipDuplicates && a.retryAfter === b.retryAfter &&
    a.summarizeOnOpen === b.summarizeOnOpen && a.fetchOgImages === b.fetchOgImages &&
    a.blockRules === b.blockRules && a.allowRules === b.allowRules;
}

/** 源 runOnceRssSync(di, feedId, triggeredByUser = false)：不等待同步完成 */
function requestFeedSync(feedId: number): void {
  SyncScheduler.runOnceRssSync(feedId, '', false, false).catch((e: Error) => {
    console.error(`${LOG_TAG}: runOnceRssSync(${feedId}) failed: ${e?.message}`);
  });
}

@ObservedV2
export class EditFeedViewModel {
  protected readonly state: SavedStateHandle;
  private readonly scope: string;
  private tagsUnsubscribe: (() => void) | null = null;

  @Trace feedUrl: string = '';
  @Trace feedTitle: string = '';
  @Trace feedTag: string = '';
  @Trace fullTextByDefault: boolean = false;
  @Trace notify: boolean = false;
  @Trace skipDuplicates: boolean = false;
  @Trace articleOpener: string = '';
  @Trace alternateId: boolean = false;
  @Trace summarizeOnOpen: boolean = false;
  @Trace fetchOgImages: boolean = false;
  @Trace blockRules: string = '';
  @Trace allowRules: string = '';

  @Trace isNotValidUrl: boolean = false;
  @Trace isOkToSave: boolean = false;
  @Trace blockRulesError: ArticleRuleError | null = null;
  @Trace allowRulesError: ArticleRuleError | null = null;
  @Trace allTags: string[] = [];
  @Trace defaultTitle: string = '';
  @Trace feedImage: string = '';
  /** 保存进行中（防重复点击 OK 造成重复插入） */
  @Trace saving: boolean = false;

  /** scope 为空串时不登记到 SavedStateRegistry（组件 @Param 默认值用） */
  constructor(scope: string = '') {
    this.scope = scope;
    this.state = scope.length > 0 ? SavedStateRegistry.handle(scope) : new SavedStateHandle();
  }

  // ------------------------------------------------------------ 派生状态（源 isOpenItemWith*）
  @Computed
  get isOpenItemWithBrowser(): boolean {
    return this.articleOpener === PREF_VAL_OPEN_WITH_BROWSER;
  }

  @Computed
  get isOpenItemWithCustomTab(): boolean {
    return this.articleOpener === PREF_VAL_OPEN_WITH_CUSTOM_TAB;
  }

  @Computed
  get isOpenItemWithReader(): boolean {
    return this.articleOpener === PREF_VAL_OPEN_WITH_READER;
  }

  /** 存量 `1`（WebView）时四项均不选中（EF-A29） */
  @Computed
  get isOpenItemWithAppDefault(): boolean {
    const v: string = this.articleOpener;
    return v !== PREF_VAL_OPEN_WITH_READER && v !== PREF_VAL_OPEN_WITH_WEBVIEW && v !== PREF_VAL_OPEN_WITH_BROWSER &&
      v !== PREF_VAL_OPEN_WITH_CUSTOM_TAB;
  }

  @Computed
  get filteredTags(): string[] {
    return filterTagSuggestions(this.allTags, this.feedTag);
  }

  // ------------------------------------------------------------ 写入（源 mutableSavedStateOf setter：写 handle + onChange）
  setFeedUrl(value: string): void {
    this.feedUrl = value;
    this.state.set(KEY_FEED_URL, value);
    this.onFeedUrlChanged(value);
  }

  setFeedTitle(value: string): void {
    this.feedTitle = value;
    this.state.set(KEY_FEED_TITLE, value);
  }

  setFeedTag(value: string): void {
    this.feedTag = value;
    this.state.set(KEY_FEED_TAG, value);
  }

  setFullTextByDefault(value: boolean): void {
    this.fullTextByDefault = value;
    this.state.set(KEY_FULL_TEXT_BY_DEFAULT, value);
  }

  /** 原始写入；权限流程由界面层负责（源 EditFeedScreen 的 screenState 包装） */
  setNotify(value: boolean): void {
    this.notify = value;
    this.state.set(KEY_NOTIFY, value);
  }

  setSkipDuplicates(value: boolean): void {
    this.skipDuplicates = value;
    this.state.set(KEY_SKIP_DUPLICATES, value);
  }

  setArticleOpener(value: string): void {
    this.articleOpener = value;
    this.state.set(KEY_ARTICLE_OPENER, value);
  }

  setAlternateId(value: boolean): void {
    this.alternateId = value;
    this.state.set(KEY_ALTERNATE_ID, value);
  }

  setSummarizeOnOpen(value: boolean): void {
    this.summarizeOnOpen = value;
    this.state.set(KEY_SUMMARIZE_ON_OPEN, value);
  }

  setFetchOgImages(value: boolean): void {
    this.fetchOgImages = value;
    this.state.set(KEY_FETCH_OG_IMAGES, value);
  }

  setBlockRules(value: string): void {
    this.blockRules = value;
    this.state.set(KEY_BLOCK_RULES, value);
    this.blockRulesError = firstRuleError(value);
  }

  setAllowRules(value: string): void {
    this.allowRules = value;
    this.state.set(KEY_ALLOW_RULES, value);
    this.allowRulesError = firstRuleError(value);
  }

  private onFeedUrlChanged(value: string): void {
    const valid: boolean = isValidUrlOrUri(value);
    this.isNotValidUrl = !valid;
    this.isOkToSave = valid;
  }

  // ------------------------------------------------------------ 初始化 / 释放

  /** 源 DelegatedMutableSavedState 首次读取：handle 有值用之，否则默认值；随后触发 onChange */
  protected restoreSavedState(): void {
    this.feedUrl = this.savedString(KEY_FEED_URL, '');
    this.feedTitle = this.savedString(KEY_FEED_TITLE, '');
    this.feedTag = this.savedString(KEY_FEED_TAG, '');
    this.fullTextByDefault = this.savedBoolean(KEY_FULL_TEXT_BY_DEFAULT, false);
    this.skipDuplicates = this.savedBoolean(KEY_SKIP_DUPLICATES, false);
    this.notify = this.savedBoolean(KEY_NOTIFY, false);
    this.articleOpener = this.savedString(KEY_ARTICLE_OPENER, '');
    this.alternateId = this.savedBoolean(KEY_ALTERNATE_ID, false);
    this.summarizeOnOpen = this.savedBoolean(KEY_SUMMARIZE_ON_OPEN, false);
    this.fetchOgImages = this.savedBoolean(KEY_FETCH_OG_IMAGES, false);
    this.blockRules = this.savedString(KEY_BLOCK_RULES, '');
    this.allowRules = this.savedString(KEY_ALLOW_RULES, '');
    this.onFeedUrlChanged(this.feedUrl);
    this.blockRulesError = firstRuleError(this.blockRules);
    this.allowRulesError = firstRuleError(this.allowRules);
  }

  protected savedString(key: string, fallback: string): string {
    const v: Object | undefined = this.state.get(key);
    return typeof v === 'string' ? v as string : fallback;
  }

  protected savedBoolean(key: string, fallback: boolean): boolean {
    const v: Object | undefined = this.state.get(key);
    return typeof v === 'boolean' ? v as boolean : fallback;
  }

  /** 源 repository.allTags.collect { allTags = it } */
  protected subscribeTags(): void {
    if (this.tagsUnsubscribe !== null) {
      return;
    }
    this.tagsUnsubscribe = Repository.instance().observeAllTags((tags: string[]) => {
      this.allTags = tags;
    });
  }

  /** 页面离开（出栈）时调用：反订阅并丢弃 SavedState（源 ViewModel.onCleared） */
  dispose(): void {
    const unsub: (() => void) | null = this.tagsUnsubscribe;
    this.tagsUnsubscribe = null;
    if (unsub !== null) {
      unsub();
    }
    if (this.scope.length > 0) {
      SavedStateRegistry.clear(this.scope);
    }
  }

  /** 表单当前值覆盖到 feed（源 Feed(...) / feed.copy(...) 的共同字段） */
  protected applyFormTo(feed: Feed): void {
    feed.url = JavaUrl.parse(this.feedUrl).toString();
    feed.title = this.feedTitle;
    feed.customTitle = this.feedTitle;
    feed.tag = this.feedTag;
    feed.fullTextByDefault = this.fullTextByDefault;
    feed.notify = this.notify;
    feed.skipDuplicates = this.skipDuplicates;
    feed.openArticlesWith = this.articleOpener;
    feed.alternateId = this.alternateId;
    feed.summarizeOnOpen = this.summarizeOnOpen;
    feed.fetchOgImages = this.fetchOgImages;
    feed.blockRules = this.blockRules;
    feed.allowRules = this.allowRules;
  }

  /** 子类实现；基类不保存 */
  async saveAndRequestSync(action: (feedId: number) => void): Promise<void> {
    console.warn(`${LOG_TAG}: saveAndRequestSync on base view model ignored`);
  }

  /** 防重入包装：保存期间重复点击 OK 忽略 */
  protected async guarded(work: () => Promise<void>): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await work();
    } catch (e) {
      console.error(`${LOG_TAG}: save failed: ${(e as Error)?.message}`);
    } finally {
      this.saving = false;
    }
  }
}

/** 源 CreateFeedScreenViewModel（AddFeed 页） */
@ObservedV2
export class CreateFeedViewModel extends EditFeedViewModel {
  constructor(param: AddFeedParam) {
    super(`AddFeed:${param.feedUrl}`);
    // 导航参数即 SavedStateHandle 初值（源 add/feed/{feedUrl}?feedTitle=&feedImage=）
    if (!this.state.contains(KEY_FEED_URL)) {
      this.state.set(KEY_FEED_URL, param.feedUrl);
    }
    if (!this.state.contains(KEY_FEED_TITLE)) {
      this.state.set(KEY_FEED_TITLE, param.feedTitle);
    }
    this.defaultTitle = param.feedTitle;
    this.feedImage = param.feedImage;
    this.restoreSavedState();
    this.subscribeTags();
  }

  /** EF-A35 */
  async saveAndRequestSync(action: (feedId: number) => void): Promise<void> {
    await this.guarded(async (): Promise<void> => {
      const feed: Feed = new Feed();
      this.applyFormTo(feed);
      feed.whenModified = Date.now();
      let image: JavaUrl | null = null;
      try {
        image = sloppyLinkToStrictURLOrNull(this.feedImage);
      } catch (e) {
        image = null;
      }
      feed.imageUrl = image !== null ? image.toString() : null;
      const feedId: number = await Repository.instance().saveFeed(feed);
      requestFeedSync(feedId);
      action(feedId);
    });
  }
}

/** 源 EditFeedScreenViewModel（EditFeed 页） */
@ObservedV2
export class EditFeedScreenViewModel extends EditFeedViewModel {
  readonly feedId: number;
  /** 读库完成 */
  @Trace loaded: boolean = false;
  /** feedId 对应订阅源不存在（源抛 IllegalArgumentException；此处显示空态） */
  @Trace missing: boolean = false;

  constructor(feedId: number) {
    super(`EditFeed:${feedId}`);
    this.feedId = feedId;
    this.restoreSavedState();
  }

  /** EF-A41/A42：读库预填；SavedState 中已有的键（已编辑未保存）不覆盖 */
  async load(): Promise<void> {
    let feed: Feed | null = null;
    try {
      feed = await Repository.instance().getFeed(this.feedId);
    } catch (e) {
      console.error(`${LOG_TAG}: getFeed(${this.feedId}) failed: ${(e as Error)?.message}`);
    }
    if (feed === null) {
      this.missing = true;
      return;
    }
    const f: Feed = feed;
    this.defaultTitle = f.title;
    this.feedImage = f.imageUrl !== null ? f.imageUrl : '';
    if (!this.state.contains(KEY_FEED_URL)) {
      this.setFeedUrl(f.url);
    }
    if (!this.state.contains(KEY_FEED_TAG)) {
      this.setFeedTag(f.tag);
    }
    if (!this.state.contains(KEY_FEED_TITLE)) {
      this.setFeedTitle(f.displayTitle);
    }
    if (!this.state.contains(KEY_FULL_TEXT_BY_DEFAULT)) {
      this.setFullTextByDefault(f.fullTextByDefault);
    }
    if (!this.state.contains(KEY_NOTIFY)) {
      this.setNotify(f.notify);
    }
    if (!this.state.contains(KEY_SKIP_DUPLICATES)) {
      this.setSkipDuplicates(f.skipDuplicates);
    }
    if (!this.state.contains(KEY_ARTICLE_OPENER)) {
      this.setArticleOpener(f.openArticlesWith);
    }
    if (!this.state.contains(KEY_ALTERNATE_ID)) {
      this.setAlternateId(f.alternateId);
    }
    if (!this.state.contains(KEY_SUMMARIZE_ON_OPEN)) {
      this.setSummarizeOnOpen(f.summarizeOnOpen);
    }
    if (!this.state.contains(KEY_FETCH_OG_IMAGES)) {
      this.setFetchOgImages(f.fetchOgImages);
    }
    if (!this.state.contains(KEY_BLOCK_RULES)) {
      this.setBlockRules(f.blockRules);
    }
    if (!this.state.contains(KEY_ALLOW_RULES)) {
      this.setAllowRules(f.allowRules);
    }
    this.loaded = true;
    this.subscribeTags();
  }

  /** EF-A43 */
  async saveAndRequestSync(action: (feedId: number) => void): Promise<void> {
    await this.guarded(async (): Promise<void> => {
      const repo: Repository = Repository.instance();
      const existing: Feed | null = await repo.getFeed(this.feedId);
      // Feed was deleted while being edited?
      const feed: Feed = existing !== null ? existing : new Feed();
      const updatedFeed: Feed = feed.copy();
      this.applyFormTo(updatedFeed);
      // No point in doing anything unless they actually differ
      if (!feedsEqual(feed, updatedFeed)) {
        // In case clocks between different devices differ don't allow this date to go backwards
        updatedFeed.whenModified = Math.max(Date.now(), feed.whenModified + 1);
        const savedId: number = await repo.saveFeed(updatedFeed);
        requestFeedSync(savedId);
      }
      action(feed.id);
    });
  }
}

/** 页面判空用：编辑页 feedId 是否有效 */
export function isValidFeedId(feedId: number): boolean {
  return feedId !== ID_UNSET;
}
