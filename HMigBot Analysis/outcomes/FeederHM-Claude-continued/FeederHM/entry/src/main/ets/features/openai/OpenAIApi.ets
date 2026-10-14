/*
 * OpenAIApi — 源 openai/OpenAIApi.kt：listModelIds / summarize / translate，结果类型与提供方判定。
 *   - 提供方判定/有效性（AI-A31/A32）复用 features/translation/LanguageUtils（同源 OpenAIApi.kt:367-406），此处再导出；
 *     isBlankConfiguration 在此定义。
 *   - DeepL 校验/翻译复用 features/translation/DeepLApi（同源 :157-269）。
 *   - 单例 OpenAIApi.instance()：appLang = Locale.getDefault().getISO3Language()（di/ArchModelModule.kt:60）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import {
  canSummarize, canTranslate, canUseAsTranslationApi, isAzure, isDeepL, isLocalTranslation, isPerplexity,
  isValidAiSettings, LOCAL_TRANSLATION_PROVIDER_URL
} from '../translation/LanguageUtils';
import { DeepLVerificationResult, TranslationResult, translateViaApi, verifyDeepLSettings } from '../translation/DeepLApi';
import {
  ChatCompletion, ChatCompletionRequest, ChatMessage, ChatRole, defaultOpenAIClientFactory, OpenAIClientFactory,
  OpenAIModel
} from './OpenAIClient';
import { appIso3Language } from './LanguageTables';

export {
  canSummarize, canTranslate, canUseAsTranslationApi, isAzure, isDeepL, isLocalTranslation, isPerplexity,
  isValidAiSettings, LOCAL_TRANSLATION_PROVIDER_URL
} from '../translation/LanguageUtils';
export { TranslationResult, TranslationErrorAction } from '../translation/DeepLApi';

/** 源 OpenAISettings.isBlankConfiguration：五个字符串字段全空白（忽略 timeout） */
export function isBlankConfiguration(s: OpenAISettings): boolean {
  return s.key.trim().length === 0 && s.modelId.trim().length === 0 && s.baseUrl.trim().length === 0 &&
    s.azureApiVersion.trim().length === 0 && s.azureDeploymentId.trim().length === 0;
}

// ------------------------------------------------------------------ 结果类型

/** 源 sealed ModelsResult 的分支 */
export enum ModelsResultKind {
  MissingToken = 'MissingToken',
  AzureApiVersionRequired = 'AzureApiVersionRequired',
  AzureDeploymentIdRequired = 'AzureDeploymentIdRequired',
  Success = 'Success',
  Error = 'Error'
}

export class ModelsResult {
  readonly kind: ModelsResultKind;
  readonly ids: string[];
  /** Error.message（可空） */
  readonly message: string | null;

  private constructor(kind: ModelsResultKind, ids: string[], message: string | null) {
    this.kind = kind;
    this.ids = ids;
    this.message = message;
  }

  static missingToken(): ModelsResult {
    return new ModelsResult(ModelsResultKind.MissingToken, [], null);
  }

  static azureApiVersionRequired(): ModelsResult {
    return new ModelsResult(ModelsResultKind.AzureApiVersionRequired, [], null);
  }

  static azureDeploymentIdRequired(): ModelsResult {
    return new ModelsResult(ModelsResultKind.AzureDeploymentIdRequired, [], null);
  }

  static success(ids: string[]): ModelsResult {
    return new ModelsResult(ModelsResultKind.Success, ids, null);
  }

  static error(message: string | null): ModelsResult {
    return new ModelsResult(ModelsResultKind.Error, [], message);
  }
}

/** 源 sealed SummaryResult（Success / Error 合一，isSuccess 区分） */
export class SummaryResult {
  readonly isSuccess: boolean;
  readonly content: string;
  id: string = '';
  created: number = 0;
  model: string = '';
  promptTokens: number = 0;
  completeTokens: number = 0;
  totalTokens: number = 0;
  detectedLanguage: string = '';

  private constructor(isSuccess: boolean, content: string) {
    this.isSuccess = isSuccess;
    this.content = content;
  }

