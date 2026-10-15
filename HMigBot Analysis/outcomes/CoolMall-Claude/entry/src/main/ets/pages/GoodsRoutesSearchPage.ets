/**
 * GoodsRoutesSearchPage — goods search (source: feature/goods/view/GoodsSearchScreen.kt,
 * viewmodel/GoodsSearchViewModel.kt).
 *
 * Layout (Column, background bg_page):
 *  - SearchTopAppBar (surface, padded by the status bar — GOODS-A26): back, input `输入内容进行搜索`, `搜索`
 *    (button or IME search → vm.onSearch).
 *  - NetWorkStateView on the recommended keyword request (loading / error + retry); success content scrolls:
 *      `搜索历史` header + delete icon (clear all) + history tags — only when history exists, then 4vp,
 *      `推荐搜索` + keyword tags (VerticalList: padding 12, spacedBy 12).
 *  - Any tag / submit → vm.onSearch (blank ignored; history written, then GoodsRoutesCategory(keyword)).
 */
import { LengthMetrics } from '@kit.ArkUI';
import { Dimens } from '../core/designsystem/Dimens';
import { GoodsSearchKeyword } from '../core/model/Goods';
import { SearchHistory } from '../core/model/Market';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { SearchTopAppBar } from '../core/ui/base/TopAppBars';
import { GoodsSearchViewModel } from '../feature/goods/list/GoodsSearchViewModel';

/** Tag flow spacing (SpaceHorizontalSmall / SpaceVerticalSmall) */
const TAG_SPACING: number = 8;

@Builder
export function GoodsRoutesSearchPageBuilder() {
  GoodsRoutesSearchPage()
}

@ComponentV2
struct GoodsRoutesSearchPage {
  @Local vm: GoodsSearchViewModel = new GoodsSearchViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();

  aboutToAppear(): void {
    this.vm.init();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private keywordList(): GoodsSearchKeyword[] {
    const data: GoodsSearchKeyword[] | null = this.vm.data;
    return data !== null ? data : [];
  }

  /** Rounded tag (source SearchHistoryTag: Card(ShapeCircle) + text padding 16 / 8) */
  @Builder
  searchTag(text: string, isHistory: boolean) {
    Row() {
      Text(text)
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
    }
    .padding({
      left: Dimens.spaceHorizontalLarge,
      right: Dimens.spaceHorizontalLarge,
      top: Dimens.spaceVerticalSmall,
      bottom: Dimens.spaceVerticalSmall
    })
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusCircle)
    .clip(true)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (isHistory) {
        const h = new SearchHistory();
        h.keyword = text;
        this.vm.onSearchHistoryClick(h);
      } else {
        this.vm.onKeywordClick(text);
      }
    })
  }

  @Builder
  sectionTitle(title: Resource) {
    Text(title)
      .fontSize(Dimens.fontTitleLarge)
      .lineHeight(Dimens.lineTitleLarge)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
  }

  @Builder
  searchHistorySection() {
    Column() {
      // AppListItem(leading = title, trailing = delete icon, no arrow / divider / padding)
      Row() {
        this.sectionTitle($r('app.string.search_history'))
        Image($r('app.media.ic_delete'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.vm.clearSearchHistory();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Start,
        space: { main: LengthMetrics.vp(TAG_SPACING), cross: LengthMetrics.vp(TAG_SPACING) }
      }) {
        ForEach(this.vm.searchHistoryList, (item: SearchHistory) => {
          this.searchTag(item.keyword, true)
        }, (item: SearchHistory) => 'history_' + item.keyword + '_' + item.searchTime)
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalSmall })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  recommendSection() {
    Column() {
      this.sectionTitle($r('app.string.recommended_search'))
      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Start,
        space: { main: LengthMetrics.vp(TAG_SPACING), cross: LengthMetrics.vp(TAG_SPACING) }
      }) {
        ForEach(this.keywordList(), (item: GoodsSearchKeyword, index: number) => {
          this.searchTag(item.name, false)
        }, (item: GoodsSearchKeyword, index: number) => 'keyword_' + index + '_' + item.id + '_' + item.name)
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalSmall })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  successContent() {
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        if (this.vm.searchHistoryList.length > 0) {
          this.searchHistorySection()
          // SpaceVerticalXSmall
          Column()
            .width('100%')
            .height(Dimens.spaceVerticalXSmall)
        }
        this.recommendSection()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }

  build() {
    NavDestination() {
      Column() {
        SearchTopAppBar({
          onSearch: (text: string) => {
            this.vm.onSearch(text);
          }
        })
        Column() {
          NetWorkStateView({
            uiState: this.vm.uiState,
            content: (): void => {
              this.successContent()
            },
            onRetry: () => {
              this.vm.retryRequest();
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
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
  }
}
