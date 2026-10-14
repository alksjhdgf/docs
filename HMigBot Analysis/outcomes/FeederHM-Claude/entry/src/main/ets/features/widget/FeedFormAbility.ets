/**
 * FeedFormAbility.ets —— 源 widget/FeedWidgetReceiver.kt（GlanceAppWidgetReceiver）+ FeedWidget.kt 数据侧
 * （provideGlance / WidgetState / 图标加载 / 同步按钮）的鸿蒙实现。
 *
 * - FeedWidgetUpdater：卡片数据构造与推送（formProvider.updateForm）。
 *   · 数据（NW-A16/A17）：全局单一小组件源（SettingsStore currentWidgetFeedId/Tag）→ FeedItemStore.getWidgetFeedListItems
 *     （收藏 / 指定源 / 指定 tag / 全部；排除屏蔽；倒序 ≤50；含已读）。
 *   · 状态（NW-A21）：源 combine(syncWorkerRunning, items)：同步进行中或尚未首次加载 → Syncing（"Refreshing"）。
 *     syncWorkerRunning 是进程内状态，而同步可能跑在主进程 / WorkScheduler 扩展进程 / 卡片扩展进程：
 *     各进程经 trackSyncRunning()/start() 订阅本进程 syncWorkerRunning —— 变真立即推送 Syncing、变假重查推送；
 *     并在 filesDir/widget_sync_running/<pid> 留跨进程标记，任一进程推送时"本进程运行中 ∨ 他进程标记未过期"即 Syncing，
 *     避免其他进程在后台同步期间把旧列表推回卡片。
 *   · 源选择（NW-A16/A30）：主进程（设置权威，NotificationActions.install 声明）以 SettingsStore 为准并镜像到
 *     filesDir/widget_source.json；扩展进程（Preferences 进程内缓存、主进程改动不可见）每次推送前读该镜像，
 *     缺失才回落本进程 SettingsStore。
 *   · 图标（NW-A25）：源图标 feedImageUrl，单张 1 秒超时，失败不显示；照源 Coil size(200) 缩放为 ≤200px PNG 后经
 *     formImages(fd) + `memory://` 下发卡片（解码失败则原样下发，不额外判失败）。
 *   · 刷新（NW-A24）：Glance 依赖 Flow 自动重组，鸿蒙必须显式推送 —— 进程内 start() 订阅
 *     「当前小组件列表（DB 变化 / 源选择变化即重查）」与「syncWorkerRunning」，去抖后重查并推送全部已发布卡片；
 *     refreshAll() 供同步结束 / 选择变化 / 卡片生命周期显式调用。
 * - FeedFormAbility（default export，FormExtensionAbility）：onAddForm / onUpdateForm / onCastToNormalForm 刷新；
 *   onFormEvent(sync) → 以默认参数（非强制、最小源年龄 5 分钟）直接 RssLocalSync.syncFeeds，结束后刷新（NW-A22，
 *   此路径不经同步作业，不发布新条目通知）。
 * module.json5 的 form 扩展声明（type "form" + metadata ohos.extension.form → $profile:form_config）归 fnd-app-init。
 */
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { process } from '@kit.ArkTS';
import { FeedListItem } from '../../core/model/FeedItem';
import { FeedItemStore } from '../../core/repo/FeedItemStore';
import { Repository } from '../../core/repo/Repository';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { HttpClient } from '../../core/net/HttpClient';
import { HttpResponse } from '../../core/net/HttpMessages';
// 卡片动作常量唯一定义在卡片文件（form_config.json 的 src），此处引用并再导出供其他调用方使用
import { WIDGET_ACTION_OPEN_APP, WIDGET_ACTION_OPEN_ARTICLE, WIDGET_ACTION_SETTINGS, WIDGET_ACTION_SYNC } from './FeedWidgetForm';
import { NetworkResult } from '../../core/net/NetworkResult';
import { SyncStatus } from '../../core/sync/SyncStatus';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { RssLocalSync } from '../../core/sync/RssLocalSync';
import { registerSyncChainStartupHook } from '../sync/SyncChain';
export { WIDGET_ACTION_OPEN_APP, WIDGET_ACTION_OPEN_ARTICLE, WIDGET_ACTION_SETTINGS, WIDGET_ACTION_SYNC };

