/*
 * LanguageUtils — 翻译语言工具。
 * 源：model/TranslationLanguageUtils.kt（检测文本准备/采样/字母数门槛/检测语言与目标匹配）、
 *     localtranslation/TranslationLanguageCodes.kt（normalizeLanguageCode）、
 *     openai/OpenAIApi.kt（OpenAISettings.isDeepL/isLocalTranslation/isValid/canTranslate/canUseAsTranslationApi、
 *     toDeepLTargetLanguageCode）、ui/compose/settings/OpenAISection.kt（BERGAMOT_TARGET_LANGUAGE_CODES、normalizedBergamotCode）。
 * 单测 TranslationLanguageUtilsKtTest → TRANSLATION_LANGUAGE_MATCH_VECTORS / PREPARE_TEXT_VECTORS（供 src/test 消费）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { parseHtml } from '../../core/html/HtmlParser';

export const LOCAL_TRANSLATION_PROVIDER_URL: string = 'local://translation';
export const MAX_LANGUAGE_DETECTION_TEXT_LENGTH: number = 4000;
export const MIN_LANGUAGE_DETECTION_LETTERS: number = 20;

// ------------------------------------------------------------------ OpenAISettings 判定（OpenAIApi.kt:389-427）

export function isAzure(s: OpenAISettings): boolean {
  return s.baseUrl.toLowerCase().includes('openai.azure.com');
}

export function isPerplexity(s: OpenAISettings): boolean {
  return s.baseUrl.toLowerCase().includes('api.perplexity.ai');
}

export function isDeepL(s: OpenAISettings): boolean {
  return s.baseUrl.toLowerCase().includes('deepl.com');
}

export function isLocalTranslation(s: OpenAISettings): boolean {
  return s.baseUrl === LOCAL_TRANSLATION_PROVIDER_URL;
}

export function isValidAiSettings(s: OpenAISettings): boolean {
  if (isLocalTranslation(s)) {
    return true;
  }
  if (isDeepL(s)) {
    return s.key.length > 0;
  }
  return s.modelId.length > 0 && s.key.length > 0 &&
    (isAzure(s) ? (s.azureApiVersion.trim().length > 0 && s.azureDeploymentId.trim().length > 0) : true);
}

export function canSummarize(s: OpenAISettings): boolean {
  return isValidAiSettings(s) && !isDeepL(s) && !isLocalTranslation(s);
}

/** OpenAISettings.canTranslate = isValid */
export function canTranslate(s: OpenAISettings): boolean {
  return isValidAiSettings(s);
}

/** TR-A01：canTranslate && (isDeepL || isLocalTranslation) */
export function canUseAsTranslationApi(s: OpenAISettings): boolean {
  return canTranslate(s) && (isDeepL(s) || isLocalTranslation(s));
}

/** 翻译缓存 provider 段（TranslationManager.cacheFile） */
export function translationProviderKey(s: OpenAISettings): string {
  if (isLocalTranslation(s)) {
    return 'local';
  }
  if (isDeepL(s)) {
    return 'deepl';
  }
  return 'openai';
}

// ------------------------------------------------------------------ 字符工具（Kotlin Char 语义）

function buildLetterRe(): RegExp | null {
  try {
    return new RegExp('\\p{L}', 'u');
  } catch (e) {
    return null;
  }
}

const LETTER_RE: RegExp | null = buildLetterRe();
const WHITESPACE_CHAR_RE: RegExp = new RegExp('\\s');
/** java.util.regex "\\s+"（非 UNICODE_CHARACTER_CLASS）：仅 [ \t\n\x0B\f\r] */
const JAVA_WS_RUN_RE: RegExp = new RegExp('[ \\t\\n\\u000B\\f\\r]+', 'g');

