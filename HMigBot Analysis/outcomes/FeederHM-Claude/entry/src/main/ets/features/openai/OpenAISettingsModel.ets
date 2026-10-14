/*
 * OpenAISettingsModel — 设置页 AI/翻译 API 区段的纯逻辑与状态。
 * 源：ui/compose/settings/OpenAISection.kt（AIProviderPreset :1094-1218、validationMessage :1262-1323、matches、
 *     sanitizeSettings :1333-1348、TranslationLanguageOption / translationLanguageOptions / translationLanguageOption）、
 *     SettingsViewModel.kt（OpenAIModelsState / OpenAISettingsState / loadOpenAIModels :381-419）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { isBergamotTargetLanguage, normalizedBergamotCode } from '../translation/LanguageUtils';
import { translationString } from '../translation/TranslationUiSupport';
import {
  canUseAsTranslationApi, isBlankConfiguration, isDeepL, isLocalTranslation, LOCAL_TRANSLATION_PROVIDER_URL,
  ModelsResult, ModelsResultKind, OpenAIApi
} from './OpenAIApi';
import {
  compareCaseInsensitive, DEEPL_TARGET_LANGUAGES, displayLanguageName, isoLanguageCodes, systemLanguageTag
} from './LanguageTables';

/** 源 OpenAISectionType */
export enum OpenAISectionType {
  Summary = 'Summary',
  Translation = 'Translation'
}

// ------------------------------------------------------------------ 提供方预设（AIProviderPreset）

export enum AIProviderPreset {
  NONE = 'NONE',
  OPENAI_COMPATIBLE = 'OPENAI_COMPATIBLE',
  AZURE_OPENAI = 'AZURE_OPENAI',
  DEEPL = 'DEEPL',
  LOCAL_TRANSLATION = 'LOCAL_TRANSLATION'
}

export const ALL_PROVIDER_PRESETS: AIProviderPreset[] = [
  AIProviderPreset.NONE, AIProviderPreset.OPENAI_COMPATIBLE, AIProviderPreset.AZURE_OPENAI, AIProviderPreset.DEEPL,
  AIProviderPreset.LOCAL_TRANSLATION
];

/** DeepL 只读端点显示值（源 endpoint 字段） */
export const DEEPL_ENDPOINT: string = 'https://api.deepl.com/v2/translate';

export function presetTitle(p: AIProviderPreset): Resource {
  switch (p) {
    case AIProviderPreset.OPENAI_COMPATIBLE:
      return $r('app.string.provider_openai_compatible');
    case AIProviderPreset.AZURE_OPENAI:
      return $r('app.string.provider_azure_openai');
    case AIProviderPreset.DEEPL:
      return $r('app.string.provider_deepl');
    case AIProviderPreset.LOCAL_TRANSLATION:
      return $r('app.string.provider_local_translation');
    default:
      return $r('app.string.provider_none');
  }
}

/** 提供方名（字符串，供 `Provider: %1$s` 格式化） */
export function presetName(p: AIProviderPreset): string {
  switch (p) {
    case AIProviderPreset.OPENAI_COMPATIBLE:
      return translationString('provider_openai_compatible', 'OpenAI or compatible');
    case AIProviderPreset.AZURE_OPENAI:
      return translationString('provider_azure_openai', 'Azure OpenAI');
    case AIProviderPreset.DEEPL:
      return translationString('provider_deepl', 'DeepL');
    case AIProviderPreset.LOCAL_TRANSLATION:
      return translationString('provider_local_translation', 'Local offline');
    default:
      return translationString('provider_none', 'None');
  }
}

export function presetSupportsSummary(p: AIProviderPreset): boolean {
  return p === AIProviderPreset.NONE || p === AIProviderPreset.OPENAI_COMPATIBLE || p === AIProviderPreset.AZURE_OPENAI;
}

export function presetSupportsTranslation(p: AIProviderPreset): boolean {
  return p === AIProviderPreset.NONE || p === AIProviderPreset.DEEPL || p === AIProviderPreset.LOCAL_TRANSLATION;
}

