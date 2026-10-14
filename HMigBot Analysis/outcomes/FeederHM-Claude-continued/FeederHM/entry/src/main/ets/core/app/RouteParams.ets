/**
 * RouteParams.ets —— 路由参数类（页面共享契约）、源路由字符串（NavigationDestinations.kt route/QueryParamsBuilder）、
 * 深链 URI 构造与宽容 URI 解析。由 DeepLinkRouter 使用并整体再导出；页面切片取参后 `instanceof XxxParam` 窄化，
 * 禁止各自重定义同名参数类。
 */
import { ID_UNSET } from '../model/Enums';
import { DEEP_LINK_BASE_URI } from '../util/Constants';

/** 源 RssNotifications.EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED（汇总通知点击：只标"已通知"） */
export const EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED: string = 'items_to_mark_as_notified';
/** 源 ACTION_OPEN_IN_CUSTOM_TAB（单篇通知：应用内浏览页打开） */
export const ACTION_OPEN_IN_CUSTOM_TAB: string = 'com.nononsenseapps.feeder.OPEN_IN_CUSTOM_TAB';
/** 源 db/Constants.COL_LINK（feed_items 通知 URI 的 link 查询参数） */
export const COL_LINK: string = 'link';
/** 源 db/Uri.URI_FEEDITEMS 的路径段 */
export const FEED_ITEMS_PATH_SEGMENT: string = 'feed_items';

export const ACTION_VIEW_DATA: string = 'ohos.want.action.viewData';
export const ACTION_SEND_DATA: string = 'ohos.want.action.sendData';

/** OPML 文件 Want 接受的 MIME（源 ImportOPMLFileActivity intent-filter） */
export const OPML_MIME_TYPES: string[] = ['text/xml', 'application/xml', 'text/x-opml', 'application/octet-stream'];

// ============================================================ 路由参数（页面共享契约）

/** Feed：`feed?id={id}&tag={tag}`，id 默认 ID_UNSET(0)、tag 默认 "" */
export class FeedParam {
  feedId: number = ID_UNSET;
  tag: string = '';

  static of(feedId: number = ID_UNSET, tag: string = ''): FeedParam {
    const p: FeedParam = new FeedParam();
    p.feedId = feedId;
    p.tag = tag;
    return p;
  }
}

/** Article：`reader/{itemId}`（必填） */
export class ArticleParam {
  itemId: number = ID_UNSET;

  static of(itemId: number): ArticleParam {
    const p: ArticleParam = new ArticleParam();
    p.itemId = itemId;
    return p;
  }
}

/** EditFeed：`edit/feed/{feedId}` */
export class EditFeedParam {
  feedId: number = ID_UNSET;

  static of(feedId: number): EditFeedParam {
    const p: EditFeedParam = new EditFeedParam();
    p.feedId = feedId;
    return p;
  }
}

/** SearchFeed / Search：`search/feed?feedUrl={feedUrl}`（默认 null → ""） */
export class SearchFeedParam {
  feedUrl: string = '';

  static of(feedUrl: string = ''): SearchFeedParam {
    const p: SearchFeedParam = new SearchFeedParam();
    p.feedUrl = feedUrl;
    return p;
  }
}

/** AddFeed：`add/feed/{feedUrl}?feedTitle=&feedImage=` */
export class AddFeedParam {
  feedUrl: string = '';
  feedTitle: string = '';
  feedImage: string = '';

  static of(feedUrl: string, feedTitle: string = '', feedImage: string = ''): AddFeedParam {
    const p: AddFeedParam = new AddFeedParam();
    p.feedUrl = feedUrl;
    p.feedTitle = feedTitle;
    p.feedImage = feedImage;
    return p;
  }
}

/** SyncScreen：`sync?syncCode=&secretKey=`（默认 ""） */
export class SyncParam {
  syncCode: string = '';
  secretKey: string = '';

  static of(syncCode: string = '', secretKey: string = ''): SyncParam {
    const p: SyncParam = new SyncParam();
    p.syncCode = syncCode;
    p.secretKey = secretKey;
    return p;
  }
}

/** AddFeedFromShare：源 `(intent.dataString ?: EXTRA_TEXT)?.trim()` */
export class AddFeedFromShareParam {
  initialFeedUrl: string = '';

  static of(initialFeedUrl: string): AddFeedFromShareParam {
    const p: AddFeedFromShareParam = new AddFeedFromShareParam();
    p.initialFeedUrl = initialFeedUrl;
    return p;
  }
}

/** ImportOPMLFile：源 intent.data（文件 URI，可能为空串 ≙ null） */
export class ImportOpmlFileParam {
  uri: string = '';

  static of(uri: string): ImportOpmlFileParam {
    const p: ImportOpmlFileParam = new ImportOpmlFileParam();
    p.uri = uri;
    return p;
  }
}

/** Settings / TextSettings 无参数路由的占位参数类（便于 instanceof 区分来源） */
export class SettingsRouteParam {
}

