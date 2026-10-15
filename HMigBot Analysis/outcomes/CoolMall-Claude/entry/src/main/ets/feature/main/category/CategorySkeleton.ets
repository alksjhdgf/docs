/**
 * CategoryLoadingSkeleton (source: feature/main/skeleton/CategorySkeleton.kt).
 * Left 100vp menu (8 rows x 50vp, first row on surface with a 3x24 indicator) + right content
 * (4 sections: line title + 2 rows x 3 cells of 92vp image + text line).
 */
import { SkeletonBlock, SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { Dimens } from '../../../core/designsystem/Dimens';

const LEFT_ROWS: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
const RIGHT_SECTIONS: number[] = [0, 1, 2, 3];
const GRID_ROWS: number[] = [0, 1];
const GRID_COLS: number[] = [0, 1, 2];

@ComponentV2
export struct CategoryLoadingSkeleton {
  @Builder
  leftMenu() {
    Column() {
      ForEach(LEFT_ROWS, (index: number) => {
        // source Box(contentAlignment = Center)
        Stack({ alignContent: Alignment.Center }) {
          // source SkeletonTextLine(widthFraction 0.56) centered by the Box
          SkeletonBlock({ skWidth: '56%', skHeight: 14, skRadius: Dimens.radiusSmall })
          if (index === 0) {
            // source SkeletonBlock.align(CenterStart), 3x24, right corners RadiusLarge
            Row() {
              SkeletonBlock({
                skWidth: 3,
                skHeight: 24,
                skRadius: { topRight: Dimens.radiusLarge, bottomRight: Dimens.radiusLarge }
              })
            }
            .width('100%')
            .height('100%')
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Start)
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
        .width('100%')
        .height(50)
        .backgroundColor(index === 0 ? $r('app.color.surface') : $r('app.color.bg_page'))
      }, (index: number) => 'sk_left_' + index)
    }
    .alignItems(HorizontalAlign.Start)
    .width(100)
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  @Builder
  rightContent() {
    Scroll() {
      Column({ space: 24 }) {
        ForEach(RIGHT_SECTIONS, (section: number) => {
          Column({ space: Dimens.spaceVerticalMedium }) {
            Row({ space: Dimens.spaceVerticalSmall }) {
              SkeletonBlock({ skWidth: 3, skHeight: 18, skRadius: Dimens.radiusCircle })
              Row() {
                SkeletonTextLine({ widthFraction: 0.3, skHeight: 18 })
              }
              .layoutWeight(1)
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Start)

            ForEach(GRID_ROWS, (row: number) => {
              Row({ space: Dimens.spacePaddingMedium }) {
                ForEach(GRID_COLS, (col: number) => {
                  Column({ space: Dimens.spaceVerticalSmall }) {
                    SkeletonBlock({ skWidth: '100%', skHeight: 92, skRadius: Dimens.radiusMedium })
                    SkeletonTextLine({ widthFraction: 0.72, skHeight: 12 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }, (col: number) => 'sk_col_' + section + '_' + row + '_' + col)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .justifyContent(FlexAlign.Start)
            }, (row: number) => 'sk_row_' + section + '_' + row)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (section: number) => 'sk_section_' + section)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8, right: 8, top: 16, bottom: 16 })
    }
    .layoutWeight(1)
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.surface'))
  }

  build() {
    Row() {
      this.leftMenu()
      this.rightContent()
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }
}