export function presetIsTranslationOnly(p: AIProviderPreset): boolean {
  return p === AIProviderPreset.DEEPL || p === AIProviderPreset.LOCAL_TRANSLATION;
}

export function presetNeedsApiKey(p: AIProviderPreset): boolean {
  return p === AIProviderPreset.OPENAI_COMPATIBLE || p === AIProviderPreset.AZURE_OPENAI || p === AIProviderPreset.DEEPL;
}

/** AI-A05/A06：availableFor(section)，按枚举声明顺序 */
export function availableProviders(section: OpenAISectionType): AIProviderPreset[] {
  return ALL_PROVIDER_PRESETS.filter((p: AIProviderPreset) =>
  section === OpenAISectionType.Summary ? presetSupportsSummary(p) : presetSupportsTranslation(p));
}

function containsIgnoreCase(s: string, needle: string): boolean {
  return s.toLowerCase().includes(needle.toLowerCase());
}

/** AI-A07：fromSettings */
export function providerFromSettings(s: OpenAISettings): AIProviderPreset {
  if (isBlankConfiguration(s)) {
    return AIProviderPreset.NONE;
  }
  if (containsIgnoreCase(s.baseUrl, 'openai.azure.com')) {
    return AIProviderPreset.AZURE_OPENAI;
  }
  if (isLocalTranslation(s)) {
    return AIProviderPreset.LOCAL_TRANSLATION;
  }
  if (isDeepL(s)) {
    return AIProviderPreset.DEEPL;
  }
  return AIProviderPreset.OPENAI_COMPATIBLE;
}

/** AI-A09：applyTo（返回新实例，timeoutSeconds 保留） */
export function applyPreset(p: AIProviderPreset, settings: OpenAISettings): OpenAISettings {
  const c = settings.copy();
  switch (p) {
    case AIProviderPreset.NONE:
      c.key = '';
      c.modelId = '';
      c.baseUrl = '';
      c.azureApiVersion = '';
      c.azureDeploymentId = '';
      break;
    case AIProviderPreset.OPENAI_COMPATIBLE:
      c.baseUrl = '';
      c.azureApiVersion = '';
      c.azureDeploymentId = '';
      break;
    case AIProviderPreset.AZURE_OPENAI:
      c.baseUrl = containsIgnoreCase(settings.baseUrl, 'openai.azure.com') ? settings.baseUrl : '';
      break;
    case AIProviderPreset.DEEPL:
      if (containsIgnoreCase(settings.baseUrl, 'api-free.deepl.com')) {
        c.baseUrl = 'https://api-free.deepl.com';
      } else if (settings.key.endsWith(':fx')) {
        c.baseUrl = 'https://api-free.deepl.com';
      } else {
        c.baseUrl = 'https://api.deepl.com';
      }
      c.azureApiVersion = '';
      c.azureDeploymentId = '';
      c.modelId = '';
      break;
    case AIProviderPreset.LOCAL_TRANSLATION:
      c.key = '';
      c.modelId = '';
      c.baseUrl = LOCAL_TRANSLATION_PROVIDER_URL;
      c.azureApiVersion = '';
      c.azureDeploymentId = '';
      break;
    default:
      break;
  }
  return c;
}

/** AI-A08：sanitizeSettings */
export function sanitizeSettings(section: OpenAISectionType, settings: OpenAISettings): OpenAISettings {
  if (isBlankConfiguration(settings)) {
    return settings;
  }
  const translationOnly = isDeepL(settings) || isLocalTranslation(settings);
  if (section === OpenAISectionType.Summary) {
    return translationOnly ? new OpenAISettings() : settings;
  }
  return translationOnly ? settings : new OpenAISettings();
}

/** AI-A03：行是否已配置（key 非空白 || canUseAsTranslationApi） */
export function isSectionConfigured(settings: OpenAISettings): boolean {
  return settings.key.trim().length > 0 || canUseAsTranslationApi(settings);
}

