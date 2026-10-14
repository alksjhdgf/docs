/*
 * OpenAIClient — OpenAI 兼容 REST 客户端（源 openai/OpenAIClient.kt + aallam openai-client 4.x 的等价自实现）。
 *   - 接口 OpenAIClient：models() / chatCompletion()（源 interface OpenAIClient）。
 *   - OpenAIClientDefault：照源 toOpenAIConfig：
 *       token=key（非 Azure：Authorization: Bearer <key>）；
 *       Timeout(socket = clamp(timeoutSeconds, 30, 600) 秒) → connect/read 超时（AI-A37）；
 *       LoggingConfig(LogLevel.Headers, sanitize = !DEBUG) → 发布版请求头脱敏（AI-A38）；
 *       host = toOpenAIHost(withAzureDeploymentId=false)；Azure：去 Authorization 改 api-key，
 *       非 models 请求改用带 deployments/<id> 的主机（AI-A35/A36）。
 *   - 主机拼接（OpenAIApi.kt:408 toOpenAIHost）：baseUrl 空 → https://api.openai.com/v1/；
 *     非空 → baseUrl + /openai [+ /deployments/<id>]，apiVersion 非空附 api-version 查询参数。
 *     源依赖 Ktor defaultRequest 相对路径解析，此处显式按"主机目录 + 相对路径"拼接（曾申报降级 deg-core-openai-1l3ts6，已被裁定不成立：视为等价实现）。
 */
import BuildProfile from 'BuildProfile';
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { HttpClient, HttpClientConfig } from '../../core/net/HttpClient';
import { HttpResponse } from '../../core/net/HttpMessages';
import { decodeUtf8 } from '../../core/util/TextCodec';
import { isAzure } from '../translation/LanguageUtils';

const LOG_TAG: string = 'FEEDER_OPENAI';

/** 源 OpenAIHost.OpenAI.baseUrl */
export const OPENAI_DEFAULT_BASE_URL: string = 'https://api.openai.com/v1/';

// ------------------------------------------------------------------ 数据类型（aallam api 子集）

/** 源 com.aallam.openai.api.model.Model（仅用到 id / created） */
export class OpenAIModel {
  id: string = '';
  created: number | null = null;
}

export enum ChatRole {
  System = 'system',
  User = 'user',
  Assistant = 'assistant'
}

export class ChatMessage {
  role: ChatRole = ChatRole.User;
  content: string = '';

  static of(role: ChatRole, content: string): ChatMessage {
    const m = new ChatMessage();
    m.role = role;
    m.content = content;
    return m;
  }
}

/** 源 ChatCompletionRequest(model, messages, responseFormat) */
export class ChatCompletionRequest {
  model: string = '';
  messages: ChatMessage[] = [];
  /** 源 ChatResponseFormat.Text → {"type":"text"} */
  responseFormatType: string = 'text';

  toJson(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      const m = this.messages[i];
      parts.push(`{"role":${JSON.stringify(m.role)},"content":${JSON.stringify(m.content)}}`);
    }
    return `{"model":${JSON.stringify(this.model)},"messages":[${parts.join(',')}],` +
      `"response_format":{"type":${JSON.stringify(this.responseFormatType)}}}`;
  }
}

export class ChatChoice {
  index: number = 0;
  /** message.content（可空） */
  content: string | null = null;
}

export class ChatUsage {
  promptTokens: number | null = null;
  completionTokens: number | null = null;
  totalTokens: number | null = null;
}

/** 源 ChatCompletion */
export class ChatCompletion {
  id: string = '';
  created: number = 0;
  model: string = '';
  choices: ChatChoice[] = [];
  usage: ChatUsage | null = null;
}

/** 源 OpenAIAPIException / 序列化异常等（message 即源 e.message） */
export class OpenAIClientException extends Error {
  readonly statusCode: number;

  constructor(message: string, statusCode: number = 0) {
    super(message);
    this.name = 'OpenAIClientException';
    this.statusCode = statusCode;
  }
}

/** 源 interface OpenAIClient */
export interface OpenAIClient {
  models(): Promise<OpenAIModel[]>;

  chatCompletion(request: ChatCompletionRequest): Promise<ChatCompletion>;
}

/** 源 bindFactory<OpenAISettings, OpenAIClient> */
export type OpenAIClientFactory = (settings: OpenAISettings) => OpenAIClient;

// ------------------------------------------------------------------ 主机（源 OpenAIHost / toOpenAIHost / toUrl）

export class OpenAIHost {
  baseUrl: string = OPENAI_DEFAULT_BASE_URL;
  queryParams: Map<string, string> = new Map<string, string>();
}

function trimEndSlashes(s: string): string {
  let end = s.length;
  while (end > 0 && s.charAt(end - 1) === '/') {
    end--;
  }
  return s.substring(0, end);
}

function encodeSegment(seg: string): string {
  return encodeURIComponent(seg);
}

