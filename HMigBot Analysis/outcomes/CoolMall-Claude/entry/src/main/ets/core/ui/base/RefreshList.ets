/**
 * RefreshList — pull-to-refresh + load-more list frame driven by a BaseNetWorkListViewModel
 * (source: core/ui/component/refresh/{RefreshLayout,RefreshContent,RefreshHeader,RefreshState}.kt).
 *
 * - Pull to refresh: ArkUI `Refresh` with a custom 52vp header (MiLoadingMobile ring + `下拉刷新` / `松开刷新` /
 *   `刷新中...` / `刷新完成`). Releasing past the header calls listVm.onRefresh(); when listVm.isRefreshing turns
 *   false the header shows `刷新完成` for 800 ms and then retracts (source RefreshLayout delay(800)).
 *   If the view model ignores the refresh (load more in progress) the header retracts immediately.
 * - List mode (source RefreshListContent): List spacedBy 12, horizontal padding 12, a zero-height first item,
 *   the items, and a LoadMoreFooter (horizontal padding 32) as the last item. When the footer state becomes
 *   Loading the list jumps to the end (source listState.scrollToItem(totalItemsCount)).
 * - Grid mode (source RefreshGridContent, LazyVerticalStaggeredGrid 2 columns, contentPadding 12, spacing 12):
 *   WaterFlow with sections — optional full-line header items (gridHeaderCount + gridHeaderBuilder, source
 *   `item(span = FullLine)`), the 2-column items, and a full-line LoadMoreFooter.
 * - Load more: onScrollIndex → listVm.shouldLoadMore(lastVisibleIndex, totalItemCount) → listVm.onLoadMore()
 *   (last 3 items; totals include the spacer / header / footer items like the source's totalItemsCount).
 * - List ↔ grid switch: fade + scale(0.92) 300 ms linear (source AnimatedContent).
 * - Inner scrollables use nestedScroll(PARENT_FIRST forward / SELF_FIRST backward) so an AppScaffold large bar
 *   (or any collapsing parent) collapses first (source scrollBehavior.nestedScrollConnection).
 *
 * Usage:
 *   RefreshList({
 *     listVm: this.vm,                                    // XxxViewModel extends BaseNetWorkListViewModel<Item>
 *     itemBuilder: (item: Object, index: number): void => { this.itemRow(item as Item, index) }
 *   })
 * Items that are @ObservedV2 instances must pass `itemKey` (the default key uses JSON.stringify).
 */
import { BaseNetWorkListViewModel } from '../../common/BaseNetWorkListViewModel';
import { LoadMoreState } from '../../common/LoadMoreState';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';
import { LoadMoreFooter, MiLoadingMobile } from './StateViews';

/** RefreshHeader height (source .height(52.dp)) = refresh trigger threshold */
const REFRESH_HEADER_HEIGHT: number = 52;
/** "刷新完成" display time before retracting */
const REFRESH_FINISH_DELAY_MS: number = 800;
/** Layout switch animation */
const LAYOUT_SWITCH_MS: number = 300;

@ComponentV2
export struct RefreshList {
  /** Driving view model (list / loadMoreState / isRefreshing / onRefresh / onLoadMore / shouldLoadMore) */
  @Param listVm: BaseNetWorkListViewModel<Object> = new BaseNetWorkListViewModel<Object>();
  /** Grid (2-column staggered) instead of list (source isGrid) */
  @Param isGrid: boolean = false;
  /** Enable pull to refresh (source RefreshState.enableRefresh) */
  @Param enableRefresh: boolean = true;
  /** List-mode scroller (source listState) */
  @Param listScroller: Scroller = new Scroller();
  /** Grid-mode scroller (source gridState) */
  @Param gridScroller: Scroller = new Scroller();
  /** Number of full-line header items before the grid items */
  @Param gridHeaderCount: number = 0;
  /** Item key; null → index + JSON of the item */
  @Param itemKey: ((item: Object, index: number) => string) | null = null;

  /** List item content (source `content`) */
  @BuilderParam itemBuilder: (item: Object, index: number) => void = this.defaultItem;
  /** Grid item content (source `gridContent`); falls back to nothing */
  @BuilderParam gridItemBuilder: (item: Object, index: number) => void = this.defaultItem;
  /** Grid full-line header item #index */
  @BuilderParam gridHeaderBuilder: (index: number) => void = this.defaultHeader;

