/**
 * MainRoutesMainPage — the main shell route (source: MainRoutes.Main → MainGraph.kt → MainRoute / MainScreen).
 * Content: MainShell (4-tab bottom navigation + horizontally swipeable pages; Home tab = HomeView).
 * No title bar (source has none). Back on the root page sends the app to the background like the Android
 * launcher activity, instead of popping the last NavDestination and leaving an empty Navigation.
 */
import { common } from '@kit.AbilityKit';
import { AppRouter } from '../common/Router';
import { MainShell } from '../feature/main/MainShell';
import { LogUtils } from '../core/util/LogUtils';

const TAG: string = 'MainRoutesMainPage';

@Builder
export function MainRoutesMainPageBuilder() {
  MainRoutesMainPage()
}

@ComponentV2
struct MainRoutesMainPage {
  private moveToBackground(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    (ctx as common.UIAbilityContext).moveAbilityToBackground().catch((e: Error) => {
      LogUtils.eTag(TAG, 'moveAbilityToBackground failed: ' + e?.message);
    });
  }

  build() {
    NavDestination() {
      Column() {
        MainShell()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (AppRouter.stack.size() <= 1) {
        this.moveToBackground();
        return true;
      }
      return false;
    })
  }
}
