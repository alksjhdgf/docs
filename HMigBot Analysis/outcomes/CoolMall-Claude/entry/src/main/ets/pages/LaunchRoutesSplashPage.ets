/**
 * LaunchRoutesSplashPage (source: feature/launch/view/SplashScreen.kt).
 *
 * Box(fillMaxSize, surface, center) {
 *   BackgroundLogoSection: LogoIcon 240 blurred 100 + alpha 0.8, centered
 *   ForegroundContentSection: Column { weight(1) / LogoIcon 120 (offsetY 160→0, rotate -15→0 in 1000ms,
 *     alpha 0→1 in 800ms, shared element `app_logo`) / weight(1) / [app_name_splash TitleLarge onSurface,
 *     12, app_copyright BodyMedium tertiary] (alpha 0→1, 800ms, delay 400) / 32 }
 * }
 * After 1200ms → SplashViewModel.checkGuideStatusAndNavigate (LAUNCH-A05/A06/A07).
 * Source draws edge-to-edge without insets (logo centered, text 32vp above the bottom edge) (LAUNCH-A04).
 */
import { SplashViewModel } from '../feature/launch/SplashViewModel';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { Dimens } from '../core/designsystem/Dimens';

/** delay(1200) before navigating */
const SPLASH_DELAY_MS: number = 1200;
const LOGO_SIZE: number = 120;
const BG_LOGO_SIZE: number = 240;
const BG_BLUR_RADIUS: number = 100;

@Builder
export function LaunchRoutesSplashPageBuilder() {
  LaunchRoutesSplashPage()
}

@ComponentV2
struct LaunchRoutesSplashPage {
  private vm: SplashViewModel = new SplashViewModel();
  /** startAnimation */
  @Local startAnimation: boolean = false;
  private navTimer: number = -1;
  private animTimer: number = -1;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.navTimer = setTimeout(() => {
      this.navTimer = -1;
      if (this.alive) {
        this.vm.checkGuideStatusAndNavigate();
      }
    }, SPLASH_DELAY_MS);
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.navTimer !== -1) {
      clearTimeout(this.navTimer);
      this.navTimer = -1;
    }
    if (this.animTimer !== -1) {
      clearTimeout(this.animTimer);
      this.animTimer = -1;
    }
  }

  /** Kick off the enter animation right after the first frame (LaunchedEffect: startAnimation = true) */
  private startEnterAnimation(): void {
    this.animTimer = setTimeout(() => {
      this.animTimer = -1;
      if (this.alive) {
        this.startAnimation = true;
      }
    }, 0);
  }

  @Builder
  backgroundLogoSection() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.ic_logo'))
        .width(BG_LOGO_SIZE)
        .height(BG_LOGO_SIZE)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .width('100%')
    .height('100%')
    .blur(BG_BLUR_RADIUS)
    .opacity(0.8)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  foregroundContentSection() {
    Column() {
      Blank()
        .layoutWeight(1)

      Image($r('app.media.ic_logo'))
        .width(LOGO_SIZE)
        .height(LOGO_SIZE)
        .objectFit(ImageFit.Contain)
        .draggable(false)
        .translate({ y: this.startAnimation ? 0 : 160 })
        .rotate({ angle: this.startAnimation ? 0 : -15 })
        .animation({ duration: 1000, curve: Curve.FastOutSlowIn })
        .opacity(this.startAnimation ? 1 : 0)
        .animation({ duration: 800, curve: Curve.FastOutSlowIn })
        .geometryTransition('app_logo')

      Blank()
        .layoutWeight(1)

      Column() {
        Text($r('app.string.app_name_splash'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.TITLE_LARGE))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.TITLE_LARGE))
          .fontWeight(AppTextStyles.fontWeight(AppTextSize.TITLE_LARGE))
          .fontColor($r('app.color.text_primary'))

        Blank()
          .height(Dimens.spaceVerticalMedium)

        Text($r('app.string.app_copyright'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontWeight(AppTextStyles.fontWeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
      }
      .alignItems(HorizontalAlign.Center)
      .opacity(this.startAnimation ? 1 : 0)
      .animation({ duration: 800, delay: 400, curve: Curve.FastOutSlowIn })

      Blank()
        .height(Dimens.spaceVerticalXXLarge)
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        this.backgroundLogoSection()
        this.foregroundContentSection()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
      .onAppear(() => {
        this.startEnterAnimation();
      })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.surface'))
  }
}
