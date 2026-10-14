/**
 * RssNotifications.ets —— 源 model/RssNotifications.kt（新条目通知：渠道、单条通知、汇总通知、各 Intent 构造、取消）。
 *
 * - notify(updateSummaryOnly)（NW-A02..A10）：无通知权限 → 直接返回；建 slot（≙ createNotificationChannel，幂等）；
 *   待通知条目 = notify=1 的源 ∩ notified=0 ∩ 未读 ∩ 未屏蔽，倒序 ≤20（无 notify 源 → 空）；为空什么都不做；
 *   非 updateSummaryOnly 时每条一条单独通知（id = 条目 id 转 int32），总是再发汇总通知（id 2147483646）。
 *   发布本身不置 notified（同 id 覆盖重发，单条静默）。
 * - 单条通知（NW-A07/A09/A10）：标题 plainTitle、正文源名；点按自动消失；点击目标按打开方式（源级覆盖全局）：
 *   链接为空或阅读器 → 文章深链；Custom Tab / 默认浏览器 → 经通知代理（OpenLinkInDefault 路由）打开链接；
 *   动作按钮顺序：附件 → "Open enclosed media"；非默认浏览器且有链接 → "Open link in web browser"；总是 "Mark as read"。
 * - 汇总通知（NW-A08/A14）：标题 "Updated feeds"，正文去重源名 ", " 连接，多行 "<源名> — <标题>"，角标=条目数；
 *   点击 → 代理标 notified 后打开 Feed 深链（id/tag 推导见 summaryDeepLinkTarget）。
 * - 划掉（removalWantAgent）→ 公共事件，由 NotificationActions 处理；进程不在时由 PostedNotifications 对账补偿（NW-A13）。
 * - "Mark as read" → START_ABILITY 拉起 NotificationActionAbility（进程无关，NW-A12）。
 * - 同步任务 finally 调用 notify（NW-A01）：经 SyncScheduler.setNewItemsNotifier 注册（NotificationActions.install /
 *   本文件 default export 的 WorkScheduler 扩展包装）。
 */
import { notificationManager } from '@kit.NotificationKit';
import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { FeedDao } from '../../core/db/FeedDao';
import { FeedItemDao } from '../../core/db/FeedItemDao';
import { FeedItemWithFeed } from '../../core/model/FeedItem';
import { ID_ALL_FEEDS, ID_UNSET, ItemOpener } from '../../core/model/Enums';
import { Repository } from '../../core/repo/Repository';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { setNewItemsNotifier, SyncScheduler } from '../../core/sync/SyncScheduler';
import {
  ACTION_OPEN_IN_CUSTOM_TAB, ACTION_VIEW_DATA, EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED, articleDeepLink, feedDeepLink,
  feedItemNotificationUri
} from '../../core/app/DeepLinkRouter';
import {
  SUMMARY_NOTIFICATION_ID, cancelNotifications as cancelNotificationIds, notificationIdOf,
  setSummaryNotificationUpdater
} from '../main/NotificationsWorker';
import { FeedWidgetUpdater } from '../widget/FeedFormAbility';
import { PostedNotifications } from './PostedNotifications';

export { SUMMARY_NOTIFICATION_ID, notificationIdOf } from '../main/NotificationsWorker';

const LOG_TAG: string = 'FEEDER_NOTIFY';

/** 源 CHANNEL_ID（鸿蒙 slot 不可命名，仅作标识/日志） */
export const CHANNEL_ID: string = 'feederNotifications';
export const ARTICLE_NOTIFICATION_GROUP: string = 'com.nononsenseapps.feeder.ARTICLE';
/** 源 RssNotificationBroadcastReceiver 动作 */
export const ACTION_MARK_AS_NOTIFIED: string = 'mark_as_notified';
export const ACTION_MARK_AS_READ: string = 'mark_as_read';
export const EXTRA_FEEDITEM_ID_ARRAY: string = 'extra_feeditem_id_array';
/** 公共事件参数：单条条目 id（源 intent.data.lastPathSegment） */
export const EXTRA_FEEDITEM_ID: string = 'extra_feeditem_id';
/** 源 IMPORTANCE_LOW：状态栏显示、无横幅、无提示音 */
export const NOTIFICATION_SLOT: notificationManager.SlotType = notificationManager.SlotType.CONTENT_INFORMATION;
/** 源 "If too many it can cause a crash, so it's limited to 20"（DAO 已 LIMIT 20） */
export const MAX_NOTIFIED_ITEMS: number = 20;
export const ENTRY_ABILITY_NAME: string = 'EntryAbility';
/** "Mark as read" 按钮的进程无关入口（NW-A12，见 notificationactionability/NotificationActionAbility.ets） */
export const NOTIFICATION_ACTION_ABILITY_NAME: string = 'NotificationActionAbility';

