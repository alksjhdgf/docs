/*
 * TranslationManager — 翻译管理器：provider 分派、译文缓存、"已是目标语言"判定。
 * 源：model/TranslationManager.kt（全量语义）。
 *   - 仅当翻译设置 canUseAsTranslationApi 时使用之，否则视为空设置（AI-A56/TR-A01）；Local → LocalTranslator，其余 → translateViaApi（TR-A02）。
 *   - 首选语言 trim 后为空不发起（TR-A03）。
 *   - 缓存 `<cacheDir>/translations/<itemId>.<local|deepl|openai>.<lang>.json`，原文 SHA-256 校验（TR-A04~A08、A13）。
 *   - 检测已是目标语言（≥95%，样本全部匹配）不调用引擎并记录源语言（TR-A09）。
 */
import { OpenAISettings, TranslationApiSettings } from '../../core/settings/SettingsModels';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { FeedListItem } from '../../core/model/FeedItem';
import { joinPath, readTextOrNull, sha256OfString, writeText } from './TranslationIo';
import {
  canTranslate, canUseAsTranslationApi, detectedLanguageMatchesTranslationTarget, hasEnoughTextForLanguageDetection,
  isLocalTranslation, prepareTextSamplesForLanguageDetection, translationProviderKey
} from './LanguageUtils';
import { detectLocaleFromText, DetectedLocale } from './LanguageDetector';
import { TranslationErrorAction, TranslationResult, translateViaApi } from './DeepLApi';
import { LocalTranslator } from './LocalTranslator';
import { CachedTranslations, isUsableCachedTranslation } from './TranslationCache';

export { CachedTranslations } from './TranslationCache';

const ALREADY_TARGET_MIN_CONFIDENCE: number = 95;

/** 源 data class ArticleTranslation */
export class ArticleTranslation {
  translatedTitle: string;
  translatedHtml: string;
  sourceLanguage: string;

  constructor(translatedTitle: string, translatedHtml: string, sourceLanguage: string) {
    this.translatedTitle = translatedTitle;
    this.translatedHtml = translatedHtml;
    this.sourceLanguage = sourceLanguage;
  }
}

/** 源 data class CachedFeedListItemTranslation */
export class CachedFeedListItemTranslation {
  item: FeedListItem;
  hasCachedTranslation: boolean;
  isFullyCached: boolean;

  constructor(item: FeedListItem, hasCachedTranslation: boolean, isFullyCached: boolean) {
    this.item = item;
    this.hasCachedTranslation = hasCachedTranslation;
    this.isFullyCached = isFullyCached;
  }
}

export class SystemTranslationSettingsRequiredException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SystemTranslationSettingsRequiredException';
  }
}

export class BergamotRuntimeDownloadRequiredException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BergamotRuntimeDownloadRequiredException';
  }
}

export class TranslationFailedException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IllegalStateException';
  }
}

/** item.copy(title, snippet) */
export function copyFeedListItem(item: FeedListItem, title: string, snippet: string): FeedListItem {
  return new FeedListItem(item.id, title, snippet, item.feedTitle, item.unread, item.pubDate, item.image, item.link,
    item.bookmarked, item.feedImageUrl, item.primarySortTime, item.rawPubDate, item.wordCount);
}

function ifBlank(s: string, fallback: string): string {
  return s.trim().length === 0 ? fallback : s;
}

function isBlank(s: string): boolean {
  return s.trim().length === 0;
}

export class TranslationManager {
  private static inst: TranslationManager | null = null;

  private readonly cacheDirOverride: string | null;
  private readonly localTranslator: LocalTranslator | null;

  constructor(cacheDir: string | null = null, localTranslator: LocalTranslator | null = null) {
    this.cacheDirOverride = cacheDir;
    this.localTranslator = localTranslator;
  }

  static instance(): TranslationManager {
    if (TranslationManager.inst === null) {
      TranslationManager.inst = new TranslationManager();
    }
    return TranslationManager.inst as TranslationManager;
  }

  private local(): LocalTranslator {
    return this.localTranslator !== null ? this.localTranslator : LocalTranslator.instance();
  }

  /** AI-A56：可用作翻译 API 才使用，否则空设置 */
  translationSettings(): TranslationApiSettings {
    const s = SettingsStore.instance().translationApiSettings;
    return canUseAsTranslationApi(s) ? s : new OpenAISettings();
  }

