/**
 * DeepLinkRouter.ets —— 源 ui/compose/navigation/NavigationDestinations.kt（路由/参数/深链/导航行为）、
 * NavigationDeepLinkViewModel.kt、MainActivity（NavHost.handleDeepLink 冷/热启）与外部入口 Activity
 * （AddFeedFromShare / ImportOPMLFile / OpenLinkInDefault）的 intent-filter 分派的鸿蒙等价物。
 *
 * - 路由参数类（FeedParam/ArticleParam/…）是页面与导航的共享契约：页面取参 `ctx.pathInfo.param as Object`
 *   后 `instanceof XxxParam` 窄化；页面切片只 import 本文件的参数类，禁止各自重定义（否则 instanceof 失配）。
 * - 深链只有三种（APP-A61）：BASE/feed?id=&tag= → Feed、BASE/article/{itemId} → Article、
 *   BASE/sync/join?sync_code=&key= → SyncScreen；BASE = https://feederapp.nononsenseapps.com。
 * - 冷启：EntryAbility.onCreate → onCreateWant(want) 解析并暂存（AppStorage 键 `feederPendingDeepLink`），
 *   Main 页 `await AppBootstrap.ready()` 后调 `DeepLinkRouter.launchFromMain()`：替换 Main 为 Feed 并消费暂存目标。
 *   热启：EntryAbility.onNewWant → onNewWant(want) 直接经 AppRouter 导航。
 */
import { common, Want } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { AppRouter, Routes } from '../../common/Router';
import { ID_UNSET } from '../model/Enums';
import { DEEP_LINK_HOST } from '../util/Constants';
import { Repository } from '../repo/Repository';
import { resolveShortcutWantUri } from '../platform/Shortcuts';
import {
  EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED, COL_LINK, FEED_ITEMS_PATH_SEGMENT, ACTION_SEND_DATA, OPML_MIME_TYPES,
  FeedParam, ArticleParam, EditFeedParam, SearchFeedParam, AddFeedParam, SyncParam, AddFeedFromShareParam,
  ImportOpmlFileParam, SettingsRouteParam, TextSettingsRouteParam, OpenLinkKind, OpenLinkInDefaultParam,
  NavRoutes, ParsedUri, parseUri, parseLongOrNull, ACTION_VIEW_DATA as VIEW_DATA_ACTION
} from './RouteParams';

export {
  EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED, ACTION_OPEN_IN_CUSTOM_TAB, COL_LINK, FEED_ITEMS_PATH_SEGMENT,
  ACTION_VIEW_DATA, ACTION_SEND_DATA, OPML_MIME_TYPES, FeedParam, ArticleParam, EditFeedParam,
  SearchFeedParam, AddFeedParam, SyncParam, AddFeedFromShareParam, ImportOpmlFileParam, SettingsRouteParam,
  TextSettingsRouteParam, OpenLinkKind, OpenLinkInDefaultParam, QueryParamsBuilder, uriEncode, uriDecode,
  NavRoutes, feedDeepLink, articleDeepLink, syncJoinDeepLink, feedItemNotificationUri, ParsedUri, parseUri,
  parseLongOrNull
} from './RouteParams';

const LOG_TAG: string = 'FEEDER_DEEPLINK';

/** 冷启暂存目标的 AppStorage 键（由 Main 经 launchFromMain/consumePending 消费） */
export const PENDING_DEEP_LINK_KEY: string = 'feederPendingDeepLink';

// ============================================================ 目标

export class DeepLinkTarget {
  route: Routes = Routes.FEED;
  param: Object = new FeedParam();

  static of(route: Routes, param: Object): DeepLinkTarget {
    const t: DeepLinkTarget = new DeepLinkTarget();
    t.route = route;
    t.param = param;
    return t;
  }
}

