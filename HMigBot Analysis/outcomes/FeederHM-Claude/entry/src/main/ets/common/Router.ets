/**
 * Router.ets —— 由 wire-routes 生成（源：src/main/AndroidManifest.xml）。
 * 路由注册与跳转唯一通道：页面只准 import AppRouter，禁散落 pushPathByName。
 * 本文件归静态前场独占；切片阶段只填页面行为，不碰壳。
 */
export class NoParam {
}

export const enum Routes {
  MAIN = 'Main',
  MANAGE_SETTINGS = 'ManageSettings',
  IMPORT_OPMLFILE = 'ImportOPMLFile',
  ADD_FEED_FROM_SHARE = 'AddFeedFromShare',
  OPEN_LINK_IN_DEFAULT = 'OpenLinkInDefault',
  FEED_WIDGET_SETTINGS = 'FeedWidgetSettings',
  SEARCH = 'Search',
  IMPORT = 'Import',
  FEED = 'Feed',
  ARTICLE = 'Article',
  SEARCH_FEED = 'SearchFeed',
  ADD_FEED = 'AddFeed',
  EDIT_FEED = 'EditFeed',
  SETTINGS = 'Settings',
  TEXT_SETTINGS = 'TextSettings',
  SYNC_SCREEN = 'SyncScreen',
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
    if (names.indexOf(Routes.MAIN) >= 0) {
      AppRouter.stack.popToName(Routes.MAIN);
      return;
    }
    AppRouter.stack.clear();
    AppRouter.stack.pushPathByName(Routes.MAIN, new NoParam());
  }
}
