/*
 * DeepLApi — 翻译 API 结果类型、provider 分派与 DeepL 客户端。
 * 源：openai/OpenAIApi.kt（TranslationResult / ErrorAction、translate() 分派 :219、translateWithDeepL :247、
 *     verifyDeepLSettings :157、postJson/httpFailure、toDeepLTranslateUrl/normalizedDeepLBaseUrl :486）。
 * 请求体 JSON 照源 kotlinx Json{ explicitNulls=false }（encodeDefaults 默认 false）：
 *   null 的 tag_handling 省略；split_sentences / preserve_formatting 为默认值时同样不被序列化（与源实际线上报文一致）。
 *   【AI-A51 说明】台账断言文本写体内带 split_sentences:"nonewlines"、preserve_formatting:true；但源 OpenAIApi.kt:28-32 的
 *   Json{ ignoreUnknownKeys; explicitNulls=false } 未开 encodeDefaults（kotlinx 默认 false），:41-47 两字段恒取默认值且无
 *   @EncodeDefault → 源 postJson(:328 json.encodeToString) 的实际报文不含这两个键。此处照源线上报文实现（parity），不额外发送。
 *   台账未登记任何相关偏差；断言文本与源实际行为不符，待断言更正（非实现缺陷）。
 * 客户端照源 OkHttpClient.Builder().callTimeout(timeoutSeconds.coerceIn(30, 600))：独立 HttpClient，无磁盘缓存。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { HttpClient, HttpClientConfig } from '../../core/net/HttpClient';
import { HttpResponse } from '../../core/net/HttpMessages';
import { decodeUtf8 } from '../../core/util/TextCodec';
import { isDeepL, isLocalTranslation, toDeepLTargetLanguageCode } from './LanguageUtils';

/** 源 TranslationResult.ErrorAction */
export enum TranslationErrorAction {
  None = 'None',
  DownloadBergamotRuntime = 'DownloadBergamotRuntime',
  OpenSystemTranslationSettings = 'OpenSystemTranslationSettings'
}

/** 源 sealed TranslationResult（Success / Error 合一，isSuccess 区分） */
export class TranslationResult {
  readonly isSuccess: boolean;
  readonly content: string;
  /** Success.detectedLanguage（Error 为空串） */
  readonly detectedLanguage: string;
  /** Error.action（Success 为 None） */
  readonly action: TranslationErrorAction;

  private constructor(isSuccess: boolean, content: string, detectedLanguage: string, action: TranslationErrorAction) {
    this.isSuccess = isSuccess;
    this.content = content;
    this.detectedLanguage = detectedLanguage;
    this.action = action;
  }

  static success(content: string, detectedLanguage: string): TranslationResult {
    return new TranslationResult(true, content, detectedLanguage, TranslationErrorAction.None);
  }

  static error(content: string, action: TranslationErrorAction = TranslationErrorAction.None): TranslationResult {
    return new TranslationResult(false, content, '', action);
  }
}

/** DeepL key 校验结果（源 ModelsResult 的 DeepL 子集：Success(emptyList) / Error(message)） */
export class DeepLVerificationResult {
  readonly ok: boolean;
  readonly message: string | null;

  constructor(ok: boolean, message: string | null) {
    this.ok = ok;
    this.message = message;
  }
}

class DeepLTranslation {
  detectedSourceLanguage: string = '';
  text: string = '';
}

class DeepLFailure extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DeepLFailure';
  }
}

/** 测试/注入：替换 HTTP 执行（未注册则用真实 HttpClient） */
export type DeepLHttpExecutor = (url: string, body: string, headers: Map<string, string>,
  timeoutSeconds: number) => Promise<HttpResponse>;

let httpExecutorOverride: DeepLHttpExecutor | null = null;

export function setDeepLHttpExecutor(executor: DeepLHttpExecutor | null): void {
  httpExecutorOverride = executor;
}

function clampTimeoutSeconds(timeoutSeconds: number): number {
  return Math.min(600, Math.max(30, timeoutSeconds));
}

async function executePost(url: string, body: string, headers: Map<string, string>,
  timeoutSeconds: number): Promise<HttpResponse> {
  const override = httpExecutorOverride;
  if (override !== null) {
    return override(url, body, headers, timeoutSeconds);
  }
  const config = new HttpClientConfig();
  const timeoutMs = clampTimeoutSeconds(timeoutSeconds) * 1000;
  config.connectTimeoutMs = timeoutMs;
  config.readTimeoutMs = timeoutMs;
  const client = new HttpClient(config);
  return client.post(url, body, 'application/json', headers);
}

function trimEndSlashes(s: string): string {
  let end = s.length;
  while (end > 0 && s.charAt(end - 1) === '/') {
    end--;
  }
  return s.substring(0, end);
}

/** AI-A52：baseUrl 去空白、去尾 '/' 与 '/v2/translate'；空或官方地址时按 key 是否 ':fx' 结尾选择 */
export function normalizedDeepLBaseUrl(settings: OpenAISettings): string {
  let normalized = trimEndSlashes(settings.baseUrl.trim());
  if (normalized.endsWith('/v2/translate')) {
    normalized = normalized.substring(0, normalized.length - '/v2/translate'.length);
  }
  const defaultBaseUrl = settings.key.endsWith(':fx') ? 'https://api-free.deepl.com' : 'https://api.deepl.com';
  if (normalized.trim().length === 0) {
    return defaultBaseUrl;
  }
  const lower = normalized.toLowerCase();
  if (lower === 'https://api.deepl.com' || lower === 'https://api-free.deepl.com') {
    return defaultBaseUrl;
  }
  return normalized;
}

