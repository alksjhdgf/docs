/**
 * OrderStatusItem (source: MeScreen.kt private OrderStatusItem).
 * Column(CenterHorizontally, clickable, padding vertical 12): 24vp icon (onSurface) — with a red
 * WeBadge(count, size 16, colorScheme.error, TopEnd) when badgeCount > 0 — then 8vp + BODY_MEDIUM label.
 * The caller wraps it in a container carrying layoutWeight(1) (source Modifier.weight(1f)).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { WeBadge } from '../../../core/ui/widget/Badge';
import { AppTextSize, AppTextStyles } from '../../../core/ui/widget/Texts';

@ComponentV2
export struct OrderStatusItem {
  @Param itemIcon: Resource | undefined = undefined;
  @Param itemLabel: ResourceStr = '';
  @Param badgeCount: number = 0;
  @Event onItemClick: () => void = () => {
  };

  @Builder
  iconBuilder() {
    if (this.itemIcon !== undefined) {
      if (typeof this.itemLabel === 'string') {
        Image(this.itemIcon as Resource)
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .accessibilityText(this.itemLabel as string)
      } else {
        Image(this.itemIcon as Resource)
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .accessibilityText(this.itemLabel as Resource)
      }
    }
  }

  build() {
    Column() {
      if (this.badgeCount > 0) {
        WeBadge({
          badgeContent: this.badgeCount.toString(),
          badgeSize: 16,
          badgeColor: $r('app.color.danger'),
          badgeAlignment: Alignment.TopEnd,
          holder: (): void => {
            this.iconBuilder()
          }
        })
      } else {
        this.iconBuilder()
      }
      Text(this.itemLabel)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor($r('app.color.text_primary'))
        .margin({ top: Dimens.spaceVerticalSmall })
    }
    .width('100%')
    .padding({ top: Dimens.spaceVerticalMedium, bottom: Dimens.spaceVerticalMedium })
    // source: Column(horizontalAlignment = CenterHorizontally)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      this.onItemClick();
    })
  }
}
