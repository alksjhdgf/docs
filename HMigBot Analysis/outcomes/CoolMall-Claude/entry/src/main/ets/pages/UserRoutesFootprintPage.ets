/**
 * UserRoutesFootprintPage — 我的足迹 (source: feature/user/view/FootprintScreen.kt + FootprintViewModel.kt).
 *
 * AppScaffold(title = footprint_title): the top bar pads itself by the status bar (USER-A25).
 * Top bar action (footprints not empty): TextButton `清空 (%d)` (footprintCount, primary) → clearAllFootprints()
 * with no confirmation (USER-A27).
 * Content (AnimatedContent fade 300ms): Loading → PageLoading; Empty → EmptyData (`暂无数据`);
 * Success → LazyVerticalStaggeredGrid(Fixed(2), contentPadding 12, spacing 12) of GoodsGridItem
 * (image / title / price / sold); tap → goods detail (USER-A26).
 * Footprint is not login-required (USER-A01); data lives in the local `footprints` table (USER-A28/A29).
 */
import { Routes } from '../common/Router';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { Footprint } from '../core/model/Market';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { GoodsDetailParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyData, PageLoading } from '../core/ui/base/StateViews';
import { GoodsGridItem } from '../core/ui/commerce/GoodsItems';
import { FootprintUiState } from '../feature/user/profile/FootprintUiState';
import { FootprintViewModel } from '../feature/user/profile/FootprintViewModel';

/** AnimatedContent fade (tween(300)) */
const STATE_FADE_MS: number = 300;
/** M3 TextButton: height 40, horizontal content padding 12 */
const TEXT_BUTTON_HEIGHT: number = 40;
const TEXT_BUTTON_H_PADDING: number = 12;

@Builder
export function UserRoutesFootprintPageBuilder() {
  UserRoutesFootprintPage()
}

@ComponentV2
struct UserRoutesFootprintPage {
  @Local vm: FootprintViewModel = new FootprintViewModel();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  /** GoodsNavigator.toDetail(goodsId) */
  private toGoodsDetail(goodsId: number): void {
    const param = new GoodsDetailParam();
    param.goodsId = goodsId;
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, param);
  }

  @Builder
  topBarActions() {
    if (this.vm.footprints.length > 0) {
      // TextButton(onClick = onClearAll) { Text(clear_with_count(footprintCount), color = primary) }
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text($r('app.string.clear_with_count', this.vm.footprintCount))
          .fontSize(Dimens.fontBodyLarge)
          .fontWeight(Dimens.weightMedium)
          .fontColor(ThemeManager.instance.primary)
      }
      .height(TEXT_BUTTON_HEIGHT)
      .padding({ left: TEXT_BUTTON_H_PADDING, right: TEXT_BUTTON_H_PADDING })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.vm.clearAllFootprints();
      })
    }
  }

  @Builder
  footprintGrid() {
    // LazyVerticalStaggeredGrid(Fixed(2), contentPadding 12, horizontal/vertical spacing 12)
    WaterFlow() {
      ForEach(this.vm.footprints, (item: Footprint) => {
        FlowItem() {
          GoodsGridItem({
            goods: FootprintViewModel.toGoods(item),
            onGoodsClick: (goodsId: number) => {
              this.toGoodsDetail(goodsId);
            }
          })
        }
        .width('100%')
      }, (item: Footprint): string => item.goodsId + '_' + item.viewTime + '_' + item.goodsName + '_' +
        item.goodsPrice + '_' + item.goodsSold + '_' + item.goodsMainPic)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(Dimens.spacePaddingMedium)
    .rowsGap(Dimens.spacePaddingMedium)
    .padding(Dimens.spacePaddingMedium)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  footprintContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.vm.uiState === FootprintUiState.Loading) {
        Column() {
          PageLoading()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      } else if (this.vm.uiState === FootprintUiState.Empty) {
        Column() {
          EmptyData()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      } else {
        Column() {
          this.footprintGrid()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.footprint_title'),
        topBarActions: (): void => {
          this.topBarActions()
        },
        content: (): void => {
          this.footprintContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
