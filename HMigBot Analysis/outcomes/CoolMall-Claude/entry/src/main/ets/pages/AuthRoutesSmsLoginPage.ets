/**
 * AuthRoutesSmsLoginPage — phone + SMS code login (source: feature/auth/view/SmsLoginScreen.kt +
 * SmsLoginViewModel.kt).
 * AnimatedAuthPage(`你好，\n欢迎登录青商城`) { PhoneInputField | 42 | VerificationCodeField (`获取验证码` only
 *   when the phone is valid) | 12 | UserAgreement(start) | 24 | `登录` (ROUND, enabled = isLoginEnabled) |
 *   BottomNavigationRow(`短信不可用？` `使用三方登录` → back to the selection page) }
 * + bottom sheet ImageCaptchaSheet (`安全验证`).
 * `获取验证码`: notification permission first (denied → `需要通知权限才能接收验证码`), then
 * vm.onSendCodeButtonClick().
 */
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppButton, AppButtonShape } from '../core/ui/widget/Buttons';
import { SheetDefaults } from '../core/ui/widget/BottomSheet';
import { Dimens } from '../core/designsystem/Dimens';
import { PermissionUtils } from '../core/util/PermissionUtils';
import { ToastUtils } from '../core/util/ToastUtils';
import { AnimatedAuthPage } from '../feature/auth/common/AnimatedAuthPage';
import { PhoneInputField } from '../feature/auth/common/PhoneInputField';
import { VerificationCodeField } from '../feature/auth/common/VerificationCodeField';
import { UserAgreement } from '../feature/auth/common/UserAgreement';
import { BottomNavigationRow } from '../feature/auth/common/BottomNavigationRow';
import { ImageCaptchaSheet } from '../feature/auth/common/ImageCaptchaSheet';
import { SmsLoginViewModel } from '../feature/auth/login/SmsLoginViewModel';

@Builder
export function AuthRoutesSmsLoginPageBuilder() {
  AuthRoutesSmsLoginPage()
}

@ComponentV2
struct AuthRoutesSmsLoginPage {
  @Local vm: SmsLoginViewModel = new SmsLoginViewModel();
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
  smsLoginContent() {
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
        .height(42)

      VerificationCodeField({
        verificationCode: this.vm.verificationCode,
        hintText: $r('app.string.verification_code'),
        imeAction: EnterKeyType.Done,
        isPhoneValid: this.vm.isPhoneValid(),
        onVerificationCodeChange: (value: string) => {
          this.vm.updateVerificationCode(value);
        },
        onSendVerificationCode: () => {
          this.onSendVerificationCodeWithPermission();
        }
      })

      // SpaceVerticalMedium()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      UserAgreement({ prefixText: $r('app.string.login_agreement_prefix') })

      // SpaceVerticalXLarge()
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      AppButton({
        btnText: $r('app.string.login'),
        btnShape: AppButtonShape.ROUND,
        btnEnabled: this.vm.isLoginEnabled(),
        onBtnClick: () => {
          this.vm.login();
        }
      })

      BottomNavigationRow({
        messageText: $r('app.string.sms_not_available'),
        actionText: $r('app.string.use_third_party_login'),
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
          titleText: $r('app.string.welcome_login'),
          authContent: (): void => {
            this.smsLoginContent()
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
