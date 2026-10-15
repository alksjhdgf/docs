/**
 * ThirdPartyLoginButton (source: feature/auth/view/LoginScreen.kt ThirdPartyLoginButton).
 * Column(centerHorizontally) { IconButton(48vp) { 32vp icon, ContentScale.Fit } ; name (bodyMedium, tertiary) }.
 * Only the icon button is clickable (as in source).
 */
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';

@ComponentV2
export struct ThirdPartyLoginButton {
  @Param iconRes: ResourceStr = '';
  // accessibilityText() only accepts string | Resource (not the ResourceStr union); all callers pass $r(...).
  @Require @Param nameText: Resource;
  @Event onItemClick: () => void = () => {
  };

  build() {
    Column() {
      // M3 IconButton: 48vp touch target, icon centered
      Stack({ alignContent: Alignment.Center }) {
        Image(this.iconRes)
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
          .draggable(false)
          .accessibilityText(this.nameText)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .onClick(() => {
        this.onItemClick();
      })

      Text(this.nameText)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
    }
    .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
  }
}
