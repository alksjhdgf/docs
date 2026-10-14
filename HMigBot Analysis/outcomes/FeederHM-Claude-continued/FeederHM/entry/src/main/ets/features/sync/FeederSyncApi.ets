/**
 * FeederSyncApi —— 源 sync/FeederSync.kt（Retrofit 接口）+ sync/Retrofit.kt（getFeederSyncClient）+
 * SyncRestClient.kt 的 Response.toEither / ErrorResponse（SY-A25/A27/A42）。
 *
 *  - 基址：`URL(syncRemote.url, "/api/v1/")`（绝对路径解析，即 `<scheme>://<host>[:port]/api/v1/`）；
 *  - 每个请求带 `Authorization: Basic base64(feeder_user:feeder_secret_1234)`（仅防扫描）；
 *  - 结果：2xx 有 body → Right；2xx 无 body → Left(998, "No body but success")；非 2xx → Left(code, errorBody)；
 *    body 解析异常 → Left(999, message)。IO 异常照 Retrofit suspend 语义向上抛出（由调用方 catch）。
 */
import { HttpClient } from '../../core/net/HttpClient';
import { HttpRequest, HttpResponse } from '../../core/net/HttpMessages';
import { toError } from '../../core/net/NetworkResult';
import { JavaUrl } from '../../core/util/JavaUrl';
import { base64Encode, encodeUtf8 } from '../../core/util/TextCodec';
import { Either, leftOf, rightOf } from '../../core/util/Either';
import {
  CreateRequest, DeviceIdRegistry, DeviceListResponse, GetEncryptedReadMarksResponse, GetFeedsResponse, JoinRequest,
  JoinResponse, SendEncryptedReadMarkBulkRequest, SendReadMarkResponse, UpdateFeedsRequest, UpdateFeedsResponse
} from './SyncRestBodies';

const LOG_TAG: string = 'FEEDER_SYNC_CLIENT';
const HARDCODED_USER: string = 'feeder_user';
const HARDCODED_PASSWORD: string = 'feeder_secret_1234';
const JSON_CONTENT_TYPE: string = 'application/json; charset=UTF-8';

/** 源 data class ErrorResponse */
export class ErrorResponse {
  code: number = 0;
  body: string | null = null;
  throwable: Error | null = null;

  static of(code: number, body: string | null = null, throwable: Error | null = null): ErrorResponse {
    const e: ErrorResponse = new ErrorResponse();
    e.code = code;
    e.body = body;
    e.throwable = throwable;
    return e;
  }

  toString(): string {
    return `ErrorResponse(code=${this.code}, body=${this.body})`;
  }
}

/** okhttp3.Credentials.basic(user, password)（ISO-8859-1 → 此处 ASCII 等价） */
export function basicCredentials(user: string, password: string): string {
  return `Basic ${base64Encode(encodeUtf8(`${user}:${password}`))}`;
}

/** 源 Response<T>.toEither()：body 解析在此进行，解析异常 → 999 */
export function responseToEither<T>(resp: HttpResponse, parse: (text: string) => T): Either<ErrorResponse, T> {
  try {
    if (resp.isSuccessful()) {
      const bytes: Uint8Array = resp.bytes();
      if (resp.body === null || bytes.length === 0) {
        return leftOf<ErrorResponse, T>(ErrorResponse.of(998, 'No body but success'));
      }
      const text: string = resp.text();
      if (text.trim() === 'null') {
        return leftOf<ErrorResponse, T>(ErrorResponse.of(998, 'No body but success'));
      }
      return rightOf<ErrorResponse, T>(parse(text));
    } else {
      const errBody: string | null = resp.body !== null ? resp.text() : null;
      return leftOf<ErrorResponse, T>(ErrorResponse.of(resp.code, errBody));
    }
  } catch (e) {
    const err: Error = toError(e as Object);
    return leftOf<ErrorResponse, T>(ErrorResponse.of(999, err.message, err));
  }
}

/** 源 interface FeederSync（Retrofit 实现等价物） */
export class FeederSyncApi {
  readonly baseUrl: string;
  private readonly client: HttpClient;
  private readonly authorization: string = basicCredentials(HARDCODED_USER, HARDCODED_PASSWORD);

  constructor(baseUrl: string, client: HttpClient) {
    this.baseUrl = baseUrl;
    this.client = client;
  }

  /** 源 getFeederSyncClient(syncRemote, okHttpClient) */
  static forRemote(remoteUrl: string): FeederSyncApi {
    const base: string = JavaUrl.parse('/api/v1/', JavaUrl.parse(remoteUrl)).toString();
    return new FeederSyncApi(base, HttpClient.main());
  }