const LOG_TAG: string = 'FEEDER_WIDGET';

/** 卡片 → 应用事件参数键与取值（与 FeedWidgetForm.ets 内常量一致） */
export const WIDGET_PARAM_ACTION: string = 'feederWidgetAction';
export const WIDGET_PARAM_ITEM_ID: string = 'feederWidgetItemId';

/** 源 Coil 单张图标加载超时 1 秒（NW-A25） */
export const WIDGET_ICON_TIMEOUT_MS: number = 1000;
/** 源 LIMIT 50（DAO 已限制；此处仅作防御） */
export const WIDGET_MAX_ITEMS: number = 50;
/** 源 Coil ImageRequest.size(200) */
export const WIDGET_ICON_SIZE_PX: number = 200;
const PUSH_DEBOUNCE_MS: number = 300;
const ICON_DIR_NAME: string = 'widget_icons';
/** 跨进程同步运行标记目录（文件名 = pid，内容 = 开始时刻 epoch ms） */
const SYNC_MARKER_DIR_NAME: string = 'widget_sync_running';
/** 标记过期（进程异常退出未清理时的兜底；超时后卡片回落列表） */
export const SYNC_MARKER_STALE_MS: number = 5 * 60 * 1000;
/** 小组件源镜像（主进程写，扩展进程读） */
const WIDGET_SOURCE_FILE: string = 'widget_source.json';

/** 卡片条目（字段与 FeedWidgetForm.FeedWidgetCardItem 一致） */
export class WidgetCardItem {
  itemId: number = 0;
  title: string = '';
  snippet: string = '';
  unread: boolean = true;
  icon: string = '';
}

/** formBindingData 载荷：syncing / items 写入卡片 LocalStorage；formImages 为系统保留键（名 → fd） */
export class WidgetCardData {
  syncing: boolean = true;
  items: WidgetCardItem[] = [];
  formImages: Record<string, number> = {};
}

class BuiltCardData {
  data: WidgetCardData = new WidgetCardData();
  fds: number[] = [];
}

/** 全局单一小组件源（NW-A16：pref_widget_last_feed_id / pref_widget_last_feed_tag） */
export class WidgetSource {
  feedId: number = 0;
  tag: string = '';

  toJson(): string {
    return `{"feedId":${this.feedId},"tag":${JSON.stringify(this.tag)}}`;
  }

  static fromJson(text: string): WidgetSource | null {
    try {
      const o: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const id: Object | undefined = o['feedId'];
      const tag: Object | undefined = o['tag'];
      if (typeof id !== 'number' || typeof tag !== 'string') {
        return null;
      }
      const r: WidgetSource = new WidgetSource();
      r.feedId = id as number;
      r.tag = tag as string;
      return r;
    } catch (e) {
      return null;
    }
  }
}

/** 纯逻辑：他进程同步标记是否有效（未过期，且不是本进程） */
export function isForeignSyncMarkerActive(markerPid: string, ownPid: string, startedAtMs: number, nowMs: number): boolean {
  if (markerPid === ownPid) {
    return false;
  }
  return startedAtMs > 0 && nowMs - startedAtMs >= 0 && nowMs - startedAtMs < SYNC_MARKER_STALE_MS;
}

/** 源 FeedWidgetItem → 卡片条目（不显示源名/日期） */
export function toWidgetCardItem(item: FeedListItem, icon: string): WidgetCardItem {
  const c: WidgetCardItem = new WidgetCardItem();
  c.itemId = item.id;
  c.title = item.title;
  c.snippet = item.snippet;
  c.unread = item.unread;
  c.icon = icon;
  return c;
}

/** 源 WidgetState：syncWorkerRunning 或尚未加载（items=null）→ Syncing */
export function isWidgetSyncing(syncWorkerRunning: boolean, items: FeedListItem[] | null): boolean {
  return syncWorkerRunning || items === null;
}

/** formImages 键：URL 的稳定短哈希（卡片按名缓存图片） */
export function widgetIconKey(url: string): string {
  let h: number = 5381;
  for (let i = 0; i < url.length; i++) {
    h = ((h << 5) + h + url.charCodeAt(i)) | 0;
  }
  return `feedicon_${(h >>> 0).toString(16)}`;
}