// ------------------------------------------------------------------ API key 掩码（VisualTransformationApiKey）

/** AI-A11：长度 ≥10 → 前 4 + 星号 + 末 3（总长不变）；否则原样 */
export function maskApiKey(text: string): string {
  if (text.trim().length === 0 || text.length < 10) {
    return text;
  }
  const PREFIX_LENGTH = 3;
  const SUFFIX_LENGTH = 4;
  const stars = '*'.repeat(text.length - PREFIX_LENGTH - SUFFIX_LENGTH);
  return text.substring(0, PREFIX_LENGTH + 1) + stars + text.substring(text.length - PREFIX_LENGTH);
}

/** 掩码输入框编辑还原：用替换区间把可见文本的改动映射回原文（掩码是恒等偏移映射） */
export function applyMaskedEdit(raw: string, oldShown: string, newShown: string, beforeStart: number | null,
  beforeEnd: number | null, afterStart: number | null, afterEnd: number | null): string {
  if (beforeStart !== null && beforeEnd !== null && afterStart !== null && afterEnd !== null &&
    beforeStart >= 0 && beforeEnd <= raw.length && beforeStart <= beforeEnd && afterStart <= afterEnd) {
    return raw.substring(0, beforeStart) + newShown.substring(afterStart, afterEnd) + raw.substring(beforeEnd);
  }
  let p = 0;
  while (p < oldShown.length && p < newShown.length && oldShown.charAt(p) === newShown.charAt(p)) {
    p++;
  }
  let s = 0;
  while (s < oldShown.length - p && s < newShown.length - p &&
    oldShown.charAt(oldShown.length - 1 - s) === newShown.charAt(newShown.length - 1 - s)) {
    s++;
  }
  return raw.substring(0, p) + newShown.substring(p, newShown.length - s) + raw.substring(raw.length - s);
}

// ------------------------------------------------------------------ 超时

/** 源 isTimeoutInputValid：非空且 toIntOrNull ∈ 30..600 */
export function isTimeoutInputValid(input: string): boolean {
  if (input.trim().length === 0) {
    return false;
  }
  if (!new RegExp('^[+-]?\\d+$').test(input)) {
    return false;
  }
  const n = Number.parseInt(input, 10);
  return n >= 30 && n <= 600 && n <= 2147483647;
}

// ------------------------------------------------------------------ 模型加载状态（OpenAIModelsState）

export enum ModelsStateKind {
  None = 'None',
  Loading = 'Loading',
  Success = 'Success',
  Error = 'Error'
}

export class OpenAIModelsState {
  readonly kind: ModelsStateKind;
  readonly ids: string[];
  readonly message: string;
  /** 发起时的设置（None 为 null） */
  readonly settings: OpenAISettings | null;

  constructor(kind: ModelsStateKind, ids: string[], message: string, settings: OpenAISettings | null) {
    this.kind = kind;
    this.ids = ids;
    this.message = message;
    this.settings = settings;
  }

  static none(): OpenAIModelsState {
    return new OpenAIModelsState(ModelsStateKind.None, [], '', null);
  }

  /** AI-A34：matches(current) —— 设置完全相等才算匹配（None 恒不匹配） */
  matches(current: OpenAISettings): boolean {
    const s = this.settings;
    return this.kind !== ModelsStateKind.None && s !== null && s.equals(current);
  }

  /** 草稿变化后旧结果视为 None */
  matchingOrNone(current: OpenAISettings): OpenAIModelsState {
    return this.matches(current) ? this : OpenAIModelsState.none();
  }
}

/** AI-A34：ModelsResult → OpenAIModelsState */
export function toModelsState(res: ModelsResult, settings: OpenAISettings): OpenAIModelsState {
  switch (res.kind) {
    case ModelsResultKind.Error:
      return new OpenAIModelsState(ModelsStateKind.Error, [], res.message !== null ? res.message : '', settings);
    case ModelsResultKind.Success:
      return new OpenAIModelsState(ModelsStateKind.Success, res.ids, '', settings);
    default:
      return OpenAIModelsState.none();
  }
}

