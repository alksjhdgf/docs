/**
 * SearchPage —— 源 ui/AddFeedFromShareActivity.kt 内 NavHost 的 "search" 目的地：与 SearchFeed 相同的搜索界面
 * （标题 `Add feed`），输入框预填共享文本（trim 后），合法时自动搜索（EF-A19..A21）。
 * 参数：SearchFeedParam{ feedUrl }；兼容 AddFeedFromShareParam{ initialFeedUrl }（分享壳直接透传）。
 * 点结果/推荐/`Add anyway` → 同一导航栈内 AddFeed(url, title, image)。
 * 顶栏返回：源 onNavigateUpFromIntentActivities（启动 MainActivity 并结束分享 Activity）→ AppRouter.goHome()。
 * 系统返回：源结束分享 Activity；本页为栈内唯一页时回主界面（避免空栈），否则正常出栈。
 */
import { AppRouter } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { AddFeedFromShareParam, SearchFeedParam } from '../core/app/RouteParams';
import { FeederTheme } from '../ui/common/Theme';
import { SearchFeedViewModel } from '../features/searchfeed/SearchFeedViewModel';
import { SearchResult } from '../features/searchfeed/SearchResult';
import { SearchFeedScreen, navigateToAddFeed, resolveAddFeedTitle } from '../features/searchfeed/SearchFeedScreen';

@Builder
export function SearchPageBuilder() {
  SearchPage()
}

/** 源 `(intent.dataString ?: EXTRA_TEXT)?.trim()` → initialFeedUrl（null → ""） */
export function initialUrlOfSearchParam(p: Object | undefined | null): string {
  if (p instanceof SearchFeedParam) {
    return (p as SearchFeedParam).feedUrl.trim();
  }
  if (p instanceof AddFeedFromShareParam) {
    return (p as AddFeedFromShareParam).initialFeedUrl.trim();
  }
  return '';
}

@ComponentV2
struct SearchPage {
  @Local vm: SearchFeedViewModel = new SearchFeedViewModel();
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local barTitle: string = '';

  aboutToAppear(): void {
    this.barTitle = resolveAddFeedTitle(this.getUIContext().getHostContext());
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  build() {
    NavDestination() {
      SearchFeedScreen({
        vm: this.vm,
        topInset: this.avoid.top,
        bottomInset: this.avoid.bottom,
        barTitle: this.barTitle,
        onNavigateUp: () => {
          AppRouter.goHome();
        },
        onResultClick: (r: SearchResult) => {
          navigateToAddFeed(r);
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      this.vm.initialize(initialUrlOfSearchParam(ctx.pathInfo.param as Object));
    })
    .onBackPressed((): boolean => {
      if (AppRouter.stack.size() <= 1) {
        AppRouter.goHome();
        return true;
      }
      return false;
    })
  }
}
