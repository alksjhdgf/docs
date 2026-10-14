/**
 * SyncScheduler.ets —— 源 background/*.kt（JobScheduler 任务）的鸿蒙实现。
 *
 * 映射：
 *  - 周期同步 RSS_SYNC_PERIODIC(2)：WorkScheduler 周期任务（repeatCycleTime + networkType WIFI/ANY + chargerType + isPersisted）；
 *    MANUAL → stopWork；设置变更 → replace 重排；启动时不存在才补建（FS-A47/A48）。周期下限 20 分钟（15 分钟档取 20 分钟）。
 *  - 一次性任务（RSS_SYNC / FULL_TEXT_SYNC / SYNC_CHAIN_*）：约束当下满足 → 进程内立即执行；否则登记一次性
 *    WorkScheduler 任务，待系统在约束满足时由 FeederWorkSchedulerAbility 执行（≙ JobScheduler 约束等待）。
 *  - 用户触发同步：同步期间发布标题 "Syncing" 的常驻低优先级通知并申请短时任务，结束即移除（FS-A51）。
 *  - 同步结束（finally）调用新条目通知钩子（FS-A50）。
 *  - 孤儿文件清理 CLEANUP_ORPHANED_FILES(7)：每日周期 + isDeepIdle + 充电 + isPersisted（FS-A55）。
 * 本文件 default export 的 FeederWorkSchedulerAbility 须在 module.json5 extensionAbilities 中以 type "workScheduler" 声明
 * （归 fnd-app-init，见 unresolved）。
 */
