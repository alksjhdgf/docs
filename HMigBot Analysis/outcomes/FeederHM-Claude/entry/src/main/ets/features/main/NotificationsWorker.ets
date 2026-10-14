/**
 * NotificationsWorker.ets —— 源 notifications/NotificationsWorker.kt（APP-A14 / NW-A15）。
 *
 * 主界面前台期间（源 MainActivity.onStart → runForever / onStop → stopForever）持续监听"需通知条目" id 集合
 * （DbNotifier 驱动重查，≙ Room Flow）：
 *  - runningReduce：从第二次发射起，prev 中不在 current 的条目取消其通知；current 为空则取消汇总通知；
 *  - collectLatest + delay(100)：current 非空时仅重发汇总通知（updateSummaryOnly=true）。
 * 发布通知的实现属通知切片（features/notify），经 setSummaryNotificationUpdater 注入（未注册 no-op）。
 */
import { notificationManager } from '@kit.NotificationKit';
import { Repository } from '../../core/repo/Repository';
import { PostedNotifications } from '../notify/PostedNotifications';

const LOG_TAG: string = 'FEEDER_NW';

/** 源 model/RssNotifications.SUMMARY_NOTIFICATION_ID */
export const SUMMARY_NOTIFICATION_ID: number = 2147483646;

/** 源 notify(context, updateSummaryOnly = true)：只更新汇总通知 */
export type SummaryNotificationUpdater = () => Promise<void>;

let summaryUpdater: SummaryNotificationUpdater | null = null;

/** 通知切片注册"仅更新汇总通知"实现；传 null 解除 */
export function setSummaryNotificationUpdater(cb: SummaryNotificationUpdater | null): void {
  summaryUpdater = cb;
}

/** 源 Long.toInt()：取低 32 位（与通知切片发布单条通知的 id 换算一致） */
export function notificationIdOf(feedItemId: number): number {
  return feedItemId | 0;
}

/** 源 cancelNotifications：无通知权限直接返回；逐条 nm.cancel(id.toInt()) */
export async function cancelNotifications(feedItemIds: number[]): Promise<void> {
  if (feedItemIds.length === 0) {
    return;
  }
  // 应用自身取消的通知不计为用户划掉（NW-A13 进程外补偿的对账记录）
  PostedNotifications.forget(feedItemIds, SUMMARY_NOTIFICATION_ID);
  let enabled: boolean = false;
  try {
    enabled = await notificationManager.isNotificationEnabled();
  } catch (e) {
    console.warn(`${LOG_TAG}: isNotificationEnabled failed: ${JSON.stringify(e)}`);
    return;
  }
  if (!enabled) {
    return;
  }
  for (const id of feedItemIds) {
    try {
      await notificationManager.cancel(notificationIdOf(id));
    } catch (e) {
      console.warn(`${LOG_TAG}: cancel ${id} failed: ${JSON.stringify(e)}`);
    }
  }
}

/** 源 unNotifyForMissingItems（纯差集逻辑抽出便于单测） */
export function missingItems(prev: number[], current: number[]): number[] {
  const cur: Set<number> = new Set<number>(current);
  return prev.filter((id: number): boolean => !cur.has(id));
}

export class NotificationsWorker {
  private static inst: NotificationsWorker | null = null;

  private unsubscribe: (() => void) | null = null;
  /** runningReduce 累积值；null = 本轮尚未首次发射 */
  private prev: number[] | null = null;
  /** collectLatest：新发射取消上一轮尚未完成的 delay */
  private latestTimer: number = -1;
  /** 每次 runForever/stopForever 换代，旧代回调作废（≙ job.cancel） */
  private generation: number = 0;

  static instance(): NotificationsWorker {
    if (NotificationsWorker.inst === null) {
      NotificationsWorker.inst = new NotificationsWorker();
    }
    return NotificationsWorker.inst as NotificationsWorker;
  }

  isRunning(): boolean {
    return this.unsubscribe !== null;
  }

  runForever(): void {
    this.cancelJob();
    const gen: number = this.generation;
    this.prev = null;
    try {
      this.unsubscribe = Repository.instance().observeFeedItemsNeedingNotifying((ids: number[]): void => {
        if (gen !== this.generation) {
          return;
        }
        this.onEmit(gen, ids);
      });
    } catch (e) {
      console.error(`${LOG_TAG}: observe failed: ${JSON.stringify(e)}`);
      this.unsubscribe = null;
    }
  }

  stopForever(): void {
    this.cancelJob();
  }

  private cancelJob(): void {
    this.generation++;
    const off: (() => void) | null = this.unsubscribe;
    this.unsubscribe = null;
    if (off !== null) {
      try {
        off();
      } catch (e) {
        console.warn(`${LOG_TAG}: unsubscribe failed: ${JSON.stringify(e)}`);
      }
    }
    if (this.latestTimer !== -1) {
      clearTimeout(this.latestTimer);
      this.latestTimer = -1;
    }
    this.prev = null;
  }

  private onEmit(gen: number, current: number[]): void {
    const prev: number[] | null = this.prev;
    if (prev !== null) {
      this.unNotifyForMissingItems(prev, current).catch((e: Error) => {
        console.error(`${LOG_TAG}: Error in notifications worker: ${e?.message}`);
      });
    }
    // Always pass current on
    this.prev = current;
    if (this.latestTimer !== -1) {
      clearTimeout(this.latestTimer);
    }
    this.latestTimer = setTimeout(() => {
      this.latestTimer = -1;
      if (gen !== this.generation) {
        return;
      }
      // Individual notifications are triggered during sync, not here
      // but the summary notification still needs updating
      if (current.length > 0) {
        this.updateSummary();
      }
    }, 100);
  }

  /** 源 unNotifyForMissingItems：current 空 → 取消汇总；prev 中消失的条目逐个取消 */
  async unNotifyForMissingItems(prev: number[], current: number[]): Promise<void> {
    if (current.length === 0) {
      await cancelNotifications([SUMMARY_NOTIFICATION_ID]);
    }
    await cancelNotifications(missingItems(prev, current));
  }

  private updateSummary(): void {
    const cb: SummaryNotificationUpdater | null = summaryUpdater;
    if (cb === null) {
      console.info(`${LOG_TAG}: no summary notification updater registered`);
      return;
    }
    cb().catch((e: Error) => {
      console.error(`${LOG_TAG}: summary notify failed: ${e?.message}`);
    });
  }
}
