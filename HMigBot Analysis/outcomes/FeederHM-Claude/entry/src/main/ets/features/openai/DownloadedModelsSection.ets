/*
 * DownloadedModelsSection — 翻译 API 对话框（Local offline）内的已下载离线模型区。
 * 源：ui/compose/settings/Settings.kt:1644 DownloadedModelsSection、:111 formatFileSize、:121 languageDisplayName。
 * 删除只标记（TranslationModelsEditor.markDelete / markDeleteAll），对话框 Save 时 commitPendingDeletions（AI-A27）。
 * 确认框：源 AlertDialog（confirm=Delete model，dismiss=Cancel）→ promptAction.showDialog 简单确认。
 */
import { promptAction } from '@kit.ArkUI';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { LanguagePairInfo } from '../translation/BergamotRegistry';
import { TranslationModelsEditor } from '../translation/TranslationModelsEditor';
import { translationString } from '../translation/TranslationUiSupport';
import { displayLanguageName } from './LanguageTables';

/** 源 formatFileSize */
export function formatFileSize(bytes: number): string {
  const kb = bytes / 1024.0;
  const mb = kb / 1024.0;
  if (mb >= 1.0) {
    return `${mb.toFixed(1)} MB`;
  }
  if (kb >= 1.0) {
    return `${kb.toFixed(0)} KB`;
  }
  return `${bytes} B`;
}

/** 源 languageDisplayName：系统显示名首字母大写；失败回落码 */
export function languageDisplayNameOf(code: string): string {
  const name = displayLanguageName(code);
  if (name.length === 0) {
    return code;
  }
  return name.charAt(0).toUpperCase() + name.substring(1);
}

@ComponentV2
export struct DownloadedModelsSection {
  @Param editor: TranslationModelsEditor = new TranslationModelsEditor();

  private confirmDelete(pair: LanguagePairInfo): void {
    const message = translationString('delete_model_pair_desc', 'Delete the %1$s to %2$s translation model (%3$s)?',
      [languageDisplayNameOf(pair.sourceLanguage), languageDisplayNameOf(pair.targetLanguage),
        formatFileSize(pair.sizeBytes)]);
    this.showConfirm($r('app.string.delete_model_pair'), message, () => {
      this.editor.markDelete(pair.sourceLanguage, pair.targetLanguage);
    });
  }

  private confirmDeleteAll(): void {
    const pairs = this.editor.visiblePairs();
    const message = translationString('delete_all_models_desc',
      'Delete all %1$d downloaded translation model(s) (%2$s)?',
      [`${pairs.length}`, formatFileSize(this.editor.totalVisibleBytes())]);
    this.showConfirm($r('app.string.delete_all_models'), message, () => {
      this.editor.markDeleteAll();
    });
  }

  private showConfirm(titleText: Resource, message: string, onConfirm: () => void): void {
    const buttons: promptAction.Button[] = [
      { text: $r('app.string.cancel'), color: FeederTheme.colors.primary },
      { text: $r('app.string.delete_model_pair'), color: FeederTheme.colors.primary }
    ];
    this.getUIContext().getPromptAction().showDialog({
      title: titleText,
      message: message,
      buttons: buttons
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        onConfirm();
      }
    }).catch((e: Error) => {
      console.debug(`DownloadedModelsSection: dialog dismissed ${e?.message}`);
    });
  }

  build() {
    Column() {
      Text($r('app.string.downloaded_translation_models'))
        .attributeModifier(textStyle(M3Type.titleSmall, false, FeederTheme.colors.primary))
        .padding({ top: 8, bottom: 4 })
      Text($r('app.string.downloaded_translation_models_desc'))
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
      Column().height(8)
      ForEach(this.editor.visiblePairs(), (pair: LanguagePairInfo) => {
        Row() {
          Column() {
            Text(`${languageDisplayNameOf(pair.sourceLanguage)} → ${languageDisplayNameOf(pair.targetLanguage)}`)
              .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
            Text(formatFileSize(pair.sizeBytes))
              .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(24)
              .fontColor([FeederTheme.colors.onSurfaceVariant])
          }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.delete_model_pair'))
          .onClick(() => {
            this.confirmDelete(pair);
          })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Center)
      }, (pair: LanguagePairInfo) => `${pair.sourceLanguage}|${pair.targetLanguage}|${pair.sizeBytes}`)

      if (this.editor.showDeleteAll()) {
        Row() {
          Column() {
            Text($r('app.string.delete_all_models'))
              .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
            Text(formatFileSize(this.editor.totalVisibleBytes()))
              .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(24)
              .fontColor([FeederTheme.colors.onSurfaceVariant])
          }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.delete_all_models'))
          .onClick(() => {
            this.confirmDeleteAll();
          })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
