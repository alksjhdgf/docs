/**
 * SearchFeedPage —— 源 ui/compose/searchfeed/SearchFeedScreen.kt（SearchFeedDestination：`search/feed?feedUrl={feedUrl}`）。
 * 参数 SearchFeedParam{ feedUrl }：预填输入框，合法则自动搜索（EF-A13）；缺省 → 空输入、不搜索。
 * 顶栏返回 → 上一页（EF-A02）；点结果/推荐/`Add anyway` → AddFeed(url, title, image)（EF-A08/A09/A12）。
 */
import { AppRouter } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { SearchFeedParam } from '../core/app/RouteParams';
import { FeederTheme } from '../ui/common/Theme';
import { SearchFeedViewModel } from '../features/searchfeed/SearchFeedViewModel';
import { SearchResult } from '../features/searchfeed/SearchResult';
import { SearchFeedScreen, navigateToAddFeed, resolveAddFeedTitle } from '../features/searchfeed/SearchFeedScreen';

@Builder
export function SearchFeedPageBuilder() {
  SearchFeedPage()
}

@ComponentV2
struct SearchFeedPage {
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
          AppRouter.back();
        },
        onResultClick: (r: SearchResult) => {
          navigateToAddFeed(r);
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object = ctx.pathInfo.param as Object;
      if (p instanceof SearchFeedParam) {
        this.vm.initialize((p as SearchFeedParam).feedUrl);
      } else {
        this.vm.initialize('');
      }
    })
  }
}
