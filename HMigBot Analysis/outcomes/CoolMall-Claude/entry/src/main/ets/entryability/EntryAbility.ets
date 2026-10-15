/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * EntryAbility — source: app/.../Application.kt (onCreate init chain, onConfigurationChanged) +
 * app/.../MainActivity.kt (enableEdgeToEdge, theme-driven status bar, QQ onActivityResult).
 *
 * onCreate (LAUNCH-A18 / INIT-A01), in source order:
 *   1. Toast (source initToast: Toaster.init(app, isDarkTheme ? white : black style)) — the default style is
 *      chosen here from the SYSTEM color mode, before anything else; the UIContext that HarmonyOS toasts need
 *      only exists once the window content is created, so it is attached in onWindowStageCreate (attachToast).
 *   2. Log (LogUtils.init, hilog) → 3. KvStore.init (MMKV) → AppDatabase.init (Room, async; DAOs await getStore())
 *   → ThemeManager.init → 4. QQ SDK (no HarmonyOS equivalent, degraded) → AppState.initialize() (after KV).
 * onWindowStageCreate: edge-to-edge (setWindowLayoutFullScreen) + AppStorageV2 AvoidArea{top,bottom} (vp)
 *   + avoidAreaChange refresh + status bar content color following the effective dark/light theme.
 */
import { AbilityConstant, bundleManager, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, UIUtils, window } from '@kit.ArkUI';
import { KvStore } from '../core/storage/KvStore';
import { AppDatabase } from '../core/storage/AppDatabase';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { ThemePreference } from '../core/designsystem/ThemePreference';
import { AppState } from '../core/data/state/AppState';
import { LogUtils } from '../core/util/LogUtils';
import { ToastUtils } from '../core/util/ToastUtils';
import { AvoidArea } from '../core/ui/base/AvoidArea';

const DOMAIN = 0x0000;