/** AI-A35：源 OpenAISettings.toOpenAIHost(withAzureDeploymentId) */
export function toOpenAIHost(settings: OpenAISettings, withAzureDeploymentId: boolean): OpenAIHost {
  const host = new OpenAIHost();
  if (settings.baseUrl.length === 0) {
    host.baseUrl = OPENAI_DEFAULT_BASE_URL;
    return host;
  }
  let base = settings.baseUrl.trim();
  let query = '';
  const q = base.search(new RegExp('[?#]'));
  if (q >= 0) {
    query = base.substring(q);
    base = base.substring(0, q);
  }
  let url = trimEndSlashes(base) + '/openai';
  if (withAzureDeploymentId && settings.azureDeploymentId.trim().length > 0) {
    url += '/deployments/' + encodeSegment(settings.azureDeploymentId);
  }
  host.baseUrl = url + query;
  if (settings.azureApiVersion.length > 0) {
    host.queryParams.set('api-version', settings.azureApiVersion);
  }
  return host;
}

/** 主机 + 相对路径（如 "models"、"chat/completions"）+ 查询参数 */
export function openAIRequestUrl(host: OpenAIHost, relativePath: string): string {
  let base = host.baseUrl;
  let existingQuery = '';
  const q = base.indexOf('?');
  if (q >= 0) {
    existingQuery = base.substring(q + 1);
    base = base.substring(0, q);
  }
  const hash = base.indexOf('#');
  if (hash >= 0) {
    base = base.substring(0, hash);
  }
  let url = trimEndSlashes(base) + '/' + relativePath;
  const params: string[] = [];
  if (existingQuery.length > 0) {
    params.push(existingQuery);
  }
  host.queryParams.forEach((v: string, k: string) => {
    params.push(`${encodeURIComponent(k)}=${encodeURIComponent(v)}`);
  });
  if (params.length > 0) {
    url += '?' + params.join('&');
  }
  return url;
}

/** 源 Ktor HttpSend 拦截器选择主机：models 列表不带 deployments，其余带（仅 Azure） */
export function openAIEndpointUrl(settings: OpenAISettings, relativePath: string): string {
  const segments = relativePath.split('/');
  const last = segments[segments.length - 1];
  const withDeployment = isAzure(settings) && last !== 'models';
  return openAIRequestUrl(toOpenAIHost(settings, withDeployment), relativePath);
}

/** AI-A36：Azure → api-key；其它 → Bearer */
export function openAIRequestHeaders(settings: OpenAISettings, withJsonBody: boolean): Map<string, string> {
  const headers = new Map<string, string>();
  if (isAzure(settings)) {
    headers.set('api-key', settings.key);
  } else {
    headers.set('Authorization', `Bearer ${settings.key}`);
  }
  if (withJsonBody) {
    headers.set('Content-Type', 'application/json');
  }
  headers.set('Accept', 'application/json');
  return headers;
}

/** AI-A37：clamp(timeoutSeconds, 30, 600) */
export function clampTimeoutSeconds(timeoutSeconds: number): number {
  return Math.min(600, Math.max(30, Math.trunc(timeoutSeconds)));
}

// ------------------------------------------------------------------ 日志（AI-A38）

const SENSITIVE_HEADERS: string[] = ['authorization', 'api-key'];

/** 源 LoggingConfig(sanitize = !BuildConfig.DEBUG)：敏感头值替换为 *** */
export function sanitizedHeaderLines(headers: Map<string, string>, sanitize: boolean): string[] {
  const lines: string[] = [];
  headers.forEach((v: string, k: string) => {
    const hide = sanitize && SENSITIVE_HEADERS.indexOf(k.toLowerCase()) >= 0;
    lines.push(`${k}: ${hide ? '***' : v}`);
  });
  return lines;
}

function logRequest(method: string, url: string, headers: Map<string, string>): void {
  const sanitize: boolean = !BuildProfile.DEBUG;
  console.debug(LOG_TAG, `REQUEST: ${method} ${url}`);
  const lines = sanitizedHeaderLines(headers, sanitize);
  for (let i = 0; i < lines.length; i++) {
    console.debug(LOG_TAG, `-> ${lines[i]}`);
  }
}

// ------------------------------------------------------------------ HTTP 执行（可注入，供测试）

export type OpenAIHttpExecutor = (method: string, url: string, body: string | null, headers: Map<string, string>,
  timeoutSeconds: number) => Promise<HttpResponse>;

let httpExecutorOverride: OpenAIHttpExecutor | null = null;

export function setOpenAIHttpExecutor(executor: OpenAIHttpExecutor | null): void {
  httpExecutorOverride = executor;
}

async function executeHttp(method: string, url: string, body: string | null, headers: Map<string, string>,
  timeoutSeconds: number): Promise<HttpResponse> {
  logRequest(method, url, headers);
  const override = httpExecutorOverride;
  if (override !== null) {
    return override(method, url, body, headers, timeoutSeconds);
  }
  const config = new HttpClientConfig();
  const timeoutMs = clampTimeoutSeconds(timeoutSeconds) * 1000;
  config.connectTimeoutMs = timeoutMs;
  config.readTimeoutMs = timeoutMs;
  const client = new HttpClient(config);
  if (method === 'POST') {
    return client.post(url, body !== null ? body : '', 'application/json', headers);
  }
  return client.get(url, headers);
}

