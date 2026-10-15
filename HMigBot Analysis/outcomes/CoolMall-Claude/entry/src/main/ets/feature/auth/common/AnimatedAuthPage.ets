/**
 * AnimatedAuthPage (source: feature/auth/component/AnimatedAuthPage.kt).
 * AppScaffold (surface background, back button that avoids the status bar) whose content — title + page
 * fields — slides in from the bottom once per page instance (tween 400ms). Content column: fill size,
 * horizontal padding 32 (SpaceHorizontalXXLarge), top padding 32 (SpaceVerticalXXLarge), start aligned.
 *
 * Usage:
 *   AnimatedAuthPage({ titleText: $r('app.string.welcome_login'), authContent: (): void => { this.body() } })
 */
import { AppScaffold } from '../../../core/ui/base/AppScaffold';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { Dimens } from '../../../core/designsystem/Dimens';
import { AuthHeader } from './AuthHeader';

@Builder
function emptyAuthContent() {
}

@ComponentV2
export struct AnimatedAuthPage {
  @Param titleText: ResourceStr = '';
  /** Source onBackClick (pages pass navigateBack) */
  @Event onBack: () => void = () => {
    AppNavigator.back();
  };
  @BuilderParam authContent: () => void = emptyAuthContent;
  /** Animation played flag (source rememberSaveable isAnimationPlayed) — per page instance */
  @Local contentVisible: boolean = false;

  @Builder
  pageBody() {
    Column() {
      if (this.contentVisible) {
        Column() {
          AuthHeader({ headerText: this.titleText })
          this.authContent()
        }
        .width('100%')
        .height('100%')
        .padding({
          left: Dimens.spaceHorizontalXXLarge,
          right: Dimens.spaceHorizontalXXLarge,
          top: Dimens.spaceVerticalXXLarge
        })
        .alignItems(HorizontalAlign.Start) // source TopColumn: start / top
        .justifyContent(FlexAlign.Start)
        // slideInVertically(initialOffsetY = { it }, tween(400))
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 400, curve: Curve.FastOutSlowIn }))
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .clip(true)
    .onAppear(() => {
      this.contentVisible = true;
    })
  }

  build() {
    AppScaffold({
      bgColor: $r('app.color.surface'),
      onBack: () => {
        this.onBack();
      },
      content: (): void => {
        this.pageBody()
      }
    })
  }
}
