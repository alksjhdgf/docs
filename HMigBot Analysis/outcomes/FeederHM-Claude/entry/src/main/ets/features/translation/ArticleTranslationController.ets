/*
 * ArticleTranslationController — 文章页翻译交互契约（源 ArticleViewModel.kt 翻译部分 + ArticleScreen.kt 菜单/对话框/进度）。
 *   TR-A33 菜单可见性与文案；TR-A34 标题+正文同时替换、切换全文/摘要时重新翻译；
 *   TR-A35 未设语言提示/失败 Toast 并恢复原文；TR-A36 运行时下载确认；TR-A37 打开系统设置；
 *   TR-A38 进度（下载进度卡 / 无限进度条）；TR-A39 默认翻译文章（本地模式仅缓存或无需下载时）。
 * 文章页（ArticlePage 单元）持有一个实例：attach(subject) / setFullText / onSettingsChanged；
 * 读 @Trace 字段与 showTranslate()/isShowingTranslated()/menuLabel() 渲染；HTML 加载由宿主注入（源 loadArticleHtml）。
 */
import { SettingsStore } from '../../core/settings/SettingsStore';
import { TranslationDownloadProgress } from '../../ui/common/CommonWidgets';
import { canUseAsTranslationApi, isLocalTranslation } from './LanguageUtils';
import {
  BergamotRuntimeDownloadRequiredException, SystemTranslationSettingsRequiredException, TranslationManager
} from './TranslationManager';
import { LocalTranslator } from './LocalTranslator';
import { BergamotModelManager } from './BergamotModels';
import { BergamotModelDownloadProgress } from './BergamotRegistry';
import { TranslationStrings } from './TranslationStrings';
import {
  confirmOpenSystemSettings, confirmRuntimeDownload, openSystemSettings, showTranslationToast, toUiDownloadProgress,
  translationString, TranslationToast
} from './TranslationUiSupport';

/** 源 sealed ArticleTranslationState */
export enum ArticleTranslationPhase {
  Empty = 'Empty',
  Loading = 'Loading',
  Result = 'Result',
  AlreadyInPreferredLanguage = 'AlreadyInPreferredLanguage',
  SystemSettingsRequired = 'SystemSettingsRequired',
  RuntimeDownloadRequired = 'RuntimeDownloadRequired'
}

/** 当前文章（源 Article 的翻译相关字段） */
export class ArticleTranslationSubject {
  itemId: number = 0;
  title: string = '';
  link: string | null = null;
  fullTextByDefault: boolean = false;
}

/** 源 loadArticleHtml(article, fullText)：失败抛错 */
export type ArticleHtmlLoader = (subject: ArticleTranslationSubject, fullText: boolean) => Promise<string>;
/** 源 loadArticleHtmlForLanguageDetection：不触发下载，无则 null */
export type ArticleHtmlPeek = (subject: ArticleTranslationSubject, fullText: boolean) => Promise<string | null>;

@ObservedV2
export class ArticleTranslationController {
  @Trace showTranslatedContent: boolean = false;
  @Trace phase: ArticleTranslationPhase = ArticleTranslationPhase.Empty;
  @Trace phaseIsFullText: boolean = false;
  @Trace translatedTitle: string = '';
  /** 译文 HTML（宿主按源 HtmlLinearizer 线性化后替换正文） */
  @Trace translatedHtml: string = '';
  @Trace sourceLanguage: string = '';
  @Trace systemSettingsMessage: string = '';
  @Trace downloadProgress: TranslationDownloadProgress | null = null;
  @Trace isFullText: boolean = false;
  /** true：需要时由控制器直接弹出 TR-A36/A37 对话框；宿主自绘对话框时置 false 并读 showRuntimeDownloadPrompt()/phase */
  autoPromptDialogs: boolean = true;

  private subject: ArticleTranslationSubject | null = null;
  private readonly loadHtml: ArticleHtmlLoader;
  private readonly peekHtml: ArticleHtmlPeek;
  private readonly toast: TranslationToast;
  private unsubscribeProgress: (() => void) | null = null;
  private unsubscribeSettings: (() => void) | null = null;
  private generation: number = 0;
  private handledInitialOpenActions: boolean = false;
  private lastSettingsKey: string = '';

