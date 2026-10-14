/**
 * ArticleViewModel —— 源 ui/compose/feedarticle/ArticleViewModel.kt（+ ArticleScreen.kt 有状态入口的回调接线）。
 *
 * Flow/StateFlow → @ObservedV2/@Trace：
 *  - articleFlow = Repository.observeArticle(itemId)（DbNotifier 驱动，收藏/已读变化即刷新菜单文案，AR-A11）；
 *  - articleContentFlow = parseArticleContent(article, override ?: fullTextByDefault)（AR-A19/A20/A22）；
 *  - 翻译状态机委托 features/translation ArticleTranslationController（TR-A33..A45；AR-A10/A38..A43）；
 *  - AI 摘要委托 features/openai AiSummaryController（AR-A09/A37/A43）；
 *  - 朗读/播客委托 features/readaloud（ReadAloudActions / PodcastLinks，AR-A31/A44/A45）；
 *  - SavedStateHandle（scrollPosition / toolbarMenuVisible）→ SavedStateRegistry 作用域句柄（AR-A48）。
 * 进入页面：DeepLinkRouter.onEnterArticle(itemId)（标记已读+已通知、pref_last_article_id、pref_is_article_open，AR-A03/A04）。
 * 不存在上一篇/下一篇（AR-A50）：本 VM 不提供任何相邻文章导航。
 */
import { DeepLinkRouter } from '../../core/app/DeepLinkRouter';
import { ID_UNSET } from '../../core/model/Enums';
import { FeedItemWithFeed } from '../../core/model/FeedItem';
import { ActivityLauncher } from '../../core/platform/LinkOpener';
import { SavedStateHandle, SavedStateRegistry } from '../../core/platform/LayoutAdapt';
import { Article, Enclosure, TextToDisplay } from '../../core/repo/RepoTypes';
import { Repository } from '../../core/repo/Repository';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { LinearArticle } from '../../core/html/LinearArticle';
import {
  ArticleAnchors, ArticleLinkAction, ArticleLinkOptions, handleArticleLinkClick, toolbarColorOfTheme
} from '../../ui/common/ArticleLinks';
import {
  ArticleTranslationController, ArticleTranslationSubject
} from '../translation/ArticleTranslationController';
import { ArticleTranslation, TranslationManager } from '../translation/TranslationManager';
import { AiSummaryController, showSummarize } from '../openai/AiSummary';
import { ArticleTtsRequest, ReadAloudActions } from '../readaloud/ReadAloudActions';
import { onEnclosureClick, openPodcastPlayer, podcastLinkOptions } from '../readaloud/PodcastLinks';
import {
  formatArticleDate, loadArticleHtml, loadArticleHtmlForLanguageDetection, newArticleLinearizer, parseArticleContent,
  ParsedArticleContent, shareArticle
} from './ArticleContentLoader';

const LOG_TAG: string = 'FEEDER_ArticleVM';
const KEY_SCROLL_POSITION: string = 'scrollPosition';
const KEY_TOOLBAR_MENU_VISIBLE: string = 'toolbarMenuVisible';

/** 源 wordsToReadTimeSecs(words) = round(words * 60 / 220.0)（AR-A28） */
export function wordsToReadTimeSecs(words: number): number {
  return Math.round(words * 60 / 220.0);
}

/** 源 shouldShowHeaderImage(showHeaderImage, image, contentImageUrls)（ReaderView.kt:395，AR-A33） */
export function shouldShowHeaderImage(showHeaderImage: boolean, imageUrl: string | null, imageFromBody: boolean,
  contentImageUrls: Set<string>): boolean {
  return showHeaderImage && imageUrl !== null && !imageFromBody && !contentImageUrls.has(imageUrl);
}

/** 源 ReaderView.kt:304-315：宽度已知且 < 640 → 不显示；未知或 ≥ 640 → 显示（AR-A33） */
export function isHeaderImageWideEnough(width: number | null): boolean {
  return width === null || width >= 640;
}

@ObservedV2
export class ArticleViewModel {
  /** 源 itemId（导航参数）；viewState.articleId 立即为此值 */
  @Trace itemId: number = ID_UNSET;
  /** 源 viewState.articleId：初值 ID_UNSET，start 后为 itemId（AR-A23：未就绪不渲染正文区） */
  @Trace articleId: number = ID_UNSET;
  @Trace article: Article = new Article(null);
  @Trace textToDisplay: TextToDisplay = TextToDisplay.CONTENT;
  @Trace articleContent: LinearArticle = new LinearArticle([]);
  @Trace translatedArticleContent: LinearArticle = new LinearArticle([]);
  @Trace displayFullTextOverride: boolean | null = null;
  @Trace showToolbarMenu: boolean = false;
  @Trace translation: ArticleTranslationController;
  readonly summary: AiSummaryController = new AiSummaryController();
  /** 阅读区滚动控制器（源 articleScrollState）；锚点表与之共享 */
  readonly scroller: Scroller = new Scroller();
  readonly anchors: ArticleAnchors;

