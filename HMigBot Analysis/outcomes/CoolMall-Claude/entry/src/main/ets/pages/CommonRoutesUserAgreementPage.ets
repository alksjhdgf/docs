/**
 * CommonRoutesUserAgreementPage — 用户协议 (source: feature/common/view/UserAgreementScreen.kt + UserAgreementViewModel.kt).
 * AppScaffold(title 用户协议, background surface) + BaseNetWorkView:
 *  loading → DocumentLoadingSkeleton (min loading time), error → EmptyNetwork with retry, success → HTML in Web (JS off).
 */
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { UserAgreementViewModel } from '../feature/common/settings/UserAgreementViewModel';
import { DocumentLoadingSkeleton } from '../feature/common/settings/DocumentSkeleton';
import { HtmlDocumentView } from '../feature/common/settings/HtmlDocumentView';

@Builder
export function CommonRoutesUserAgreementPageBuilder() {
  CommonRoutesUserAgreementPage()
}

@ComponentV2
struct CommonRoutesUserAgreementPage {
  @Local vm: UserAgreementViewModel = new UserAgreementViewModel();

  aboutToAppear(): void {
    this.vm.executeRequest();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  @Builder
  loadingBuilder() {
    DocumentLoadingSkeleton()
  }

  @Builder
  contentBuilder() {
    HtmlDocumentView({ html: this.vm.data ?? '' })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      useCustomLoading: true,
      customLoading: (): void => {
        this.loadingBuilder()
      },
      content: (): void => {
        this.contentBuilder()
      },
      onRetry: () => {
        this.vm.retryRequest();
      }
    })
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.user_agreement_title'),
        bgColor: $r('app.color.surface'),
        onBack: () => {
          AppNavigator.back();
        },
        content: (): void => {
          this.pageContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
