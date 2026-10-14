/**
 * MainViewModel.ets —— 源 ui/MainActivityViewModel.kt + MainActivity 生命周期职责（onCreate/onStart/onResume/
 * onStop/onKeyDown）的鸿蒙等价物。
 *
 * Main 页是冷启壳：`await AppBootstrap.ready()` 后调 `MainViewModel.instance().launch(ctx)` 再立即
 * `DeepLinkRouter.launchFromMain()` 替换为 Feed。Main 页随即出栈，因此"Activity 生命周期"职责不能挂在 Main 页上，
 * 而是由本模块级单例经 ApplicationContext `applicationStateChange` 接管（单 UIAbility 应用：应用前后台 ≙ Activity
 * onStart/onStop + onResume）：
 *  - launch（≙ onCreate→onStart→onResume）：ensurePeriodicSyncConfigured + 孤儿文件清理调度（APP-A13）、
 *    快照 syncOnResume（源构造期快照）、启动通知监听（APP-A14）、setResumeTime（APP-A15）、maybeRequestSync（APP-A11）。
 *  - 前台：runForever + setResumeTime + maybeRequestSync；后台：stopForever。
 *  - 音量键（APP-A12）：分页模式且文章打开时经 inputConsumer 'keyPressed' 订阅音量上/下（订阅期间系统不再调音量），
 *    发出 ScrollDirection 滚动命令（≙ MutableSharedFlow 无 replay）；条件不满足或进入后台即退订，恢复系统行为。
 */
import { ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { inputConsumer, KeyCode, KeyEvent as InputKeyEvent } from '@kit.InputKit';
import { ID_UNSET } from '../../core/model/Enums';
import { isOkToSyncAutomatically as systemOkToSync } from '../../core/platform/SystemConditions';
import { Repository } from '../../core/repo/Repository';
import { Listeners } from '../../core/repo/RepoTypes';
import { AppScope } from '../../core/app/AppBootstrap';
import { PREF_IS_ARTICLE_OPEN, PREF_PAGING_MODE } from '../../core/settings/SettingsKeys';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { NotificationsWorker } from './NotificationsWorker';

const LOG_TAG: string = 'FEEDER_MAIN';

/** 源 ui/MainActivityViewModel.ScrollDirection */
export enum ScrollDirection {
  UP = 0,
  DOWN = 1,
}

/** 源 isOkToSyncAutomatically 的纯组合（短路顺序照源），便于单测 */
export function shouldRequestSyncOnResume(syncOnResumeSnapshot: boolean, okToSyncAutomatically: () => boolean): boolean {
  return syncOnResumeSnapshot && okToSyncAutomatically();
}

/** 源 onKeyDown 判定：分页模式且文章打开时消费音量上/下键 */
export function volumeKeyScrollDirection(keyCode: number, pagingMode: boolean,
  articleOpen: boolean): ScrollDirection | null {
  if (!pagingMode || !articleOpen) {
    return null;
  }
  if (keyCode === KeyCode.KEYCODE_VOLUME_UP) {
    return ScrollDirection.UP;
  }
  if (keyCode === KeyCode.KEYCODE_VOLUME_DOWN) {
    return ScrollDirection.DOWN;
  }
  return null;
}

@ObservedV2
export class MainViewModel {
  private static inst: MainViewModel | null = null;

  /** 当前是否处于前台（≙ Activity started） */
  @Trace inForeground: boolean = false;
  /** 音量键滚动是否在接管（订阅中） */
  @Trace volumeKeysCaptured: boolean = false;

  /** 源 shouldSyncOnResume：构造期快照 repository.syncOnResume.value（每次 Main 启动重取） */
  private syncOnResumeSnapshot: boolean = false;
  private launchCount: number = 0;
  private appCtx: common.ApplicationContext | null = null;
  private stateCallback: ApplicationStateChangeCallback | null = null;
  private settingsOff: (() => void) | null = null;
  private readonly scrollListeners: Listeners<ScrollDirection> = new Listeners<ScrollDirection>();
  private readonly volumeUpCb: (e: InputKeyEvent) => void = (e: InputKeyEvent): void => {
    this.onVolumeKey(e);
  };
  private readonly volumeDownCb: (e: InputKeyEvent) => void = (e: InputKeyEvent): void => {
    this.onVolumeKey(e);
  };

  static instance(): MainViewModel {
    if (MainViewModel.inst === null) {
      MainViewModel.inst = new MainViewModel();
    }
    return MainViewModel.inst as MainViewModel;
  }

  // ------------------------------------------------------------ 源 MainActivityViewModel 公开面

  get isPagingMode(): boolean {
    return Repository.instance().isPagingMode;
  }

  get isAnimatedPaging(): boolean {
    return SettingsStore.instance().isAnimatedPaging;
  }

  get shouldSyncOnResume(): boolean {
    return this.syncOnResumeSnapshot;
  }

  /** 源 scrollCommand（SharedFlow，无 replay）：文章页订阅；返回反订阅函数 */
  observeScrollCommand(cb: (direction: ScrollDirection) => void): () => void {
    return this.scrollListeners.add(cb);
  }

  emitScrollCommand(direction: ScrollDirection): void {
    this.scrollListeners.emit(direction);
  }

  /** 源 setResumeTime(Instant.now())（APP-A15，会话级） */
  setResumeTime(): void {
    Repository.instance().setResumeTime(Date.now());
  }

  /** 源 ensurePeriodicSyncConfigured → schedulePeriodicRssSync(replace=false) */
  ensurePeriodicSyncConfigured(): void {
    AppScope.launch('ensurePeriodicSyncConfigured', (): Promise<void> => SyncScheduler.ensurePeriodicSyncConfigured());
  }

  /** 源 isOkToSyncAutomatically：联网 &&（!仅充电 || 充电中）&&（!仅 Wi-Fi || 非计费） */
  isOkToSyncAutomatically(): boolean {
    return systemOkToSync();
  }

  // ------------------------------------------------------------ 生命周期

  /**
   * Main 页在 AppBootstrap.ready() 之后调用（≙ MainActivity.onCreate → onStart → onResume）。
   * 每次 Main 启动（含 UIAbility 销毁重建）调用一次。
   */
  launch(ctx: common.UIAbilityContext | null): void {
    this.launchCount++;
    // onCreate：首次启动的两项调度已由 AppBootstrap.run 发起（同一进程内重复并发调度会互相 replace），
    // 此后每次 Main 重建照源再确保一次（replace=false / 已存在则不重复）。
    if (this.launchCount > 1) {
      this.ensurePeriodicSyncConfigured();
      AppScope.launch('schedulePeriodicOrphanedFilesCleanup',
        (): Promise<void> => SyncScheduler.schedulePeriodicOrphanedFilesCleanup());
    }
    this.syncOnResumeSnapshot = Repository.instance().syncOnResume;
    this.registerAppStateCallback(ctx);
    this.observeSettings();
    // 冷启时 Main 必在前台：onStart + onResume
    this.inForeground = true;
    this.onStart();
    this.onResume();
  }

  private registerAppStateCallback(ctx: common.UIAbilityContext | null): void {
    if (this.stateCallback !== null || ctx === null) {
      return;
    }
    try {
      const appCtx: common.ApplicationContext = ctx.getApplicationContext();
      const cb: ApplicationStateChangeCallback = {
        onApplicationForeground(): void {
          MainViewModel.instance().onAppForeground();
        },
        onApplicationBackground(): void {
          MainViewModel.instance().onAppBackground();
        }
      };
      appCtx.on('applicationStateChange', cb);
      this.appCtx = appCtx;
      this.stateCallback = cb;
    } catch (e) {
      console.error(`${LOG_TAG}: register applicationStateChange failed: ${JSON.stringify(e)}`);
    }
  }

  private observeSettings(): void {
    if (this.settingsOff !== null) {
      return;
    }
    this.settingsOff = SettingsStore.instance().observe((key: string): void => {
      if (key === PREF_PAGING_MODE || key === PREF_IS_ARTICLE_OPEN) {
        this.updateVolumeKeyCapture();
      }
    });
  }

  /** 应用回到前台（≙ onStart + onResume）；已在前台则忽略（去重冷启首发） */
  onAppForeground(): void {
    if (this.inForeground) {
      return;
    }
    this.inForeground = true;
    this.onStart();
    this.onResume();
  }

  /** 应用进入后台（≙ onStop） */
  onAppBackground(): void {
    if (!this.inForeground) {
      return;
    }
    this.inForeground = false;
    NotificationsWorker.instance().stopForever();
    this.updateVolumeKeyCapture();
  }

  private onStart(): void {
    NotificationsWorker.instance().runForever();
    this.updateVolumeKeyCapture();
  }

  private onResume(): void {
    this.setResumeTime();
    this.maybeRequestSync();
  }

  /** 源 MainActivity.maybeRequestSync（APP-A11）：同步链取更新 + RSS 同步（非用户触发、不强制网络） */
  maybeRequestSync(): void {
    if (!shouldRequestSyncOnResume(this.syncOnResumeSnapshot, (): boolean => this.isOkToSyncAutomatically())) {
      return;
    }
    try {
      SyncScheduler.runOnceSyncChainGetUpdates();
    } catch (e) {
      console.error(`${LOG_TAG}: runOnceSyncChainGetUpdates failed: ${JSON.stringify(e)}`);
    }
    SyncScheduler.runOnceRssSync(ID_UNSET, '', false, false).catch((e: Error) => {
      console.error(`${LOG_TAG}: resume sync failed: ${e?.message}`);
    });
  }

  // ------------------------------------------------------------ 音量键（APP-A12）

  /** 前台 且 分页模式 且 文章打开 → 接管音量键；否则释放（系统调音量） */
  updateVolumeKeyCapture(): void {
    const repo: Repository = Repository.instance();
    const want: boolean = this.inForeground && repo.isPagingMode && repo.isArticleOpen;
    if (want === this.volumeKeysCaptured) {
      return;
    }
    if (want) {
      this.captureVolumeKeys();
    } else {
      this.releaseVolumeKeys();
    }
  }

  private captureVolumeKeys(): void {
    try {
      const up: inputConsumer.KeyPressedConfig = { key: KeyCode.KEYCODE_VOLUME_UP, action: 1, isRepeat: true };
      inputConsumer.on('keyPressed', up, this.volumeUpCb);
      const down: inputConsumer.KeyPressedConfig = { key: KeyCode.KEYCODE_VOLUME_DOWN, action: 1, isRepeat: true };
      inputConsumer.on('keyPressed', down, this.volumeDownCb);
      this.volumeKeysCaptured = true;
    } catch (e) {
      console.error(`${LOG_TAG}: subscribe volume keys failed: ${JSON.stringify(e)}`);
      this.releaseVolumeKeys();
    }
  }

  private releaseVolumeKeys(): void {
    try {
      inputConsumer.off('keyPressed', this.volumeUpCb);
      inputConsumer.off('keyPressed', this.volumeDownCb);
    } catch (e) {
      console.warn(`${LOG_TAG}: unsubscribe volume keys failed: ${JSON.stringify(e)}`);
    }
    this.volumeKeysCaptured = false;
  }

  private onVolumeKey(e: InputKeyEvent): void {
    const repo: Repository = Repository.instance();
    const dir: ScrollDirection | null = volumeKeyScrollDirection(e.key.code, repo.isPagingMode, repo.isArticleOpen);
    if (dir !== null) {
      this.emitScrollCommand(dir);
    } else {
      // 条件已变（设置通知尚未到达）：释放接管，下一次按键回归系统音量
      this.updateVolumeKeyCapture();
    }
  }

  /** 测试/进程收尾：对称清理全部订阅 */
  dispose(): void {
    NotificationsWorker.instance().stopForever();
    this.releaseVolumeKeys();
    const off: (() => void) | null = this.settingsOff;
    this.settingsOff = null;
    if (off !== null) {
      off();
    }
    const appCtx: common.ApplicationContext | null = this.appCtx;
    const cb: ApplicationStateChangeCallback | null = this.stateCallback;
    if (appCtx !== null && cb !== null) {
      try {
        appCtx.off('applicationStateChange', cb);
      } catch (e) {
        console.warn(`${LOG_TAG}: off applicationStateChange failed: ${JSON.stringify(e)}`);
      }
    }
    this.appCtx = null;
    this.stateCallback = null;
    this.inForeground = false;
  }
}