function bodyText(response: HttpResponse): string {
  return response.body !== null ? decodeUtf8(new Uint8Array(response.body)) : '';
}

/** 源 aallam 错误处理：{"error":{"message":...}} 的 message；解析不了 → HTTP 状态描述 */
export function openAIErrorMessage(response: HttpResponse): string {
  const text = bodyText(response);
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const err = root['error'];
    if (err !== null && err !== undefined && typeof err === 'object') {
      const msg = (err as Record<string, Object>)['message'];
      if (typeof msg === 'string' && (msg as string).length > 0) {
        return msg as string;
      }
    }
  } catch (e) {
    console.debug(LOG_TAG, 'error body is not JSON');
  }
  const status = response.message.trim().length > 0 ? ` ${response.message}` : '';
  return `HTTP ${response.code}${status}`;
}

function numberOrNull(v: Object | null | undefined): number | null {
  return typeof v === 'number' ? (v as number) : null;
}

function requireString(obj: Record<string, Object>, field: string): string {
  const v = obj[field];
  if (typeof v !== 'string') {
    throw new OpenAIClientException(`Field '${field}' is required`);
  }
  return v as string;
}

/** 源 ListResponse<Model>.data */
export function parseModels(text: string): OpenAIModel[] {
  const root = JSON.parse(text) as Record<string, Object>;
  const data = root['data'];
  if (!Array.isArray(data)) {
    throw new OpenAIClientException('Field \'data\' is required');
  }
  const arr = data as Array<Object>;
  const out: OpenAIModel[] = [];
  for (let i = 0; i < arr.length; i++) {
    const obj = arr[i] as Record<string, Object>;
    const m = new OpenAIModel();
    m.id = requireString(obj, 'id');
    m.created = numberOrNull(obj['created']);
    out.push(m);
  }
  return out;
}

/** 源 ChatCompletion 反序列化（ignoreUnknownKeys） */
export function parseChatCompletion(text: string): ChatCompletion {
  const root = JSON.parse(text) as Record<string, Object>;
  const c = new ChatCompletion();
  c.id = requireString(root, 'id');
  const created = numberOrNull(root['created']);
  if (created === null) {
    throw new OpenAIClientException('Field \'created\' is required');
  }
  c.created = created;
  c.model = requireString(root, 'model');
  const choices = root['choices'];
  if (!Array.isArray(choices)) {
    throw new OpenAIClientException('Field \'choices\' is required');
  }
  const arr = choices as Array<Object>;
  for (let i = 0; i < arr.length; i++) {
    const obj = arr[i] as Record<string, Object>;
    const ch = new ChatChoice();
    const idx = numberOrNull(obj['index']);
    ch.index = idx !== null ? idx : i;
    const msg = obj['message'];
    if (msg !== null && msg !== undefined && typeof msg === 'object') {
      const content = (msg as Record<string, Object>)['content'];
      ch.content = typeof content === 'string' ? (content as string) : null;
    }
    c.choices.push(ch);
  }
  const usage = root['usage'];
  if (usage !== null && usage !== undefined && typeof usage === 'object') {
    const u = usage as Record<string, Object>;
    const cu = new ChatUsage();
    cu.promptTokens = numberOrNull(u['prompt_tokens']);
    cu.completionTokens = numberOrNull(u['completion_tokens']);
    cu.totalTokens = numberOrNull(u['total_tokens']);
    c.usage = cu;
  }
  return c;
}

/** 源 OpenAIClientDefault */
export class OpenAIClientDefault implements OpenAIClient {
  private readonly settings: OpenAISettings;

  constructor(settings: OpenAISettings) {
    this.settings = settings.copy();
  }

  async models(): Promise<OpenAIModel[]> {
    const url = openAIEndpointUrl(this.settings, 'models');
    const response = await executeHttp('GET', url, null, openAIRequestHeaders(this.settings, false),
      this.settings.timeoutSeconds);
    if (!response.isSuccessful()) {
      throw new OpenAIClientException(openAIErrorMessage(response), response.code);
    }
    return parseModels(bodyText(response));
  }

  async chatCompletion(request: ChatCompletionRequest): Promise<ChatCompletion> {
    const url = openAIEndpointUrl(this.settings, 'chat/completions');
    const response = await executeHttp('POST', url, request.toJson(), openAIRequestHeaders(this.settings, true),
      this.settings.timeoutSeconds);
    if (!response.isSuccessful()) {
      throw new OpenAIClientException(openAIErrorMessage(response), response.code);
    }
    return parseChatCompletion(bodyText(response));
  }
}

/** 默认工厂（源 DI bindFactory） */
export const defaultOpenAIClientFactory: OpenAIClientFactory =
  (settings: OpenAISettings): OpenAIClient => new OpenAIClientDefault(settings);
