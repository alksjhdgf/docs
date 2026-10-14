/**
 * NetworkResult.ets —— 网络调用结果（成功 / HttpError(code) / NetworkError）与可抛出的网络异常。
 * 源：OkHttp 的 IOException 语义（Call.execute 失败抛 IOException）+ FeedParser.kt 的 HttpError(code,message,retryAfterSeconds)。
 * 调用方用 NetworkResult 承接，不让异常穿透 UI（conventions §C）。
 * 注意：Error 子类实例赋给 `Error` 型变量/形参时写 `e as Object as Error`。
 */

/** 网络层 IO 失败（连接失败、超时、DNS、TLS、读失败…）。对应 OkHttp 抛出的 IOException。 */
export class NetworkIOException extends Error {
  /** @kit.NetworkKit BusinessError.code（如 2300028 超时）；未知为 -1 */
  readonly errorCode: number;
  readonly url: string;

  constructor(message: string, url: string, errorCode: number) {
    super(message);
    this.name = 'NetworkIOException';
    this.url = url;
    this.errorCode = errorCode;
  }
}

/** 非 2xx 响应被调用方当作异常抛出时使用（源 HtmlUtils.fetchOgImage 等 `!isSuccessful` 抛 IOException 的场景）。 */
export class HttpStatusException extends Error {
  readonly code: number;
  readonly url: string;
  readonly retryAfterSeconds: number | null;

  constructor(code: number, message: string, url: string, retryAfterSeconds: number | null) {
    super(`${code}: ${message}`);
    this.name = 'HttpStatusException';
    this.code = code;
    this.url = url;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

/** 网络调用结果（密封族）：NetworkSuccess / NetworkHttpError / NetworkError */
export abstract class NetworkResult<T> {
  abstract isSuccess(): boolean;

  asSuccess(): NetworkSuccess<T> | null {
    return this instanceof NetworkSuccess ? this as NetworkResult<T> as NetworkSuccess<T> : null;
  }

  asHttpError(): NetworkHttpError<T> | null {
    return this instanceof NetworkHttpError ? this as NetworkResult<T> as NetworkHttpError<T> : null;
  }

  asNetworkError(): NetworkError<T> | null {
    return this instanceof NetworkError ? this as NetworkResult<T> as NetworkError<T> : null;
  }

  /** 成功值，失败为 null */
  getOrNull(): T | null {
    const s = this.asSuccess();
    return s !== null ? s.value : null;
  }

  /** 简短描述（日志/提示用） */
  abstract describe(): string;
}

export class NetworkSuccess<T> extends NetworkResult<T> {
  readonly value: T;

  constructor(value: T) {
    super();
    this.value = value;
  }

  isSuccess(): boolean {
    return true;
  }

  describe(): string {
    return 'success';
  }
}

/** HTTP 非成功状态码。message 为状态行原因短语（可能为空串）。 */
export class NetworkHttpError<T> extends NetworkResult<T> {
  readonly code: number;
  readonly message: string;
  readonly url: string;
  /** 源 Response.retryAfterSeconds：所有 retry-after 头取最大，非数字按 3600；无此头为 null */
  readonly retryAfterSeconds: number | null;

  constructor(code: number, message: string, url: string, retryAfterSeconds: number | null) {
    super();
    this.code = code;
    this.message = message;
    this.url = url;
    this.retryAfterSeconds = retryAfterSeconds;
  }

  isSuccess(): boolean {
    return false;
  }

  /** 源 HttpError.description = "$code: $message" */
  describe(): string {
    return `${this.code}: ${this.message}`;
  }
}

/** 网络 IO 失败（无 HTTP 响应） */
export class NetworkError<T> extends NetworkResult<T> {
  readonly error: Error;
  readonly url: string;

  constructor(error: Error, url: string) {
    super();
    this.error = error;
    this.url = url;
  }

  isSuccess(): boolean {
    return false;
  }

  describe(): string {
    return this.error.message;
  }
}

/** 把任意捕获值规整为 Error（catch 形参不标类型时使用） */
export function toError(e: Object | null | undefined): Error {
  if (e instanceof Error) {
    return e as Error;
  }
  if (e === null || e === undefined) {
    return new Error('unknown error');
  }
  return new Error(String(e));
}
