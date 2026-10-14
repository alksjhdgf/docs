/**
 * ArticlePage —— 源 ui/compose/navigation/NavigationDestinations.kt ArticleDestination（`reader/{itemId}`，
 * 深链 `https://feederapp.nononsenseapps.com/article/{itemId}` 由 DeepLinkRouter 解析到本页）+ ArticleScreen.kt。
 *
 * 结构（源 Scaffold(contentWindowInsets = statusBars)）：
 *   NavDestination
 *    └ Column
 *       ├ ArticleTopBar（顶部避让状态栏，AR-A01/A05/A07/A08）
 *       ├ Stack（layoutWeight 1）
 *       │   ├ ReaderView（头部 + 附件 + 头图 + 正文槽 + 92vp 底部留白）
 *       │   └ 翻页模式：左 20% / 中 60%（穿透）/ 右 20% 点击区（AR-A46）
 *       └ ArticlePlayerBottomBar（播客优先，否则朗读栏，AR-A44）
 * 参数 ArticleParam{ itemId }：缺失/非法 → 空态（提示 + 返回），不抛不自动 pop（AR-A02）。
 * 返回（顶栏箭头/系统返回）：有上一页则 pop，否则进入 Feed 页（AR-A06）。
 * 翻页模式音量键（AR-A47）：MainViewModel 在“前台 && 翻页模式 && 文章打开”时经 inputConsumer 接管音量键并发出
 *  scrollCommand（源 MainActivity.onKeyDown → mavm.scrollCommand）；本页订阅该命令按 0.9 视口滚动，销毁时退订。
 */
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { ArticleParam } from '../core/app/RouteParams';
import { ID_UNSET } from '../core/model/Enums';
import { unicodeWrap } from '../core/platform/LayoutAdapt';
import { TextToDisplay } from '../core/repo/RepoTypes';
import { ColumnArticleContent } from '../ui/common/ArticleBlocks';
import { TranslationDownloadProgress, TranslationProgressContent } from '../ui/common/CommonWidgets';
import { FeederTheme } from '../ui/common/Theme';
import { M3Type, textStyle } from '../ui/common/Typography';
import { SummaryPhase, SummarySection } from '../features/openai/AiSummary';
import { ArticlePlayerBottomBar } from '../features/readaloud/PlayerBars';
import { ArticleViewModel } from '../features/article/ArticleViewModel';
import { ArticleTopBar } from '../features/article/ArticleTopBar';
import { ReaderScrollMetrics, ReaderView } from '../features/article/ReaderView';
import { registerInAppBrowser } from '../features/article/InAppBrowser';
import { MainViewModel, ScrollDirection } from '../features/main/MainViewModel';
import { FeederEditMenuOptions } from '../core/platform/TextToolbar';

const LOG_TAG: string = 'FEEDER_ARTICLE_PAGE';
/** 源 snapshotFlow { scrollState.value }.debounce(500) */
const SCROLL_SAVE_DEBOUNCE_MS: number = 500;
/** 源 viewportSize * 0.9f */
const PAGE_FRACTION: number = 0.9;

@Builder
export function ArticlePageBuilder() {
  ArticlePage()
}

/** 源 M3 LinearProgressIndicator()（不定进度） */
@ComponentV2
struct ArticleLinearProgress {
  @Local trackWidth: number = 0;
  @Local pos: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('30%')
        .height(4)
        .backgroundColor(FeederTheme.colors.primary)
        .borderRadius(2)
        .translate({ x: this.pos * this.trackWidth * 1.3 - this.trackWidth * 0.3 })
    }
    .width('100%')
    .height(4)
    .clip(true)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .borderRadius(2)
    .onAreaChange((o: Area, n: Area) => {
      this.trackWidth = n.width as number;
    })
    .onAppear(() => {
      this.getUIContext().animateTo({ duration: 1500, iterations: -1, curve: Curve.EaseInOut }, () => {
        this.pos = 1;
      });
    })
  }
}

