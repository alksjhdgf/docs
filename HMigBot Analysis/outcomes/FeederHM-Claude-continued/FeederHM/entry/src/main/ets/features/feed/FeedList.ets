/**
 * FeedList — 源 FeedScreen.kt FeedListContent（:1359）/ FeedGridContent（:1621）+ FAB（:1164）。
 *  - 紧凑设备（宽或高 Compact）→ 单列 List；否则瀑布流 WaterFlow，列数 forceSingleColumn ? 1 : dimens.feedScreenColumns
 *    （2 / >1028vp 3 / >1360vp 4，FD-A38）；
 *  - 条目 = ui/common/SwipeableFeedItem（四种样式；列表模式 COMPACT/SUPER_COMPACT 条目间分割线，FD-A39）；
 *    CARD/COMPACT_CARD 列表间距与左右边距 = dimens.margin，紧凑样式 0；网格间距 = dimens.gutter；
 *  - 底栏不可见时内容底部避让导航条；列表模式 FAB 可见时末尾 72vp 占位（SpacerForFab）；
 *  - 每个 feed/tag 独立滚动状态：切换 feed/tag 时换新 Scroller 并重建列表 → 从顶部开始（FD-A08）；
 *  - 无可见条目 → NothingToRead 空态（`Open another feed?` 开/关抽屉、`Add more feeds?` 进 SearchFeed，FD-A35）；
 *  - 滚动中禁滑动（swipeEnabled = !isScrollInProgress）；onReachEnd → 分页加载；可见比例 → 滚动标已读（FD-A45）。
 */
import { FeedListItem } from '../../core/model/FeedItem';
import { LayoutAdapt, WindowMetrics } from '../../core/platform/LayoutAdapt';
import { FeedItemStyle } from '../../core/model/Enums';
import { FeederTheme } from '../../ui/common/Theme';
import { NothingToRead } from '../../ui/common/EmptyState';
import { FeedItemHandlers } from '../../ui/common/FeedItemText';
import { SwipeableFeedItem, feedItemShowsDivider } from '../../ui/common/SwipeableFeedItem';
import { FeedViewModel, MARK_AS_READ_VISIBLE_THRESHOLD } from './FeedViewModel';
import { feedItemKey } from './FeedListSource';
import { placeholderFeedViewModel } from './FeedTopBar';

/** 源 SpacerForFab 高度 56 + 16 */
export const FAB_SPACER_HEIGHT: number = 72;
const VISIBILITY_RATIOS: number[] = [0.0, MARK_AS_READ_VISIBLE_THRESHOLD, 1.0];

