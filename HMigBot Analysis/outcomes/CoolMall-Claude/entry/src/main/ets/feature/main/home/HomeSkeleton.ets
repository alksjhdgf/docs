/**
 * HomeLoadingSkeleton (source: feature/main/skeleton/HomeSkeleton.kt) — the dedicated home first-load
 * skeleton (HOME-A08): Column(fillMaxSize, padding horizontal 12 + top 12, verticalScroll, spacedBy 12):
 *   banner block (2:1, ShapeMedium) → coupon bar → category card (2 rows × 5) → flash sale card →
 *   section title → 3 recommended goods cards.
 * Shapes / sizes follow the source; skeleton blocks take their size through params (core Skeleton).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { SkeletonBlock, SkeletonCircle, SkeletonTextLine } from '../../../core/ui/base/Skeleton';
import { AppCard } from '../../../core/ui/widget/AppCard';

/** Flash sale skeleton item width = 0.3 of the LazyRow viewport (source fillParentMaxWidth(0.3f)) */
const FLASH_ITEM_FRACTION: number = 0.3;
/** Category circle size (source size = 50.dp) */
const CATEGORY_CIRCLE_SIZE: number = 50;
/** Recommended goods image (source 108.dp) */
const RECOMMEND_IMAGE_SIZE: number = 108;

@ComponentV2
export struct HomeLoadingSkeleton {
  /** Vertical scroll offset (source: the skeleton scroll also drives the enterAlways top bar) */
  @Event onScrollOffset: (offsetY: number) => void = (offsetY: number) => {
  };

  /** Flash sale LazyRow viewport width (vp) */
  @Local flashRowWidth: number = 0;

  private scroller: Scroller = new Scroller();

  private flashItemWidth(): number {
    return this.flashRowWidth > 0 ? this.flashRowWidth * FLASH_ITEM_FRACTION : 96;
  }

  @Builder
  sectionTitleSkeleton() {
    // Row(CenterVertically, spacedBy 8).padding(vertical = 8)
    Row({ space: Dimens.spaceHorizontalSmall }) {
      SkeletonBlock({ skWidth: 3, skHeight: 18, skRadius: 999 })
      Column() {
        SkeletonTextLine({ widthFraction: 1, skHeight: 18 })
      }
      .width('32%')
      .padding({ top: 2, bottom: 2 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: Dimens.spaceVerticalSmall, bottom: Dimens.spaceVerticalSmall })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  couponSkeleton() {
    // Card { Row(fillMaxWidth, padding 12, CenterVertically, spacedBy 12) }
    Row({ space: Dimens.spaceHorizontalMedium }) {
      SkeletonBlock({ skWidth: 28, skHeight: 28, skRadius: 4 })
      Column() {
        SkeletonTextLine({ widthFraction: 1 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column() {
        SkeletonTextLine({ widthFraction: 1 })
      }
      .width('18%')
      .padding({ top: 2, bottom: 2 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  categoryRow() {
    Row({ space: 4 }) {
      ForEach([0, 1, 2, 3, 4], (i: number) => {
        Column() {
          SkeletonCircle({ skSize: CATEGORY_CIRCLE_SIZE })
          Column() {
            SkeletonTextLine({ widthFraction: 0.72, skHeight: 12 })
          }
          .width('100%')
          .margin({ top: Dimens.spaceVerticalXSmall })
          .alignItems(HorizontalAlign.Center) // source CenterHorizontally
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
      }, (i: number) => 'sk_cat_' + i)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  categoryContent() {
    Column() {
      this.categoryRow()
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalSmall)
      this.categoryRow()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  flashSaleSkeleton() {
    Column() {
      // Row(fillMaxWidth, padding h12 v12, CenterVertically)
      Row() {
        SkeletonBlock({ skWidth: 18, skHeight: 18, skRadius: 4 })
        Column() {
          SkeletonTextLine({ widthFraction: 1 })
        }
        .layoutWeight(1)
        .padding({ left: Dimens.spaceHorizontalSmall })
        .alignItems(HorizontalAlign.Start)
        Column() {
          SkeletonTextLine({ widthFraction: 1, skHeight: 14 })
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
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // LazyRow(spacedBy 8).padding(12)
      Column() {
        Scroll() {
          Row({ space: Dimens.spaceHorizontalSmall }) {
            ForEach([0, 1, 2, 3], (i: number) => {
              Column({ space: Dimens.spaceVerticalSmall }) {
                SkeletonBlock({ skWidth: '100%', skAspectRatio: 1 })
                SkeletonTextLine({ widthFraction: 0.84 })
                SkeletonTextLine({ widthFraction: 0.52 })
              }
              .width(this.flashItemWidth())
              .alignItems(HorizontalAlign.Start)
            }, (i: number) => 'sk_flash_' + i)
          }
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.flashRowWidth = newArea.width as number;
        })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  recommendCardContent() {
    Row({ space: Dimens.spacePaddingMedium }) {
      SkeletonBlock({ skWidth: RECOMMEND_IMAGE_SIZE, skHeight: RECOMMEND_IMAGE_SIZE, skRadius: Dimens.radiusMedium })
      Column({ space: Dimens.spaceVerticalSmall }) {
        SkeletonTextLine({ widthFraction: 0.72 })
        SkeletonTextLine({ widthFraction: 1 })
        SkeletonTextLine({ widthFraction: 0.88 })
        // Spacer(weight 1): no extra height inside the vertical scroll (unbounded), still one gap
        Column()
          .width('100%')
          .height(0)
        SkeletonTextLine({ widthFraction: 0.32 })
      }
      .layoutWeight(1)
      .padding({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Dimens.spacePaddingMedium }) {
        SkeletonBlock({ skWidth: '100%', skAspectRatio: 2, skRadius: Dimens.radiusMedium })
        this.couponSkeleton()
        AppCard({
          cardContent: (): void => {
            this.categoryContent()
          }
        })
        this.flashSaleSkeleton()
        this.sectionTitleSkeleton()
        Column({ space: Dimens.spacePaddingMedium }) {
          ForEach([0, 1, 2], (i: number) => {
            AppCard({
              cardContent: (): void => {
                this.recommendCardContent()
              }
            })
          }, (i: number) => 'sk_rec_' + i)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium, top: Dimens.spacePaddingMedium })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .onDidScroll(() => {
      this.onScrollOffset(this.scroller.currentOffset().yOffset);
    })
  }
}
