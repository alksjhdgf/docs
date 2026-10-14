/**
 * NotificationActions.ets —— 源 model/RssNotificationBroadcastReceiver.kt + 小组件 router 事件的鸿蒙接线。
 * （通知代理 ≙ OpenLinkInDefaultActivity 的唯一实现在 pages/OpenLinkInDefaultPage.ets，NW-A11/A14，本文件不再重复。）
 *
 * - install(ctx)：EntryAbility.onCreate 调用（见 blocked）：注册新条目通知钩子（NW-A01/A15）、订阅通知后台动作
 *   公共事件、声明本进程为小组件源设置权威（扩展进程经镜像读取，NW-A16/A24）、AppBootstrap 就绪后启动小组件推送（NW-A24）。
 * - 公共事件（≙ BroadcastReceiver，进程内快路径；进程不在时：Mark as read 走 NotificationActionAbility，
 *   划掉走 PostedNotifications 对账，NW-A12/A13）：
 *   · mark_as_notified（划掉单条/汇总）：ids 非空 → FeedItemDao.markAsNotified(ids) + 取消这些通知；
 *   · mark_as_read（"Mark as read" 按钮）：FeedItemDao.markAsReadAndNotified(id)（read_time 保留已有、notified=1）+ 取消；
 *     照源直接写 DAO，不经 Repository → 不触发同步链已读上报。
 * - onWant(want)（EntryAbility.onCreate/onNewWant 在交 DeepLinkRouter 之前调用）：卡片 router 事件 →
 *   open_article：改写为文章深链（Article 页进入即标已读+已通知，NW-A20）；settings：打开 FeedWidgetSettings（NW-A23）；
 *   open_app：照常启动主界面。
 */
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import { AppRouter, NoParam, Routes } from '../../common/Router';
import { AppBootstrap, AppScope } from '../../core/app/AppBootstrap';
import {
  ACTION_VIEW_DATA, DeepLinkRouter, ParsedUri, articleDeepLink, parseLongOrNull, parseUri
} from '../../core/app/DeepLinkRouter';
import { FeedItemDao } from '../../core/db/FeedItemDao';
import { ID_UNSET } from '../../core/model/Enums';
import {
  ACTION_MARK_AS_NOTIFIED, ACTION_MARK_AS_READ, EXTRA_FEEDITEM_ID, EXTRA_FEEDITEM_ID_ARRAY, RssNotifications,
  notificationEventName
} from './RssNotifications';
import {
  FeedWidgetUpdater, WIDGET_ACTION_OPEN_APP, WIDGET_ACTION_OPEN_ARTICLE, WIDGET_ACTION_SETTINGS, WIDGET_PARAM_ACTION,
  WIDGET_PARAM_ITEM_ID
} from '../widget/FeedFormAbility';

const LOG_TAG: string = 'FEEDER_NOTIFY_ACTIONS';
/** 冷启等待 Main 接管导航的上限 */
const MAIN_WAIT_LIMIT_MS: number = 10000;
const MAIN_WAIT_STEP_MS: number = 50;

const sleep = (ms: number): Promise<void> => new Promise<void>((resolve) => {
  setTimeout(() => {
    resolve();
  }, ms);
});

/** 源 RssNotificationBroadcastReceiver 读取的条目 id 数组（缺失 → 空） */
export function readIdArrayParam(params: Record<string, Object> | undefined, key: string): number[] {
  if (params === undefined) {
    return [];
  }
  const v: Object | undefined = params[key];
  if (v === undefined || v === null || !Array.isArray(v)) {
    return [];
  }
  const out: number[] = [];
  for (const x of v as Object[]) {
    const n: number = Number(x);
    if (Number.isSafeInteger(n)) {
      out.push(n);
    }
  }
  return out;
}

/** 源 intent.data.lastPathSegment.toLong()（失败 → 0）；优先显式参数 */
export function readItemIdParam(params: Record<string, Object> | undefined, uri: string): number {
  if (params !== undefined) {
    const v: Object | undefined = params[EXTRA_FEEDITEM_ID];
    if (v !== undefined && v !== null) {
      const n: number = Number(v);
      if (Number.isSafeInteger(n)) {
        return n;
      }
    }
  }
  const u: ParsedUri | null = uri.length > 0 ? parseUri(uri) : null;
  if (u === null || u.segments.length === 0) {
    return ID_UNSET;
  }
  const id: number | null = parseLongOrNull(u.segments[u.segments.length - 1]);
  return id !== null ? id : ID_UNSET;
}

/** 卡片 router 事件参数：系统把 params 以 JSON 串放在 want.parameters.params；也兼容直接平铺 */
export function widgetWantParam(want: Want, key: string): Object | undefined {
  const params: Record<string, Object> | undefined = want.parameters;
  if (params === undefined) {
    return undefined;
  }
  const direct: Object | undefined = params[key];
  if (direct !== undefined) {
    return direct;
  }
  const nested: Object | undefined = params['params'];
  if (typeof nested === 'string') {
    try {
      const obj: Record<string, Object> = JSON.parse(nested as string) as Record<string, Object>;
      return obj[key];
    } catch (e) {
      return undefined;
    }
  }
  if (nested !== undefined && nested !== null && typeof nested === 'object') {
    return (nested as Record<string, Object>)[key];
  }
  return undefined;
}

export class NotificationActions {
  private static subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private static installed: boolean = false;

