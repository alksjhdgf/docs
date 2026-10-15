/**
 * GoodsSearchViewModel (source: feature/goods/viewmodel/GoodsSearchViewModel.kt).
 *
 * - GOODS-A23: init() requests the recommended keyword list (BaseNetWorkViewModel.executeRequest) and observes the
 *   10 most recent search history entries (query once, then re-query after every search_history write).
 * - GOODS-A25: onSearch(keyword) ignores blank keywords; otherwise writes the history (trimmed, deduped by keyword,
 *   time refreshed — SearchHistoryRepository.addSearchHistory) and then opens GoodsRoutesCategory(keyword).
 * - dispose(): call from the page's aboutToDisappear (cancels the history observation and late callbacks).
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { SearchHistoryRepository } from '../../../core/data/repository/SearchHistoryRepository';
import { GoodsSearchKeyword } from '../../../core/model/Goods';
import { SearchHistory } from '../../../core/model/Market';
import { NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { GoodsCategoryParam } from '../../../core/navigation/RouteParams';
import { LogUtils } from '../../../core/util/LogUtils';
import { Routes } from '../../../common/Router';

const TAG: string = 'GoodsSearchViewModel';

/** getRecentSearchHistory(10) */
const RECENT_HISTORY_LIMIT: number = 10;

@ObservedV2
export class GoodsSearchViewModel extends BaseNetWorkViewModel<GoodsSearchKeyword[]> {
  /** Search history (latest 10, newest first) */
  @Trace searchHistoryList: SearchHistory[] = [];

  private historyObserverId: number = -1;

  constructor() {
    super();
  }

  /** Source init { executeRequest(); loadSearchHistory() } — call once from aboutToAppear */
  init(): void {
    this.executeRequest();
    this.loadSearchHistory();
  }

  /** Recommended search keyword list */
  protected requestApiFlow(): Promise<NetworkResponse<GoodsSearchKeyword[]>> {
    return GoodsRepository.getSearchKeywordList();
  }

  /** Observe the latest 10 history entries (Flow collect equivalent) */
  private loadSearchHistory(): void {
    if (this.historyObserverId >= 0) {
      return;
    }
    this.historyObserverId = SearchHistoryRepository.observeRecentSearchHistory(RECENT_HISTORY_LIMIT,
      (list: SearchHistory[]): void => {
        if (!this.disposed) {
          this.searchHistoryList = list;
        }
      });
  }

  /** Search: blank → nothing; otherwise write history then open the category goods list with the keyword */
  onSearch(keyword: string): void {
    if (keyword.trim().length === 0) {
      return;
    }
    SearchHistoryRepository.addSearchHistory(keyword).then((): void => {
      this.toCategory(keyword);
    }).catch((err: Error): void => {
      LogUtils.eTag(TAG, 'addSearchHistory failed: ' + (err?.message ?? ''));
      this.toCategory(keyword);
    });
  }

  /** Recommended keyword tag */
  onKeywordClick(keyword: string): void {
    this.onSearch(keyword);
  }

  /** History tag */
  onSearchHistoryClick(searchHistory: SearchHistory): void {
    this.onSearch(searchHistory.keyword);
  }

  /** Delete icon: clear all history (the observation refreshes the list) */
  clearSearchHistory(): void {
    SearchHistoryRepository.clearAllSearchHistory().catch((err: Error): void => {
      LogUtils.eTag(TAG, 'clearAllSearchHistory failed: ' + (err?.message ?? ''));
    });
  }

  dispose(): void {
    super.dispose();
    if (this.historyObserverId >= 0) {
      SearchHistoryRepository.unsubscribe(this.historyObserverId);
      this.historyObserverId = -1;
    }
  }

  /** GoodsRoutes.Category(typeId = null, featured = false, recommend = false, keyword = keyword) */
  private toCategory(keyword: string): void {
    if (this.disposed) {
      return;
    }
    const param = new GoodsCategoryParam();
    param.typeId = null;
    param.featured = false;
    param.recommend = false;
    param.keyword = keyword;
    AppNavigator.navigate(Routes.GOODS_ROUTES_CATEGORY, param);
  }
}
