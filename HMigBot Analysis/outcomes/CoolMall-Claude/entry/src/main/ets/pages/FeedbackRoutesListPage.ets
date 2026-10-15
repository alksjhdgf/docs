/**
 * FeedbackRoutesListPage — feedback list (source: feature/feedback/view/FeedbackListScreen.kt +
 * viewmodel/FeedbackListViewModel.kt) — USER-A35~A38.
 *
 * AppScaffold(top bar `反馈列表`, back; the built-in top bar pads the status bar — USER-A35,
 *   bottomBar `我要反馈` only when the list state is neither loading nor error — USER-A38) {
 *   NetWorkStateView(loading → FeedbackListLoadingSkeleton | error → retry | empty → retry)
 *     success → RefreshList (pull to refresh + load more) { FeedbackCard(feedback, typeName) }
 * }
 * Submitting on the submit page returns RefreshResult(refresh = true) → the view model refreshes
 * (observeRefreshState) — USER-A36.
 */
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { Feedback } from '../core/model/Market';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { RefreshList } from '../core/ui/base/RefreshList';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { Routes } from '../common/Router';
import { FeedbackCard } from '../feature/feedback/FeedbackCard';
import { FeedbackListLoadingSkeleton } from '../feature/feedback/FeedbackListSkeleton';
import { FeedbackListViewModel } from '../feature/feedback/FeedbackListViewModel';

@Builder
export function FeedbackRoutesListPageBuilder() {
  FeedbackRoutesListPage()
}

@ComponentV2
struct FeedbackRoutesListPage {
  @Local vm: FeedbackListViewModel = new FeedbackListViewModel();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  /** Source: bottomBar only when uiState != Loading && uiState != Error */
  private showBottomBar(): boolean {
    return this.vm.uiState !== 'loading' && this.vm.uiState !== 'error';
  }

  @Builder
  feedbackItem(item: Object, index: number) {
    Column() {
      FeedbackCard({
        feedback: item as Feedback,
        typeName: this.vm.getFeedbackTypeName((item as Feedback).type)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  skeleton() {
    FeedbackListLoadingSkeleton()
  }

  @Builder
  listContent() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      itemKey: (item: Object, index: number): string => {
        const f: Feedback = item as Feedback;
        return 'feedback_' + index + '_' + f.id + '_' + f.type + '_' + f.status + '_' + (f.remark ?? '') + '_' +
          (f.updateTime ?? '') + '_' + this.vm.feedbackTypes.length;
      },
      itemBuilder: (item: Object, index: number): void => {
        this.feedbackItem(item, index)
      }
    })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      useCustomLoading: true,
      onRetry: () => {
        this.vm.retryRequest();
      },
      customLoading: (): void => {
        this.skeleton()
      },
      content: (): void => {
        this.listContent()
      }
    })
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.feedback_submit'),
      onBtnClick: () => {
        // source FeedbackNavigator.toSubmit
        AppNavigator.navigate(Routes.FEEDBACK_ROUTES_SUBMIT);
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.feedback_list'),
          hasBottomBar: this.showBottomBar(),
          bottomBar: (): void => {
            this.bottomBar()
          },
          content: (): void => {
            this.pageContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
  }
}
