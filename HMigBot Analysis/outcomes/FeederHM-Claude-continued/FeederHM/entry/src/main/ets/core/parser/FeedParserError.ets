/**
 * FeedParserError.ets —— 源 model/FeedParser.kt 的 `sealed class FeedParserError` 全族（url / description / throwable），
 * 以及 OkHttpClient.curlAndOnResponse / curl 两个获取辅助（FeedParser.kt:400-477）。
 *
 * 判别：`kind` 字段等于源类名（UI 按类型映射错误标题，见 EF-A10）。description 默认值照源：
 *  - FetchError / MetaDataParseError / RSSParseError / JsonFeedParseError / FullTextDecodingFailure：throwable?.message ?: ""
 *  - HttpError："$code: $message"；UnsupportedContentType：mimeType；FullTextTooLarge："Response body exceeded $maxBytes bytes"
 *  - 其余：""
 */
import { Either, Left, Right } from '../util/Either';
import { HttpClient } from '../net/HttpClient';
import { HttpResponse, MediaType } from '../net/HttpMessages';

export abstract class FeedParserError {
  /** 源类名（判别） */
  readonly kind: string;
  readonly url: string;
  readonly description: string;
  readonly throwable: Error | null;

  protected constructor(kind: string, url: string, description: string, throwable: Error | null) {
    this.kind = kind;
    this.url = url;
    this.description = description;
    this.throwable = throwable;
  }

  toString(): string {
    return `${this.kind}(url=${this.url}, description=${this.description})`;
  }
}

function messageOf(t: Error | null): string {
  if (t === null || t.message === undefined || t.message === null) {
    return '';
  }
  return t.message;
}

export class NotInitializedYet extends FeedParserError {
  constructor() {
    super('NotInitializedYet', '', '', null);
  }
}

export class FetchError extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super('FetchError', url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class NotHTML extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super('NotHTML', url, description, throwable);
  }
}

export class MetaDataParseError extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super('MetaDataParseError', url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class RSSParseError extends FeedParserError {
  constructor(throwable: Error | null, url: string, description: string | null = null) {
    super('RSSParseError', url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class JsonFeedParseError extends FeedParserError {
  constructor(throwable: Error | null, url: string, description: string | null = null) {
    super('JsonFeedParseError', url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class NoAlternateFeeds extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super('NoAlternateFeeds', url, description, throwable);
  }
}

export class HttpError extends FeedParserError {
  readonly code: number;
  readonly message: string;
  readonly retryAfterSeconds: number | null;

  constructor(url: string, code: number, message: string, retryAfterSeconds: number | null,
    description: string | null = null, throwable: Error | null = null) {
    super('HttpError', url, description !== null ? description : `${code}: ${message}`, throwable);
    this.code = code;
    this.message = message;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export class UnsupportedContentType extends FeedParserError {
  readonly mimeType: string;

  constructor(url: string, mimeType: string, description: string | null = null, throwable: Error | null = null) {
    super('UnsupportedContentType', url, description !== null ? description : mimeType, throwable);
    this.mimeType = mimeType;
  }
}

export class NoBody extends FeedParserError {
  constructor(url: string, description: string = '', throwable: Error | null = null) {
    super('NoBody', url, description, throwable);
  }
}

export class NoUrl extends FeedParserError {
  constructor(description: string = '', url: string = '', throwable: Error | null = null) {
    super('NoUrl', url, description, throwable);
  }
}

export class FullTextDecodingFailure extends FeedParserError {
  constructor(url: string, throwable: Error | null, description: string | null = null) {
    super('FullTextDecodingFailure', url, description !== null ? description : messageOf(throwable), throwable);
  }
}

export class FullTextTooLarge extends FeedParserError {
  readonly maxBytes: number;

  constructor(url: string, maxBytes: number, description: string | null = null, throwable: Error | null = null) {
    super('FullTextTooLarge', url, description !== null ? description : `Response body exceeded ${maxBytes} bytes`,
      throwable);
    this.maxBytes = maxBytes;
  }
}

/**
 * 源 OkHttpClient.curlAndOnResponse：getResponse 抛错 → FetchError；非 2xx → HttpError(url, code, message,
 * retryAfterSeconds)；否则交给 block。
 */
export async function curlAndOnResponse<T>(client: HttpClient, url: string,
  block: (response: HttpResponse) => Promise<Either<FeedParserError, T>>): Promise<Either<FeedParserError, T>> {
  let response: HttpResponse;
  try {
    response = await client.getResponse(url);
  } catch (t) {
    return new Left<FeedParserError, T>(new FetchError(url, t as Error));
  }
  if (response.isSuccessful()) {
    return block(response);
  }
  return new Left<FeedParserError, T>(new HttpError(url, response.code, response.message, response.retryAfterSeconds()));
}

/**
 * 源 OkHttpClient.curl：仅接受 text/plain 与 text/html，返回响应文本（按 BOM/Content-Type charset 解码）；
 * 其它类型（含无 Content-Type）→ UnsupportedContentType；读取失败 → FetchError；无 body → NoBody。
 */
export async function curl(client: HttpClient, url: string): Promise<Either<FeedParserError, string>> {
  return curlAndOnResponse<string>(client, url, async (response: HttpResponse): Promise<Either<FeedParserError, string>> => {
    const mt: MediaType | null = response.contentType();
    if (mt !== null && mt.type === 'text' && (mt.subtype === 'plain' || mt.subtype === 'html')) {
      if (response.body === null) {
        return new Left<FeedParserError, string>(new NoBody(url));
      }
      try {
        return new Right<FeedParserError, string>(response.text());
      } catch (t) {
        return new Left<FeedParserError, string>(new FetchError(url, t as Error));
      }
    }
    // 源 contentType.toString()：无（或无法解析的）Content-Type 时为 "null"
    return new Left<FeedParserError, string>(new UnsupportedContentType(url, mt !== null ? mt.toString() : 'null'));
  });
}