  static success(id: string, created: number, model: string, content: string, promptTokens: number,
    completeTokens: number, totalTokens: number, detectedLanguage: string): SummaryResult {
    const r = new SummaryResult(true, content);
    r.id = id;
    r.created = created;
    r.model = model;
    r.promptTokens = promptTokens;
    r.completeTokens = completeTokens;
    r.totalTokens = totalTokens;
    r.detectedLanguage = detectedLanguage;
    return r;
  }

  static error(content: string): SummaryResult {
    return new SummaryResult(false, content);
  }
}

/** 源 SummaryResponse(lang, content) */
export class SummaryResponse {
  lang: string = '';
  content: string = '';
}

export const SUMMARIZATION_NOT_SUPPORTED: string = 'Summarization is not supported for this translation-only provider';

const LANG_REGEX: RegExp = new RegExp('^Lang: "?([a-zA-Z_-]+)"?$');

/** Kotlin String.lineSequence().firstOrNull()：按 \r\n / \n / \r 切首行 */
function firstLineOf(content: string): string {
  for (let i = 0; i < content.length; i++) {
    const c = content.charAt(i);
    if (c === '\n' || c === '\r') {
      return content.substring(0, i);
    }
  }
  return content;
}

/** AI-A42：源 parseSummaryResponse —— 首行匹配取语言码；正文 = replaceFirst(首行, "").trim() */
export function parseSummaryResponse(content: string): SummaryResponse {
  const firstLine = firstLineOf(content);
  const m = LANG_REGEX.exec(firstLine);
  const r = new SummaryResponse();
  r.lang = m !== null && m.length > 1 && m[1] !== undefined ? m[1] : '';
  const idx = content.indexOf(firstLine);
  const removed = idx >= 0 ? content.substring(0, idx) + content.substring(idx + firstLine.length) : content;
  r.content = kotlinTrim(removed);
  return r;
}

/** Kotlin String.trim()：去掉首尾 isWhitespace 字符 */
function kotlinTrim(s: string): string {
  const ws = new RegExp('^[\\s\\u001c-\\u001f]+|[\\s\\u001c-\\u001f]+$', 'g');
  return s.replace(ws, '');
}

/** AI-A41：源 summaryRequest —— system 指令（逐条原文以空格拼接）+ user "Summarize:\n\n<content>"，响应格式 text */
export function buildSummaryRequest(content: string, settings: OpenAISettings, appLang: string): ChatCompletionRequest {
  const instructions: string[] = [
    'You are an assistant in an RSS reader app, summarizing article content.',
    `The app language is '${appLang}'.`,
    'Provide summaries in the article\'s language if 99% recognizable; otherwise, use the app language.',
    'First line must be exactly: \'Lang: "ISO code"\' with NO markdown formatting around the Lang line whatsoever.',
    'Keep summaries up to 100 words, 3 paragraphs, with up to 3 bullet points per paragraph.',
    'For readability use markdown formatting: **bold** for emphasis, *italics* for quotes, bullet points (-) for lists, # headers for sections, and > for block quotes.',
    'Use markdown to structure content and improve readability.',
    'Use only single language.',
    'Keep full quotes if any.'
  ];
  const req = new ChatCompletionRequest();
  req.model = settings.modelId;
  req.messages = [
    ChatMessage.of(ChatRole.System, instructions.join(' ')),
    ChatMessage.of(ChatRole.User, `Summarize:\n\n${content}`)
  ];
  req.responseFormatType = 'text';
  return req;
}

function messageOf(e: Object | null | undefined): string | null {
  if (e instanceof Error) {
    const err = e as Error;
    if (err.message !== undefined && err.message !== null && err.message.length > 0) {
      return err.message;
    }
    return null;
  }
  return e !== null && e !== undefined ? `${e}` : null;
}

function createdOrMin(m: OpenAIModel): number {
  return m.created !== null ? m.created : Number.NEGATIVE_INFINITY;
}

export class OpenAIApi {
  private static singleton: OpenAIApi | null = null;

