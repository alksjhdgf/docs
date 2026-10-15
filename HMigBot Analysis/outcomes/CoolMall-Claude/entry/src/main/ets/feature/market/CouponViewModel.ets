/**
 * CouponViewModel — my coupons (source: feature/market/viewmodel/CouponViewModel.kt) — USER-A31/A33.
 *
 * - BaseNetWorkListViewModel<Coupon>: POST market/coupon/user/page { page, size = 10 }, minimum first-load
 *   time enabled (source enableMinLoadingTime = true), init load on construction (source init { initLoad() }).
 * - navigateToGoodsCategory(coupon): GoodsRoutes.Category(minPrice = condition.fullAmount.toString() or "").
 * The page calls dispose() from aboutToDisappear.
 */
import { BaseNetWorkListViewModel } from '../../core/common/BaseNetWorkListViewModel';
import { CouponRepository } from '../../core/data/repository/CouponRepository';
import { Coupon } from '../../core/model/Market';
import { Condition } from '../../core/model/Goods';
import { PageRequest } from '../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../core/model/Response';
import { AppNavigator } from '../../core/navigation/AppNavigator';
import { GoodsCategoryParam } from '../../core/navigation/RouteParams';
import { Routes } from '../../common/Router';

/**
 * Kotlin Double.toString() for the usual price range: integral values keep one decimal ("100.0"),
 * others print their shortest representation ("99.5").
 */
export function kotlinDoubleToString(value: number): string {
  if (Number.isInteger(value) && Math.abs(value) < 10000000) {
    return value.toFixed(1);
  }
  return String(value);
}

@ObservedV2
export class CouponViewModel extends BaseNetWorkListViewModel<Coupon> {
  constructor() {
    super();
    // source: override val enableMinLoadingTime = true
    this.enableMinLoadingTime = true;
    this.initLoad();
  }

  /** market/coupon/user/page (source requestListData) */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Coupon>>> {
    const req: PageRequest = new PageRequest();
    req.page = this.page;
    req.size = this.pageSize;
    return CouponRepository.getUserCouponPage(req);
  }

  /** Use the coupon: goods category with the threshold as minimum price (source navigateToGoodsCategory) */
  navigateToGoodsCategory(coupon: Coupon): void {
    const condition: Condition | null | undefined = coupon?.condition;
    let minPrice: string = '';
    if (condition !== null && condition !== undefined && condition.fullAmount !== null &&
      condition.fullAmount !== undefined) {
      minPrice = kotlinDoubleToString(condition.fullAmount);
    }
    const param: GoodsCategoryParam = new GoodsCategoryParam();
    param.minPrice = minPrice;
    AppNavigator.navigate(Routes.GOODS_ROUTES_CATEGORY, param);
  }
}