/** 每个区段在 VM 中的状态（源 OpenAISettingsState.modelsResult / showModelsError，跨对话框保留） */
@ObservedV2
export class OpenAISectionVmState {
  @Trace modelsState: OpenAIModelsState = OpenAIModelsState.none();
  @Trace showModelsError: boolean = false;
  @Trace isEditMode: boolean = false;

  /** 源 loadOpenAIModels（无取消；以最后完成者为准，matches 兜底） */
  loadModels(settings: OpenAISettings): void {
    const snapshot = settings.copy();
    this.modelsState = new OpenAIModelsState(ModelsStateKind.Loading, [], '', snapshot);
    OpenAIApi.instance().listModelIds(snapshot).then((res: ModelsResult) => {
      this.modelsState = toModelsState(res, snapshot);
    }).catch((e: Error) => {
      this.modelsState = new OpenAIModelsState(ModelsStateKind.Error, [], e?.message ?? '', snapshot);
    });
  }
}

/** 源 SettingsViewModel 中的 summaryAIState / translationApiState（模块级单例） */
export class OpenAISettingsVm {
  private static singleton: OpenAISettingsVm | null = null;
  readonly summary: OpenAISectionVmState = new OpenAISectionVmState();
  readonly translation: OpenAISectionVmState = new OpenAISectionVmState();

  static instance(): OpenAISettingsVm {
    if (OpenAISettingsVm.singleton === null) {
      OpenAISettingsVm.singleton = new OpenAISettingsVm();
    }
    return OpenAISettingsVm.singleton as OpenAISettingsVm;
  }

  stateOf(section: OpenAISectionType): OpenAISectionVmState {
    return section === OpenAISectionType.Summary ? this.summary : this.translation;
  }
}

// ------------------------------------------------------------------ 校验提示（validationMessage）

export enum ValidationKind {
  EnterDeepLKey = 'EnterDeepLKey',
  EnterApiKey = 'EnterApiKey',
  TimeoutInvalid = 'TimeoutInvalid',
  EnterModelId = 'EnterModelId',
  VerifyingApi = 'VerifyingApi',
  ApiNotVerified = 'ApiNotVerified',
  EnterAzureEndpoint = 'EnterAzureEndpoint',
  EnterAzureDeploymentId = 'EnterAzureDeploymentId',
  EnterAzureApiVersion = 'EnterAzureApiVersion',
  VerifyingAzure = 'VerifyingAzure',
  AzureNotVerified = 'AzureNotVerified',
  VerifyingDeepL = 'VerifyingDeepL',
  DeepLNotVerified = 'DeepLNotVerified',
  /** 远端错误原文 */
  Raw = 'Raw'
}

export class ValidationMessage {
  readonly kind: ValidationKind;
  readonly raw: string;

  constructor(kind: ValidationKind, raw: string = '') {
    this.kind = kind;
    this.raw = raw;
  }
}

export function validationText(v: ValidationMessage): ResourceStr {
  switch (v.kind) {
    case ValidationKind.EnterDeepLKey:
      return $r('app.string.enter_deepl_api_key_before_saving');
    case ValidationKind.EnterApiKey:
      return $r('app.string.enter_api_key_before_saving');
    case ValidationKind.TimeoutInvalid:
      return $r('app.string.time_out_validation_error');
    case ValidationKind.EnterModelId:
      return $r('app.string.enter_model_id_before_saving');
    case ValidationKind.VerifyingApi:
      return $r('app.string.verifying_api_settings');
    case ValidationKind.ApiNotVerified:
      return $r('app.string.api_settings_could_not_be_verified');
    case ValidationKind.EnterAzureEndpoint:
      return $r('app.string.enter_azure_endpoint_before_saving');
    case ValidationKind.EnterAzureDeploymentId:
      return $r('app.string.enter_azure_deployment_id_before_saving');
    case ValidationKind.EnterAzureApiVersion:
      return $r('app.string.enter_azure_api_version_before_saving');
    case ValidationKind.VerifyingAzure:
      return $r('app.string.verifying_azure_openai_settings');
    case ValidationKind.AzureNotVerified:
      return $r('app.string.azure_openai_settings_could_not_be_verified');
    case ValidationKind.VerifyingDeepL:
      return $r('app.string.verifying_deepl_key');
    case ValidationKind.DeepLNotVerified:
      return $r('app.string.deepl_key_could_not_be_verified');
    default:
      return v.raw;
  }
}