  private readonly appLang: string;
  private readonly openAIClientFactory: OpenAIClientFactory;

  constructor(appLang: string, openAIClientFactory: OpenAIClientFactory) {
    this.appLang = appLang;
    this.openAIClientFactory = openAIClientFactory;
  }

  /** 源 DI 单例 OpenAIApi(appLang = Locale.getDefault().getISO3Language(), factory()) */
  static instance(): OpenAIApi {
    if (OpenAIApi.singleton === null) {
      OpenAIApi.singleton = new OpenAIApi(appIso3Language(), defaultOpenAIClientFactory);
    }
    return OpenAIApi.singleton as OpenAIApi;
  }

  /** AI-A33：源 listModelIds */
  async listModelIds(settings: OpenAISettings): Promise<ModelsResult> {
    if (isLocalTranslation(settings)) {
      return ModelsResult.success([]);
    }
    if (settings.key.length === 0) {
      return ModelsResult.missingToken();
    }
    if (isDeepL(settings)) {
      const v: DeepLVerificationResult = await verifyDeepLSettings(settings);
      return v.ok ? ModelsResult.success([]) : ModelsResult.error(v.message);
    }
    if (isPerplexity(settings)) {
      return ModelsResult.success([]);
    }
    if (isAzure(settings)) {
      if (settings.azureApiVersion.trim().length === 0) {
        return ModelsResult.azureApiVersionRequired();
      }
      if (settings.azureDeploymentId.trim().length === 0) {
        return ModelsResult.azureDeploymentIdRequired();
      }
    }
    try {
      const models: OpenAIModel[] = await this.openAIClientFactory(settings).models();
      // sortedByDescending { it.created }（稳定排序，null 视为最小）
      const indexed: OpenAIModel[] = models.slice();
      const order = new Map<OpenAIModel, number>();
      indexed.forEach((m: OpenAIModel, i: number) => {
        order.set(m, i);
      });
      indexed.sort((a: OpenAIModel, b: OpenAIModel): number => {
        const ca = createdOrMin(a);
        const cb = createdOrMin(b);
        if (ca !== cb) {
          return ca < cb ? 1 : -1;
        }
        return (order.get(a) as number) - (order.get(b) as number);
      });
      return ModelsResult.success(indexed.map((m: OpenAIModel) => m.id));
    } catch (e) {
      return ModelsResult.error(messageOf(e as Object));
    }
  }

  /** AI-A40..A43：源 summarize */
  async summarize(content: string, settings: OpenAISettings): Promise<SummaryResult> {
    if (isDeepL(settings)) {
      return SummaryResult.error(SUMMARIZATION_NOT_SUPPORTED);
    }
    if (isLocalTranslation(settings)) {
      return SummaryResult.error(SUMMARIZATION_NOT_SUPPORTED);
    }
    try {
      const response: ChatCompletion = await this.openAIClientFactory(settings)
        .chatCompletion(buildSummaryRequest(content, settings, this.appLang));
      const first = response.choices.length > 0 ? response.choices[0] : null;
      const text: string | null = first !== null ? first.content : null;
      if (text === null) {
        throw new Error('Response content is null');
      }
      const summary = parseSummaryResponse(text);
      const usage = response.usage;
      return SummaryResult.success(
        response.id,
        response.created,
        response.model,
        summary.content,
        usage !== null && usage.promptTokens !== null ? usage.promptTokens : 0,
        usage !== null && usage.completionTokens !== null ? usage.completionTokens : 0,
        usage !== null && usage.totalTokens !== null ? usage.totalTokens : 0,
        summary.lang
      );
    } catch (e) {
      const m = messageOf(e as Object);
      return SummaryResult.error(m !== null ? m : '');
    }
  }

  /** 源 translate（DeepL → DeepL；Local → 错误；其它 → 不支持） */
  async translate(content: string, targetLanguage: string, settings: OpenAISettings,
    preserveHtml: boolean = false): Promise<TranslationResult> {
    return translateViaApi(content, targetLanguage, settings, preserveHtml);
  }
}
