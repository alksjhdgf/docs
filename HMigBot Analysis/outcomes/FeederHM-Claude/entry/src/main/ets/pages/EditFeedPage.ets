/**
 * EditFeedPage —— 源 NavigationDestinations.kt EditFeedDestination（`edit/feed/{feedId}`）
 * + EditFeedScreen（EditFeedScreen.kt:121）+ EditFeedScreenViewModel。
 *  - 参数 EditFeedParam{ feedId }；缺参或订阅源不存在显示空态（提示 + 返回），不抛不自动 pop。
 *  - 进入按 feedId 读库预填（EF-A41），已编辑未保存字段经 SavedStateRegistry 在进程重建后保留（EF-A42）。
 *  - 返回 / Cancel：popBackStack（不保存，EF-A39）；OK：保存（无改动不写库，EF-A43）后跳 Feed 页显示该订阅源并清空返回栈（EF-A44）。
 */
import { AppRouter } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { EditFeedParam } from '../core/app/RouteParams';
import { LayoutAdapt, WindowMetrics } from '../core/platform/LayoutAdapt';
import { FeederTheme } from '../ui/common/Theme';
import { EditFeedScreenViewModel, EditFeedViewModel, isValidFeedId } from '../features/editfeed/EditFeedViewModel';
import { EditFeedScreen, EditFeedScreenPhase } from '../features/editfeed/EditFeedScreen';

const LOG_TAG: string = 'EditFeedPage';

@Builder
export function EditFeedPageBuilder() {
  EditFeedPage()
}

@ComponentV2
struct EditFeedPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local vm: EditFeedViewModel = new EditFeedViewModel();
  @Local phase: EditFeedScreenPhase = EditFeedScreenPhase.LOADING;
  private editVm: EditFeedScreenViewModel | null = null;

  aboutToDisappear(): void {
    const vm: EditFeedScreenViewModel | null = this.editVm;
    this.editVm = null;
    if (vm !== null) {
      vm.dispose();
    }
  }

  private onRouteParam(p: EditFeedParam): void {
    if (this.editVm !== null) {
      return;
    }
    if (!isValidFeedId(p.feedId)) {
      this.phase = EditFeedScreenPhase.MISSING;
      return;
    }
    const vm: EditFeedScreenViewModel = new EditFeedScreenViewModel(p.feedId);
    this.editVm = vm;
    this.vm = vm;
    vm.load().then(() => {
      this.phase = vm.missing ? EditFeedScreenPhase.MISSING : EditFeedScreenPhase.READY;
    });
  }

  private onNavigateUp(): void {
    AppRouter.back();
  }

  private onOk(): void {
    const vm: EditFeedScreenViewModel | null = this.editVm;
    if (vm === null) {
      return;
    }
    vm.saveAndRequestSync((feedId: number) => {
      DeepLinkRouter.onFeedSaved(feedId);
    });
  }

  build() {
    NavDestination() {
      EditFeedScreen({
        vm: this.vm,
        phase: this.phase,
        screenType: this.metrics.screenType,
        topInset: this.avoid.top,
        bottomInset: this.avoid.bottom,
        onNavigateUp: () => {
          this.onNavigateUp();
        },
        onOk: () => {
          this.onOk();
        },
        onCancel: () => {
          this.onNavigateUp();
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object = ctx.pathInfo.param as Object;
      if (p instanceof EditFeedParam) {
        this.onRouteParam(p as EditFeedParam);
      } else {
        console.warn(`${LOG_TAG}: missing EditFeedParam`);
        this.phase = EditFeedScreenPhase.MISSING;
      }
    })
  }
}
