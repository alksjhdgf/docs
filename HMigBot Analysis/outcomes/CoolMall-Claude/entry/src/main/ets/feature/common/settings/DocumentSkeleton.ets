/**
 * DocumentLoadingSkeleton — 文本文档骨架屏 (source: feature/common/skeleton/DocumentSkeleton.kt).
 * Column(fillMaxSize, padding(h = 12, v = 16), spacedBy(12)): title / meta lines + paragraphs (spacedBy(8), 18vp lines).
 */
import { SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { Dimens } from '../../../core/designsystem/Dimens';

const DOC_PARAGRAPH_LINE_HEIGHT: number = 18;

@ComponentV2
export struct DocumentParagraphSkeleton {
  @Param lineFractions: number[] = [];

  build() {
    Column({ space: Dimens.spaceVerticalSmall }) {
      ForEach(this.lineFractions, (fraction: number, index: number) => {
        SkeletonTextLine({ widthFraction: fraction, skHeight: DOC_PARAGRAPH_LINE_HEIGHT })
      }, (fraction: number, index: number) => index + '_' + fraction)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct DocumentLoadingSkeleton {
  build() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonTextLine({ widthFraction: 0.36, skHeight: 36 })
      SkeletonTextLine({ widthFraction: 0.44, skHeight: 18 })
      DocumentParagraphSkeleton({ lineFractions: [0.96, 0.92, 0.98, 0.9] })
      DocumentParagraphSkeleton({ lineFractions: [0.94, 0.88, 0.96] })
      SkeletonTextLine({ widthFraction: 0.52, skHeight: 30 })
      SkeletonTextLine({ widthFraction: 0.4, skHeight: 24 })
      DocumentParagraphSkeleton({ lineFractions: [0.97, 0.95, 0.93, 0.9, 0.86] })
      DocumentParagraphSkeleton({ lineFractions: [0.96, 0.9, 0.82] })
    }
    .width('100%')
    .height('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingLarge,
      bottom: Dimens.spacePaddingLarge
    })
    .alignItems(HorizontalAlign.Start) // source Column without horizontalAlignment = start
    .justifyContent(FlexAlign.Start)
    .clip(true)
  }
}
