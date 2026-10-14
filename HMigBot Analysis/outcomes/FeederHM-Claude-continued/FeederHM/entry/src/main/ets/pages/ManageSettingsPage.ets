/**
 * ManageSettingsPage —— 源 ui/ManageSettingsActivity.kt（系统"流量使用 → 应用设置"MANAGE_NETWORK_USAGE 入口）。
 *
 * 源直接渲染与应用内相同的 SettingsScreen，仅替换三个导航回调。本页为宿主：进入即在其上打开应用内 Settings 页
 * （同一实现 = 相同内容与行为，APP-A21），并改写 Settings 发出的导航，使之与源回调一致：
 *  - 返回/向上（Settings 出栈、本页重新可见）→ onNavigateUpFromIntentActivities：打开主界面（Feed）并关闭本页（APP-A22）；
 *  - 同步设置项（Settings 打开 SyncScreen）→ 打开主界面的同步页并关闭本页（返回栈 = Feed → SyncScreen，APP-A23）；
 *    源以含字面量 `{syncCode}`/`{secretKey}` 占位符的 uriPattern 发出（源缺陷），此处透传 Settings 给出的实际参数；
 *  - 文字设置项（Settings 打开 TextSettings）→ 打开主界面的文字设置页并关闭本页（APP-A24；源对空深链列表 `.first()`
 *    必崩，属源缺陷，不复刻）。
 *  - 顶部避让状态栏（APP-A20）：本页自身背景层按 AvoidArea 避让；Settings 页自身负责其内容避让。
 * 导航改写经 UIObserver `navDestinationSwitch` 观察（不占用 AppRouter.stack 的唯一 setInterception，后者归 Index 冒烟钩子）。
 */
import { uiObserver } from '@kit.ArkUI';
import { AppRouter, Routes } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { SettingsRouteParam, SyncParam } from '../core/app/RouteParams';
import { ID_UNSET } from '../core/model/Enums';
import { FeederTheme } from '../ui/common/Theme';

const LOG_TAG: string = 'FEEDER_MANAGESETTINGS';

@Builder
export function ManageSettingsPageBuilder() {
  ManageSettingsPage()
}

/** Settings 打开的、需改道到"主界面内"打开的目的地（源 onNavigateToSyncScreen / onNavigateToTextSettingsScreen） */
function isRedirectedRoute(name: string): boolean {
  return name === Routes.SYNC_SCREEN || name === Routes.TEXT_SETTINGS;
}

@ComponentV2
struct ManageSettingsPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  private settingsOpened: boolean = false;
  private covered: boolean = false;
  private leaving: boolean = false;
  private switchCb: ((info: uiObserver.NavDestinationSwitchInfo) => void) | null = null;

  aboutToAppear(): void {
    const cb = (info: uiObserver.NavDestinationSwitchInfo): void => {
      this.onDestinationSwitch(info);
    };
    try {
      this.getUIContext().getUIObserver().on('navDestinationSwitch', cb);
      this.switchCb = cb;
    } catch (e) {
      console.error(`${LOG_TAG}: observe navDestinationSwitch failed: ${JSON.stringify(e)}`);
    }
  }

  aboutToDisappear(): void {
    const cb: ((info: uiObserver.NavDestinationSwitchInfo) => void) | null = this.switchCb;
    this.switchCb = null;
    if (cb !== null) {
      try {
        this.getUIContext().getUIObserver().off('navDestinationSwitch', cb);
      } catch (e) {
        console.warn(`${LOG_TAG}: unobserve failed: ${JSON.stringify(e)}`);
      }
    }
  }

  /** 进入即显示完整设置页（与应用内 Settings 同一页面实现） */
  private openSettings(): void {
    if (this.settingsOpened) {
      return;
    }
    this.settingsOpened = true;
    AppRouter.push(Routes.SETTINGS, new SettingsRouteParam());
  }

  /** 源 onNavigateUpFromIntentActivities()：startActivity(MainActivity) + finish() */
  private navigateUpToMain(): void {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    DeepLinkRouter.navigateToFeed(ID_UNSET, '');
  }

  /**
   * Settings（位于本页正上方）打开 SyncScreen / TextSettings 时：改为"打开主界面并跳到该页、关闭本页"——
   * 返回栈重建为 Feed → 目标页（≙ 源以深链 VIEW 启动 MainActivity 后 finish()）。
   */
  private onDestinationSwitch(info: uiObserver.NavDestinationSwitchInfo): void {
    if (this.leaving || typeof info.to === 'string') {
      return;
    }
    const to: uiObserver.NavDestinationInfo = info.to as uiObserver.NavDestinationInfo;
    const toName: string = typeof to.name === 'string' ? to.name as string : '';
    if (!isRedirectedRoute(toName)) {
      return;
    }
    const names: string[] = AppRouter.stack.getAllPathName();
    const me: number = names.lastIndexOf(Routes.MANAGE_SETTINGS);
    if (me < 0 || names.length !== me + 3 || names[me + 1] !== Routes.SETTINGS || names[me + 2] !== toName) {
      return;
    }
    this.leaving = true;
    const param: Object | undefined = to.param;
    // 不在观察回调中同步改栈：下一轮事件循环再重建
    setTimeout(() => {
      DeepLinkRouter.navigateToFeed(ID_UNSET, '');
      if (toName === Routes.SYNC_SCREEN) {
        const sp: SyncParam = param instanceof SyncParam ? param as SyncParam : new SyncParam();
        DeepLinkRouter.navigateToSyncScreen(sp.syncCode, sp.secretKey);
      } else {
        DeepLinkRouter.navigateToTextSettings();
      }
    }, 0);
  }

  build() {
    NavDestination() {
      // 宿主层：Settings 页覆盖其上；仅在跳转瞬间可见，铺主题背景并避让系统栏
      Column() {
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.avoid.top, bottom: this.avoid.bottom })
      .backgroundColor(FeederTheme.colors.background)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady(() => {
      this.openSettings();
    })
    .onHidden(() => {
      if (this.settingsOpened) {
        this.covered = true;
      }
    })
    .onShown(() => {
      // Settings 已出栈（返回/向上）→ 打开主界面并关闭本页
      if (this.covered) {
        this.navigateUpToMain();
      }
    })
    .onBackPressed(() => {
      this.navigateUpToMain();
      return true;
    })
  }
}
