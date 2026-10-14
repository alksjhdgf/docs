/**
 * AddFeedPage —— 源 NavigationDestinations.kt AddFeedDestination（`add/feed/{feedUrl}?feedTitle=&feedImage=`）
 * + CreateFeedScreen（EditFeedScreen.kt:92）+ CreateFeedScreenViewModel。
 *  - 参数 AddFeedParam{ feedUrl, feedTitle, feedImage }；缺参显示空态（提示 + 返回），不抛不自动 pop。
 *  - 返回 / Cancel：popBackStack（不保存，EF-A23/A34）。
 *  - OK（EF-A35/A36）：保存并请求同步 → 普通流程跳 Feed 页显示新订阅源并清空返回栈；
 *    分享流程（栈中有 AddFeedFromShare，源 AddFeedFromShareActivity 内 onOk = finish()）→ 结束分享流程：
 *    弹出分享流程全部页面（AddFeedFromShare 及其上），若分享页位于栈底则结束 Ability。
 */
import { common } from '@kit.AbilityKit';
import { AppRouter, Routes } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { AddFeedParam } from '../core/app/RouteParams';
import { LayoutAdapt, WindowMetrics } from '../core/platform/LayoutAdapt';
import { FeederTheme } from '../ui/common/Theme';
import { CreateFeedViewModel, EditFeedViewModel } from '../features/editfeed/EditFeedViewModel';
import { EditFeedScreen, EditFeedScreenPhase } from '../features/editfeed/EditFeedScreen';

const LOG_TAG: string = 'AddFeedPage';

@Builder
export function AddFeedPageBuilder() {
  AddFeedPage()
}

@ComponentV2
struct AddFeedPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local vm: EditFeedViewModel = new EditFeedViewModel();
  @Local phase: EditFeedScreenPhase = EditFeedScreenPhase.LOADING;
  private createVm: CreateFeedViewModel | null = null;

  aboutToDisappear(): void {
    const vm: CreateFeedViewModel | null = this.createVm;
    this.createVm = null;
    if (vm !== null) {
      vm.dispose();
    }
  }

  private onRouteParam(p: AddFeedParam): void {
    if (this.createVm !== null) {
      return;
    }
    const vm: CreateFeedViewModel = new CreateFeedViewModel(p);
    this.createVm = vm;
    this.vm = vm;
    this.phase = EditFeedScreenPhase.READY;
  }

  private onNavigateUp(): void {
    AppRouter.back();
  }

  private onOk(): void {
    const vm: CreateFeedViewModel | null = this.createVm;
    if (vm === null) {
      return;
    }
    vm.saveAndRequestSync((feedId: number) => {
      if (AppRouter.stack.getAllPathName().indexOf(Routes.ADD_FEED_FROM_SHARE) >= 0) {
        this.finishShareFlow();
      } else {
        DeepLinkRouter.onFeedSaved(feedId);
      }
    });
  }

  /** 源 AddFeedFromShareActivity.finish()：结束分享流程，回到分享前的页面 */
  private finishShareFlow(): void {
    const names: string[] = AppRouter.stack.getAllPathName();
    const idx: number = names.indexOf(Routes.ADD_FEED_FROM_SHARE);
    if (idx > 0) {
      AppRouter.stack.popToIndex(idx - 1, false);
      return;
    }
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      ctx.terminateSelf().catch((e: Error) => {
        console.error(`${LOG_TAG}: terminateSelf failed: ${e?.message}`);
      });
    } catch (e) {
      console.error(`${LOG_TAG}: finish share flow failed: ${JSON.stringify(e)}`);
      AppRouter.back();
    }
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
      if (p instanceof AddFeedParam) {
        this.onRouteParam(p as AddFeedParam);
      } else {
        console.warn(`${LOG_TAG}: missing AddFeedParam`);
        this.phase = EditFeedScreenPhase.MISSING;
      }
    })
  }
}