/** Char.isLetter（逐 UTF-16 码元，代理项不算字母，与 Kotlin 一致） */
export function isLetterChar(ch: string): boolean {
  const code = ch.charCodeAt(0);
  if (code >= 0xd800 && code <= 0xdfff) {
    return false;
  }
  if (LETTER_RE !== null) {
    return LETTER_RE.test(ch);
  }
  // 运行时不支持 \p{} 时的近似：有大小写之分，或落在常见无大小写文字区段（CJK/假名/韩文/阿拉伯/希伯来/泰/天城等）
  if (ch.toLowerCase() !== ch.toUpperCase()) {
    return true;
  }
  return (code >= 0x05d0 && code <= 0x05ea) || (code >= 0x0620 && code <= 0x064a) || (code >= 0x0671 && code <= 0x06d3) ||
    (code >= 0x0904 && code <= 0x0939) || (code >= 0x0e01 && code <= 0x0e30) || (code >= 0x3041 && code <= 0x30ff) ||
    (code >= 0x3400 && code <= 0x9fff) || (code >= 0xac00 && code <= 0xd7a3) || code === 0x00aa || code === 0x00ba;
}

export function isWhitespaceChar(ch: string): boolean {
  return WHITESPACE_CHAR_RE.test(ch);
}

export function countLetters(s: string): number {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    if (isLetterChar(s.charAt(i))) {
      n++;
    }
  }
  return n;
}

// ------------------------------------------------------------------ 检测文本准备（TranslationLanguageUtils.kt:15-60）

function prepareFullTextForLanguageDetection(content: string, preserveHtml: boolean): string {
  const raw = preserveHtml ? parseHtml(content).text() : content;
  return raw.replace(JAVA_WS_RUN_RE, ' ').trim();
}

/** TR-A12：HTML 去标签、空白折叠、trim，截前 4000 字符 */
export function prepareTextForLanguageDetection(content: string, preserveHtml: boolean): string {
  return prepareFullTextForLanguageDetection(content, preserveHtml).substring(0, MAX_LANGUAGE_DETECTION_TEXT_LENGTH);
}

/** TR-A09：长文取头/中/尾各 4000 字符（去重） */
export function prepareTextSamplesForLanguageDetection(content: string, preserveHtml: boolean): string[] {
  const text = prepareFullTextForLanguageDetection(content, preserveHtml);
  if (text.length <= MAX_LANGUAGE_DETECTION_TEXT_LENGTH) {
    return [text];
  }
  const middleStart = Math.max(0, Math.floor((text.length - MAX_LANGUAGE_DETECTION_TEXT_LENGTH) / 2));
  const endStart = Math.max(0, text.length - MAX_LANGUAGE_DETECTION_TEXT_LENGTH);
  const samples: string[] = [
    text.substring(0, MAX_LANGUAGE_DETECTION_TEXT_LENGTH),
    text.substring(middleStart, middleStart + MAX_LANGUAGE_DETECTION_TEXT_LENGTH),
    text.substring(endStart)
  ];
  const out: string[] = [];
  for (let i = 0; i < samples.length; i++) {
    if (out.indexOf(samples[i]) < 0) {
      out.push(samples[i]);
    }
  }
  return out;
}

/** TR-A10：字母数 ≥ 20 才参与检测 */
export function hasEnoughTextForLanguageDetection(content: string): boolean {
  return countLetters(content) >= MIN_LANGUAGE_DETECTION_LETTERS;
}

// ------------------------------------------------------------------ 语言匹配（TranslationLanguageUtils.kt:62-194）

export class ComparableTranslationLanguage {
  language: string;
  region: string | null;

  constructor(language: string, region: string | null = null) {
    this.language = language;
    this.region = region;
  }
}

const ALPHA_2_8: RegExp = new RegExp('^[a-zA-Z]{2,8}$');
const ALPHA_3: RegExp = new RegExp('^[a-zA-Z]{3}$');
const ALPHA_4: RegExp = new RegExp('^[a-zA-Z]{4}$');
const REGION_RE: RegExp = new RegExp('^([a-zA-Z]{2}|[0-9]{3})$');

