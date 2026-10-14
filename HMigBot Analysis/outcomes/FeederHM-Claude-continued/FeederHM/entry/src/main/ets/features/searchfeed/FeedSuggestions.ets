/**
 * FeedSuggestions.ets —— 源 data/suggestions/SuggestedFeedRepository.kt（离线订阅源推荐）+
 * SearchFeedViewModel.suggestionsFor / ensureSuggestionsLoaded。
 *
 * - 数据：rawfile `feeds_mapped.json`（源 res/raw/feeds_mapped，约 5.7MB）；主线程只读字节，
 *   解码 + JSON 解析 + 规范化文本预计算在 taskpool 中完成（源 Dispatchers.IO lazy 加载），进程内只加载一次；
 *   任何失败 → 空列表，不崩溃（SS-A30）。
 * - search(query)：见 SuggestionsIndex.searchSuggestedFeeds（SS-A31..A33）。
 * - suggestionsFor(query)：先确保已加载；空白 → 空；结果映射为 SearchResult：
 *   title=headline、url=feed_url、description=作者（仅当非空白且 headline 不含作者名（忽略大小写））、feedImage=""（SS-A34）。
 * - SuggestionDebouncer：源 snapshotFlow{feedUrl}.debounce(150).collectLatest（<2 字符 → 空），EF-A11。
 */
import { taskpool } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { isBlankString } from '../../core/model/Feed';
import {
  DEFAULT_RESULT_LIMIT, SuggestedFeed, parseSuggestedFeedsBytes, searchSuggestedFeeds
} from './SuggestionsIndex';
import { SearchResult } from './SearchResult';

export { SuggestedFeed };

const LOG_TAG: string = 'FEEDER_SUGGESTIONS';
export const SUGGESTED_FEEDS_RAWFILE: string = 'feeds_mapped.json';
export const SUGGESTION_DEBOUNCE_MS: number = 150;
export const SUGGESTION_MIN_QUERY_LENGTH: number = 2;

/** taskpool 工作函数：UTF-8 字节 → SuggestedFeed[]（失败返回空数组） */
@Concurrent
function parseSuggestionsTask(bytes: Uint8Array): SuggestedFeed[] {
  return parseSuggestedFeedsBytes(bytes);
}

/** Kotlin String.contains(other, ignoreCase = true) 近似：双方 toLowerCase 后包含 */
function containsIgnoreCase(haystack: string, needle: string): boolean {
  return haystack.toLowerCase().includes(needle.toLowerCase());
}

/** 源 suggestionsFor 的映射段（SS-A34） */
export function suggestionToSearchResult(feed: SuggestedFeed): SearchResult {
  const author: string = feed.authorName;
  const showAuthor: boolean = !isBlankString(author) && !containsIgnoreCase(feed.headline, author);
  return SearchResult.of(feed.headline, feed.feedUrl, showAuthor ? author : '', '');
}

export class FeedSuggestions {
  private static inst: FeedSuggestions | null = null;

  private feeds: SuggestedFeed[] = [];
  private loadPromise: Promise<void> | null = null;
  private loaded: boolean = false;

  static instance(): FeedSuggestions {
    if (FeedSuggestions.inst === null) {
      FeedSuggestions.inst = new FeedSuggestions();
    }
    return FeedSuggestions.inst as FeedSuggestions;
  }

  /** 单测/预置数据用：直接注入数据集 */
  setFeedsForTest(feeds: SuggestedFeed[]): void {
    this.feeds = feeds;
    this.loaded = true;
    this.loadPromise = Promise.resolve();
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  /** 源 preload / ensureSuggestionsLoaded：幂等；ctx 缺省取 AppBootstrap.context() */
  preload(ctx: common.Context | null = null): Promise<void> {
    if (this.loadPromise !== null) {
      return this.loadPromise as Promise<void>;
    }
    const p: Promise<void> = this.load(ctx);
    this.loadPromise = p;
    return p;
  }

  private async load(ctx: common.Context | null): Promise<void> {
    let feeds: SuggestedFeed[] = [];
    try {
      const c: common.Context | null = ctx !== null ? ctx : AppBootstrap.context();
      if (c === null) {
        console.warn(`${LOG_TAG}: no context; suggestions disabled`);
      } else {
        const bytes: Uint8Array = await c.resourceManager.getRawFileContent(SUGGESTED_FEEDS_RAWFILE);
        try {
          const result: Object = await taskpool.execute(parseSuggestionsTask, bytes);
          feeds = result as SuggestedFeed[];
        } catch (e) {
          // taskpool 不可用（如主机侧单测）→ 同步解析兜底
          console.warn(`${LOG_TAG}: taskpool parse failed, parsing inline: ${(e as Error)?.message}`);
          feeds = parseSuggestedFeedsBytes(bytes);
        }
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: failed to load ${SUGGESTED_FEEDS_RAWFILE}: ${(e as Error)?.message}`);
      feeds = [];
    }
    this.feeds = Array.isArray(feeds) ? feeds : [];
    this.loaded = true;
  }

  /** 源 SuggestedFeedRepository.search（需已加载；未加载时按空数据集） */
  search(query: string, limit: number = DEFAULT_RESULT_LIMIT): SuggestedFeed[] {
    return searchSuggestedFeeds(this.feeds, query, limit);
  }

  /** 源 SearchFeedViewModel.suggestionsFor */
  async suggestionsFor(query: string): Promise<SearchResult[]> {
    await this.preload();
    if (isBlankString(query)) {
      return [];
    }
    return this.search(query).map((f: SuggestedFeed): SearchResult => suggestionToSearchResult(f));
  }
}

/**
 * 源 snapshotFlow { feedUrl }.debounce(150).collectLatest { … }：
 * 每次输入变化重置 150ms 计时；到时 <2 字符 → 空，否则查询；较新的输入到来时丢弃旧查询结果（collectLatest）。
 */
export class SuggestionDebouncer {
  private timer: number = -1;
  private generation: number = 0;
  private disposed: boolean = false;
  private onResult: (results: SearchResult[]) => void;

  constructor(onResult: (results: SearchResult[]) => void) {
    this.onResult = onResult;
  }

  submit(query: string): void {
    if (this.disposed) {
      return;
    }
    this.generation++;
    const gen: number = this.generation;
    if (this.timer !== -1) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.run(query, gen);
    }, SUGGESTION_DEBOUNCE_MS);
  }

  private run(query: string, gen: number): void {
    if (query.length < SUGGESTION_MIN_QUERY_LENGTH) {
      this.deliver([], gen);
      return;
    }
    FeedSuggestions.instance().suggestionsFor(query).then((results: SearchResult[]) => {
      this.deliver(results, gen);
    }).catch((e: Error) => {
      console.warn(`${LOG_TAG}: suggestionsFor failed: ${e?.message}`);
    });
  }

  private deliver(results: SearchResult[], gen: number): void {
    if (this.disposed || gen !== this.generation) {
      return;
    }
    this.onResult(results);
  }

  dispose(): void {
    this.disposed = true;
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }
}