  preferredTranslationLanguage(): string {
    return SettingsStore.instance().preferredTranslationLanguage;
  }

  // ---------------------------------------------------------------- 列表卡片

  async getCachedTranslatedFeedListItem(item: FeedListItem, settings: TranslationApiSettings,
    targetLanguage: string): Promise<CachedFeedListItemTranslation> {
    if (!canTranslate(settings) || isBlank(targetLanguage)) {
      return new CachedFeedListItemTranslation(item, false, false);
    }
    const cache = this.loadCache(item.id, settings, targetLanguage);
    const titleHash = sha256OfString(item.title);
    const snippetHash = sha256OfString(item.snippet);
    const hasCachedTitle = !isBlank(item.title) && cache.titleHash === titleHash &&
      isUsableCachedTranslation(cache.translatedTitle, item.title, cache.sourceLanguage, targetLanguage, settings);
    const hasCachedSnippet = !isBlank(item.snippet) && cache.snippetHash === snippetHash &&
      isUsableCachedTranslation(cache.translatedSnippet, item.snippet, cache.sourceLanguage, targetLanguage, settings);
    const titleReady = isBlank(item.title) || hasCachedTitle;
    const snippetReady = isBlank(item.snippet) || hasCachedSnippet;
    return new CachedFeedListItemTranslation(
      copyFeedListItem(item,
        hasCachedTitle ? cache.translatedTitle as string : item.title,
        hasCachedSnippet ? cache.translatedSnippet as string : item.snippet),
      hasCachedTitle || hasCachedSnippet,
      titleReady && snippetReady);
  }

  /** 使用当前设置翻译卡片 */
  async translateFeedListItemWithCurrentSettings(item: FeedListItem): Promise<FeedListItem> {
    return this.translateFeedListItem(item, this.translationSettings(), this.preferredTranslationLanguage());
  }

  /** TR-A08：卡片翻译（标题/摘要独立成功与缓存） */
  async translateFeedListItem(item: FeedListItem, settings: TranslationApiSettings,
    targetLanguageRaw: string): Promise<FeedListItem> {
    const targetLanguage = targetLanguageRaw.trim();
    if (!canTranslate(settings) || targetLanguage.length === 0) {
      return item;
    }
    const cache = this.loadCache(item.id, settings, targetLanguage);
    const titleHash = sha256OfString(item.title);
    const snippetHash = sha256OfString(item.snippet);
    const cachedTitle: string | null = (cache.titleHash === titleHash &&
      isUsableCachedTranslation(cache.translatedTitle, item.title, cache.sourceLanguage, targetLanguage, settings)) ?
      cache.translatedTitle : null;
    const cachedSnippet: string | null = (cache.snippetHash === snippetHash &&
      isUsableCachedTranslation(cache.translatedSnippet, item.snippet, cache.sourceLanguage, targetLanguage, settings)) ?
      cache.translatedSnippet : null;

    const titleReady = isBlank(item.title) || cachedTitle !== null;
    const snippetReady = isBlank(item.snippet) || cachedSnippet !== null;
    if (titleReady && snippetReady) {
      return copyFeedListItem(item, cachedTitle !== null ? cachedTitle : item.title,
        cachedSnippet !== null ? cachedSnippet : item.snippet);
    }
    const cachedSourceLanguage = (cachedTitle !== null || cachedSnippet !== null) ? cache.sourceLanguage : '';

    const joined = [item.title, item.snippet].filter((s: string) => !isBlank(s)).join('\n\n');
    const detectedSameLanguage = this.detectSourceLanguageIfAlreadyTargetLanguage(joined, targetLanguage, settings, false);
    if (detectedSameLanguage !== null) {
      const updated = cache.copy();
      updated.sourceLanguage = detectedSameLanguage;
      updated.titleHash = isBlank(item.title) ? null : titleHash;
      updated.translatedTitle = isBlank(item.title) ? null : item.title;
      updated.snippetHash = isBlank(item.snippet) ? null : snippetHash;
      updated.translatedSnippet = isBlank(item.snippet) ? null : item.snippet;
      if (!updated.equals(cache)) {
        this.saveCache(item.id, settings, targetLanguage, updated);
      }
      return item;
    }

    const snippetResult: TranslationResult | null = (isBlank(item.snippet) || cachedSnippet !== null) ? null :
      await this.translateOrNull(item.snippet, targetLanguage, settings, cachedSourceLanguage, false);
    const translatedSnippet = cachedSnippet !== null ? cachedSnippet : (snippetResult !== null ? snippetResult.content : '');
    const sourceLanguageHint = ifBlank(snippetResult !== null ? snippetResult.detectedLanguage : '', cachedSourceLanguage);

    const titleResult: TranslationResult | null = (isBlank(item.title) || cachedTitle !== null) ? null :
      await this.translateOrNull(item.title, targetLanguage, settings, sourceLanguageHint, false);
    const translatedTitle = cachedTitle !== null ? cachedTitle : (titleResult !== null ? titleResult.content : '');
    const sourceLanguage = ifBlank(ifBlank(snippetResult !== null ? snippetResult.detectedLanguage : '',
      titleResult !== null ? titleResult.detectedLanguage : ''), cachedSourceLanguage);

    const updated = cache.copy();
    updated.sourceLanguage = ifBlank(sourceLanguage, cachedSourceLanguage);
    if (isBlank(item.title)) {
      updated.titleHash = null;
      updated.translatedTitle = null;
    } else if (!isBlank(translatedTitle)) {
      updated.titleHash = titleHash;
      updated.translatedTitle = translatedTitle;
    }
    if (isBlank(item.snippet)) {
      updated.snippetHash = null;
      updated.translatedSnippet = null;
    } else if (!isBlank(translatedSnippet)) {
      updated.snippetHash = snippetHash;
      updated.translatedSnippet = translatedSnippet;
    }
    if (!updated.equals(cache)) {
      this.saveCache(item.id, settings, targetLanguage, updated);
    }
    return copyFeedListItem(item, ifBlank(translatedTitle, item.title), ifBlank(translatedSnippet, item.snippet));
  }

