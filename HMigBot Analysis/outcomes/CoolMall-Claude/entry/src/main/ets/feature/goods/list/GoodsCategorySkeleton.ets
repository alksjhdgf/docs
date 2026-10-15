/**
 * GoodsCategoryLoadingSkeleton (source: feature/goods/skeleton/GoodsCategorySkeleton.kt).
 * Default two-column grid: 4 rows × 2 AppCard items (square image block + 3 text lines 0.82 / 1 / 0.44),
 * padding 12, spacing 12, vertically scrollable.
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { AppCard } from '../../../core/ui/widget/AppCard';

const SKELETON_ROWS: number[] = [0, 1, 2, 3];
const SKELETON_COLUMNS: number[] = [0, 1];

@ComponentV2
export struct GoodsCategoryLoadingSkeleton {
  @Builder
  gridItemContent() {
    Column({ space: Dimens.spaceVerticalSmall }) {
      SkeletonBlock({ skWidth: '100%', skAspectRatio: 1, skRadius: Dimens.radiusMedium })
      SkeletonTextLine({ widthFraction: 0.82 })
      SkeletonTextLine({ widthFraction: 1 })
      SkeletonTextLine({ widthFraction: 0.44 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start) // source Column default horizontalAlignment = Start
  }

  build() {
    Scroll() {
      Column({ space: Dimens.spacePaddingMedium }) {
        ForEach(SKELETON_ROWS, (row: number) => {
          Row({ space: Dimens.spacePaddingMedium }) {
            ForEach(SKELETON_COLUMNS, (col: number) => {
              Column() {
                AppCard({
                  cardContent: (): void => {
                    this.gridItemContent()
                  }
                })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }, (col: number) => 'sk_col_' + row + '_' + col)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Top) // source Row default verticalAlignment = Top
        }, (row: number) => 'sk_row_' + row)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart) // source verticalScroll column starts at the top
    .scrollBar(BarState.Off)
  }
}
