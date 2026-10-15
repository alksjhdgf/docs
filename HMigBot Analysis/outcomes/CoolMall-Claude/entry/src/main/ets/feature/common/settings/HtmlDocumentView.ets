/**
 * HtmlDocumentView — renders an HTML string in a Web component
 * (source: UserAgreementScreen / PrivacyPolicyScreen `*ContentView` → AndroidView(WebView) + loadDataWithBaseURL).
 *
 * WebView settings mapped from the source: javaScriptEnabled=false → javaScriptAccess(false);
 * loadsImagesAutomatically → imageAccess(true); loadWithOverviewMode → overviewModeAccess(true);
 * setSupportZoom/builtInZoomControls → zoomAccess(true); domStorageEnabled=false → domStorageAccess(false).
 * Content: controller.loadData(html, "text/html", "UTF-8") once the initial about:blank has finished loading.
 */
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtils } from '../../../core/util/LogUtils';

const TAG: string = 'HtmlDocumentView';

@ComponentV2
export struct HtmlDocumentView {
  /** HTML 内容 */
  @Param html: string = '';

  private controller: webview.WebviewController = new webview.WebviewController();
  private attached: boolean = false;

  @Monitor('html')
  onHtmlChanged(): void {
    if (this.attached) {
      this.loadHtml();
    }
  }

  private loadHtml(): void {
    try {
      this.controller.loadData(this.html, 'text/html', 'UTF-8');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      LogUtils.eTag(TAG, `loadData failed: ${err.code} ${err.message}`);
    }
  }

  build() {
    Column() {
      Web({ src: 'about:blank', controller: this.controller })
        .width('100%')
        .height('100%')
        .javaScriptAccess(false)
        .domStorageAccess(false)
        .fileAccess(false)
        .imageAccess(true)
        .onlineImageAccess(true)
        .overviewModeAccess(true)
        .zoomAccess(true)
        // Load the HTML only after the initial about:blank has finished: loading earlier (onControllerAttached)
        // is overwritten when about:blank completes (device 4b: Web stayed at about:blank).
        .onPageEnd((event: OnPageEndEvent) => {
          if (!this.attached && event.url === 'about:blank') {
            this.attached = true;
            if (this.html.length > 0) {
              this.loadHtml();
            }
          }
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
