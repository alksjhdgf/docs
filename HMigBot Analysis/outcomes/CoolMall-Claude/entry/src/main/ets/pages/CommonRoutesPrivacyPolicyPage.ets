/**
 * CommonRoutesPrivacyPolicyPage — 隐私政策 (source: feature/common/view/PrivacyPolicyScreen.kt + PrivacyPolicyViewModel.kt).
 * AppScaffold(title 隐私政策, background surface) + BaseNetWorkView:
 *  loading → DocumentLoadingSkeleton (min loading time), error → EmptyNetwork with retry, success → HTML in Web (JS off).
 */
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { PrivacyPolicyViewModel } from '../feature/common/settings/PrivacyPolicyViewModel';
import { DocumentLoadingSkeleton } from '../feature/common/settings/DocumentSkeleton';
import { HtmlDocumentView } from '../feature/common/settings/HtmlDocumentView';

@Builder
export function CommonRoutesPrivacyPolicyPageBuilder() {
  CommonRoutesPrivacyPolicyPage()
}

@ComponentV2
struct CommonRoutesPrivacyPolicyPage {
  @Local vm: PrivacyPolicyViewModel = new PrivacyPolicyViewModel();

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
        titleText: $r('app.string.privacy_policy_title'),
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
