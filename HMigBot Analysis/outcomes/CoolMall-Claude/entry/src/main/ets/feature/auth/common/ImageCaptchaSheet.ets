/**
 * ImageCaptchaSheet (source: feature/auth/component/ImageCaptchaDialog.kt ImageCaptchaDialog).
 * Content of the bottom sheet `安全验证`: StartRow { image-code input (digits only, at most 4, placeholder
 * `请输入图形验证码`, weight 1) | CaptchaImage } + FocusableDivider + 24vp + `完成验证` (enabled only with 4
 * characters) → onConfirm(code).
 * The input state lives in this component, so it is reset every time the sheet is shown again
 * (source: the dialog's remember{} state is dropped while hidden).
 *
 * Host page:
 *   @Builder captchaSheet() { Column() { ImageCaptchaSheet({ ... }) } }
 *   Column() {...}.bindSheet(vm.showImageCodePopup, this.captchaSheet(), SheetDefaults.options(() => vm.onHideImageCodePopup()))
 */
import { BottomModal } from '../../../core/ui/widget/BottomSheet';
import { AppButton } from '../../../core/ui/widget/Buttons';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { FocusableDivider } from './FocusableDivider';
import { CaptchaImage } from './CaptchaImage';

@ComponentV2
export struct ImageCaptchaSheet {
  /** Captcha.data */
  @Param captchaData: string = '';
  @Param sheetTitleText: ResourceStr = $r('app.string.security_verification');
  @Param buttonText: ResourceStr = $r('app.string.complete_verification');
  @Event onConfirm: (code: string) => void = (code: string) => {
  };
  @Event onRefreshCaptcha: () => void = () => {
  };
  @Local imageCode: string = '';
  @Local imageCodeFocused: boolean = false;

  @Builder
  sheetBody() {
    Column() {
      Row() {
        TextInput({ text: this.imageCode, placeholder: $r('app.string.image_captcha_hint') })
          .type(InputType.Number)
          .inputFilter('[0-9]')
          .maxLength(4)
          .enterKeyType(EnterKeyType.Done)
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
            // only digits, at most 4
            if (value.length <= 4 && (value.length === 0 || new RegExp('^[0-9]+$').test(value))) {
              this.imageCode = value;
            }
          })
          .onFocus(() => {
            this.imageCodeFocused = true;
          })
          .onBlur(() => {
            this.imageCodeFocused = false;
          })

        CaptchaImage({
          captchaData: this.captchaData,
          onRefresh: () => {
            this.onRefreshCaptcha();
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start) // StartRow
      .alignItems(VerticalAlign.Center)

      FocusableDivider({ fieldFocused: this.imageCodeFocused })

      // SpaceVerticalXLarge()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      AppButton({
        btnText: this.buttonText,
        btnEnabled: this.imageCode.length === 4,
        onBtnClick: () => {
          this.onConfirm(this.imageCode);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: this.sheetTitleText,
        sheetContent: (): void => {
          this.sheetBody()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
