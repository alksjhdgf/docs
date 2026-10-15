/**
 * SplashViewModel (source: feature/launch/viewmodel/SplashViewModel.kt).
 * After the splash animation: guide_shown == true → main page, otherwise → guide page;
 * both close the splash page (LAUNCH-A06 / A07).
 */
import { Routes } from '../../common/Router';
import { AppNavigator } from '../../core/navigation/AppNavigator';
import { GuideParam } from '../../core/navigation/RouteParams';
import { KvKeys, KvStore } from '../../core/storage/KvStore';

export class SplashViewModel {
  /** KEY_GUIDE_SHOWN = "guide_shown" */
  static readonly KEY_GUIDE_SHOWN: string = KvKeys.GUIDE_SHOWN;

  /** checkGuideStatusAndNavigate */
  checkGuideStatusAndNavigate(): void {
    if (this.isGuideShown()) {
      this.toMainPage();
    } else {
      this.toGuidePage();
    }
  }

  private isGuideShown(): boolean {
    return KvStore.getBoolean(SplashViewModel.KEY_GUIDE_SHOWN, false);
  }

  /** LaunchNavigator.toGuideAndCloseCurrent(Splash) */
  private toGuidePage(): void {
    const param: GuideParam = new GuideParam();
    param.fromSettings = false;
    AppNavigator.replace(Routes.LAUNCH_ROUTES_GUIDE, param);
  }

  /** MainNavigator.toMainAndCloseCurrent(Splash) */
  toMainPage(): void {
    AppNavigator.toMain();
  }
}
