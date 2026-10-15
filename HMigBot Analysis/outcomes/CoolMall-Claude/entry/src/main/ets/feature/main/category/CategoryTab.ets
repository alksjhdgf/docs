/**
 * CategoryTab — the Category tab of the main page (source: feature/main/view/CategoryScreen.kt
 * CategoryRoute / CategoryScreen / CategoryContentView / LeftCategoryList / RightCategoryContent).
 *
 * Layout (source CommonScaffold: contentWindowInsets exclude navigationBars):
 *   Column(bg_page) {
 *     CenterTopAppBar(`分类`, no back icon) — pads itself by the status bar (MAIN-A01/A02)
 *     NetWorkStateView(loading → CategoryLoadingSkeleton, error → EmptyNetwork + retry, success → content)
 *   }
 * The bottom navigation-bar inset is NOT applied here (excluded in source; the main page's bottom bar owns it).
 *
 * Content: Row { left 100vp first-level list | right List (one ListItem per first-level category) }.
 * Linkage (source LaunchedEffects):
 *  - left tap → vm.selectCategory(i); if i != lastSelectedIndex → flag isScrollingFromLeftClick, animate the
 *    right list to item i; flag cleared on scroll stop (or when the user starts dragging).
 *  - right scroll (onDidScroll) → visible index (first item whose center lies in the top half of the viewport,
 *    else the first completely visible one, else the first visible one); when not from a left tap and it
 *    differs from lastSelectedIndex → vm.selectCategory(index).
 */
import { curves } from '@kit.ArkUI';
import { CategoryViewModel } from './CategoryViewModel';
import { CategoryLoadingSkeleton } from './CategorySkeleton';
import { CategoryTree } from '../../../core/model/Goods';
import { CenterTopAppBar } from '../../../core/ui/base/TopAppBars';
import { NetWorkStateView } from '../../../core/ui/base/StateViews';
import { TitleWithLine } from '../../../core/ui/widget/AppCard';
import { NetWorkImage } from '../../../core/ui/widget/Images';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { GoodsCategoryParam } from '../../../core/navigation/RouteParams';
import { Routes } from '../../../common/Router';

/** Left menu width (source 100.dp) */
const LEFT_MENU_WIDTH: number = 100;
/** Left item height (source 50.dp) */
const LEFT_ITEM_HEIGHT: number = 50;
/** Right list vertical content padding (source contentPadding vertical 16.dp) */
const RIGHT_CONTENT_PADDING: number = 16;
/** Sub categories per row (source itemsPerRow) */
const ITEMS_PER_ROW: number = 3;

/** Split a list into rows of `size` (source List.chunked) */
function chunkCategories(list: CategoryTree[], size: number): CategoryTree[][] {
  const rows: CategoryTree[][] = [];
  for (let i = 0; i < list.length; i += size) {
    rows.push(list.slice(i, i + size));
  }
  return rows;
}

@ComponentV2
export struct CategoryTab {
  @Local vm: CategoryViewModel = new CategoryViewModel();
  /** Right list scroll state (source rightListState) */
  private rightScroller: Scroller = new Scroller();
  /** Scroll currently driven by a left tap (source isScrollingFromLeftClick) */
  private isScrollingFromLeftClick: boolean = false;
  /** Last index applied to the left selection (source lastSelectedIndex) */
  private lastSelectedIndex: number = 0;
  /** Right list viewport height (vp) */
  private rightListHeight: number = 0;

