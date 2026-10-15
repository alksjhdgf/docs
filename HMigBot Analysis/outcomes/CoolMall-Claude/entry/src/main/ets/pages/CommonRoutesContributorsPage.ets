/**
 * CommonRoutesContributorsPage — contributors list (source: feature/common/view/ContributorsScreen.kt
 * ContributorsRoute / ContributorsScreen / ContributorsContentView, viewmodel/ContributorsViewModel.kt).
 *
 * AppScaffold(`贡献者`, back → previous page) {
 *   BaseNetWorkListView → NetWorkStateView: loading → PageLoading, empty → EmptyData, error → EmptyNetwork + retry
 *   success → RefreshList (pull to refresh, load more near the end) of UserContributorCard        COM-A26
 * }
 * Card tap: websiteUrl non-blank → Web(url, title = nickName); otherwise nothing                   COM-A27
 */
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { UserContributor } from '../core/model/Market';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { RefreshList } from '../core/ui/base/RefreshList';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { CommonNavigator } from '../feature/common/about/CommonNavigator';
import { ContributorsViewModel } from '../feature/common/about/ContributorsViewModel';
import { UserContributorCard } from '../feature/common/about/UserContributorCard';

@Builder
export function CommonRoutesContributorsPageBuilder() {
  CommonRoutesContributorsPage()
}

@ComponentV2
struct CommonRoutesContributorsPage {
  @Local vm: ContributorsViewModel = new ContributorsViewModel();

  private listScroller: Scroller = new Scroller();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  /** Source onClick: contributor.websiteUrl?.takeIf { it.isNotBlank() }?.let { toWeb(url, nickName) } */
  private onContributorClick(contributor: UserContributor): void {
    const url: string | null | undefined = contributor.websiteUrl;
    if (url !== null && url !== undefined && url.trim().length > 0) {
      CommonNavigator.toWeb(url, contributor.nickName ?? '');
    }
  }

  @Builder
  contributorItem(item: Object, index: number) {
    Column() {
      UserContributorCard({
        contributor: item as UserContributor,
        onCardClick: (c: UserContributor) => {
          this.onContributorClick(c);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  listContent() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      listScroller: this.listScroller,
      itemKey: (item: Object, index: number): string => {
        const c: UserContributor = item as UserContributor;
        return 'contributor_' + index + '_' + c.id + '_' + (c.nickName ?? '') + '_' + (c.avatarUrl ?? '') + '_' +
          (c.signature ?? '') + '_' + (c.tags?.join(',') ?? '') + '_' + (c.websiteUrl ?? '');
      },
      itemBuilder: (item: Object, index: number): void => {
        this.contributorItem(item, index)
      }
    })
  }

  @Builder
  pageContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      NetWorkStateView({
        uiState: this.vm.uiState,
        content: (): void => {
          this.listContent()
        },
        onRetry: () => {
          this.vm.retryRequest();
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.contributors_title'),
        content: (): void => {
          this.pageContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
