/**
 * Page aggregate APIs (source: core/network/service/PageService.kt)
 * Embedded coupons are normalized (Coupon.condition may arrive as a JSON string, source ConditionSerializer).
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse } from '../../model/Response';
import { GoodsDetail, Home } from '../../model/Goods';
import { ConfirmOrder } from '../../model/Order';
import { Coupon } from '../../model/Market';

export class PageService {
  /** Home page data */
  static async getHomeData(): Promise<NetworkResponse<Home>> {
    const r = await HttpClient.get<Home>('page/home');
    const d = r.data;
    if (d !== null && d !== undefined && d.coupon !== null && d.coupon !== undefined) {
      Coupon.normalizeList(d.coupon);
    }
    return r;
  }

  /** Goods detail page data */
  static async getGoodsDetail(goodsId: number): Promise<NetworkResponse<GoodsDetail>> {
    const query = new Map<string, string>();
    query.set('goodsId', String(goodsId));
    const r = await HttpClient.get<GoodsDetail>('page/goodsDetail', query);
    const d = r.data;
    if (d !== null && d !== undefined && d.coupon !== null && d.coupon !== undefined) {
      Coupon.normalizeList(d.coupon);
    }
    return r;
  }

  /** Confirm order page data */
  static async getConfirmOrder(): Promise<NetworkResponse<ConfirmOrder>> {
    const r = await HttpClient.get<ConfirmOrder>('page/confirmOrder');
    const d = r.data;
    if (d !== null && d !== undefined && d.userCoupon !== null && d.userCoupon !== undefined) {
      Coupon.normalizeList(d.userCoupon);
    }
    return r;
  }
}