function timeout<T>(ms: number, fallback: T): Promise<T> {
  return new Promise<T>((resolve) => {
    setTimeout(() => {
      resolve(fallback);
    }, ms);
  });
}

export class FeedWidgetUpdater {
  private static ctx: common.Context | null = null;
  private static offItems: (() => void) | null = null;
  private static offSync: (() => void) | null = null;
  /** null = 尚未首次加载 */
  private static items: FeedListItem[] | null = null;
  private static syncRunning: boolean = false;
  private static pushTimer: number = -1;
  /** 本进程已知的卡片 id（onAddForm 记录；getPublishedRunningFormInfos 不可用时兜底） */
  private static knownFormIds: Set<string> = new Set<string>();
  /** 已成功落盘的图标：url → 文件路径 */
  private static iconFiles: Map<string, string> = new Map<string, string>();
  /** 本进程是否为小组件源设置的权威进程（主进程；SettingsStore 即真值） */
  private static settingsAuthority: boolean = false;
  private static lastMirroredSource: string = '';
  /** 他进程同步标记过期时补推一次（本进程存活时） */
  private static staleTimer: number = -1;

  static setContext(ctx: common.Context): void {
    FeedWidgetUpdater.ctx = ctx;
  }

  /** 主进程声明：小组件源以本进程 SettingsStore 为准，并镜像给扩展进程（NotificationActions.install 调用） */
  static becomeSettingsAuthority(): void {
    FeedWidgetUpdater.settingsAuthority = true;
  }

  /**
   * NW-A21：订阅本进程 syncWorkerRunning（幂等）。变真 → 立即推送 Syncing 并留跨进程标记；变假 → 清标记并重查推送。
   * WorkScheduler 扩展进程（后台周期/一次性同步）在 onWorkStart 调用；start() 内含此订阅。
   */
  static trackSyncRunning(ctx: common.Context): void {
    FeedWidgetUpdater.ctx = ctx;
    if (FeedWidgetUpdater.offSync !== null) {
      return;
    }
    FeedWidgetUpdater.offSync = SyncStatus.observeSyncWorkerRunning((running: boolean): void => {
      FeedWidgetUpdater.onLocalSyncRunning(running);
    });
  }

  private static onLocalSyncRunning(running: boolean): void {
    const changed: boolean = FeedWidgetUpdater.syncRunning !== running;
    FeedWidgetUpdater.syncRunning = running;
    FeedWidgetUpdater.writeSyncMarker(running);
    if (!changed) {
      return;
    }
    if (running) {
      // 源 WidgetState 立即切到 Syncing：无需查库，直接推送
      FeedWidgetUpdater.pushState(true, FeedWidgetUpdater.items, null).catch((e: Error) => {
        console.error(`${LOG_TAG}: push syncing failed: ${e?.message}`);
      });
    } else {
      FeedWidgetUpdater.schedulePush();
    }
  }

  /** 进程内持续推送（主进程在 AppBootstrap.ready() 后调用；卡片扩展进程同步期间调用） */
  static start(ctx: common.Context): void {
    FeedWidgetUpdater.ctx = ctx;
    FeedWidgetUpdater.trackSyncRunning(ctx);
    if (FeedWidgetUpdater.offItems !== null) {
      return;
    }
    if (FeedWidgetUpdater.settingsAuthority) {
      FeedWidgetUpdater.mirrorSource(FeedWidgetUpdater.settingsSource());
    }
    try {
      FeedWidgetUpdater.offItems = Repository.instance().observeCurrentWidgetFeedListItems(
        (items: FeedListItem[]): void => {
          FeedWidgetUpdater.items = items;
          FeedWidgetUpdater.schedulePush();
        });
    } catch (e) {
      console.error(`${LOG_TAG}: observe widget items failed: ${JSON.stringify(e)}`);
      FeedWidgetUpdater.offItems = (): void => {
      };
    }
  }