  constructor(loadHtml: ArticleHtmlLoader, peekHtml: ArticleHtmlPeek, toast: TranslationToast | null = null) {
    this.loadHtml = loadHtml;
    this.peekHtml = peekHtml;
    this.toast = toast !== null ? toast : (m: string) => {
      showTranslationToast(m);
    };
  }

  /** 页面 aboutToAppear：订阅下载进度与设置（返回前须 detach） */
  start(): void {
    if (this.unsubscribeProgress === null) {
      const bus = BergamotModelManager.instance().progress;
      this.downloadProgress = toUiDownloadProgress(bus.value);
      this.unsubscribeProgress = bus.subscribe((p: BergamotModelDownloadProgress | null) => {
        this.downloadProgress = toUiDownloadProgress(p);
      });
    }
    if (this.unsubscribeSettings === null) {
      this.lastSettingsKey = this.settingsKey();
      this.unsubscribeSettings = SettingsStore.instance().observe((_k: string) => {
        const key = this.settingsKey();
        if (key !== this.lastSettingsKey) {
          this.lastSettingsKey = key;
          this.runLanguageCheck();
        }
      });
    }
  }

  /** 页面 aboutToDisappear */
  stop(): void {
    if (this.unsubscribeProgress !== null) {
      this.unsubscribeProgress();
      this.unsubscribeProgress = null;
    }
    if (this.unsubscribeSettings !== null) {
      this.unsubscribeSettings();
      this.unsubscribeSettings = null;
    }
  }

  private settingsKey(): string {
    const s = SettingsStore.instance().translationApiSettings;
    return `${s.baseUrl}\u0000${s.key}\u0000${s.modelId}\u0000${SettingsStore.instance().preferredTranslationLanguage}`;
  }

  /** 文章切换/首次加载；isFullText 为当前显示模式 */
  attach(subject: ArticleTranslationSubject, isFullText: boolean): void {
    const changed = this.subject === null || this.subject.itemId !== subject.itemId;
    this.subject = subject;
    this.isFullText = isFullText;
    if (changed) {
      this.generation++;
      this.handledInitialOpenActions = false;
      this.clearTranslatedContent();
    }
    this.runLanguageCheck();
  }

  // ---------------------------------------------------------------- 派生视图状态（ArticleViewModel.kt:186-238）

  private canRequestTranslation(): boolean {
    const s = this.subject;
    return canUseAsTranslationApi(SettingsStore.instance().translationApiSettings) &&
      SettingsStore.instance().preferredTranslationLanguage.trim().length > 0 &&
      s !== null && s.link !== null && s.link.length > 0;
  }

  isShowingTranslated(): boolean {
    return this.showTranslatedContent && this.phase === ArticleTranslationPhase.Result &&
      this.phaseIsFullText === this.isFullText;
  }

  private alreadyInPreferredLanguage(): boolean {
    return this.phase === ArticleTranslationPhase.AlreadyInPreferredLanguage && this.phaseIsFullText === this.isFullText;
  }

  /** TR-A33：菜单项可见 */
  showTranslate(): boolean {
    return this.isShowingTranslated() || (this.canRequestTranslation() && !this.alreadyInPreferredLanguage());
  }

  isTranslationLoading(): boolean {
    return this.phase === ArticleTranslationPhase.Loading;
  }

  showRuntimeDownloadPrompt(): boolean {
    return this.phase === ArticleTranslationPhase.RuntimeDownloadRequired;
  }

  translationSourceLanguage(): string {
    if (this.isShowingTranslated()) {
      return this.sourceLanguage;
    }
    return this.alreadyInPreferredLanguage() ? this.sourceLanguage : '';
  }

  /** TR-A33：`Translate article` / `Show original (%1$s)`（源语言未知 → original） */
  menuLabel(): string {
    if (this.isShowingTranslated()) {
      const src = this.translationSourceLanguage().trim().length > 0 ? this.translationSourceLanguage() :
        translationString('original_article', 'original');
      return translationString('show_original_language', 'Show original (%1$s)', [src]);
    }
    return translationString('translate_article', 'Translate article');
  }

  /** TR-A34：显示标题 */
  displayTitle(originalTitle: string): string {
    return this.isShowingTranslated() ? this.translatedTitle : originalTitle;
  }

  // ---------------------------------------------------------------- 动作

  /** 菜单点击：显示译文时切回原文（不重新请求），否则翻译 */
  translate(): void {
    if (this.showTranslatedContent) {
      this.showTranslatedContent = false;
      return;
    }
    this.showTranslatedContent = true;
    this.translateCurrentArticle();
  }