/** APP-A61：只认三种深链（https + host feederapp.nononsenseapps.com）；不匹配返回 null（源 NavController 拒绝，仅日志） */
export function matchDeepLink(raw: string): DeepLinkTarget | null {
  const u: ParsedUri | null = parseUri(raw);
  if (u === null || u.scheme !== 'https' || u.host !== DEEP_LINK_HOST) {
    return null;
  }
  const seg: string[] = u.segments;
  if (seg.length === 1 && seg[0] === 'feed') {
    const idStr: string | undefined = u.query.get('id');
    let feedId: number = ID_UNSET;
    if (idStr !== undefined) {
      const n: number | null = parseLongOrNull(idStr);
      if (n === null) {
        return null;
      }
      feedId = n;
    }
    const tag: string | undefined = u.query.get('tag');
    return DeepLinkTarget.of(Routes.FEED, FeedParam.of(feedId, tag !== undefined ? tag : ''));
  }
  if (seg.length === 2 && seg[0] === 'article') {
    const n: number | null = parseLongOrNull(seg[1]);
    return n === null ? null : DeepLinkTarget.of(Routes.ARTICLE, ArticleParam.of(n));
  }
  if (seg.length === 2 && seg[0] === 'sync' && seg[1] === 'join') {
    const code: string | undefined = u.query.get('sync_code');
    const key: string | undefined = u.query.get('key');
    return DeepLinkTarget.of(Routes.SYNC_SCREEN,
      SyncParam.of(code !== undefined ? code : '', key !== undefined ? key : ''));
  }
  return null;
}

