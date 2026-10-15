/**
 * GoodsRepository (source: core/data/repository/GoodsRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Category, Comment, Goods, GoodsSearchKeyword, GoodsSpec } from '../../model/Goods';
import { GoodsCommentPageRequest, GoodsCommentSubmitRequest, GoodsSearchRequest } from '../../model/Request';
import { GoodsService } from '../../network/service/GoodsService';

export class GoodsRepository {
  /** goods/type/list */
  static getGoodsTypeList(): Promise<NetworkResponse<Category[]>> {
    return GoodsService.getGoodsTypeList();
  }

  /** goods/spec/list */
  static getGoodsSpecList(params: Record<string, number>): Promise<NetworkResponse<GoodsSpec[]>> {
    return GoodsService.getGoodsSpecList(params);
  }

  /** goods/search/keyword/list */
  static getSearchKeywordList(): Promise<NetworkResponse<GoodsSearchKeyword[]>> {
    return GoodsService.getSearchKeywordList();
  }

  /** goods/info/page */
  static getGoodsPage(params: GoodsSearchRequest): Promise<NetworkResponse<NetworkPageData<Goods>>> {
    return GoodsService.getGoodsPage(params);
  }

  /** goods/info/info?id= (unused) */
  static getGoodsInfo(id: string): Promise<NetworkResponse<Goods>> {
    return GoodsService.getGoodsInfo(id);
  }

  /** goods/comment/submit */
  static submitGoodsComment(params: GoodsCommentSubmitRequest): Promise<NetworkResponse<boolean>> {
    return GoodsService.submitGoodsComment(params);
  }

  /** goods/comment/page */
  static getGoodsCommentPage(params: GoodsCommentPageRequest): Promise<NetworkResponse<NetworkPageData<Comment>>> {
    return GoodsService.getGoodsCommentPage(params);
  }
}