  /** 源 toggleFullText 后：正在显示译文则对新模式重新翻译 */
  setFullText(isFullText: boolean): void {
    if (this.isFullText === isFullText) {
      return;
    }
    this.isFullText = isFullText;
    this.runLanguageCheck();
    if (this.showTranslatedContent) {
      this.translateCurrentArticle();
    }
  }

  /** TR-A39：文章首次打开时的默认翻译 */
  async autoTranslateOnOpen(): Promise<void> {
    const subject = this.subject;
    if (subject === null || this.handledInitialOpenActions) {
      return;
    }
    this.handledInitialOpenActions = true;
    if (SettingsStore.instance().translateArticlesByDefault && this.canTranslateArticles() &&
      await this.canStartAutomaticArticleTranslation(subject)) {
      this.showTranslatedContent = true;
      this.translateCurrentArticle();
    }
  }

  private canTranslateArticles(): boolean {
    return canUseAsTranslationApi(SettingsStore.instance().translationApiSettings) &&
      SettingsStore.instance().preferredTranslationLanguage.trim().length > 0;
  }

  private async canStartAutomaticArticleTranslation(subject: ArticleTranslationSubject): Promise<boolean> {
    const settings = SettingsStore.instance().translationApiSettings;
    if (!isLocalTranslation(settings)) {
      return true;
    }
    const targetLanguage = SettingsStore.instance().preferredTranslationLanguage.trim();
    if (targetLanguage.length === 0) {
      return false;
    }
    try {
      const fullText = subject.fullTextByDefault;
      const html = await this.loadHtml(subject, fullText);
      const hasCached = await TranslationManager.instance().hasCachedTranslatedArticle(subject.itemId, subject.title,
        html, fullText, settings, targetLanguage);
      if (hasCached) {
        return true;
      }
      return await LocalTranslator.instance().canTranslateWithoutBergamotDownload(html, targetLanguage, '', true);
    } catch (e) {
      return false;
    }
  }

  private translateCurrentArticle(): void {
    const gen = this.generation;
    this.doTranslate(gen).catch((e: Error) => {
      console.warn(`ArticleTranslationController: translate failed: ${e?.message}`);
    });
  }

  private async doTranslate(gen: number): Promise<void> {
    try {
      const targetLanguage = SettingsStore.instance().preferredTranslationLanguage.trim();
      if (targetLanguage.length === 0) {
        this.toast(TranslationStrings.get(TranslationStrings.SET_LANGUAGE_FIRST));
        this.clearTranslatedContent();
        return;
      }
      const subject = this.subject;
      if (subject === null) {
        return;
      }
      const fullText = this.isFullText;
      if (!canUseAsTranslationApi(SettingsStore.instance().translationApiSettings)) {
        this.clearTranslatedContent();
        return;
      }
      const html = await this.loadHtml(subject, fullText);
      if (gen !== this.generation) {
        return;
      }
      const detected = await TranslationManager.instance().detectArticleAlreadyInTargetLanguage(subject.itemId,
        subject.title, html, fullText);
      if (detected !== null) {
        this.setAlreadyInPreferredLanguage(detected, fullText);
        return;
      }
      this.phase = ArticleTranslationPhase.Loading;
      const translation = await TranslationManager.instance().getOrTranslateArticle(subject.itemId, subject.title, html,
        fullText);
      if (translation === null) {
        throw new Error('Translation failed');
      }
      if (gen !== this.generation) {
        return;
      }
      this.translatedTitle = translation.translatedTitle;
      this.translatedHtml = translation.translatedHtml;
      this.sourceLanguage = translation.sourceLanguage;
      this.phaseIsFullText = fullText;
      this.phase = ArticleTranslationPhase.Result;
    } catch (e) {
      if (gen !== this.generation) {
        return;
      }
      if (e instanceof SystemTranslationSettingsRequiredException) {
        this.showTranslatedContent = false;
        this.translatedHtml = '';
        const msg = (e as Error).message;
        this.systemSettingsMessage = msg.length > 0 ? msg : 'Translation model required';
        this.phase = ArticleTranslationPhase.SystemSettingsRequired;
        if (this.autoPromptDialogs) {
          this.promptSystemSettings();
        }
      } else if (e instanceof BergamotRuntimeDownloadRequiredException) {
        this.showTranslatedContent = false;
        this.translatedHtml = '';
        this.phase = ArticleTranslationPhase.RuntimeDownloadRequired;
        if (this.autoPromptDialogs) {
          this.promptRuntimeDownload();
        }
      } else {
        this.clearTranslatedContent();
        const msg = (e as Error)?.message;
        this.toast(msg !== undefined && msg.length > 0 ? msg : 'Translation failed');
      }
    }
  }

