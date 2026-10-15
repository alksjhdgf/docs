/**
 * ChatLoadingSkeleton (source: feature/cs/skeleton/ChatSkeleton.kt) — CS-A03.
 * Column(padding h12) {
 *   Column(weight 1, padding top 8 / bottom 12, spacedBy 12) { day header, other, user, other, user }
 *   input placeholder row (bottom 16, top 8): 44vp rounded block + 68x36 primary@24% block
 * }
 */
import { Dimens } from '../../core/designsystem/Dimens';
import { ThemeManager } from '../../core/designsystem/ThemeManager';
import { SkeletonBlock, SkeletonCircle, SkeletonTextLine } from '../../core/ui/base/Skeleton';

const AVATAR_SIZE: number = 36;
const BUBBLE_HEIGHT: number = 42;

/** primary.copy(alpha = 0.24f) from the live theme color '#RRGGBB' */
function primaryAlpha24(): string {
  const hex: string = ThemeManager.instance.primary;
  return hex.length === 7 ? '#3D' + hex.substring(1) : hex;
}

const OTHER_BUBBLE_RADIUS: BorderRadiuses = { topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 };
const USER_BUBBLE_RADIUS: BorderRadiuses = { topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 };

@ComponentV2
export struct ChatLoadingSkeleton {
  @Builder
  dayHeader() {
    Row() {
      SkeletonBlock({
        skWidth: 88,
        skHeight: 24,
        skRadius: Dimens.radiusSmall,
        skColor: $r('app.color.surface')
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  otherMessage(nameWidthFraction: number, bubbleWidth: number) {
    Row() {
      SkeletonCircle({ skSize: AVATAR_SIZE })
      Column({ space: Dimens.spaceVerticalSmall }) {
        SkeletonTextLine({ widthFraction: nameWidthFraction })
        SkeletonBlock({
          skWidth: bubbleWidth,
          skHeight: BUBBLE_HEIGHT,
          skRadius: OTHER_BUBBLE_RADIUS,
          skColor: $r('app.color.surface')
        })
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalSmall })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start) // source Arrangement.Start
    .alignItems(VerticalAlign.Top) // source Alignment.Top
  }

  @Builder
  userMessage(nameWidthFraction: number, bubbleWidth: number) {
    Row() {
      Column({ space: Dimens.spaceVerticalSmall }) {
        Row() {
          SkeletonTextLine({ widthFraction: nameWidthFraction })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Top)

        SkeletonBlock({
          skWidth: bubbleWidth,
          skHeight: BUBBLE_HEIGHT,
          skRadius: USER_BUBBLE_RADIUS,
          skColor: primaryAlpha24()
        })
      }
      .layoutWeight(1)
      .margin({ right: Dimens.spaceHorizontalSmall })
      .alignItems(HorizontalAlign.End) // source horizontalAlignment = End

      SkeletonCircle({ skSize: AVATAR_SIZE })
    }
    .width('100%')
    .justifyContent(FlexAlign.End) // source Arrangement.End
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        this.dayHeader()
        this.otherMessage(0.14, 84)
        this.userMessage(0.12, 66)
        this.otherMessage(0.16, 92)
        this.userMessage(0.12, 74)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: Dimens.spacePaddingSmall, bottom: Dimens.spacePaddingMedium })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Row() {
        Row() {
          SkeletonBlock({
            skWidth: '100%',
            skHeight: 44,
            skRadius: 18,
            skColor: $r('app.color.surface')
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        Row() {
          SkeletonBlock({
            skWidth: 68,
            skHeight: 36,
            skRadius: 18,
            skColor: primaryAlpha24()
          })
        }
        .margin({ left: Dimens.spaceHorizontalSmall })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ top: Dimens.spacePaddingSmall, bottom: Dimens.spacePaddingLarge })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
    }
    .width('100%')
    .height('100%')
    .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
    .alignItems(HorizontalAlign.Start)
  }
}
