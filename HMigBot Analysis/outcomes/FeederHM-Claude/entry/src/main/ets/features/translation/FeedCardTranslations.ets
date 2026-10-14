/*
 * FeedCardTranslations — 列表卡片翻译交互契约（源 FeedViewModel.kt :79-347、:734-782 TranslatedFeedCards/FeedCardSource）。
 *   TR-A40：`Translate article previews` 开启后可见卡片先显示缓存、再翻译；本地模式需下载模型时保持原文且不触发下载。
 *   TR-A41：开关/provider/首选语言变化 → 清空全部卡片译文、代数 +1、按新配置重译。
 *   TR-A42：列表页顶部下载进度卡（downloadProgress）。
 * 列表页持有一个实例：start()/stop()；卡片可见时 translateFeedCardIfNeeded(item)；渲染用 merge(item)，
 * ForEach/LazyForEach key 需含 generation（或读取 merge 的 @Trace 依赖）。
 */
import { SettingsStore } from '../../core/settings/SettingsStore';
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { FeedListItem } from '../../core/model/FeedItem';
import { ID_UNSET } from '../../core/model/Enums';
import { TranslationDownloadProgress } from '../../ui/common/CommonWidgets';
import { canUseAsTranslationApi, isLocalTranslation } from './LanguageUtils';
import { copyFeedListItem, TranslationManager } from './TranslationManager';
import { LocalTranslator } from './LocalTranslator';
import { BergamotModelManager } from './BergamotModels';
import { BergamotModelDownloadProgress } from './BergamotRegistry';
import { toUiDownloadProgress } from './TranslationUiSupport';

/** 源 FeedCardTranslationConfig */
class FeedCardTranslationConfig {
  enabled: boolean;
  settings: OpenAISettings;
  targetLanguage: string;

  constructor(enabled: boolean, settings: OpenAISettings, targetLanguage: string) {
    this.enabled = enabled;
    this.settings = settings.copy();
    this.targetLanguage = targetLanguage.trim();
  }

  isActive(): boolean {
    return this.enabled && canUseAsTranslationApi(this.settings) && this.targetLanguage.length > 0;
  }

  equals(o: FeedCardTranslationConfig): boolean {
    return this.enabled === o.enabled && this.settings.equals(o.settings) && this.targetLanguage === o.targetLanguage;
  }
}

/** 源 FeedCardTranslationEntry（以 FeedCardSource 为键：itemId + 原标题 + 原摘要） */
export class FeedCardTranslationEntry {
  sourceTitle: string;
  sourceSnippet: string;
  item: FeedListItem;
  isComplete: boolean;

  constructor(sourceTitle: string, sourceSnippet: string, item: FeedListItem, isComplete: boolean) {
    this.sourceTitle = sourceTitle;
    this.sourceSnippet = sourceSnippet;
    this.item = item;
    this.isComplete = isComplete;
  }
}

function currentConfig(): FeedCardTranslationConfig {
  const st = SettingsStore.instance();
  return new FeedCardTranslationConfig(st.translateArticlePreviewsByDefault, st.translationApiSettings,
    st.preferredTranslationLanguage);
}

@ObservedV2
export class FeedCardTranslations {
  /** 源 TranslatedFeedCards.generation */
  @Trace generation: number = 0;
  /** itemId → 译文条目（V2 观察 Map 增删改） */
  @Trace entries: Map<number, FeedCardTranslationEntry> = new Map<number, FeedCardTranslationEntry>();
  @Trace downloadProgress: TranslationDownloadProgress | null = null;

  private inFlight: Set<string> = new Set<string>();
  private lastConfig: FeedCardTranslationConfig | null = null;
  private unsubscribeSettings: (() => void) | null = null;
  private unsubscribeProgress: (() => void) | null = null;

  start(): void {
    if (this.unsubscribeSettings === null) {
      this.lastConfig = currentConfig();
      this.unsubscribeSettings = SettingsStore.instance().observe((_k: string) => {
        const cfg = currentConfig();
        const last = this.lastConfig;
        if (last === null || !last.equals(cfg)) {
          this.lastConfig = cfg;
          this.reset();
        }
      });
    }
    if (this.unsubscribeProgress === null) {
      const bus = BergamotModelManager.instance().progress;
      this.downloadProgress = toUiDownloadProgress(bus.value);
      this.unsubscribeProgress = bus.subscribe((p: BergamotModelDownloadProgress | null) => {
        this.downloadProgress = toUiDownloadProgress(p);
      });
    }
  }

