/**
 * WebViewModel (source: feature/common/viewmodel/WebViewModel.kt).
 *
 * - init(param, defaultTitle): url from the route; title = route title ?? `网页` (only when url is non-empty,
 *   as in source).
 * - pageTitle is replaced by WebView onTitleReceive; currentProgress by onProgressChange.
 * - refreshPage(): raises shouldRefresh (the page reloads the WebView and resets it) and closes the menu.
 * - openInBrowser(ctx): opens the route's initial url in the system browser (startAbility viewData + uri),
 *   then closes the menu.
 */
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WebParam } from '../../../core/navigation/RouteParams';
import { LogUtils } from '../../../core/util/LogUtils';
import { WebViewData } from './WebViewData';

const TAG: string = 'WebViewModel';

@ObservedV2
export class WebViewModel {
  /** WebView data (url + title from the route) */
  @Trace webViewData: WebViewData = new WebViewData();
  /** Title bar text */
  @Trace pageTitle: ResourceStr = '';
  /** Loading progress 0..100 */
  @Trace currentProgress: number = 0;
  /** Reload request */
  @Trace shouldRefresh: boolean = false;
  /** `更多选项` menu visibility */
  @Trace showDropdownMenu: boolean = false;

  /** Read the route param (source init block) */
  init(param: WebParam | null, defaultTitle: ResourceStr): void {
    if (param === null) {
      return;
    }
    const url: string = param.url ?? '';
    if (url.length > 0) {
      const routeTitle: string | null = param.title ?? null;
      this.webViewData = new WebViewData(url, routeTitle !== null ? routeTitle : '');
      this.pageTitle = routeTitle !== null ? routeTitle : defaultTitle;
    }
  }

  updatePageTitle(title: string): void {
    this.pageTitle = title;
  }

  updateProgress(progress: number): void {
    this.currentProgress = progress;
  }

  refreshPage(): void {
    this.shouldRefresh = true;
    this.dismissDropdownMenu();
  }

  resetRefreshState(): void {
    this.shouldRefresh = false;
  }

  /** Open the initial url in the system browser */
  openInBrowser(ctx: common.UIAbilityContext | undefined): void {
    const currentUrl: string = this.webViewData.url;
    if (currentUrl.length > 0) {
      WebViewModel.openWithSystem(ctx, currentUrl, true);
    }
    this.dismissDropdownMenu();
  }

  showMenu(): void {
    this.showDropdownMenu = true;
  }

  dismissDropdownMenu(): void {
    this.showDropdownMenu = false;
  }

  /**
   * Hand a uri to the system (source Intent.ACTION_VIEW + uri). `browsable` adds the browser entity so an
   * http(s) url goes to the system browser; other schemes (tel:/mailto:/geo:) are resolved by uri only.
   * Failures are logged (source printStackTrace).
   */
  static openWithSystem(ctx: common.UIAbilityContext | undefined, uri: string, browsable: boolean): void {
    if (ctx === undefined) {
      LogUtils.wTag(TAG, 'no ability context, cannot open ' + uri);
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uri
    };
    if (browsable) {
      want.entities = ['entity.system.browsable'];
    }
    try {
      ctx.startAbility(want).catch((err: BusinessError) => {
        LogUtils.wTag(TAG, `startAbility failed: ${err.code} ${err.message}`);
      });
    } catch (e) {
      const be: BusinessError = e as BusinessError;
      LogUtils.wTag(TAG, `startAbility threw: ${be?.code} ${be?.message}`);
    }
  }
}
