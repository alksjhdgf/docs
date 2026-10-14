/**
 * PostedNotifications.ets —— NW-A13（划掉通知 → notified=1）在应用进程未运行时的补偿路径。
 *
 * 源 RssNotificationBroadcastReceiver（manifest 静态注册，进程死亡也会被拉起）收 deleteIntent → markAsNotified。
 * 鸿蒙：removalWantAgent 只能是 START_ABILITY / START_ABILITIES / START_SERVICE(仅 FA) / SEND_COMMON_EVENT
 * （@ohos.app.ability.wantAgent.d.ts OperationType）；第三方无静态公共事件订阅（公开 SDK 无
 * StaticSubscriberExtensionAbility）；划掉时拉起 UIAbility 会把应用顶到前台，不可接受。
 * 故：进程存活 → 公共事件快路径（NotificationActions.subscribe）；进程不在 → 本模块在下一次进程启动 /
 * 下一次 notify() 前对账：记录"已发布且仍待用户处理"的通知，对比 notificationManager.getActiveNotifications()，
 * 用户已移除者照源 markAsNotified（汇总被移除 → 汇总内全部条目 markAsNotified + 取消）。
 * - 应用自身 cancel 的条目从记录中剔除（forget），不算用户划掉；
 * - 重启（开机时刻变化）或通知权限关闭导致的消失不算划掉（Android 此时也不发 deleteIntent），记录清空。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { notificationManager } from '@kit.NotificationKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { FeedItemDao } from '../../core/db/FeedItemDao';

const LOG_TAG: string = 'FEEDER_NOTIFY_POSTED';
const RECORD_FILE: string = 'notifications_posted.json';
/** 开机时刻（now - uptime）判定同一次开机的容差 */
export const BOOT_TOLERANCE_MS: number = 60 * 1000;

export class PostedRecord {
  bootEpochMs: number = 0;
  singles: number[] = [];
  summary: number[] = [];

  toJson(): string {
    return `{"bootEpochMs":${this.bootEpochMs},"singles":${JSON.stringify(this.singles)},` +
      `"summary":${JSON.stringify(this.summary)}}`;
  }

  static fromJson(text: string): PostedRecord | null {
    try {
      const o: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const r: PostedRecord = new PostedRecord();
      const b: Object | undefined = o['bootEpochMs'];
      r.bootEpochMs = typeof b === 'number' ? b as number : 0;
      r.singles = numberArray(o['singles']);
      r.summary = numberArray(o['summary']);
      return r;
    } catch (e) {
      return null;
    }
  }
}

function numberArray(v: Object | undefined): number[] {
  const out: number[] = [];
  if (v === undefined || v === null || !Array.isArray(v)) {
    return out;
  }
  for (const x of v as Object[]) {
    const n: number = Number(x);
    if (Number.isSafeInteger(n)) {
      out.push(n);
    }
  }
  return out;
}

/**
 * 纯逻辑：哪些条目应照源 markAsNotified。
 * 不同次开机 → 空（通知被系统清空，非用户划掉）；单条通知 id 不在活动集 → 该条；汇总不在活动集 → 汇总全部条目。
 */
export function dismissedItemIds(rec: PostedRecord, activeIds: Set<number>, bootEpochNowMs: number,
  summaryNotificationId: number, idOf: (itemId: number) => number): number[] {
  if (Math.abs(rec.bootEpochMs - bootEpochNowMs) > BOOT_TOLERANCE_MS) {
    return [];
  }
  const out: Set<number> = new Set<number>();
  for (const id of rec.singles) {
    if (!activeIds.has(idOf(id))) {
      out.add(id);
    }
  }
  if (rec.summary.length > 0 && !activeIds.has(summaryNotificationId)) {
    for (const id of rec.summary) {
      out.add(id);
    }
  }
  return Array.from(out);
}

export class PostedNotifications {
  private static dir: string = '';

  /** 记录目录（filesDir）；各发布/取消通知的进程在 RssNotifications.init 时设置 */
  static setDirectory(filesDir: string): void {
    PostedNotifications.dir = filesDir;
  }

  private static path(): string {
    return PostedNotifications.dir.length > 0 ? `${PostedNotifications.dir}/${RECORD_FILE}` : '';
  }

  static bootEpochMs(): number {
    try {
      return Date.now() - systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    } catch (e) {
      return 0;
    }
  }