/** 公共事件名：应用私有前缀 + 源动作名 */
export function notificationEventName(bundleName: string, action: string): string {
  return `${bundleName}.${action}`;
}

// ============================================================ 纯逻辑（便于单测）

/** 汇总通知深链目标（源 inboxNotification：deepLinkId / deepLinkTag） */
export class SummaryDeepLink {
  feedId: number = ID_UNSET;
  tag: string = '';
}

/**
 * NW-A14：所有条目 tag 相同 → 该 tag，否则 ""；所有条目同源 → 该 feedId（null → ID_UNSET）；
 * 否则 tag 非空 → ID_ALL_FEEDS（tag 优先），再否则 ID_UNSET（默认上次打开）。
 */
export function summaryDeepLinkTarget(items: FeedItemWithFeed[]): SummaryDeepLink {
  const tags: Set<string> = new Set<string>(items.map((it: FeedItemWithFeed): string => it.tag));
  const r: SummaryDeepLink = new SummaryDeepLink();
  r.tag = tags.size === 1 ? Array.from(tags)[0] : '';
  const feedIds: Set<number | null> = new Set<number | null>(items.map((it: FeedItemWithFeed): number | null => it.feedId));
  if (feedIds.size === 1) {
    const only: number | null = Array.from(feedIds)[0];
    r.feedId = only !== null ? only : ID_UNSET;
  } else {
    r.feedId = r.tag.length > 0 ? ID_ALL_FEEDS : ID_UNSET;
  }
  return r;
}

/** NW-A08：去重源名（保持首次出现顺序）以 ", " 连接 */
export function summaryText(items: FeedItemWithFeed[]): string {
  const names: string[] = [];
  for (const it of items) {
    const n: string = it.feedDisplayTitle;
    if (names.indexOf(n) < 0) {
      names.push(n);
    }
  }
  return names.join(', ');
}

/** NW-A08：InboxStyle 每条一行 "<源名> — <标题>"（U+2014） */
export function summaryLines(items: FeedItemWithFeed[]): string[] {
  return items.map((it: FeedItemWithFeed): string => `${it.feedDisplayTitle} — ${it.plainTitle}`);
}

/** 单条通知点击目标（源 contentIntent） */
export class ItemClickTarget {
  uri: string = '';
  action: string = ACTION_VIEW_DATA;
}

/** NW-A10：link 为空或 READER → 文章深链；CUSTOM_TAB → 代理 + OPEN_IN_CUSTOM_TAB；DEFAULT_BROWSER → 代理 + VIEW */
export function itemClickTarget(bundleName: string, itemId: number, link: string | null,
  opener: ItemOpener): ItemClickTarget {
  const t: ItemClickTarget = new ItemClickTarget();
  if (link === null || opener === ItemOpener.READER) {
    t.uri = articleDeepLink(itemId);
    t.action = ACTION_VIEW_DATA;
  } else if (opener === ItemOpener.CUSTOM_TAB) {
    t.uri = feedItemNotificationUri(bundleName, itemId, link);
    t.action = ACTION_OPEN_IN_CUSTOM_TAB;
  } else {
    t.uri = feedItemNotificationUri(bundleName, itemId, link);
    t.action = ACTION_VIEW_DATA;
  }
  return t;
}

/** 动作按钮种类（NW-A09，顺序固定） */
export enum NotificationButtonKind {
  OPEN_ENCLOSURE = 0,
  OPEN_IN_BROWSER = 1,
  MARK_AS_READ = 2,
}

