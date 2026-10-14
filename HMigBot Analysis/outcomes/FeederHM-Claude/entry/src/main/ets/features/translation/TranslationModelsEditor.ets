/*
 * TranslationModelsEditor — 设置页翻译 API 对话框中的离线模型管理与语言过滤契约。
 * 源：ui/compose/settings/Settings.kt :865-905、:1644（DownloadedModelsSection）、SettingsViewModel.kt :222-250、
 *     OpenAISection.kt :307/485-495/724-740（Show only downloadable languages，默认开）。
 *   TR-A43：provider 为 Local offline 时显示开关（默认开）；开启时仅列 Bergamot 目标语言（filterLanguageCodes）。
 *   TR-A44：可翻译且有已下载模型时显示列表（visiblePairs），每行 "源 → 目标" + 大小 + 删除；>1 对显示"全部删除"。
 *   TR-A45：删除先标记，点保存（commitPendingDeletions）才真正删除；取消（discardPendingDeletions）恢复显示。
 */
import { BergamotModelManager } from './BergamotModels';
import { LanguagePairInfo } from './BergamotRegistry';
import { filterTranslationLanguageCodes } from './LanguageUtils';
import { translationString } from './TranslationUiSupport';

function pairKey(source: string, target: string): string {
  return `${source}\u0000${target}`;
}

@ObservedV2
export class TranslationModelsEditor {
  /** 源 downloadedLanguagePairs StateFlow */
  @Trace downloaded: LanguagePairInfo[] = [];
  /** 源 pendingDeletedLanguagePairs（对话框内） */
  @Trace pendingDeleted: string[] = [];
  /** 源 showOnlyBergamotLanguages（remember，默认 true） */
  @Trace showOnlyBergamotLanguages: boolean = true;

  private readonly manager: BergamotModelManager;

  constructor(manager: BergamotModelManager | null = null) {
    this.manager = manager !== null ? manager : BergamotModelManager.instance();
  }

  /** 源 loadDownloadedLanguagePairs（设置页打开时） */
  async load(): Promise<void> {
    this.downloaded = await this.manager.getDownloadedLanguagePairs();
  }

  /** 未被标记删除的已下载语言对 */
  visiblePairs(): LanguagePairInfo[] {
    return this.downloaded.filter((p: LanguagePairInfo) =>
    this.pendingDeleted.indexOf(pairKey(p.sourceLanguage, p.targetLanguage)) < 0);
  }

  /** TR-A44：canTranslate && 有可见语言对 */
  showSection(canTranslate: boolean): boolean {
    return canTranslate && this.visiblePairs().length > 0;
  }

  showDeleteAll(): boolean {
    return this.visiblePairs().length > 1;
  }

  /** 行文案 "源 → 目标" */
  pairLabel(p: LanguagePairInfo): string {
    return `${p.sourceLanguage} → ${p.targetLanguage}`;
  }

  /** 确认框文案：`Delete the %1$s to %2$s translation model (%3$s)?` */
  deletePairMessage(p: LanguagePairInfo, formattedSize: string): string {
    return translationString('delete_model_pair_desc', 'Delete the %1$s to %2$s translation model (%3$s)?',
      [p.sourceLanguage, p.targetLanguage, formattedSize]);
  }

  /** 确认框文案：`Delete all %1$d downloaded translation model(s) (%2$s)?` */
  deleteAllMessage(formattedTotalSize: string): string {
    return translationString('delete_all_models_desc', 'Delete all %1$d downloaded translation model(s) (%2$s)?',
      [`${this.visiblePairs().length}`, formattedTotalSize]);
  }

  totalVisibleBytes(): number {
    let total = 0;
    this.visiblePairs().forEach((p: LanguagePairInfo) => {
      total += p.sizeBytes;
    });
    return total;
  }

  markDelete(source: string, target: string): void {
    const k = pairKey(source, target);
    if (this.pendingDeleted.indexOf(k) < 0) {
      this.pendingDeleted = this.pendingDeleted.concat([k]);
    }
  }

  markDeleteAll(): void {
    const keys = this.pendingDeleted.slice();
    this.visiblePairs().forEach((p: LanguagePairInfo) => {
      keys.push(pairKey(p.sourceLanguage, p.targetLanguage));
    });
    this.pendingDeleted = keys;
  }

  /** TR-A45：对话框保存 → 真正删除 */
  async commitPendingDeletions(): Promise<void> {
    const pending = this.pendingDeleted.slice();
    this.pendingDeleted = [];
    for (let i = 0; i < pending.length; i++) {
      const parts = pending[i].split('\u0000');
      await this.manager.deleteLanguagePair(parts[0], parts[1]);
    }
    this.downloaded = await this.manager.getDownloadedLanguagePairs();
  }

  /** TR-A45：对话框取消 → 恢复 */
  discardPendingDeletions(): void {
    this.pendingDeleted = [];
  }

  /** 源 SettingsViewModel.deleteLanguagePair（立即删除） */
  async deleteLanguagePair(source: string, target: string): Promise<void> {
    await this.manager.deleteLanguagePair(source, target);
    this.downloaded = await this.manager.getDownloadedLanguagePairs();
  }

  /** 源 SettingsViewModel.deleteAllLanguagePairs */
  async deleteAllLanguagePairs(): Promise<void> {
    const pairs = this.downloaded.slice();
    for (let i = 0; i < pairs.length; i++) {
      await this.manager.deleteLanguagePair(pairs[i].sourceLanguage, pairs[i].targetLanguage);
    }
    this.downloaded = [];
  }

  /** TR-A43 */
  filterLanguageCodes(codes: string[], isLocalProvider: boolean): string[] {
    return filterTranslationLanguageCodes(codes, isLocalProvider, this.showOnlyBergamotLanguages);
  }
}
