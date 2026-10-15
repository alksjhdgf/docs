/**
 * Response models (source: core/model/response/*.kt)
 *
 * These are plain classes so `JSON.parse(text) as NetworkResponse<T>` works directly; parsed objects
 * have no methods, so use the static helpers (NetworkResponse.succeeded(resp)).
 */
import { DictItem } from './Market';

/** Unified response wrapper; code 1000 = success */
export class NetworkResponse<T> {
  data?: T | null;
  code: number = 1000;
  message?: string | null;

  /** Success code (source: code == 1000) */
  static readonly SUCCESS_CODE: number = 1000;

  /** Whether the given response succeeded (works on parsed plain objects) */
  static succeeded<R>(resp: NetworkResponse<R> | null | undefined): boolean {
    return resp !== null && resp !== undefined && resp.code === NetworkResponse.SUCCESS_CODE;
  }

  /** Source property isSucceeded (only on real instances) */
  get isSucceeded(): boolean {
    return this.code === NetworkResponse.SUCCESS_CODE;
  }
}

/** Pagination meta */
export class NetworkPageMeta {
  total: number | null = null;
  size: number | null = null;
  page: number | null = null;
}

/** Paged data */
export class NetworkPageData<T> {
  list?: T[] | null;
  pagination?: NetworkPageMeta | null;
}

/** Dict data response */
export class DictDataResponse {
  orderCancelReason: DictItem[] | null = null;
  orderRefundReason: DictItem[] | null = null;
  feedbackType: DictItem[] | null = null;
}