export function notificationButtonKinds(enclosureLink: string | null, link: string | null,
  opener: ItemOpener): NotificationButtonKind[] {
  const out: NotificationButtonKind[] = [];
  if (enclosureLink !== null) {
    out.push(NotificationButtonKind.OPEN_ENCLOSURE);
  }
  if (opener !== ItemOpener.DEFAULT_BROWSER && link !== null) {
    out.push(NotificationButtonKind.OPEN_IN_BROWSER);
  }
  out.push(NotificationButtonKind.MARK_AS_READ);
  return out;
}

// ============================================================ 发布

export class RssNotifications {
  private static ctx: common.Context | null = null;
  private static largeIcon: image.PixelMap | null = null;
  private static smallIcon: image.PixelMap | null = null;
  private static iconsLoaded: boolean = false;

  /** 记录上下文并注册同步结束钩子（NW-A01）与"仅更新汇总"钩子（NW-A15）；幂等 */
  static init(ctx: common.Context): void {
    RssNotifications.ctx = ctx;
    PostedNotifications.setDirectory(ctx.filesDir);
    setNewItemsNotifier((): Promise<void> => RssNotifications.onSyncFinished());
    setSummaryNotificationUpdater((): Promise<void> => RssNotifications.notify(true));
  }

  static context(): common.Context | null {
    return RssNotifications.ctx;
  }

  static bundleName(): string {
    const ctx: common.Context | null = RssNotifications.ctx;
    return ctx !== null ? ctx.applicationInfo.name : '';
  }

  /** 同步任务 finally：发布新条目通知；本进程无卡片推送订阅时补推一次小组件 */
  static async onSyncFinished(): Promise<void> {
    await RssNotifications.notify(false);
    try {
      await FeedWidgetUpdater.refreshAll();
    } catch (e) {
      console.warn(`${LOG_TAG}: widget refresh after sync failed: ${JSON.stringify(e)}`);
    }
  }

