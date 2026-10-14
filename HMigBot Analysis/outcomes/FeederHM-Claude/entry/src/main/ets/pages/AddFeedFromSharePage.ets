/**
 * AddFeedFromSharePage —— 源 ui/AddFeedFromShareActivity.kt（仅经分享/打开链接 Want 进入：DeepLinkRouter →
 * AddFeedFromShareParam{ initialFeedUrl = (intent.dataString ?: EXTRA_TEXT)?.trim() }）。
 *
 * 源为独立 Activity 内的私有 NavHost（start="search" → "add/feed/…"，fade 过渡），本页同构为页内两屏：
 *  - search：SearchFeedScreen，输入框预填 initialFeedUrl（去首尾空白，APP-A42）；顶部避让状态栏（APP-A40）；
 *    向上导航 → 打开主界面（Feed）并关闭分享流程（源 onNavigateUpFromIntentActivities，APP-A46）；
 *    点选结果 → add 屏，带入结果的 url/title/feedImage（源 AddFeedDestination.navigate，APP-A43）。
 *    搜索屏保持挂载（≙ NavHost 返回栈保留 search 条目及其 ViewModel），从 add 返回时输入与结果不丢。
 *  - add：CreateFeedScreen（EditFeedScreen + CreateFeedViewModel）；返回/Cancel → popBackStack 回 search（APP-A44）；
 *    保存成功 → finish()：关闭整个分享流程并把应用退回后台、回到分享来源应用，不跳主界面（APP-A45）。
 *  - 系统返回：add → 回 search；search（NavHost 栈底）→ 源 Activity 默认 finish()，同上关闭分享流程。
 */
import { common } from '@kit.AbilityKit';
import { AppRouter, Routes } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { AddFeedFromShareParam, AddFeedParam } from '../core/app/RouteParams';
import { ID_UNSET } from '../core/model/Enums';
import { LayoutAdapt, WindowMetrics } from '../core/platform/LayoutAdapt';
import { FeederTheme } from '../ui/common/Theme';
import { SearchFeedViewModel } from '../features/searchfeed/SearchFeedViewModel';
import { SearchResult } from '../features/searchfeed/SearchResult';
import { SearchFeedScreen, resolveAddFeedTitle } from '../features/searchfeed/SearchFeedScreen';
import { CreateFeedViewModel, EditFeedViewModel } from '../features/editfeed/EditFeedViewModel';
import { EditFeedScreen, EditFeedScreenPhase } from '../features/editfeed/EditFeedScreen';

const LOG_TAG: string = 'AddFeedFromShare';

/** 源 composable 过渡 fadeIn()/fadeOut() 的默认时长 */
const FADE_MS: number = 300;

@Builder
export function AddFeedFromSharePageBuilder() {
  AddFeedFromSharePage()
}

/** 页内两屏（源私有 NavHost 的两个 destination） */
enum ShareFlowScreen {
  SEARCH = 0,
  ADD_FEED = 1,
}

