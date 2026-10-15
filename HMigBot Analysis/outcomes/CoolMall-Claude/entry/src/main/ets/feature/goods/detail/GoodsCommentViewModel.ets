/**
 * GoodsCommentViewModel (source: feature/goods/viewmodel/GoodsCommentViewModel.kt).
 *
 * BaseNetWorkListViewModel<Comment>: POST goods/comment/page { goodsId (string), page, size = 10 };
 * pull to refresh / load more / empty / error come from the base class; the first load keeps the
 * skeleton for at least 320 ms (enableMinLoadingTime) (GOODS-A19/A20).
 * Items are normalized on arrival (J2: absent fields → model defaults).
 */
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { Comment } from '../../../core/model/Goods';
import { GoodsCommentPageRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';
import { GoodsDetailViewModel } from './GoodsDetailViewModel';

@ObservedV2
export class GoodsCommentViewModel extends BaseNetWorkListViewModel<Comment> {
  /** Route goodsId (source navKey.goodsId) */
  goodsId: number = 0;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  /** Set the route goodsId and run the first load (source init { initLoad() }) */
  start(goodsId: number): void {
    this.goodsId = goodsId;
    this.initLoad();
  }

  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Comment>>> {
    const req: GoodsCommentPageRequest = new GoodsCommentPageRequest();
    req.goodsId = String(this.goodsId);
    req.page = this.page;
    req.size = this.pageSize;
    return GoodsRepository.getGoodsCommentPage(req);
  }

  protected handleSuccess(data: NetworkPageData<Comment> | null): void {
    if (data !== null && data.list !== null && data.list !== undefined) {
      const raw: Comment[] = data.list as Comment[];
      data.list = raw.map((c: Comment): Comment => GoodsDetailViewModel.normalizeComment(c));
    }
    super.handleSuccess(data);
  }
}
