/**
 * NotificationActionAbility.ets —— 通知 "Mark as read" 按钮的进程无关入口（NW-A12）。
 *
 * 源 RssNotificationBroadcastReceiver 为 manifest 静态接收器：应用进程不在时系统也会拉起它执行
 * markAsReadAndNotified + 取消通知。鸿蒙第三方应用的 WantAgent 只能 START_ABILITY / START_ABILITIES /
 * START_SERVICE(仅 FA 模型) / SEND_COMMON_EVENT（@ohos.app.ability.wantAgent.d.ts OperationType），
 * 公共事件只有进程内动态订阅者能收到（公开 SDK 无 StaticSubscriberExtensionAbility）。
 * 故按钮改为 START_ABILITY 拉起本 UIAbility：不加载页面，初始化数据库后照源写库并取消通知，随即 terminateSelf
 * （removeMissionAfterTerminate，不留最近任务）。代价：点击瞬间可见启动窗（平台策略，见降级候选 deg-acc-notify-action）。
 * 进程内快路径（公共事件订阅，NotificationActions.subscribe）保留，处理既有 SEND_COMMON_EVENT 型通知与划掉事件。
 */
import { AbilityConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppDatabase } from '../core/db/AppDatabase';
import { NotificationActions } from '../features/notify/NotificationActions';
import { ACTION_MARK_AS_READ, RssNotifications, notificationEventName } from '../features/notify/RssNotifications';

const LOG_TAG: string = 'FEEDER_NOTIFY_ABILITY';

export default class NotificationActionAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handle(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handle(want);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 不加载任何页面：动作完成后立即 terminateSelf
    console.info(`${LOG_TAG}: window stage created (no content)`);
  }

  private handle(want: Want): void {
    const ctx: common.UIAbilityContext = this.context;
    const bundle: string = ctx.applicationInfo.name;
    const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
    const uri: string = want.uri ?? '';
    const isMarkAsRead: boolean = want.action === notificationEventName(bundle, ACTION_MARK_AS_READ);
    const run = async (): Promise<void> => {
      if (!isMarkAsRead) {
        console.warn(`${LOG_TAG}: ignored action ${want.action ?? ''}`);
        return;
      }
      await AppDatabase.init(ctx);
      RssNotifications.init(ctx);
      await NotificationActions.onReceive(ACTION_MARK_AS_READ, params, uri);
    };
    run().catch((e: Error) => {
      console.error(`${LOG_TAG}: action failed: ${e?.message}`);
    }).finally(() => {
      ctx.terminateSelf().catch((e: Error) => {
        console.error(`${LOG_TAG}: terminateSelf failed: ${e?.message}`);
      });
    });
  }
}