import { workScheduler, WorkSchedulerExtensionAbility, backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { ID_UNSET } from '../model/Enums';
import { FilePathProvider } from '../util/Constants';
import { SettingsStore } from '../settings/SettingsStore';
import { setBlocklistChangedHook, setSyncScheduleHook } from '../settings/SettingsHooks';
import { AppDatabase } from '../db/AppDatabase';
import { BlocklistDao } from '../db/BlocklistDao';
import { HttpClient } from '../net/HttpClient';
import { AsyncMutex } from '../net/Interceptors';
import { toError } from '../net/NetworkResult';
import { FullTextParser } from '../html/FullTextParser';
import {
  currentlyCharging, currentlyConnected, currentlyUnmetered, isOkToSyncAutomatically
} from '../platform/SystemConditions';
import {
  RssLocalSync, SyncChainClient, applyRemoteReadMarks, cleanupOrphanedFiles, getSyncChainClient, isSyncChainConfigured,
  setFullTextSyncRequester
} from './RssLocalSync';

const LOG_TAG: string = 'FEEDER_SYNC_SCHEDULER';

/** 源 BackgroundJobId（同时作为 WorkScheduler workId） */
export enum BackgroundJobId {
  RSS_SYNC = 1,
  RSS_SYNC_PERIODIC = 2,
  FULL_TEXT_SYNC = 3,
  SYNC_CHAIN_GET_UPDATES = 4,
  SYNC_CHAIN_SEND_READ = 5,
  BLOCKLIST_UPDATE = 6,
  CLEANUP_ORPHANED_FILES = 7,
}

/** module.json5 中 WorkScheduler 扩展能力名 */
export const WORK_SCHEDULER_ABILITY_NAME: string = 'FeederWorkSchedulerAbility';
/** 鸿蒙 WorkScheduler 周期任务最小间隔（系统管控；15 分钟档按此执行） */
export const MIN_REPEAT_CYCLE_MS: number = 20 * 60 * 1000;
export const SYNC_NOTIFICATION_ID: number = 42623;
export const SYNC_NOTIFICATION_GROUP: string = 'com.nononsenseapps.feeder.SYNC';
export const ARG_FEED_ID: string = 'feed_id';
export const ARG_FEED_TAG: string = 'feed_tag';
export const ARG_FORCE_NETWORK: string = 'force_network';
export const ARG_ONLY_NEW: string = 'only_new';
const SEND_READ_MIN_LATENCY_MS: number = 10 * 1000;
const DAY_MS: number = 24 * 60 * 60 * 1000;

/** 源 notify(context)（新条目通知；features/notify 注册） */
export type NewItemsNotifier = () => Promise<void>;

let newItemsNotifier: NewItemsNotifier | null = null;

export function setNewItemsNotifier(cb: NewItemsNotifier | null): void {
  newItemsNotifier = cb;
}

async function notifyNewItems(): Promise<void> {
  const cb: NewItemsNotifier | null = newItemsNotifier;
  if (cb === null) {
    console.info(LOG_TAG, 'No new-items notifier registered');
    return;
  }
  try {
    await cb();
  } catch (e) {
    console.error(LOG_TAG, `notify failed: ${toError(e as Object).message}`);
  }
}

function readNumberParam(work: workScheduler.WorkInfo, key: string, def: number): number {
  const p: Record<string, number | string | boolean> | undefined = work.parameters;
  if (p === undefined) {
    return def;
  }
  const v: number | string | boolean | undefined = p[key];
  return typeof v === 'number' ? v as number : def;
}

function readStringParam(work: workScheduler.WorkInfo, key: string, def: string): string {
  const p: Record<string, number | string | boolean> | undefined = work.parameters;
  if (p === undefined) {
    return def;
  }
  const v: number | string | boolean | undefined = p[key];
  return typeof v === 'string' ? v as string : def;
}

function readBoolParam(work: workScheduler.WorkInfo, key: string, def: boolean): boolean {
  const p: Record<string, number | string | boolean> | undefined = work.parameters;
  if (p === undefined) {
    return def;
  }
  const v: number | string | boolean | undefined = p[key];
  return typeof v === 'boolean' ? v as boolean : def;
}

/**
 * 存储层就绪钩子（反向依赖注入，§C）：features/* 的进程级安装项（如同步链客户端 installSyncChain）由各进程入口
 * （EntryAbility / WorkScheduler 扩展壳 / 卡片扩展）在模块加载时注册；AppBootstrap.run 第 5 步之后与
 * bootstrapHeadless 在 SyncScheduler.init 之后执行。未注册 → no-op。同名覆盖、执行需幂等。
 */
export type StorageReadyHook = (ctx: common.Context) => Promise<void>;

export class SyncScheduler {
  private static storageReadyHooks: Map<string, StorageReadyHook> = new Map<string, StorageReadyHook>();
  private static ctx: common.Context | null = null;
  private static bundleName: string = '';
  private static filePaths: FilePathProvider | null = null;
  private static fullTextMutex: AsyncMutex = new AsyncMutex();
  private static sendReadTimer: number = -1;

  /** 应用（或扩展进程）初始化：配置 RssLocalSync 路径并注册设置钩子。幂等。 */
  /** 注册存储层就绪钩子（同名覆盖） */
  static addStorageReadyHook(hookName: string, cb: StorageReadyHook): void {
    SyncScheduler.storageReadyHooks.set(hookName, cb);
  }

  /** 依次执行全部存储层就绪钩子；单个失败只记日志 */
  static async runStorageReadyHooks(ctx: common.Context): Promise<void> {
    const names: string[] = Array.from(SyncScheduler.storageReadyHooks.keys());
    for (const hookName of names) {
      const cb: StorageReadyHook | undefined = SyncScheduler.storageReadyHooks.get(hookName);
      if (cb === undefined) {
        continue;
      }
      try {
        await cb(ctx);
      } catch (e) {
        console.error(LOG_TAG, `storage-ready hook ${hookName} failed: ${toError(e as Object).message}`);
      }
    }
  }

  static init(ctx: common.Context): void {
    SyncScheduler.ctx = ctx;
    SyncScheduler.bundleName = ctx.applicationInfo.name;
    const paths: FilePathProvider = new FilePathProvider(ctx.cacheDir, ctx.filesDir);
    SyncScheduler.filePaths = paths;
    RssLocalSync.configure(paths);
    setFullTextSyncRequester((triggeredByUser: boolean) => {
      SyncScheduler.runOnceFullTextSync(triggeredByUser);
    });
    setSyncScheduleHook((replace: boolean): Promise<void> => SyncScheduler.schedulePeriodicRssSync(replace));
    setBlocklistChangedHook((): Promise<void> => SyncScheduler.runOnceBlocklistUpdate());
  }

  static filePathProvider(): FilePathProvider | null {
    return SyncScheduler.filePaths;
  }

  // ------------------------------------------------------------ WorkScheduler 基础

  private static baseWork(workId: number): workScheduler.WorkInfo | null {
    if (SyncScheduler.bundleName.length === 0) {
      console.error(LOG_TAG, 'WorkScheduler not available: SyncScheduler.init not called');
      return null;
    }
    const info: workScheduler.WorkInfo = {
      workId: workId,
      bundleName: SyncScheduler.bundleName,
      abilityName: WORK_SCHEDULER_ABILITY_NAME
    };
    return info;
  }

  private static async workExists(workId: number): Promise<boolean> {
    try {
      await workScheduler.getWorkStatus(workId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * 按 id 取消。stopWork 会先校验 WorkInfo：只有 workId/bundleName/abilityName 而无任何条件时直接报
   * "Set none conditions, so fail to init WorkInfo"（实测），任务根本不会被取消，随后同 id startWork 一律
   * 9700005 "already added"——频率/仅 Wi-Fi/仅充电/手动 的修改全部不生效。故优先用 getWorkStatus 取回已登记的
   * WorkInfo（带条件）去停止；取不到则补一个最小条件再停。
   */
  private static async stopWork(workId: number): Promise<void> {
    let info: workScheduler.WorkInfo | null = null;
    try {
      info = await workScheduler.getWorkStatus(workId);
    } catch (e) {
      // 不存在的任务
      return;
    }
    if (info === null || info === undefined) {
      return;
    }
    if (info.networkType === undefined && info.isCharging === undefined && info.batteryLevel === undefined &&
      info.batteryStatus === undefined && info.storageRequest === undefined && info.isDeepIdle === undefined &&
      info.idleWaitTime === undefined && info.repeatCycleTime === undefined) {
      info.networkType = workScheduler.NetworkType.NETWORK_TYPE_ANY;
    }
    try {
      workScheduler.stopWork(info, true);
      console.info(LOG_TAG, `stopWork(${workId})`);
    } catch (e) {
      console.warn(LOG_TAG, `stopWork(${workId}) failed: ${JSON.stringify(e)} ${(e as Error)?.message}`);
    }
  }

  /** 同 id 替换（≙ JobScheduler.schedule 同 jobId 替换） */
  private static async replaceWork(info: workScheduler.WorkInfo): Promise<void> {
    await SyncScheduler.stopWork(info.workId);
    try {
      workScheduler.startWork(info);
      console.info(LOG_TAG, `startWork ${JSON.stringify(info)}`);
    } catch (e) {
      console.error(LOG_TAG, `startWork(${info.workId}) failed: ${JSON.stringify(e)} ${(e as Error)?.message} ${JSON.stringify(info)}`);
    }
  }

  private static networkType(requireUnmetered: boolean): workScheduler.NetworkType {
    return requireUnmetered ? workScheduler.NetworkType.NETWORK_TYPE_WIFI : workScheduler.NetworkType.NETWORK_TYPE_ANY;
  }

  private static constraintsMet(requireCharging: boolean, requireUnmetered: boolean): boolean {
    return currentlyConnected() && (!requireCharging || currentlyCharging()) &&
      (!requireUnmetered || currentlyUnmetered());
  }

  // ------------------------------------------------------------ 周期任务

  /** 源 schedulePeriodicRssSync(di, replace)（FS-A47/A48） */
  static async schedulePeriodicRssSync(replace: boolean): Promise<void> {
    const s: SettingsStore = SettingsStore.instance();
    const minutes: number = s.syncFrequency as number;
    if (minutes < 1) {
      // Cancel and return
      await SyncScheduler.stopWork(BackgroundJobId.RSS_SYNC_PERIODIC);
      return;
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.RSS_SYNC_PERIODIC);
    if (info === null) {
      return;
    }
    info.isRepeat = true;
    info.repeatCycleTime = Math.max(minutes * 60 * 1000, MIN_REPEAT_CYCLE_MS);
    info.networkType = SyncScheduler.networkType(s.syncOnlyOnWifi);
    if (s.syncOnlyWhenCharging) {
      info.isCharging = true;
      info.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY;
    }
    info.isPersisted = true;
    if (replace || !(await SyncScheduler.workExists(BackgroundJobId.RSS_SYNC_PERIODIC))) {
      await SyncScheduler.replaceWork(info);
    }
  }

  /** 源 MainActivity.onCreate → ensurePeriodicSyncConfigured（replace=false） */
  static ensurePeriodicSyncConfigured(): Promise<void> {
    return SyncScheduler.schedulePeriodicRssSync(false);
  }

  /** 源 schedulePeriodicOrphanedFilesCleanup：不存在才建（FS-A55） */
  static async schedulePeriodicOrphanedFilesCleanup(): Promise<void> {
    if (await SyncScheduler.workExists(BackgroundJobId.CLEANUP_ORPHANED_FILES)) {
      return;
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.CLEANUP_ORPHANED_FILES);
    if (info === null) {
      return;
    }
    info.isDeepIdle = true;
    info.isCharging = true;
    info.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY;
    info.isRepeat = true;
    info.repeatCycleTime = DAY_MS;
    info.isPersisted = true;
    try {
      workScheduler.startWork(info);
      console.info(LOG_TAG, `Scheduled daily cleanup of orphaned files ${JSON.stringify(info)}`);
    } catch (e) {
      console.error(LOG_TAG, `schedule cleanup failed: ${JSON.stringify(e)}`);
    }
  }

  static async cleanupOrphanedFilesNow(): Promise<void> {
    const paths: FilePathProvider | null = SyncScheduler.filePaths;
    if (paths !== null) {
      await cleanupOrphanedFiles(paths);
    }
  }

  // ------------------------------------------------------------ RSS 同步

  /**
   * 源 runOnceRssSync(di, feedId, feedTag, forceNetwork, triggeredByUser)（FS-A49）：
   * 非强制且"仅 Wi-Fi"时要求非计费网络，否则任意网络。约束满足 → 立即在进程内同步（Promise 在同步结束后兑现 true/false）；
   * 否则登记一次性后台任务并返回 false。
   */
  static async runOnceRssSync(feedId: number = ID_UNSET, feedTag: string = '', forceNetwork: boolean = false,
    triggeredByUser: boolean = false): Promise<boolean> {
    const requireUnmetered: boolean = !forceNetwork && SettingsStore.instance().syncOnlyOnWifi;
    if (SyncScheduler.constraintsMet(false, requireUnmetered)) {
      return SyncScheduler.runRssSyncNow(feedId, feedTag, forceNetwork, triggeredByUser);
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.RSS_SYNC);
    if (info !== null) {
      info.networkType = SyncScheduler.networkType(requireUnmetered);
      const params: Record<string, number | string | boolean> = {
        'feed_id': feedId,
        'feed_tag': feedTag,
        'force_network': forceNetwork
      };
      info.parameters = params;
      await SyncScheduler.replaceWork(info);
    }
    return false;
  }

  /** 设计签名 syncNow(feedId?, tag?, forceNetwork)：用户触发的一次性同步（下拉刷新/菜单） */
  static syncNow(feedId: number = ID_UNSET, tag: string = '', forceNetwork: boolean = true,
    triggeredByUser: boolean = true): Promise<boolean> {
    return SyncScheduler.runOnceRssSync(feedId, tag, forceNetwork, triggeredByUser);
  }

  /** 源 RssSyncJob.doWork：同步后（finally）发送新条目通知 */
  private static async runRssSyncNow(feedId: number, feedTag: string, forceNetwork: boolean,
    triggeredByUser: boolean): Promise<boolean> {
    let notificationShown: boolean = false;
    let delayId: number = -1;
    if (triggeredByUser) {
      notificationShown = await SyncScheduler.showSyncNotification();
      delayId = SyncScheduler.requestSuspendDelay();
    }
    try {
      return await RssLocalSync.instance().syncFeeds(feedId, feedTag, forceNetwork, 5);
    } catch (e) {
      console.error(LOG_TAG, `Failure during sync: ${toError(e as Object).message}`);
      return false;
    } finally {
      await notifyNewItems();
      if (delayId !== -1) {
        try {
          backgroundTaskManager.cancelSuspendDelay(delayId);
        } catch (e) {
          console.warn(LOG_TAG, `cancelSuspendDelay failed: ${JSON.stringify(e)}`);
        }
      }
      if (notificationShown) {
        notificationManager.cancel(SYNC_NOTIFICATION_ID).catch((e: Error) => {
          console.warn(LOG_TAG, `cancel sync notification failed: ${e?.message}`);
        });
      }
    }
  }

  /** 短时任务：用户触发的同步在退到后台后尽量完成 */
  private static requestSuspendDelay(): number {
    try {
      let id: number = -1;
      const info: backgroundTaskManager.DelaySuspendInfo = backgroundTaskManager.requestSuspendDelay('feed sync', () => {
        if (id !== -1) {
          backgroundTaskManager.cancelSuspendDelay(id);
          id = -1;
        }
      });
      id = info.requestId;
      return id;
    } catch (e) {
      console.warn(LOG_TAG, `requestSuspendDelay failed: ${JSON.stringify(e)}`);
      return -1;
    }
  }

  /** 源 background/Notifications.kt getNotificationForSync：常驻、低优先级、标题 "Syncing" */
  private static async showSyncNotification(): Promise<boolean> {
    const ctx: common.Context | null = SyncScheduler.ctx;
    if (ctx === null) {
      return false;
    }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.OTHER_TYPES);
      const titleText: string = ctx.resourceManager.getStringByNameSync('syncing');
      const statusText: string = ctx.resourceManager.getStringByNameSync('sync_status');
      const request: notificationManager.NotificationRequest = {
        id: SYNC_NOTIFICATION_ID,
        notificationSlotType: notificationManager.SlotType.OTHER_TYPES,
        isOngoing: true,
        groupName: SYNC_NOTIFICATION_GROUP,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: titleText,
            text: statusText
          }
        }
      };
      await notificationManager.publish(request);
      return true;
    } catch (e) {
      console.warn(LOG_TAG, `sync notification not shown: ${JSON.stringify(e)}`);
      return false;
    }
  }

  // ------------------------------------------------------------ 全文

  /** 源 runOnceFullTextSync(di, triggeredByUser)（FS-A56）：非用户触发时受充电/Wi-Fi 设置约束 */
  static runOnceFullTextSync(triggeredByUser: boolean): void {
    const s: SettingsStore = SettingsStore.instance();
    if (triggeredByUser || SyncScheduler.constraintsMet(s.syncOnlyWhenCharging, s.syncOnlyOnWifi)) {
      SyncScheduler.runFullTextNow().catch((e: Error) => {
        console.error(LOG_TAG, `Full text sync failed: ${e?.message}`);
      });
      return;
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.FULL_TEXT_SYNC);
    if (info === null) {
      return;
    }
    info.networkType = SyncScheduler.networkType(s.syncOnlyOnWifi);
    if (s.syncOnlyWhenCharging) {
      info.isCharging = true;
      info.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY;
    }
    SyncScheduler.replaceWork(info).catch((e: Error) => {
      console.error(LOG_TAG, `replaceWork failed: ${e?.message}`);
    });
  }

  private static runFullTextNow(): Promise<boolean> {
    return SyncScheduler.fullTextMutex.withLock<boolean>(async (): Promise<boolean> => {
      const paths: FilePathProvider | null = SyncScheduler.filePaths;
      if (paths === null) {
        console.error(LOG_TAG, 'Full text sync before init');
        return false;
      }
      console.info(LOG_TAG, 'Performing full text parse work');
      const r: boolean = await FullTextParser.instance(paths).parseFullArticlesForMissing();
      console.info(LOG_TAG, 'Finished full text parse work');
      return r;
    });
  }

  // ------------------------------------------------------------ 同步链

  /** 源 runOnceSyncChainSendRead（FS-A53）：未配置不调度；≥10 秒后执行以合并；已有待执行任务不重复 */
  static runOnceSyncChainSendRead(): void {
    if (!isSyncChainConfigured()) {
      return;
    }
    if (SyncScheduler.sendReadTimer !== -1) {
      return;
    }
    SyncScheduler.sendReadTimer = setTimeout(() => {
      SyncScheduler.sendReadTimer = -1;
      SyncScheduler.sendReadWhenAllowed().catch((e: Error) => {
        console.error(LOG_TAG, `send read failed: ${e?.message}`);
      });
    }, SEND_READ_MIN_LATENCY_MS);
  }

  private static async sendReadWhenAllowed(): Promise<void> {
    const s: SettingsStore = SettingsStore.instance();
    const client: SyncChainClient | null = getSyncChainClient();
    if (client === null) {
      return;
    }
    if (SyncScheduler.constraintsMet(s.syncOnlyWhenCharging, s.syncOnlyOnWifi)) {
      try {
        await client.markAsRead();
      } catch (e) {
        console.error(LOG_TAG, `Error when sending read marks: ${toError(e as Object).message}`);
      }
      return;
    }
    if (await SyncScheduler.workExists(BackgroundJobId.SYNC_CHAIN_SEND_READ)) {
      return;
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.SYNC_CHAIN_SEND_READ);
    if (info !== null) {
      info.networkType = SyncScheduler.networkType(s.syncOnlyOnWifi);
      if (s.syncOnlyWhenCharging) {
        info.isCharging = true;
        info.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY;
      }
      await SyncScheduler.replaceWork(info);
    }
  }

  /** 源 runOnceSyncChainGetUpdates：getRead → applyRemoteReadMarks → getDevices */
  static runOnceSyncChainGetUpdates(): void {
    if (!isSyncChainConfigured()) {
      console.debug(LOG_TAG, 'Sync chain not enabled');
      return;
    }
    const s: SettingsStore = SettingsStore.instance();
    if (SyncScheduler.constraintsMet(s.syncOnlyWhenCharging, s.syncOnlyOnWifi)) {
      SyncScheduler.getUpdatesNow().catch((e: Error) => {
        console.error(LOG_TAG, `get updates failed: ${e?.message}`);
      });
      return;
    }
    const info: workScheduler.WorkInfo | null = SyncScheduler.baseWork(BackgroundJobId.SYNC_CHAIN_GET_UPDATES);
    if (info !== null) {
      info.networkType = SyncScheduler.networkType(s.syncOnlyOnWifi);
      if (s.syncOnlyWhenCharging) {
        info.isCharging = true;
        info.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY;
      }
      SyncScheduler.replaceWork(info).catch((e: Error) => {
        console.error(LOG_TAG, `replaceWork failed: ${e?.message}`);
      });
    }
  }

  private static async getUpdatesNow(): Promise<void> {
    const client: SyncChainClient | null = getSyncChainClient();
    if (client === null) {
      return;
    }
    try {
      await client.getRead();
      await applyRemoteReadMarks();
      await client.getDevices();
    } catch (e) {
      console.error(LOG_TAG, `Error when getting updates: ${toError(e as Object).message}`);
    }
  }

  // ------------------------------------------------------------ 屏蔽词

  /** 源 BlocklistUpdateJob（FS-A54）：feedId → 该源新条目；onlyNew → 屏蔽状态为空者；否则全量重算 */
  static async runOnceBlocklistUpdate(feedId: number = ID_UNSET, onlyNew: boolean = false): Promise<void> {
    const s: SettingsStore = SettingsStore.instance();
    const now: number = Date.now();
    try {
      if (feedId !== ID_UNSET) {
        await BlocklistDao.setItemBlockStatusForNewInFeed(feedId, now, s.applyBlocklistToSummaries,
          s.applyBlocklistToLinks);
      } else if (onlyNew) {
        await BlocklistDao.setItemBlockStatusWhereNull(now, s.applyBlocklistToSummaries, s.applyBlocklistToLinks);
      } else {
        await BlocklistDao.setItemBlockStatus(now, s.applyBlocklistToSummaries, s.applyBlocklistToLinks);
      }
    } catch (e) {
      console.error(LOG_TAG, `Blocklist update failed: ${toError(e as Object).message}`);
    }
  }

  // ------------------------------------------------------------ 前台恢复

  /** 源 MainActivity.maybeRequestSync（FS-A52）：syncOnResume 且联网/充电/非计费约束满足 */
  static maybeRequestSyncOnResume(): void {
    if (SettingsStore.instance().syncOnResume && isOkToSyncAutomatically()) {
      SyncScheduler.runOnceSyncChainGetUpdates();
      SyncScheduler.runOnceRssSync(ID_UNSET, '', false, false).catch((e: Error) => {
        console.error(LOG_TAG, `resume sync failed: ${e?.message}`);
      });
    }
  }

  // ------------------------------------------------------------ 扩展进程执行

  /** 扩展进程无 AppBootstrap：自行初始化存储层 */
  static async bootstrapHeadless(ctx: common.Context): Promise<void> {
    await SettingsStore.init(ctx);
    await AppDatabase.init(ctx);
    HttpClient.init(new FilePathProvider(ctx.cacheDir, ctx.filesDir));
    SyncScheduler.init(ctx);
    // 同步链客户端等进程级安装项（扩展壳模块加载时已注册；≙ 源 DI 单例在 Job 进程同样可用）
    await SyncScheduler.runStorageReadyHooks(ctx);
  }

  /** FeederJobService.onStartJob 的分派 */
  static async runWork(ctx: common.Context, work: workScheduler.WorkInfo): Promise<void> {
    await SyncScheduler.bootstrapHeadless(ctx);
    switch (work.workId) {
      case BackgroundJobId.RSS_SYNC_PERIODIC:
        await SyncScheduler.runRssSyncNow(ID_UNSET, '', false, false);
        break;
      case BackgroundJobId.RSS_SYNC:
        await SyncScheduler.runRssSyncNow(readNumberParam(work, ARG_FEED_ID, ID_UNSET),
          readStringParam(work, ARG_FEED_TAG, ''), readBoolParam(work, ARG_FORCE_NETWORK, false), false);
        break;
      case BackgroundJobId.FULL_TEXT_SYNC:
        await SyncScheduler.runFullTextNow();
        break;
      case BackgroundJobId.SYNC_CHAIN_GET_UPDATES:
        await SyncScheduler.getUpdatesNow();
        break;
      case BackgroundJobId.SYNC_CHAIN_SEND_READ: {
        const client: SyncChainClient | null = getSyncChainClient();
        if (client !== null) {
          await client.markAsRead();
        }
        break;
      }
      case BackgroundJobId.BLOCKLIST_UPDATE:
        await SyncScheduler.runOnceBlocklistUpdate(readNumberParam(work, ARG_FEED_ID, ID_UNSET),
          readBoolParam(work, ARG_ONLY_NEW, false));
        break;
      case BackgroundJobId.CLEANUP_ORPHANED_FILES:
        await SyncScheduler.cleanupOrphanedFilesNow();
        break;
      default:
        console.error(LOG_TAG, `Unknown work id ${work.workId}`);
    }
  }
}

/** WorkScheduler 扩展能力（≙ 源 FeederJobService） */
export default class FeederWorkSchedulerAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    console.info(LOG_TAG, `onWorkStart ${work.workId}`);
    SyncScheduler.runWork(this.context, work).catch((e: Error) => {
      console.error(LOG_TAG, `work ${work.workId} failed: ${e?.message}`);
    });
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    // 源 onStopJob：取消且不重排；进程内协程无法强制取消，记录即可
    console.info(LOG_TAG, `onWorkStop ${work.workId}`);
  }
}
