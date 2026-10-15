/**
 * UserAgreement (source: feature/auth/component/UserAgreement.kt).
 * `<prefix>` + `《用户协议》` + `和` + `《隐私政策》` (bodyMedium; prefix / `和` tertiary, links in the theme
 * primary). centerAlignment → CenterRow; otherwise StartRow followed by SpaceVerticalMedium (12vp).
 * Default prefix `登录即代表您已阅读并同意` (register passes `注册即代表您已阅读并同意`).
 * Default clicks open the user agreement / privacy policy pages (source callers pass
 * CommonNavigator::toUserAgreement / ::toPrivacyPolicy).
 * Laid out as a wrapping Flex so the line never overflows narrow screens (Compose Row measures the last
 * child with the remaining width and wraps its text).
 */
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { Routes } from '../../../common/Router';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';
import { Dimens } from '../../../core/designsystem/Dimens';

@ComponentV2
export struct UserAgreement {
  @Param prefixText: ResourceStr = $r('app.string.login_agreement_prefix');
  @Param centerAlignment: boolean = false;
  @Event onUserAgreementClick: () => void = () => {
    AppNavigator.navigate(Routes.COMMON_ROUTES_USER_AGREEMENT);
  };
  @Event onPrivacyPolicyClick: () => void = () => {
    AppNavigator.navigate(Routes.COMMON_ROUTES_PRIVACY_POLICY);
  };

  @Builder
  plainText(text: ResourceStr) {
    Text(text)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
  }

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
        justifyContent: this.centerAlignment ? FlexAlign.Center : FlexAlign.Start,
        alignItems: ItemAlign.Center
      }) {
        this.plainText(this.prefixText)
        Text($r('app.string.user_agreement'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.LINK))
          .onClick(() => {
            this.onUserAgreementClick();
          })
        this.plainText($r('app.string.and'))
        Text($r('app.string.privacy_policy'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.LINK))
          .onClick(() => {
            this.onPrivacyPolicyClick();
          })
      }
      .width('100%')

      if (!this.centerAlignment) {
        // SpaceVerticalMedium()
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
      }
    }
    .width('100%')
    .alignItems(this.centerAlignment ? HorizontalAlign.Center : HorizontalAlign.Start)
  }
}
