/**
 * GoodsCommentLoadingSkeleton (source: feature/goods/skeleton/GoodsCommentSkeleton.kt) — GOODS-A19.
 *
 * Scroll Column(padding 12, spacedBy 12) { comment card skeleton with a 2x3 image grid ; one without images }
 * Card: Row(padding 12) { circle 40 | 12 | Column(weight 1, spacedBy 4) {
 *   Row(spacedBy 12) { 42 % line (weight 1) | 52 % line (weight 1) } ; 30 % line ;
 *   Column(spacedBy 4) { 100 % / 92 % / 58 % lines } ; [8 + image grid] } }
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonCircle, SkeletonTextLine } from '../../../core/ui/base/Skeleton';

const GRID_SPACING: number = 8;

@ComponentV2
export struct GoodsCommentLoadingSkeleton {
  private scroller: Scroller = new Scroller();

  @Builder
  imageGrid() {
    Column({ space: GRID_SPACING }) {
      ForEach([0, 1], (r: number) => {
        Row({ space: GRID_SPACING }) {
          ForEach([0, 1, 2], (c: number) => {
            Column() {
              SkeletonBlock({ skWidth: '100%', skAspectRatio: 1, skRadius: Dimens.radiusSmall })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }, (c: number) => 'cell_' + r + '_' + c)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Start)
      }, (r: number) => 'row_' + r)
    }
    .width('100%')
    // source: SpaceVerticalSmall() is itself a spacedBy(4) child → 8 + 4 extra before the grid
    .margin({ top: Dimens.spaceVerticalSmall + Dimens.spaceVerticalXSmall })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  cardSkeleton(showImages: boolean) {
    Row() {
      SkeletonCircle({ skSize: 40 })
      Column({ space: Dimens.spaceVerticalXSmall }) {
        Row({ space: Dimens.spaceHorizontalMedium }) {
          Column() {
            SkeletonTextLine({ widthFraction: 0.42 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Column() {
            SkeletonTextLine({ widthFraction: 0.52 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Start)

        SkeletonTextLine({ widthFraction: 0.3 })

        Column({ space: Dimens.spaceVerticalXSmall }) {
          SkeletonTextLine({ widthFraction: 1 })
          SkeletonTextLine({ widthFraction: 0.92 })
          SkeletonTextLine({ widthFraction: 0.58 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (showImages) {
          this.imageGrid()
        }
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Dimens.spacePaddingMedium }) {
        this.cardSkeleton(true)
        this.cardSkeleton(false)
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
}