enum ArticlePagePhase {
  LOADING = 0,
  READY = 1,
  MISSING = 2
}

@ComponentV2
struct ArticlePage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local vm: ArticleViewModel = new ArticleViewModel();
  @Local phase: ArticlePagePhase = ArticlePagePhase.LOADING;
  @Local scrolled: boolean = false;
  private metrics: ReaderScrollMetrics = new ReaderScrollMetrics();
  private initialScroll: number = 0;
  private saveTimer: number = -1;
  private disposed: boolean = false;
  private shown: boolean = false;
  private unsubscribeScrollCommand: (() => void) | null = null;

  aboutToAppear(): void {
    registerInAppBrowser();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
      // 未到防抖时间的最后位置也保存（页面重建后回到原阅读位置）
      try {
        this.vm.saveScrollPosition(this.vm.scroller.currentOffset().yOffset);
      } catch (e) {
        console.warn(`${LOG_TAG}: save scroll position failed: ${(e as Error)?.message}`);
      }
    }
    const off: (() => void) | null = this.unsubscribeScrollCommand;
    this.unsubscribeScrollCommand = null;
    if (off !== null) {
      off();
    }
    this.vm.dispose();
  }

  // ---------------------------------------------------------------- 参数 / 生命周期

  private onRouteParam(p: ArticleParam): void {
    if (p.itemId <= ID_UNSET) {
      console.warn(`${LOG_TAG}: invalid itemId ${p.itemId}`);
      this.phase = ArticlePagePhase.MISSING;
      return;
    }
    const itemId: number = p.itemId;
    AppBootstrap.ready().then(() => {
      if (this.disposed) {
        return;
      }
      this.vm.start(itemId);
      this.initialScroll = this.vm.scrollPosition;
      this.phase = ArticlePagePhase.READY;
      this.observeScrollCommands();
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: bootstrap failed: ${e?.message}`);
    });
  }

  /** 源 onNavigateUp：popBackStack 失败（深链冷启无后栈）→ Feed（AR-A06） */
  private navigateUp(): void {
    DeepLinkRouter.backOr(() => {
      DeepLinkRouter.navigateToFeed();
    });
  }

  // ---------------------------------------------------------------- 滚动 / 翻页

  private onScrollOffset(y: number): void {
    this.scrolled = y > 0;
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.vm.saveScrollPosition(y);
    }, SCROLL_SAVE_DEBOUNCE_MS);
  }

  /** 源 ScrollDirection.UP/DOWN：±0.9 视口（不越界），动画翻页时平滑滚动（AR-A46/A47） */
  private pageScroll(down: boolean): void {
    const scroller: Scroller = this.vm.scroller;
    const amount: number = this.metrics.viewportHeight * PAGE_FRACTION;
    const current: number = scroller.currentOffset().yOffset;
    const target: number = down ? Math.min(current + amount, this.metrics.maxOffset()) : Math.max(current - amount, 0);
    if (this.vm.isAnimatedPaging) {
      scroller.scrollTo({ xOffset: 0, yOffset: target, animation: true });
    } else {
      scroller.scrollTo({ xOffset: 0, yOffset: target, animation: false });
    }
  }

  /** 源 LaunchedEffect(Unit) { mavm.scrollCommand.collect { … } }：音量键翻页命令（AR-A47） */
  private observeScrollCommands(): void {
    if (this.unsubscribeScrollCommand !== null) {
      return;
    }
    this.unsubscribeScrollCommand = MainViewModel.instance().observeScrollCommand((direction: ScrollDirection) => {
      if (this.shown) {
        this.pageScroll(direction === ScrollDirection.DOWN);
      }
    });
  }

  // ---------------------------------------------------------------- 文案

  /** 源 ArticleContent authorDate（AR-A26）：无日期 → null；仅日期 → on_date；两者 → by_author_on_date */
  private authorDate(): string | null {
    const date: string | null = this.vm.formattedPubDate;
    if (date === null) {
      return null;
    }
    const ctx = this.getUIContext().getHostContext();
    const author: string | null = this.vm.article.author;
    try {
      if (ctx !== undefined) {
        if (author === null) {
          return ctx.resourceManager.getStringByNameSync('on_date', date);
        }
        // Must wrap author in unicode marks to ensure it formats correctly in RTL
        return ctx.resourceManager.getStringByNameSync('by_author_on_date', unicodeWrap(author), date);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: author/date string failed: ${JSON.stringify(e)}`);
    }
    return author === null ? date : `${unicodeWrap(author)}, ${date}`;
  }

  /** 状态文本的纯文本（供 FeederEditMenuOptions 取选中文本） */
  private statusPlainText(): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      return ctx !== undefined ? ctx.resourceManager.getStringSync(this.statusText(this.vm.textToDisplay)) : '';
    } catch (e) {
      return '';
    }
  }

  private statusText(t: TextToDisplay): Resource {
    switch (t) {
      case TextToDisplay.LOADING_FULLTEXT:
        return $r('app.string.fetching_full_article');
      case TextToDisplay.FAILED_MISSING_BODY:
        return $r('app.string.failed_to_fetch_full_article_missing_body');
      case TextToDisplay.FAILED_MISSING_LINK:
        return $r('app.string.failed_to_fetch_full_article_missing_link');
      case TextToDisplay.FAILED_NOT_HTML:
        return $r('app.string.failed_to_fetch_full_article_not_html');
      case TextToDisplay.FAILED_FULLTEXT_TOO_LARGE:
        return $r('app.string.failed_to_fetch_full_article_too_large');
      default:
        return $r('app.string.failed_to_fetch_full_article');
    }
  }

  // ---------------------------------------------------------------- 布局

  /** 源 ArticleContent 的 articleBody 槽：直接产出子组件（锚点坐标依赖 ReaderView Column 为直接父节点） */
  @Builder
  articleBodyBuilder() {
    if (this.vm.isTranslationLoading) {
      if (this.vm.translation.downloadProgress !== null) {
        Column() {
          TranslationProgressContent({
            progress: this.vm.translation.downloadProgress as TranslationDownloadProgress
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: FeederTheme.dimens.maxReaderWidth })
        .border({ width: 1, color: FeederTheme.colors.outlineVariant, radius: 12 })
        .clip(true)
      } else {
        Column() {
          ArticleLinearProgress()
        }
        .width('100%')
        .constraintSize({ maxWidth: FeederTheme.dimens.maxReaderWidth })
      }
    }
    if (this.vm.summary.state.phase !== SummaryPhase.Empty) {
      Column() {
        SummarySection({ summary: this.vm.summary.state })
      }
      .width('100%')
      .constraintSize({ maxWidth: FeederTheme.dimens.maxReaderWidth })
    }
    // Can take a composition or two before viewstate is set to its actual values
    if (this.vm.articleId > ID_UNSET) {
      if (this.vm.textToDisplay === TextToDisplay.CONTENT) {
        ColumnArticleContent({
          article: this.vm.displayedContent,
          anchors: this.vm.anchors,
          onLinkClick: (link: string, index: number | null) => {
            this.vm.onLinkClick(link, index);
          },
          onElementPosition: (index: number, y: number) => {
            // 位置已由 anchors 登记（内容坐标），此处仅留调试痕迹
            console.debug(`${LOG_TAG}: element ${index} at ${y}`);
          },
          onArticleTop: (y: number) => {
            console.debug(`${LOG_TAG}: article top at ${y}`);
          }
        })
      } else {
        Text(this.statusText(this.vm.textToDisplay))
          .attributeModifier(textStyle(M3Type.bodyLarge, true, FeederTheme.colors.onBackground))
          .width('100%')
          .constraintSize({ maxWidth: FeederTheme.dimens.maxReaderWidth })
          .textAlign(TextAlign.Start)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(new FeederEditMenuOptions((): string => this.statusPlainText()))
        if (this.vm.textToDisplay === TextToDisplay.FAILED_FULLTEXT_TOO_LARGE) {
          Button($r('app.string.open_in_web_view'), { type: ButtonType.Capsule, stateEffect: true })
            .fontColor(FeederTheme.colors.onPrimary)
            .backgroundColor(FeederTheme.colors.primary)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 8 })
            .onClick(() => {
              this.vm.openInCustomTab();
            })
        }
      }
    }
  }

  @Builder
  pagingOverlay() {
    Row() {
      Column()
        .height('100%')
        .layoutWeight(2)
        .onClick(() => {
          this.pageScroll(false);
        })
      Column()
        .height('100%')
        .layoutWeight(6)
        .hitTestBehavior(HitTestMode.None)
      Column()
        .height('100%')
        .layoutWeight(2)
        .onClick(() => {
          this.pageScroll(true);
        })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  missingBuilder() {
    Column({ space: 16 }) {
      Text($r('app.string.nothing_to_display'))
        .attributeModifier(textStyle(M3Type.bodyLarge, true, FeederTheme.colors.onBackground))
      Button($r('app.string.go_back'), { type: ButtonType.Capsule, stateEffect: true })
        .fontColor(FeederTheme.colors.onPrimary)
        .backgroundColor(FeederTheme.colors.primary)
        .onClick(() => {
          this.navigateUp();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  readerBuilder() {
    Stack({ alignContent: Alignment.TopStart }) {
      ReaderView({
        scroller: this.vm.scroller,
        metrics: this.metrics,
        readTimeSecs: this.vm.readTimeSecs,
        enclosure: this.vm.enclosure,
        articleTitle: this.vm.articleTitle,
        feedTitle: this.vm.feedDisplayTitle,
        authorDate: this.authorDate(),
        showImage: this.vm.showHeaderImage,
        imageUrl: this.vm.headerImageUrl,
        initialScrollPosition: this.initialScroll,
        onEnclosureClick: () => {
          this.vm.openEnclosure();
        },
        onFeedTitleClick: () => {
          // 源 onNavigateToFeed(articleFeedId) → FeedDestination.navigate（AR-A25）
          DeepLinkRouter.navigateToFeed(this.vm.article.feedId);
        },
        onScrollOffset: (y: number) => {
          this.onScrollOffset(y);
        },
        articleBody: (): void => {
          this.articleBodyBuilder()
        }
      })
      if (this.vm.isPagingMode) {
        this.pagingOverlay()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    NavDestination() {
      Column() {
        ArticleTopBar({
          vm: this.vm,
          topInset: this.avoid.top,
          scrolled: this.scrolled,
          onNavigateUp: () => {
            this.navigateUp();
          },
          onShare: () => {
            this.vm.share(this.getUIContext());
          }
        })
        if (this.phase === ArticlePagePhase.MISSING) {
          this.missingBuilder()
        } else {
          if (this.phase === ArticlePagePhase.READY) {
            this.readerBuilder()
          } else {
            Column()
              .width('100%')
              .layoutWeight(1)
          }
          ArticlePlayerBottomBar({
            bottomInset: this.avoid.bottom,
            onTtsPlay: () => {
              this.vm.ttsPlay();
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(FeederTheme.colors.background)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object = ctx.pathInfo.param as Object;
      if (p instanceof ArticleParam) {
        this.onRouteParam(p as ArticleParam);
      } else {
        console.warn(`${LOG_TAG}: missing ArticleParam`);
        this.phase = ArticlePagePhase.MISSING;
      }
    })
    .onShown(() => {
      this.shown = true;
    })
    .onHidden(() => {
      this.shown = false;
    })
    .onBackPressed((): boolean => {
      this.navigateUp();
      return true;
    })
  }
}
