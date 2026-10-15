/**
 * Goods APIs (source: core/network/service/GoodsService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Category, Comment, Goods, GoodsSearchKeyword, GoodsSpec } from '../../model/Goods';
import { GoodsCommentPageRequest, GoodsCommentSubmitRequest, GoodsSearchRequest } from '../../model/Request';

export class GoodsService {
  /** Goods categories */
  static getGoodsTypeList(): Promise<NetworkResponse<Category[]>> {
    return HttpClient.post<Category[]>('goods/type/list');
  }

  /** Goods specs; params e.g. { 'goodsId': 1 } */
  static getGoodsSpecList(params: Record<string, number>): Promise<NetworkResponse<GoodsSpec[]>> {
    return HttpClient.post<GoodsSpec[]>('goods/spec/list', params);
  }

  /** Search keywords */
  static getSearchKeywordList(): Promise<NetworkResponse<GoodsSearchKeyword[]>> {
    return HttpClient.post<GoodsSearchKeyword[]>('goods/search/keyword/list');
  }

  /** Goods page */
  static getGoodsPage(params: GoodsSearchRequest): Promise<NetworkResponse<NetworkPageData<Goods>>> {
    return HttpClient.post<NetworkPageData<Goods>>('goods/info/page', params);
  }

  /** Goods info (unused in source features) */
  static getGoodsInfo(id: string): Promise<NetworkResponse<Goods>> {
    const query = new Map<string, string>();
    query.set('id', id);
    return HttpClient.get<Goods>('goods/info/info', query);
  }

  /** Submit goods comment */
  static submitGoodsComment(params: GoodsCommentSubmitRequest): Promise<NetworkResponse<boolean>> {
    return HttpClient.post<boolean>('goods/comment/submit', params);
  }

  /** Goods comment page */
  static getGoodsCommentPage(params: GoodsCommentPageRequest): Promise<NetworkResponse<NetworkPageData<Comment>>> {
    return HttpClient.post<NetworkPageData<Comment>>('goods/comment/page', params);
  }
}