export class TextSettingsRouteParam {
}

export enum OpenLinkKind {
  /** 分支 A：汇总通知（BASE/feed?…）→ markAsNotified(ids) → 打开该 Feed 深链 */
  SUMMARY_NOTIFICATION = 0,
  /** 分支 B：单篇通知（…/feed_items/{id}?link=）→ markAsReadAndNotified + 取消通知 + 打开链接 */
  ITEM_NOTIFICATION = 1,
}

/** OpenLinkInDefault（无界面代理，源 OpenLinkInDefaultActivity） */
export class OpenLinkInDefaultParam {
  kind: OpenLinkKind = OpenLinkKind.ITEM_NOTIFICATION;
  /** 原始 URI */
  uri: string = '';
  /** Want action（ACTION_OPEN_IN_CUSTOM_TAB → 应用内浏览页，否则默认浏览器） */
  action: string = '';
  /** 分支 A：需标记为已通知的条目 id */
  itemsToMarkAsNotified: number[] = [];
  /** 分支 B：条目 id（源 lastPathSegment，缺失 → ID_UNSET） */
  itemId: number = ID_UNSET;
  /** 分支 B：要打开的链接（源 getQueryParameter(COL_LINK)） */
  link: string | null = null;
  /** 分支 A：解析出的 Feed 深链目标（打开主界面用） */
  feedTarget: FeedParam | null = null;
}

// ============================================================ 路由字符串（APP-A60 / A62）

/** 源 QueryParamsBuilder：null/空值跳过；值 Uri.encode；首个 `?` 其后 `&` */
export class QueryParamsBuilder {
  private sb: string = '';

  add(name: string, value: string | null): QueryParamsBuilder {
    if (value === null || value.length === 0) {
      return this;
    }
    this.sb += this.sb.length === 0 ? '?' : '&';
    this.sb += `${name}=${uriEncode(value)}`;
    return this;
  }

  toString(): string {
    return this.sb;
  }
}

/** android.net.Uri.encode 等价（保留 A-Z a-z 0-9 _-!.~'()*，其余 UTF-8 百分号编码） */
export function uriEncode(s: string): string {
  return encodeURIComponent(s);
}

/**
 * java.net.URLEncoder.encode(s, "UTF-8") 等价（源 util/SystemUtils.kt:34 `String.urlEncode()`，表单编码）：
 * 保留 A-Z a-z 0-9 . - * _，空格 → '+'，其余 UTF-8 百分号编码（大写十六进制）。
 */
export function formEncode(s: string): string {
  return encodeURIComponent(s)
    .replace(new RegExp('!', 'g'), '%21')
    .replace(new RegExp('\'', 'g'), '%27')
    .replace(new RegExp('\\(', 'g'), '%28')
    .replace(new RegExp('\\)', 'g'), '%29')
    .replace(new RegExp('~', 'g'), '%7E')
    .replace(new RegExp('%20', 'g'), '+');
}

/** android.net.Uri.getQueryParameter 解码语义：'+' 视为空格（UriCodec.decode convertPlus=true）后百分号解码 */
export function queryParamDecode(s: string): string {
  return uriDecode(s.replace(new RegExp('\\+', 'g'), ' '));
}

/** 宽容解码：非法百分号序列原样返回 */
export function uriDecode(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch (e) {
    return s;
  }
}

/** 源各 Destination.navigate 生成的 route 字符串（与源路由集合一一对应，供日志/测试/外部对照） */
export class NavRoutes {
  /** 路由模板集合（源 NavigationDestination.route） */
  static readonly PATTERNS: string[] = [
    'feed?id={id}&tag={tag}',
    'reader/{itemId}',
    'edit/feed/{feedId}',
    'search/feed?feedUrl={feedUrl}',
    'add/feed/{feedUrl}?feedTitle={feedTitle}&feedImage={feedImage}',
    'settings',
    'sync?syncCode={syncCode}&secretKey={secretKey}',
    'font/add',
  ];

  static feed(feedId: number = ID_UNSET, tag: string = ''): string {
    const q: QueryParamsBuilder = new QueryParamsBuilder();
    if (feedId !== ID_UNSET) {
      q.add('id', `${feedId}`);
    }
    q.add('tag', tag);
    return `feed${q.toString()}`;
  }

  static reader(itemId: number): string {
    return `reader/${itemId}`;
  }

  static editFeed(feedId: number): string {
    return `edit/feed/${feedId}`;
  }

  static searchFeed(feedUrl: string | null = null): string {
    return `search/feed${new QueryParamsBuilder().add('feedUrl', feedUrl).toString()}`;
  }

  static addFeed(feedUrl: string, feedTitle: string = '', feedImage: string = ''): string {
    const q: string = new QueryParamsBuilder().add('feedTitle', feedTitle).add('feedImage', feedImage).toString();
    return `add/feed/${uriEncode(feedUrl)}${q}`;
  }

