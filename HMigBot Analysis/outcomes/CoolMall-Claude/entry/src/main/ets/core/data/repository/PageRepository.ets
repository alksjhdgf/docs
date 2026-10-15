/**
 * PageRepository (source: core/data/repository/PageRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse } from '../../model/Response';
import { GoodsDetail, Home } from '../../model/Goods';
import { ConfirmOrder } from '../../model/Order';
import { PageService } from '../../network/service/PageService';

export class PageRepository {
  /** page/home */
  static getHomeData(): Promise<NetworkResponse<Home>> {
    return PageService.getHomeData();
  }

  /** page/goodsDetail?goodsId= */
  static getGoodsDetail(goodsId: number): Promise<NetworkResponse<GoodsDetail>> {
    return PageService.getGoodsDetail(goodsId);
  }

  /** page/confirmOrder */
  static getConfirmOrder(): Promise<NetworkResponse<ConfirmOrder>> {
    return PageService.getConfirmOrder();
  }
}