  stop(): void {
    if (this.unsubscribeSettings !== null) {
      this.unsubscribeSettings();
      this.unsubscribeSettings = null;
    }
    if (this.unsubscribeProgress !== null) {
      this.unsubscribeProgress();
      this.unsubscribeProgress = null;
    }
  }

  /** TR-A41 */
  reset(): void {
    this.inFlight.clear();
    this.entries = new Map<number, FeedCardTranslationEntry>();
    this.generation = this.generation + 1;
  }

  /** 源 TranslatedFeedCards.merge：来源匹配时替换标题/摘要（译文为空保持原文） */
  merge(item: FeedListItem): FeedListItem {
    const e = this.entries.get(item.id);
    if (e === undefined || e.sourceTitle !== item.title || e.sourceSnippet !== item.snippet) {
      return item;
    }
    return copyFeedListItem(item, e.item.title.trim().length === 0 ? item.title : e.item.title,
      e.item.snippet.trim().length === 0 ? item.snippet : e.item.snippet);
  }

  private update(item: FeedListItem, translated: FeedListItem, isComplete: boolean): void {
    const next = new Map<number, FeedCardTranslationEntry>(this.entries);
    next.set(item.id, new FeedCardTranslationEntry(item.title, item.snippet, translated, isComplete));
    this.entries = next;
  }

  /** TR-A40：卡片可见时调用 */
  translateFeedCardIfNeeded(item: FeedListItem): void {
    if (item.id === ID_UNSET) {
      return;
    }
    const config = currentConfig();
    if (!config.isActive()) {
      return;
    }
    const existing = this.entries.get(item.id);
    if (existing !== undefined && existing.sourceTitle === item.title && existing.sourceSnippet === item.snippet &&
      existing.isComplete) {
      return;
    }
    const s = config.settings;
    const requestKey = [`${item.id}`, item.title, item.snippet, s.baseUrl, s.key, s.modelId, `${s.timeoutSeconds}`,
      s.azureApiVersion, s.azureDeploymentId, config.targetLanguage].join('\u0000');
    if (this.inFlight.has(requestKey)) {
      return;
    }
    this.inFlight.add(requestKey);
    this.run(item, config).catch((e: Error) => {
      console.warn(`FeedCardTranslations: translate ${item.id} failed: ${e?.message}`);
    }).finally(() => {
      this.inFlight.delete(requestKey);
    });
  }

  private async run(item: FeedListItem, config: FeedCardTranslationConfig): Promise<void> {
    const manager = TranslationManager.instance();
    const cached = await manager.getCachedTranslatedFeedListItem(item, config.settings, config.targetLanguage);
    if (cached.hasCachedTranslation) {
      this.update(item, cached.item, cached.isFullyCached);
    }
    if (cached.isFullyCached) {
      return;
    }
    if (isLocalTranslation(config.settings)) {
      const text = [item.title, item.snippet].filter((t: string) => t.trim().length > 0).join(' ');
      const ok = await LocalTranslator.instance().canTranslateWithoutBergamotDownload(text, config.targetLanguage, '',
        false);
      if (!ok) {
        return;
      }
    }
    const translatedItem = await manager.translateFeedListItem(item, config.settings, config.targetLanguage);
    const updatedCached = await manager.getCachedTranslatedFeedListItem(item, config.settings, config.targetLanguage);
    let displayItem: FeedListItem | null = null;
    if (updatedCached.hasCachedTranslation) {
      displayItem = updatedCached.item;
    } else if (translatedItem.title !== item.title || translatedItem.snippet !== item.snippet) {
      displayItem = translatedItem;
    }
    const now = currentConfig();
    if (displayItem !== null && now.isActive() && now.equals(config)) {
      this.update(item, displayItem, updatedCached.isFullyCached);
    }
  }
}