/** URLBuilder().takeFrom(base).appendPathSegments("v2","translate") */
export function toDeepLTranslateUrl(settings: OpenAISettings): string {
  const base = normalizedDeepLBaseUrl(settings);
  let path = base;
  let suffix = '';
  const q = base.search(new RegExp('[?#]'));
  if (q >= 0) {
    path = base.substring(0, q);
    suffix = base.substring(q);
  }
  return `${trimEndSlashes(path)}/v2/translate${suffix}`;
}

/** 源 DeepLTranslateRequest 的 kotlinx 序列化（explicitNulls=false、encodeDefaults=false） */
export function deepLRequestJson(text: string[], targetLang: string, tagHandling: string | null): string {
  let json = `{"text":${JSON.stringify(text)},"target_lang":${JSON.stringify(targetLang)}`;
  if (tagHandling !== null) {
    json += `,"tag_handling":${JSON.stringify(tagHandling)}`;
  }
  return json + '}';
}

function httpFailureMessage(prefix: string, response: HttpResponse): string {
  const msg = response.message.trim().length > 0 ? ` ${response.message}` : '';
  return `${prefix}: HTTP ${response.code}${msg}`;
}

function parseTranslations(body: string): DeepLTranslation[] {
  const root = JSON.parse(body) as Record<string, Object>;
  const list = root['translations'];
  if (!Array.isArray(list)) {
    throw new DeepLFailure('Field \'translations\' is required');
  }
  const arr = list as Array<Object>;
  const out: DeepLTranslation[] = [];
  for (let i = 0; i < arr.length; i++) {
    const obj = arr[i] as Record<string, Object>;
    const t = new DeepLTranslation();
    const lang = obj['detected_source_language'];
    const text = obj['text'];
    if (typeof text !== 'string' || typeof lang !== 'string') {
      throw new DeepLFailure('Malformed DeepL translation');
    }
    t.detectedSourceLanguage = lang as string;
    t.text = text as string;
    out.push(t);
  }
  return out;
}

async function postDeepL(settings: OpenAISettings, text: string[], targetLang: string, tagHandling: string | null,
  failurePrefix: string): Promise<DeepLTranslation[]> {
  const headers = new Map<string, string>();
  headers.set('Content-Type', 'application/json');
  headers.set('Authorization', `DeepL-Auth-Key ${settings.key}`);
  const response = await executePost(toDeepLTranslateUrl(settings), deepLRequestJson(text, targetLang, tagHandling),
    headers, settings.timeoutSeconds);
  if (!response.isSuccessful()) {
    throw new DeepLFailure(httpFailureMessage(failurePrefix, response));
  }
  const body = response.body !== null ? decodeUtf8(new Uint8Array(response.body)) : '';
  return parseTranslations(body);
}

function messageOf(e: Object | null | undefined): string {
  if (e instanceof Error) {
    return (e as Error).message ?? '';
  }
  return e !== null && e !== undefined ? `${e}` : '';
}

/** AI-A51/A54：DeepL 翻译 */
export async function translateWithDeepL(settings: OpenAISettings, content: string, targetLanguage: string,
  preserveHtml: boolean): Promise<TranslationResult> {
  const targetLanguageCode = toDeepLTargetLanguageCode(targetLanguage);
  try {
    const translations = await postDeepL(settings, [content], targetLanguageCode, preserveHtml ? 'html' : null,
      'DeepL request failed');
    if (translations.length === 0) {
      throw new DeepLFailure('DeepL returned no translations');
    }
    return TranslationResult.success(translations[0].text, translations[0].detectedSourceLanguage);
  } catch (e) {
    return TranslationResult.error(messageOf(e as Object));
  }
}

/** AI-A55：以 "Hello"→DE 真实请求校验 key */
export async function verifyDeepLSettings(settings: OpenAISettings): Promise<DeepLVerificationResult> {
  try {
    const translations = await postDeepL(settings, ['Hello'], 'DE', null, 'DeepL verification failed');
    if (translations.length === 0) {
      return new DeepLVerificationResult(false, 'DeepL verification failed: no translation was returned');
    }
    return new DeepLVerificationResult(true, null);
  } catch (e) {
    const m = messageOf(e as Object);
    return new DeepLVerificationResult(false, m.length > 0 ? m : null);
  }
}

/** AI-A50：OpenAIApi.translate 分派（DeepL→DeepL；Local→错误；其它→不支持） */
export async function translateViaApi(content: string, targetLanguage: string, settings: OpenAISettings,
  preserveHtml: boolean = false): Promise<TranslationResult> {
  if (isDeepL(settings)) {
    return translateWithDeepL(settings, content, targetLanguage, preserveHtml);
  }
  if (isLocalTranslation(settings)) {
    return TranslationResult.error('Local translation is not available through this API');
  }
  return TranslationResult.error('Translation is not supported for this provider');
}
