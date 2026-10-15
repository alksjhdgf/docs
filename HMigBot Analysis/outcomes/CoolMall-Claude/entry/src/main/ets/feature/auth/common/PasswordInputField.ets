/**
 * PasswordInputField (source: feature/auth/component/PasswordInputField.kt).
 * Box { masked single-line input (KeyboardType.Password, placeholder `请输入密码`) | eye toggle at CenterEnd
 * (24vp button, 20vp icon: ic_eye when visible, ic_eye_hide when hidden) } + FocusableDivider.
 * Masked by default; the eye toggles show / hide (source rememberSaveable passwordVisible).
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { FocusableDivider } from './FocusableDivider';

@ComponentV2
export struct PasswordInputField {
  @Param password: string = '';
  /** Placeholder (source placeholder.ifEmpty { password_hint }) */
  @Param hintText: ResourceStr = $r('app.string.password_hint');
  /** IME action (source nextAction = ImeAction.Done) */
  @Param imeAction: EnterKeyType = EnterKeyType.Done;
  @Event onPasswordChange: (value: string) => void = (value: string) => {
  };
  @Local fieldFocused: boolean = false;
  @Local passwordVisible: boolean = false;

  build() {
    Column() {
      // Box(modifier) { BasicTextField(fillMaxWidth); IconButton(align CenterEnd) }
      Stack({ alignContent: Alignment.End }) {
        TextInput({ text: this.password, placeholder: this.hintText })
          .type(InputType.Password)
          .showPassword(this.passwordVisible)
          .showPasswordIcon(false)
          .enterKeyType(this.imeAction)
          .maxLines(1)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor(Color.Gray)
          .placeholderFont({ size: 16 })
          .caretColor(ThemeManager.instance.primary)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 0, top: 0, bottom: 0, right: 28 })
          .width('100%')
          .onChange((value: string) => {
            this.onPasswordChange(value);
          })
          .onFocus(() => {
            this.fieldFocused = true;
          })
          .onBlur(() => {
            this.fieldFocused = false;
          })

        // IconButton(size 24) { Image(20dp) } — centered icon inside the button (M3 IconButton)
        Stack({ alignContent: Alignment.Center }) {
          Image(this.passwordVisible ? $r('app.media.ic_eye') : $r('app.media.ic_eye_hide'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .draggable(false)
            .accessibilityText(this.passwordVisible ? $r('app.string.hide_password') : $r('app.string.show_password'))
        }
        .width(24)
        .height(24)
        .onClick(() => {
          this.passwordVisible = !this.passwordVisible;
        })
      }
      .width('100%')

      FocusableDivider({ fieldFocused: this.fieldFocused })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
