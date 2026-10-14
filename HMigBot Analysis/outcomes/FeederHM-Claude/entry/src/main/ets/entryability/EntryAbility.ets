import { AbilityConstant, UIAbility, Want, appRecovery } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UIContext, window } from '@kit.ArkUI';
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { LayoutAdapt, SavedStateRegistry } from '../core/platform/LayoutAdapt';
import { ActivityLauncher } from '../core/platform/LinkOpener';
import { FeederUiBootstrap, ThemeController, screenDensity } from '../ui/common/Theme';
import { registerInAppBrowser } from '../features/article/InAppBrowser';
import { NotificationActions } from '../features/notify/NotificationActions';
import { registerSyncChainStartupHook } from '../features/sync/SyncChain';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // hmig:smokeRoute 波级冒烟直达透传（smoke.mjs 经 aa start --ps smokeRoute 传入；正常启动无此参数）——冻结件，勿删
    const hmigSmokeRoute: Object | undefined = want.parameters?.['smokeRoute'];
    if (typeof hmigSmokeRoute === 'string' && hmigSmokeRoute.length > 0) {
      AppStorage.setOrCreate('smokeRoute', hmigSmokeRoute);
    }
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    // UT-A47/FD-A51：≙ Android 进程被回收后 Activity savedInstanceState 恢复（源 SavedStateHandle/rememberSaveable）。
    // 退后台即存（SAVE_WHEN_BACKGROUND → onSaveState），重建时 launchReason=APP_RECOVERY 走下方恢复分支；
    // 配合 module.json5 EntryAbility "recoverable": true（SDK toolchains/modulecheck/module.json:1243）。
    try {
      appRecovery.enableAppRecovery(appRecovery.RestartFlag.ALWAYS_RESTART,
        appRecovery.SaveOccasionFlag.SAVE_WHEN_BACKGROUND, appRecovery.SaveModeFlag.SAVE_WITH_FILE);
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'enableAppRecovery failed: %{public}s', JSON.stringify(e) ?? '');
    }
    // fnd-app-init：进程重建恢复页面保存态（SavedStateHandle 等价）
    if (launchParam.launchReason === AbilityConstant.LaunchReason.APP_RECOVERY) {
      SavedStateRegistry.restoreAll(want.parameters);
    }
    // 3b 收口：features 级进程安装项须在 AppBootstrap.start 之前注册（run() 第 5 步后执行 installSyncChain）
    registerSyncChainStartupHook();
    // fnd-app-init：应用级初始化（≙ FeederApplication DI + MainActivity.onCreate 调度），Main 页 await ready()
    AppBootstrap.start(this.context);
    ActivityLauncher.bind(this.context);
    // 3b 收口：应用内浏览页钩子（CUSTOM_TAB），不依赖 Article 页懒加载
    registerInAppBrowser();
    // 3b 收口：新条目通知钩子 / 通知后台动作订阅 / 小组件推送；卡片 router 事件改写须先于 DeepLinkRouter
    NotificationActions.install(this.context);
    NotificationActions.onWant(want);
    // 冷启 Want（深链/分享/OPML/通知点击）解析暂存，由 Main 消费
    DeepLinkRouter.onCreateWant(want);
    // APP-A63/A65：全局导航观察——Feed 清栈、其余 singleTop、进入 Feed 设当前 feed/tag 与 isArticleOpen=false
    DeepLinkRouter.installNavigationObserver(this.context);
    // 主题/字体状态依赖设置（APP-A74：所有入口统一应用主题、暗色、动态色、文字缩放、字体）
    AppBootstrap.settingsReady().then(() => {
      FeederUiBootstrap.init(this.context);
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', 'Ability onNewWant reason=%{public}d', launchParam.launchReason);
    // 热启（≙ singleTop onNewIntent → navController.handleDeepLink）
    NotificationActions.onWant(want);
    DeepLinkRouter.onNewWant(want);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    DeepLinkRouter.uninstallNavigationObserver();
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    SavedStateRegistry.saveAll(wantParam);
    return AbilityConstant.OnSaveResult.RECOVERY_AGREE;
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // fnd-app-init：沉浸式（≙ enableEdgeToEdge）+ 避让区 AppStorageV2 `AvoidArea` + 窗口度量
    let mainWindow: window.Window | null = null;
    try {
      mainWindow = windowStage.getMainWindowSync();
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'getMainWindowSync failed: %{public}s', JSON.stringify(e) ?? '');
    }
    if (mainWindow !== null) {
      const win: window.Window = mainWindow;
      win.setWindowLayoutFullScreen(true).catch((e: Error) => {
        hilog.error(0x0000, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(e) ?? '');
      });
      AvoidAreaStore.attach(win, screenDensity());
      LayoutAdapt.attach(win);
      // 主题状态栏/导航栏内容色（设置加载后；FeederUiBootstrap.init 已在 onCreate 链上先注册）
      AppBootstrap.settingsReady().then(() => {
        FeederUiBootstrap.attachWindow(win);
      });
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
      if (mainWindow !== null) {
        const loadedWindow: window.Window = mainWindow;
        try {
          const ui: UIContext = loadedWindow.getUIContext();
          ActivityLauncher.instance()?.setUIContext(ui);
          LayoutAdapt.resizeOnKeyboard(ui);
        } catch (e) {
          hilog.error(0x0000, 'testTag', 'getUIContext failed: %{public}s', JSON.stringify(e) ?? '');
        }
        AppBootstrap.settingsReady().then(() => {
          FeederUiBootstrap.onContentLoaded(loadedWindow);
        });
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    AvoidAreaStore.detach();
    LayoutAdapt.detach();
    ThemeController.detachWindow();
  }

  onForeground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
