/**
 * GoodsRoutesCategoryPage — category goods list (source: feature/goods/view/GoodsCategoryScreen.kt,
 * viewmodel/GoodsCategoryViewModel.kt, component/FilterDialog.kt, skeleton/GoodsCategorySkeleton.kt).
 *
 * Layout (Column, background bg_page):
 *  - Top bar block (surface, padded by the status bar height — GOODS-A35):
 *      SearchTopAppBar (enterAlways scroll behaviour: slides up as the list scrolls down, back on scroll up;
 *      actions = grid/list toggle), 8vp, sort/filter bar, 8vp.
 *  - Content: NetWorkStateView — skeleton (loading) / EmptyData (empty) / EmptyNetwork + retry (error) /
 *    RefreshList (pull to refresh, load more, grid default 2 columns or list). Tap goods → GoodsRoutesDetail.
 *  - FilterDialog overlay over the whole page while vm.filtersVisible (fade in/out).
 * Route params (GoodsCategoryParam) are read in onReady; a missing param falls back to the source defaults.
 */
import { Routes } from '../common/Router';
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { Dimens } from '../core/designsystem/Dimens';
import { Goods } from '../core/model/Goods';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { GoodsCategoryParam, GoodsDetailParam } from '../core/navigation/RouteParams';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { RefreshList } from '../core/ui/base/RefreshList';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { SearchTopAppBar, TOP_APP_BAR_HEIGHT } from '../core/ui/base/TopAppBars';
import { GoodsGridItem, GoodsListItem } from '../core/ui/commerce/GoodsItems';
import { FilterDialog } from '../feature/goods/list/FilterDialog';
import { GoodsCategoryFilterBar, LayoutToggleButton } from '../feature/goods/list/GoodsCategoryFilterBar';
import { GoodsCategoryLoadingSkeleton } from '../feature/goods/list/GoodsCategorySkeleton';
import { GoodsCategoryViewModel } from '../feature/goods/list/GoodsCategoryViewModel';
import { SortState } from '../feature/goods/list/SortState';
import { SortType } from '../feature/goods/list/SortType';

/** Source AnimatedVisibility(visible = collapsedFraction >= 0.8f) for the sort-bar toggle */
const TOGGLE_IN_SORT_BAR_FRACTION: number = 0.8;
/** FilterDialog fadeIn / fadeOut */
const FILTER_FADE_MS: number = 300;

@Builder
export function GoodsRoutesCategoryPageBuilder() {
  GoodsRoutesCategoryPage()
}

@ComponentV2
struct GoodsRoutesCategoryPage {
  @Local vm: GoodsCategoryViewModel | null = null;
  @Local avoidArea: AvoidArea = AvoidArea.get();
  /** enterAlways top bar height offset: -TOP_APP_BAR_HEIGHT (collapsed) .. 0 (expanded) */
  @Local barHeightOffset: number = 0;
  private lastScrollY: number = 0;
  private listScroller: Scroller = new Scroller();
  private gridScroller: Scroller = new Scroller();

  aboutToDisappear(): void {
    if (this.vm !== null) {
      this.vm.dispose();
    }
  }

  private initViewModel(param: GoodsCategoryParam | null): void {
    if (this.vm === null) {
      this.vm = new GoodsCategoryViewModel(param);
    }
  }

  private collapsedFraction(): number {
    return -this.barHeightOffset / TOP_APP_BAR_HEIGHT;
  }

  /** Scroll delta → top bar offset (TopAppBarDefaults.enterAlwaysScrollBehavior) */
  private onContentScroll(offsetY: number): void {
    const delta: number = offsetY - this.lastScrollY;
    this.lastScrollY = offsetY;
    let next: number = this.barHeightOffset - delta;
    if (offsetY <= 0) {
      next = 0; // list back at the top (or pulled for refresh): fully expanded
    }
    if (next < -TOP_APP_BAR_HEIGHT) {
      next = -TOP_APP_BAR_HEIGHT;
    } else if (next > 0) {
      next = 0;
    }
    if (next !== this.barHeightOffset) {
      this.barHeightOffset = next;
    }
  }

  private toggleLayout(): void {
    if (this.vm !== null) {
      this.vm.toggleLayoutMode();
      // the other scrollable starts from its own offset
      this.lastScrollY = this.vm.isGridLayout ? this.gridScroller.currentOffset().yOffset :
      this.listScroller.currentOffset().yOffset;
    }
  }

