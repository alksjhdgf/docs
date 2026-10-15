/**
 * BaseNetWorkListViewModel (source: core/common/base/viewmodel/BaseNetWorkListViewModel.kt +
 * base/state/BaseNetWorkListUiState.kt + LoadMoreState.kt). DATA-A06, HOME-A19/A20 semantics.
 *
 * Subclass contract (ArkTS port of the abstract Kotlin class):
 *   @ObservedV2 export class XxxViewModel extends BaseNetWorkListViewModel<Item> {
 *     constructor() { super(); this.enableMinLoadingTime = true; this.initLoad(); }
 *     protected requestListData(): Promise<NetworkResponse<NetworkPageData<Item>>> {
 *       const req = new PageRequest(); req.page = this.page; req.size = this.pageSize;
 *       return XxxRepository.getXxxPage(req);
 *     }
 *   }
 *
 * - uiState: 'loading' | 'success' | 'error' | 'empty' (source Loading/Success/Error/Empty).
 * - hasNext = size * page < total (pagination fields fall back to pageSize / current page / 0).
 * - Page 1 (first load / refresh): list replaced; with enableMinLoadingTime the success state appears
 *   after at least 320 ms (first load only).
 * - Page > 1: loadMoreState = Success, then after 400 ms the items are appended and loadMoreState becomes
 *   PullToLoad (hasNext) or NoMore.
 * - Failure: page 1 → error state only when the list is empty, loadMoreState PullToLoad; page > 1 → page
 *   rolled back, loadMoreState Error.
 * - onRefresh ignored while loadMoreState == Loading; onLoadMore only from PullToLoad / Error.
 * - shouldLoadMore(lastIndex, total): lastIndex >= total - 3 and not Loading/NoMore and list not empty.
 * - dispose(): call from aboutToDisappear.
 */
import { NetworkPageData, NetworkResponse } from '../model/Response';
import { HttpClient } from '../network/HttpClient';
import { ResultHandler, ResultHandleOptions } from '../network/ResultHandler';
import { AppNavigator } from '../navigation/AppNavigator';
import { RefreshResult } from '../navigation/RouteParams';
import { LogUtils } from '../util/LogUtils';
import { LoadMoreState } from './LoadMoreState';
import { MIN_LOADING_TIME_MS } from './BaseNetWorkViewModel';

export { LoadMoreState } from './LoadMoreState';

/** Source BaseNetWorkListUiState: Loading / Success / Error / Empty */
export type NetWorkListUiState = 'loading' | 'success' | 'error' | 'empty';

/** Delay before appended load-more items are shown (source delay(400)) */
export const LOAD_MORE_APPEND_DELAY_MS: number = 400;

/** Load more triggers when the last visible index is within this many items of the end */
export const LOAD_MORE_THRESHOLD: number = 3;

const TAG: string = 'BaseNetWorkListViewModel';

@ObservedV2
export class BaseNetWorkListViewModel<T> {
  /** List UI state */
  @Trace uiState: NetWorkListUiState = 'loading';
  /** List data (source listData) */
  @Trace list: T[] = [];
  /** Load-more footer state */
  @Trace loadMoreState: LoadMoreState = LoadMoreState.PullToLoad;
  /** Pull-to-refresh indicator state (bind to Refresh) */
  @Trace isRefreshing: boolean = false;
  /** Whether another page exists (size * page < total) */
  @Trace hasNext: boolean = false;
  /** Current page (source currentPage), starts at 1 */
  @Trace page: number = 1;

  /** Page size (source pageSize = 10) */
  readonly pageSize: number = 10;

  /** Keep the first load at least 320 ms (source enableMinLoadingTime, default false) */
  protected enableMinLoadingTime: boolean = false;
  /** True after dispose(): late callbacks must not touch state */
  protected disposed: boolean = false;

  private requestStartTime: number = 0;
  private pendingTimers: number[] = [];
  private refreshSubscriptionId: number = -1;

  /**
   * Subclasses MUST override: the paged request for `this.page` / `this.pageSize`
   * (source requestListData(): Flow<NetworkResponse<NetworkPageData<T>>>).
   */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<T>>> {
    LogUtils.eTag(TAG, 'requestListData() not overridden');
    return Promise.resolve(HttpClient.failure<NetworkPageData<T>>(HttpClient.NETWORK_ERROR_CODE,
      HttpClient.NETWORK_ERROR_MESSAGE));
  }

  /** First load; call once from the subclass constructor / page aboutToAppear (source initLoad) */
  initLoad(): void {
    this.loadListData();
  }