  private saved: SavedStateHandle = new SavedStateHandle();
  private unsubscribeArticle: (() => void) | null = null;
  private parseGeneration: number = 0;
  private lastContentKey: string = '';
  private handledInitialOpenActions: boolean = false;
  private disposed: boolean = false;

  constructor() {
    this.anchors = new ArticleAnchors(this.scroller);
    this.translation = new ArticleTranslationController(
      (subject: ArticleTranslationSubject, fullText: boolean): Promise<string> =>
      loadArticleHtml(subject.itemId, this.article.snippet, fullText),
      (subject: ArticleTranslationSubject, fullText: boolean): Promise<string | null> =>
      loadArticleHtmlForLanguageDetection(subject.itemId, this.article.snippet, fullText)
    );
  }

  // ================================================================ 生命周期

  /** 页面拿到参数后调用（AppBootstrap.ready 之后） */
  start(itemId: number): void {
    if (this.itemId === itemId && this.unsubscribeArticle !== null) {
      return;
    }
    this.stopObserving();
    this.itemId = itemId;
    this.articleId = itemId;
    this.saved = SavedStateRegistry.handle(`ArticleViewModel.${itemId}`);
    const menu: Object | undefined = this.saved.get(KEY_TOOLBAR_MENU_VISIBLE);
    this.showToolbarMenu = typeof menu === 'boolean' && (menu as boolean);
    this.translation.start();
    // 源 NavigationDeepLinkViewModel.setCurrentArticle（AR-A03/A04）
    DeepLinkRouter.onEnterArticle(itemId).catch((e: Error) => {
      console.error(`${LOG_TAG}: onEnterArticle failed: ${e?.message}`);
    });
    this.unsubscribeArticle = Repository.instance().observeArticle(itemId, (article: Article) => {
      this.onArticle(article);
    });
  }

  dispose(): void {
    this.disposed = true;
    this.stopObserving();
    this.translation.stop();
  }

  private stopObserving(): void {
    const off: (() => void) | null = this.unsubscribeArticle;
    this.unsubscribeArticle = null;
    if (off !== null) {
      off();
    }
  }

  private onArticle(article: Article): void {
    if (this.disposed) {
      return;
    }
    this.article = article;
    const fullText: boolean = this.isFullText;
    // 源 combine(articleFlow, displayFullTextOverride, …)：模式变化且在显示译文 → 重新翻译；语言检测随文章刷新
    this.translation.setFullText(fullText);
    this.translation.attach(this.translationSubject(), fullText);
    this.refreshContent(false);
    this.handleInitialOpenActions();
  }

  /** 源 init { articleFlow.collect { … handledInitialOpenActions … } }（AR-A43） */
  private handleInitialOpenActions(): void {
    const item: FeedItemWithFeed | null = this.article.item;
    if (item === null || item.feedId === null || this.handledInitialOpenActions) {
      return;
    }
    this.handledInitialOpenActions = true;
    const a: Article = this.article;
    this.summary.summarizeOnOpenIfEnabled(a.feedId, this.itemId, a.link, a.feedUrl).catch((e: Error) => {
      console.error(`${LOG_TAG}: summarizeOnOpen failed: ${e?.message}`);
    });
    this.translation.autoTranslateOnOpen().catch((e: Error) => {
      console.error(`${LOG_TAG}: autoTranslateOnOpen failed: ${e?.message}`);
    });
  }

  private translationSubject(): ArticleTranslationSubject {
    const s: ArticleTranslationSubject = new ArticleTranslationSubject();
    s.itemId = this.itemId;
    s.title = this.article.title;
    s.link = this.article.link;
    s.fullTextByDefault = this.article.fullTextByDefault;
    return s;
  }

  // ================================================================ 正文（articleContentFlow）

  private contentKey(): string {
    const a: Article = this.article;
    return `${a.id}|${this.isFullText}|${a.feedUrl}|${a.link}|${a.snippet}|${a.wordCount}|${a.wordCountFull}`;
  }

