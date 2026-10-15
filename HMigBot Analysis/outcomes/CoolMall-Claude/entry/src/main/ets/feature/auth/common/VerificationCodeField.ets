/**
 * VerificationCodeField (source: feature/auth/component/VerificationCodeField.kt).
 * StartRow { code input (digits only, at most 4, KeyboardType.Number, weight 1, placeholder `验证码`) |
 * `获取验证码` (16fp, start padding 24; ColorWarning and clickable only when isPhoneValid, Gray otherwise) }
 * + FocusableDivider. No countdown (source has none).
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { FocusableDivider } from './FocusableDivider';

@ComponentV2
export struct VerificationCodeField {
  @Param verificationCode: string = '';
  /** Placeholder (source placeholder.ifEmpty { verification_code }) */
  @Param hintText: ResourceStr = $r('app.string.verification_code');
  @Param imeAction: EnterKeyType = EnterKeyType.Next;
  /** `获取验证码` enabled (source isPhoneValid, default true) */
  @Param isPhoneValid: boolean = true;
  @Event onVerificationCodeChange: (value: string) => void = (value: string) => {
  };
  @Event onSendVerificationCode: () => void = () => {
  };
  @Local fieldFocused: boolean = false;

  build() {
    Column() {
      Row() {
        TextInput({ text: this.verificationCode, placeholder: this.hintText })
          .type(InputType.Number)
          // source onValueChange: only digits, length <= 4
          .inputFilter('[0-9]')
          .maxLength(4)
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
            if (value.length <= 4 && (value.length === 0 || new RegExp('^[0-9]+$').test(value))) {
              this.onVerificationCodeChange(value);
            }
          })
          .onFocus(() => {
            this.fieldFocused = true;
          })
          .onBlur(() => {
            this.fieldFocused = false;
          })

        Text($r('app.string.get_verification_code'))
          .fontSize(16)
          .fontColor(this.isPhoneValid ? $r('app.color.warning') : Color.Gray)
          .margin({ left: Dimens.spaceHorizontalXLarge })
          .onClick(() => {
            if (this.isPhoneValid) {
              this.onSendVerificationCode();
            }
          })
          // clickable(enabled = isPhoneValid): a disabled clickable does not take part in hit testing
          .hitTestBehavior(this.isPhoneValid ? HitTestMode.Default : HitTestMode.None)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      FocusableDivider({ fieldFocused: this.fieldFocused })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
