/**
 * SuggestionsIndex.ets —— 源 data/suggestions/SuggestedFeedRepository.kt 的纯逻辑部分（可在 taskpool 中调用）：
 *  - tokenize：`[\p{L}\p{N}']+` 全部匹配，逐个 lowercase(Locale.ROOT)；
 *  - normalizeForTextMatch：词元以单空格连接；
 *  - toSearchableUrlText：`https://<name>.substack.com/feed[/]`（忽略大小写，trim 后整串匹配）→ `<name>`（SS-A32）；
 *  - SuggestedFeed：headline / author_name / feed_url / total_subscribers（非数字 → 0）及预计算规范化文本；
 *  - searchSuggestedFeeds：查询 <2 → 空；无 ≥2 的词元 → 空；标题/作者/URL 规范化文本包含查询规范化文本 →
 *    按订阅数降序（稳定排序）取前 limit（默认 10）（SS-A31/A33）。
 * 源 scoreFeed 计算的其余打分字段（exact/tokenMatches/urlPartial…）不参与过滤与排序，结果等价，故不复刻。
 */
import { decodeUtf8 } from '../../core/util/TextCodec';

export const MIN_SEARCH_LENGTH: number = 2;
export const MIN_TOKEN_LENGTH: number = 2;
export const DEFAULT_RESULT_LIMIT: number = 10;

const WORD_PATTERN: string = '[\\p{L}\\p{N}\']+';
const SUBSTACK_FEED_PATTERN: string = '^https://([\\p{L}\\p{N}-]+)\\.substack\\.com/feed/?$';

const INT_MAX: number = 2147483647;
const INT_MIN: number = -2147483648;

/** 源 tokenize */
export function tokenizeSuggestion(text: string): string[] {
  const re: RegExp = new RegExp(WORD_PATTERN, 'gu');
  const m: RegExpMatchArray | null = text.match(re);
  const out: string[] = [];
  if (m === null) {
    return out;
  }
  for (let i = 0; i < m.length; i++) {
    out.push(m[i].toLowerCase());
  }
  return out;
}

/** 源 normalizeForTextMatch */
export function normalizeForTextMatch(text: string): string {
  return tokenizeSuggestion(text).join(' ');
}

/** 源 String.toSearchableUrlText */
export function toSearchableUrlText(url: string): string {
  const re: RegExp = new RegExp(SUBSTACK_FEED_PATTERN, 'iu');
  const m: RegExpMatchArray | null = url.trim().match(re);
  if (m !== null && m[1] !== undefined) {
    return m[1];
  }
  return url;
}

/** Kotlin String.toIntOrNull() ?: 0（十进制、可带 +/- 号、Int 范围） */
export function kotlinToIntOrZero(raw: string): number {
  if (raw.length === 0) {
    return 0;
  }
  let start: number = 0;
  const first: string = raw.charAt(0);
  if (first === '-' || first === '+') {
    if (raw.length === 1) {
      return 0;
    }
    start = 1;
  }
  for (let i = start; i < raw.length; i++) {
    const c: number = raw.charCodeAt(i);
    if (c < 48 || c > 57) {
      return 0;
    }
  }
  const v: number = parseInt(raw, 10);
  if (isNaN(v) || v > INT_MAX || v < INT_MIN) {
    return 0;
  }
  return v;
}

/** JSON 原始条目（字段可能缺失） */
export interface RawSuggestedFeed {
  headline?: string;
  author_name?: string;
  feed_url?: string;
  total_subscribers?: string;
}

/** 源 SuggestedFeed（含 @Transient 预计算字段中参与匹配的部分） */
export class SuggestedFeed {
  headline: string = '';
  authorName: string = '';
  feedUrl: string = '';
  totalSubscribersRaw: string = '';
  totalSubscribers: number = 0;
  normalizedHeadlineText: string = '';
  normalizedAuthorText: string = '';
  normalizedUrlText: string = '';