  /** 源 combine(articleFlow, displayFullTextOverride).filterNotNull().map(parseArticleContent) */
  private refreshContent(force: boolean): void {
    if (this.article.item === null) {
      return;
    }
    const key: string = this.contentKey();
    if (!force && key === this.lastContentKey) {
      return;
    }
    this.lastContentKey = key;
    const gen: number = ++this.parseGeneration;
    const article: Article = this.article;
    const fullText: boolean = this.isFullText;
    parseArticleContent(article, fullText).then((r: ParsedArticleContent) => {
      if (gen !== this.parseGeneration || this.disposed) {
        return;
      }
      if (r.textToDisplay !== null) {
        this.textToDisplay = r.textToDisplay as TextToDisplay;
      }
      this.articleContent = r.content;
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: parseArticleContent failed: ${e?.message}`);
    });
  }

  /** 译文 HTML → 线性化正文（源 translateCurrentArticle 成功分支 / 清空分支） */
  @Monitor('translation.translatedHtml')
  onTranslatedHtmlChanged(monitor: IMonitor): void {
    const html: string = this.translation.translatedHtml;
    if (html.length === 0) {
      this.translatedArticleContent = new LinearArticle([]);
      return;
    }
    try {
      const baseUrl: string = this.article.feedUrl !== null ? this.article.feedUrl as string : '';
      this.translatedArticleContent = newArticleLinearizer(this.article.link).linearize(html, baseUrl);
    } catch (e) {
      console.error(`${LOG_TAG}: linearize translation failed: ${(e as Error)?.message}`);
      this.translatedArticleContent = new LinearArticle([]);
    }
  }

  // ================================================================ 派生视图状态（源 viewState combine）

  /** 源 isFullText = displayFullTextOverride ?: article.fullTextByDefault ?: false */
  get isFullText(): boolean {
    const o: boolean | null = this.displayFullTextOverride;
    return o !== null ? o as boolean : this.article.fullTextByDefault;
  }

  get feedDisplayTitle(): string {
    return this.article.feedDisplayTitle;
  }

  get isBookmarked(): boolean {
    return this.article.bookmarked;
  }

  get isShowingTranslated(): boolean {
    return this.translation.isShowingTranslated();
  }

  /** 显示译文时为译文标题，否则 plainTitle */
  get articleTitle(): string {
    return this.translation.displayTitle(this.article.title);
  }

  get displayedContent(): LinearArticle {
    return this.isShowingTranslated ? this.translatedArticleContent : this.articleContent;
  }

  /** 源 wordCount = isFullText ? wordCountFull : wordCount */
  get wordCount(): number {
    return this.isFullText ? this.article.wordCountFull : this.article.wordCount;
  }

  get readTimeSecs(): number {
    return wordsToReadTimeSecs(this.wordCount);
  }

  get showSummarize(): boolean {
    return showSummarize(Repository.instance().openAISettings, this.article.link);
  }

  get showTranslate(): boolean {
    return this.translation.showTranslate();
  }

  get translateMenuLabel(): string {
    return this.translation.menuLabel();
  }

  get isTranslationLoading(): boolean {
    return this.translation.isTranslationLoading();
  }

  get useInAppAudioPlayer(): boolean {
    return SettingsStore.instance().state.useInAppAudioPlayer;
  }

  get isPagingMode(): boolean {
    return SettingsStore.instance().state.isPagingMode;
  }

  get isAnimatedPaging(): boolean {
    return SettingsStore.instance().state.isAnimatedPaging;
  }

  get enclosure(): Enclosure {
    return this.article.enclosure;
  }

  /** 格式化后的发布日期；无发布日期 → null（AR-A26/A27） */
  get formattedPubDate(): string | null {
    return formatArticleDate(this.article.pubDate);
  }

  /** 头图显示判定（AR-A33）：CONTENT、非取自正文、URL 不在正文、宽度未知或 ≥640 */
  get showHeaderImage(): boolean {
    const img = this.article.image;
    if (img === null) {
      return false;
    }
    return shouldShowHeaderImage(this.textToDisplay === TextToDisplay.CONTENT, img.url, img.fromBody,
      this.displayedContent.imageUrls) && isHeaderImageWideEnough(img.width);
  }

  get headerImageUrl(): string {
    const img = this.article.image;
    return img !== null ? img.url : '';
  }

  // ================================================================ 保存状态（AR-A48）

  get scrollPosition(): number {
    const v: Object | undefined = this.saved.get(KEY_SCROLL_POSITION);
    return typeof v === 'number' ? v as number : 0;
  }

  saveScrollPosition(pos: number): void {
    this.saved.set(KEY_SCROLL_POSITION, pos);
  }

  setToolbarMenuVisible(visible: boolean): void {
    this.saved.set(KEY_TOOLBAR_MENU_VISIBLE, visible);
    this.showToolbarMenu = visible;
  }

  // ================================================================ 动作

  /** 源 toggleFullText（AR-A19/A42） */
  toggleFullText(): void {
    // Using as general loading text
    this.textToDisplay = TextToDisplay.LOADING_FULLTEXT;
    const o: boolean | null = this.displayFullTextOverride;
    if (o !== null) {
      this.displayFullTextOverride = !(o as boolean);
    } else if (this.article.item !== null) {
      this.displayFullTextOverride = !this.article.fullTextByDefault;
    } else {
      this.displayFullTextOverride = true;
    }
    this.translation.setFullText(this.isFullText);
    this.refreshContent(true);
  }

  /** 源 markAsUnread（applicationCoroutineScope：不随页面取消，AR-A13） */
  markAsUnread(): void {
    Repository.instance().markAsUnread(this.itemId).catch((e: Error) => {
      console.error(`${LOG_TAG}: markAsUnread failed: ${e?.message}`);
    });
  }

  /** 源 setBookmarked（applicationCoroutineScope，AR-A12） */
  setBookmarked(bookmarked: boolean): void {
    Repository.instance().setBookmarked(this.itemId, bookmarked).catch((e: Error) => {
      console.error(`${LOG_TAG}: setBookmarked failed: ${e?.message}`);
    });
  }

  toggleBookmark(): void {
    this.setBookmarked(!this.isBookmarked);
  }

  /** 源 onShare（AR-A14）：仅 articleId > ID_UNSET */
  share(ui: UIContext): void {
    if (this.articleId > ID_UNSET) {
      shareArticle(ui, this.article.link, this.articleTitle).catch((e: Error) => {
        console.error(`${LOG_TAG}: share failed: ${e?.message}`);
      });
    }
  }

  /** 源 onOpenInCustomTab（AR-A17）：链接非空 → 总是应用内浏览页（不看 linkOpener 设置） */
  openInCustomTab(): void {
    const link: string | null = this.article.link;
    if (link === null) {
      return;
    }
    const launcher: ActivityLauncher | null = ActivityLauncher.instance();
    if (launcher === null) {
      console.warn(`${LOG_TAG}: ActivityLauncher not bound`);
      return;
    }
    launcher.openLinkInCustomTab(link, toolbarColorOfTheme()).catch((e: Error) => {
      console.error(`${LOG_TAG}: openLinkInCustomTab failed: ${e?.message}`);
    });
  }

  /** 源 ReaderView onEnclosureClick（AR-A31） */
  openEnclosure(): void {
    onEnclosureClick(this.article.enclosure, this.useInAppAudioPlayer);
  }

  /** 源 openPodcastPlayer(link) */
  openPodcastPlayer(link: string): void {
    openPodcastPlayer(link);
  }

  /** 正文链接路由上下文（AR-A34） */
  linkOptions(): ArticleLinkOptions {
    return podcastLinkOptions(this.article.enclosure, this.useInAppAudioPlayer);
  }

  /** 源 ColumnArticleContent onLinkClick（AR-A34/A35）：锚点 → 平滑滚动；音频 → 播客；其余按设置打开 */
  onLinkClick(link: string, index: number | null): ArticleLinkAction {
    return handleArticleLinkClick(link, index, this.anchors, this.linkOptions());
  }

  /** 源 ttsPlay（AR-A44/A45） */
  ttsPlay(): void {
    const req: ArticleTtsRequest = new ArticleTtsRequest();
    req.itemId = this.itemId;
    req.displayFullTextOverride = this.displayFullTextOverride;
    req.showTranslatedContent = this.translation.showTranslatedContent;
    req.loadTranslatedHtml = (item: FeedItemWithFeed, readFullText: boolean): Promise<string> =>
    loadTranslatedArticleHtml(new Article(item), readFullText);
    ReadAloudActions.articleTtsPlay(req);
  }

  ttsPause(): void {
    ReadAloudActions.ttsPause();
  }

  ttsStop(): void {
    ReadAloudActions.ttsStop();
  }

  /** 源 summarize（AR-A37） */
  summarize(): void {
    const a: Article = this.article;
    this.summary.summarize(this.articleId, a.link, a.feedUrl).catch((e: Error) => {
      console.error(`${LOG_TAG}: summarize failed: ${e?.message}`);
    });
  }

  /** 源 translate（AR-A38）：显示译文中 → 切回原文，否则翻译 */
  translate(): void {
    this.translation.translate();
  }
}

/** 源 loadTranslatedArticle(article, fullText).translatedHtml（失败抛错） */
async function loadTranslatedArticleHtml(article: Article, fullText: boolean): Promise<string> {
  const html: string = await loadArticleHtml(article.id, article.snippet, fullText);
  const translation: ArticleTranslation | null =
    await TranslationManager.instance().getOrTranslateArticle(article.id, article.title, html, fullText);
  if (translation === null) {
    throw new Error('Translation failed');
  }
  return translation.translatedHtml;
}
