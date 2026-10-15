/**
 * AuthRoutesAccountLoginPage — account + password login (source: feature/auth/view/AccountLoginScreen.kt +
 * AccountLoginViewModel.kt).
 * AnimatedAuthPage(`你好，\n欢迎登录青商城`) { PhoneInputField | 42 | PasswordInputField | 12 |
 *   UserAgreement(start) | 24 | `登录` (enabled = isLoginEnabled) | BottomNavigationRow(`去注册` | `忘记密码`) }
 */
import { Routes } from '../common/Router';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppButton } from '../core/ui/widget/Buttons';
import { Dimens } from '../core/designsystem/Dimens';
import { AnimatedAuthPage } from '../feature/auth/common/AnimatedAuthPage';
import { PhoneInputField } from '../feature/auth/common/PhoneInputField';
import { PasswordInputField } from '../feature/auth/common/PasswordInputField';
import { UserAgreement } from '../feature/auth/common/UserAgreement';
import { BottomNavigationRow } from '../feature/auth/common/BottomNavigationRow';
import { AccountLoginViewModel } from '../feature/auth/login/AccountLoginViewModel';

@Builder
export function AuthRoutesAccountLoginPageBuilder() {
  AuthRoutesAccountLoginPage()
}

@ComponentV2
struct AuthRoutesAccountLoginPage {
  @Local vm: AccountLoginViewModel = new AccountLoginViewModel();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  @Builder
  accountLoginContent() {
    Column() {
      PhoneInputField({
        phone: this.vm.account,
        hintText: $r('app.string.phone_hint'),
        imeAction: EnterKeyType.Next,
        onPhoneChange: (value: string) => {
          this.vm.updateAccount(value);
        }
      })

      Row()
        .width('100%')
        .height(42)

      PasswordInputField({
        password: this.vm.password,
        hintText: $r('app.string.password_hint'),
        imeAction: EnterKeyType.Done,
        onPasswordChange: (value: string) => {
          this.vm.updatePassword(value);
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
        btnEnabled: this.vm.isLoginEnabled(),
        onBtnClick: () => {
          this.vm.login();
        }
      })

      BottomNavigationRow({
        messageText: $r('app.string.go_register'),
        actionText: $r('app.string.forgot_password'),
        withDivider: true,
        onCancelClick: () => {
          AppNavigator.navigate(Routes.AUTH_ROUTES_REGISTER);
        },
        onActionClick: () => {
          AppNavigator.navigate(Routes.AUTH_ROUTES_RESET_PASSWORD);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start) // TopColumn content: start aligned
  }

  build() {
    NavDestination() {
      AnimatedAuthPage({
        titleText: $r('app.string.welcome_login'),
        authContent: (): void => {
          this.accountLoginContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