  static stop(): void {
    const a: (() => void) | null = FeedWidgetUpdater.offItems;
    const b: (() => void) | null = FeedWidgetUpdater.offSync;
    FeedWidgetUpdater.offItems = null;
    FeedWidgetUpdater.offSync = null;
    if (a !== null) {
      a();
    }
    if (b !== null) {
      b();
    }
    if (FeedWidgetUpdater.pushTimer !== -1) {
      clearTimeout(FeedWidgetUpdater.pushTimer);
      FeedWidgetUpdater.pushTimer = -1;
    }
    if (FeedWidgetUpdater.staleTimer !== -1) {
      clearTimeout(FeedWidgetUpdater.staleTimer);
      FeedWidgetUpdater.staleTimer = -1;
    }
    if (FeedWidgetUpdater.syncRunning) {
      FeedWidgetUpdater.writeSyncMarker(false);
    }
  }

  static rememberFormId(formId: string): void {
    if (formId.length > 0) {
      FeedWidgetUpdater.knownFormIds.add(formId);
    }
  }

  static forgetFormId(formId: string): void {
    FeedWidgetUpdater.knownFormIds.delete(formId);
  }

  private static schedulePush(): void {
    if (FeedWidgetUpdater.pushTimer !== -1) {
      clearTimeout(FeedWidgetUpdater.pushTimer);
    }
    FeedWidgetUpdater.pushTimer = setTimeout(() => {
      FeedWidgetUpdater.pushTimer = -1;
      // 每次按当前小组件源重查（扩展进程的列表订阅可能基于过期的源选择）
      FeedWidgetUpdater.refreshAll().catch((e: Error) => {
        console.error(`${LOG_TAG}: push failed: ${e?.message}`);
      });
    }, PUSH_DEBOUNCE_MS);
  }

  private static settingsSource(): WidgetSource {
    const s: SettingsStore = SettingsStore.instance();
    const r: WidgetSource = new WidgetSource();
    r.feedId = s.currentWidgetFeedId;
    r.tag = s.currentWidgetFeedTag;
    return r;
  }

  private static sourceFilePath(): string {
    const ctx: common.Context | null = FeedWidgetUpdater.ctx;
    return ctx !== null ? `${ctx.filesDir}/${WIDGET_SOURCE_FILE}` : '';
  }