  /** 源 checkSelfPermission(POST_NOTIFICATIONS)（NW-A02） */
  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      console.warn(`${LOG_TAG}: isNotificationEnabled failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /** 通知权限请求（源 Settings / EditFeed 在 API≥33 打开通知开关时请求）；返回是否已授权 */
  static async requestPermission(ctx: common.UIAbilityContext): Promise<boolean> {
    if (await RssNotifications.isEnabled()) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(ctx);
    } catch (e) {
      console.warn(`${LOG_TAG}: requestEnableNotification failed: ${JSON.stringify(e)}`);
    }
    return await RssNotifications.isEnabled();
  }

  /** 源 getItemsToNotify（NW-A03） */
  static async getItemsToNotify(): Promise<FeedItemWithFeed[]> {
    const feeds: number[] = await FeedDao.loadFeedIdsToNotify();
    if (feeds.length === 0) {
      return [];
    }
    return await FeedItemDao.loadItemsToNotify(feeds);
  }

  /** 源 notify(appContext, updateSummaryOnly) */
  static async notify(updateSummaryOnly: boolean = false): Promise<void> {
    if (!(await RssNotifications.isEnabled())) {
      return;
    }
    const ctx: common.Context | null = RssNotifications.ctx;
    if (ctx === null) {
      console.error(`${LOG_TAG}: notify before init`);
      return;
    }
    await RssNotifications.createNotificationChannel();
    // NW-A13：进程不在时被划掉的通知（公共事件无人接收）在此补记 notified=1，避免重复通知
    await RssNotifications.reconcileDismissed();
    let feedItems: FeedItemWithFeed[] = [];
    try {
      feedItems = (await RssNotifications.getItemsToNotify()).slice(0, MAX_NOTIFIED_ITEMS);
    } catch (e) {
      console.error(`${LOG_TAG}: load items to notify failed: ${JSON.stringify(e)}`);
      return;
    }
    if (feedItems.length === 0) {
      return;
    }
    await RssNotifications.loadIcons(ctx);
    // 只记录真正发布成功的通知：发布失败的条目不在活动集中，若也记入则下次对账会被误判为"划掉"而置 notified=1，
    // 违背"发布不置 notified、下次同步同 id 重发"（NW-A05）
    const publishedSingles: number[] = [];
    if (!updateSummaryOnly) {
      for (const item of feedItems) {
        try {
          await notificationManager.publish(await RssNotifications.singleNotification(ctx, item));
          publishedSingles.push(item.id);
        } catch (e) {
          console.error(`${LOG_TAG}: publish ${item.id} failed: ${JSON.stringify(e)}`);
        }
      }
    }
    let summaryPublished: boolean = false;
    try {
      await notificationManager.publish(await RssNotifications.inboxNotification(ctx, feedItems));
      summaryPublished = true;
    } catch (e) {
      console.error(`${LOG_TAG}: publish summary failed: ${JSON.stringify(e)}`);
    }
    const ids: number[] = feedItems.map((it: FeedItemWithFeed): number => it.id);
    PostedNotifications.recordPublished(publishedSingles, summaryPublished ? ids : []);
  }

  /**
   * NW-A13 进程外划掉的补偿（PostedNotifications）：已被用户移除的单条/汇总 → markAsNotified；
   * 汇总被移除时照源（RssNotificationBroadcastReceiver.markAsNotified）一并取消其中各条。
   */
  static async reconcileDismissed(): Promise<void> {
    try {
      const marked: number[] = await PostedNotifications.reconcile(SUMMARY_NOTIFICATION_ID, notificationIdOf);
      if (marked.length > 0) {
        await cancelNotificationIds(marked);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: reconcile dismissed failed: ${JSON.stringify(e)}`);
    }
  }

  static cancelNotification(feedItemId: number): Promise<void> {
    return cancelNotificationIds([feedItemId]);
  }

  /** 源 cancelNotifications：无权限直接返回；逐条 cancel(id.toInt()) */
  static cancelNotifications(feedItemIds: number[]): Promise<void> {
    return cancelNotificationIds(feedItemIds);
  }

  /** 源 createNotificationChannel（每次调用，幂等） */
  private static async createNotificationChannel(): Promise<void> {
    try {
      await notificationManager.addSlot(NOTIFICATION_SLOT);
    } catch (e) {
      console.warn(`${LOG_TAG}: addSlot failed: ${JSON.stringify(e)}`);
    }
  }

  private static str(ctx: common.Context, name: string): string {
    try {
      return ctx.resourceManager.getStringByNameSync(name);
    } catch (e) {
      return name;
    }
  }

  /** 源 notificationBuilder：小图标 ic_stat_f、大图标 ic_launcher（解码失败则不设） */
  private static async loadIcons(ctx: common.Context): Promise<void> {
    if (RssNotifications.iconsLoaded) {
      return;
    }
    RssNotifications.iconsLoaded = true;
    RssNotifications.largeIcon = await RssNotifications.decodeMedia(ctx, 'ic_launcher', 128);
    RssNotifications.smallIcon = await RssNotifications.decodeMedia(ctx, 'ic_stat_f', 48);
  }

  private static async decodeMedia(ctx: common.Context, name: string, size: number): Promise<image.PixelMap | null> {
    try {
      const bytes: Uint8Array = ctx.resourceManager.getMediaByNameSync(name);
      const buf: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      const src: image.ImageSource = image.createImageSource(buf);
      const opts: image.DecodingOptions = { desiredSize: { width: size, height: size } };
      const pm: image.PixelMap = await src.createPixelMap(opts);
      src.release();
      return pm;
    } catch (e) {
      console.warn(`${LOG_TAG}: decode ${name} failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  private static applyIcons(req: notificationManager.NotificationRequest): void {
    if (RssNotifications.largeIcon !== null) {
      req.largeIcon = RssNotifications.largeIcon;
    }
    if (RssNotifications.smallIcon !== null) {
      req.smallIcon = RssNotifications.smallIcon;
    }
  }

  private static async opener(itemId: number): Promise<ItemOpener> {
    try {
      return await Repository.instance().getArticleOpener(itemId);
    } catch (e) {
      return SettingsStore.instance().itemOpener;
    }
  }

  /** 源 singleNotification（:138-220） */
  private static async singleNotification(ctx: common.Context,
    item: FeedItemWithFeed): Promise<notificationManager.NotificationRequest> {
    const bundle: string = ctx.applicationInfo.name;
    const notifId: number = notificationIdOf(item.id);
    const opener: ItemOpener = await RssNotifications.opener(item.id);
    const target: ItemClickTarget = itemClickTarget(bundle, item.id, item.link, opener);
    const contentAgent: WantAgent = await RssNotifications.abilityAgent(bundle, target.uri, target.action,
      null, notifId);
    const deleteAgent: WantAgent = await RssNotifications.eventAgent(bundle, ACTION_MARK_AS_NOTIFIED,
      feedItemNotificationUri(bundle, item.id, null), [item.id], notifId);

    const buttons: notificationManager.NotificationActionButton[] = [];
    for (const kind of notificationButtonKinds(item.enclosureLink, item.link, opener)) {
      if (kind === NotificationButtonKind.OPEN_ENCLOSURE) {
        // Important to keep the URI different so PendingIntents don't collide
        const enclosure: string = item.enclosureLink !== null ? item.enclosureLink : '';
        buttons.push({
          title: RssNotifications.str(ctx, 'open_enclosed_media'),
          wantAgent: await RssNotifications.abilityAgent(bundle, feedItemNotificationUri(bundle, item.id, enclosure),
            ACTION_VIEW_DATA, null, notifId)
        });
      } else if (kind === NotificationButtonKind.OPEN_IN_BROWSER) {
        const link: string = item.link !== null ? item.link : '';
        buttons.push({
          title: RssNotifications.str(ctx, 'open_link_in_browser'),
          wantAgent: await RssNotifications.abilityAgent(bundle, feedItemNotificationUri(bundle, item.id, link),
            ACTION_VIEW_DATA, null, notifId)
        });
      } else {
        // NW-A12：START_ABILITY 拉起无界面的 NotificationActionAbility，进程不在也能写库（SEND_COMMON_EVENT 做不到）
        buttons.push({
          title: RssNotifications.str(ctx, 'mark_as_read'),
          wantAgent: await RssNotifications.actionAbilityAgent(bundle, ACTION_MARK_AS_READ,
            feedItemNotificationUri(bundle, item.id, null), [item.id], notifId)
        });
      }
    }

    const req: notificationManager.NotificationRequest = {
      id: notifId,
      notificationSlotType: NOTIFICATION_SLOT,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_LONG_TEXT,
        longText: {
          title: item.plainTitle,
          text: item.feedDisplayTitle,
          longText: item.feedDisplayTitle,
          briefText: item.feedDisplayTitle,
          expandedTitle: item.plainTitle
        }
      },
      groupName: ARTICLE_NOTIFICATION_GROUP,
      // setSilent(true)：同 id 覆盖重发不再提醒
      isAlertOnce: true,
      // setAutoCancel(true)
      tapDismissed: true,
      badgeNumber: 1,
      wantAgent: contentAgent,
      removalWantAgent: deleteAgent,
      actionButtons: buttons
    };
    RssNotifications.applyIcons(req);
    return req;
  }

  /** 源 inboxNotification（:282-359） */
  private static async inboxNotification(ctx: common.Context,
    feedItems: FeedItemWithFeed[]): Promise<notificationManager.NotificationRequest> {
    const bundle: string = ctx.applicationInfo.name;
    const title: string = RssNotifications.str(ctx, 'updated_feeds');
    const text: string = summaryText(feedItems);
    const target: SummaryDeepLink = summaryDeepLinkTarget(feedItems);
    const ids: number[] = feedItems.map((it: FeedItemWithFeed): number => it.id);
    const params: Record<string, Object> = {};
    params[EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED] = ids;
    const contentAgent: WantAgent = await RssNotifications.abilityAgent(bundle,
      feedDeepLink(target.feedId, target.tag), ACTION_VIEW_DATA, params, SUMMARY_NOTIFICATION_ID);
    const deleteAgent: WantAgent = await RssNotifications.eventAgent(bundle, ACTION_MARK_AS_NOTIFIED, '', ids, 0);
    const req: notificationManager.NotificationRequest = {
      id: SUMMARY_NOTIFICATION_ID,
      notificationSlotType: NOTIFICATION_SLOT,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_MULTILINE,
        multiLine: {
          title: title,
          text: text,
          briefText: text,
          longTitle: title,
          lines: summaryLines(feedItems)
        }
      },
      groupName: ARTICLE_NOTIFICATION_GROUP,
      tapDismissed: true,
      badgeNumber: feedItems.length,
      wantAgent: contentAgent,
      removalWantAgent: deleteAgent
    };
    RssNotifications.applyIcons(req);
    return req;
  }

  /** 点击/打开类：拉起 EntryAbility（≙ PendingIntent.getActivity，经 DeepLinkRouter 分派） */
  private static async abilityAgent(bundle: string, uri: string, action: string, params: Record<string, Object> | null,
    requestCode: number): Promise<WantAgent> {
    const w: Want = {
      bundleName: bundle,
      abilityName: ENTRY_ABILITY_NAME,
      uri: uri,
      action: action
    };
    if (params !== null) {
      w.parameters = params;
    }
    const info: wantAgent.WantAgentInfo = {
      wants: [w],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: requestCode,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  /** "Mark as read"：拉起 NotificationActionAbility（≙ PendingIntent.getBroadcast → 静态接收器，进程无关） */
  private static async actionAbilityAgent(bundle: string, action: string, uri: string, ids: number[],
    requestCode: number): Promise<WantAgent> {
    const params: Record<string, Object> = {};
    params[EXTRA_FEEDITEM_ID_ARRAY] = ids;
    if (ids.length === 1) {
      params[EXTRA_FEEDITEM_ID] = ids[0];
    }
    const w: Want = {
      bundleName: bundle,
      abilityName: NOTIFICATION_ACTION_ABILITY_NAME,
      action: notificationEventName(bundle, action),
      uri: uri,
      parameters: params
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [w],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: requestCode,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  /** 划掉（removalWantAgent）：应用私有公共事件（进程内快路径；进程不在时由 reconcileDismissed 补偿） */
  private static async eventAgent(bundle: string, action: string, uri: string, ids: number[],
    requestCode: number): Promise<WantAgent> {
    const params: Record<string, Object> = {};
    params[EXTRA_FEEDITEM_ID_ARRAY] = ids;
    if (ids.length === 1) {
      params[EXTRA_FEEDITEM_ID] = ids[0];
    }
    const w: Want = {
      action: notificationEventName(bundle, action),
      parameters: params
    };
    if (uri.length > 0) {
      w.uri = uri;
    }
    const info: wantAgent.WantAgentInfo = {
      wants: [w],
      actionType: wantAgent.OperationType.SEND_COMMON_EVENT,
      requestCode: requestCode,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }
}

/**
 * WorkScheduler 扩展包装（≙ 源 FeederJobService 进程内也能 notify）：后台同步进程无 AppBootstrap / UI，
 * 在此注册通知钩子与小组件同步状态订阅（同步开始即推 Refreshing，NW-A21）后再交 SyncScheduler.runWork；
 * RSS 同步作业结束后 notify（finally，NW-A01）并推送小组件。
 * 若 module.json5 的 workScheduler srcEntry 指向本文件，则后台周期同步也会发布通知（见 blocked）。
 */
export default class NotifyingWorkSchedulerAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    const ctx: common.Context = this.context;
    RssNotifications.init(ctx);
    // NW-A21：后台同步在本进程运行，订阅本进程 syncWorkerRunning → 同步期间卡片显示 Refreshing（并留跨进程标记）
    FeedWidgetUpdater.trackSyncRunning(ctx);
    SyncScheduler.runWork(ctx, work).catch((e: Error) => {
      console.error(`${LOG_TAG}: work ${work.workId} failed: ${e?.message}`);
    });
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    console.info(`${LOG_TAG}: onWorkStop ${work.workId}`);
  }
}
