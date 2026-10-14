/*
 * OpenAIEditDialogModel — 编辑对话框的草稿状态与动作（源 OpenAISection.kt:100-199 中的 remember 状态与按钮回调）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { Repository } from '../../core/repo/Repository';
import { TranslationModelsEditor } from '../translation/TranslationModelsEditor';
import {
  AIProviderPreset, applyPreset, isTimeoutInputValid, ModelsStateKind, OpenAIModelsState, OpenAISectionType,
  OpenAISectionVmState, ValidationMessage, validationMessage
} from './OpenAISettingsModel';

const LOAD_DEBOUNCE_MS: number = 750;

/** 对话框关闭句柄（close 幂等） */
export class OpenAIDialogHandle {
  private closer: (() => void) | null = null;
  private closed: boolean = false;

  bind(closer: () => void): void {
    this.closer = closer;
  }

  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const c = this.closer;
    if (c !== null) {
      c();
    }
  }
}

@ObservedV2
export class OpenAIEditDialogModel {
  section: OpenAISectionType = OpenAISectionType.Summary;
  dialogTitle: ResourceStr = '';
  info: ResourceStr = '';
  /** 草稿（源 current） */
  @Trace current: OpenAISettings = new OpenAISettings();
  /** 源 provider（remember，由存储推断） */
  @Trace provider: AIProviderPreset = AIProviderPreset.NONE;
  /** 源 currentPreferredTranslationLanguage */
  @Trace preferredLanguage: string = '';
  /** 源 timeoutString（remember(current.timeoutSeconds)） */
  @Trace timeoutString: string = '30';
  /** 源 showOnlyBergamotLanguages（对话框内 remember，默认 true，不持久化） */
  @Trace showOnlyBergamotLanguages: boolean = true;
  /** 源 Settings.canTranslate（已保存翻译设置可用且首选语言非空） */
  @Trace canTranslate: boolean = false;
  vm: OpenAISectionVmState = new OpenAISectionVmState();
  editor: TranslationModelsEditor | null = null;
  handle: OpenAIDialogHandle = new OpenAIDialogHandle();
  private timer: number = -1;

  /** AI-A34：仅与当前草稿完全匹配的结果有效 */
  matchingModels(): OpenAIModelsState {
    return this.vm.modelsState.matchingOrNone(this.current);
  }

  validation(): ValidationMessage | null {
    return validationMessage(this.current, this.provider, this.matchingModels());
  }

  hasProvider(): boolean {
    return this.provider !== AIProviderPreset.NONE;
  }

  /** 源 onEvent(UpdateSettings) 被对话框拦截 → 改草稿 */
  setDraft(next: OpenAISettings): void {
    if (next.equals(this.current)) {
      return;
    }
    const timeoutChanged = next.timeoutSeconds !== this.current.timeoutSeconds;
    this.current = next;
    if (timeoutChanged) {
      this.timeoutString = `${next.timeoutSeconds}`;
    }
    this.scheduleLoad();
  }

  /** AI-A09：切换提供方立即改写草稿 */
  setProvider(p: AIProviderPreset): void {
    this.provider = p;
    this.current = applyPreset(p, this.current);
    this.scheduleLoad();
  }

  /** AI-A12：非法超时不写入草稿 */
  setTimeoutInput(input: string): void {
    this.timeoutString = input;
    if (isTimeoutInputValid(input)) {
      const next = this.current.copy();
      next.timeoutSeconds = Number.parseInt(input, 10);
      this.setDraft(next);
    }
  }

  /** AI-A14：LaunchedEffect(current, provider) → 750ms 后 LoadModels(current)（非 None/Local） */
  scheduleLoad(): void {
    this.cancelTimer();
    if (this.provider === AIProviderPreset.NONE || this.provider === AIProviderPreset.LOCAL_TRANSLATION) {
      return;
    }
    const snapshot = this.current.copy();
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.vm.loadModels(snapshot);
    }, LOAD_DEBOUNCE_MS);
  }

  cancelTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  modelsLoading(): boolean {
    return this.matchingModels().kind === ModelsStateKind.Loading;
  }

  /** AI-A22：Save */
  save(): void {
    if (this.provider !== AIProviderPreset.NONE && this.provider !== AIProviderPreset.LOCAL_TRANSLATION &&
      this.validation() !== null) {
      return;
    }
    this.cancelTimer();
    const draft = this.current.copy();
    const repo = Repository.instance();
    if (this.section === OpenAISectionType.Summary) {
      repo.setOpenAiSettings(draft).catch((e: Error) => {
        console.error(`OpenAIEditDialog: save summary settings failed ${e?.message}`);
      });
    } else {
      repo.setTranslationApiSettings(draft).catch((e: Error) => {
        console.error(`OpenAIEditDialog: save translation settings failed ${e?.message}`);
      });
      repo.setPreferredTranslationLanguage(this.preferredLanguage).catch((e: Error) => {
        console.error(`OpenAIEditDialog: save preferred language failed ${e?.message}`);
      });
    }
    const editor = this.editor;
    if (editor !== null) {
      editor.commitPendingDeletions().catch((e: Error) => {
        console.error(`OpenAIEditDialog: delete language pairs failed ${e?.message}`);
      });
    }
    this.vm.isEditMode = false;
    this.handle.close();
  }

  /** AI-A23：Cancel / 点外部 / 返回 */
  dismiss(): void {
    this.cancelTimer();
    const editor = this.editor;
    if (editor !== null) {
      editor.discardPendingDeletions();
    }
    this.vm.isEditMode = false;
    this.handle.close();
  }
}
