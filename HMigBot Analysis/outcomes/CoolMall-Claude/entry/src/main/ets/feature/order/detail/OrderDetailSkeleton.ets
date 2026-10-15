/**
 * OrderDetailLoadingSkeleton (source: feature/order/skeleton/OrderDetailSkeleton.kt) — ORDA-A23.
 *
 * Column(fillMaxSize, padding 12, verticalScroll, spacedBy 12) {
 *   AddressCardSkeleton() · OrderGoodsCardSkeleton × 2 ·
 *   price card { line 0.28, row, row, row(last) } · info card { line 0.24, row × 4 }
 * }
 * OrderGoodsCardSkeleton / OrderInfoRowSkeleton are shared with the confirm skeleton (same source file).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { AddressCardSkeleton } from '../../../core/ui/commerce/AddressCard';
import { OrderConfirmGoodsCardSkeleton, OrderConfirmInfoRowSkeleton } from '../confirm/OrderConfirmSkeleton';

const INFO_ROW_INDICES: number[] = [0, 1, 2, 3];

@ComponentV2
export struct OrderDetailLoadingSkeleton {
  @Builder
  priceSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.28 })
      OrderConfirmInfoRowSkeleton()
      OrderConfirmInfoRowSkeleton()
      OrderConfirmInfoRowSkeleton({ last: true })
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  infoSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.24 })
      ForEach(INFO_ROW_INDICES, (index: number) => {
        OrderConfirmInfoRowSkeleton()
      }, (index: number) => 'info_row_' + index)
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

        OrderConfirmGoodsCardSkeleton()
        OrderConfirmGoodsCardSkeleton()
        this.priceSkeleton()
        this.infoSkeleton()
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
