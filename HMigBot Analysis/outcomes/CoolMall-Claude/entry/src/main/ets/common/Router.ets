/**
 * Router.ets —— 由 wire-routes 生成（源：src/main/AndroidManifest.xml）。
 * 路由注册与跳转唯一通道：页面只准 import AppRouter，禁散落 pushPathByName。
 * 本文件归静态前场独占；切片阶段只填页面行为，不碰壳。
 */
export class NoParam {
}

export const enum Routes {
  USER_ROUTES_PROFILE = 'UserRoutesProfile',
  USER_ROUTES_ADDRESS_LIST = 'UserRoutesAddressList',
  USER_ROUTES_ADDRESS_DETAIL = 'UserRoutesAddressDetail',
  USER_ROUTES_FOOTPRINT = 'UserRoutesFootprint',
  ORDER_ROUTES_LIST = 'OrderRoutesList',
  ORDER_ROUTES_CONFIRM = 'OrderRoutesConfirm',
  ORDER_ROUTES_DETAIL = 'OrderRoutesDetail',
  ORDER_ROUTES_PAY = 'OrderRoutesPay',
  ORDER_ROUTES_LOGISTICS = 'OrderRoutesLogistics',
  ORDER_ROUTES_REFUND = 'OrderRoutesRefund',
  ORDER_ROUTES_COMMENT = 'OrderRoutesComment',
  MARKET_ROUTES_COUPON = 'MarketRoutesCoupon',
  MAIN_ROUTES_MAIN = 'MainRoutesMain',
  MAIN_ROUTES_CART = 'MainRoutesCart',
  LAUNCH_ROUTES_SPLASH = 'LaunchRoutesSplash',
  LAUNCH_ROUTES_GUIDE = 'LaunchRoutesGuide',
  GOODS_ROUTES_DETAIL = 'GoodsRoutesDetail',
  GOODS_ROUTES_SEARCH = 'GoodsRoutesSearch',
  GOODS_ROUTES_COMMENT = 'GoodsRoutesComment',
  GOODS_ROUTES_CATEGORY = 'GoodsRoutesCategory',
  FEEDBACK_ROUTES_LIST = 'FeedbackRoutesList',
  FEEDBACK_ROUTES_SUBMIT = 'FeedbackRoutesSubmit',
  CS_ROUTES_CHAT = 'CsRoutesChat',
  COMMON_ROUTES_ABOUT = 'CommonRoutesAbout',
  COMMON_ROUTES_WEB = 'CommonRoutesWeb',
  COMMON_ROUTES_SETTINGS = 'CommonRoutesSettings',
  COMMON_ROUTES_USER_AGREEMENT = 'CommonRoutesUserAgreement',
  COMMON_ROUTES_PRIVACY_POLICY = 'CommonRoutesPrivacyPolicy',
  COMMON_ROUTES_CONTRIBUTORS = 'CommonRoutesContributors',
  AUTH_ROUTES_LOGIN = 'AuthRoutesLogin',
  AUTH_ROUTES_ACCOUNT_LOGIN = 'AuthRoutesAccountLogin',
  AUTH_ROUTES_SMS_LOGIN = 'AuthRoutesSmsLogin',
  AUTH_ROUTES_REGISTER = 'AuthRoutesRegister',
  AUTH_ROUTES_RESET_PASSWORD = 'AuthRoutesResetPassword',
}

export class AppRouter {
  static readonly stack: NavPathStack = new NavPathStack();

  static push(route: Routes, params?: Object, onPop?: (pop: PopInfo) => void): void {
    const param: Object = params !== undefined ? params : new NoParam();
    if (onPop !== undefined) {
      AppRouter.stack.pushPathByName(route, param, onPop);
    } else {
      AppRouter.stack.pushPathByName(route, param);
    }
  }

  /** 按运行期路由名跳转（冒烟直达钩子/深链用；业务代码一律走 push(Routes.X)） */
  static pushName(name: string, params?: Object): void {
    AppRouter.stack.pushPathByName(name, params !== undefined ? params : new NoParam());
  }

  static back(): void {
    AppRouter.stack.pop();
  }

  static backWithResult(result: Object): void {
    AppRouter.stack.pop(result);
  }

  static replace(route: Routes, params?: Object): void {
    AppRouter.stack.replacePathByName(route, params !== undefined ? params : new NoParam());
  }

  static goHome(): void {
    const names: Array<string> = AppRouter.stack.getAllPathName();
    if (names.indexOf(Routes.LAUNCH_ROUTES_SPLASH) >= 0) {
      AppRouter.stack.popToName(Routes.LAUNCH_ROUTES_SPLASH);
      return;
    }
    AppRouter.stack.clear();
    AppRouter.stack.pushPathByName(Routes.LAUNCH_ROUTES_SPLASH, new NoParam());
  }
}
