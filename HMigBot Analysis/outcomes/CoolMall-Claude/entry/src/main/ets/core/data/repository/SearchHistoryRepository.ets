/**
 * SearchHistoryRepository (source: core/data/repository/SearchHistoryRepository.kt → SearchHistoryDao).
 * Table `search_history`, keyword PK (trimmed; blank ignored; repeat refreshes searchTime), ordered by
 * searchTime DESC, search page shows the latest 10 (DATA-A17).
 * Room Flow observation is replaced by subscribe/unsubscribe and observe* helpers.
 */
import { SearchHistory } from '../../model/Market';
import { SearchHistoryDao } from '../../storage/SearchHistoryDao';
import { QueryObserver } from './QueryObserver';

export class SearchHistoryRepository {
  /** Search page shows the latest 10 keywords */
  static readonly SEARCH_RECENT_LIMIT: number = SearchHistoryDao.SEARCH_RECENT_LIMIT;

  /** Blank keyword ignored; stores keyword.trim() with the current time */
  static addSearchHistory(keyword: string): Promise<void> {
    return SearchHistoryDao.instance.addSearchHistory(keyword);
  }

  static removeSearchHistory(keyword: string): Promise<void> {
    return SearchHistoryDao.instance.removeSearchHistory(keyword);
  }

  static clearAllSearchHistory(): Promise<void> {
    return SearchHistoryDao.instance.clearAllSearchHistory();
  }

  static getAllSearchHistory(): Promise<SearchHistory[]> {
    return SearchHistoryDao.instance.getAllSearchHistory();
  }

  static getSearchHistoryCount(): Promise<number> {
    return SearchHistoryDao.instance.getSearchHistoryCount();
  }

  static getRecentSearchHistory(limit: number): Promise<SearchHistory[]> {
    return SearchHistoryDao.instance.getRecentSearchHistory(limit);
  }

  static getSearchHistoryByKeyword(keyword: string): Promise<SearchHistory | null> {
    return SearchHistoryDao.instance.getSearchHistoryByKeyword(keyword);
  }

  /** Raw change subscription: cb is called after every write to `search_history`. */
  static subscribe(cb: () => void): number {
    return SearchHistoryDao.instance.subscribe(cb);
  }

  static unsubscribe(id: number): void {
    SearchHistoryDao.instance.unsubscribe(id);
  }

  /** Flow equivalent of getAllSearchHistory() */
  static observeAllSearchHistory(onData: (list: SearchHistory[]) => void): number {
    return QueryObserver.observe<SearchHistory[]>(
      (cb: () => void): number => SearchHistoryDao.instance.subscribe(cb),
      (): Promise<SearchHistory[]> => SearchHistoryDao.instance.getAllSearchHistory(), onData);
  }

  /** Flow equivalent of getRecentSearchHistory(limit) */
  static observeRecentSearchHistory(limit: number, onData: (list: SearchHistory[]) => void): number {
    return QueryObserver.observe<SearchHistory[]>(
      (cb: () => void): number => SearchHistoryDao.instance.subscribe(cb),
      (): Promise<SearchHistory[]> => SearchHistoryDao.instance.getRecentSearchHistory(limit), onData);
  }
}