@ComponentV2
struct AddFeedFromSharePage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local searchVm: SearchFeedViewModel = new SearchFeedViewModel();
  @Local barTitle: string = '';
  @Local screen: ShareFlowScreen = ShareFlowScreen.SEARCH;
  @Local addVm: EditFeedViewModel = new EditFeedViewModel();
  private createVm: CreateFeedViewModel | null = null;
  private initialized: boolean = false;
  private finishing: boolean = false;

  aboutToAppear(): void {
    this.barTitle = resolveAddFeedTitle(this.getUIContext().getHostContext());
  }

  aboutToDisappear(): void {
    this.disposeCreateVm();
    this.searchVm.dispose();
  }

  private disposeCreateVm(): void {
    const vm: CreateFeedViewModel | null = this.createVm;
    this.createVm = null;
    if (vm !== null) {
      vm.dispose();
    }
  }

  private switchScreen(next: ShareFlowScreen): void {
    try {
      this.getUIContext().animateTo({ duration: FADE_MS }, () => {
        this.screen = next;
      });
    } catch (e) {
      console.warn(`${LOG_TAG}: animateTo failed: ${JSON.stringify(e)}`);
      this.screen = next;
    }
  }

  /** 源 AddFeedDestination.navigate(navController, feedUrl = it.url, feedTitle = it.title, feedImage = it.feedImage) */
  private openAddFeed(r: SearchResult): void {
    if (this.finishing) {
      return;
    }
    this.disposeCreateVm();
    const vm: CreateFeedViewModel = new CreateFeedViewModel(AddFeedParam.of(r.url, r.title, r.feedImage));
    this.createVm = vm;
    this.addVm = vm;
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (e) {
      console.warn(`${LOG_TAG}: clearFocus failed: ${JSON.stringify(e)}`);
    }
    this.switchScreen(ShareFlowScreen.ADD_FEED);
  }

  /** 源 CreateFeedScreen onNavigateUp = navController.popBackStack() */
  private popToSearch(): void {
    this.switchScreen(ShareFlowScreen.SEARCH);
    this.disposeCreateVm();
  }

  /** 源 CreateFeedScreen onOk → saveAndRequestSync { finish() } */
  private onSave(): void {
    const vm: CreateFeedViewModel | null = this.createVm;
    if (vm === null || this.finishing) {
      return;
    }
    vm.saveAndRequestSync((feedId: number) => {
      console.debug(`${LOG_TAG}: saved feed ${feedId}`);
      this.finishActivity();
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: save failed: ${e?.message}`);
    });
  }

  /** 源 onNavigateUpFromIntentActivities()：startActivity(MainActivity) + finish() */
  private navigateUpToMain(): void {
    if (this.finishing) {
      return;
    }
    this.finishing = true;
    DeepLinkRouter.navigateToFeed(ID_UNSET, '');
  }

  /**
   * 源 Activity.finish()：分享流程是来源应用任务内的独立 Activity，finish 后回到来源应用。
   * 鸿蒙：弹出本页（及其上页面），并把 Ability 退到后台（回到发起分享的应用），不导航到主界面。
   */
  private finishActivity(): void {
    if (this.finishing) {
      return;
    }
    this.finishing = true;
    const names: string[] = AppRouter.stack.getAllPathName();
    const idx: number = names.lastIndexOf(Routes.ADD_FEED_FROM_SHARE);
    if (idx > 0) {
      AppRouter.stack.popToIndex(idx - 1, false);
    } else if (idx === 0) {
      // 分享页位于栈底（无主界面可回）：以 Feed 作为后台栈底，避免留下空 Navigation
      DeepLinkRouter.navigateToFeed(ID_UNSET, '');
    }
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        (ctx as common.UIAbilityContext).moveAbilityToBackground().catch((e: Error) => {
          console.warn(`${LOG_TAG}: moveAbilityToBackground failed: ${e?.message}`);
        });
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: moveAbilityToBackground threw: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      Stack() {
        // "search"：保持挂载（≙ 返回栈中的 search 条目），add 屏打开时淡出并禁用交互
        Column() {
          SearchFeedScreen({
            vm: this.searchVm,
            topInset: this.avoid.top,
            bottomInset: this.avoid.bottom,
            barTitle: this.barTitle,
            onNavigateUp: () => {
              this.navigateUpToMain();
            },
            onResultClick: (r: SearchResult) => {
              this.openAddFeed(r);
            }
          })
        }
        .width('100%')
        .height('100%')
        .opacity(this.screen === ShareFlowScreen.SEARCH ? 1 : 0)
        .enabled(this.screen === ShareFlowScreen.SEARCH)
        .accessibilityLevel(this.screen === ShareFlowScreen.SEARCH ? 'auto' : 'no-hide-descendants')

        if (this.screen === ShareFlowScreen.ADD_FEED) {
          Column() {
            EditFeedScreen({
              vm: this.addVm,
              phase: EditFeedScreenPhase.READY,
              screenType: this.metrics.screenType,
              topInset: this.avoid.top,
              bottomInset: this.avoid.bottom,
              onNavigateUp: () => {
                this.popToSearch();
              },
              onOk: () => {
                this.onSave();
              },
              onCancel: () => {
                this.popToSearch();
              }
            })
          }
          .width('100%')
          .height('100%')
          .backgroundColor(FeederTheme.colors.background)
          .transition(TransitionEffect.OPACITY)
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      if (this.initialized) {
        return;
      }
      this.initialized = true;
      const p: Object = ctx.pathInfo.param as Object;
      let initialFeedUrl: string = '';
      if (p instanceof AddFeedFromShareParam) {
        initialFeedUrl = (p as AddFeedFromShareParam).initialFeedUrl.trim();
      } else {
        console.warn(`${LOG_TAG}: no AddFeedFromShareParam, starting with empty search`);
      }
      this.searchVm.initialize(initialFeedUrl);
    })
    .onBackPressed(() => {
      if (this.screen === ShareFlowScreen.ADD_FEED) {
        this.popToSearch();
      } else {
        this.finishActivity();
      }
      return true;
    })
  }
}