  // ---------------------------------------------------------------- 文章

  /**
   * TR-A05/A06/A09：文章翻译。设置不可用/目标为空/HTML 为空 → null；
   * 引擎失败抛 SystemTranslationSettingsRequiredException / BergamotRuntimeDownloadRequiredException / TranslationFailedException。
   */
  async getOrTranslateArticle(itemId: number, title: string, html: string,
    isFullText: boolean): Promise<ArticleTranslation | null> {
    const settings = this.translationSettings();
    const targetLanguage = this.preferredTranslationLanguage().trim();
    if (!canTranslate(settings) || targetLanguage.length === 0 || isBlank(html)) {
      return null;
    }
    const cache = this.loadCache(itemId, settings, targetLanguage);
    const titleHash = sha256OfString(title);
    const htmlHash = sha256OfString(html);
    const cachedHtml: string | null = isFullText ?
      (cache.fullArticleHtmlHash === htmlHash ? cache.translatedFullArticleHtml : null) :
      (cache.articleHtmlHash === htmlHash ? cache.translatedArticleHtml : null);
    const cachedTitle: string | null = (cache.titleHash === titleHash &&
      isUsableCachedTranslation(cache.translatedTitle, title, cache.sourceLanguage, targetLanguage, settings)) ?
      cache.translatedTitle : null;

    if (cachedHtml !== null && cachedTitle !== null) {
      return new ArticleTranslation(cachedTitle, cachedHtml, cache.sourceLanguage);
    }

    const detectedSameLanguage = this.detectArticleAlreadyInTargetLanguageWith(itemId, title, html, isFullText, settings,
      targetLanguage, cache);
    if (detectedSameLanguage !== null) {
      return new ArticleTranslation(title, html, detectedSameLanguage);
    }
    const cachedSourceLanguage = cache.sourceLanguage;

    const htmlResult: TranslationResult | null = cachedHtml !== null ? null :
      await this.translateOrThrow(html, targetLanguage, settings, cachedSourceLanguage, true);
    const sourceLanguageHint = ifBlank(htmlResult !== null ? htmlResult.detectedLanguage : '', cachedSourceLanguage);
    const titleResult: TranslationResult | null = cachedTitle !== null ? null :
      await this.translateOrThrow(title, targetLanguage, settings, sourceLanguageHint, false);

    const translatedTitle = cachedTitle !== null ? cachedTitle : ifBlank(titleResult !== null ? titleResult.content : '', title);
    const translatedHtml = cachedHtml !== null ? cachedHtml : ifBlank(htmlResult !== null ? htmlResult.content : '', html);
    const sourceLanguage = ifBlank(ifBlank(htmlResult !== null ? htmlResult.detectedLanguage : '',
      titleResult !== null ? titleResult.detectedLanguage : ''), cachedSourceLanguage);

    const updated = cache.copy();
    updated.sourceLanguage = ifBlank(sourceLanguage, cachedSourceLanguage);
    updated.titleHash = titleHash;
    updated.translatedTitle = translatedTitle;
    if (isFullText) {
      updated.fullArticleHtmlHash = htmlHash;
      updated.translatedFullArticleHtml = translatedHtml;
    } else {
      updated.articleHtmlHash = htmlHash;
      updated.translatedArticleHtml = translatedHtml;
    }
    this.saveCache(itemId, settings, targetLanguage, updated);
    return new ArticleTranslation(translatedTitle, translatedHtml, sourceLanguage);
  }

