/**
 * CouponLoadingSkeleton (source: feature/market/skeleton/CouponSkeleton.kt) — USER-A31 first-load skeleton.
 * Column(fill, padding 12, spacedBy 12) { 3 × CouponItemSkeleton }.
 * CouponItemSkeleton = Card { Row(padding 12, centerV){ 46 block · 12 · Column(weight 1, spacedBy 8){0.82, 0.48}
 *   · 12 · Column(end, spacedBy 4){0.42, 0.58} } · WeDivider · Row(padding 12/12, centerV){
 *   Row(weight 1){ line 32% · 4 · 16×16 block } · 12 · 92×32 block } }.
 */
import { Dimens } from '../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonTextLine } from '../../core/ui/base/Skeleton';
import { WeDivider } from '../../core/ui/widget/AppCard';

/** Width of the trailing (end-aligned) text column; source wraps content of fractional lines */
const TRAILING_COLUMN_WIDTH: number = 72;

@ComponentV2
export struct CouponLoadingSkeleton {
  private indices: number[] = [0, 1, 2];

  @Builder
  itemSkeleton() {
    Column() {
      Row() {
        SkeletonBlock({ skWidth: 46, skHeight: 46, skRadius: Dimens.radiusSmall })
        Column({ space: Dimens.spaceVerticalSmall }) {
          SkeletonTextLine({ widthFraction: 0.82 })
          SkeletonTextLine({ widthFraction: 0.48 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })

        Column({ space: Dimens.spaceHorizontalXSmall }) {
          SkeletonBlock({ skWidth: TRAILING_COLUMN_WIDTH * 0.42, skRadius: Dimens.radiusSmall })
          SkeletonBlock({ skWidth: TRAILING_COLUMN_WIDTH * 0.58, skRadius: Dimens.radiusSmall })
        }
        .width(TRAILING_COLUMN_WIDTH)
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(VerticalAlign.Center)

      WeDivider()

      Row() {
        Row() {
          Row() {
            SkeletonTextLine({ widthFraction: 1 })
          }
          .width('32%')
          .alignItems(VerticalAlign.Center)

          Row() {
            SkeletonBlock({ skWidth: 16, skHeight: 16, skRadius: Dimens.radiusSmall })
          }
          .margin({ left: Dimens.spaceHorizontalXSmall })
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)

        Row() {
          SkeletonBlock({ skWidth: 92, skHeight: 32, skRadius: Dimens.radiusSmall })
        }
        .margin({ left: Dimens.spaceHorizontalMedium })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({
        left: Dimens.spacePaddingMedium,
        right: Dimens.spacePaddingMedium,
        top: Dimens.spaceVerticalMedium,
        bottom: Dimens.spaceVerticalMedium
      })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    Column({ space: Dimens.spacePaddingMedium }) {
      ForEach(this.indices, (i: number) => {
        this.itemSkeleton()
      }, (i: number) => 'coupon_sk_' + i)
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}
