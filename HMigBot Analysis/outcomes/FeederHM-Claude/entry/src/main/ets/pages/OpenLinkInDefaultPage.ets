/**
 * OpenLinkInDefaultPage —— 源 ui/OpenLinkInDefaultActivity.kt + OpenLinkInDefaultActivityViewModel.kt
 * （无界面代理；仅由通知点击 Want 经 DeepLinkRouter → OpenLinkInDefaultParam 进入）。
 *
 *  - 汇总通知（APP-A51）：通知所含条目 markAsNotified（不标已读）→ 打开主界面并定位到 URI 指定的 feed/tag
 *    （DeepLinkRouter.navigateToFeed 清栈，本页随之出栈）。
 *  - 单篇通知（APP-A52）：markAsReadAndNotified(id) → 取消该通知；link 非空时 action==OPEN_IN_CUSTOM_TAB
 *    → 应用内浏览页（工具栏色 R.color.primary），否则默认浏览器（openAdjacentIfSuitable=false）。
 *  - APP-A53：写库在应用级作用域（AppScope）执行且本页 await 其完成后才出栈——不随页面关闭被取消
 *    （源 lifecycleScope 在 finish 后被取消属源竞态，不复刻）。
 *  - APP-A54：无可处理链接的应用 → Toast `no_activity_for_link`（ActivityLauncher 内部），其余异常同样 Toast，不崩。
 *  - APP-A50/A55：页面为 DIALOG 模式透明层、无任何可见内容（不闪现空白页），处理完毕立即出栈，
 *    不在主任务栈留下额外页面；参数缺失 → 直接出栈。
 */
import { common } from '@kit.AbilityKit';
import { AppRouter, Routes } from '../common/Router';
import { AppScope } from '../core/app/AppBootstrap';
import { OpenLinkInDefaultParam, OpenLinkKind, FeedParam, ACTION_OPEN_IN_CUSTOM_TAB } from '../core/app/RouteParams';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { ID_UNSET } from '../core/model/Enums';
import { Repository } from '../core/repo/Repository';
import { ActivityLauncher } from '../core/platform/LinkOpener';
import { RssNotifications } from '../features/notify/RssNotifications';

const LOG_TAG: string = 'FEEDEROpenInWebBrowser';

/** 源 res/values/colors.xml `primary` = #ff0b8043（CustomTab toolbarColor） */
const PRIMARY_ARGB_FALLBACK: number = 0xFF0B8043;

@Builder
export function OpenLinkInDefaultPageBuilder() {
  OpenLinkInDefaultPage()
}

/** 在应用级作用域执行写库；返回的 Promise 在任务结束（成功或失败）后 resolve */
function launchInAppScope(name: string, task: () => Promise<void>): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    AppScope.launch(name, async (): Promise<void> => {
      try {
        await task();
      } finally {
        resolve();
      }
    });
  });
}

@ComponentV2
struct OpenLinkInDefaultPage {
  private handled: boolean = false;
  private finished: boolean = false;

  private primaryArgb(): number {
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        return ctx.resourceManager.getColorSync($r('app.color.primary').id);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: resolve primary color failed: ${JSON.stringify(e)}`);
    }
    return PRIMARY_ARGB_FALLBACK;
  }

  private showNoActivityToast(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.no_activity_for_link'),
        duration: 2000,
      });
    } catch (e) {
      console.warn(`${LOG_TAG}: toast failed: ${JSON.stringify(e)}`);
    }
  }

  /** 源 finish()：本页仍在栈顶则出栈（汇总分支已被 Feed 清栈时无需处理） */
  private finishProxy(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const names: string[] = AppRouter.stack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === Routes.OPEN_LINK_IN_DEFAULT) {
      AppRouter.stack.pop(false);
    }
  }

  private async handle(p: OpenLinkInDefaultParam): Promise<void> {
    if (p.kind === OpenLinkKind.SUMMARY_NOTIFICATION) {
      // 源 viewModel.markAsNotifiedInBackground(ids)：只标"已通知"
      const ids: number[] = p.itemsToMarkAsNotified;
      await launchInAppScope('markAsNotified', (): Promise<void> => Repository.instance().markAsNotified(ids));
      // 源 startActivity(ACTION_VIEW uri → MainActivity, openAdjacentIfSuitable=false)
      const f: FeedParam | null = p.feedTarget;
      this.finished = true;
      DeepLinkRouter.navigateToFeed(f !== null ? f.feedId : ID_UNSET, f !== null ? f.tag : '');
      return;
    }
    this.handleNotificationActions(p);
  }

  /** 源 handleNotificationActions：标记 + 取消通知（等待完成）与打开链接并行，二者结束后出栈 */
  private handleNotificationActions(p: OpenLinkInDefaultParam): void {
    const id: number = p.itemId;
    const write: Promise<void> = launchInAppScope('markAsReadAndNotified', async (): Promise<void> => {
      await Repository.instance().markAsReadAndNotified(id);
      await RssNotifications.cancelNotification(id);
    });
    const open: Promise<void> = this.openLink(p);
    Promise.all([write, open]).then(() => {
      this.finishProxy();
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: notification action failed: ${e?.message}`);
      this.finishProxy();
    });
  }

  private async openLink(p: OpenLinkInDefaultParam): Promise<void> {
    const link: string | null = p.link;
    if (link === null) {
      return;
    }
    const launcher: ActivityLauncher | null = ActivityLauncher.instance();
    if (launcher === null) {
      console.error(`${LOG_TAG}: Failed to start browser: ActivityLauncher not bound`);
      this.showNoActivityToast();
      return;
    }
    try {
      if (p.action === ACTION_OPEN_IN_CUSTOM_TAB) {
        await launcher.openLinkInCustomTab(link, this.primaryArgb(), false);
      } else {
        await launcher.openLinkInBrowser(link, false);
      }
    } catch (e) {
      // 无可处理应用的情况 ActivityLauncher 已 Toast；其余意外异常同源 catch(Throwable) → Toast
      console.error(`${LOG_TAG}: Failed to start browser: ${JSON.stringify(e)}`);
      this.showNoActivityToast();
    }
  }

  build() {
    NavDestination() {
      // 无界面代理：不渲染任何内容
    }
    .mode(NavDestinationMode.DIALOG)
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
    .onReady((ctx: NavDestinationContext) => {
      if (this.handled) {
        return;
      }
      this.handled = true;
      const param: Object = ctx.pathInfo.param as Object;
      if (!(param instanceof OpenLinkInDefaultParam)) {
        console.warn(`${LOG_TAG}: missing OpenLinkInDefaultParam`);
        this.finishProxy();
        return;
      }
      this.handle(param as OpenLinkInDefaultParam).catch((e: Error) => {
        console.error(`${LOG_TAG}: proxy failed: ${e?.message}`);
        this.finishProxy();
      });
    })
    .onBackPressed(() => {
      this.finishProxy();
      return true;
    })
  }
}