  private static mirrorSource(src: WidgetSource): void {
    const json: string = src.toJson();
    const p: string = FeedWidgetUpdater.sourceFilePath();
    if (p.length === 0 || json === FeedWidgetUpdater.lastMirroredSource) {
      return;
    }
    let file: fs.File | null = null;
    try {
      file = fs.openSync(p, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, json);
      FeedWidgetUpdater.lastMirroredSource = json;
    } catch (e) {
      console.warn(`${LOG_TAG}: mirror widget source failed: ${JSON.stringify(e)}`);
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (ce) {
          console.warn(`${LOG_TAG}: close source file failed: ${JSON.stringify(ce)}`);
        }
      }
    }
  }

  /**
   * NW-A16/A24/A30：当前全局小组件源。主进程 = SettingsStore（并镜像）；扩展进程 = 主进程镜像（每次重读），
   * 无镜像时回落本进程启动时载入的 SettingsStore。
   */
  static currentSource(): WidgetSource {
    if (FeedWidgetUpdater.settingsAuthority) {
      const src: WidgetSource = FeedWidgetUpdater.settingsSource();
      FeedWidgetUpdater.mirrorSource(src);
      return src;
    }
    const p: string = FeedWidgetUpdater.sourceFilePath();
    if (p.length > 0) {
      try {
        if (fs.accessSync(p)) {
          const mirrored: WidgetSource | null = WidgetSource.fromJson(fs.readTextSync(p));
          if (mirrored !== null) {
            return mirrored;
          }
        }
      } catch (e) {
        console.warn(`${LOG_TAG}: read widget source failed: ${JSON.stringify(e)}`);
      }
    }
    return FeedWidgetUpdater.settingsSource();
  }

  private static markerDir(): string {
    const ctx: common.Context | null = FeedWidgetUpdater.ctx;
    return ctx !== null ? `${ctx.filesDir}/${SYNC_MARKER_DIR_NAME}` : '';
  }

  private static writeSyncMarker(running: boolean): void {
    const dir: string = FeedWidgetUpdater.markerDir();
    if (dir.length === 0) {
      return;
    }
    const path: string = `${dir}/${process.pid}`;
    try {
      if (running) {
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir);
        }
        const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          fs.writeSync(file.fd, `${Date.now()}`);
        } finally {
          fs.closeSync(file);
        }
      } else if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: sync marker update failed: ${JSON.stringify(e)}`);
    }
  }

  /** 他进程（后台同步 / 卡片同步 / 主进程手动同步）正在同步时返回其最晚过期时刻，否则 -1 */
  private static foreignSyncExpiry(): number {
    const dir: string = FeedWidgetUpdater.markerDir();
    if (dir.length === 0) {
      return -1;
    }
    const own: string = `${process.pid}`;
    const now: number = Date.now();
    let expiry: number = -1;
    try {
      if (!fs.accessSync(dir)) {
        return -1;
      }
      for (const name of fs.listFileSync(dir)) {
        let started: number = 0;
        try {
          started = Number(fs.readTextSync(`${dir}/${name}`).trim());
        } catch (re) {
          started = 0;
        }
        if (isForeignSyncMarkerActive(name, own, isNaN(started) ? 0 : started, now)) {
          expiry = Math.max(expiry, started + SYNC_MARKER_STALE_MS);
        } else if (name !== own) {
          try {
            fs.unlinkSync(`${dir}/${name}`);
          } catch (ue) {
            // 并发删除，忽略
          }
        }
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: read sync markers failed: ${JSON.stringify(e)}`);
    }
    return expiry;
  }

  /** NW-A21：本进程 syncWorkerRunning ∨ 他进程同步标记有效 */
  private static effectiveSyncing(localRunning: boolean): boolean {
    const expiry: number = FeedWidgetUpdater.foreignSyncExpiry();
    if (expiry > 0 && FeedWidgetUpdater.staleTimer === -1) {
      // 他进程异常退出未清标记：过期后补推，避免卡片停在 Refreshing
      FeedWidgetUpdater.staleTimer = setTimeout(() => {
        FeedWidgetUpdater.staleTimer = -1;
        FeedWidgetUpdater.refreshAll().catch((e: Error) => {
          console.error(`${LOG_TAG}: stale-marker refresh failed: ${e?.message}`);
        });
      }, Math.max(expiry - Date.now(), 0) + 1000);
    }
    return localRunning || expiry > 0;
  }

  /** 重查当前小组件列表并推送到全部（或指定）卡片（源 updateAll 的等价物，NW-A24/A29） */
  static async refreshAll(onlyFormId: string | null = null): Promise<void> {
    let items: FeedListItem[] | null = null;
    try {
      const src: WidgetSource = FeedWidgetUpdater.currentSource();
      items = await FeedItemStore.instance().getWidgetFeedListItems(src.feedId, src.tag);
    } catch (e) {
      console.error(`${LOG_TAG}: load widget items failed: ${JSON.stringify(e)}`);
    }
    if (items !== null) {
      FeedWidgetUpdater.items = items;
    }
    await FeedWidgetUpdater.pushState(SyncStatus.isSyncWorkerRunning(), items, onlyFormId);
  }

  /** 已发布到桌面的本应用卡片 id */
  static async publishedFormIds(): Promise<string[]> {
    const ids: Set<string> = new Set<string>(FeedWidgetUpdater.knownFormIds);
    try {
      const infos: formInfo.RunningFormInfo[] = await formProvider.getPublishedRunningFormInfos();
      for (const info of infos) {
        ids.add(info.formId);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: getPublishedRunningFormInfos failed: ${JSON.stringify(e)}`);
    }
    return Array.from(ids);
  }

  private static async pushState(syncing: boolean, items: FeedListItem[] | null, onlyFormId: string | null): Promise<void> {
    const formIds: string[] = onlyFormId !== null ? [onlyFormId] : await FeedWidgetUpdater.publishedFormIds();
    if (formIds.length === 0) {
      return;
    }
    const effective: boolean = FeedWidgetUpdater.effectiveSyncing(syncing);
    for (const formId of formIds) {
      // 每张卡片各自一组 fd（updateForm 后关闭）
      const built: BuiltCardData = await FeedWidgetUpdater.build(effective, items);
      try {
        await formProvider.updateForm(formId, formBindingData.createFormBindingData(built.data));
      } catch (e) {
        console.warn(`${LOG_TAG}: updateForm(${formId}) failed: ${JSON.stringify(e)}`);
        if (onlyFormId === null) {
          FeedWidgetUpdater.forgetFormId(formId);
        }
      } finally {
        FeedWidgetUpdater.closeAll(built.fds);
      }
    }
  }

  /** 构造卡片数据（导出供 onAddForm 同步返回首帧） */
  static async build(syncing: boolean, items: FeedListItem[] | null): Promise<BuiltCardData> {
    const out: BuiltCardData = new BuiltCardData();
    out.data.syncing = isWidgetSyncing(syncing, items);
    if (out.data.syncing || items === null) {
      return out;
    }
    const list: FeedListItem[] = items.slice(0, WIDGET_MAX_ITEMS);
    const urls: string[] = [];
    for (const it of list) {
      const u: string | null = it.feedImageUrl;
      if (u !== null && u.length > 0 && urls.indexOf(u) < 0) {
        urls.push(u);
      }
    }
    const paths: (string | null)[] = await Promise.all(urls.map((u: string): Promise<string | null> =>
      FeedWidgetUpdater.iconFile(u)));
    const iconByUrl: Map<string, string> = new Map<string, string>();
    for (let i = 0; i < urls.length; i++) {
      const p: string | null = paths[i];
      if (p === null) {
        continue;
      }
      try {
        const file: fs.File = fs.openSync(p, fs.OpenMode.READ_ONLY);
        const key: string = widgetIconKey(urls[i]);
        out.data.formImages[key] = file.fd;
        out.fds.push(file.fd);
        iconByUrl.set(urls[i], `memory://${key}`);
      } catch (e) {
        FeedWidgetUpdater.iconFiles.delete(urls[i]);
      }
    }
    out.data.items = list.map((it: FeedListItem): WidgetCardItem => {
      const u: string | null = it.feedImageUrl;
      const icon: string | undefined = u !== null ? iconByUrl.get(u) : undefined;
      return toWidgetCardItem(it, icon !== undefined ? icon : '');
    });
    return out;
  }

  private static closeAll(fds: number[]): void {
    for (const fd of fds) {
      try {
        fs.closeSync(fd);
      } catch (e) {
        // ignore
      }
    }
  }

  /** 照源 Coil size(200)：等比缩放到长边 ≤200px 并编码为 PNG；无法解码的格式原样返回（交卡片 Image 自行解码） */
  private static async downscale(body: ArrayBuffer): Promise<ArrayBuffer> {
    let src: image.ImageSource | null = null;
    let pm: image.PixelMap | null = null;
    try {
      src = image.createImageSource(body);
      const info: image.ImageInfo = await src.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      if (w <= 0 || h <= 0) {
        return body;
      }
      const scale: number = Math.min(1, WIDGET_ICON_SIZE_PX / Math.max(w, h));
      if (scale >= 1) {
        return body;
      }
      const opts: image.DecodingOptions = {
        desiredSize: { width: Math.max(1, Math.round(w * scale)), height: Math.max(1, Math.round(h * scale)) }
      };
      pm = await src.createPixelMap(opts);
      const packer: image.ImagePacker = image.createImagePacker();
      try {
        const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
        return await packer.packToData(pm, packOpts);
      } finally {
        packer.release();
      }
    } catch (e) {
      return body;
    } finally {
      if (pm !== null) {
        pm.release();
      }
      if (src !== null) {
        src.release();
      }
    }
  }

  /** 源 Coil：size 200、单张超时 1 秒、失败 null（不阻塞列表） */
  private static async iconFile(url: string): Promise<string | null> {
    const cached: string | undefined = FeedWidgetUpdater.iconFiles.get(url);
    if (cached !== undefined) {
      return cached;
    }
    const ctx: common.Context | null = FeedWidgetUpdater.ctx;
    if (ctx === null) {
      return null;
    }
    let body: ArrayBuffer | null = null;
    try {
      const fetching: Promise<ArrayBuffer | null> = HttpClient.images().fetchImage(url)
        .then((r: NetworkResult<HttpResponse>): ArrayBuffer | null => {
          const resp: HttpResponse | null = r.getOrNull();
          return resp !== null && resp.isSuccessful() ? resp.body : null;
        })
        .catch((): ArrayBuffer | null => null);
      body = await Promise.race<ArrayBuffer | null>([fetching, timeout<ArrayBuffer | null>(WIDGET_ICON_TIMEOUT_MS, null)]);
    } catch (e) {
      body = null;
    }
    if (body === null || body.byteLength === 0) {
      return null;
    }
    body = await FeedWidgetUpdater.downscale(body);
    try {
      const dir: string = `${ctx.cacheDir}/${ICON_DIR_NAME}`;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const path: string = `${dir}/${widgetIconKey(url)}.img`;
      const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, body);
      } finally {
        fs.closeSync(file);
      }
      FeedWidgetUpdater.iconFiles.set(url, path);
      return path;
    } catch (e) {
      console.warn(`${LOG_TAG}: write icon failed: ${JSON.stringify(e)}`);
      return null;
    }
  }
}

