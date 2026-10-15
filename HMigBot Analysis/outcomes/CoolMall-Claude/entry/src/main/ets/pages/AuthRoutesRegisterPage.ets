/**
 * AuthRoutesRegisterPage — user registration (source: feature/auth/view/RegisterScreen.kt +
 * RegisterViewModel.kt).
 * AnimatedAuthPage(`你好，\n欢迎注册青商城`) { PhoneInputField | 30 | VerificationCodeField (`获取验证码` active
 *   only when the phone is valid) | 30 | PasswordInputField(`请设置密码`) | 30 | PasswordInputField(`请确认密码`) |
 *   12 | UserAgreement(`注册即代表您已阅读并同意`) | 24 | `注册` (enabled = isRegisterEnabled) |
 *   BottomNavigationRow(`已有账号？` `去登录` → back) }
 * + bottom sheet ImageCaptchaSheet (`安全验证`).
 * `获取验证码`: notification permission first (denied → `需要通知权限才能接收验证码`), then
 * vm.onSendCodeButtonClick().
 */
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppButton } from '../core/ui/widget/Buttons';
import { SheetDefaults } from '../core/ui/widget/BottomSheet';
import { Dimens } from '../core/designsystem/Dimens';
import { PermissionUtils } from '../core/util/PermissionUtils';
import { ToastUtils } from '../core/util/ToastUtils';
import { AnimatedAuthPage } from '../feature/auth/common/AnimatedAuthPage';
import { PhoneInputField } from '../feature/auth/common/PhoneInputField';
import { VerificationCodeField } from '../feature/auth/common/VerificationCodeField';
import { PasswordInputField } from '../feature/auth/common/PasswordInputField';
import { UserAgreement } from '../feature/auth/common/UserAgreement';
import { BottomNavigationRow } from '../feature/auth/common/BottomNavigationRow';
import { ImageCaptchaSheet } from '../feature/auth/common/ImageCaptchaSheet';
import { RegisterViewModel } from '../feature/auth/register/RegisterViewModel';

@Builder
export function AuthRoutesRegisterPageBuilder() {
  AuthRoutesRegisterPage()
}

@ComponentV2
struct AuthRoutesRegisterPage {
  @Local vm: RegisterViewModel = new RegisterViewModel();
  private alive: boolean = true;

  aboutToDisappear(): void {
    this.alive = false;
    this.vm.dispose();
  }

  /** Source onSendVerificationCodeWithPermission */
  private onSendVerificationCodeWithPermission(): void {
    const ctx: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    PermissionUtils.requestNotificationPermission(ctx, (granted: boolean) => {
      if (!this.alive) {
        return;
      }
      if (granted) {
        this.vm.onSendCodeButtonClick();
      } else {
        ToastUtils.showError($r('app.string.notification_permission_required'));
      }
    });
  }

  @Builder
  captchaSheet() {
    Column() {
      ImageCaptchaSheet({
        captchaData: this.vm.captchaData,
        onConfirm: (code: string) => {
          this.vm.onImageCodeConfirm(code);
        },
        onRefreshCaptcha: () => {
          this.vm.getCaptcha();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  registerContent() {
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

      VerificationCodeField({
        verificationCode: this.vm.verificationCode,
        hintText: $r('app.string.verification_code'),
        imeAction: EnterKeyType.Next,
        isPhoneValid: this.vm.isPhoneValid(),
        onVerificationCodeChange: (value: string) => {
          this.vm.updateVerificationCode(value);
        },
        onSendVerificationCode: () => {
          this.onSendVerificationCodeWithPermission();
        }
      })

      Row()
        .width('100%')
        .height(30)

      PasswordInputField({
        password: this.vm.password,
        hintText: $r('app.string.set_password'),
        imeAction: EnterKeyType.Next,
        onPasswordChange: (value: string) => {
          this.vm.updatePassword(value);
        }
      })

      Row()
        .width('100%')
        .height(30)

      PasswordInputField({
        password: this.vm.confirmPassword,
        hintText: $r('app.string.confirm_password'),
        imeAction: EnterKeyType.Done,
        onPasswordChange: (value: string) => {
          this.vm.updateConfirmPassword(value);
        }
      })

      // SpaceVerticalMedium()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      UserAgreement({ prefixText: $r('app.string.register_agreement_prefix') })

      // SpaceVerticalXLarge()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      AppButton({
        btnText: $r('app.string.register'),
        btnEnabled: this.vm.isRegisterEnabled(),
        onBtnClick: () => {
          this.vm.register();
        }
      })

      BottomNavigationRow({
        messageText: $r('app.string.have_account'),
        actionText: $r('app.string.go_login'),
        onActionClick: () => {
          AppNavigator.back();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start) // TopColumn content: start aligned
  }

  build() {
    NavDestination() {
      Column() {
        AnimatedAuthPage({
          titleText: $r('app.string.welcome_register'),
          authContent: (): void => {
            this.registerContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet(this.vm.showImageCodePopup, this.captchaSheet(), SheetDefaults.options(() => {
        this.vm.onHideImageCodePopup();
      }))
    }
    .hideTitleBar(true)
  }
}
