/**
 * AuthRoutesLoginPage — login method selection (source: feature/auth/view/LoginScreen.kt + LoginViewModel.kt).
 * AppScaffold (surface, back) { SpaceBetweenColumn(centerHorizontally) {
 *   logo 120vp (padding top 80 / bottom 30; slides down with a medium-bouncy low-stiffness spring)
 *   CenterColumn(padding 24) { `验证码登录` | 24 | `账号密码登录` (outlined) | 48 | `其他登录方式` | 24 |
 *     SpaceEvenlyRow{ 微信 / QQ / 支付宝 } | UserAgreement(center, top 32) }  (slides up, tween 500 delay 100)
 * } }
 */
import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { Routes } from '../common/Router';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { AppButton, AppButtonStyle } from '../core/ui/widget/Buttons';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { Dimens } from '../core/designsystem/Dimens';
import { UserAgreement } from '../feature/auth/common/UserAgreement';
import { LoginViewModel } from '../feature/auth/login/LoginViewModel';
import { ThirdPartyLoginButton } from '../feature/auth/login/ThirdPartyLoginButton';

@Builder
export function AuthRoutesLoginPageBuilder() {
  AuthRoutesLoginPage()
}

@ComponentV2
struct AuthRoutesLoginPage {
  @Local vm: LoginViewModel = new LoginViewModel();
  /** Source rememberSaveable isAnimationPlayed: animate once per page instance */
  @Local animationVisible: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  @Builder
  logoSection() {
    // Box(padding top 80 / bottom 30, contentAlignment = Center) { LogoIcon(120) }
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.ic_logo'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .padding({ top: 80, bottom: 30 })
  }

  @Builder
  actionSection() {
    Column() {
      AppButton({
        btnText: $r('app.string.sms_login'),
        onBtnClick: () => {
          AppNavigator.navigate(Routes.AUTH_ROUTES_SMS_LOGIN);
        }
      })

      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      AppButton({
        btnText: $r('app.string.account_login'),
        btnStyle: AppButtonStyle.OUTLINED,
        onBtnClick: () => {
          AppNavigator.navigate(Routes.AUTH_ROUTES_ACCOUNT_LOGIN);
        }
      })

      Row()
        .width('100%')
        .height(48)

      Text($r('app.string.other_login_methods'))
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor(AppTextStyles.color(AppTextType.TERTIARY))

      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      // SpaceEvenlyRow
      Row() {
        ThirdPartyLoginButton({
          iconRes: $r('app.media.ic_wechat'),
          nameText: $r('app.string.wechat'),
          onItemClick: () => {
            this.vm.onWechatLoginClick();
          }
        })
        ThirdPartyLoginButton({
          iconRes: $r('app.media.ic_qq'),
          nameText: $r('app.string.qq'),
          onItemClick: () => {
            this.vm.startQQLogin(this.abilityContext());
          }
        })
        ThirdPartyLoginButton({
          iconRes: $r('app.media.ic_alipay'),
          nameText: $r('app.string.alipay'),
          onItemClick: () => {
            this.vm.onAlipayLoginClick();
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)

      Column() {
        UserAgreement({ centerAlignment: true })
      }
      .width('100%')
      .padding({ top: 32 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center) // CenterColumn
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  loginContent() {
    // SpaceBetweenColumn(fillMaxSize, CenterHorizontally)
    Column() {
      if (this.animationVisible) {
        Column() {
          this.logoSection()
        }
        .alignItems(HorizontalAlign.Center)
        // slideInVertically(initialOffsetY = -it, spring(DampingRatioMediumBouncy 0.5, StiffnessLow 200))
        .transition(TransitionEffect.move(TransitionEdge.TOP)
          .animation({ curve: curves.interpolatingSpring(0, 1, 200, 14.14) }))
      }
      if (this.animationVisible) {
        Column() {
          this.actionSection()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        // slideInVertically(initialOffsetY = it, tween(500, delay 100))
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
          .animation({ duration: 500, delay: 100, curve: Curve.FastOutSlowIn }))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
    .clip(true)
    .onAppear(() => {
      this.animationVisible = true;
    })
  }

  build() {
    NavDestination() {
      AppScaffold({
        bgColor: $r('app.color.surface'),
        content: (): void => {
          this.loginContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