  static settings(): string {
    return 'settings';
  }

  static sync(syncCode: string, secretKey: string): string {
    const q: QueryParamsBuilder = new QueryParamsBuilder();
    if (syncCode.trim().length > 0) {
      q.add('syncCode', syncCode);
    }
    if (secretKey.trim().length > 0) {
      q.add('secretKey', secretKey);
    }
    return `sync${q.toString()}`;
  }

  static textSettings(): string {
    return 'font/add';
  }
}

// ============================================================ 深链 URI 构造（外区写入方使用）

/** 通知汇总 / 快捷方式 / OPML 导入完成：`BASE/feed?id={id}&tag={urlEncoded}`（源 RssNotifications.kt:320 `deepLinkTag.urlEncode()`，表单编码，UT-A30） */
export function feedDeepLink(feedId: number, tag: string = ''): string {
  return `${DEEP_LINK_BASE_URI}/feed?id=${feedId}&tag=${formEncode(tag)}`;
}

/** 通知单篇 / 小组件条目：`BASE/article/{id}` */
export function articleDeepLink(itemId: number): string {
  return `${DEEP_LINK_BASE_URI}/article/${itemId}`;
}

/** 同步"添加设备"：`BASE/sync/join?sync_code=…&key=…` */
export function syncJoinDeepLink(syncCode: string, secretKey: string): string {
  // 源 SyncScreenViewModel.kt:229 key 用 urlEncode()（表单编码）；sync_code 源未编码（十六进制，uriEncode 恒等）
  return `${DEEP_LINK_BASE_URI}/sync/join?sync_code=${uriEncode(syncCode)}&key=${formEncode(secretKey)}`;
}

/** 单篇通知代理 URI（源 URI_FEEDITEMS/{id}?link=…）；authority 用 `<bundleName>.rssprovider` 对齐源 */
export function feedItemNotificationUri(bundleName: string, itemId: number, link: string | null): string {
  const q: string = new QueryParamsBuilder().add(COL_LINK, link).toString();
  return `content://${bundleName}.rssprovider/${FEED_ITEMS_PATH_SEGMENT}/${itemId}${q}`;
}

// ============================================================ URI 解析

export class ParsedUri {
  scheme: string = '';
  host: string = '';
  path: string = '';
  segments: string[] = [];
  query: Map<string, string> = new Map<string, string>();
}

/** 宽容 URI 拆分（scheme://authority/path?query#fragment）；无 scheme 返回 null */
export function parseUri(raw: string): ParsedUri | null {
  const s: string = raw.trim();
  const schemeEnd: number = s.indexOf(':');
  if (schemeEnd <= 0) {
    return null;
  }
  const r: ParsedUri = new ParsedUri();
  r.scheme = s.substring(0, schemeEnd).toLowerCase();
  let rest: string = s.substring(schemeEnd + 1);
  const hashAt: number = rest.indexOf('#');
  if (hashAt >= 0) {
    rest = rest.substring(0, hashAt);
  }
  let queryStr: string = '';
  const qAt: number = rest.indexOf('?');
  if (qAt >= 0) {
    queryStr = rest.substring(qAt + 1);
    rest = rest.substring(0, qAt);
  }
  if (rest.startsWith('//')) {
    rest = rest.substring(2);
    const slash: number = rest.indexOf('/');
    let authority: string = slash >= 0 ? rest.substring(0, slash) : rest;
    rest = slash >= 0 ? rest.substring(slash) : '';
    const at: number = authority.lastIndexOf('@');
    if (at >= 0) {
      authority = authority.substring(at + 1);
    }
    const colon: number = authority.lastIndexOf(':');
    if (colon >= 0 && authority.indexOf(']') < colon) {
      authority = authority.substring(0, colon);
    }
    r.host = authority.toLowerCase();
  }
  r.path = rest;
  r.segments = rest.split('/').filter((seg: string): boolean => seg.length > 0).map((seg: string): string => uriDecode(seg));
  if (queryStr.length > 0) {
    for (const pair of queryStr.split('&')) {
      if (pair.length === 0) {
        continue;
      }
      const eq: number = pair.indexOf('=');
      // 源经 android.net.Uri.getQueryParameter(s)：'+' → 空格（与 formEncode 对称）
      const k: string = queryParamDecode(eq >= 0 ? pair.substring(0, eq) : pair);
      const v: string = queryParamDecode(eq >= 0 ? pair.substring(eq + 1) : '');
      if (!r.query.has(k)) {
        r.query.set(k, v);
      }
    }
  }
  return r;
}

/** Java Long.parseLong 语义（可选负号 + 十进制数字，且在安全整数内）；失败 null */
export function parseLongOrNull(s: string): number | null {
  if (!new RegExp('^-?[0-9]+$').test(s)) {
    return null;
  }
  const n: number = Number(s);
  return Number.isSafeInteger(n) ? n : null;
}
