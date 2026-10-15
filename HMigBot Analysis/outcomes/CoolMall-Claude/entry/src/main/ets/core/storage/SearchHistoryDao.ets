/**
 * SearchHistoryDao — Room SearchHistoryDao + SearchHistoryDataSource equivalent
 * (source: core/database/dao/SearchHistoryDao.kt, datasource/searchhistory/SearchHistoryDataSource.kt,
 * trim/blank rule from core/data/repository/SearchHistoryRepository.kt).
 * DATA-A17: trimmed keyword is the PK (blank ignored, repeat search refreshes searchTime via REPLACE),
 * ordered by searchTime DESC, search page shows getRecentSearchHistory(10).
 */
import { relationalStore } from '@kit.ArkData';
import { SearchHistory } from '../model/Market';
import { AppDatabase } from './AppDatabase';
import { DaoChangeNotifier } from './DaoChangeNotifier';

const TAG: string = 'SearchHistoryDao';

export class SearchHistoryDao {
  static readonly instance: SearchHistoryDao = new SearchHistoryDao();
  /** GoodsSearchViewModel: getRecentSearchHistory(10) */
  static readonly SEARCH_RECENT_LIMIT: number = 10;

  private notifier: DaoChangeNotifier = new DaoChangeNotifier(TAG);

  private constructor() {
  }

  subscribe(cb: () => void): number {
    return this.notifier.subscribe(cb);
  }

  unsubscribe(id: number): void {
    this.notifier.unsubscribe(id);
  }

  private static readRows(rs: relationalStore.ResultSet): SearchHistory[] {
    const list: SearchHistory[] = [];
    try {
      const iKey = rs.getColumnIndex('keyword');
      const iTime = rs.getColumnIndex('searchTime');
      while (rs.goToNextRow()) {
        const h = new SearchHistory();
        h.keyword = rs.getString(iKey);
        h.searchTime = rs.getLong(iTime);
        list.push(h);
      }
    } finally {
      rs.close();
    }
    return list;
  }

  /** @Insert(onConflict = REPLACE) — raw insert, keyword stored as given */
  async insertSearchHistory(searchHistory: SearchHistory): Promise<void> {
    const store = await AppDatabase.getStore();
    const vb: relationalStore.ValuesBucket = {
      'keyword': searchHistory.keyword,
      'searchTime': searchHistory.searchTime
    };
    await store.insert(AppDatabase.TABLE_SEARCH_HISTORY, vb, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    this.notifier.notifyChanged();
  }

  /**
   * SearchHistoryRepository.addSearchHistory: blank keyword ignored; otherwise stores keyword.trim()
   * with the current time (dedupe via PK REPLACE).
   */
  async addSearchHistory(keyword: string): Promise<void> {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) {
      return;
    }
    const h = new SearchHistory();
    h.keyword = trimmed;
    h.searchTime = Date.now();
    await this.insertSearchHistory(h);
  }

  async deleteSearchHistoryByKeyword(keyword: string): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM search_history WHERE keyword = ?', [keyword]);
    this.notifier.notifyChanged();
  }

  async removeSearchHistory(keyword: string): Promise<void> {
    await this.deleteSearchHistoryByKeyword(keyword);
  }

  async clearAllSearchHistory(): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM search_history');
    this.notifier.notifyChanged();
  }

  async getAllSearchHistory(): Promise<SearchHistory[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM search_history ORDER BY searchTime DESC');
    return SearchHistoryDao.readRows(rs);
  }

  async getSearchHistoryCount(): Promise<number> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT COUNT(*) AS cnt FROM search_history');
    let count = 0;
    try {
      if (rs.goToFirstRow()) {
        count = rs.getLong(0);
      }
    } finally {
      rs.close();
    }
    return count;
  }

  async getRecentSearchHistory(limit: number = SearchHistoryDao.SEARCH_RECENT_LIMIT): Promise<SearchHistory[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM search_history ORDER BY searchTime DESC LIMIT ?', [limit]);
    return SearchHistoryDao.readRows(rs);
  }

  async getSearchHistoryByKeyword(keyword: string): Promise<SearchHistory | null> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM search_history WHERE keyword = ?', [keyword]);
    const list = SearchHistoryDao.readRows(rs);
    return list.length > 0 ? list[0] : null;
  }
}