class ParsedLocale {
  language: string = '';
  country: string = '';
}

/** java.util.Locale.forLanguageTag 的 language/country 子集（不合法后缀截断） */
function forLanguageTag(tag: string): ParsedLocale {
  const out = new ParsedLocale();
  const parts = tag.split('-');
  if (parts.length === 0 || !ALPHA_2_8.test(parts[0])) {
    return out;
  }
  const lang = parts[0].toLowerCase();
  out.language = lang === 'und' ? '' : lang;
  let i = 1;
  if (lang.length <= 3) {
    let ext = 0;
    while (i < parts.length && ext < 3 && ALPHA_3.test(parts[i])) {
      i++;
      ext++;
    }
  }
  if (i < parts.length && ALPHA_4.test(parts[i])) {
    i++;
  }
  if (i < parts.length && REGION_RE.test(parts[i])) {
    out.country = parts[i].toUpperCase();
  }
  return out;
}

function substringBefore(s: string, delim: string): string {
  const i = s.indexOf(delim);
  return i < 0 ? s : s.substring(0, i);
}

function firstRegionLike(parts: string[]): string | null {
  for (let i = 1; i < parts.length; i++) {
    if (parts[i].length === 2 || parts[i].length === 3) {
      return parts[i];
    }
  }
  return null;
}

function toCanonicalLanguageCode(s: string): string {
  const l = s.toLowerCase();
  return l === 'nb' ? 'no' : l;
}

function asComparableDetectedLanguage(value: string): ComparableTranslationLanguage | null {
  const normalized = value.trim().split('_').join('-');
  if (normalized.trim().length === 0) {
    return null;
  }
  const locale = forLanguageTag(normalized);
  let language = locale.language;
  if (language.length === 0 || language === 'und') {
    language = substringBefore(normalized, '-');
    if (language.trim().length === 0) {
      return null;
    }
  }
  let region: string | null = locale.country.length > 0 ? locale.country : firstRegionLike(normalized.split('-'));
  return new ComparableTranslationLanguage(toCanonicalLanguageCode(language), region !== null ? region.toUpperCase() : null);
}

function deepLComparableTarget(code: string): ComparableTranslationLanguage | null {
  switch (code) {
    case 'ENGLISH': case 'EN': return new ComparableTranslationLanguage('en');
    case 'EN_GB': case 'ENGLISH_UK': case 'ENGLISH_GB': case 'BRITISH_ENGLISH':
      return new ComparableTranslationLanguage('en', 'GB');
    case 'EN_US': case 'ENGLISH_US': case 'AMERICAN_ENGLISH':
      return new ComparableTranslationLanguage('en', 'US');
    case 'GERMAN': case 'DE': return new ComparableTranslationLanguage('de');
    case 'FRENCH': case 'FR': return new ComparableTranslationLanguage('fr');
    case 'SPANISH': case 'ES': return new ComparableTranslationLanguage('es');
    case 'PORTUGUESE': case 'PT': return new ComparableTranslationLanguage('pt');
    case 'PT_BR': case 'PORTUGUESE_BR': case 'BRAZILIAN_PORTUGUESE':
      return new ComparableTranslationLanguage('pt', 'BR');
    case 'PT_PT': case 'PORTUGUESE_PT': case 'EUROPEAN_PORTUGUESE':
      return new ComparableTranslationLanguage('pt', 'PT');
    case 'ITALIAN': case 'IT': return new ComparableTranslationLanguage('it');
    case 'DUTCH': case 'NL': return new ComparableTranslationLanguage('nl');
    case 'POLISH': case 'PL': return new ComparableTranslationLanguage('pl');
    case 'RUSSIAN': case 'RU': return new ComparableTranslationLanguage('ru');
    case 'JAPANESE': case 'JA': return new ComparableTranslationLanguage('ja');
    case 'CHINESE': case 'ZH': return new ComparableTranslationLanguage('zh');
    case 'CZECH': case 'CS': return new ComparableTranslationLanguage('cs');
    case 'DANISH': case 'DA': return new ComparableTranslationLanguage('da');
    case 'GREEK': case 'EL': return new ComparableTranslationLanguage('el');
    case 'FINNISH': case 'FI': return new ComparableTranslationLanguage('fi');
    case 'HUNGARIAN': case 'HU': return new ComparableTranslationLanguage('hu');
    case 'INDONESIAN': case 'ID': return new ComparableTranslationLanguage('id');
    case 'KOREAN': case 'KO': return new ComparableTranslationLanguage('ko');
    case 'LITHUANIAN': case 'LT': return new ComparableTranslationLanguage('lt');
    case 'LATVIAN': case 'LV': return new ComparableTranslationLanguage('lv');
    case 'NORWEGIAN': case 'NB': case 'NORWEGIAN_BOKMAL': return new ComparableTranslationLanguage('no');
    case 'ROMANIAN': case 'RO': return new ComparableTranslationLanguage('ro');
    case 'SLOVAK': case 'SK': return new ComparableTranslationLanguage('sk');
    case 'SLOVENIAN': case 'SL': return new ComparableTranslationLanguage('sl');
    case 'SWEDISH': case 'SV': return new ComparableTranslationLanguage('sv');
    case 'TURKISH': case 'TR': return new ComparableTranslationLanguage('tr');
    case 'UKRAINIAN': case 'UK': return new ComparableTranslationLanguage('uk');
    default: return fallbackComparableTarget(code, true);
  }
}

