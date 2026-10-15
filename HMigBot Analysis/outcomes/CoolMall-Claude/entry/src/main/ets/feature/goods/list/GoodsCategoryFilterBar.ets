/**
 * Category goods list sort / filter bar (source: GoodsCategoryScreen.kt FilterBar, FilterButton,
 * SortButtonWithArrows, SortArrows, LayoutToggleButton).
 *
 * Row(padding horizontal 12, CenterVertically):
 *  - `筛选` pill (ic_filter 14 + text, 32vp high, bg_page) — hidden while the filter dialog is visible
 *  - `综合` / `销量`▲▼ / `价格`▲▼ pills (start margin 8, 32vp high, primary@0.1 background when selected)
 *  - weight spacer, then the grid/list toggle when the top bar is collapsed (scale in/out)
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { SortState } from './SortState';
import { SortType } from './SortType';

/** FilterButton height 32.dp */
const PILL_HEIGHT: number = 32;
/** onSurfaceVariant @ 0.4 (inactive arrow) / @ 0.6 (filter icon) */
const INACTIVE_ARROW_OPACITY: number = 0.4;
const FILTER_ICON_OPACITY: number = 0.6;

/** Grid ↔ list toggle (source LayoutToggleButton): 24vp icon in a 4vp padded circle */
@ComponentV2
export struct LayoutToggleButton {
  @Param isGridLayout: boolean = true;
  @Event onToggleLayout: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Center }) { // icon fills the padded box
      Image(this.isGridLayout ? $r('app.media.ic_menu_list') : $r('app.media.ic_menu'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_primary'))
    }
    .padding(Dimens.spacePaddingXSmall)
    .borderRadius(Dimens.radiusCircle)
    .clip(true)
    .onClick(() => {
      this.onToggleLayout();
    })
  }
}

@ComponentV2
export struct GoodsCategoryFilterBar {
  @Param filtersVisible: boolean = false;
  @Param currentSortType: SortType = SortType.COMPREHENSIVE;
  @Param currentSortState: SortState = SortState.NONE;
  @Param isGridLayout: boolean = true;
  /** Top bar collapsedFraction >= 0.8 */
  @Param showLayoutToggle: boolean = false;
  @Event onFiltersClick: () => void = () => {
  };
  @Event onSortClick: (sortType: SortType) => void = (sortType: SortType) => {
  };
  @Event onToggleLayout: () => void = () => {
  };

  private isArrowSelected(sortType: SortType): boolean {
    return this.currentSortType === sortType && this.currentSortState !== SortState.NONE;
  }

  private pillBackground(selected: boolean): ResourceColor {
    return selected ? ThemeManager.withAlpha(ThemeManager.instance.primary, 0.1) : $r('app.color.bg_page');
  }

  private arrowColor(sortType: SortType, state: SortState): ResourceColor {
    if (this.currentSortType === sortType && this.currentSortState === state) {
      return ThemeManager.instance.primary;
    }
    return $r('app.color.text_secondary');
  }

  private arrowOpacity(sortType: SortType, state: SortState): number {
    return (this.currentSortType === sortType && this.currentSortState === state) ? 1 : INACTIVE_ARROW_OPACITY;
  }

  @Builder
  sortButtonWithArrows(textRes: Resource, sortType: SortType) {
    Row() {
      Text(textRes)
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor(this.isArrowSelected(sortType) ? ThemeManager.instance.primary : $r('app.color.text_primary'))
      Column() {
        Image($r('app.media.ic_up_triangle'))
          .width(6)
          .height(6)
          .objectFit(ImageFit.Contain)
          .fillColor(this.arrowColor(sortType, SortState.ASC))
          .opacity(this.arrowOpacity(sortType, SortState.ASC))
        Image($r('app.media.ic_down_triangle'))
          .width(6)
          .height(6)
          .objectFit(ImageFit.Contain)
          .fillColor(this.arrowColor(sortType, SortState.DESC))
          .opacity(this.arrowOpacity(sortType, SortState.DESC))
      }
      .padding({ left: Dimens.spaceVerticalXSmall })
      .alignItems(HorizontalAlign.Start) // source Column default horizontalAlignment = Start
    }
    .height(PILL_HEIGHT)
    .margin({ left: Dimens.spaceHorizontalSmall })
    .padding({ left: Dimens.spaceHorizontalLarge, right: Dimens.spaceHorizontalLarge })
    .borderRadius(PILL_HEIGHT / 2)
    .clip(true)
    .backgroundColor(this.pillBackground(this.isArrowSelected(sortType)))
    .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
    .alignItems(VerticalAlign.Center) // source Row(verticalAlignment = CenterVertically)
    .onClick(() => {
      this.onSortClick(sortType);
    })
  }

  build() {
    Row() {
      if (!this.filtersVisible) {
        Row() {
          Image($r('app.media.ic_filter'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.text_secondary'))
            .opacity(FILTER_ICON_OPACITY)
          Text($r('app.string.filter'))
            .fontSize(Dimens.fontBodyMedium)
            .lineHeight(Dimens.lineBodyMedium)
            .fontColor($r('app.color.text_primary'))
        }
        .height(PILL_HEIGHT)
        .padding({ left: Dimens.spaceHorizontalLarge, right: Dimens.spaceHorizontalLarge })
        .borderRadius(PILL_HEIGHT / 2)
        .clip(true)
        .backgroundColor($r('app.color.bg_page'))
        .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
        .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0, y: 0 }))
          .animation({ duration: 300 }))
        .onClick(() => {
          this.onFiltersClick();
        })
      }

      // 综合
      Row() {
        Text($r('app.string.comprehensive'))
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor(this.currentSortType === SortType.COMPREHENSIVE ? ThemeManager.instance.primary :
          $r('app.color.text_primary'))
      }
      .height(PILL_HEIGHT)
      .margin({ left: Dimens.spaceHorizontalSmall })
      .padding({ left: Dimens.spaceHorizontalLarge, right: Dimens.spaceHorizontalLarge })
      .borderRadius(PILL_HEIGHT / 2)
      .clip(true)
      .backgroundColor(this.pillBackground(this.currentSortType === SortType.COMPREHENSIVE))
      .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onSortClick(SortType.COMPREHENSIVE);
      })

      this.sortButtonWithArrows($r('app.string.sales'), SortType.SALES)
      this.sortButtonWithArrows($r('app.string.price'), SortType.PRICE)

      Blank()
        .layoutWeight(1)

      if (this.showLayoutToggle) {
        Row() {
          LayoutToggleButton({
            isGridLayout: this.isGridLayout,
            onToggleLayout: () => {
              this.onToggleLayout();
            }
          })
        }
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.scale({ x: 0, y: 0 }).animation({ duration: 300 }))
      }
    }
    .width('100%')
    .padding({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
  }
}