  private async call(method: string, path: string, headers: Map<string, string>, body: string | null): Promise<HttpResponse> {
    const r: HttpRequest = new HttpRequest(this.baseUrl + path);
    r.method = method;
    headers.forEach((v: string, k: string) => {
      r.headers.set(k, v);
    });
    r.headers.set('Authorization', this.authorization);
    if (body !== null) {
      r.body = body;
      r.headers.set('Content-Type', JSON_CONTENT_TYPE);
    }
    const resp: HttpResponse = await this.client.execute(r);
    console.debug(LOG_TAG, `Response cached: ${resp.fromCache && !resp.networkUsed}, ${resp.code}`);
    return resp;
  }

  private static chainHeaders(syncChainId: string, currentDeviceId: number): Map<string, string> {
    const h: Map<string, string> = new Map<string, string>();
    h.set('X-FEEDER-ID', syncChainId);
    h.set('X-FEEDER-DEVICE-ID', DeviceIdRegistry.format(currentDeviceId));
    return h;
  }

  /** POST create */
  async create(request: CreateRequest): Promise<Either<ErrorResponse, JoinResponse>> {
    const resp: HttpResponse = await this.call('POST', 'create', new Map<string, string>(), request.toJson());
    return responseToEither<JoinResponse>(resp, (t: string): JoinResponse => JoinResponse.fromJson(t));
  }

  /** POST join（X-FEEDER-ID） */
  async join(syncChainId: string, request: JoinRequest): Promise<Either<ErrorResponse, JoinResponse>> {
    const h: Map<string, string> = new Map<string, string>();
    h.set('X-FEEDER-ID', syncChainId);
    const resp: HttpResponse = await this.call('POST', 'join', h, request.toJson());
    return responseToEither<JoinResponse>(resp, (t: string): JoinResponse => JoinResponse.fromJson(t));
  }

  /** GET devices */
  async getDevices(syncChainId: string, currentDeviceId: number): Promise<Either<ErrorResponse, DeviceListResponse>> {
    const resp: HttpResponse =
      await this.call('GET', 'devices', FeederSyncApi.chainHeaders(syncChainId, currentDeviceId), null);
    return responseToEither<DeviceListResponse>(resp, (t: string): DeviceListResponse => DeviceListResponse.fromJson(t));
  }

  /** DELETE devices/{deviceId} */
  async removeDevice(syncChainId: string, currentDeviceId: number,
    deviceId: number): Promise<Either<ErrorResponse, DeviceListResponse>> {
    const resp: HttpResponse = await this.call('DELETE', `devices/${DeviceIdRegistry.format(deviceId)}`,
      FeederSyncApi.chainHeaders(syncChainId, currentDeviceId), null);
    return responseToEither<DeviceListResponse>(resp, (t: string): DeviceListResponse => DeviceListResponse.fromJson(t));
  }

  /** GET ereadmark?since=<ms> */
  async getEncryptedReadMarks(syncChainId: string, currentDeviceId: number,
    sinceMillis: number): Promise<Either<ErrorResponse, GetEncryptedReadMarksResponse>> {
    const resp: HttpResponse = await this.call('GET', `ereadmark?since=${Math.trunc(sinceMillis)}`,
      FeederSyncApi.chainHeaders(syncChainId, currentDeviceId), null);
    return responseToEither<GetEncryptedReadMarksResponse>(resp,
      (t: string): GetEncryptedReadMarksResponse => GetEncryptedReadMarksResponse.fromJson(t));
  }

  /** POST ereadmark */
  async sendEncryptedReadMarks(syncChainId: string, currentDeviceId: number,
    request: SendEncryptedReadMarkBulkRequest): Promise<Either<ErrorResponse, SendReadMarkResponse>> {
    const resp: HttpResponse = await this.call('POST', 'ereadmark',
      FeederSyncApi.chainHeaders(syncChainId, currentDeviceId), request.toJson());
    return responseToEither<SendReadMarkResponse>(resp,
      (t: string): SendReadMarkResponse => SendReadMarkResponse.fromJson(t));
  }

  /** GET feeds */
  async getFeeds(syncChainId: string, currentDeviceId: number): Promise<Either<ErrorResponse, GetFeedsResponse>> {
    const resp: HttpResponse =
      await this.call('GET', 'feeds', FeederSyncApi.chainHeaders(syncChainId, currentDeviceId), null);
    return responseToEither<GetFeedsResponse>(resp, (t: string): GetFeedsResponse => GetFeedsResponse.fromJson(t));
  }

  /** POST feeds（If-Match） */
  async updateFeeds(syncChainId: string, currentDeviceId: number, etagValue: string,
    request: UpdateFeedsRequest): Promise<Either<ErrorResponse, UpdateFeedsResponse>> {
    const h: Map<string, string> = FeederSyncApi.chainHeaders(syncChainId, currentDeviceId);
    h.set('If-Match', etagValue);
    const resp: HttpResponse = await this.call('POST', 'feeds', h, request.toJson());
    return responseToEither<UpdateFeedsResponse>(resp,
      (t: string): UpdateFeedsResponse => UpdateFeedsResponse.fromJson(t));
  }
}
