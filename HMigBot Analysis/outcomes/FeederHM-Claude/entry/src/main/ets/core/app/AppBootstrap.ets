/**
 * AppBootstrap.ets —— 源 FeederApplication（Kodein DI 单例容器 + onCreate）与 MainActivity.onCreate 调度项的鸿蒙等价物。
 *
 * 源 INIT 逐项（INIT-A01）：
 *  - FeederApplication.onCreate 仅 `staticFilesDir = filesDir`（供旧 DB 迁移写 blob，已废弃）→ 不适用：
 *    鸿蒙库从 schema 40 新建，无旧迁移；filesDir 经 FilePathProvider 统一派生（APP-A75）。
 *  - DI 绑定（构造期/懒加载单例，APP-A70）在此按依赖顺序显式初始化：
 *    SettingsStore（单一 preferences 文件，APP-A73）→ AppDatabase + DAO（静态单例）→ HttpClient（200MB 主缓存 +
 *    300MB 图片缓存，拦截器链见 core/net，APP-A71/A72）→ SyncScheduler（RssLocalSync 路径、设置钩子）→
 *    RepositoryHooks（同步/同步链/快捷方式反向依赖）→ Repository.init（屏蔽钩子、字体目录、首启加 Feeder News 源）。
 *  - MainActivity.onCreate：ensurePeriodicSyncConfigured（replace=false）+ schedulePeriodicOrphanedFilesCleanup（每日）。
 *  - RSSContentProvider（INIT-A02）：onCreate 只取 DI，不承载初始化职责 → 不适用；对外只读接口降级见 RssReadOnlyApi。
 *  - TTSStateHolder / PodcastPlayerStateHolder 构造期创建 → 由各自切片懒加载（不在本启动链）。
 * 页面（Main）`await AppBootstrap.ready()` 后再进入首页（INIT-A01：首页前完成）。
 */
import { common } from '@kit.AbilityKit';
import { SettingsStore } from '../settings/SettingsStore';
import { AppDatabase } from '../db/AppDatabase';
import { HttpClient } from '../net/HttpClient';
import { FilePathProvider } from '../util/Constants';
import { Repository } from '../repo/Repository';
import { RepositoryHooks } from '../repo/RepoTypes';
import { SyncScheduler } from '../sync/SyncScheduler';
import { isSyncChainConfigured } from '../sync/RssLocalSync';
import { addDynamicShortcutToFeed, removeFeedShortcuts, reportShortcutToFeedUsed } from '../platform/Shortcuts';

const LOG_TAG: string = 'FEEDER_BOOTSTRAP';

/**
 * 源 ApplicationCoroutineScope（Dispatchers.Default + SupervisorJob，APP-A76）：
 * 每个后台任务独立捕获异常，单个失败不影响其它任务。
 */
export class AppScope {
  private static running: number = 0;

  static launch(name: string, task: () => Promise<void>): void {
    AppScope.running++;
    let p: Promise<void>;
    try {
      p = task();
    } catch (e) {
      AppScope.running--;
      console.error(`${LOG_TAG}: task ${name} threw: ${(e as Error)?.message}`);
      return;
    }
    p.catch((e: Error) => {
      console.error(`${LOG_TAG}: task ${name} failed: ${e?.message}`);
    }).finally(() => {
      AppScope.running--;
    });
  }

  static activeCount(): number {
    return AppScope.running;
  }
}

export class AppBootstrap {
  private static ctx: common.UIAbilityContext | null = null;
  private static paths: FilePathProvider | null = null;
  private static settingsPromise: Promise<void> | null = null;
  private static readyPromise: Promise<void> | null = null;
  private static readyFlag: boolean = false;
  private static error: Error | null = null;

  /** EntryAbility.onCreate 调用；幂等（热启/重建不重复初始化） */
  static start(ctx: common.UIAbilityContext): void {
    AppBootstrap.ctx = ctx;
    if (AppBootstrap.readyPromise !== null) {
      return;
    }
    AppBootstrap.paths = new FilePathProvider(ctx.cacheDir, ctx.filesDir);
    const settings: Promise<void> = SettingsStore.init(ctx);
    AppBootstrap.settingsPromise = settings.catch((e: Error) => {
      AppBootstrap.recordError('settings', e);
    });
    AppBootstrap.readyPromise = AppBootstrap.run(ctx).catch((e: Error) => {
      AppBootstrap.recordError('bootstrap', e);
    }).finally(() => {
      AppBootstrap.readyFlag = true;
    });
  }