  private toGoodsDetail(goodsId: number): void {
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(goodsId));
  }

  @Builder
  toggleAction() {
    Row() {
      LayoutToggleButton({
        isGridLayout: this.vm !== null ? this.vm.isGridLayout : true,
        onToggleLayout: () => {
          this.toggleLayout();
        }
      })
    }
    .margin({ right: Dimens.spaceHorizontalSmall })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  topBar(vm: GoodsCategoryViewModel) {
    Column() {
      // Search bar (64vp), clipped while sliding up
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          SearchTopAppBar({
            initialSearchText: vm.getCurrentSearchKeyword(),
            avoidStatusBar: false,
            onSearch: (text: string) => {
              this.vm?.onSearch(text);
            },
            actions: (): void => {
              this.toggleAction()
            }
          })
        }
        .width('100%')
        .height(TOP_APP_BAR_HEIGHT)
        .alignItems(HorizontalAlign.Start)
        .translate({ y: this.barHeightOffset })
      }
      .width('100%')
      .height(TOP_APP_BAR_HEIGHT + this.barHeightOffset)
      .clip(true)

      GoodsCategoryFilterBar({
        filtersVisible: this.vm !== null ? this.vm.filtersVisible : false,
        currentSortType: this.vm !== null ? this.vm.currentSortType : SortType.COMPREHENSIVE,
        currentSortState: this.vm !== null ? this.vm.currentSortState : SortState.NONE,
        isGridLayout: this.vm !== null ? this.vm.isGridLayout : true,
        showLayoutToggle: this.collapsedFraction() >= TOGGLE_IN_SORT_BAR_FRACTION,
        onFiltersClick: () => {
          this.vm?.showFilters();
        },
        onSortClick: (sortType: SortType) => {
          this.vm?.onSortClick(sortType);
        },
        onToggleLayout: () => {
          this.toggleLayout();
        }
      })
    }
    .width('100%')
    // status bar inset (source SearchTopAppBar windowInsets) + SpaceVerticalSmall above and below the sort bar
    .padding({ top: this.avoidArea.top, bottom: Dimens.spaceVerticalSmall })
    .backgroundColor($r('app.color.surface'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  gridItem(item: Object, index: number) {
    GoodsGridItem({
      goods: item as Goods,
      onGoodsClick: (goodsId: number) => {
        this.toGoodsDetail(goodsId);
      }
    })
  }

  @Builder
  listItem(item: Object, index: number) {
    GoodsListItem({
      goods: item as Goods,
      onGoodsClick: (goodsId: number) => {
        this.toGoodsDetail(goodsId);
      }
    })
  }

  @Builder
  listContent() {
    if (this.vm !== null) {
      RefreshList({
        listVm: (this.vm as GoodsCategoryViewModel) as BaseNetWorkListViewModel<Object>,
        isGrid: this.vm.isGridLayout,
        listScroller: this.listScroller,
        gridScroller: this.gridScroller,
        itemKey: (item: Object, index: number): string => {
          const g: Goods = item as Goods;
          return 'goods_' + index + '_' + g.id + '_' + g.price + '_' + g.sold + '_' + g.title;
        },
        itemBuilder: (item: Object, index: number): void => {
          this.listItem(item, index)
        },
        gridItemBuilder: (item: Object, index: number): void => {
          this.gridItem(item, index)
        },
        onScrollOffset: (offsetY: number) => {
          this.onContentScroll(offsetY);
        }
      })
    }
  }

  @Builder
  loadingSkeleton() {
    GoodsCategoryLoadingSkeleton()
  }

  @Builder
  pageContent(vm: GoodsCategoryViewModel) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.topBar(vm)
        Column() {
          NetWorkStateView({
            uiState: this.vm !== null ? this.vm.uiState : 'loading',
            useCustomLoading: true,
            customLoading: (): void => {
              this.loadingSkeleton()
            },
            content: (): void => {
              this.listContent()
            },
            onRetry: () => {
              this.vm?.retryRequest();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: this.avoidArea.bottom })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.vm !== null && this.vm.filtersVisible) {
        Stack({ alignContent: Alignment.TopStart }) {
          FilterDialog({
            categoryState: this.vm.categoryUiState,
            categoryTree: this.vm.categoryTree,
            selectedCategoryIds: this.vm.selectedCategoryIds,
            minPrice: this.vm.minPrice,
            maxPrice: this.vm.maxPrice,
            onDismiss: () => {
              this.vm?.hideFilters();
            },
            onApplyFilters: (ids: number[], min: string, max: string) => {
              this.vm?.applyFilters(ids, min, max);
            },
            onResetFilters: () => {
              this.vm?.resetFilters();
            }
          })
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: FILTER_FADE_MS }))
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        if (this.vm !== null) {
          this.pageContent(this.vm as GoodsCategoryViewModel)
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p !== undefined && p !== null && p instanceof GoodsCategoryParam) {
        this.initViewModel(p as GoodsCategoryParam);
      } else {
        this.initViewModel(null);
      }
    })
  }
}
