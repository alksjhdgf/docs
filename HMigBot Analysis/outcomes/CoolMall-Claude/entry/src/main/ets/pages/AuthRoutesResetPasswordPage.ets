/**
 * AuthRoutesResetPasswordPage — reset password (source: feature/auth/view/ResetPasswordScreen.kt +
 * ResetPasswordViewModel.kt).
 * AnimatedAuthPage(`重置密码`) { PhoneInputField | 30 | VerificationCodeField | 30 |
 *   PasswordInputField(`请设置新密码`) | 30 | PasswordInputField(`请确认新密码`) | 12 |
 *   StartRow(`重置密码后，请使用新密码登录`, 12fp gray) |
 *   [both non-empty and different: 12 | `两次输入的密码不一致` (bodySmall, error color)] | 24 |
 *   `重置密码` (always disabled) }
 * Source keeps both send-code and reset as empty implementations: no request is ever made.
 */
import { AppButton } from '../core/ui/widget/Buttons';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { Dimens } from '../core/designsystem/Dimens';
import { AnimatedAuthPage } from '../feature/auth/common/AnimatedAuthPage';
import { PhoneInputField } from '../feature/auth/common/PhoneInputField';
import { VerificationCodeField } from '../feature/auth/common/VerificationCodeField';
import { PasswordInputField } from '../feature/auth/common/PasswordInputField';
import { ResetPasswordViewModel } from '../feature/auth/register/ResetPasswordViewModel';

@Builder
export function AuthRoutesResetPasswordPageBuilder() {
  AuthRoutesResetPasswordPage()
}

@ComponentV2
struct AuthRoutesResetPasswordPage {
  @Local vm: ResetPasswordViewModel = new ResetPasswordViewModel();

  @Builder
  resetPasswordContent() {
    Column() {
      PhoneInputField({
        phone: this.vm.phone,
        hintText: $r('app.string.phone_hint'),
        imeAction: EnterKeyType.Next,
        onPhoneChange: (value: string) => {
          this.vm.updatePhone(value);
        }
      })

      Row()
        .width('100%')
        .height(30)

      // Source passes no isPhoneValid (component default true)
      VerificationCodeField({
        verificationCode: this.vm.verificationCode,
        hintText: $r('app.string.verification_code'),
        imeAction: EnterKeyType.Next,
        onVerificationCodeChange: (value: string) => {
          this.vm.updateVerificationCode(value);
        },
        onSendVerificationCode: () => {
          this.vm.sendVerificationCode();
        }
      })

      Row()
        .width('100%')
        .height(30)

      PasswordInputField({
        password: this.vm.newPassword,
        hintText: $r('app.string.set_new_password'),
        imeAction: EnterKeyType.Next,
        onPasswordChange: (value: string) => {
          this.vm.updateNewPassword(value);
        }
      })

      Row()
        .width('100%')
        .height(30)

      PasswordInputField({
        password: this.vm.confirmPassword,
        hintText: $r('app.string.confirm_new_password'),
        imeAction: EnterKeyType.Done,
        onPasswordChange: (value: string) => {
          this.vm.updateConfirmPassword(value);
        }
      })

      // SpaceVerticalMedium()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      // StartRow { Text(reset_password_tip, 12.sp, Color.Gray) }
      Row() {
        Text($r('app.string.reset_password_tip'))
          .fontSize(12)
          .fontColor(Color.Gray)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      if (this.vm.isPasswordMismatch()) {
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
        Text($r('app.string.password_mismatch'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
          .fontColor(AppTextStyles.color(AppTextType.ERROR))
      }

      // SpaceVerticalXLarge()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      // Source: enabled = false (always disabled)
      AppButton({
        btnText: $r('app.string.reset_password_button'),
        btnEnabled: false,
        onBtnClick: () => {
          this.vm.resetPassword();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start) // TopColumn content: start aligned
  }

  build() {
    NavDestination() {
      AnimatedAuthPage({
        titleText: $r('app.string.reset_password'),
        authContent: (): void => {
          this.resetPasswordContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
