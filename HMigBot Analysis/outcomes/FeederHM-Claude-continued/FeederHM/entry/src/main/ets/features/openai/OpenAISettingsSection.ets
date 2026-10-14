/*
 * OpenAISettingsSection — Settings 页 `AI and translation` 组的全部条目（由 page-settings 嵌入）。
 * 源：ui/compose/settings/Settings.kt:866-930（SettingsGroup(openai_settings)：Summary API 行、Translation API 行、
 *     canTranslate 时 Translate article previews / Translate articles by default 两开关）、
 *     OpenAISection.kt:80-270（OpenAISection / TranslationApiSection / OpenAISectionItem）。
 * 用法：page-settings 在其组列表中放 `OpenAISettingsSection({ showGroupTitle: true })`
 *       （若页面自行绘制组标题则 showGroupTitle: false）。
 */
import { SettingsState } from '../../core/settings/SettingsModels';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { Repository } from '../../core/repo/Repository';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { TranslationModelsEditor } from '../translation/TranslationModelsEditor';
import {
  canTranslateWithSettings, isSectionConfigured, OpenAISectionType, OpenAISettingsVm, presetName,
  providerFromSettings, sanitizeSettings
} from './OpenAISettingsModel';
import { OpenAIEditDialogModel } from './OpenAIEditDialogModel';
import { openOpenAIEditDialog } from './OpenAIEditDialog';

export { OpenAISectionType } from './OpenAISettingsModel';

/** 源 OpenAISectionItem：64vp 空占位 + 标题(titleMedium)/副标题(bodySmall)，整行可点 */
@ComponentV2
struct OpenAISectionRow {
  @Param rowTitle: ResourceStr = '';
  @Param configured: boolean = false;
  @Param providerName: string = '';
  @Event onOpen: () => void = () => {
    console.info('TODO:open:OpenAISectionRow');
  };

  build() {
    Row() {
      Column()
        .width(64)
        .height(64)
      Column() {
        Text(this.rowTitle)
          .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        Column().height(2)
        if (!this.configured) {
          Text($r('app.string.ai_not_configured'))
            .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
        } else {
          Text($r('app.string.api_provider_summary', this.providerName))
            .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => {
      this.onOpen();
    })
  }
}

/** 源 SwitchSetting（无 description；icon 占位 64vp） */
@ComponentV2
struct AiSwitchRow {
  @Param rowTitle: ResourceStr = '';
  @Param checked: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = (v: boolean) => {
    console.info('TODO:checkedChange:AiSwitchRow ' + v);
  };

  build() {
    Row() {
      Column()
        .width(64)
        .height(64)
      Text(this.rowTitle)
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .layoutWeight(1)
      Row().width(8)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(FeederTheme.colors.primary)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: 64 })
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.SWITCH)
    .accessibilityChecked(this.checked)
    .onClick(() => {
      this.onCheckedChange(!this.checked);
    })
  }
}

@ComponentV2
export struct OpenAISettingsSection {
  /** 是否绘制组标题 `AI and translation`（源 GroupTitle：64vp 起始空白、labelMedium、primary 色、高 64） */
  @Param showGroupTitle: boolean = false;
  @Local st: SettingsState = SettingsStore.instance().state;
  @Local editor: TranslationModelsEditor = new TranslationModelsEditor();

  aboutToAppear(): void {
    // 源 SettingsViewModel.init → loadDownloadedLanguagePairs()
    this.editor.load().catch((e: Error) => {
      console.warn(`OpenAISettingsSection: load downloaded pairs failed ${e?.message}`);
    });
  }

  private canTranslate(): boolean {
    return canTranslateWithSettings(this.st.translationApiSettings, this.st.preferredTranslationLanguage);
  }

  private openEditor(section: OpenAISectionType): void {
    const vm = OpenAISettingsVm.instance().stateOf(section);
    if (vm.isEditMode) {
      return;
    }
    const stored = section === OpenAISectionType.Summary ? this.st.openAiSettings : this.st.translationApiSettings;
    const sanitized = sanitizeSettings(section, stored);
    const model = new OpenAIEditDialogModel();
    model.section = section;
    model.dialogTitle = section === OpenAISectionType.Summary ? $r('app.string.summary_api_settings') :
    $r('app.string.translation_api_settings');
    model.info = section === OpenAISectionType.Summary ? $r('app.string.summary_api_settings_info') :
    $r('app.string.translation_api_settings_info');
    model.current = sanitized.copy();
    model.provider = providerFromSettings(sanitized);
    model.preferredLanguage = this.st.preferredTranslationLanguage;
    model.timeoutString = `${sanitized.timeoutSeconds}`;
    model.showOnlyBergamotLanguages = true;
    model.canTranslate = this.canTranslate();
    model.vm = vm;
    model.editor = section === OpenAISectionType.Translation ? this.editor : null;
    openOpenAIEditDialog(this.getUIContext(), model);
  }

  build() {
    Column() {
      if (this.showGroupTitle) {
        Row() {
          Column()
            .width(64)
            .height(64)
          Text($r('app.string.openai_settings'))
            .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.primary))
        }
        .width('100%')
        .height(64)
        .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
        .alignItems(VerticalAlign.Center)
      }

      OpenAISectionRow({
        rowTitle: $r('app.string.summary_api_settings'),
        configured: isSectionConfigured(sanitizeSettings(OpenAISectionType.Summary, this.st.openAiSettings)),
        providerName: presetName(providerFromSettings(sanitizeSettings(OpenAISectionType.Summary,
          this.st.openAiSettings))),
        onOpen: () => {
          this.openEditor(OpenAISectionType.Summary);
        }
      })

      OpenAISectionRow({
        rowTitle: $r('app.string.translation_api_settings'),
        configured: isSectionConfigured(sanitizeSettings(OpenAISectionType.Translation,
          this.st.translationApiSettings)),
        providerName: presetName(providerFromSettings(sanitizeSettings(OpenAISectionType.Translation,
          this.st.translationApiSettings))),
        onOpen: () => {
          this.openEditor(OpenAISectionType.Translation);
        }
      })

      if (this.canTranslate()) {
        AiSwitchRow({
          rowTitle: $r('app.string.translate_feed_cards_by_default'),
          checked: this.st.translateArticlePreviewsByDefault,
          onCheckedChange: (v: boolean) => {
            Repository.instance().setTranslateArticlePreviewsByDefault(v).catch((e: Error) => {
              console.error(`OpenAISettingsSection: save preview translation failed ${e?.message}`);
            });
          }
        })
        AiSwitchRow({
          rowTitle: $r('app.string.translate_articles_by_default'),
          checked: this.st.translateArticlesByDefault,
          onCheckedChange: (v: boolean) => {
            Repository.instance().setTranslateArticlesByDefault(v).catch((e: Error) => {
              console.error(`OpenAISettingsSection: save article translation failed ${e?.message}`);
            });
          }
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