  /** Vertical scroll offset of the active scrollable (for custom collapsing headers) */
  @Event onScrollOffset: (offsetY: number) => void = (offsetY: number) => {
  };

  @Local refreshing: boolean = false;
  @Local refreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @Local finishing: boolean = false;

  private finishTimer: number = -1;
  private sections: WaterFlowSections = new WaterFlowSections();

  @Builder
  defaultItem(item: Object, index: number) {
  }

  @Builder
  defaultHeader(index: number) {
  }

  aboutToAppear(): void {
    this.rebuildSections();
  }

  aboutToDisappear(): void {
    if (this.finishTimer >= 0) {
      clearTimeout(this.finishTimer);
      this.finishTimer = -1;
    }
  }

  // ------------------------------------------------------------------ refresh

  private startRefresh(): void {
    if (this.finishTimer >= 0) {
      clearTimeout(this.finishTimer);
      this.finishTimer = -1;
    }
    this.finishing = false;
    this.listVm.onRefresh();
    if (!this.listVm.isRefreshing) {
      // Ignored by the view model (load more in progress): retract at once
      this.refreshing = false;
    }
  }

  @Monitor('listVm.isRefreshing')
  onVmRefreshingChange(monitor: IMonitor): void {
    if (!this.listVm.isRefreshing && this.refreshing && !this.finishing) {
      this.finishing = true;
      this.finishTimer = setTimeout(() => {
        this.finishTimer = -1;
        this.finishing = false;
        this.refreshing = false;
      }, REFRESH_FINISH_DELAY_MS);
    }
  }

  private headerText(): Resource {
    if (this.refreshing) {
      return this.finishing ? $r('app.string.refresh_complete') : $r('app.string.refresh_refreshing');
    }
    if (this.refreshStatus === RefreshStatus.OverDrag) {
      return $r('app.string.refresh_release');
    }
    return $r('app.string.refresh_pull_down');
  }

  /** onSurface @ 0.5 */
  private headerRingColor(): string {
    return ThemeManager.instance.isDark ? '#80D1D1D1' : '#80181818';
  }