  /** 设置已加载（主题/字体等 UI 状态依赖它）；失败也会兑现（错误见 lastError） */
  static settingsReady(): Promise<void> {
    const p: Promise<void> | null = AppBootstrap.settingsPromise;
    return p !== null ? p : Promise.resolve();
  }

  /** 首页前必须完成的初始化全部结束；失败也会兑现（不让 Main 卡住），错误见 lastError */
  static ready(): Promise<void> {
    const p: Promise<void> | null = AppBootstrap.readyPromise;
    if (p === null) {
      console.error(`${LOG_TAG}: ready() before start()`);
      return Promise.resolve();
    }
    return p;
  }

  static isReady(): boolean {
    return AppBootstrap.readyFlag;
  }

  static lastError(): Error | null {
    return AppBootstrap.error;
  }

  static context(): common.UIAbilityContext | null {
    return AppBootstrap.ctx;
  }

  /** APP-A75 存储目录约定（files/articles、cache/full_articles、files/fonts、cache/http、cache/image_cache…） */
  static filePaths(): FilePathProvider | null {
    return AppBootstrap.paths;
  }

  private static recordError(step: string, e: Error): void {
    AppBootstrap.error = e;
    console.error(`${LOG_TAG}: ${step} failed: ${e?.message}`);
  }

  private static async run(ctx: common.UIAbilityContext): Promise<void> {
    const paths: FilePathProvider = new FilePathProvider(ctx.cacheDir, ctx.filesDir);
    // 1. 设置（单一 preferences，各 Store 共享）
    await SettingsStore.init(ctx);
    // 2. 数据库（rssDatabase，schema 40，DAO 静态单例）
    await AppDatabase.init(ctx);
    // 3. HTTP 客户端（主 200MB 磁盘缓存；图片独立缓存 + 仅 Wi-Fi 只读缓存）
    HttpClient.init(paths);
    // 4. 同步引擎（RssLocalSync 路径、设置变化→重排周期同步、全文同步请求器）
    SyncScheduler.init(ctx);
    // 5. Repository 反向依赖钩子（JobScheduler / 同步链 / 动态快捷方式）
    AppBootstrap.registerRepositoryHooks();
    // 5b. 进程级安装项（同步链客户端 installSyncChain 等；由 EntryAbility 在 start() 前注册，core 不反向 import features）
    await SyncScheduler.runStorageReadyHooks(ctx);
    // 6. Repository 首启：屏蔽状态钩子、字体目录扫描、addedFeederNews=false 时订阅 Feeder News 并同步该源
    await Repository.instance().init(ctx);
    // 7. 源 MainActivity.onCreate 的两项调度（不阻塞首页）
    AppScope.launch('ensurePeriodicSyncConfigured', (): Promise<void> => SyncScheduler.ensurePeriodicSyncConfigured());
    AppScope.launch('schedulePeriodicOrphanedFilesCleanup',
      (): Promise<void> => SyncScheduler.schedulePeriodicOrphanedFilesCleanup());
    console.info(`${LOG_TAG}: ready`);
  }

  /** 注入点由 core/repo/RepoTypes 定义；已注册者（后续切片）可再次覆盖 */
  private static registerRepositoryHooks(): void {
    RepositoryHooks.setRssSyncHook(async (feedId: number, feedTag: string, forceNetwork: boolean,
      triggeredByUser: boolean): Promise<void> => {
      await SyncScheduler.runOnceRssSync(feedId, feedTag, forceNetwork, triggeredByUser);
    });
    RepositoryHooks.setSyncChainSendReadHook(async (): Promise<void> => {
      SyncScheduler.runOnceSyncChainSendRead();
    });
    RepositoryHooks.setSyncChainConfiguredHook((): boolean => isSyncChainConfigured());
    RepositoryHooks.setShortcutHooks(async (feedId: number, label: string): Promise<void> => {
      addDynamicShortcutToFeed(label, feedId);
      reportShortcutToFeedUsed(feedId);
    }, (feedIds: number[]): void => {
      removeFeedShortcuts(feedIds);
    });
  }
}