/** Source: core/common/config/AppConfig.kt QQ_APP_ID (kept for reference; the QQ SDK is not available on HarmonyOS). */
const QQ_APP_ID: string = '102756675';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private avoidAreaListener: ((options: window.AvoidAreaOptions) => void) | null = null;
  private themeMonitorAdded: boolean = false;
  /** System dark mode as last reported (drives the default toast style, LAUNCH-A32). */
  private systemDarkForToast: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // hmig:smokeRoute 波级冒烟直达透传（smoke.mjs 经 aa start --ps smokeRoute 传入；正常启动无此参数）——冻结件，勿删
    const hmigSmokeRoute: Object | undefined = want.parameters?.['smokeRoute'];
    if (typeof hmigSmokeRoute === 'string' && hmigSmokeRoute.length > 0) {
      AppStorage.setOrCreate('smokeRoute', hmigSmokeRoute);
    }
    // 1. Toast (source initToast, first item): pick the default style from the system theme —
    //    dark system → white toast, light system → black toast. Read before ThemeManager may force an app mode.
    this.initToastStyle();
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 2. Log (source initLog: LogUtils.init(this, BuildConfig.DEBUG)) — debug flag from the bundle's appInfo.
    LogUtils.init(this.isDebugBuild());
    // 3. Local KV storage (source initMMKV)
    try {
      KvStore.init(this.context);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'KvStore.init failed. Cause: %{public}s', JSON.stringify(err));
    }
    //    Room database equivalent (Hilt-provided in the source). Async: DAOs await AppDatabase.getStore(),
    //    so any query issued before the open completes waits for it.
    AppDatabase.init(this.context).catch((err: Object) => {
      hilog.error(DOMAIN, 'testTag', 'AppDatabase.init failed. Cause: %{public}s', JSON.stringify(err));
    });
    //    Theme: reads persisted mode/color and applies the app color mode (overrides the NOT_SET above).
    ThemeManager.instance.init(this.context);
    // 4. QQ SDK (source initQQ: QQLoginManager.init(this, AppConfig.QQ_APP_ID)) — no HarmonyOS equivalent.
    //    The MainActivity.onActivityResult → QQLoginManager result bridge (LAUNCH-A34) is degraded with it:
    //    there is no Tencent SDK result to forward, so the login flow never receives a QQ callback.
    LogUtils.wTag('EntryAbility', 'QQ SDK unavailable on HarmonyOS; QQ login degraded (AppId ' + QQ_APP_ID + ')');
    //    Global login state — only after KV storage is ready (source: appState.initialize()).
    AppState.instance.initialize();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onConfigurationUpdate(config: Configuration): void {
    ThemeManager.instance.updateSystemColorMode(config.colorMode);
    // Source Application.onConfigurationChanged: toast style follows the SYSTEM dark mode (LAUNCH-A32).
    // The source reads the system uiMode, which the in-app theme override (Compose) never changes. Here an
    // app-forced mode (ThemeManager.applyColorMode → setColorMode) rewrites config.colorMode to the forced
    // value, so config.colorMode is only the system mode while ThemeManager.mode is FOLLOW_SYSTEM. In that
    // case use it (ThemeManager.updateSystemColorMode above has already recorded it); otherwise keep the
    // last known system value (ThemeManager.systemDark), never the forced app value.
    if (ThemeManager.instance.mode === ThemePreference.FOLLOW_SYSTEM) {
      if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ||
        config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        this.applyToastStyle(config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      }
    } else if (ThemeManager.instance.systemDark !== this.systemDarkForToast) {
      this.applyToastStyle(ThemeManager.instance.systemDark);
    }
    this.applyStatusBarColor();
  }

  /** Source initToast style choice: read the system color mode at process start (no app mode applied yet). */
  private initToastStyle(): void {
    let dark: boolean = false;
    if (ThemeManager.instance.mode !== ThemePreference.FOLLOW_SYSTEM) {
      // Ability re-created inside a live process whose app color mode is still forced: config.colorMode is
      // the forced value, so use the system value ThemeManager last recorded instead.
      this.applyToastStyle(ThemeManager.instance.systemDark);
      return;
    }
    try {
      dark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (err) {
      dark = false;
    }
    this.applyToastStyle(dark);
  }

  /** Source: isDarkTheme → Toaster.setStyle(WhiteToastStyle) else BlackToastStyle. */
  private applyToastStyle(systemDark: boolean): void {
    this.systemDarkForToast = systemDark;
    if (systemDark) {
      ToastUtils.setWhiteStyle();
    } else {
      ToastUtils.setBlackStyle();
    }
  }

  /** Status-bar text: light text on dark theme, dark text on light theme. */
  private applyStatusBarColor(): void {
    if (this.mainWindow === null) {
      return;
    }
    const contentColor: string = ThemeManager.instance.isDark ? '#FFFFFF' : '#000000';
    try {
      this.mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'setWindowSystemBarProperties failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'setWindowSystemBarProperties threw: %{public}s', JSON.stringify(err));
    }
  }

  /** Re-apply the status bar color whenever the effective theme changes (Settings mode switch / system switch). */
  private watchThemeChanges(): void {
    if (this.themeMonitorAdded) {
      return;
    }
    try {
      UIUtils.addMonitor(ThemeManager.instance, ['mode', 'systemDark'], (): void => {
        this.applyStatusBarColor();
      });
      this.themeMonitorAdded = true;
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'addMonitor(ThemeManager) failed: %{public}s', JSON.stringify(err));
    }
  }

  private isDebugBuild(): boolean {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      return info.appInfo.debug;
    } catch (err) {
      return false;
    }
  }

  /** px → vp using the default display density (usable before loadContent, unlike UIContext.px2vp). */
  private pxToVp(px: number): number {
    let density: number = 1;
    try {
      density = display.getDefaultDisplaySync().densityPixels;
    } catch (err) {
      density = 1;
    }
    if (density <= 0) {
      density = 1;
    }
    return Math.round((px / density) * 100) / 100;
  }

  /** Reads the status bar / navigation indicator insets into AppStorageV2 AvoidArea (LAUNCH-A23). */
  private setupEdgeToEdge(win: window.Window): void {
    win.setWindowLayoutFullScreen(true).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
    });
    const area: AvoidArea = AvoidArea.get();
    try {
      const sys: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      area.top = this.pxToVp(sys.topRect.height);
      const nav: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      area.bottom = this.pxToVp(nav.bottomRect.height);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'getWindowAvoidArea failed: %{public}s', JSON.stringify(err));
    }
    const listener = (options: window.AvoidAreaOptions): void => {
      const current: AvoidArea = AvoidArea.get();
      if (options.type === window.AvoidAreaType.TYPE_SYSTEM) {
        current.top = this.pxToVp(options.area.topRect.height);
      } else if (options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        current.bottom = this.pxToVp(options.area.bottomRect.height);
      }
    };
    try {
      win.on('avoidAreaChange', listener);
      this.avoidAreaListener = listener;
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'on(avoidAreaChange) failed: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    try {
      this.mainWindow = windowStage.getMainWindowSync();
      this.setupEdgeToEdge(this.mainWindow);
      this.applyStatusBarColor();
      this.watchThemeChanges();
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'getMainWindowSync failed: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.attachToast();
    });
  }

  /**
   * Attaches the window UIContext to the toast utility (the style was already chosen in onCreate step 1).
   * Window.getUIContext() only becomes valid once loadContent has created the UI instance, which is the
   * earliest point a HarmonyOS toast can be displayed at all; this runs before the first Splash frame.
   */
  private attachToast(): void {
    if (this.mainWindow === null) {
      return;
    }
    try {
      ToastUtils.init(this.mainWindow.getUIContext(), this.systemDarkForToast);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'ToastUtils.init failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== null && this.avoidAreaListener !== null) {
      try {
        this.mainWindow.off('avoidAreaChange', this.avoidAreaListener);
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'off(avoidAreaChange) failed: %{public}s', JSON.stringify(err));
      }
    }
    this.avoidAreaListener = null;
    this.mainWindow = null;
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