  static of(headline: string, authorName: string, feedUrl: string, totalSubscribersRaw: string): SuggestedFeed {
    const f: SuggestedFeed = new SuggestedFeed();
    f.headline = headline;
    f.authorName = authorName;
    f.feedUrl = feedUrl;
    f.totalSubscribersRaw = totalSubscribersRaw;
    f.totalSubscribers = kotlinToIntOrZero(totalSubscribersRaw);
    f.normalizedHeadlineText = normalizeForTextMatch(headline);
    f.normalizedAuthorText = normalizeForTextMatch(authorName);
    f.normalizedUrlText = normalizeForTextMatch(toSearchableUrlText(feedUrl));
    return f;
  }
}

function stringField(v: string | undefined): string | null {
  if (typeof v !== 'string') {
    return null;
  }
  return v as string;
}

/**
 * 源 json.decodeFromStream<List<SuggestedFeed>>：headline / feed_url 必填（缺失即整体解码失败 → 调用方得空列表），
 * author_name / total_subscribers 缺省为 ""。
 */
export function parseSuggestedFeedsJson(text: string): SuggestedFeed[] {
  const parsed: Object = JSON.parse(text) as Object;
  if (!(parsed instanceof Array)) {
    throw new Error('feeds_mapped: root is not an array');
  }
  const arr: RawSuggestedFeed[] = parsed as RawSuggestedFeed[];
  const out: SuggestedFeed[] = [];
  for (let i = 0; i < arr.length; i++) {
    const raw: RawSuggestedFeed = arr[i];
    const headline: string | null = stringField(raw.headline);
    const feedUrl: string | null = stringField(raw.feed_url);
    if (headline === null || feedUrl === null) {
      throw new Error(`feeds_mapped: missing required field at index ${i}`);
    }
    const author: string | null = stringField(raw.author_name);
    const subs: string | null = stringField(raw.total_subscribers);
    out.push(SuggestedFeed.of(headline, author !== null ? author : '', feedUrl, subs !== null ? subs : ''));
  }
  return out;
}

/** UTF-8 字节 → 解析；任何失败 → 空列表（源 runCatching.getOrElse { emptyList() }，SS-A30） */
export function parseSuggestedFeedsBytes(bytes: Uint8Array): SuggestedFeed[] {
  try {
    return parseSuggestedFeedsJson(decodeUtf8(bytes));
  } catch (e) {
    console.warn(`FEEDER_SUGGESTIONS: failed to load suggestions: ${(e as Error)?.message}`);
    return [];
  }
}

/** 源 SuggestedFeedRepository.search */
export function searchSuggestedFeeds(feeds: SuggestedFeed[], query: string,
  limit: number = DEFAULT_RESULT_LIMIT): SuggestedFeed[] {
  if (query.length < MIN_SEARCH_LENGTH) {
    return [];
  }
  const tokens: string[] = tokenizeSuggestion(query).filter((t: string): boolean => t.length >= MIN_TOKEN_LENGTH);
  if (tokens.length === 0) {
    return [];
  }
  const normalizedQueryText: string = normalizeForTextMatch(query);
  if (normalizedQueryText.length === 0) {
    return [];
  }
  const matched: SuggestedFeed[] = [];
  for (let i = 0; i < feeds.length; i++) {
    const f: SuggestedFeed = feeds[i];
    if (f.normalizedHeadlineText.includes(normalizedQueryText) ||
      f.normalizedAuthorText.includes(normalizedQueryText) ||
      f.normalizedUrlText.includes(normalizedQueryText)) {
      matched.push(f);
    }
  }
  // sortedByDescending 为稳定排序；Array.prototype.sort 稳定
  matched.sort((a: SuggestedFeed, b: SuggestedFeed): number => b.totalSubscribers - a.totalSubscribers);
  return matched.slice(0, Math.max(0, limit));
}
