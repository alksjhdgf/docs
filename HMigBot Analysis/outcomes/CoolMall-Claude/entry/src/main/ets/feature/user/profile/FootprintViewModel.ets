/**
 * FootprintViewModel (source: feature/user/viewmodel/FootprintViewModel.kt).
 *
 * - footprints: all footprints (viewTime DESC), queried once and re-queried after every FootprintDao write
 *   (Room Flow equivalent via FootprintRepository.observeAllFootprints, J3).
 * - uiState: Loading until the first footprints result, then Empty / Success (source map + stateIn).
 * - footprintCount: total count (source getFootprintCount() Flow).
 * - clearAllFootprints(): delete every footprint (no confirmation); the observers re-query → Empty.
 * - dispose(): unsubscribe both observers; late callbacks never touch state (A2.4).
 */
import { FootprintRepository } from '../../../core/data/repository/FootprintRepository';
import { Footprint } from '../../../core/model/Market';
import { Goods } from '../../../core/model/Goods';
import { LogUtils } from '../../../core/util/LogUtils';
import { FootprintUiState } from './FootprintUiState';

const TAG: string = 'FootprintViewModel';

@ObservedV2
export class FootprintViewModel {
  /** All footprint records (source footprints, initial emptyList()) */
  @Trace footprints: Footprint[] = [];
  /** Page UI state (source uiState, initial Loading) */
  @Trace uiState: FootprintUiState = FootprintUiState.Loading;
  /** Total footprint count (source footprintCount, initial 0) */
  @Trace footprintCount: number = 0;

  private listObserverId: number = -1;
  private countObserverId: number = -1;
  private disposed: boolean = false;

  constructor() {
    this.listObserverId = FootprintRepository.observeAllFootprints((list: Footprint[]): void => {
      if (this.disposed) {
        return;
      }
      this.footprints = list;
      this.uiState = list.length === 0 ? FootprintUiState.Empty : FootprintUiState.Success;
    });
    this.countObserverId = FootprintRepository.observeFootprintCount((count: number): void => {
      if (!this.disposed) {
        this.footprintCount = count;
      }
    });
  }

  /** Remove one footprint (source removeFootprint) */
  removeFootprint(goodsId: number): void {
    FootprintRepository.removeFootprint(goodsId).catch((err: Error): void => {
      LogUtils.eTag(TAG, 'removeFootprint failed: ' + (err?.message ?? ''));
    });
  }

  /** Clear all footprints (source clearAllFootprints) */
  clearAllFootprints(): void {
    FootprintRepository.clearAllFootprints().catch((err: Error): void => {
      LogUtils.eTag(TAG, 'clearAllFootprints failed: ' + (err?.message ?? ''));
    });
  }

  /** Footprint → Goods for GoodsGridItem (source private Footprint.toGoods()) */
  static toGoods(footprint: Footprint): Goods {
    const goods = new Goods();
    goods.id = footprint.goodsId;
    goods.title = footprint.goodsName;
    goods.subTitle = footprint.goodsSubTitle;
    goods.mainPic = footprint.goodsMainPic;
    goods.price = footprint.goodsPrice;
    goods.sold = footprint.goodsSold;
    return goods;
  }

  dispose(): void {
    this.disposed = true;
    if (this.listObserverId >= 0) {
      FootprintRepository.unsubscribe(this.listObserverId);
      this.listObserverId = -1;
    }
    if (this.countObserverId >= 0) {
      FootprintRepository.unsubscribe(this.countObserverId);
      this.countObserverId = -1;
    }
  }
}
