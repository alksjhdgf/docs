/**
 * CouponRepository (source: core/data/repository/CouponRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Coupon } from '../../model/Market';
import { PageRequest, ReceiveCouponRequest } from '../../model/Request';
import { CouponService } from '../../network/service/CouponService';

export class CouponRepository {
  /** market/coupon/user/receive */
  static receiveCoupon(request: ReceiveCouponRequest): Promise<NetworkResponse<string>> {
    return CouponService.receiveCoupon(request);
  }

  /** market/coupon/user/page */
  static getUserCouponPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Coupon>>> {
    return CouponService.getUserCouponPage(params);
  }

  /** market/coupon/user/list */
  static getUserCouponList(params: Object): Promise<NetworkResponse<Coupon[]>> {
    return CouponService.getUserCouponList(params);
  }
}
