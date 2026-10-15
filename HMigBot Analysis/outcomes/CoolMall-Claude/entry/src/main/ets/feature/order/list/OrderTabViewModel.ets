/**
 * OrderTabViewModel — per-tab paging state of the order list (source: OrderListViewModel's per-tab
 * _uiStates / _listDataMap / _loadMoreStates / _refreshingStates / pageIndices, exposed per tab as
 * feature/order/model/OrderTabState.kt). ORDA-A07..A11.
 *
 * Built on BaseNetWorkListViewModel (same paging semantics as the source's per-tab code):
 * - request: POST order/info/page { page, size = 10, status = tab filter (omitted for 全部) }
 * - page 1 success replaces the list (empty → 'empty' state); page > 1 appends after 400 ms;
 *   hasNext = pagination.size * page < total, otherwise `no more`.
 * - page 1 failure: 'error' only when the list is empty (old data kept on refresh failure);
 *   load-more failure rolls the page back and shows the footer error (tap to retry).
 * - refresh is ignored while a load is in progress; retry restarts from page 1.
 * Source specifics added here:
 * - the minimum 320 ms first-screen loading applies once, to the initial tab only, on success AND error
 *   (source applyInitialLoadingDelayIfNeeded / initialLoadingConsumed).
 * - an empty page-1 result resets the load-more state to PullToLoad (source handleSuccess).
 */
import { BaseNetWorkListViewModel, LoadMoreState } from '../../../core/common/BaseNetWorkListViewModel';
import { MIN_LOADING_TIME_MS } from '../../../core/common/BaseNetWorkViewModel';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { Order } from '../../../core/model/Order';
import { OrderPageRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';

@ObservedV2
export class OrderTabViewModel extends BaseNetWorkListViewModel<Order> {
  /** Tab index (OrderStatus ordinal) */
  readonly tabIndex: number;
  /** order/info/page status filter; null = no status field (全部) */
  readonly statusFilter: number[] | null;

  /** Start time of the current request (for the initial-screen minimum loading time) */
  private requestStart: number = 0;

  constructor(tabIndex: number, statusFilter: number[] | null) {
    super();
    this.tabIndex = tabIndex;
    this.statusFilter = statusFilter;
  }

  /** Enable the one-shot minimum loading time (initial tab of the page only) */
  enableInitialMinLoading(): void {
    this.enableMinLoadingTime = true;
  }

  /** Load the current page (source loadListData(tabIndex)); used by lazy tab loading / tab reset */
  load(): void {
    this.loadListData();
  }

  /** Reset the page index to 1 (source resetTabLoadState: the list itself is kept until replaced) */
  resetPage(): void {
    this.page = 1;
  }

  /** Release timers; call from the page's aboutToDisappear */
  release(): void {
    this.dispose();
  }

  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Order>>> {
    this.requestStart = Date.now();
    const req: OrderPageRequest = new OrderPageRequest();
    req.page = this.page;
    req.size = this.pageSize;
    if (this.statusFilter !== null) {
      req.status = this.statusFilter;
    }
    return OrderRepository.getOrderPage(req);
  }

  protected handleSuccess(data: NetworkPageData<Order> | null): void {
    const firstPage: boolean = this.page === 1;
    const listRaw: Order[] | null | undefined = data !== null ? data.list : null;
    const emptyResult: boolean = listRaw === null || listRaw === undefined || listRaw.length === 0;
    super.handleSuccess(data);
    // The base class only delays the first load; the source consumes the delay once
    this.enableMinLoadingTime = false;
    if (firstPage && emptyResult) {
      this.loadMoreState = LoadMoreState.PullToLoad;
    }
  }

  protected handleError(message: string, err?: Error): void {
    if (this.enableMinLoadingTime && this.page === 1) {
      // Source: the initial-screen minimum loading time also applies before the error state
      this.enableMinLoadingTime = false;
      const elapsed: number = Date.now() - this.requestStart;
      if (elapsed < MIN_LOADING_TIME_MS) {
        this.schedule((): void => {
          this.applyError(message, err);
        }, MIN_LOADING_TIME_MS - elapsed);
        return;
      }
    }
    this.applyError(message, err);
  }

  private applyError(message: string, err?: Error): void {
    super.handleError(message, err);
  }
}
