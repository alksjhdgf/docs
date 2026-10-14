/**
 * FeedParserError.ets —— 源 model/FeedParser.kt:479-585 的错误族（sealed class FeedParserError）。
 * 全文抓取（FullTextParser）与订阅源抓取/发现（core/sync FeedFetcher）、SearchFeed/EditFeed 错误卡共用；
 * fnd-html-linear 先落地于此，其它单元直接 import（不要重复定义）。
 * 判别：instanceof 子类，或读 kind 字段（与源类名一致）。
 */

export enum FeedParserErrorKind {
  NOT_INITIALIZED_YET = 'NotInitializedYet',
  FETCH_ERROR = 'FetchError',
  NOT_HTML = 'NotHTML',
  META_DATA_PARSE_ERROR = 'MetaDataParseError',
  RSS_PARSE_ERROR = 'RSSParseError',
  JSON_FEED_PARSE_ERROR = 'JsonFeedParseError',
  NO_ALTERNATE_FEEDS = 'NoAlternateFeeds',
  HTTP_ERROR = 'HttpError',
  UNSUPPORTED_CONTENT_TYPE = 'UnsupportedContentType',
  NO_BODY = 'NoBody',
  NO_URL = 'NoUrl',
  FULL_TEXT_DECODING_FAILURE = 'FullTextDecodingFailure',
  FULL_TEXT_TOO_LARGE = 'FullTextTooLarge'
}

function messageOf(t: Error | null): string {
  return t !== null && t.message !== undefined && t.message !== null ? t.message : '';
}

export abstract class FeedParserError {
  readonly kind: FeedParserErrorKind;
  readonly url: string;
  readonly description: string;
  readonly throwable: Error | null;

  constructor(kind: FeedParserErrorKind, url: string, description: string, throwable: Error | null) {
    this.kind = kind;
    this.url = url;
    this.description = description;
    this.throwable = throwable;
  }

  toString(): string {
    return this.kind + '(url=' + this.url + ', description=' + this.description + ')';
  }
}

export class NotInitializedYet extends FeedParserError {
  constructor() {
    super(FeedParserErrorKind.NOT_INITIALIZED_YET, '', '', null);
  }
}

export class FetchError extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super(FeedParserErrorKind.FETCH_ERROR, url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class NotHTML extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super(FeedParserErrorKind.NOT_HTML, url, description, throwable);
  }
}

export class MetaDataParseError extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super(FeedParserErrorKind.META_DATA_PARSE_ERROR, url, description !== null ? description : messageOf(throwable),
      throwable);
  }
}

export class RSSParseError extends FeedParserError {
  constructor(throwable: Error | null, url: string, description: string | null = null) {
    super(FeedParserErrorKind.RSS_PARSE_ERROR, url, description !== null ? description : messageOf(throwable),
      throwable);
  }
}

export class JsonFeedParseError extends FeedParserError {
  constructor(throwable: Error | null, url: string, description: string | null = null) {
    super(FeedParserErrorKind.JSON_FEED_PARSE_ERROR, url, description !== null ? description : messageOf(throwable),
      throwable);
  }
}

export class NoAlternateFeeds extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super(FeedParserErrorKind.NO_ALTERNATE_FEEDS, url, description, throwable);
  }
}

export class HttpError extends FeedParserError {
  readonly code: number;
  readonly message: string;
  readonly retryAfterSeconds: number | null;

  constructor(url: string, code: number, message: string, retryAfterSeconds: number | null,
    description: string | null = null, throwable: Error | null = null) {
    super(FeedParserErrorKind.HTTP_ERROR, url, description !== null ? description : code + ': ' + message, throwable);
    this.code = code;
    this.message = message;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export class UnsupportedContentType extends FeedParserError {
  readonly mimeType: string;

  constructor(url: string, mimeType: string, description: string | null = null, throwable: Error | null = null) {
    super(FeedParserErrorKind.UNSUPPORTED_CONTENT_TYPE, url, description !== null ? description : mimeType, throwable);
    this.mimeType = mimeType;
  }
}

export class NoBody extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super(FeedParserErrorKind.NO_BODY, url, description, throwable);
  }
}

export class NoUrl extends FeedParserError {
  constructor(description: string = '', url: string = '', throwable: Error | null = null) {
    super(FeedParserErrorKind.NO_URL, url, description, throwable);
  }
}

export class FullTextDecodingFailure extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super(FeedParserErrorKind.FULL_TEXT_DECODING_FAILURE, url,
      description !== null ? description : messageOf(throwable), throwable);
  }
}

export class FullTextTooLarge extends FeedParserError {
  readonly maxBytes: number;

  constructor(url: string, maxBytes: number, description: string | null = null, throwable: Error | null = null) {
    super(FeedParserErrorKind.FULL_TEXT_TOO_LARGE, url,
      description !== null ? description : 'Response body exceeded ' + maxBytes + ' bytes', throwable);
    this.maxBytes = maxBytes;
  }
}