// ============================================================ 卡片扩展进程

// 卡片扩展进程：同步按钮直接 syncFeeds（NW-A22），同步链客户端须在 bootstrapHeadless 内安装（≙ 源 DI 单例）
registerSyncChainStartupHook();

let headlessReady: Promise<void> | null = null;

/** 卡片扩展进程无 AppBootstrap：初始化设置/数据库/HTTP/同步引擎（一次） */
function ensureHeadless(ctx: common.Context): Promise<void> {
  if (headlessReady === null) {
    headlessReady = SyncScheduler.bootstrapHeadless(ctx).catch((e: Error) => {
      headlessReady = null;
      console.error(`${LOG_TAG}: headless bootstrap failed: ${e?.message}`);
    });
  }
  return headlessReady as Promise<void>;
}

function formIdOf(want: Want): string {
  const v: Object | undefined = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
  return typeof v === 'string' ? v as string : '';
}

function messageAction(message: string): string {
  try {
    const obj: Record<string, Object> = JSON.parse(message) as Record<string, Object>;
    const v: Object | undefined = obj[WIDGET_PARAM_ACTION];
    if (typeof v === 'string') {
      return v as string;
    }
    const params: Object | undefined = obj['params'];
    if (params !== undefined && typeof params === 'object') {
      const inner: Object | undefined = (params as Record<string, Object>)[WIDGET_PARAM_ACTION];
      return typeof inner === 'string' ? inner as string : '';
    }
  } catch (e) {
    console.warn(`${LOG_TAG}: bad form message: ${message}`);
  }
  return '';
}