  static read(): PostedRecord | null {
    const p: string = PostedNotifications.path();
    if (p.length === 0) {
      return null;
    }
    try {
      if (!fs.accessSync(p)) {
        return null;
      }
      return PostedRecord.fromJson(fs.readTextSync(p));
    } catch (e) {
      console.warn(`${LOG_TAG}: read failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  static write(rec: PostedRecord): void {
    const p: string = PostedNotifications.path();
    if (p.length === 0) {
      return;
    }
    let file: fs.File | null = null;
    try {
      file = fs.openSync(p, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, rec.toJson());
    } catch (e) {
      console.warn(`${LOG_TAG}: write failed: ${JSON.stringify(e)}`);
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (ce) {
          console.warn(`${LOG_TAG}: close failed: ${JSON.stringify(ce)}`);
        }
      }
    }
  }

  /** notify() 发布后：单条记录 = 仍在记录中的 ∪ 本批；汇总记录 = 本批（updateSummaryOnly 时单条不变） */
  static recordPublished(singles: number[], summary: number[]): void {
    if (PostedNotifications.path().length === 0) {
      return;
    }
    const prev: PostedRecord | null = PostedNotifications.read();
    const rec: PostedRecord = new PostedRecord();
    rec.bootEpochMs = PostedNotifications.bootEpochMs();
    const s: Set<number> = new Set<number>(prev !== null ? prev.singles : []);
    for (const id of singles) {
      s.add(id);
    }
    rec.singles = Array.from(s);
    rec.summary = summary.slice();
    PostedNotifications.write(rec);
  }

  /** 应用自身取消的通知不算用户划掉（NotificationsWorker.cancelNotifications 调用）；summaryId 命中则清汇总记录 */
  static forget(itemIds: number[], summaryNotificationId: number): void {
    if (itemIds.length === 0 || PostedNotifications.path().length === 0) {
      return;
    }
    const rec: PostedRecord | null = PostedNotifications.read();
    if (rec === null) {
      return;
    }
    const drop: Set<number> = new Set<number>(itemIds);
    rec.singles = rec.singles.filter((id: number): boolean => !drop.has(id));
    if (drop.has(summaryNotificationId)) {
      rec.summary = [];
    }
    PostedNotifications.write(rec);
  }

  /**
   * 对账：返回照源已 markAsNotified 的条目 id（调用方负责取消这些条目残留的单条通知）。
   * 通知权限关闭 / 查询失败 → 不标记（不确定即不改库），权限关闭时清空记录。
   */
  static async reconcile(summaryNotificationId: number, idOf: (itemId: number) => number): Promise<number[]> {
    const rec: PostedRecord | null = PostedNotifications.read();
    if (rec === null || (rec.singles.length === 0 && rec.summary.length === 0)) {
      return [];
    }
    let enabled: boolean = false;
    try {
      enabled = await notificationManager.isNotificationEnabled();
    } catch (e) {
      return [];
    }
    if (!enabled) {
      PostedNotifications.write(new PostedRecord());
      return [];
    }
    let active: notificationManager.NotificationRequest[] = [];
    try {
      active = await notificationManager.getActiveNotifications();
    } catch (e) {
      console.warn(`${LOG_TAG}: getActiveNotifications failed: ${JSON.stringify(e)}`);
      return [];
    }
    const activeIds: Set<number> = new Set<number>();
    for (const r of active) {
      if (r.id !== undefined) {
        activeIds.add(r.id);
      }
    }
    const bootNow: number = PostedNotifications.bootEpochMs();
    const dismissed: number[] = dismissedItemIds(rec, activeIds, bootNow, summaryNotificationId, idOf);
    if (dismissed.length > 0) {
      await FeedItemDao.markAsNotified(dismissed);
      console.info(`${LOG_TAG}: marked ${dismissed.length} dismissed item(s) as notified`);
    }
    const next: PostedRecord = new PostedRecord();
    next.bootEpochMs = bootNow;
    if (Math.abs(rec.bootEpochMs - bootNow) <= BOOT_TOLERANCE_MS) {
      const gone: Set<number> = new Set<number>(dismissed);
      next.singles = rec.singles.filter((id: number): boolean => !gone.has(id));
      next.summary = activeIds.has(summaryNotificationId) ? rec.summary : [];
    }
    PostedNotifications.write(next);
    return dismissed;
  }
}