function fallbackComparableTarget(code: string, preserveRegion: boolean): ComparableTranslationLanguage | null {
  const normalized = code.toLowerCase().split('_').join('-');
  if (normalized.trim().length === 0) {
    return null;
  }
  const locale = forLanguageTag(normalized);
  let language = locale.language;
  if (language.length === 0 || language === 'und') {
    language = substringBefore(normalized, '-');
    if (language.trim().length === 0) {
      return null;
    }
  }
  let region: string | null = null;
  if (preserveRegion) {
    region = locale.country.length > 0 ? locale.country : firstRegionLike(normalized.split('-'));
  }
  return new ComparableTranslationLanguage(toCanonicalLanguageCode(language), region !== null ? region.toUpperCase() : null);
}

function asComparableTranslationTarget(value: string, settings: OpenAISettings): ComparableTranslationLanguage | null {
  const normalized = value.trim().split('-').join('_').toUpperCase();
  if (normalized.trim().length === 0) {
    return null;
  }
  if (isDeepL(settings)) {
    return deepLComparableTarget(normalized);
  }
  const generic = deepLComparableTarget(normalized);
  return generic !== null ? generic : fallbackComparableTarget(normalized, true);
}

/** TR-A11：语言码相同且（目标无区域或区域相同）才匹配；nb ≡ no */
export function detectedLanguageMatchesTranslationTarget(detectedLanguage: string, targetLanguage: string,
  settings: OpenAISettings): boolean {
  const detected = asComparableDetectedLanguage(detectedLanguage);
  if (detected === null) {
    return false;
  }
  const target = asComparableTranslationTarget(targetLanguage, settings);
  if (target === null) {
    return false;
  }
  return detected.language === target.language && (target.region === null || detected.region === target.region);
}

// ------------------------------------------------------------------ 本地翻译语言码（TranslationLanguageCodes.kt）