function errorOr(models: OpenAIModelsState, fallback: ValidationKind): ValidationMessage {
  return models.message.trim().length > 0 ? new ValidationMessage(ValidationKind.Raw, models.message) :
    new ValidationMessage(fallback);
}

/** AI-A17..A21：源 OpenAISettings.validationMessage（null = 可保存） */
export function validationMessage(s: OpenAISettings, provider: AIProviderPreset,
  models: OpenAIModelsState): ValidationMessage | null {
  if (provider === AIProviderPreset.NONE) {
    return null;
  }
  if (presetNeedsApiKey(provider) && s.key.trim().length === 0) {
    return new ValidationMessage(provider === AIProviderPreset.DEEPL ? ValidationKind.EnterDeepLKey :
    ValidationKind.EnterApiKey);
  }
  if (!isTimeoutInputValid(`${s.timeoutSeconds}`)) {
    return new ValidationMessage(ValidationKind.TimeoutInvalid);
  }
  const pending = models.kind === ModelsStateKind.None || models.kind === ModelsStateKind.Loading;
  switch (provider) {
    case AIProviderPreset.OPENAI_COMPATIBLE:
      if (s.modelId.trim().length === 0) {
        return new ValidationMessage(ValidationKind.EnterModelId);
      }
      if (pending) {
        return new ValidationMessage(ValidationKind.VerifyingApi);
      }
      if (models.kind === ModelsStateKind.Error) {
        return errorOr(models, ValidationKind.ApiNotVerified);
      }
      return null;
    case AIProviderPreset.AZURE_OPENAI:
      if (s.modelId.trim().length === 0) {
        return new ValidationMessage(ValidationKind.EnterModelId);
      }
      if (s.baseUrl.trim().length === 0) {
        return new ValidationMessage(ValidationKind.EnterAzureEndpoint);
      }
      if (s.azureDeploymentId.trim().length === 0) {
        return new ValidationMessage(ValidationKind.EnterAzureDeploymentId);
      }
      if (s.azureApiVersion.trim().length === 0) {
        return new ValidationMessage(ValidationKind.EnterAzureApiVersion);
      }
      if (pending) {
        return new ValidationMessage(ValidationKind.VerifyingAzure);
      }
      if (models.kind === ModelsStateKind.Error) {
        return errorOr(models, ValidationKind.AzureNotVerified);
      }
      return null;
    case AIProviderPreset.DEEPL:
      if (pending) {
        return new ValidationMessage(ValidationKind.VerifyingDeepL);
      }
      if (models.kind === ModelsStateKind.Error) {
        return errorOr(models, ValidationKind.DeepLNotVerified);
      }
      return null;
    default:
      return null;
  }
}

// ------------------------------------------------------------------ 翻译语言选项（TranslationLanguageOption）

export class TranslationLanguageOption {
  readonly code: string;
  readonly name: string;
  readonly label: string;

  constructor(code: string, name: string) {
    this.code = code;
    this.name = name;
    this.label = `${name} (${code})`;
  }

  normalizedBergamotCode(): string {
    return normalizedBergamotCode(this.code);
  }
}

function sortByName(options: TranslationLanguageOption[]): TranslationLanguageOption[] {
  return options.sort((a: TranslationLanguageOption, b: TranslationLanguageOption): number =>
  compareCaseInsensitive(a.name, b.name));
}

