/**
 * CommonRoutesWebPage — in-app web page (source: feature/common/view/WebScreen.kt WebRoute / WebScreen /
 * WebScreenTopBarActions / WebViewContent, viewmodel/WebViewModel.kt).
 *
 * Param: WebParam(url, title?). Missing / foreign param or empty url → stays on the page with an empty state.
 *
 * AppScaffold(title = pageTitle: route title ?? `网页`, replaced by the document title — COM-A20;
 *             back → previous page; actions: `更多选项` (ic_more_vertical) → menu `刷新` / `用浏览器打开` — COM-A21) {
 *   Stack(TopStart) {
 *     Web(src = url): JavaScript + DOM Storage on, images, zoom, overview mode, no multi window;
 *       onTitleReceive → title, onProgressChange → progress;
 *       onLoadIntercept: http/https load in place, other schemes (tel:/mailto:/geo:…) → system (COM-A22)
 *     LinearProgress(progress/100) at the top (padding top 1) while progress < 100 (COM-A20)
 *   }
 * }
 */
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { WebParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyData } from '../core/ui/base/StateViews';
import { LogUtils } from '../core/util/LogUtils';
import { WebViewModel } from '../feature/common/about/WebViewModel';

const TAG: string = 'CommonRoutesWebPage';
/** M3 IconButton size / CommonIcon default size */
const ACTION_BUTTON_SIZE: number = 48;
const ACTION_ICON_SIZE: number = 24;

@Builder
export function CommonRoutesWebPageBuilder() {
  CommonRoutesWebPage()
}

@ComponentV2
struct CommonRoutesWebPage {
  @Local vm: WebViewModel = new WebViewModel();
  /** Route param read (onReady) */
  @Local paramReady: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();
  /** M3 LinearProgressIndicator: 4vp track, no scan effect */
  private progressStyle: LinearStyleOptions = { strokeWidth: 4, enableScanEffect: false };
  private started: boolean = false;
  private disappeared: boolean = false;

  aboutToDisappear(): void {
    this.disappeared = true;
  }

  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  private onParam(p: Object | undefined): void {
    if (this.started) {
      return;
    }
    this.started = true;
    if (p !== undefined && p !== null && p instanceof WebParam) {
      this.vm.init(p as WebParam, $r('app.string.web_title'));
    } else {
      this.vm.init(null, $r('app.string.web_title'));
    }
    this.paramReady = true;
  }

  /** Source LaunchedEffect(shouldRefresh): reload, then reset */
  @Monitor('vm.shouldRefresh')
  onShouldRefreshChange(monitor: IMonitor): void {
    if (!this.vm.shouldRefresh) {
      return;
    }
    try {
      this.controller.refresh();
    } catch (e) {
      const be: BusinessError = e as BusinessError;
      LogUtils.wTag(TAG, `refresh failed: ${be?.code} ${be?.message}`);
    }
    this.vm.resetRefreshState();
  }

  /** shouldOverrideUrlLoading: true = handled here (WebView must not load it) */
  private interceptUrl(url: string): boolean {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // http / https: load in the WebView
      return false;
    }
    // tel: / mailto: / geo: … → system apps
    WebViewModel.openWithSystem(this.abilityContext(), url, false);
    return true;
  }

  @Builder
  moreMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.web_menu_refresh') })
        .onClick(() => {
          this.vm.refreshPage();
        })
      MenuItem({ content: $r('app.string.web_menu_open_browser') })
        .onClick(() => {
          this.vm.openInBrowser(this.abilityContext());
        })
    }
  }

  @Builder
  topBarActions() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Image($r('app.media.ic_more_vertical'))
        .width(ACTION_ICON_SIZE)
        .height(ACTION_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_primary'))
        .accessibilityText($r('app.string.web_more_options'))
    }
    .width(ACTION_BUTTON_SIZE)
    .height(ACTION_BUTTON_SIZE)
    .backgroundColor(Color.Transparent)
    .accessibilityText($r('app.string.web_more_options'))
    .onClick(() => {
      this.vm.showMenu();
    })
    .bindMenu(this.vm.showDropdownMenu, this.moreMenu(), {
      placement: Placement.BottomRight,
      onDisappear: () => {
        this.vm.dismissDropdownMenu();
      }
    })
  }

  @Builder
  webContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Web({ src: this.vm.webViewData.url, controller: this.controller })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .zoomAccess(true)
        .overviewModeAccess(true)
        .multiWindowAccess(false)
        .mediaPlayGestureAccess(false)
        .onTitleReceive((event: OnTitleReceiveEvent) => {
          if (!this.disappeared && event !== undefined && event.title !== undefined && event.title !== null) {
            this.vm.updatePageTitle(event.title);
          }
        })
        .onProgressChange((event: OnProgressChangeEvent) => {
          if (!this.disappeared && event !== undefined) {
            this.vm.updateProgress(event.newProgress);
          }
        })
        .onLoadIntercept((event: OnLoadInterceptEvent) => {
          if (event === undefined || event.data === undefined) {
            return false;
          }
          return this.interceptUrl(event.data.getRequestUrl());
        })

      if (this.vm.currentProgress < 100) {
        Progress({ value: this.vm.currentProgress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .margin({ top: 1 })
          .color(ThemeManager.instance.primary)
          .backgroundColor($r('app.color.bg_content'))
          .style(this.progressStyle)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  pageContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.paramReady) {
        if (this.vm.webViewData.url.length > 0) {
          this.webContent()
        } else {
          EmptyData()
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: this.vm.pageTitle,
        topBarActions: (): void => {
          this.topBarActions()
        },
        content: (): void => {
          this.pageContent()
        }
      })
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
