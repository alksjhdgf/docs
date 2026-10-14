/**
 * SearchFeedViewModel.ets —— 源 ui/compose/searchfeed/SearchFeedViewModel.kt + SearchFeedScreen.kt 中
 * SearchFeedView（有状态层）的状态与回调（feedUrl/currentlySearching/results/errors/suggestions/currentSearchJob）。
 *
 * 搜索（源 searchForFeeds，EF-A15..A18）：
 *  1. getSiteMetaData(输入 URL)：成功 → 每个 alternate 链接一个候选（YouTube channel feed 紧随 UULF/UUSH/UULV 三个播放列表候选），
 *     无 alternate → 错误 NoAlternateFeeds(输入URL)；失败 → （HttpError 先处理 Retry-After）输入 URL 本身作为候选。
 *     （发现段由 core/sync/FeedFetcher.findFeedUrls 实现。）
 *  2. 每个候选 parseFeedUrl：成功 → SearchResult(title ?: "", feed_url ?: 候选, description ?: "", siteMetaData.feedImage ?: "")；
 *     若站点元数据此前失败且订阅含 home_page_url → 改抓主页站点元数据（后续候选沿用）；失败 → 错误（HttpError 处理 Retry-After）。
 *  3. 结果/错误逐条追加；搜索结束（且仍是当前搜索）→ currentlySearching=false。
 * 输入变化（源 onUrlChange）：取消进行中搜索、清空结果与错误、隐藏进度（EF-A07），并驱动 150ms 防抖推荐（EF-A11）。
 */
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { isBlankString } from '../../core/model/Feed';
import { ParsedFeed, SiteMetaData } from '../../core/model/Parsed';
import { HttpClient } from '../../core/net/HttpClient';
import { FeedParserError } from '../../core/parser/FeedParserError';
import {
  FeedUrlCandidates, findFeedUrls, getSiteMetaData, handleHttpErrorRetryAfter, parseFeedUrl
} from '../../core/sync/FeedFetcher';
import { Either } from '../../core/util/Either';
import { JavaUrl, MalformedURLException } from '../../core/util/JavaCompat';
import { sloppyLinkToStrictURLNoThrows, sloppyLinkToStrictURLOrNull } from '../../core/util/LinkUtils';
import { FeedSuggestions, SuggestionDebouncer } from './FeedSuggestions';
import { SearchResult } from './SearchResult';

export { SearchResult };

const LOG_TAG: string = 'FEEDER_SearchFeed';

/**
 * 源 isValidUrl：空白 → false；URL(url) 成功 → true；MalformedURLException → 再试 URL("http://$url")；其余异常 → false。
 */
export function isValidFeedSearchUrl(url: string): boolean {
  if (isBlankString(url)) {
    return false;
  }
  try {
    JavaUrl.parse(url);
    return true;
  } catch (e) {
    if (!(e instanceof MalformedURLException)) {
      return false;
    }
  }
  try {
    JavaUrl.parse('http://' + url);
    return true;
  } catch (e2) {
    return false;
  }
}

/** 源 leftContent.isNotValidUrl：非空且不合法 → 输入框错误态（EF-A04） */
export function isFeedSearchUrlError(url: string): boolean {
  return url.length > 0 && !isValidFeedSearchUrl(url);
}

/** 源 SearchResult → AddFeed 导航参数提供者（错误卡 `Add anyway`：title=url=错误 URL，图片空） */
export function addAnywayResult(error: FeedParserError): SearchResult {
  return SearchResult.of(error.url, error.url, '', '');
}

/** 搜索任务的取消令牌（源 Job） */
class SearchJob {
  cancelled: boolean = false;
}

@ObservedV2
export class SearchFeedViewModel {
  @Trace feedUrl: string = '';
  @Trace currentlySearching: boolean = false;
  @Trace results: SearchResult[] = [];
  @Trace errors: FeedParserError[] = [];
  @Trace suggestions: SearchResult[] = [];

  private currentSearchJob: SearchJob | null = null;
  private debouncer: SuggestionDebouncer | null = null;
  private initialized: boolean = false;
  private disposed: boolean = false;

  /** 源 errors = if (currentlySearching) emptyList() else errors（EF-A06） */
  @Computed
  get visibleErrors(): FeedParserError[] {
    return this.currentlySearching ? [] : this.errors;
  }

  @Computed
  get isValidUrl(): boolean {
    return isValidFeedSearchUrl(this.feedUrl);
  }

  @Computed
  get isNotValidUrl(): boolean {
    return isFeedSearchUrlError(this.feedUrl);
  }

  /**
   * 首次进入（源 rememberSaveable { initialFeedUrl } + LaunchedEffect(Unit)/LaunchedEffect(initialFeedUrl)）：
   * 预填输入框、启动推荐防抖（首值即参与）、预加载推荐数据；预填非空且合法 → 自动搜索（EF-A13/A20）。幂等。
   */
  initialize(initialFeedUrl: string): void {
    if (this.initialized || this.disposed) {
      return;
    }
    this.initialized = true;
    this.feedUrl = initialFeedUrl;
    this.debouncer = new SuggestionDebouncer((results: SearchResult[]) => {
      if (!this.disposed) {
        this.suggestions = results;
      }
    });
    FeedSuggestions.instance().preload().catch((e: Error) => {
      console.warn(`${LOG_TAG}: preload suggestions failed: ${e?.message}`);
    });
    this.debouncer.submit(this.feedUrl);
    if (!isBlankString(initialFeedUrl) &&
      this.feedUrl === initialFeedUrl &&
      this.results.length === 0 &&
      this.errors.length === 0 &&
      isValidFeedSearchUrl(initialFeedUrl)) {
      this.search(sloppyLinkToStrictURLNoThrows(initialFeedUrl));
    }
  }