export function normalizeLanguageCode(language: string): string {
  const normalized = substringBefore(language.trim().toLowerCase().split('_').join('-'), '-');
  switch (normalized) {
    case 'english': case 'en': return 'en';
    case 'german': case 'de': return 'de';
    case 'french': case 'fr': return 'fr';
    case 'spanish': case 'es': return 'es';
    case 'portuguese': case 'pt': return 'pt';
    case 'italian': case 'it': return 'it';
    case 'dutch': case 'nl': return 'nl';
    case 'polish': case 'pl': return 'pl';
    case 'russian': case 'ru': return 'ru';
    case 'czech': case 'cs': return 'cs';
    case 'estonian': case 'et': return 'et';
    case 'bulgarian': case 'bg': return 'bg';
    case 'icelandic': case 'is': return 'is';
    case 'norwegian': case 'nb': case 'nn': return 'nb';
    case 'persian': case 'fa': return 'fa';
    case 'swedish': case 'sv': return 'sv';
    case 'ukrainian': case 'uk': return 'uk';
    default: return normalized;
  }
}

// ------------------------------------------------------------------ DeepL 目标语言码（AI-A53，OpenAIApi.kt:445）

const DEEPL_TARGET_CODES: Map<string, string> = new Map<string, string>([
  ['ENGLISH', 'EN'], ['EN', 'EN'],
  ['EN_GB', 'EN-GB'], ['ENGLISH_UK', 'EN-GB'], ['ENGLISH_GB', 'EN-GB'], ['BRITISH_ENGLISH', 'EN-GB'],
  ['EN_US', 'EN-US'], ['ENGLISH_US', 'EN-US'], ['AMERICAN_ENGLISH', 'EN-US'],
  ['GERMAN', 'DE'], ['DE', 'DE'], ['FRENCH', 'FR'], ['FR', 'FR'], ['SPANISH', 'ES'], ['ES', 'ES'],
  ['PORTUGUESE', 'PT'], ['PT', 'PT'],
  ['PT_BR', 'PT-BR'], ['PORTUGUESE_BR', 'PT-BR'], ['BRAZILIAN_PORTUGUESE', 'PT-BR'],
  ['PT_PT', 'PT-PT'], ['PORTUGUESE_PT', 'PT-PT'], ['EUROPEAN_PORTUGUESE', 'PT-PT'],
  ['ITALIAN', 'IT'], ['IT', 'IT'], ['DUTCH', 'NL'], ['NL', 'NL'], ['POLISH', 'PL'], ['PL', 'PL'],
  ['RUSSIAN', 'RU'], ['RU', 'RU'], ['JAPANESE', 'JA'], ['JA', 'JA'], ['CHINESE', 'ZH'], ['ZH', 'ZH'],
  ['CZECH', 'CS'], ['CS', 'CS'], ['DANISH', 'DA'], ['DA', 'DA'], ['GREEK', 'EL'], ['EL', 'EL'],
  ['FINNISH', 'FI'], ['FI', 'FI'], ['HUNGARIAN', 'HU'], ['HU', 'HU'], ['INDONESIAN', 'ID'], ['ID', 'ID'],
  ['KOREAN', 'KO'], ['KO', 'KO'], ['LITHUANIAN', 'LT'], ['LT', 'LT'], ['LATVIAN', 'LV'], ['LV', 'LV'],
  ['NORWEGIAN', 'NB'], ['NB', 'NB'], ['NORWEGIAN_BOKMAL', 'NB'], ['ROMANIAN', 'RO'], ['RO', 'RO'],
  ['SLOVAK', 'SK'], ['SK', 'SK'], ['SLOVENIAN', 'SL'], ['SL', 'SL'], ['SWEDISH', 'SV'], ['SV', 'SV'],
  ['TURKISH', 'TR'], ['TR', 'TR'], ['UKRAINIAN', 'UK'], ['UK', 'UK']
]);

/** trim → 大写 → '-'→'_' → 查表；未命中 '_'→'-' */
export function toDeepLTargetLanguageCode(language: string): string {
  const normalized = language.trim().toUpperCase().split('-').join('_');
  const mapped = DEEPL_TARGET_CODES.get(normalized);
  return mapped !== undefined ? mapped : normalized.split('_').join('-');
}

