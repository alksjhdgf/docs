/**
 * SettingsPage —— 源 ui/compose/settings/Settings.kt SettingsScreen（:131）+ navigation/NavigationDestinations.kt:314-348。
 *  - Scaffold(contentWindowInsets = statusBars) + SensibleTopAppBar(`Settings`, ArrowBack `Go back`) → 自绘顶栏，
 *    顶部避让状态栏（AvoidArea.top，ST-A01）；滚动后顶栏换 scrolled 容器色。
 *  - 返回：popBackStack() 失败（栈中无上一页）→ 导航到 Feed（ST-A02）。
 *  - `Device sync` → SyncScreen(syncCode = "", secretKey = "")（ST-A23）；`Text settings` → TextSettings（ST-A16）。
 *  - 内容：features/settings/SettingsSections.SettingsList（单列纵向滚动，ST-A03）。
 *  - 回到页面（onShown / 前台 resumeTime）刷新电池优化状态与通知授权状态（ST-A22/A09）。
 */
import { AppRouter, Routes } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { FeedParam, SyncParam, TextSettingsRouteParam } from '../core/app/RouteParams';
import { smallestScreenWidthVp } from '../core/platform/LinkOpener';
import { FeederTheme } from '../ui/common/Theme';
import { M3Type, textStyle } from '../ui/common/Typography';
import { SettingsViewModel } from '../features/settings/SettingsViewModel';
import { SettingsList } from '../features/settings/SettingsSections';
import {
  openBatteryOptimizationSettings, sendBugReport, SettingsDialogsController
} from '../features/settings/SettingsActions';

const LOG_TAG: string = 'FEEDER_SETTINGS_PAGE';

@Builder
export function SettingsPageBuilder() {
  SettingsPage()
}

@ComponentV2
struct SettingsPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local vm: SettingsViewModel = new SettingsViewModel();
  @Local dialogs: SettingsDialogsController = new SettingsDialogsController();
  /** 源 LocalConfiguration.smallestScreenWidthDp >= 600 */
  @Local notCompactScreen: boolean = false;
  @Local scrolled: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.notCompactScreen = smallestScreenWidthVp() >= 600;
    this.vm.start();
    this.dialogs.refreshNotificationPermission();
  }

  aboutToDisappear(): void {
    this.dialogs.closeAll();
    this.vm.stop();
  }

  /** 源 onNavigateUp：popBackStack() 失败 → FeedDestination.navigate */
  private navigateUp(): void {
    if (AppRouter.stack.size() > 1) {
      AppRouter.back();
    } else {
      AppRouter.replace(Routes.FEED, new FeedParam());
    }
  }

  private handleShown(): void {
    this.vm.refreshBatteryOptimization();
    this.dialogs.refreshNotificationPermission();
  }

  build() {
    NavDestination() {
      Column() {
        this.topBarBuilder()
        Scroll(this.scroller) {
          SettingsList({
            vm: this.vm,
            dialogs: this.dialogs,
            notCompactScreen: this.notCompactScreen,
            bottomInset: this.avoid.bottom,
            onOpenSyncSettings: () => {
              AppRouter.push(Routes.SYNC_SCREEN, SyncParam.of('', ''));
            },
            onTextSettings: () => {
              AppRouter.push(Routes.TEXT_SETTINGS, new TextSettingsRouteParam());
            },
            onBatteryOptimization: () => {
              openBatteryOptimizationSettings(this.getUIContext()).catch((e: Error) => {
                console.error(`${LOG_TAG}: battery settings failed ${e?.message}`);
              });
            },
            onSendFeedback: () => {
              sendBugReport(this.getUIContext()).catch((e: Error) => {
                console.error(`${LOG_TAG}: bug report failed ${e?.message}`);
              });
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
        .onDidScroll(() => {
          this.scrolled = this.scroller.currentOffset().yOffset > 0;
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)
      .backgroundColor(FeederTheme.colors.background)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onShown(() => {
      this.handleShown();
    })
    .onBackPressed((): boolean => {
      this.navigateUp();
      return true;
    })
  }

  /** 源 SensibleTopAppBar(title = title_activity_settings, navigationIcon = ArrowBack / go_back) */
  @Builder
  topBarBuilder() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurface])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.go_back'))
      .onClick(() => {
        this.navigateUp();
      })

      Text($r('app.string.title_activity_settings'))
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height(64 + this.avoid.top)
    .padding({ top: this.avoid.top, left: 4, right: 4 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.scrolled ? FeederTheme.scrolledBarColor : FeederTheme.colors.background)
  }
}
