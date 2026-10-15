/**
 * BaseNetWorkViewModel (source: core/common/base/viewmodel/BaseNetWorkViewModel.kt +
 * base/state/BaseNetWorkUiState.kt).
 *
 * Subclass contract (ArkTS port of the abstract Kotlin class):
 *   @ObservedV2 export class XxxViewModel extends BaseNetWorkViewModel<Data> {
 *     constructor() { super(); this.enableMinLoadingTime = true; }      // optional switches
 *     protected requestApiFlow(): Promise<NetworkResponse<Data>> { return XxxRepository.getX(...); }
 *   }
 *   then call vm.executeRequest() (e.g. from aboutToAppear / NavDestination.onReady).
 *
 * State: uiState 'loading' | 'success' | 'error' (+ data on success, errorMessage on error).
 * - Success only when code == 1000 AND data != null (ResultHandler semantics; data == null → no callback,
 *   the state stays as it is, same as source).
 * - enableMinLoadingTime: success state is delayed so loading lasts at least 320 ms.
 * - observeRefreshState(): re-request when any page returns RefreshResult{refresh:true} (AppNavigator bus).
 * - dispose(): call from the page's aboutToDisappear — cancels timers/subscriptions and ignores late callbacks.
 */
import { NetworkResponse } from '../model/Response';
import { HttpClient } from '../network/HttpClient';
import { ResultHandler, ResultHandleOptions } from '../network/ResultHandler';
import { AppNavigator } from '../navigation/AppNavigator';
import { RefreshResult } from '../navigation/RouteParams';
import { LogUtils } from '../util/LogUtils';

/** Source BaseNetWorkUiState: Loading / Success(data) / Error(message, exception) */
export type NetWorkUiState = 'loading' | 'success' | 'error';

/** Minimum loading time in ms when enableMinLoadingTime is on */
export const MIN_LOADING_TIME_MS: number = 320;

const TAG: string = 'BaseNetWorkViewModel';

@ObservedV2
export class BaseNetWorkViewModel<T> {
  /** Network UI state, initially loading */
  @Trace uiState: NetWorkUiState = 'loading';
  /** Data of the Success state (null otherwise until the first success) */
  @Trace data: T | null = null;
  /** Message of the Error state */
  @Trace errorMessage: string | null = null;

  /** Show a toast when the request fails (source showErrorToast, default false) */
  protected showErrorToast: boolean = false;
  /** Keep loading at least 320 ms (source enableMinLoadingTime, default false) */
  protected enableMinLoadingTime: boolean = false;

  /** True after dispose(): late callbacks must not touch state */
  protected disposed: boolean = false;

  private requestStartTime: number = 0;
  private pendingTimers: number[] = [];
  private refreshSubscriptionId: number = -1;

  /**
   * Subclasses MUST override: the API request (source requestApiFlow(): Flow<NetworkResponse<T>>).
   * The default resolves to a network failure and logs an error.
   */
  protected requestApiFlow(): Promise<NetworkResponse<T>> {
    LogUtils.eTag(TAG, 'requestApiFlow() not overridden');
    return Promise.resolve(HttpClient.failure<T>(HttpClient.NETWORK_ERROR_CODE, HttpClient.NETWORK_ERROR_MESSAGE));
  }

  /** Load or reload data (ResultHandler: onLoading → onSuccess / onError) */
  executeRequest(): void {
    if (this.disposed) {
      return;
    }
    if (this.enableMinLoadingTime) {
      this.requestStartTime = Date.now();
    }
    let request: Promise<NetworkResponse<T>>;
    try {
      request = this.requestApiFlow();
    } catch (e) {
      request = Promise.reject(e as Error);
    }
    const opts: ResultHandleOptions<T> = {
      showToast: this.showErrorToast,
      onLoading: (): void => {
        if (!this.disposed) {
          this.onRequestStart();
        }
      },
      onSuccess: (d: T): void => {
        if (!this.disposed) {
          this.onRequestSuccess(d);
        }
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.onRequestError(msg, err);
        }
      }
    };
    ResultHandler.handleAsync<T>(request, opts);
  }

  /** Called before the request starts; default sets the loading state */
  protected onRequestStart(): void {
    this.setLoadingState();
  }

  /** Success handling; default sets the success state (respecting the 320 ms minimum when enabled) */
  protected onRequestSuccess(data: T): void {
    if (this.enableMinLoadingTime) {
      const elapsed = Date.now() - this.requestStartTime;
      if (elapsed < MIN_LOADING_TIME_MS) {
        this.schedule((): void => {
          this.setSuccessState(data);
        }, MIN_LOADING_TIME_MS - elapsed);
        return;
      }
    }
    this.setSuccessState(data);
  }

  /** Error handling; default sets the error state */
  protected onRequestError(message: string, err?: Error): void {
    this.setErrorState(message, err);
  }

  /** Retry: loading state, then request again */
  retryRequest(): void {
    this.setLoadingState();
    this.executeRequest();
  }

  protected setLoadingState(): void {
    this.uiState = 'loading';
  }

  protected setSuccessState(data: T): void {
    this.data = data;
    this.errorMessage = null;
    this.uiState = 'success';
  }

  protected setErrorState(message: string | null = null, err?: Error): void {
    this.errorMessage = message;
    this.uiState = 'error';
  }

  /** Data of the success state; throws when uiState is not 'success' (source getSuccessData) */
  getSuccessData(): T {
    if (this.uiState !== 'success' || this.data === null) {
      throw new Error('Current page uiState is not in Success state, unable to retrieve data');
    }
    return this.data as T;
  }

  /**
   * Register once for refresh signals (source observeRefreshState(RefreshResultKey)):
   * any AppNavigator.backWithRefresh() triggers executeRequest().
   */
  observeRefreshState(): void {
    if (this.refreshSubscriptionId >= 0) {
      return;
    }
    this.refreshSubscriptionId = AppNavigator.subscribeResult((r: Object): void => {
      this.onRefreshResult(r);
    });
  }

  /** Handle a navigation result: RefreshResult{refresh:true} → executeRequest(). Usable as navigate onResult. */
  onRefreshResult(result: Object): void {
    if (!this.disposed && RefreshResult.isRefresh(result)) {
      this.executeRequest();
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
}
