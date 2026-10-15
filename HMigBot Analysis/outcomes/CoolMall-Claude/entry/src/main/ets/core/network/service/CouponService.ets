/**
 * Coupon APIs (source: core/network/service/CouponService.kt)
 * Coupon.condition may arrive as a JSON string (source ConditionSerializer); responses are normalized here.
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Coupon } from '../../model/Market';
import { PageRequest, ReceiveCouponRequest } from '../../model/Request';

export class CouponService {
  /** Receive a coupon */
  static receiveCoupon(request: ReceiveCouponRequest): Promise<NetworkResponse<string>> {
    return HttpClient.post<string>('market/coupon/user/receive', request);
  }

  /** User coupon page */
  static async getUserCouponPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Coupon>>> {
    const r = await HttpClient.post<NetworkPageData<Coupon>>('market/coupon/user/page', params);
    const page = r.data;
    if (page !== null && page !== undefined && page.list !== null && page.list !== undefined) {
      Coupon.normalizeList(page.list);
    }
    return r;
  }

  /** User coupon list (unused in source features) */
  static async getUserCouponList(params: Object): Promise<NetworkResponse<Coupon[]>> {
    const r = await HttpClient.post<Coupon[]>('market/coupon/user/list', params);
    if (r.data !== null && r.data !== undefined) {
      Coupon.normalizeList(r.data);
    }
    return r;
  }
}
