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

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { Runtime } from '../core/Runtime';
import { weatherService } from '../core/WeatherService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private stageGeneration: number = 0;
  private initialization: Promise<void> = Promise.resolve();
  private readonly avoidAreaListener: (event: window.AvoidAreaOptions) => void =
    (event: window.AvoidAreaOptions): void => {
      if (event.type === window.AvoidAreaType.TYPE_SYSTEM ||
        event.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        this.updateWindowInsets();
      }
    };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Runtime.init(this.context);
    // Explicit singleton construction replaces Hilt. init(false) performs the
    // synchronous cache/settings/unit initialization before the first page;
    // the location/permission phase remains separate from application setup.
    this.initialization = weatherService.init(false).catch((error: Error): void => {
      hilog.error(DOMAIN, 'testTag', 'Failed to initialize view model: %{public}s', error.message);
    });
    AppStorage.setOrCreate<number>('statusBarHeight', 0);
    AppStorage.setOrCreate<number>('navigationBarHeight', 0);
    // hmig:smokeRoute 波级冒烟直达透传（smoke.mjs 经 aa start --ps smokeRoute 传入；正常启动无此参数）——冻结件，勿删
    const hmigSmokeRoute: Object | undefined = want.parameters?.['smokeRoute'];
    if (typeof hmigSmokeRoute === 'string' && hmigSmokeRoute.length > 0) {
      AppStorage.setOrCreate('smokeRoute', hmigSmokeRoute);
    }
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    this.releaseWindow();
    if (Runtime.context === this.context) {
      Runtime.context = null;
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.releaseWindow();
    const generation = this.stageGeneration;
    const mainWindow = windowStage.getMainWindowSync();
    this.mainWindow = mainWindow;
    mainWindow.on('avoidAreaChange', this.avoidAreaListener);
    Promise.all([this.initialization, mainWindow.setWindowLayoutFullScreen(true)]).then((): void => {
      if (generation !== this.stageGeneration || this.mainWindow !== mainWindow) {
        return;
      }
      this.updateWindowInsets();
    // Preserve the frozen loadContent route/callback, but only invoke it after
    // full-screen layout and the initial real window insets are available.
    windowStage.loadContent('pages/Index', (err) => {
      if (generation !== this.stageGeneration || this.mainWindow !== mainWindow) {
        return;
      }
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.updateWindowInsets();
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
    }).catch((err: Error): void => {
      hilog.error(DOMAIN, 'testTag', 'Failed to configure full-screen window: %{public}s', err.message);
    });
  }

  onWindowStageDestroy(): void {
    this.releaseWindow();
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

  private updateWindowInsets(): void {
    const mainWindow = this.mainWindow;
    if (mainWindow === null) {
      return;
    }
    const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navigationArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    // Display density is available before loadContent, unlike UIContext.
    const density = display.getDisplayByIdSync(mainWindow.getWindowProperties().displayId).densityPixels;
    AppStorage.setOrCreate<number>('statusBarHeight', systemArea.topRect.height / density);
    AppStorage.setOrCreate<number>('navigationBarHeight',
      Math.max(systemArea.bottomRect.height, navigationArea.bottomRect.height) / density);
  }

  private releaseWindow(): void {
    this.stageGeneration += 1;
    const mainWindow = this.mainWindow;
    this.mainWindow = null;
    if (mainWindow !== null) {
      mainWindow.off('avoidAreaChange', this.avoidAreaListener);
    }
  }
}
