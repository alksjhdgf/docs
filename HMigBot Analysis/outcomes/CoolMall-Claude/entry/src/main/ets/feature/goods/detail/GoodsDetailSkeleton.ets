/**
 * GoodsDetailLoadingSkeleton (source: feature/goods/skeleton/GoodsDetailSkeleton.kt) — GOODS-A01.
 *
 * Scroll Column { square banner block (bottom corners 12) ; Column(padding 12, spacedBy 12) {
 *   info card | delivery card | comments card | detail section } ; Spacer 120 }
 * Text lines inside SpaceBetween rows use SkeletonBlock with a percent width (source fillMaxWidth(fraction)
 * measured against the row width).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonCircle, SkeletonTextLine } from '../../../core/ui/base/Skeleton';

const FULL_RADIUS: number = 999;
/** RoundedCornerShape(bottomStart = 12, bottomEnd = 12) */
const BOTTOM_ROUNDED: BorderRadiuses = {
  topLeft: 0,
  topRight: 0,
  bottomLeft: Dimens.radiusMedium,
  bottomRight: Dimens.radiusMedium
};

@ComponentV2
export struct GoodsDetailLoadingSkeleton {
  private scroller: Scroller = new Scroller();

  /** TitleWithLine skeleton: 3x18 bar + 28 % line (18 high), spacedBy 8 */
  @Builder
  sectionTitle() {
    Row({ space: Dimens.spaceHorizontalSmall }) {
      SkeletonBlock({ skWidth: 3, skHeight: 18, skRadius: FULL_RADIUS })
      Column() {
        SkeletonTextLine({ widthFraction: 0.28, skHeight: 18 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  listItemSkeleton(showDivider: boolean) {
    Column() {
      Row() {
        SkeletonBlock({ skWidth: '18%', skHeight: 16, skRadius: Dimens.radiusSmall })
        SkeletonBlock({ skWidth: 120, skHeight: 16, skRadius: Dimens.radiusSmall })
      }
      .width('100%')
      .padding({ top: Dimens.spaceVerticalSmall, bottom: Dimens.spaceVerticalSmall })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      if (showDivider) {
        Column()
          .width('100%')
          .height(Dimens.spacePaddingXSmall)
      }
    }
    .width('100%')
    .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  infoCard() {
    Column() {
      Row() {
        SkeletonBlock({ skWidth: '34%', skHeight: 28, skRadius: Dimens.radiusSmall })
        SkeletonBlock({ skWidth: 72, skHeight: 28, skRadius: FULL_RADIUS })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row({ space: Dimens.spaceHorizontalSmall }) {
        SkeletonBlock({ skWidth: 92, skHeight: 28, skRadius: Dimens.spaceVerticalXSmall })
        SkeletonBlock({ skWidth: 92, skHeight: 28, skRadius: Dimens.spaceVerticalXSmall })
      }
      .margin({ top: Dimens.spaceVerticalMedium, bottom: Dimens.spaceVerticalMedium })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)

      SkeletonTextLine({ widthFraction: 0.86, skHeight: 24 })
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalXSmall)
      SkeletonTextLine({ widthFraction: 1 })
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      Row() {
        SkeletonBlock({ skWidth: '56%', skHeight: 16, skRadius: Dimens.radiusSmall })
        SkeletonBlock({ skWidth: 18, skHeight: 18, skRadius: FULL_RADIUS })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(Dimens.radiusSmall)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  deliveryCard() {
    Column({ space: Dimens.spaceVerticalXSmall }) {
      Row() {
        this.sectionTitle()
      }
      .width('100%')
      .padding({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)
      this.listItemSkeleton(true)
      this.listItemSkeleton(false)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  commentRow() {
    Row({ space: Dimens.spacePaddingMedium }) {
      SkeletonCircle({ skSize: 40 })
      Column({ space: Dimens.spaceVerticalSmall }) {
        SkeletonTextLine({ widthFraction: 0.32 })
        SkeletonTextLine({ widthFraction: 1 })
        SkeletonTextLine({ widthFraction: 0.74 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spaceVerticalSmall,
      bottom: Dimens.spaceVerticalSmall
    })
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  commentsCard() {
    Column() {
      Row() {
        Column() {
          this.sectionTitle()
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column() {
          SkeletonBlock({ skWidth: '100%', skHeight: 14, skRadius: Dimens.radiusSmall })
        }
        .width('18%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: Dimens.spacePaddingMedium,
        right: Dimens.spacePaddingMedium,
        top: Dimens.spaceVerticalMedium,
        bottom: Dimens.spaceVerticalMedium
      })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)

      this.commentRow()
      Column() {
        SkeletonBlock({
          skWidth: '100%',
          skHeight: 1,
          skRadius: 0,
          skColor: $r('app.color.border'),
          shimmerEnabled: false
        })
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
      .opacity(0.35)
      .alignItems(HorizontalAlign.Start)
      this.commentRow()
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  contentSection() {
    Column() {
      Row() {
        this.sectionTitle()
      }
      .width('100%')
      .padding({
        left: Dimens.spacePaddingMedium,
        right: Dimens.spacePaddingMedium,
        top: Dimens.spaceVerticalMedium,
        bottom: Dimens.spaceVerticalMedium
      })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)

      SkeletonBlock({ skWidth: '100%', skHeight: 220 - Dimens.spaceVerticalXSmall, skRadius: 0 })
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalXSmall)
      SkeletonBlock({ skWidth: '100%', skHeight: 220 - Dimens.spaceVerticalXSmall, skRadius: 0 })
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalXSmall)
      SkeletonBlock({
        skWidth: '100%',
        skHeight: 220,
        skRadius: BOTTOM_ROUNDED
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: Dimens.radiusMedium, topRight: Dimens.radiusMedium })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        SkeletonBlock({
          skWidth: '100%',
          skAspectRatio: 1,
          skRadius: BOTTOM_ROUNDED
        })
        Column({ space: Dimens.spaceVerticalMedium }) {
          this.infoCard()
          this.deliveryCard()
          this.commentsCard()
          this.contentSection()
        }
        .width('100%')
        .padding(Dimens.spacePaddingMedium)
        .alignItems(HorizontalAlign.Start)
        Column()
          .width('100%')
          .height(120)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }
}
