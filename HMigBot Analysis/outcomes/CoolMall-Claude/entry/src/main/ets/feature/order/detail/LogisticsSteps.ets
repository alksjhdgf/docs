/**
 * LogisticsSteps (source: feature/order/component/LogisticsSteps.kt) — ORDA-A34.
 *
 * Vertical step timeline in list order (latest first). Each item (source Box + drawBehind):
 *   dot centred at (12, 12): first item radius 5 in the active color (colorScheme.primary), others radius 4
 *   in colorScheme.outline; connecting 1vp line from y = 24 to the item bottom (outline), except the last item.
 *   content: start padding 36, bottom padding 16 (0 for the last), min height 40;
 *   status (if any): BODY_MEDIUM, PRIMARY + Medium for the first item / SECONDARY + Normal, bottom 4;
 *   time (if any): BODY_SMALL TERTIARY.
 * The drawn dot/line are rebuilt with a stretched 24vp gutter column (Flex ItemAlign.Stretch) so the line
 * spans the full item height, as drawBehind did.
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { LogisticsItem } from '../../../core/model/Order';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';

/** drawBehind offset 12.dp: dot centre x/y */
const STEP_OFFSET: number = 12;
/** Content start padding 36.dp */
const STEP_CONTENT_START: number = 36;
/** Bottom padding of non-last items 16.dp */
const STEP_BOTTOM_PADDING: number = 16;
/** sizeIn(minHeight = 40.dp) */
const STEP_MIN_HEIGHT: number = 40;

@ComponentV2
export struct LogisticsSteps {
  /** Logistics track, newest first (source logisticsItems) */
  @Param logisticsItems: LogisticsItem[] = [];

  private textOf(v: string | null | undefined): string | null {
    return (v !== null && v !== undefined) ? v : null;
  }

  @Builder
  stepItem(item: LogisticsItem, isFirst: boolean, isLast: boolean) {
    Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
      // Gutter: dot (centre 12,12) + connecting line from y = 24 to the bottom
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(isFirst ? 10 : 8)
            .height(isFirst ? 10 : 8)
            .fill(isFirst ? ThemeManager.instance.primary : $r('app.color.divider'))
        }
        .width(STEP_OFFSET * 2)
        .height(STEP_OFFSET * 2)

        if (!isLast) {
          Column()
            .width(1)
            .layoutWeight(1)
            .backgroundColor($r('app.color.divider'))
        }
      }
      .width(STEP_OFFSET * 2)
      .flexShrink(0)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)

      // Content (start padding 36 measured from the item start = 24 gutter + 12)
      Column() {
        Column() {
          if (this.textOf(item.status) !== null) {
            Text(this.textOf(item.status) as string)
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
              .fontColor(AppTextStyles.color(isFirst ? AppTextType.PRIMARY : AppTextType.SECONDARY))
              .fontWeight(isFirst ? FontWeight.Medium : FontWeight.Normal)
              .padding({ bottom: 4 })
          }
          if (this.textOf(item.time) !== null) {
            Text(this.textOf(item.time) as string)
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
              .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
          }
        }
        .width('100%')
        .constraintSize({ minHeight: STEP_MIN_HEIGHT })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .flexGrow(1)
      .flexShrink(1)
      .flexBasis(0)
      .margin({ left: STEP_CONTENT_START - STEP_OFFSET * 2 })
      .padding({ bottom: isLast ? 0 : STEP_BOTTOM_PADDING })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  build() {
    Column() {
      ForEach(this.logisticsItems, (item: LogisticsItem, index: number) => {
        this.stepItem(item, index === 0, index === this.logisticsItems.length - 1)
      }, (item: LogisticsItem, index: number) =>
        index + '_' + this.logisticsItems.length + '_' + (item.time ?? '') + '_' + (item.status ?? ''))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
