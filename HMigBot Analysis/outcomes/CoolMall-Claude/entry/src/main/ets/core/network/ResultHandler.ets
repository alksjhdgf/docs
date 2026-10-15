/**
 * Network result handling (source: core/result/ResultHandler.kt, Result.kt, ResultExt.kt)
 *
 * Semantics (DATA-A04 / DATA-A05):
 * - code == 1000 → onResponse(resp); then onSuccess(data) only when data != null
 *   (data == null: no callback, no error).
 * - code != 1000 → onResponse(resp), onError(message ?? '未知错误') and an error toast when showToast (default true).
 * - transport failure (HttpClient code -1) / rejected promise → onError(message ?? '网络请求失败') + toast;
 *   onResponse is NOT called (source Result.Error branch).
 * - exception thrown inside callbacks (handleAsync) → onError('请求处理异常') + toast.
 * - handleAsync: onLoading first, onFinally always last.
 * There is no 401 / token-expiry interception (source has none).
 */
import { NetworkResponse } from '../model/Response';
import { LogUtils } from '../util/LogUtils';
import { ToastUtils } from '../util/ToastUtils';
import { HttpClient } from './HttpClient';

/** Options of ResultHandler.handle / handleAsync (all optional) */
export interface ResultHandleOptions<T> {
  /** Show an error toast on failure (default true) */
  showToast?: boolean;
  /** Loading callback (handleAsync only) — source onLoading */
  onLoading?: () => void;
  /** Called with the whole response on any server reply — source onSuccess(NetworkResponse) */
  onResponse?: (resp: NetworkResponse<T>) => void;
  /** Called only when code == 1000 and data != null — source onSuccessWithData / onData */
  onSuccess?: (data: T) => void;
  /** Error callback (message, cause) — source onError */
  onError?: (msg: string, err?: Error) => void;
  /** Always called last (handleAsync only) — source onFinally */
  onFinally?: () => void;
}

export class ResultHandler {
  /** Success code check (source NetworkResponse.isSucceeded: code == 1000) */
  static isSuccess<T>(r: NetworkResponse<T> | null | undefined): boolean {
    return r !== null && r !== undefined && r.code === NetworkResponse.SUCCESS_CODE;
  }

  /** Handle an already received response synchronously */
  static handle<T>(r: NetworkResponse<T>, opts?: ResultHandleOptions<T>): void {
    const showToast: boolean = opts?.showToast ?? true;
    if (r === null || r === undefined) {
      ResultHandler.handleError(HttpClient.NETWORK_ERROR_MESSAGE, undefined, showToast, opts);
      return;
    }
    if (r.code === HttpClient.NETWORK_ERROR_CODE) {
      // Transport failure: equivalent to source Result.Error
      const msg = (r.message !== null && r.message !== undefined && r.message.length > 0) ? r.message :
        HttpClient.NETWORK_ERROR_MESSAGE;
      ResultHandler.handleError(msg, new Error(msg), showToast, opts);
      return;
    }
    if (opts?.onResponse !== undefined) {
      opts.onResponse(r);
    }
    if (ResultHandler.isSuccess(r)) {
      const data = r.data;
      if (data === null || data === undefined) {
        return;
      }
      if (opts?.onSuccess !== undefined) {
        opts.onSuccess(data as T);
      }
    } else {
      const errorMsg = (r.message !== null && r.message !== undefined) ? r.message : '未知错误';
      ResultHandler.handleError(errorMsg, new Error(errorMsg), showToast, opts);
    }
  }

  /** Await a request and handle it (source handleResult: Loading → Success/Error → finally) */
  static async handleAsync<T>(p: Promise<NetworkResponse<T>>, opts?: ResultHandleOptions<T>): Promise<void> {
    const showToast: boolean = opts?.showToast ?? true;
    try {
      if (opts?.onLoading !== undefined) {
        opts.onLoading();
      }
      let resp: NetworkResponse<T> | null = null;
      try {
        resp = await p;
      } catch (e) {
        const err = e as Error;
        const msg = (err !== null && err !== undefined && err.message !== undefined && err.message.length > 0) ?
          err.message : HttpClient.NETWORK_ERROR_MESSAGE;
        ResultHandler.handleError(msg, err, showToast, opts);
        return;
      }
      ResultHandler.handle<T>(resp, opts);
    } catch (e) {
      ResultHandler.handleError('请求处理异常', e as Error, showToast, opts);
    } finally {
      if (opts?.onFinally !== undefined) {
        opts.onFinally();
      }
    }
  }

  private static handleError<T>(errorMsg: string, err: Error | undefined, showToast: boolean,
    opts?: ResultHandleOptions<T>): void {
    LogUtils.e(ResultHandler.formatErrorLog(errorMsg, err));
    if (opts?.onError !== undefined) {
      opts.onError(errorMsg, err);
    }
    if (showToast) {
      ToastUtils.showError(errorMsg);
    }
  }

  private static formatErrorLog(errorMsg: string, err: Error | undefined): string {
    let s = '=== 网络请求错误 ===\n';
    s += `错误信息: ${errorMsg}\n`;
    if (err !== undefined && err !== null) {
      s += `异常类型: ${err.name}\n`;
      if (err.stack !== undefined) {
        s += `异常堆栈:\n${err.stack}\n`;
      }
    }
    s += '==================';
    return s;
  }
}