  @Builder
  refreshHeader() {
    Row() {
      Stack({ alignContent: Alignment.Center }) { // source Box(contentAlignment = Center)
        if (this.refreshing) {
          MiLoadingMobile({ ringColor: this.headerRingColor(), ringSize: 24, rotating: true })
        } else {
          MiLoadingMobile({ ringColor: this.headerRingColor(), ringSize: 24, rotating: false })
        }
      }
      .width(24)
      .height(24)
      Text(this.headerText())
        .margin({ left: Dimens.spaceHorizontalSmall })
        .fontSize(Dimens.fontBodyMedium)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(REFRESH_HEADER_HEIGHT)
    .justifyContent(FlexAlign.Center) // source Arrangement.Center
    .alignItems(VerticalAlign.Center)
  }

  // ------------------------------------------------------------------ load more

  private checkLoadMore(lastIndex: number, total: number): void {
    if (this.listVm.shouldLoadMore(lastIndex, total)) {
      this.listVm.onLoadMore();
    }
  }

  @Monitor('listVm.loadMoreState')
  onLoadMoreStateChange(monitor: IMonitor): void {
    if (!this.isGrid && this.listVm.loadMoreState === LoadMoreState.Loading && this.listVm.list.length > 0) {
      // Footer index = spacer (0) + items
      this.listScroller.scrollToIndex(this.listVm.list.length + 1, false, ScrollAlign.END);
    }
  }

  private retryLoadMore(): void {
    this.listVm.onLoadMore();
  }

  private keyOf(item: Object, index: number): string {
    const keyFn: ((item: Object, index: number) => string) | null = this.itemKey;
    if (keyFn !== null) {
      return keyFn(item, index);
    }
    return index + '_' + JSON.stringify(item);
  }

  // ------------------------------------------------------------------ grid sections

  @Monitor('listVm.list', 'gridHeaderCount', 'isGrid')
  onGridShapeChange(monitor: IMonitor): void {
    this.rebuildSections();
  }

  private rebuildSections(): void {
    const gap: number = Dimens.spacePaddingMedium;
    const result: SectionOptions[] = [];
    const sideMargin: Margin = { top: gap, left: gap, right: gap };
    const lastMargin: Margin = { top: gap, left: gap, right: gap, bottom: gap };
    const headerCount: number = this.gridHeaderCount > 0 ? this.gridHeaderCount : 0;
    if (headerCount > 0) {
      const header: SectionOptions = {
        itemsCount: headerCount,
        crossCount: 1,
        rowsGap: gap,
        margin: sideMargin
      };
      result.push(header);
    }
    if (this.listVm.list.length > 0) {
      const items: SectionOptions = {
        itemsCount: this.listVm.list.length,
        crossCount: 2,
        columnsGap: gap,
        rowsGap: gap,
        margin: sideMargin
      };
      result.push(items);
    }
    const footer: SectionOptions = {
      itemsCount: 1,
      crossCount: 1,
      margin: lastMargin
    };
    result.push(footer);
    this.sections.splice(0, this.sections.length(), result);
  }

  private headerIndices(): number[] {
    const result: number[] = [];
    for (let i = 0; i < this.gridHeaderCount; i++) {
      result.push(i);
    }
    return result;
  }

  // ------------------------------------------------------------------ content

  @Builder
  footerItem() {
    Column() {
      LoadMoreFooter({
        loadState: this.listVm.loadMoreState,
        retryEnabled: true,
        onRetry: () => {
          this.retryLoadMore();
        }
      })
    }
    .width('100%')
    .padding({ left: Dimens.spaceHorizontalXXLarge, right: Dimens.spaceHorizontalXXLarge })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  listContent() {
    List({ space: Dimens.spaceVerticalMedium, scroller: this.listScroller }) {
      // source item { Spacer(modifier = Modifier) }: zero-height first item (adds one 12vp gap)
      ListItem() {
        Column()
          .width('100%')
          .height(0)
      }

      ForEach(this.listVm.list, (item: Object, index: number) => {
        ListItem() {
          this.itemBuilder(item, index)
        }
      }, (item: Object, index: number) => this.keyOf(item, index))

      ListItem() {
        this.footerItem()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })
    .scrollBar(BarState.Off)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    .onScrollIndex((start: number, end: number) => {
      this.checkLoadMore(end, this.listVm.list.length + 2);
    })
    .onDidScroll(() => {
      this.onScrollOffset(this.listScroller.currentOffset().yOffset);
    })
  }

  @Builder
  gridContent() {
    WaterFlow({ scroller: this.gridScroller, sections: this.sections }) {
      ForEach(this.headerIndices(), (i: number) => {
        FlowItem() {
          this.gridHeaderBuilder(i)
        }
        .width('100%')
      }, (i: number) => 'grid_header_' + i)

      ForEach(this.listVm.list, (item: Object, index: number) => {
        FlowItem() {
          this.gridItemBuilder(item, index)
        }
        .width('100%')
      }, (item: Object, index: number) => this.keyOf(item, index))

      FlowItem() {
        this.footerItem()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    .onScrollIndex((first: number, last: number) => {
      this.checkLoadMore(last, this.gridHeaderCount + this.listVm.list.length + 1);
    })
    .onDidScroll(() => {
      this.onScrollOffset(this.gridScroller.currentOffset().yOffset);
    })
  }

  build() {
    Refresh({ refreshing: this.refreshing!!, builder: this.refreshHeader() }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.isGrid) {
          Stack({ alignContent: Alignment.TopStart }) {
            this.gridContent()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
            .animation({ duration: LAYOUT_SWITCH_MS, curve: Curve.Linear }))
        } else {
          Stack({ alignContent: Alignment.TopStart }) {
            this.listContent()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
            .animation({ duration: LAYOUT_SWITCH_MS, curve: Curve.Linear }))
        }
      }
      .width('100%')
      .height('100%')
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .refreshOffset(REFRESH_HEADER_HEIGHT)
    .pullToRefresh(this.enableRefresh)
    .onStateChange((state: RefreshStatus) => {
      this.refreshStatus = state;
    })
    .onRefreshing(() => {
      this.startRefresh();
    })
  }
}