  /** Load the current page */
  protected loadListData(): void {
    if (this.disposed) {
      return;
    }
    const isFirstLoading = this.page === 1 && this.list.length === 0 && !this.isRefreshing;
    if (isFirstLoading && this.enableMinLoadingTime) {
      this.requestStartTime = Date.now();
    }
    if (isFirstLoading) {
      this.uiState = 'loading';
      this.loadMoreState = LoadMoreState.Loading;
    }
    let request: Promise<NetworkResponse<NetworkPageData<T>>>;
    try {
      request = this.requestListData();
    } catch (e) {
      request = Promise.reject(e as Error);
    }
    const opts: ResultHandleOptions<NetworkPageData<T>> = {
      showToast: false,
      // Source handleResult onSuccess: any code == 1000 reply, even with data == null
      onResponse: (resp: NetworkResponse<NetworkPageData<T>>): void => {
        if (this.disposed || !ResultHandler.isSuccess(resp)) {
          return;
        }
        const d = resp.data;
        this.handleSuccess(d === undefined ? null : d);
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.handleError(msg, err);
        }
      }
    };
    ResultHandler.handleAsync<NetworkPageData<T>>(request, opts);
  }

  /** Success handling (overridable) */
  protected handleSuccess(data: NetworkPageData<T> | null): void {
    const newList: T[] = (data !== null && data.list !== null && data.list !== undefined) ? data.list : [];
    const pagination = (data !== null) ? data.pagination : null;

    let hasNextPage = false;
    if (pagination !== null && pagination !== undefined) {
      const total: number = pagination.total ?? 0;
      const size: number = pagination.size ?? this.pageSize;
      const currentPageNum: number = pagination.page ?? this.page;
      hasNextPage = size * currentPageNum < total;
    }
    this.hasNext = hasNextPage;

    if (this.page === 1) {
      // First load or refresh: replace the list
      this.list = newList;
      this.isRefreshing = false;
      if (this.enableMinLoadingTime) {
        const elapsed = Date.now() - this.requestStartTime;
        if (elapsed < MIN_LOADING_TIME_MS) {
          this.schedule((): void => {
            this.setFirstLoadSuccessState(newList, hasNextPage);
          }, MIN_LOADING_TIME_MS - elapsed);
          return;
        }
      }
      this.setFirstLoadSuccessState(newList, hasNextPage);
    } else {
      // Load more: show success first, append after 400 ms
      this.loadMoreState = LoadMoreState.Success;
      this.schedule((): void => {
        this.list = this.list.concat(newList);
        this.loadMoreState = hasNextPage ? LoadMoreState.PullToLoad : LoadMoreState.NoMore;
      }, LOAD_MORE_APPEND_DELAY_MS);
    }
  }

  /** Error handling (overridable) */
  protected handleError(message: string, err?: Error): void {
    this.isRefreshing = false;
    if (this.page === 1) {
      if (this.list.length === 0) {
        this.uiState = 'error';
      }
      this.loadMoreState = LoadMoreState.PullToLoad;
    } else {
      // Load more failed: roll back the page
      this.page = this.page - 1;
      this.loadMoreState = LoadMoreState.Error;
    }
  }

  /** Retry from page 1 */
  retryRequest(): void {
    this.page = 1;
    this.loadMoreState = LoadMoreState.Loading;
    this.loadListData();
  }

  /** Pull to refresh (ignored while loading) */
  onRefresh(): void {
    if (this.loadMoreState === LoadMoreState.Loading) {
      return;
    }
    this.isRefreshing = true;
    this.page = 1;
    this.loadListData();
  }

  /** Load the next page (only from PullToLoad / Error) */
  onLoadMore(): void {
    if (this.loadMoreState === LoadMoreState.Loading ||
      this.loadMoreState === LoadMoreState.NoMore ||
      this.loadMoreState === LoadMoreState.Success) {
      return;
    }
    this.loadMoreState = LoadMoreState.Loading;
    this.page = this.page + 1;
    this.loadListData();
  }

  /** Whether to trigger load more: last visible index within the last 3 items (source shouldTriggerLoadMore) */
  shouldLoadMore(lastIndex: number, total: number): boolean {
    return lastIndex >= total - LOAD_MORE_THRESHOLD &&
      this.loadMoreState !== LoadMoreState.Loading &&
      this.loadMoreState !== LoadMoreState.NoMore &&
      this.list.length > 0;
  }

  /** Source-name alias of shouldLoadMore */
  shouldTriggerLoadMore(lastIndex: number, total: number): boolean {
    return this.shouldLoadMore(lastIndex, total);
  }

  /** Register once for refresh signals: any backWithRefresh() triggers onRefresh() (source observeRefreshState) */
  observeRefreshState(): void {
    if (this.refreshSubscriptionId >= 0) {
      return;
    }
    this.refreshSubscriptionId = AppNavigator.subscribeResult((r: Object): void => {
      this.onRefreshResult(r);
    });
  }

  /** Handle a navigation result: RefreshResult{refresh:true} → onRefresh(). Usable as navigate onResult. */
  onRefreshResult(result: Object): void {
    if (!this.disposed && RefreshResult.isRefresh(result)) {
      this.onRefresh();
    }
  }

  /** Release timers / subscriptions; call from aboutToDisappear */
  dispose(): void {
    this.disposed = true;
    for (const t of this.pendingTimers) {
      clearTimeout(t);
    }
    this.pendingTimers = [];
    if (this.refreshSubscriptionId >= 0) {
      AppNavigator.unsubscribeResult(this.refreshSubscriptionId);
      this.refreshSubscriptionId = -1;
    }
  }

  /** setTimeout tracked for dispose(); the callback is skipped once disposed */
  protected schedule(fn: () => void, delayMs: number): void {
    const id: number = setTimeout((): void => {
      const idx = this.pendingTimers.indexOf(id);
      if (idx >= 0) {
        this.pendingTimers.splice(idx, 1);
      }
      if (!this.disposed) {
        fn();
      }
    }, delayMs);
    this.pendingTimers.push(id);
  }

  private setFirstLoadSuccessState(newList: T[], hasNextPage: boolean): void {
    if (newList.length === 0) {
      this.uiState = 'empty';
    } else {
      this.uiState = 'success';
      this.loadMoreState = hasNextPage ? LoadMoreState.PullToLoad : LoadMoreState.NoMore;
    }
  }
}