  async hasCachedTranslatedArticle(itemId: number, title: string, html: string, isFullText: boolean,
    settings: TranslationApiSettings, targetLanguageRaw: string): Promise<boolean> {
    const targetLanguage = targetLanguageRaw.trim();
    if (!canTranslate(settings) || targetLanguage.length === 0 || isBlank(html)) {
      return false;
    }
    const cache = this.loadCache(itemId, settings, targetLanguage);
    const titleHash = sha256OfString(title);
    const htmlHash = sha256OfString(html);
    const cachedHtml: string | null = isFullText ?
      (cache.fullArticleHtmlHash === htmlHash ? cache.translatedFullArticleHtml : null) :
      (cache.articleHtmlHash === htmlHash ? cache.translatedArticleHtml : null);
    const titleOk = cache.titleHash === titleHash &&
      isUsableCachedTranslation(cache.translatedTitle, title, cache.sourceLanguage, targetLanguage, settings);
    return cachedHtml !== null && cache.translatedTitle !== null && titleOk;
  }

  /** 当前设置下判定文章是否已是目标语言（返回源语言或 null） */
  async detectArticleAlreadyInTargetLanguage(itemId: number, title: string, html: string,
    isFullText: boolean): Promise<string | null> {
    const settings = this.translationSettings();
    const targetLanguage = this.preferredTranslationLanguage().trim();
    return this.detectArticleAlreadyInTargetLanguageWith(itemId, title, html, isFullText, settings, targetLanguage, null);
  }

  // ---------------------------------------------------------------- 缓存

  private cacheDir(): string {
    if (this.cacheDirOverride !== null) {
      return this.cacheDirOverride;
    }
    const paths = AppBootstrap.filePaths();
    return paths !== null ? paths.cacheDir : '';
  }

  /** TR-A04：`<cacheDir>/translations/<itemId>.<provider>.<lang>.json` */
  cacheFilePath(itemId: number, settings: OpenAISettings, targetLanguage: string): string {
    const provider = translationProviderKey(settings);
    const lang = targetLanguage.trim().toLowerCase().replace(new RegExp('[^a-z0-9._-]+', 'g'), '_');
    const langPart = lang.trim().length === 0 ? 'default' : lang;
    return joinPath(joinPath(this.cacheDir(), 'translations'), `${itemId}.${provider}.${langPart}.json`);
  }

  /** TR-A07：不存在/损坏 → 空缓存 */
  private loadCache(itemId: number, settings: OpenAISettings, targetLanguage: string): CachedTranslations {
    const text = readTextOrNull(this.cacheFilePath(itemId, settings, targetLanguage));
    if (text === null) {
      return new CachedTranslations();
    }
    const parsed = CachedTranslations.fromJson(text);
    return parsed !== null ? parsed : new CachedTranslations();
  }

  private saveCache(itemId: number, settings: OpenAISettings, targetLanguage: string, cache: CachedTranslations): void {
    try {
      writeText(this.cacheFilePath(itemId, settings, targetLanguage), cache.toJson());
    } catch (e) {
      console.warn(`TranslationManager: save cache failed: ${(e as Error)?.message}`);
    }
  }

  // ---------------------------------------------------------------- 分派

  private async translate(content: string, targetLanguage: string, settings: OpenAISettings, sourceLangHint: string,
    preserveHtml: boolean): Promise<TranslationResult> {
    if (isLocalTranslation(settings)) {
      return this.local().translate(content, targetLanguage, sourceLangHint, preserveHtml);
    }
    return translateViaApi(content, targetLanguage, settings, preserveHtml);
  }

