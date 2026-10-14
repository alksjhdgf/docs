/**
 * Index —— Navigation 壳，由 wire-routes 生成。路由注册唯一真源 = resources/base/profile/route_map.json
 * （systemRouterMap，8 条），冷启自动入栈 launcher（Main）。
 * 本文件归静态前场独占（冻结件）：smokeRoute 直达钩子 + hmigSmoke 着陆日志供波级冒烟核证，勿删勿改。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppRouter, Routes } from '../common/Router';

@Entry
@ComponentV2
struct Index {
  navStack: NavPathStack = AppRouter.stack;

  aboutToAppear(): void {
    // hmig:smokeLanding 着陆证据：每次页面显示打一条 hilog（smoke.mjs 经 hilog -x -T hmigSmoke 核对着陆页名）
    AppRouter.stack.setInterception({
      didShow: (from: NavDestinationContext | NavBar, to: NavDestinationContext | NavBar,
        operation: NavigationOperation, isAnimated: boolean): void => {
        let shown: string = 'navBar';
        if (typeof to !== 'string') {
          shown = (to as NavDestinationContext).pathInfo.name;
        }
        hilog.info(0x0000, 'hmigSmoke', 'didShow %{public}s', shown);
      }
    });
    if (AppRouter.stack.size() === 0) {
      // smokeRoute：波级冒烟直达钩子（aa start --ps smokeRoute <名>，EntryAbility 透传；正常启动为空走首页链）
      // 两个独立 push（勿并三元）：首页跳转保持静态常量形态，check-routes 首屏链路门才可解析
      const smokeRoute = AppStorage.get<string>('smokeRoute') ?? '';
      if (smokeRoute.length) {
        AppRouter.pushName(smokeRoute);
      } else {
        AppRouter.push(Routes.MAIN, undefined);
      }
    }
  }

  build() {
    Navigation(this.navStack) {
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}
