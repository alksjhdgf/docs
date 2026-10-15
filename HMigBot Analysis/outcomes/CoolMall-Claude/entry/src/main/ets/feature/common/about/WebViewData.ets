/**
 * WebViewData (source: feature/common/model/WebViewData.kt) — url + title of the Web page.
 */
@ObservedV2
export class WebViewData {
  @Trace url: string = '';
  @Trace title: string = '';

  constructor(url: string = '', title: string = '') {
    this.url = url;
    this.title = title;
  }
}
