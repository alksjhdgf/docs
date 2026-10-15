/**
 * FeedbackListLoadingSkeleton (source: feature/feedback/skeleton/FeedbackListSkeleton.kt) — USER-A36.
 * Column(fill, padding 12, spacedBy 12) { item(images + reply), item(no images, no reply) }.
 * Item = Card { Column(padding 12) { SpaceBetweenRow{ Row(spacedBy 8){56×22, 64×22}, line 24% }
 *   Column(top 12, spacedBy 8){0.94, 0.82} [Row(top 12, spacedBy 8){3 × square block}]
 *   [Box(top 12, surfaceVariant, small corners, padding 12){ Column(spacedBy 8){0.22, 0.88} }] } }
 */
import { Dimens } from '../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonTextLine } from '../../core/ui/base/Skeleton';

/** Item variant */
class FeedbackSkeletonItem {
  key: string;
  showImages: boolean;
  showReply: boolean;

  constructor(key: string, showImages: boolean, showReply: boolean) {
    this.key = key;
    this.showImages = showImages;
    this.showReply = showReply;
  }
}

/** Width of the time line slot (source SkeletonTextLine(0.24f) inside a wrap-content row end) */
const TIME_LINE_WIDTH: number = 72;
/** Image placeholder gap (source 8.dp) */
const IMAGE_GAP: number = 8;

@ComponentV2
export struct FeedbackListLoadingSkeleton {
  private items: FeedbackSkeletonItem[] = [
    new FeedbackSkeletonItem('fb_sk_0', true, true),
    new FeedbackSkeletonItem('fb_sk_1', false, false)
  ];
  private imageIndices: number[] = [0, 1, 2];

  @Builder
  itemSkeleton(showImages: boolean, showReply: boolean) {
    Column() {
      Row() {
        Row({ space: Dimens.spaceHorizontalSmall }) {
          SkeletonBlock({ skWidth: 56, skHeight: 22 })
          SkeletonBlock({ skWidth: 64, skHeight: 22 })
        }
        .alignItems(VerticalAlign.Center)

        Row() {
          SkeletonBlock({ skWidth: TIME_LINE_WIDTH, skRadius: Dimens.radiusSmall })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Column({ space: Dimens.spaceVerticalSmall }) {
        SkeletonTextLine({ widthFraction: 0.94 })
        SkeletonTextLine({ widthFraction: 0.82 })
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalMedium })
      .alignItems(HorizontalAlign.Start)

      if (showImages) {
        Row({ space: IMAGE_GAP }) {
          ForEach(this.imageIndices, (i: number) => {
            Column() {
              SkeletonBlock({ skWidth: '100%', skAspectRatio: 1, skRadius: Dimens.radiusSmall })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }, (i: number) => 'fb_sk_img_' + i)
        }
        .width('100%')
        .margin({ top: Dimens.spaceVerticalMedium })
        .alignItems(VerticalAlign.Top)
      }

      if (showReply) {
        Column({ space: Dimens.spaceVerticalSmall }) {
          SkeletonTextLine({ widthFraction: 0.22 })
          SkeletonTextLine({ widthFraction: 0.88 })
        }
        .width('100%')
        .margin({ top: Dimens.spaceVerticalMedium })
        .padding(Dimens.spacePaddingMedium)
        .backgroundColor($r('app.color.bg_content'))
        .borderRadius(Dimens.radiusSmall)
        .alignItems(HorizontalAlign.Start)
      }
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
      ForEach(this.items, (item: FeedbackSkeletonItem) => {
        this.itemSkeleton(item.showImages, item.showReply)
      }, (item: FeedbackSkeletonItem) => item.key)
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}