// ------------------------------------------------------------------ 设置页 Bergamot 语言集合（OpenAISection.kt:717/910）

export const BERGAMOT_TARGET_LANGUAGE_CODES: Set<string> = new Set<string>([
  'af', 'ar', 'az', 'bg', 'bn', 'bs', 'ca', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'eu', 'fa', 'fi', 'fr', 'gl',
  'gu', 'he', 'hi', 'hr', 'hu', 'id', 'is', 'it', 'ja', 'kn', 'ko', 'lt', 'lv', 'ml', 'mr', 'ms', 'nb', 'nl', 'pl',
  'pt', 'ro', 'ru', 'sk', 'sl', 'sr', 'sv', 'ta', 'te', 'th', 'tr', 'uk', 'ur', 'vi'
]);

/** TranslationLanguageOption.normalizedBergamotCode */
export function normalizedBergamotCode(code: string): string {
  const base = substringBefore(code.toLowerCase(), '-');
  return (base === 'nb' || base === 'nn') ? 'nb' : base;
}

export function isBergamotTargetLanguage(code: string): boolean {
  return BERGAMOT_TARGET_LANGUAGE_CODES.has(normalizedBergamotCode(code));
}

/** TR-A43：provider 为 Local offline 且开关开启时仅保留 Bergamot 支持的目标语言 */
export function filterTranslationLanguageCodes(codes: string[], isLocalProvider: boolean,
  showOnlyBergamotLanguages: boolean): string[] {
  if (!(isLocalProvider && showOnlyBergamotLanguages)) {
    return codes;
  }
  return codes.filter((c: string) => isBergamotTargetLanguage(c));
}

// ------------------------------------------------------------------ 单测向量（TranslationLanguageUtilsKtTest）

export class LanguageMatchVector {
  name: string;
  detected: string;
  target: string;
  baseUrl: string;
  expected: boolean;

  constructor(name: string, detected: string, target: string, baseUrl: string, expected: boolean) {
    this.name = name;
    this.detected = detected;
    this.target = target;
    this.baseUrl = baseUrl;
    this.expected = expected;
  }
}

export const TRANSLATION_LANGUAGE_MATCH_VECTORS: LanguageMatchVector[] = [
  new LanguageMatchVector('deepLAllowsGenericEnglishToMatchRegionalVariant', 'en-GB', 'English', 'https://api.deepl.com', true),
  new LanguageMatchVector('deepLRequiresExactRegionalMatchWhenTargetIsRegional', 'en-GB', 'EN_US', 'https://api.deepl.com', false),
  new LanguageMatchVector('norwegianBokmalMatchesGenericNorwegianTarget', 'nb-NO', 'Norwegian', 'https://api.deepl.com', true),
  new LanguageMatchVector('targetEnMatchesEnGb', 'en-GB', 'EN', 'https://api.deepl.com', true),
  new LanguageMatchVector('targetEnGbDoesNotMatchEnUs', 'en-US', 'EN_GB', 'https://api.deepl.com', false)
];

export class PrepareTextVector {
  name: string;
  content: string;
  preserveHtml: boolean;
  expected: string;

  constructor(name: string, content: string, preserveHtml: boolean, expected: string) {
    this.name = name;
    this.content = content;
    this.preserveHtml = preserveHtml;
    this.expected = expected;
  }
}

export const PREPARE_TEXT_VECTORS: PrepareTextVector[] = [
  new PrepareTextVector('prepareTextForLanguageDetectionStripsHtmlAndCollapsesWhitespace',
    'Headline\n<div>Hello <b>world</b></div>', true, 'Headline Hello world')
];

/** prepareTextSamplesForLanguageDetectionSamplesLongTextAcrossContent 的输入：A×4500 + B×4500 + C×4500 → 3 样本 */
export function longSampleVectorContent(): string {
  return 'A'.repeat(4500) + 'B'.repeat(4500) + 'C'.repeat(4500);
}