  /** 源 onUrlChange（EF-A07） */
  onUrlChange(newUrl: string): void {
    const changed: boolean = newUrl !== this.feedUrl;
    this.feedUrl = newUrl;
    this.cancelCurrentJob();
    this.currentlySearching = false;
    this.results = [];
    this.errors = [];
    if (changed && this.debouncer !== null) {
      this.debouncer.submit(newUrl);
    }
  }

  /** 当前输入合法时发起搜索（按钮/IME 搜索键/硬件 Enter，EF-A05）；返回是否已发起 */
  searchCurrentInput(): boolean {
    if (!isValidFeedSearchUrl(this.feedUrl)) {
      return false;
    }
    try {
      this.search(sloppyLinkToStrictURLNoThrows(this.feedUrl));
      return true;
    } catch (e) {
      console.error(`${LOG_TAG}: Can't search: ${(e as Error)?.message}`);
      return false;
    }
  }

  /** 源 onSearch(url) */
  search(url: JavaUrl): void {
    this.results = [];
    this.errors = [];
    this.currentlySearching = true;
    this.cancelCurrentJob();
    const job: SearchJob = new SearchJob();
    this.currentSearchJob = job;
    this.runSearch(url, job).catch((e: Error) => {
      console.error(`${LOG_TAG}: search failed: ${e?.message}`);
    }).finally(() => {
      // 源 job.invokeOnCompletion { if (currentSearchJob == job) currentlySearching = false }
      if (this.currentSearchJob === job) {
        this.currentlySearching = false;
      }
    });
  }

  private cancelCurrentJob(): void {
    const job: SearchJob | null = this.currentSearchJob;
    if (job !== null) {
      job.cancelled = true;
    }
    this.currentSearchJob = null;
  }

  private isActive(job: SearchJob): boolean {
    return !job.cancelled && !this.disposed;
  }

  private appendResult(job: SearchJob, r: SearchResult): void {
    if (this.isActive(job)) {
      this.results = this.results.concat([r]);
    }
  }

  private appendError(job: SearchJob, e: FeedParserError): void {
    if (this.isActive(job)) {
      this.errors = this.errors.concat([e]);
    }
  }

  /** 源 searchForFeeds(initialUrl).collect { … } */
  private async runSearch(initialUrl: JavaUrl, job: SearchJob): Promise<void> {
    await AppBootstrap.ready();
    if (!this.isActive(job)) {
      return;
    }
    const client: HttpClient = HttpClient.main();
    const found: FeedUrlCandidates = await findFeedUrls(initialUrl, client);
    let siteMetaData: Either<FeedParserError, SiteMetaData> = found.siteMetaData;
    for (let i = 0; i < found.candidates.length; i++) {
      if (!this.isActive(job)) {
        return;
      }
      const candidate: Either<FeedParserError, string> = found.candidates[i];
      const candidateError: FeedParserError | null = candidate.leftOrNull();
      if (candidateError !== null) {
        this.appendError(job, candidateError);
        continue;
      }
      const url: string | null = candidate.getOrNull();
      if (url === null) {
        continue;
      }
      const parsed: Either<FeedParserError, ParsedFeed> = await parseFeedUrl(client, url);
      if (!this.isActive(job)) {
        return;
      }
      const feed: ParsedFeed | null = parsed.getOrNull();
      if (feed !== null) {
        if (siteMetaData.isLeft()) {
          const pageLink: string | null = feed.home_page_url;
          if (pageLink !== null) {
            const pageUrl: JavaUrl | null = sloppyLinkToStrictURLOrNull(pageLink);
            if (pageUrl !== null) {
              siteMetaData = await getSiteMetaData(pageUrl, client);
              if (!this.isActive(job)) {
                return;
              }
            }
          }
        }
        const md: SiteMetaData | null = siteMetaData.getOrNull();
        const image: string | null = md !== null ? md.feedImage : null;
        this.appendResult(job, SearchResult.of(
          feed.title !== null ? feed.title : '',
          feed.feed_url !== null ? feed.feed_url : url,
          feed.description !== null ? feed.description : '',
          image !== null ? image : ''
        ));
      } else {
        const err: FeedParserError | null = parsed.leftOrNull();
        if (err !== null) {
          await handleHttpErrorRetryAfter(err);
          this.appendError(job, err);
        }
      }
    }
  }

  /** aboutToDisappear：取消搜索与防抖计时器 */
  dispose(): void {
    this.disposed = true;
    this.cancelCurrentJob();
    if (this.debouncer !== null) {
      this.debouncer.dispose();
      this.debouncer = null;
    }
  }
}
