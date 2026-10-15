/**
 * CommonNavigator (source: navigation/common/CommonNavigator.kt, the parts used by About / Contributors).
 * All calls go through AppNavigator (none of these routes is behind the login wall).
 */
import { Routes } from '../../../common/Router';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { WebParam } from '../../../core/navigation/RouteParams';

export class CommonNavigator {
  /** CommonRoutes.Web(url, title) */
  static toWeb(url: string, title: string | null = null): void {
    const p: WebParam = new WebParam();
    p.url = url;
    p.title = title;
    AppNavigator.navigate(Routes.COMMON_ROUTES_WEB, p);
  }

  /** CommonRoutes.Contributors */
  static toContributors(): void {
    AppNavigator.navigate(Routes.COMMON_ROUTES_CONTRIBUTORS);
  }

  /** CommonRoutes.UserAgreement */
  static toUserAgreement(): void {
    AppNavigator.navigate(Routes.COMMON_ROUTES_USER_AGREEMENT);
  }

  /** CommonRoutes.PrivacyPolicy */
  static toPrivacyPolicy(): void {
    AppNavigator.navigate(Routes.COMMON_ROUTES_PRIVACY_POLICY);
  }
}