export function deepLTargetLanguageOptions(): TranslationLanguageOption[] {
  return sortByName(DEEPL_TARGET_LANGUAGES.map((row: string[]) => new TranslationLanguageOption(row[0], row[1])));
}

let isoOptionsCache: TranslationLanguageOption[] | null = null;
let isoOptionsLocale: string = '';

/** 源 isoLanguageOptions()：系统显示名，空名剔除，按码去重、按名排序 */
export function isoLanguageOptions(): TranslationLanguageOption[] {
  const localeKey = systemLanguageTag();
  if (isoOptionsCache !== null && isoOptionsLocale === localeKey) {
    return isoOptionsCache as TranslationLanguageOption[];
  }
  const seen = new Set<string>();
  const out: TranslationLanguageOption[] = [];
  const codes = isoLanguageCodes();
  for (let i = 0; i < codes.length; i++) {
    const code = codes[i];
    const name = displayLanguageName(code);
    if (name.trim().length === 0 || seen.has(code.toLowerCase())) {
      continue;
    }
    seen.add(code.toLowerCase());
    out.push(new TranslationLanguageOption(code, name));
  }
  isoOptionsCache = sortByName(out);
  isoOptionsLocale = localeKey;
  return isoOptionsCache as TranslationLanguageOption[];
}

/** AI-A24/A25：translationLanguageOptions(provider, showOnlyBergamotLanguages) */
export function translationLanguageOptions(provider: AIProviderPreset,
  showOnlyBergamotLanguages: boolean): TranslationLanguageOption[] {
  const options = provider === AIProviderPreset.DEEPL ? deepLTargetLanguageOptions() : isoLanguageOptions();
  if (provider === AIProviderPreset.LOCAL_TRANSLATION && showOnlyBergamotLanguages) {
    return options.filter((o: TranslationLanguageOption) => isBergamotTargetLanguage(o.code));
  }
  return options;
}

function findOption(options: TranslationLanguageOption[], trimmed: string): TranslationLanguageOption | null {
  const t = trimmed.toLowerCase();
  for (let i = 0; i < options.length; i++) {
    if (options[i].code.toLowerCase() === t || options[i].name.toLowerCase() === t) {
      return options[i];
    }
  }
  return null;
}

/** 源 translationLanguageOption(provider, language) */
export function translationLanguageOption(provider: AIProviderPreset, language: string): TranslationLanguageOption | null {
  const trimmed = language.trim();
  if (trimmed.length === 0) {
    return null;
  }
  if (provider === AIProviderPreset.DEEPL) {
    const d = findOption(deepLTargetLanguageOptions(), trimmed);
    if (d !== null) {
      return d;
    }
  }
  const iso = findOption(isoLanguageOptions(), trimmed);
  if (iso !== null) {
    return iso;
  }
  // Locale.forLanguageTag(trimmed)：合法 BCP47 且语言非 und
  if (new RegExp('^[a-zA-Z]{2,8}(-[a-zA-Z0-9]{1,8})*$').test(trimmed)) {
    const lang = trimmed.split('-')[0].toLowerCase();
    if (lang !== 'und') {
      const name = displayLanguageName(lang);
      return new TranslationLanguageOption(trimmed, name.trim().length > 0 ? name : trimmed);
    }
  }
  return null;
}

/** AI-A26：Local 说明是否追加 Bergamot 句 */
export function selectedIsBergamotLanguage(selected: TranslationLanguageOption | null): boolean {
  return selected !== null && isBergamotTargetLanguage(selected.code);
}

/** AI-A28：翻译开关可见（翻译设置 canUseAsTranslationApi && 首选语言非空） */
export function canTranslateWithSettings(translationSettings: OpenAISettings, preferredLanguage: string): boolean {
  return canUseAsTranslationApi(translationSettings) && preferredLanguage.trim().length > 0;
}
