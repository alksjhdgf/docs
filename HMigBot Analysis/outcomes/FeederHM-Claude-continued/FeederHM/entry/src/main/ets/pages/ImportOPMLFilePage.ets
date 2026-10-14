/**
 * ImportOPMLFilePage —— 源 ui/ImportOPMLFileActivity.kt（仅经"打开文件"Want 进入，DeepLinkRouter → ImportOpmlFileParam）：
 *  - 以 Want 携带的文件 URI 为导入源（APP-A32）；顶部避让状态栏（APP-A30，AvoidArea.top）；
 *  - OK → 打开主界面并定位"全部订阅"（`feed?id=-10`），同时关闭导入页（APP-A33）；
 *  - Dismiss（Cancel）→ 仅关闭导入页并回到调用方（源 finish()，不打开主界面，APP-A34）；
 *  - 向上导航 → 打开主界面并关闭导入页（源 onNavigateUpFromIntentActivities，APP-A35）。
 */
import { common } from '@kit.AbilityKit';
import { AppRouter } from '../common/Router';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { ImportOpmlFileParam } from '../core/app/RouteParams';
import { ID_ALL_FEEDS, ID_UNSET } from '../core/model/Enums';
import { OpmlImportScreen } from '../features/import/OpmlImportScreen';

const LOG_TAG: string = 'FEEDER_OPMLIMPORT';

@Builder
export function ImportOPMLFilePageBuilder() {
  ImportOPMLFilePage()
}

@ComponentV2
struct ImportOPMLFilePage {
  @Local fileUri: string = '';
  @Local ready: boolean = false;

  /** 源 finish()：关闭导入页并把应用退到后台（回到发起"打开文件"的应用） */
  private finishActivity(): void {
    AppRouter.back();
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        (ctx as common.UIAbilityContext).moveAbilityToBackground().catch((e: Error) => {
          console.warn(LOG_TAG, `moveAbilityToBackground failed: ${e?.message}`);
        });
      }
    } catch (e) {
      console.warn(LOG_TAG, `moveAbilityToBackground threw: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      if (this.ready) {
        OpmlImportScreen({
          uri: this.fileUri,
          onNavigateUp: () => {
            // 源 onNavigateUpFromIntentActivities：startActivity(MainActivity) + finish()
            DeepLinkRouter.navigateToFeed(ID_UNSET, '');
          },
          onDismiss: () => {
            this.finishActivity();
          },
          onOk: () => {
            // 源 ACTION_VIEW "$DEEP_LINK_BASE_URI/feed?id=$ID_ALL_FEEDS" → MainActivity + finish()
            DeepLinkRouter.navigateToFeed(ID_ALL_FEEDS, '');
          }
        })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object;
      if (p instanceof ImportOpmlFileParam) {
        this.fileUri = (p as ImportOpmlFileParam).uri;
      }
      console.debug(LOG_TAG, `Uri: ${this.fileUri}`);
      this.ready = true;
    })
    .onBackPressed(() => {
      // 系统返回 ≙ 源 Activity 默认 back = finish()
      this.finishActivity();
      return true;
    })
  }
}