  /** EntryAbility.onCreate：通知钩子 + 后台动作订阅 + 小组件推送；幂等 */
  static install(ctx: common.UIAbilityContext): void {
    RssNotifications.init(ctx);
    FeedWidgetUpdater.setContext(ctx);
    FeedWidgetUpdater.becomeSettingsAuthority();
    if (NotificationActions.installed) {
      return;
    }
    NotificationActions.installed = true;
    NotificationActions.subscribe(ctx.applicationInfo.name).catch((e: Error) => {
      console.error(`${LOG_TAG}: subscribe failed: ${e?.message}`);
    });
    AppBootstrap.ready().then(() => {
      FeedWidgetUpdater.start(ctx);
      // NW-A13：上次进程不在时被划掉的通知补记 notified=1
      RssNotifications.reconcileDismissed();
    });
  }

  /** 进程收尾（测试用）：对称清理 */
  static uninstall(): void {
    const s: commonEventManager.CommonEventSubscriber | null = NotificationActions.subscriber;
    NotificationActions.subscriber = null;
    NotificationActions.installed = false;
    if (s !== null) {
      try {
        commonEventManager.unsubscribe(s);
      } catch (e) {
        console.warn(`${LOG_TAG}: unsubscribe failed: ${JSON.stringify(e)}`);
      }
    }
    FeedWidgetUpdater.stop();
  }

  private static async subscribe(bundleName: string): Promise<void> {
    const info: commonEventManager.CommonEventSubscribeInfo = {
      events: [notificationEventName(bundleName, ACTION_MARK_AS_NOTIFIED),
        notificationEventName(bundleName, ACTION_MARK_AS_READ)],
      publisherBundleName: bundleName
    };
    const sub: commonEventManager.CommonEventSubscriber = await commonEventManager.createSubscriber(info);
    NotificationActions.subscriber = sub;
    commonEventManager.subscribe(sub, (err: BusinessError, data: commonEventManager.CommonEventData) => {
      if (err !== null && err !== undefined && err.code !== 0) {
        console.error(`${LOG_TAG}: event error ${err.code}`);
        return;
      }
      const params: Record<string, Object> | undefined = data.parameters as Record<string, Object> | undefined;
      const event: string = data.event;
      let action: string = '';
      if (event === notificationEventName(bundleName, ACTION_MARK_AS_NOTIFIED)) {
        action = ACTION_MARK_AS_NOTIFIED;
      } else if (event === notificationEventName(bundleName, ACTION_MARK_AS_READ)) {
        action = ACTION_MARK_AS_READ;
      }
      const uri: string = params !== undefined && typeof params['uri'] === 'string' ? params['uri'] as string : '';
      AppScope.launch(`notification ${action}`, (): Promise<void> => NotificationActions.onReceive(action, params, uri));
    });
  }

  /** 源 RssNotificationBroadcastReceiver.onReceive */
  static async onReceive(action: string, params: Record<string, Object> | undefined, uri: string): Promise<void> {
    if (AppBootstrap.context() !== null) {
      await AppBootstrap.ready();
    }
    if (action === ACTION_MARK_AS_NOTIFIED) {
      const ids: number[] = readIdArrayParam(params, EXTRA_FEEDITEM_ID_ARRAY);
      if (ids.length > 0) {
        await FeedItemDao.markAsNotified(ids);
        await RssNotifications.cancelNotifications(ids);
      }
    } else if (action === ACTION_MARK_AS_READ) {
      const id: number = readItemIdParam(params, uri);
      await FeedItemDao.markAsReadAndNotified(id);
      await RssNotifications.cancelNotification(id);
    }
  }

  // ------------------------------------------------------------ 小组件 router 事件

  /** 交 DeepLinkRouter 之前调用：改写/消费小组件事件；返回是否为小组件事件 */
  static onWant(want: Want): boolean {
    const a: Object | undefined = widgetWantParam(want, WIDGET_PARAM_ACTION);
    if (typeof a !== 'string') {
      return false;
    }
    const action: string = a as string;
    if (action === WIDGET_ACTION_OPEN_ARTICLE) {
      const n: number = Number(widgetWantParam(want, WIDGET_PARAM_ITEM_ID));
      if (Number.isSafeInteger(n)) {
        want.uri = articleDeepLink(n);
        want.action = ACTION_VIEW_DATA;
      }
    } else if (action === WIDGET_ACTION_SETTINGS) {
      NotificationActions.openWidgetSettings().catch((e: Error) => {
        console.error(`${LOG_TAG}: open widget settings failed: ${e?.message}`);
      });
    } else if (action !== WIDGET_ACTION_OPEN_APP) {
      console.warn(`${LOG_TAG}: unknown widget action ${action}`);
    }
    return true;
  }

  /** 源 FeedWidget 齿轮 → FeedWidgetSettingsActivity（冷启：等 Main 接管导航后压栈） */
  static async openWidgetSettings(): Promise<void> {
    await AppBootstrap.ready();
    let waited: number = 0;
    while (!DeepLinkRouter.isMainLaunched() && waited < MAIN_WAIT_LIMIT_MS) {
      await sleep(MAIN_WAIT_STEP_MS);
      waited += MAIN_WAIT_STEP_MS;
    }
    await sleep(0);
    const names: string[] = AppRouter.stack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === Routes.FEED_WIDGET_SETTINGS) {
      return;
    }
    AppRouter.push(Routes.FEED_WIDGET_SETTINGS, new NoParam());
  }
}
