/**
 * OrderLogisticsLoadingSkeleton (source: feature/order/skeleton/OrderLogisticsSkeleton.kt) — ORDA-A31.
 *
 * Column(fillMaxSize, padding 12, verticalScroll, spacedBy 12) {
 *   AddressCardSkeleton()
 *   info card  { Row(spacedBy 12) { line 0.28 (weight 1), 18 × 18 block }, OrderInfoRowSkeleton × 4 }
 *   track card { line 0.24, 4 × Row(spacedBy 12) { circle 14, Column(weight 1, spacedBy 8) { 0.9, 0.56 },
 *                8 spacer, line 0.18 } }
 * }
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonCircle, SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { AddressCardSkeleton } from '../../../core/ui/commerce/AddressCard';
import { OrderConfirmInfoRowSkeleton } from '../confirm/OrderConfirmSkeleton';

const ROW_INDICES: number[] = [0, 1, 2, 3];

@ComponentV2
export struct OrderLogisticsLoadingSkeleton {
  @Builder
  infoSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      Row({ space: Dimens.spaceHorizontalMedium }) {
        Column() {
          SkeletonTextLine({ widthFraction: 0.28 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SkeletonBlock({ skWidth: 18, skHeight: 18, skRadius: Dimens.radiusSmall })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      ForEach(ROW_INDICES, (index: number) => {
        OrderConfirmInfoRowSkeleton()
      }, (index: number) => 'logistics_info_row_' + index)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  trackRow() {
    Row({ space: Dimens.spaceHorizontalMedium }) {
      SkeletonCircle({ skSize: 14 })

      Column({ space: 8 }) {
        SkeletonTextLine({ widthFraction: 0.9 })
        SkeletonTextLine({ widthFraction: 0.56 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // Spacer(width 8) + fillMaxWidth(0.18) of the row
      Column() {
        SkeletonTextLine({ widthFraction: 1 })
      }
      .width('18%')
      // spacedBy 12 around the 8vp Spacer child: 12 (Row space) + 8 + 12
      .margin({ left: 8 + Dimens.spaceHorizontalMedium })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  trackSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.24 })
      ForEach(ROW_INDICES, (index: number) => {
        this.trackRow()
      }, (index: number) => 'logistics_track_row_' + index)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    Scroll() {
      Column({ space: Dimens.spacePaddingMedium }) {
        Column() {
          AddressCardSkeleton()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        this.infoSkeleton()
        this.trackSkeleton()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }
}
