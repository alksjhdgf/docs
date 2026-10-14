/**
 * ImportPage —— 源 compose 路由 "import"（OpmlImportScreen）：选择/确认导入 OPML。
 *  - 带 ImportOpmlFileParam(uri) 进入：直接以该 uri 预览；无 uri：先弹 DocumentViewPicker 选文件（取消 → 返回）；
 *  - 预览订阅源列表（按标题排序）+ 摘要；OK 在应用级作用域完整导入（订阅源/设置/屏蔽词）并触发一次用户同步，
 *    随后打开主界面"全部订阅"（id=-10）；Cancel / 返回 → 关闭本页且不导入。
 */
import { AppRouter } from '../common/Router';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { ImportOpmlFileParam } from '../core/app/RouteParams';
import { ID_ALL_FEEDS } from '../core/model/Enums';
import { OpmlImportScreen } from '../features/import/OpmlImportScreen';
import { ImportViewModel } from '../features/import/ImportViewModel';

const LOG_TAG: string = 'FEEDER_OPMLIMPORT';

@Builder
export function ImportPageBuilder() {
  ImportPage()
}

@ComponentV2
struct ImportPage {
  @Local fileUri: string = '';
  @Local ready: boolean = false;

  private pickFile(): void {
    ImportViewModel.pickOpmlFile(this.getUIContext()).then((uri: string | null) => {
      if (uri === null) {
        AppRouter.back();
        return;
      }
      this.fileUri = uri;
      this.ready = true;
    }).catch((e: Error) => {
      // 选择器打不开：以"无 uri"进入预览 → 显示 `Failed to import OPML`
      console.error(LOG_TAG, `OPML picker failed: ${e?.message}`);
      this.fileUri = '';
      this.ready = true;
    });
  }

  build() {
    NavDestination() {
      if (this.ready) {
        OpmlImportScreen({
          uri: this.fileUri,
          onNavigateUp: () => {
            AppRouter.back();
          },
          onDismiss: () => {
            AppRouter.back();
          },
          onOk: () => {
            DeepLinkRouter.navigateToFeed(ID_ALL_FEEDS, '');
          }
        })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object;
      if (p instanceof ImportOpmlFileParam && (p as ImportOpmlFileParam).uri.length > 0) {
        this.fileUri = (p as ImportOpmlFileParam).uri;
        this.ready = true;
        return;
      }
      this.pickFile();
    })
  }
}
