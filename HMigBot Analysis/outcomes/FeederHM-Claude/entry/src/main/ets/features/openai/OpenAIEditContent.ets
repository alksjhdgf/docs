/*
 * OpenAIEditContent — 对话框可滚动主体（源 OpenAISection.kt:281-602 OpenAISectionEdit）。
 * 字段顺序：info → 校验提示卡 → Provider → key → Model Id(+模型状态) → Base URL / Translation endpoint →
 *   （Translation）首选语言 + 说明 [+ Local：仅可下载语言开关 + 已下载模型区] → Timeout → Azure 部署/版本。
 * M3 TextField（filled）以自绘容器近似：surfaceContainerHighest 底、上圆角 4、底部指示线；标签常驻上方。
 */
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { OpenAIEditDialogModel } from './OpenAIEditDialogModel';
import {
  AIProviderPreset, availableProviders, DEEPL_ENDPOINT, isTimeoutInputValid, ModelsStateKind, OpenAIModelsState,
  OpenAISectionType, presetIsTranslationOnly, presetNeedsApiKey, presetTitle, selectedIsBergamotLanguage,
  TranslationLanguageOption, translationLanguageOption, translationLanguageOptions, ValidationMessage, validationText,
  applyMaskedEdit, maskApiKey
} from './OpenAISettingsModel';
import { OPENAI_DEFAULT_BASE_URL } from './OpenAIClient';
import { DownloadedModelsSection } from './DownloadedModelsSection';
import { TranslationModelsEditor } from '../translation/TranslationModelsEditor';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

@Builder
function noTrailing() {
}

/** 源 M3 TextField（filled）近似 */
@ComponentV2
export struct AiTextField {
  @Param label: ResourceStr = '';
  @Param value: string = '';
  @Param placeholder: ResourceStr = '';
  /** AI-A11：key 掩码显示 */
  @Param masked: boolean = false;
  @Param readOnly: boolean = false;
  /** 只读字段显示值（readEmpty 时显示 placeholder） */
  @Param readValue: ResourceStr = '';
  @Param readEmpty: boolean = false;
  @Param fieldEnabled: boolean = true;
  @Param isError: boolean = false;
  @Param supportingError: ResourceStr = '';
  @Param inputKind: InputType = InputType.Normal;
  @BuilderParam trailing: () => void = noTrailing;
  @Event onValueChange: (v: string) => void = (v: string) => {
    console.info('TODO:valueChange:AiTextField ' + v.length);
  };

  private shown(): string {
    return this.masked ? maskApiKey(this.value) : this.value;
  }

