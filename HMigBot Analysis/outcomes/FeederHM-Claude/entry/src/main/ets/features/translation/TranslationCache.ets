/*
 * TranslationCache — 译文缓存条目（源 TranslationManager.kt private @Serializable data class CachedTranslations）
 * 与 isUsableCachedTranslation（TR-A13）。
 * JSON 照 kotlinx Json{ prettyPrint=false }（encodeDefaults=false：默认值字段不写出）；解析容错（ignoreUnknownKeys，类型不符视为损坏 → null）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { detectedLanguageMatchesTranslationTarget } from './LanguageUtils';

class CacheParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CacheParseError';
  }
}

function optString(o: Record<string, Object>, key: string): string | null {
  const v = o[key];
  if (v === undefined || v === null) {
    return null;
  }
  if (typeof v !== 'string') {
    throw new CacheParseError(key);
  }
  return v as string;
}

export class CachedTranslations {
  sourceLanguage: string = '';
  titleHash: string | null = null;
  translatedTitle: string | null = null;
  snippetHash: string | null = null;
  translatedSnippet: string | null = null;
  articleHtmlHash: string | null = null;
  translatedArticleHtml: string | null = null;
  fullArticleHtmlHash: string | null = null;
  translatedFullArticleHtml: string | null = null;

  copy(): CachedTranslations {
    const c = new CachedTranslations();
    c.sourceLanguage = this.sourceLanguage;
    c.titleHash = this.titleHash;
    c.translatedTitle = this.translatedTitle;
    c.snippetHash = this.snippetHash;
    c.translatedSnippet = this.translatedSnippet;
    c.articleHtmlHash = this.articleHtmlHash;
    c.translatedArticleHtml = this.translatedArticleHtml;
    c.fullArticleHtmlHash = this.fullArticleHtmlHash;
    c.translatedFullArticleHtml = this.translatedFullArticleHtml;
    return c;
  }

  equals(o: CachedTranslations): boolean {
    return this.sourceLanguage === o.sourceLanguage && this.titleHash === o.titleHash &&
      this.translatedTitle === o.translatedTitle && this.snippetHash === o.snippetHash &&
      this.translatedSnippet === o.translatedSnippet && this.articleHtmlHash === o.articleHtmlHash &&
      this.translatedArticleHtml === o.translatedArticleHtml && this.fullArticleHtmlHash === o.fullArticleHtmlHash &&
      this.translatedFullArticleHtml === o.translatedFullArticleHtml;
  }

  toJson(): string {
    const o: Record<string, Object> = {};
    if (this.sourceLanguage !== '') {
      o['sourceLanguage'] = this.sourceLanguage;
    }
    if (this.titleHash !== null) {
      o['titleHash'] = this.titleHash;
    }
    if (this.translatedTitle !== null) {
      o['translatedTitle'] = this.translatedTitle;
    }
    if (this.snippetHash !== null) {
      o['snippetHash'] = this.snippetHash;
    }
    if (this.translatedSnippet !== null) {
      o['translatedSnippet'] = this.translatedSnippet;
    }
    if (this.articleHtmlHash !== null) {
      o['articleHtmlHash'] = this.articleHtmlHash;
    }
    if (this.translatedArticleHtml !== null) {
      o['translatedArticleHtml'] = this.translatedArticleHtml;
    }
    if (this.fullArticleHtmlHash !== null) {
      o['fullArticleHtmlHash'] = this.fullArticleHtmlHash;
    }
    if (this.translatedFullArticleHtml !== null) {
      o['translatedFullArticleHtml'] = this.translatedFullArticleHtml;
    }
    return JSON.stringify(o);
  }

  /** 解析失败 → null（TR-A07） */
  static fromJson(text: string): CachedTranslations | null {
    try {
      const parsed = JSON.parse(text) as Object;
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return null;
      }
      const o = parsed as Record<string, Object>;
      const c = new CachedTranslations();
      const src = optString(o, 'sourceLanguage');
      c.sourceLanguage = src !== null ? src : '';
      c.titleHash = optString(o, 'titleHash');
      c.translatedTitle = optString(o, 'translatedTitle');
      c.snippetHash = optString(o, 'snippetHash');
      c.translatedSnippet = optString(o, 'translatedSnippet');
      c.articleHtmlHash = optString(o, 'articleHtmlHash');
      c.translatedArticleHtml = optString(o, 'translatedArticleHtml');
      c.fullArticleHtmlHash = optString(o, 'fullArticleHtmlHash');
      c.translatedFullArticleHtml = optString(o, 'translatedFullArticleHtml');
      return c;
    } catch (e) {
      return null;
    }
  }
}

/** TR-A13：非空；与原文不同即可用；等于原文时仅当源语言为空或匹配目标 */
export function isUsableCachedTranslation(value: string | null, original: string, sourceLanguage: string,
  targetLanguage: string, settings: OpenAISettings): boolean {
  if (value === null || value.trim().length === 0) {
    return false;
  }
  if (value !== original) {
    return true;
  }
  return sourceLanguage.trim().length === 0 ||
    detectedLanguageMatchesTranslationTarget(sourceLanguage, targetLanguage, settings);
}
