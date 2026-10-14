/*
 * OpenAIEditDialog — Summary API / Translation API 编辑对话框外壳。
 * 源：ui/compose/settings/OpenAISection.kt:100-199（Dialog + Surface(fillMaxHeight 0.92, padding 24, extraLarge) +
 *     标题 headlineSmall + OpenAISectionEdit + 右对齐 Cancel/Save(enabled = validationMessage == null)）。
 * 弹窗：ComponentContent + getPromptAction().openCustomDialog（禁 CustomDialogController）；
 * 点外部/返回 → onWillDismiss → 丢弃草稿（AI-A23）。
 */
import { ComponentContent, promptAction } from '@kit.ArkUI';
import { AvoidArea, AvoidAreaStore } from '../../core/app/AvoidArea';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { OpenAIDialogHandle, OpenAIEditDialogModel } from './OpenAIEditDialogModel';
import { OpenAIEditContent } from './OpenAIEditContent';

@Builder
function openAIEditDialogBuilder(model: OpenAIEditDialogModel) {
  OpenAIEditDialogView({ model: model })
}

@ComponentV2
export struct OpenAIEditDialogView {
  @Param model: OpenAIEditDialogModel = new OpenAIEditDialogModel();
  @Local avoid: AvoidArea = AvoidAreaStore.get();

  private surfaceWidth(): number {
    return Math.max(0, FeederTheme.windowWidthVp - 48);
  }

  /** 源 fillMaxHeight(0.92f).padding(24)；另保证不与状态栏/导航条重叠（AI-A01） */
  private surfaceHeight(): number {
    const h = FeederTheme.windowHeightVp;
    const inset = Math.max(this.avoid.top, this.avoid.bottom, 24);
    return Math.max(0, Math.min(h * 0.92 - 48, h - 2 * inset));
  }

  build() {
    Column() {
      Text(this.model.dialogTitle)
        .attributeModifier(textStyle(M3Type.headlineSmall, false, FeederTheme.colors.onSurface))
        .width('100%')
      Column().height(16)
      Column() {
        OpenAIEditContent({ model: this.model })
      }
      .layoutWeight(1)
      .width('100%')
      Column().height(16)
      Row() {
        Button($r('app.string.cancel'))
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.model.dismiss();
          })
        Row().width(8)
        Button($r('app.string.save'))
          .backgroundColor(this.model.validation() === null ? FeederTheme.colors.primary :
            FeederTheme.colors.onSurface)
          .fontColor(this.model.validation() === null ? FeederTheme.colors.onPrimary : FeederTheme.colors.surface)
          .opacity(this.model.validation() === null ? 1.0 : 0.38)
          .enabled(this.model.validation() === null)
          .onClick(() => {
            this.model.save();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width(this.surfaceWidth())
    .height(this.surfaceHeight())
    .padding(24)
    .backgroundColor(FeederTheme.colors.surface)
    .borderRadius(28)
    .alignItems(HorizontalAlign.Start)
  }
}

/** AI-A04：打开编辑对话框（源 SwitchEditMode(true)） */
export function openOpenAIEditDialog(ui: UIContext, model: OpenAIEditDialogModel): OpenAIDialogHandle {
  const node = new ComponentContent<OpenAIEditDialogModel>(ui, wrapBuilder(openAIEditDialogBuilder), model);
  const pa = ui.getPromptAction();
  model.handle.bind(() => {
    pa.closeCustomDialog(node).then(() => {
      node.dispose();
    }).catch((e: Error) => {
      console.error(`OpenAIEditDialog: close failed ${e?.message}`);
    });
  });
  const opts: promptAction.BaseDialogOptions = {
    autoCancel: true,
    alignment: DialogAlignment.Center,
    onWillDismiss: (action: DismissDialogAction) => {
      console.debug(`OpenAIEditDialog: dismiss request reason=${action.reason}`);
      model.dismiss();
    }
  };
  model.vm.isEditMode = true;
  pa.openCustomDialog(node, opts).catch((e: Error) => {
    console.error(`OpenAIEditDialog: open failed ${e?.message}`);
    model.cancelTimer();
    model.vm.isEditMode = false;
    node.dispose();
  });
  model.scheduleLoad();
  return model.handle;
}