/** 卡片同步按钮（源 rssLocalSync.syncFeeds() 默认参数；不经同步作业 → 不发通知） */
export async function runWidgetSync(ctx: common.Context): Promise<void> {
  await ensureHeadless(ctx);
  FeedWidgetUpdater.start(ctx);
  try {
    await RssLocalSync.instance().syncFeeds();
  } catch (e) {
    console.error(`${LOG_TAG}: widget sync failed: ${JSON.stringify(e)}`);
  }
  await FeedWidgetUpdater.refreshAll();
}

export default class FeedFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = formIdOf(want);
    FeedWidgetUpdater.rememberFormId(formId);
    FeedWidgetUpdater.setContext(this.context);
    this.refresh(formId.length > 0 ? formId : null);
    // 源 WidgetState 起始先 emit Syncing
    return formBindingData.createFormBindingData(new WidgetCardData());
  }

  onCastToNormalForm(formId: string): void {
    FeedWidgetUpdater.rememberFormId(formId);
    this.refresh(formId);
  }

  onUpdateForm(formId: string, wantParams?: Record<string, Object>): void {
    FeedWidgetUpdater.rememberFormId(formId);
    this.refresh(formId);
  }

  onFormEvent(formId: string, message: string): void {
    FeedWidgetUpdater.rememberFormId(formId);
    if (messageAction(message) === WIDGET_ACTION_SYNC) {
      runWidgetSync(this.context).catch((e: Error) => {
        console.error(`${LOG_TAG}: sync event failed: ${e?.message}`);
      });
      return;
    }
    console.warn(`${LOG_TAG}: unknown form event ${message}`);
  }

  onRemoveForm(formId: string): void {
    FeedWidgetUpdater.forgetFormId(formId);
  }

  private refresh(formId: string | null): void {
    const ctx: common.Context = this.context;
    ensureHeadless(ctx).then(() => {
      FeedWidgetUpdater.setContext(ctx);
      return FeedWidgetUpdater.refreshAll(formId);
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: refresh failed: ${e?.message}`);
    });
  }
}
