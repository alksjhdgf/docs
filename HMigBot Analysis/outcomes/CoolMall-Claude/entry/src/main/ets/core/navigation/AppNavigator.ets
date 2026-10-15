/**
 * AppNavigator — the only navigation entry for business code (source: core/navigation/AppNavigator.kt,
 * RouteInterceptor.kt, NavigationService.kt, BackStackNavigationController.kt, main/MainNavigator.kt).
 * Internally only goes through AppRouter (common/Router.ets).
 *
 * - navigate(route, param?, onResult?): login wall (DATA-A13 / LAUNCH-A22) — when the route is one of the
 *   14 login-required routes and AppState.isLoggedIn is false, AuthRoutesLogin is pushed instead.
 * - back(): pops only when more than one page is on the stack (source navigateBack size > 1).
 * - backWithResult(result) / backWithRefresh(): source popBackStackWithResult — the result is dispatched
 *   to global result subscribers (source resultEvents flow) AND delivered to the pusher's onResult
 *   callback (NavPathStack pop result). Use ONE of the two on a given page to avoid double handling.
 * - replace(route, param?): source navigateAndCloseCurrent (close current page, open route; login wall applies).
 * - toMain(): clear the stack and show MainRoutesMain (source MainNavigator.toMainAndCloseCurrent).
 */
import { AppRouter, NoParam, Routes } from '../../common/Router';
import { AppState } from '../data/AppState';
import { LogUtils } from '../util/LogUtils';
import { RefreshResult } from './RouteParams';

const TAG: string = 'AppNavigator';

/** Callback receiving a page result (narrow with instanceof RefreshResult / SelectAddressResult) */
export type NavResultCallback = (result: Object) => void;

/** RouteInterceptor.loginRequiredRouteTypes (14 routes) */
const LOGIN_REQUIRED_ROUTES: Routes[] = [
  Routes.USER_ROUTES_PROFILE,
  Routes.USER_ROUTES_ADDRESS_LIST,
  Routes.USER_ROUTES_ADDRESS_DETAIL,
  Routes.ORDER_ROUTES_LIST,
  Routes.ORDER_ROUTES_CONFIRM,
  Routes.ORDER_ROUTES_DETAIL,
  Routes.ORDER_ROUTES_PAY,
  Routes.ORDER_ROUTES_REFUND,
  Routes.ORDER_ROUTES_COMMENT,
  Routes.ORDER_ROUTES_LOGISTICS,
  Routes.CS_ROUTES_CHAT,
  Routes.MARKET_ROUTES_COUPON,
  Routes.FEEDBACK_ROUTES_LIST,
  Routes.FEEDBACK_ROUTES_SUBMIT
];

export class AppNavigator {
  private static nextResultId: number = 1;
  private static resultListeners: Map<number, NavResultCallback> = new Map<number, NavResultCallback>();

  /** RouteInterceptor.requiresLogin */
  static requiresLogin(route: Routes): boolean {
    return LOGIN_REQUIRED_ROUTES.indexOf(route) >= 0;
  }

  /** RouteInterceptor.getLoginRoute */
  static getLoginRoute(): Routes {
    return Routes.AUTH_ROUTES_LOGIN;
  }

  /** AppNavigator.resolveTargetRoute: login route when the target needs login and the user is logged out */
  static resolveTargetRoute(route: Routes): Routes {
    AppState.instance.ensureInitialized();
    if (AppNavigator.requiresLogin(route) && !AppState.instance.isLoggedIn) {
      return AppNavigator.getLoginRoute();
    }
    return route;
  }

  /**
   * Navigate to a route (with login wall). `param` is a RouteParams class instance (NoParam when omitted).
   * `onResult` is called when the pushed page returns with a result (backWithResult / backWithRefresh);
   * it is not attached when the login wall redirects to the login page.
   */
  static navigate(route: Routes, param?: Object, onResult?: NavResultCallback): void {
    const target = AppNavigator.resolveTargetRoute(route);
    if (target !== route) {
      LogUtils.iTag(TAG, `login required for ${route}, redirect to ${target}`);
      AppRouter.push(target, new NoParam());
      return;
    }
    const p: Object = (param !== undefined && param !== null) ? param : new NoParam();
    if (onResult !== undefined) {
      AppRouter.push(target, p, (pop: PopInfo): void => {
        const r: Object | undefined = pop.result;
        if (r !== undefined && r !== null) {
          onResult(r);
        }
      });
    } else {
      AppRouter.push(target, p);
    }
  }

  /** Go back one page (no-op when only one page is on the stack, as in source) */
  static back(): void {
    if (AppRouter.stack.size() > 1) {
      AppRouter.back();
    }
  }

  /**
   * Go back and return a result (source popBackStackWithResult): dispatch to global subscribers,
   * then pop delivering it to the pusher's onResult.
   */
  static backWithResult(result: Object): void {
    AppNavigator.dispatchResult(result);
    if (AppRouter.stack.size() > 1) {
      AppRouter.backWithResult(result);
    }
  }

  /** Go back and ask the previous page to refresh: RefreshResult{ refresh: true } */
  static backWithRefresh(): void {
    AppNavigator.backWithResult(new RefreshResult(true));
  }

  /** Close the current page and open `route` (source navigateAndCloseCurrent; login wall applies) */
  static replace(route: Routes, param?: Object): void {
    const target = AppNavigator.resolveTargetRoute(route);
    if (target !== route) {
      LogUtils.iTag(TAG, `login required for ${route}, redirect to ${target}`);
      AppRouter.replace(target, new NoParam());
      return;
    }
    AppRouter.replace(target, (param !== undefined && param !== null) ? param : new NoParam());
  }

  /** Clear the whole stack and show the main shell (MainRoutesMain) */
  static toMain(): void {
    AppRouter.stack.clear(false);
    AppRouter.push(Routes.MAIN_ROUTES_MAIN, new NoParam());
  }

  /**
   * Pop back to the last `route` on the stack (source navigateBackTo). `inclusive` also pops that page.
   * No-op when the route is not on the stack.
   */
  static backTo(route: Routes, inclusive: boolean = false): void {
    const names: string[] = AppRouter.stack.getAllPathName();
    const idx = names.lastIndexOf(route);
    if (idx < 0) {
      return;
    }
    const targetIndex = inclusive ? idx - 1 : idx;
    if (targetIndex < 0) {
      // Source keeps the first entry unless popping to empty is allowed
      if (names.length > 1) {
        AppRouter.stack.popToIndex(0);
      }
      return;
    }
    AppRouter.stack.popToIndex(targetIndex);
  }

  /**
   * Subscribe to every result returned with backWithResult/backWithRefresh (source resultEvents()).
   * Returns an id for unsubscribeResult; unsubscribe symmetrically (aboutToDisappear / ViewModel dispose).
   */
  static subscribeResult(cb: NavResultCallback): number {
    const id = AppNavigator.nextResultId;
    AppNavigator.nextResultId++;
    AppNavigator.resultListeners.set(id, cb);
    return id;
  }

  static unsubscribeResult(id: number): void {
    AppNavigator.resultListeners.delete(id);
  }

  private static dispatchResult(result: Object): void {
    const cbs: NavResultCallback[] = Array.from(AppNavigator.resultListeners.values());
    for (const cb of cbs) {
      try {
        cb(result);
      } catch (e) {
        LogUtils.eTag(TAG, 'result listener threw: ' + ((e as Error)?.message ?? ''));
      }
    }
  }
}