  private promptRuntimeDownload(): void {
    confirmRuntimeDownload().then((download: boolean) => {
      if (download) {
        this.downloadBergamotRuntimeAndTranslate();
      } else {
        this.dismissBergamotRuntimeDownloadPrompt();
      }
    });
  }

  private promptSystemSettings(): void {
    confirmOpenSystemSettings(this.systemSettingsMessage).then((open: boolean) => {
      if (open) {
        this.openSystemTranslationSettings();
      } else {
        this.dismissSystemTranslationSettingsPrompt();
      }
    });
  }

  /** TR-A36：Download → 下载运行时后继续翻译；失败提示 */
  downloadBergamotRuntimeAndTranslate(): void {
    this.phase = ArticleTranslationPhase.Loading;
    BergamotModelManager.instance().downloadRuntime().then((ok: boolean) => {
      if (ok) {
        this.showTranslatedContent = true;
        this.translateCurrentArticle();
      } else {
        this.clearTranslatedContent();
        this.toast(TranslationStrings.get(TranslationStrings.RUNTIME_DOWNLOAD_FAILED));
      }
    });
  }

  dismissBergamotRuntimeDownloadPrompt(): void {
    if (this.phase === ArticleTranslationPhase.RuntimeDownloadRequired) {
      this.phase = ArticleTranslationPhase.Empty;
    }
  }

  /** TR-A37：Open settings */
  openSystemTranslationSettings(): void {
    openSystemSettings().then(() => {
      this.dismissSystemTranslationSettingsPrompt();
    });
  }

  dismissSystemTranslationSettingsPrompt(): void {
    if (this.phase === ArticleTranslationPhase.SystemSettingsRequired) {
      this.phase = ArticleTranslationPhase.Empty;
    }
  }

  // ---------------------------------------------------------------- 已是目标语言检测（ArticleViewModel.kt:270-318）

  private runLanguageCheck(): void {
    const gen = this.generation;
    const subject = this.subject;
    if (subject === null) {
      return;
    }
    const fullText = this.isFullText;
    const settings = SettingsStore.instance().translationApiSettings;
    const target = SettingsStore.instance().preferredTranslationLanguage;
    if (!canUseAsTranslationApi(settings) || target.trim().length === 0 || subject.link === null ||
      subject.link.trim().length === 0) {
      this.clearAlreadyInPreferredLanguageState(null);
      return;
    }
    this.peekHtml(subject, fullText).then(async (html: string | null): Promise<void> => {
      if (gen !== this.generation || fullText !== this.isFullText) {
        return;
      }
      if (html === null) {
        this.clearAlreadyInPreferredLanguageState(fullText);
        return;
      }
      const src = await TranslationManager.instance().detectArticleAlreadyInTargetLanguage(subject.itemId, subject.title,
        html, fullText);
      if (gen !== this.generation) {
        return;
      }
      if (src !== null) {
        this.setAlreadyInPreferredLanguage(src, fullText);
      } else {
        this.clearAlreadyInPreferredLanguageState(fullText);
      }
    }).catch((e: Error) => {
      console.warn(`ArticleTranslationController: language check failed: ${e?.message}`);
    });
  }

  private setAlreadyInPreferredLanguage(sourceLanguage: string, isFullText: boolean): void {
    this.showTranslatedContent = false;
    this.translatedHtml = '';
    this.sourceLanguage = sourceLanguage;
    this.phaseIsFullText = isFullText;
    this.phase = ArticleTranslationPhase.AlreadyInPreferredLanguage;
  }

  private clearAlreadyInPreferredLanguageState(isFullText: boolean | null): void {
    if (this.phase !== ArticleTranslationPhase.AlreadyInPreferredLanguage) {
      return;
    }
    if (isFullText === null || this.phaseIsFullText === isFullText) {
      this.phase = ArticleTranslationPhase.Empty;
    }
  }

  private clearTranslatedContent(): void {
    this.showTranslatedContent = false;
    this.translatedHtml = '';
    this.phase = ArticleTranslationPhase.Empty;
  }
}