  private labelColor(): string {
    if (this.isError) {
      return FeederTheme.colors.error;
    }
    return FeederTheme.colors.onSurfaceVariant;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.label)
            .attributeModifier(textStyle(M3Type.bodySmall, false, this.labelColor()))
          if (this.readOnly) {
            if (!this.readEmpty) {
              Text(this.readValue)
                .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
                .padding({ top: 4, bottom: 4 })
            } else {
              Text(this.placeholder)
                .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurfaceVariant))
                .padding({ top: 4, bottom: 4 })
            }
          } else {
            TextInput({ text: this.shown(), placeholder: this.placeholder })
              .editMenuOptions(new FeederEditMenuOptions((): string => this.shown()))
              .type(this.inputKind)
              .backgroundColor(Color.Transparent)
              .padding(0)
              .borderRadius(0)
              .fontSize(M3Type.bodyLarge.size)
              .fontColor(FeederTheme.colors.onSurface)
              .placeholderColor(FeederTheme.colors.onSurfaceVariant)
              .caretColor(FeederTheme.colors.primary)
              .enterKeyType(EnterKeyType.Next)
              .width('100%')
              .onChange((text: string, previewText?: PreviewText, options?: TextChangeOptions) => {
                const raw = this.value;
                const oldShown = this.shown();
                if (text === oldShown) {
                  return;
                }
                if (!this.masked) {
                  this.onValueChange(text);
                  return;
                }
                let beforeStart: number | null = null;
                let beforeEnd: number | null = null;
                let afterStart: number | null = null;
                let afterEnd: number | null = null;
                if (options !== undefined && options !== null) {
                  beforeStart = options.rangeBefore.start !== undefined ? options.rangeBefore.start : null;
                  beforeEnd = options.rangeBefore.end !== undefined ? options.rangeBefore.end : null;
                  afterStart = options.rangeAfter.start !== undefined ? options.rangeAfter.start : null;
                  afterEnd = options.rangeAfter.end !== undefined ? options.rangeAfter.end : null;
                }
                this.onValueChange(applyMaskedEdit(raw, oldShown, text, beforeStart, beforeEnd, afterStart, afterEnd));
              })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, top: 8, bottom: 8, right: 8 })

        this.trailing()
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
      .borderRadius({ topLeft: 4, topRight: 4 })
      .border({
        width: { bottom: this.isError ? 2 : 1 },
        color: { bottom: this.isError ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant }
      })
      .opacity(this.fieldEnabled ? 1.0 : 0.38)
      .enabled(this.fieldEnabled)

      if (this.isError) {
        Text(this.supportingError)
          .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.error))
          .padding({ left: 16, right: 16, top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct OpenAIEditContent {
  @Param model: OpenAIEditDialogModel = new OpenAIEditDialogModel();

  private showDownloadedModels(): boolean {
    const editor = this.model.editor;
    return editor !== null && this.model.canTranslate && editor.visiblePairs().length > 0;
  }

  private providerMenu(): MenuElement[] {
    const out: MenuElement[] = [];
    availableProviders(this.model.section).forEach((p: AIProviderPreset) => {
      out.push({
        value: presetTitle(p), action: () => {
          this.model.setProvider(p);
        }
      });
    });
    return out;
  }

  private modelsMenu(): MenuElement[] {
    const out: MenuElement[] = [];
    const state: OpenAIModelsState = this.model.matchingModels();
    if (state.kind !== ModelsStateKind.Success) {
      return out;
    }
    state.ids.forEach((id: string) => {
      out.push({
        value: id, action: () => {
          const next = this.model.current.copy();
          next.modelId = id;
          this.model.setDraft(next);
        }
      });
    });
    return out;
  }

  private languageMenu(): MenuElement[] {
    const out: MenuElement[] = [];
    translationLanguageOptions(this.model.provider, this.model.showOnlyBergamotLanguages)
      .forEach((o: TranslationLanguageOption) => {
        out.push({
          value: o.label, action: () => {
            this.model.preferredLanguage = o.code;
          }
        });
      });
    return out;
  }

  private selectedLanguage(): TranslationLanguageOption | null {
    return translationLanguageOption(this.model.provider, this.model.preferredLanguage);
  }

  private selectedLanguageLabel(): string {
    const s = this.selectedLanguage();
    return s !== null ? s.label : this.model.preferredLanguage;
  }

  @Builder
  expandButton(menu: MenuElement[], description: Resource, clickable: boolean) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
    }
    .width(48)
    .height(48)
    .margin({ right: 4 })
    .backgroundColor(Color.Transparent)
    .accessibilityText(description)
    .opacity(clickable ? 1.0 : 0.38)
    .enabled(clickable)
    .bindMenu(menu)
  }

  @Builder
  providerTrailing() {
    this.expandButton(this.providerMenu(), $r('app.string.ai_provider'), true)
  }

  @Builder
  modelsTrailing() {
    if (this.model.modelsLoading()) {
      LoadingProgress()
        .width(40)
        .height(40)
        .margin({ right: 8 })
        .color(FeederTheme.colors.primary)
    } else {
      this.expandButton(this.modelsMenu(), $r('app.string.list_of_available_models'),
        this.model.matchingModels().kind === ModelsStateKind.Success)
    }
  }

  @Builder
  languageTrailing() {
    this.expandButton(this.languageMenu(), $r('app.string.preferred_translation_language'), true)
  }

  @Builder
  warningCard(v: ValidationMessage) {
    Row() {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurface])
      Text(validationText(v))
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
        .padding({ left: 8 })
        .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FeederTheme.colors.surface)
    .border({ width: 1, color: FeederTheme.colors.outlineVariant, radius: 12 })
  }

  /** 源 OpenAIModelsStatus（AI-A16） */
  @Builder
  modelsStatus() {
    if (this.model.matchingModels().kind === ModelsStateKind.Success &&
      this.model.matchingModels().ids.length === 0) {
      Text($r('app.string.no_models_were_found'))
        .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
        .padding(8)
        .border({ width: 1, color: FeederTheme.colors.outlineVariant, radius: 12 })
    } else if (this.model.matchingModels().kind === ModelsStateKind.Error) {
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(24)
            .fontColor([FeederTheme.colors.onSurface])
          Text($r('app.string.unable_to_load_models'))
            .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
            .padding({ left: 4 })
            .layoutWeight(1)
          if (this.model.matchingModels().message.length > 0) {
            SymbolGlyph(this.model.vm.showModelsError ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
              .fontSize(24)
              .fontColor([FeederTheme.colors.onSurface])
              .accessibilityText($r('app.string.show_message'))
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.model.matchingModels().message.length > 0 && this.model.vm.showModelsError) {
          Text(this.model.matchingModels().message)
            .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
            .padding(8)
        }
      }
      .width('100%')
      .padding(8)
      .alignItems(HorizontalAlign.Start)
      .border({ width: 1, color: FeederTheme.colors.outlineVariant, radius: 12 })
      .onClick(() => {
        this.model.vm.showModelsError = !this.model.vm.showModelsError;
      })
    }
  }

  /** 源 preferredTranslationLanguageDescription（AI-A24/A26） */
  @Builder
  languageDescription() {
    if (this.model.provider !== AIProviderPreset.LOCAL_TRANSLATION) {
      Text($r('app.string.preferred_translation_language_description'))
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
        .padding({ left: 16, top: 4, right: 16 })
    } else {
      Text() {
        Span($r('app.string.local_translation_setup_system'))
        if (selectedIsBergamotLanguage(this.selectedLanguage())) {
          Span(' ')
          Span($r('app.string.local_translation_setup_bergamot'))
        }
      }
      .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
      .padding({ left: 16, top: 4, right: 16 })
    }
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        // 1. info（AI-A04）
        Text(this.model.info)
          .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.outline))

        // 2. 校验提示（AI-A17..A20）
        if (this.model.validation() !== null) {
          this.warningCard(this.model.validation() as ValidationMessage)
        }

        // 3. Provider（AI-A05/A06）
        AiTextField({
          label: $r('app.string.ai_provider'),
          readValue: presetTitle(this.model.provider),
          readOnly: true,
          trailing: (): void => {
            this.providerTrailing()
          }
        })

        // 4. key（AI-A10/A11）
        if (this.model.hasProvider() && presetNeedsApiKey(this.model.provider)) {
          AiTextField({
            label: this.model.provider === AIProviderPreset.DEEPL ? $r('app.string.deepl_api_key') :
            $r('app.string.api_key'),
            value: this.model.current.key,
            masked: true,
            onValueChange: (v: string) => {
              const next = this.model.current.copy();
              next.key = v;
              this.model.setDraft(next);
            }
          })
        }

        // 5. Model Id + 模型状态（AI-A15/A16）
        if (this.model.hasProvider() && !presetIsTranslationOnly(this.model.provider)) {
          AiTextField({
            label: $r('app.string.model_id'),
            value: this.model.current.modelId,
            trailing: (): void => {
              this.modelsTrailing()
            },
            onValueChange: (v: string) => {
              const next = this.model.current.copy();
              next.modelId = v;
              this.model.setDraft(next);
            }
          })
          this.modelsStatus()
        }

        // 6. Base URL / Translation endpoint
        if (this.model.hasProvider() && !presetIsTranslationOnly(this.model.provider)) {
          AiTextField({
            label: $r('app.string.base_url_optional'),
            value: this.model.current.baseUrl,
            placeholder: OPENAI_DEFAULT_BASE_URL,
            inputKind: InputType.URL,
            onValueChange: (v: string) => {
              const next = this.model.current.copy();
              next.baseUrl = v;
              this.model.setDraft(next);
            }
          })
        } else if (this.model.provider === AIProviderPreset.DEEPL) {
          AiTextField({
            label: $r('app.string.translation_endpoint'),
            readValue: DEEPL_ENDPOINT,
            readOnly: true,
            fieldEnabled: false
          })
        }

        // 7. 首选翻译语言（AI-A24..A27）
        if (this.model.section === OpenAISectionType.Translation && this.model.hasProvider()) {
          Column() {
            AiTextField({
              label: $r('app.string.preferred_translation_language'),
              readValue: this.selectedLanguageLabel(),
              readEmpty: this.selectedLanguageLabel().length === 0,
              placeholder: $r('app.string.translation_language_placeholder'),
              readOnly: true,
              trailing: (): void => {
                this.languageTrailing()
              }
            })
            this.languageDescription()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.model.provider === AIProviderPreset.LOCAL_TRANSLATION) {
            Row() {
              Text($r('app.string.show_only_bergamot_languages'))
                .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.model.showOnlyBergamotLanguages })
                .selectedColor(FeederTheme.colors.primary)
                .onChange((isOn: boolean) => {
                  this.model.showOnlyBergamotLanguages = isOn;
                })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.model.showOnlyBergamotLanguages = !this.model.showOnlyBergamotLanguages;
            })

            if (this.showDownloadedModels()) {
              DownloadedModelsSection({ editor: this.model.editor as TranslationModelsEditor })
            }
          }
        }

        // 8. Timeout（AI-A12）
        if (this.model.hasProvider() && this.model.provider !== AIProviderPreset.LOCAL_TRANSLATION) {
          AiTextField({
            label: $r('app.string.time_out'),
            value: this.model.timeoutString,
            placeholder: $r('app.string.time_out_placeholder'),
            inputKind: InputType.Number,
            isError: !isTimeoutInputValid(this.model.timeoutString),
            supportingError: $r('app.string.time_out_validation_error'),
            onValueChange: (v: string) => {
              this.model.setTimeoutInput(v);
            }
          })
        }

        // 9. Azure（AI-A13）
        if (this.model.hasProvider() && this.model.provider === AIProviderPreset.AZURE_OPENAI) {
          AiTextField({
            label: $r('app.string.azure_deployment_id'),
            value: this.model.current.azureDeploymentId,
            onValueChange: (v: string) => {
              const next = this.model.current.copy();
              next.azureDeploymentId = v;
              this.model.setDraft(next);
            }
          })
          AiTextField({
            label: $r('app.string.azure_api_version'),
            value: this.model.current.azureApiVersion,
            placeholder: '2024-02-15-preview',
            onValueChange: (v: string) => {
              const next = this.model.current.copy();
              next.azureApiVersion = v;
              this.model.setDraft(next);
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }
}
