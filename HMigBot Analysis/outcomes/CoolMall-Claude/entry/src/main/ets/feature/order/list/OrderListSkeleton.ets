/**
 * OrderListLoadingSkeleton (source: feature/order/skeleton/OrderListSkeleton.kt) — first-load skeleton of
 * each order tab (ORDA-A09): 3 cards { order no. / status lines, 3 × 80vp thumbnails + price lines,
 * divider, 2 button blocks (74 × 30) at the end }.
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { WeDivider } from '../../../core/ui/widget/AppCard';

const THUMB_INDICES: number[] = [0, 1, 2];
const BUTTON_INDICES: number[] = [0, 1];
const CARD_INDICES: number[] = [0, 1, 2];

@ComponentV2
export struct OrderListLoadingSkeleton {
  @Builder
  cardSkeleton() {
    Column() {
      // SpaceBetweenRow(padding 12) { line 0.38, line 0.18 }
      Row() {
        Column() {
          SkeletonTextLine({ widthFraction: 1 })
        }
        .width('38%')
        .alignItems(HorizontalAlign.Start)

        Column() {
          SkeletonTextLine({ widthFraction: 1 })
        }
        .width('18%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // Row(padding h12, bottom 12) { 3 × 80 blocks (8 apart), Spacer(weight 1), Column(spacedBy 8) { 0.64, 0.44 } }
      Row() {
        ForEach(THUMB_INDICES, (index: number) => {
          Row() {
            SkeletonBlock({ skWidth: 80, skHeight: 80, skRadius: Dimens.radiusSmall })
          }
          .margin({ right: index !== 2 ? Dimens.spaceHorizontalSmall : 0 })
          .alignItems(VerticalAlign.Top)
        }, (index: number) => 'thumb_' + index)

        // Spacer(weight 1) + wrap Column: the column is 64% of the remaining width, anchored at the end
        Column() {
          Column({ space: Dimens.spaceVerticalSmall }) {
            SkeletonTextLine({ widthFraction: 1 })
            SkeletonTextLine({ widthFraction: 0.44 / 0.64 })
          }
          .width('64%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium, bottom: Dimens.spacePaddingMedium })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)

      WeDivider()

      // Row(padding 12, Arrangement.End) { 2 × (74 × 30) }
      Row() {
        ForEach(BUTTON_INDICES, (index: number) => {
          Row() {
            SkeletonBlock({ skWidth: 74, skHeight: 30, skRadius: Dimens.radiusSmall })
          }
          .margin({ right: index !== 1 ? Dimens.spaceHorizontalSmall : 0 })
          .alignItems(VerticalAlign.Top)
        }, (index: number) => 'btn_' + index)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    // Column(fillMaxSize, padding 12, spacedBy 12)
    Column({ space: Dimens.spacePaddingMedium }) {
      ForEach(CARD_INDICES, (index: number) => {
        this.cardSkeleton()
      }, (index: number) => 'card_' + index)
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}
