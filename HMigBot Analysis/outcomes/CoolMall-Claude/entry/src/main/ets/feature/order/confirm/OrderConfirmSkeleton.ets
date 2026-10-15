/**
 * Confirm-order skeleton (source: feature/order/skeleton/OrderConfirmSkeleton.kt) — ORDB-A03.
 *
 * Column(fillMaxSize, padding 12, spacedBy 12) {
 *   AddressCardSkeleton(addressSelected) · OrderGoodsCardSkeleton × 2 · price detail (with discount) · remark
 * }
 * Cards are M3 Cards (bg_card, 12vp radius).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { AddressCardSkeleton } from '../../../core/ui/commerce/AddressCard';
import { SkeletonBlock, SkeletonTextLine } from '../../../core/ui/base/Skeleton';

/** Order goods card skeleton (source OrderGoodsCardSkeleton) */
@ComponentV2
export struct OrderConfirmGoodsCardSkeleton {
  build() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      Row() {
        SkeletonTextLine({ widthFraction: 0.38 })
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)

      // OrderGoodsItemSkeleton
      Row() {
        SkeletonBlock({ skWidth: 90, skHeight: 90, skRadius: Dimens.radiusSmall })

        Column({ space: Dimens.spaceVerticalMedium }) {
          SkeletonBlock({ skWidth: '48%', skRadius: Dimens.radiusXSmall })
          Row() {
            SkeletonBlock({ skWidth: '32%', skRadius: Dimens.radiusSmall })
            SkeletonBlock({ skWidth: '16%', skRadius: Dimens.radiusSmall })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .margin({ left: Dimens.spaceHorizontalMedium })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingLarge, right: Dimens.spacePaddingLarge, bottom: Dimens.spacePaddingLarge })
      // source Row without verticalAlignment = top
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding({ top: Dimens.spacePaddingMedium, bottom: Dimens.spacePaddingMedium })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}

/** Info row skeleton (source OrderInfoRowSkeleton: SpaceBetweenRow of two text lines) */
@ComponentV2
export struct OrderConfirmInfoRowSkeleton {
  @Param last: boolean = false;

  build() {
    Row() {
      SkeletonBlock({ skWidth: '26%', skRadius: Dimens.radiusSmall })
      SkeletonBlock({ skWidth: this.last ? '20%' : '30%', skRadius: Dimens.radiusSmall })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct OrderConfirmLoadingSkeleton {
  @Builder
  priceDetailSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.28 })
      OrderConfirmInfoRowSkeleton()
      OrderConfirmInfoRowSkeleton()
      // showDiscount = true
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
  remarkSkeleton() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.24 })
      SkeletonBlock({ skWidth: '100%', skHeight: 96, skRadius: Dimens.radiusMedium })
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    Column({ space: Dimens.spacePaddingMedium }) {
      Column() {
        AddressCardSkeleton({ addressSelected: true })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      OrderConfirmGoodsCardSkeleton()
      OrderConfirmGoodsCardSkeleton()
      this.priceDetailSkeleton()
      this.remarkSkeleton()
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}