function readIdArray(want: Want, key: string): number[] | null {
  const v: Object | undefined = want.parameters?.[key];
  if (v === undefined || !Array.isArray(v)) {
    return null;
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

function isOpmlLike(want: Want, u: ParsedUri): boolean {
  const type: string = (want.type ?? '').toLowerCase();
  if (OPML_MIME_TYPES.indexOf(type) >= 0) {
    return true;
  }
  const p: string = u.path.toLowerCase();
  return p.endsWith('.opml') || p.endsWith('.xml');
}

/** 通知点击（源经 OpenLinkInDefaultActivity 代理的两条分支） */
function matchNotificationWant(want: Want, raw: string, u: ParsedUri): DeepLinkTarget | null {
  const ids: number[] | null = readIdArray(want, EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED);
  const seg: string[] = u.segments;
  if (u.host === DEEP_LINK_HOST && seg.length > 0 && seg[seg.length - 1] === 'feed' && ids !== null) {
    const p: OpenLinkInDefaultParam = new OpenLinkInDefaultParam();
    p.kind = OpenLinkKind.SUMMARY_NOTIFICATION;
    p.uri = raw;
    p.action = want.action ?? '';
    p.itemsToMarkAsNotified = ids;
    const feed: DeepLinkTarget | null = matchDeepLink(raw);
    p.feedTarget = feed !== null && feed.param instanceof FeedParam ? feed.param as FeedParam : null;
    return DeepLinkTarget.of(Routes.OPEN_LINK_IN_DEFAULT, p);
  }
  const fi: number = seg.indexOf(FEED_ITEMS_PATH_SEGMENT);
  if (fi >= 0 && u.host !== DEEP_LINK_HOST) {
    const p: OpenLinkInDefaultParam = new OpenLinkInDefaultParam();
    p.kind = OpenLinkKind.ITEM_NOTIFICATION;
    p.uri = raw;
    p.action = want.action ?? '';
    const last: string = seg[seg.length - 1];
    const id: number | null = fi < seg.length - 1 ? parseLongOrNull(last) : null;
    p.itemId = id !== null ? id : ID_UNSET;
    const link: string | undefined = u.query.get(COL_LINK);
    p.link = link !== undefined ? link : null;
    return DeepLinkTarget.of(Routes.OPEN_LINK_IN_DEFAULT, p);
  }
  return null;
}

/** 分享 Want（Share Kit）：文本/链接 → AddFeedFromShare；XML/OPML 文件 → ImportOPMLFile */
async function matchShareWant(want: Want): Promise<DeepLinkTarget | null> {
  try {
    const data: systemShare.SharedData = await systemShare.getSharedData(want);
    const records: systemShare.SharedRecord[] = data.getRecords();
    for (const rec of records) {
      const utd: string = rec.utd;
      const fileUri: string = rec.uri ?? '';
      if (fileUri.length > 0 && (utd.indexOf('xml') >= 0 || utd.indexOf('opml') >= 0 ||
        fileUri.toLowerCase().endsWith('.opml'))) {
        return DeepLinkTarget.of(Routes.IMPORT_OPMLFILE, ImportOpmlFileParam.of(fileUri));
      }
      // 源 AddFeedFromShareActivity：intent.dataString（链接数据）优先，其次 EXTRA_TEXT → 超链接记录的 uri 先于文本内容
      if (fileUri.length > 0 && (fileUri.startsWith('http://') || fileUri.startsWith('https://'))) {
        return DeepLinkTarget.of(Routes.ADD_FEED_FROM_SHARE, AddFeedFromShareParam.of(fileUri.trim()));
      }
      const text: string = (rec.content ?? '').trim();
      if (text.length > 0) {
        return DeepLinkTarget.of(Routes.ADD_FEED_FROM_SHARE, AddFeedFromShareParam.of(text));
      }
    }
  } catch (e) {
    console.warn(`${LOG_TAG}: getSharedData failed: ${JSON.stringify(e)}`);
  }
  // 兜底：显式 Want 直接携带 uri / 文本参数
  const uri: string = (want.uri ?? '').trim();
  if (uri.length > 0) {
    return DeepLinkTarget.of(Routes.ADD_FEED_FROM_SHARE, AddFeedFromShareParam.of(uri));
  }
  return null;
}

/**
 * Want → 目标。顺序：通知代理 → 三种深链 → 分享（sendData）→ VIEW http(s)（订阅源 MIME）→ OPML 文件；
 * 其余（桌面图标启动等）返回 null。
 */
export async function resolveWant(want: Want): Promise<DeepLinkTarget | null> {
  // RP-A08/UT-A34 静态槽位降级：桌面快捷方式槽位（parameters.feederShortcutSlot）→ 该槽当前源的深链
  const shortcutUri: string | null = await resolveShortcutWantUri(want);
  if (shortcutUri !== null) {
    want.uri = shortcutUri;
    want.action = VIEW_DATA_ACTION;
  }
  const raw: string = (want.uri ?? '').trim();
  const action: string = want.action ?? '';
  const u: ParsedUri | null = raw.length > 0 ? parseUri(raw) : null;
  if (u !== null) {
    const n: DeepLinkTarget | null = matchNotificationWant(want, raw, u);
    if (n !== null) {
      return n;
    }
    const d: DeepLinkTarget | null = matchDeepLink(raw);
    if (d !== null) {
      return d;
    }
    if (u.host === DEEP_LINK_HOST) {
      // 源：NavController rejected intent —— 仅日志，停留当前页
      console.error(`${LOG_TAG}: NavController rejected intent ${raw}`);
      return null;
    }
  }
  if (action === ACTION_SEND_DATA) {
    return await matchShareWant(want);
  }
  if (u !== null && (u.scheme === 'http' || u.scheme === 'https')) {
    return DeepLinkTarget.of(Routes.ADD_FEED_FROM_SHARE, AddFeedFromShareParam.of(raw));
  }
  const isFileScheme: boolean = u !== null && (u.scheme === 'file' || u.scheme === 'content' || u.scheme === 'datashare');
  if (u !== null && isFileScheme && isOpmlLike(want, u)) {
    return DeepLinkTarget.of(Routes.IMPORT_OPMLFILE, ImportOpmlFileParam.of(raw));
  }
  return null;
}

// ============================================================ 路由器

export class DeepLinkRouter {
  private static pending: Promise<DeepLinkTarget | null> | null = null;
  private static mainLaunched: boolean = false;

  /** EntryAbility.onCreate：解析冷启 Want 并暂存（AppStorage 镜像供 Main 观察） */
  static onCreateWant(want: Want): void {
    DeepLinkRouter.stash(want);
  }

  /** EntryAbility.onNewWant：Main 已接管导航 → 直接导航；否则暂存覆盖 */
  static onNewWant(want: Want): void {
    if (!DeepLinkRouter.mainLaunched) {
      DeepLinkRouter.stash(want);
      return;
    }
    resolveWant(want).then((t: DeepLinkTarget | null) => {
      if (t !== null) {
        DeepLinkRouter.navigate(t);
      }
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: resolve new want failed: ${e?.message}`);
    });
  }

  private static stash(want: Want): void {
    const p: Promise<DeepLinkTarget | null> = resolveWant(want).then((t: DeepLinkTarget | null) => {
      if (t !== null) {
        AppStorage.setOrCreate<DeepLinkTarget>(PENDING_DEEP_LINK_KEY, t);
      }
      return t;
    }).catch((e: Error): DeepLinkTarget | null => {
      console.error(`${LOG_TAG}: resolve want failed: ${e?.message}`);
      return null;
    });
    DeepLinkRouter.pending = p;
  }

  /** 取走冷启暂存目标（一次性） */
  static async consumePending(): Promise<DeepLinkTarget | null> {
    const p: Promise<DeepLinkTarget | null> | null = DeepLinkRouter.pending;
    DeepLinkRouter.pending = null;
    const t: DeepLinkTarget | null = p !== null ? await p : null;
    AppStorage.delete(PENDING_DEEP_LINK_KEY);
    return t;
  }

  /**
   * Main 页调用（AppBootstrap.ready() 之后）：替换 Main 为 Feed（冷启无参 = 上次 feed/tag），
   * 冷启目标为 Feed 则直接带参替换，否则在 Feed 之上打开目标页。此后 onNewWant 直接导航。
   */
  static async launchFromMain(): Promise<void> {
    const t: DeepLinkTarget | null = await DeepLinkRouter.consumePending();
    DeepLinkRouter.mainLaunched = true;
    if (t !== null && t.route === Routes.FEED) {
      AppRouter.replace(Routes.FEED, t.param);
      return;
    }
    AppRouter.replace(Routes.FEED, new FeedParam());
    if (t !== null) {
      DeepLinkRouter.navigate(t);
    }
  }

  static isMainLaunched(): boolean {
    return DeepLinkRouter.mainLaunched;
  }

  /** 统一导航：Feed 清栈（APP-A63），OpenLinkInDefault 总是压栈（源 singleInstance 代理），其余 singleTop */
  static navigate(t: DeepLinkTarget): void {
    if (t.route === Routes.FEED) {
      const p: FeedParam = t.param instanceof FeedParam ? t.param as FeedParam : new FeedParam();
      DeepLinkRouter.navigateToFeed(p.feedId, p.tag);
      return;
    }
    if (t.route === Routes.OPEN_LINK_IN_DEFAULT) {
      AppRouter.push(t.route, t.param);
      return;
    }
    DeepLinkRouter.navigateSingleTop(t.route, t.param);
  }

  /**
   * APP-A63：源 FeedDestination.navigate —— popUpTo(graph){inclusive} + launchSingleTop：
   * 清空整个返回栈，只留一个 Feed 实例。
   */
  static navigateToFeed(feedId: number = ID_UNSET, tag: string = ''): void {
    const param: FeedParam = FeedParam.of(feedId, tag);
    console.debug(`${LOG_TAG}: Navigate to ${NavRoutes.feed(feedId, tag)}`);
    const stack: NavPathStack = AppRouter.stack;
    if (stack.size() === 0) {
      AppRouter.push(Routes.FEED, param);
      return;
    }
    if (stack.size() > 1) {
      stack.popToIndex(0, false);
    }
    stack.replacePathByName(Routes.FEED, param, false);
  }

  /** launchSingleTop：栈顶已是同一目的地则原位替换参数，否则压栈 */
  static navigateSingleTop(route: Routes, param: Object): void {
    const names: string[] = AppRouter.stack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === route) {
      AppRouter.stack.replacePathByName(route, param, false);
      return;
    }
    AppRouter.push(route, param);
  }

  static navigateToArticle(itemId: number): void {
    DeepLinkRouter.navigateSingleTop(Routes.ARTICLE, ArticleParam.of(itemId));
  }

  static navigateToEditFeed(feedId: number): void {
    DeepLinkRouter.navigateSingleTop(Routes.EDIT_FEED, EditFeedParam.of(feedId));
  }

  static navigateToSearchFeed(feedUrl: string | null = null): void {
    DeepLinkRouter.navigateSingleTop(Routes.SEARCH_FEED, SearchFeedParam.of(feedUrl !== null ? feedUrl : ''));
  }

  static navigateToAddFeed(feedUrl: string, feedTitle: string = '', feedImage: string = ''): void {
    DeepLinkRouter.navigateSingleTop(Routes.ADD_FEED, AddFeedParam.of(feedUrl, feedTitle, feedImage));
  }

  static navigateToSettings(): void {
    DeepLinkRouter.navigateSingleTop(Routes.SETTINGS, new SettingsRouteParam());
  }

  static navigateToSyncScreen(syncCode: string = '', secretKey: string = ''): void {
    DeepLinkRouter.navigateSingleTop(Routes.SYNC_SCREEN, SyncParam.of(syncCode, secretKey));
  }

  static navigateToTextSettings(): void {
    DeepLinkRouter.navigateSingleTop(Routes.TEXT_SETTINGS, new TextSettingsRouteParam());
  }

  /** APP-A64：应用内添加/编辑订阅保存后 → 该订阅的 Feed 页 */
  static onFeedSaved(feedId: number): void {
    DeepLinkRouter.navigateToFeed(feedId, '');
  }

  /** 源 Article/Settings 返回：pop 失败（栈底）则 → fallback */
  static backOr(fallback: () => void): void {
    if (AppRouter.stack.size() > 1) {
      AppRouter.back();
    } else {
      fallback();
    }
  }

  // ------------------------------------------------------------ 全局导航观察（APP-A63 / APP-A65）

  private static switchCb: ((info: uiObserver.NavDestinationSwitchInfo) => void) | null = null;
  private static observedCtx: common.UIAbilityContext | null = null;

  /**
   * EntryAbility.onCreate 安装：观察本 Ability 内全部 NavDestination 切换（UIObserver navDestinationSwitch，
   * 不占用 AppRouter.stack 唯一的 setInterception——后者归 Index 冒烟钩子）。
   * 使任何调用方（含页面直接 AppRouter.push）都满足源 NavController 语义：
   *  - APP-A63：Feed 入栈/替换后清掉其下全部栈项（popUpTo(graph){inclusive}+singleTop）；
   *    其余目的地（OpenLinkInDefault 代理页、Main 壳除外）launchSingleTop：同名压到同名之上则移除下方旧实例；
   *  - APP-A65：进入（含返回到）Feed 页 ≙ FeedDestination LaunchedEffect → onEnterFeed(id, tag)。
   */
  static installNavigationObserver(ctx: common.UIAbilityContext): void {
    if (DeepLinkRouter.switchCb !== null) {
      return;
    }
    const cb = (info: uiObserver.NavDestinationSwitchInfo): void => {
      DeepLinkRouter.onDestinationSwitch(info);
    };
    try {
      uiObserver.on('navDestinationSwitch', ctx, cb);
      DeepLinkRouter.switchCb = cb;
      DeepLinkRouter.observedCtx = ctx;
    } catch (e) {
      console.error(`${LOG_TAG}: observe navDestinationSwitch failed: ${JSON.stringify(e)}`);
    }
  }

  static uninstallNavigationObserver(): void {
    const cb: ((info: uiObserver.NavDestinationSwitchInfo) => void) | null = DeepLinkRouter.switchCb;
    const ctx: common.UIAbilityContext | null = DeepLinkRouter.observedCtx;
    DeepLinkRouter.switchCb = null;
    DeepLinkRouter.observedCtx = null;
    if (cb !== null && ctx !== null) {
      try {
        uiObserver.off('navDestinationSwitch', ctx, cb);
      } catch (e) {
        console.warn(`${LOG_TAG}: unobserve navDestinationSwitch failed: ${JSON.stringify(e)}`);
      }
    }
  }

  private static destName(d: uiObserver.NavDestinationInfo | NavBar): string {
    if (typeof d === 'string') {
      return '';
    }
    const n: ResourceStr = (d as uiObserver.NavDestinationInfo).name;
    return typeof n === 'string' ? n as string : '';
  }

  private static onDestinationSwitch(info: uiObserver.NavDestinationSwitchInfo): void {
    if (typeof info.to === 'string') {
      return;
    }
    const to: uiObserver.NavDestinationInfo = info.to as uiObserver.NavDestinationInfo;
    const toName: string = DeepLinkRouter.destName(to);
    if (toName.length === 0) {
      return;
    }
    const op: NavigationOperation = info.operation;
    if (toName === Routes.FEED) {
      if (op === NavigationOperation.PUSH || op === NavigationOperation.REPLACE) {
        DeepLinkRouter.deferStackFix(() => DeepLinkRouter.clearBelowTopFeed());
      }
      DeepLinkRouter.enterFeedFrom(to);
      return;
    }
    if (op === NavigationOperation.PUSH && toName !== Routes.OPEN_LINK_IN_DEFAULT && toName !== Routes.MAIN &&
      DeepLinkRouter.destName(info.from) === toName) {
      DeepLinkRouter.deferStackFix(() => DeepLinkRouter.dropDuplicateBelowTop(toName));
    }
  }

  /** 栈修正延后到本次切换处理之后（避免在观察回调里同步改栈） */
  private static deferStackFix(fix: () => void): void {
    setTimeout(() => {
      try {
        fix();
      } catch (e) {
        console.error(`${LOG_TAG}: back stack fix failed: ${JSON.stringify(e)}`);
      }
    }, 0);
  }

  /** APP-A63（Feed）：栈顶仍是 Feed 时移除其下全部栈项 → Feed 为唯一实例 */
  private static clearBelowTopFeed(): void {
    const names: string[] = AppRouter.stack.getAllPathName();
    const top: number = names.length - 1;
    if (top <= 0 || names[top] !== Routes.FEED) {
      return;
    }
    const below: number[] = [];
    for (let i = 0; i < top; i++) {
      below.push(i);
    }
    AppRouter.stack.removeByIndexes(below);
  }

  /** APP-A63（singleTop）：栈顶与其下一项同名 → 移除下方旧实例（≙ 复用栈顶并换新参数，不叠加） */
  private static dropDuplicateBelowTop(route: string): void {
    const names: string[] = AppRouter.stack.getAllPathName();
    const top: number = names.length - 1;
    if (top >= 1 && names[top] === route && names[top - 1] === route) {
      AppRouter.stack.removeByIndexes([top - 1]);
    }
  }

  /** APP-A65：取 Feed 栈项参数（优先原对象，保证 instanceof）→ onEnterFeed */
  private static enterFeedFrom(to: uiObserver.NavDestinationInfo): void {
    let param: Object | undefined = undefined;
    try {
      param = AppRouter.stack.getParamByIndex(to.index) as Object | undefined;
    } catch (e) {
      param = undefined;
    }
    if (!(param instanceof FeedParam)) {
      param = to.param;
    }
    if (!(param instanceof FeedParam)) {
      return;
    }
    const p: FeedParam = param as FeedParam;
    DeepLinkRouter.onEnterFeed(p.feedId, p.tag).catch((e: Error) => {
      console.error(`${LOG_TAG}: onEnterFeed failed: ${e?.message}`);
    });
  }

  // ------------------------------------------------------------ APP-A65：NavigationDeepLinkViewModel

  /** Feed 页进入：id/tag 任一有值才设当前 feed/tag（并 isArticleOpen=false）；都空 = 显示上次 feed/tag */
  static async onEnterFeed(feedId: number, tag: string): Promise<void> {
    if (feedId !== ID_UNSET || tag.trim().length > 0) {
      const repo: Repository = Repository.instance();
      await repo.setCurrentFeedAndTag(feedId, tag);
      // Should open feed in portrait
      await repo.setIsArticleOpen(false);
    }
  }

  /** Article 页进入：后台标记已读+已通知；当前文章 id；isArticleOpen=true */
  static async onEnterArticle(itemId: number): Promise<void> {
    const repo: Repository = Repository.instance();
    repo.markAsReadAndNotified(itemId).catch((e: Error) => {
      console.error(`${LOG_TAG}: markAsReadAndNotified failed: ${e?.message}`);
    });
    await repo.setCurrentArticle(itemId);
    // Should open article in portrait
    await repo.setIsArticleOpen(true);
  }
}