@ComponentV2
export struct FeedList {
  @Param vm: FeedViewModel = placeholderFeedViewModel();
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  /** 源 isBottomBarVisible（播客条 / 朗读条） */
  @Param bottomBarVisible: boolean = false;
  /** 导航条避让（vp，AvoidArea.bottom） */
  @Param bottomInset: number = 0;
  @Event onOpenNavDrawer: () => void = () => {
    console.info('TODO:openNavDrawer:FeedList');
  };
  @Event onAddFeed: () => void = () => {
    console.info('TODO:addFeed:FeedList');
  };
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  /** 源 listState.isScrollInProgress */
  @Local scrolling: boolean = false;
  /** 当前滚动状态所属 feed/tag（ForEach 键：变化即重建列表） */
  @Local scrollerKey: string = '';
  @Local viewportHeight: number = 0;
  private listScroller: Scroller = new Scroller();
  private gridScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollerKey = this.vm.feedKey;
  }

  aboutToDisappear(): void {
    this.vm.flushVisibilityMarks();
  }

  /** 源 key(viewState.currentFeedOrTag) { rememberLazyListState() }：每个 feed/tag 独立滚动状态 */
  @Monitor('vm.currentFeedId', 'vm.currentTag')
  onFeedChanged(monitor: IMonitor): void {
    const key: string = this.vm.feedKey;
    if (key === this.scrollerKey) {
      return;
    }
    this.vm.flushVisibilityMarks();
    this.listScroller = new Scroller();
    this.gridScroller = new Scroller();
    this.scrolling = false;
    this.scrollerKey = key;
  }

  /** Sync feeds / 仅未读下 Mark the above as read → 回到顶部（FD-A22 / FD-A44） */
  @Monitor('vm.scrollToTopRequest')
  onScrollToTopRequested(monitor: IMonitor): void {
    try {
      if (this.isGrid()) {
        this.gridScroller.scrollToIndex(0, true);
      } else {
        this.listScroller.scrollToIndex(0, true);
      }
    } catch (e) {
      console.info(`FeedList: scrollToTop skipped: ${(e as Error)?.message}`);
    }
  }

  /** 源 isCompactDevice() → FeedList，否则 FeedGrid */
  private isGrid(): boolean {
    return !this.metrics.isCompactDevice;
  }

  private columnCount(): number {
    return this.vm.settings.forceSingleColumn ? 1 : Math.max(1, FeederTheme.dimens.feedScreenColumns);
  }

  private columnsTemplate(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.columnCount(); i++) {
      parts.push('1fr');
    }
    return parts.join(' ');
  }

  private isCardStyle(): boolean {
    const s: FeedItemStyle = this.vm.settings.feedItemStyle;
    return s === FeedItemStyle.CARD || s === FeedItemStyle.COMPACT_CARD;
  }

  /** 源 arrangement：CARD/COMPACT_CARD spacedBy(margin)，紧凑样式 0 */
  private listSpace(): number {
    return this.isCardStyle() ? FeederTheme.dimens.margin : 0;
  }

  private listSideMargin(): number {
    return !this.bottomBarVisible && this.isCardStyle() ? FeederTheme.dimens.margin : 0;
  }

  /** 源网格 contentPadding：底栏可见 0；否则导航条底部 inset + margin（四周） */
  private gridPadding(): Padding {
    if (this.bottomBarVisible) {
      const none: Padding = { left: 0, right: 0, top: 0, bottom: 0 };
      return none;
    }
    const m: number = FeederTheme.dimens.margin;
    const p: Padding = { left: m, right: m, top: m, bottom: m + this.bottomInset };
    return p;
  }

  @Builder
  feedItem(item: FeedListItem, index: number, withDivider: boolean) {
    SwipeableFeedItem({
      item: item,
      listFilter: this.vm.filter,
      showThumbnail: this.vm.settings.showThumbnails,
      feedItemStyle: this.vm.settings.feedItemStyle,
      swipeAsRead: this.vm.settings.swipeAsRead,
      bookmarkIndicator: !this.vm.isSavedArticles,
      maxLines: this.vm.settings.maxLines,
      showOnlyTitle: this.vm.settings.showOnlyTitle,
      showReadingTime: this.vm.settings.showReadingTime,
      swipeEnabled: !this.scrolling,
      showDivider: withDivider && feedItemShowsDivider(this.vm.settings.feedItemStyle, index, this.vm.itemCount),
      handlers: this.handlers
    })
  }

  @Builder
  listBuilder() {
    List({ scroller: this.listScroller, space: this.listSpace() }) {
      LazyForEach(this.vm.dataSource, (item: FeedListItem, index: number) => {
        ListItem() {
          this.feedItem(item, index, true)
        }
        .width('100%')
        .onAppear(() => {
          this.vm.onItemShown(index);
        })
        .onDisAppear(() => {
          this.vm.onItemGone(item.id);
        })
        .onVisibleAreaChange(VISIBILITY_RATIOS, (isExpanding: boolean, ratio: number) => {
          this.vm.onItemVisibility(item, ratio);
        })
      }, (item: FeedListItem, index: number): string => feedItemKey(item))
      if (this.vm.showFab && !this.bottomBarVisible) {
        ListItem() {
          Column()
            .width('100%')
            .height(FAB_SPACER_HEIGHT)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .alignListItem(ListItemAlign.Center)
    .cachedCount(4)
    .padding({ left: this.listSideMargin(), right: this.listSideMargin() })
    .contentEndOffset(this.bottomBarVisible ? 0 : this.bottomInset)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onScrollStart(() => {
      this.scrolling = true;
    })
    .onScrollStop(() => {
      this.scrolling = false;
    })
    .onReachEnd(() => {
      this.vm.loadMore();
    })
  }

  @Builder
  gridBuilder() {
    WaterFlow({ scroller: this.gridScroller }) {
      LazyForEach(this.vm.dataSource, (item: FeedListItem, index: number) => {
        FlowItem() {
          this.feedItem(item, index, false)
        }
        .width('100%')
        .onAppear(() => {
          this.vm.onItemShown(index);
        })
        .onDisAppear(() => {
          this.vm.onItemGone(item.id);
        })
        .onVisibleAreaChange(VISIBILITY_RATIOS, (isExpanding: boolean, ratio: number) => {
          this.vm.onItemVisibility(item, ratio);
        })
      }, (item: FeedListItem, index: number): string => feedItemKey(item))
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(FeederTheme.dimens.gutter)
    .rowsGap(FeederTheme.dimens.gutter)
    .cachedCount(4)
    .padding(this.gridPadding())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onScrollStart(() => {
      this.scrolling = true;
    })
    .onScrollStop(() => {
      this.scrolling = false;
    })
    .onReachEnd(() => {
      this.vm.loadMore();
    })
  }

  @Builder
  emptyBuilder() {
    // 源：空态背后保留可滚动 Box（下拉刷新仍可用）+ NothingToRead
    Scroll() {
      Column() {
        NothingToRead({
          onOpenOtherFeed: () => {
            this.onOpenNavDrawer();
          },
          onAddFeed: () => {
            this.onAddFeed();
          }
        })
      }
      .width('100%')
      .height(this.viewportHeight > 0 ? this.viewportHeight : '100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (!this.vm.haveVisibleFeedItems) {
        this.emptyBuilder()
      } else {
        ForEach([this.scrollerKey], (key: string) => {
          if (this.isGrid()) {
            this.gridBuilder()
          } else {
            this.listBuilder()
          }
        }, (key: string): string => `${key}|${this.isGrid()}`)
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const h: number = Number(newValue.height);
      if (!isNaN(h) && h > 0) {
        this.viewportHeight = h;
      }
    })
  }
}

/** 源 FAB：Mark all as read（DoneAll）；pref_open_drawer_on_fab 开时同时开/关抽屉（FD-A36） */
@ComponentV2
export struct FeedFab {
  @Param bottomInset: number = 0;
  @Event onFabClick: () => void = () => {
    console.info('TODO:fabClick:FeedFab');
  };

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onPrimaryContainer])
    }
    .width(56)
    .height(56)
    .borderRadius(16)
    .backgroundColor(FeederTheme.colors.primaryContainer)
    .shadow({ radius: 6, color: '#33000000', offsetX: 0, offsetY: 3 })
    .margin({ right: 16, bottom: 16 + this.bottomInset })
    .accessibilityText($r('app.string.mark_all_as_read'))
    .onClick(() => {
      this.onFabClick();
    })
  }
}
