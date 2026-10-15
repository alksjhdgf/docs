/**
 * QuantityStepper (source: core/ui/component/stepper/QuantityStepper.kt).
 * [ - ] quantity [ + ]: minus = surfaceVariant circle (disabled at minValue, icon alpha .6/.3),
 * plus = primary circle with a white icon (disabled at maxValue). minValue defaults to 1.
 * The stepper only reports the new value through onQuantityChanged; the caller owns `quantity`.
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';

@ComponentV2
export struct QuantityStepper {
  @Param quantity: number = 1;
  @Param minValue: number = 1;
  @Param maxValue: number = Number.MAX_SAFE_INTEGER;
  @Param buttonSize: number = 24;
  @Param quantityWidth: number = 24;
  @Event onQuantityChanged: (value: number) => void = (value: number) => {
  };

  private canDecrease(): boolean {
    return this.quantity > this.minValue;
  }

  private canIncrease(): boolean {
    return this.quantity < this.maxValue;
  }

  build() {
    Row() {
      // decrease
      Row() {
        Image($r('app.media.ic_reduce'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .opacity(this.canDecrease() ? 0.6 : 0.3)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      // source: Box(contentAlignment = Center)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_content'))
      .borderRadius(this.buttonSize / 2)
      .clip(true)
      .onClick(() => {
        if (this.canDecrease()) {
          this.onQuantityChanged(this.quantity - 1);
        }
      })
      .hitTestBehavior(this.canDecrease() ? HitTestMode.Default : HitTestMode.None)

      // quantity: padding(horizontal 12) then widthIn(min = quantityWidth)
      Text(String(this.quantity))
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
        .constraintSize({ minWidth: this.quantityWidth + Dimens.spacePaddingMedium * 2 })

      // increase
      Row() {
        Image($r('app.media.ic_add'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ThemeManager.instance.primary)
      .borderRadius(this.buttonSize / 2)
      .clip(true)
      .onClick(() => {
        if (this.canIncrease()) {
          this.onQuantityChanged(this.quantity + 1);
        }
      })
      .hitTestBehavior(this.canIncrease() ? HitTestMode.Default : HitTestMode.None)
    }
    // source: WrapRow(horizontalArrangement = Start, verticalAlignment = CenterVertically)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}