  private async translateOrNull(content: string, targetLanguage: string, settings: OpenAISettings,
    sourceLangHint: string, preserveHtml: boolean): Promise<TranslationResult | null> {
    try {
      const result = await this.translate(content, targetLanguage, settings, sourceLangHint, preserveHtml);
      return result.isSuccess && !isBlank(result.content) ? result : null;
    } catch (e) {
      console.warn(`TranslationManager: translate failed: ${(e as Error)?.message}`);
      return null;
    }
  }

  private async translateOrThrow(content: string, targetLanguage: string, settings: OpenAISettings,
    sourceLangHint: string, preserveHtml: boolean): Promise<TranslationResult> {
    const result = await this.translate(content, targetLanguage, settings, sourceLangHint, preserveHtml);
    if (result.isSuccess) {
      if (isBlank(result.content)) {
        throw new TranslationFailedException('Translation failed');
      }
      return result;
    }
    const message = ifBlank(result.content, 'Translation failed');
    if (result.action === TranslationErrorAction.DownloadBergamotRuntime) {
      throw new BergamotRuntimeDownloadRequiredException(message);
    }
    if (result.action === TranslationErrorAction.OpenSystemTranslationSettings) {
      throw new SystemTranslationSettingsRequiredException(message);
    }
    throw new TranslationFailedException(message);
  }

  // ---------------------------------------------------------------- 语言检测

  /** TR-A09/A10：全部样本 ≥95% 且匹配目标 → 返回首个检测语言；否则 null */
  detectSourceLanguageIfAlreadyTargetLanguage(content: string, targetLanguage: string, settings: OpenAISettings,
    preserveHtml: boolean): string | null {
    try {
      const samples = prepareTextSamplesForLanguageDetection(content, preserveHtml)
        .filter((s: string) => hasEnoughTextForLanguageDetection(s));
      if (samples.length === 0) {
        return null;
      }
      let first: string | null = null;
      for (let i = 0; i < samples.length; i++) {
        const found: DetectedLocale[] = detectLocaleFromText(samples[i], ALREADY_TARGET_MIN_CONFIDENCE);
        if (found.length === 0) {
          return null;
        }
        const detected = found[0].languageTag;
        if (!detectedLanguageMatchesTranslationTarget(detected, targetLanguage, settings)) {
          return null;
        }
        if (first === null) {
          first = detected;
        }
      }
      return first;
    } catch (e) {
      return null;
    }
  }

  private detectArticleAlreadyInTargetLanguageWith(itemId: number, title: string, html: string, isFullText: boolean,
    settings: OpenAISettings, targetLanguage: string, existingCache: CachedTranslations | null): string | null {
    if (!canTranslate(settings) || isBlank(targetLanguage) || isBlank(html)) {
      return null;
    }
    const cache = existingCache !== null ? existingCache : this.loadCache(itemId, settings, targetLanguage);
    const titleHash = sha256OfString(title);
    const htmlHash = sha256OfString(html);
    const currentHtmlHash = isFullText ? cache.fullArticleHtmlHash : cache.articleHtmlHash;
    const cachedSameLanguage = cache.titleHash === titleHash && currentHtmlHash === htmlHash &&
      !isBlank(cache.sourceLanguage) &&
      detectedLanguageMatchesTranslationTarget(cache.sourceLanguage, targetLanguage, settings);
    if (cachedSameLanguage) {
      return cache.sourceLanguage;
    }
    let content = '';
    if (!isBlank(title)) {
      content += title;
    }
    if (!isBlank(html)) {
      if (content.length > 0) {
        content += '\n\n';
      }
      content += html;
    }
    const detected = this.detectSourceLanguageIfAlreadyTargetLanguage(content, targetLanguage, settings, true);
    if (detected === null) {
      return null;
    }
    const updated = cache.copy();
    updated.sourceLanguage = detected;
    updated.titleHash = isBlank(title) ? null : titleHash;
    updated.translatedTitle = isBlank(title) ? null : title;
    if (isFullText) {
      updated.fullArticleHtmlHash = htmlHash;
      updated.translatedFullArticleHtml = html;
    } else {
      updated.articleHtmlHash = htmlHash;
      updated.translatedArticleHtml = html;
    }
    this.saveCache(itemId, settings, targetLanguage, updated);
    return detected;
  }
}