  aboutToAppear(): void {
    this.lastSelectedIndex = this.vm.selectedCategoryIndex;
    // source: init { executeRequest() }
    this.vm.executeRequest();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private categories(): CategoryTree[] {
    const data: CategoryTree[] | null = this.vm.data;
    return data !== null && data !== undefined ? data : [];
  }

  /** Left tap (source onCategorySelected + LaunchedEffect(selectedIndex)) */
  private onLeftCategorySelected(index: number): void {
    this.vm.selectCategory(index);
    const size: number = this.categories().length;
    if (index >= 0 && index < size && index !== this.lastSelectedIndex) {
      this.isScrollingFromLeftClick = true;
      this.lastSelectedIndex = index;
      this.rightScroller.scrollToIndex(index, true, ScrollAlign.START);
    }
  }

  /** Index of the first-level category currently in view (source derivedStateOf currentVisibleIndex) */
  private computeVisibleIndex(): number {
    const size: number = this.categories().length;
    let firstVisible: number = -1;
    let firstCompletelyVisible: number = -1;
    let centerItem: number = -1;
    const centerOffset: number = (this.rightListHeight - RIGHT_CONTENT_PADDING) / 2;
    for (let i = 0; i < size; i++) {
      let rect: RectResult | null = null;
      try {
        rect = this.rightScroller.getItemRect(i);
      } catch (e) {
        rect = null;
      }
      if (rect === null || (rect.width === 0 && rect.height === 0)) {
        continue; // not visible
      }
      // offsets relative to the content start (Compose item offset excludes the before-content padding)
      const offset: number = rect.y - RIGHT_CONTENT_PADDING;
      if (firstVisible < 0) {
        firstVisible = i;
      }
      if (firstCompletelyVisible < 0 && offset >= 0) {
        firstCompletelyVisible = i;
      }
      const itemCenter: number = offset + rect.height / 2;
      if (centerItem < 0 && itemCenter > 0 && itemCenter < centerOffset) {
        centerItem = i;
      }
    }
    if (firstVisible < 0) {
      return this.vm.selectedCategoryIndex;
    }
    if (centerItem >= 0) {
      return centerItem;
    }
    return firstCompletelyVisible >= 0 ? firstCompletelyVisible : firstVisible;
  }

  /** Right scroll → left selection (source LaunchedEffect(currentVisibleIndex)) */
  private syncLeftFromRight(): void {
    if (this.isScrollingFromLeftClick) {
      return;
    }
    const visible: number = this.computeVisibleIndex();
    if (visible !== this.lastSelectedIndex) {
      this.lastSelectedIndex = visible;
      this.vm.selectCategory(visible);
    }
  }

  /** Sub category tap → GoodsRoutes.Category(typeId) (source GoodsNavigator.toCategory) */
  private toGoodsCategory(sub: CategoryTree): void {
    const param: GoodsCategoryParam = new GoodsCategoryParam();
    param.typeId = sub.id.toString();
    AppNavigator.navigate(Routes.GOODS_ROUTES_CATEGORY, param);
  }

  @Builder
  skeletonBuilder() {
    CategoryLoadingSkeleton()
  }

  @Builder
  leftCategoryList() {
    List() {
      ForEach(this.categories(), (category: CategoryTree, index: number) => {
        ListItem() {
          LeftCategoryItem({
            itemName: category.name,
            isSelected: index === this.vm.selectedCategoryIndex,
            isPrevious: index === this.vm.selectedCategoryIndex - 1,
            isNext: index === this.vm.selectedCategoryIndex + 1,
            isFirst: index === 0,
            onItemClick: () => {
              this.onLeftCategorySelected(index);
            }
          })
        }
      }, (category: CategoryTree, index: number) => 'left_' + category.id + '_' + index + '_' + category.name)
      // extra non-clickable placeholder (rounded corner under the last item)
      ListItem() {
        BottomPlaceholderItem({
          isLastSelected: this.vm.selectedCategoryIndex === this.categories().length - 1
        })
      }
    }
    .width(LEFT_MENU_WIDTH)
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg_page'))
  }

  @Builder
  categorySection(category: CategoryTree) {
    Column() {
      ForEach(chunkCategories(category.children, ITEMS_PER_ROW), (rowItems: CategoryTree[], rowIndex: number) => {
        Row() {
          ForEach(rowItems, (sub: CategoryTree) => {
            Column() {
              SubCategoryItem({
                subName: sub.name,
                imageUrl: sub.pic ?? '',
                onItemClick: () => {
                  this.toGoodsCategory(sub);
                }
              })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (sub: CategoryTree) => 'sub_' + sub.id + '_' + sub.name + '_' + (sub.pic ?? ''))
          if (rowItems.length < ITEMS_PER_ROW) {
            // blank placeholder for an incomplete row (source Spacer.weight)
            Row()
              .layoutWeight(ITEMS_PER_ROW - rowItems.length)
              .height(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.SpaceBetween)
      }, (rowItems: CategoryTree[], rowIndex: number) => 'row_' + category.id + '_' + rowIndex + '_' +
        rowItems.map((c: CategoryTree): string => c.id.toString()).join(','))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  rightCategoryContent() {
    List({ scroller: this.rightScroller, space: 24 }) {
      ForEach(this.categories(), (category: CategoryTree, index: number) => {
        ListItem() {
          Column() {
            TitleWithLine({ titleText: category.name })
            Row()
              .width('100%')
              .height(8)
            if (category.children.length > 0) {
              this.categorySection(category)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 8 })
        }
      }, (category: CategoryTree, index: number) => 'right_' + category.id + '_' + index + '_' + category.name + '_' +
        category.children.length)
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('app.color.surface'))
    .padding({ left: 8, right: 8 })
    .contentStartOffset(RIGHT_CONTENT_PADDING)
    .contentEndOffset(RIGHT_CONTENT_PADDING)
    .scrollBar(BarState.Off)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.rightListHeight = Number(newArea.height);
    })
    .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult => {
      // user drag / fling (not scroller-driven): any left-tap scroll is over
      this.isScrollingFromLeftClick = false;
      const result: OnScrollFrameBeginHandlerResult = { offsetRemain: offset };
      return result;
    })
    .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
      this.syncLeftFromRight();
    })
    .onScrollStop(() => {
      this.isScrollingFromLeftClick = false;
    })
  }

  @Builder
  contentView() {
    Row() {
      this.leftCategoryList()
      this.rightCategoryContent()
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      CenterTopAppBar({ titleText: $r('app.string.category'), showBackIcon: false })
      Column() {
        NetWorkStateView({
          uiState: this.vm.uiState,
          useCustomLoading: true,
          onRetry: () => {
            this.vm.retryRequest();
          },
          content: (): void => {
            this.contentView()
          },
          customLoading: (): void => {
            this.skeletonBuilder()
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.bg_page'))
  }
}

/**
 * Left category item (source LeftCategoryItem).
 * Base surface layer; unselected items add a bg_page layer with the "connected" corners next to the selected
 * item; selected: 3x24 primary indicator, primary bold text scaled 1.2x; selected item is not clickable.
 */
@ComponentV2
struct LeftCategoryItem {
  @Param itemName: string = '';
  @Param isSelected: boolean = false;
  @Param isPrevious: boolean = false;
  @Param isNext: boolean = false;
  @Param isFirst: boolean = false;
  @Event onItemClick: () => void = () => {
  };

  private cornerRadius(): BorderRadiuses {
    const r: number = Dimens.radiusLarge;
    let topRight: number = 0;
    let bottomRight: number = 0;
    if (!this.isSelected) {
      if (this.isFirst) {
        topRight = r;
        bottomRight = this.isPrevious ? r : 0;
      } else if (this.isPrevious) {
        bottomRight = r;
      } else if (this.isNext) {
        topRight = r;
      }
    }
    const radii: BorderRadiuses = { topLeft: 0, topRight: topRight, bottomLeft: 0, bottomRight: bottomRight };
    return radii;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.isSelected) {
        Row()
          .width('100%')
          .height('100%')
          .borderRadius(this.cornerRadius())
          .backgroundColor($r('app.color.bg_page'))
          .hitTestBehavior(HitTestMode.Transparent)
      }
      // left indicator (animated width 0 ↔ 3, spring)
      Row() {
        Row()
          .width(this.isSelected ? 3 : 0)
          .height(24)
          .backgroundColor(ThemeManager.instance.primary)
          .animation({ curve: curves.springMotion(0.4, 0.75) })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)
      .hitTestBehavior(HitTestMode.Transparent)

      Text(this.itemName)
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(this.isSelected ? Dimens.fontBodyMedium * 1.2 : Dimens.fontBodyMedium)
        .fontWeight(this.isSelected ? 800 : FontWeight.Normal)
        .fontColor(this.isSelected ? ThemeManager.instance.primary : $r('app.color.text_secondary'))
        .animation({ duration: 300, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height(LEFT_ITEM_HEIGHT)
    .backgroundColor($r('app.color.surface'))
    .hitTestBehavior(this.isSelected ? HitTestMode.None : HitTestMode.Default)
    .onClick(() => {
      if (!this.isSelected) {
        this.onItemClick();
      }
    })
  }
}

/** Bottom placeholder under the left list (source BottomPlaceholderItem) */
@ComponentV2
struct BottomPlaceholderItem {
  @Param isLastSelected: boolean = false;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.isLastSelected) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.surface'))
        Row()
          .width('100%')
          .height('100%')
          .borderRadius({ topLeft: 0, topRight: Dimens.radiusLarge, bottomLeft: 0, bottomRight: 0 })
          .backgroundColor($r('app.color.bg_page'))
      } else {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.bg_page'))
      }
    }
    .width('100%')
    .height(LEFT_ITEM_HEIGHT)
    .hitTestBehavior(HitTestMode.None)
  }
}

/** Sub category cell: square image (ShapeMedium) + bodySmall name (source SubCategoryItem) */
@ComponentV2
struct SubCategoryItem {
  @Param subName: string = '';
  @Param imageUrl: string = '';
  @Event onItemClick: () => void = () => {
  };

  build() {
    Column() {
      Column() {
        NetWorkImage({ model: this.imageUrl, contentScale: ImageFit.Cover, cornerRadius: Dimens.radiusMedium })
      }
      .width('100%')
      .aspectRatio(1)
      .borderRadius(Dimens.radiusMedium)
      .clip(true)

      Text(this.subName)
        .fontSize(Dimens.fontBodySmall)
        .lineHeight(Dimens.lineBodySmall)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .padding({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(8)
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
    .onClick(() => {
      this.onItemClick();
    })
  }
}
