/**
 * SearchResult.ets —— 源 ui/compose/searchfeed/SearchFeedScreen.kt `data class SearchResult`
 * （feedImage 为空串而非 null，因为要进查询参数）。
 */
export class SearchResult {
  title: string = '';
  url: string = '';
  description: string = '';
  feedImage: string = '';

  static of(title: string, url: string, description: string, feedImage: string): SearchResult {
    const r: SearchResult = new SearchResult();
    r.title = title;
    r.url = url;
    r.description = description;
    r.feedImage = feedImage;
    return r;
  }
}
