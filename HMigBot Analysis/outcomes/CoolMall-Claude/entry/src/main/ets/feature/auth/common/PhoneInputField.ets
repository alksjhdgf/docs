/**
 * PhoneInputField (source: feature/auth/component/PhoneInputField.kt).
 * StartRow { `+86` (primary, 16fp, end padding 24) | single-line phone input (KeyboardType.Phone, no length
 * limit, placeholder `请输入手机号`, weight 1) } + FocusableDivider.
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { FocusableDivider } from './FocusableDivider';

@ComponentV2
export struct PhoneInputField {
  @Param phone: string = '';
  /** Placeholder (source placeholder.ifEmpty { phone_hint }) */
  @Param hintText: ResourceStr = $r('app.string.phone_hint');
  /** IME action (source nextAction = ImeAction.Next) */
  @Param imeAction: EnterKeyType = EnterKeyType.Next;
  @Event onPhoneChange: (value: string) => void = (value: string) => {
  };
  @Local fieldFocused: boolean = false;

  build() {
    Column() {
      Row() {
        Text($r('app.string.phone_code'))
          .fontSize(16)
          .fontColor(ThemeManager.instance.primary)
          .margin({ right: Dimens.spaceHorizontalXLarge })
        TextInput({ text: this.phone, placeholder: this.hintText })
          .type(InputType.PhoneNumber)
          .enterKeyType(this.imeAction)
          .maxLines(1)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor(Color.Gray)
          .placeholderFont({ size: 16 })
          .caretColor(ThemeManager.instance.primary)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding(0)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.onPhoneChange(value);
          })
          .onFocus(() => {
            this.fieldFocused = true;
          })
          .onBlur(() => {
            this.fieldFocused = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start) // StartRow: horizontal start
      .alignItems(VerticalAlign.Center) // StartRow: centerVertically

      FocusableDivider({ fieldFocused: this.fieldFocused })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
