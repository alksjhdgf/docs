/**
 * WeDialog + DialogHelper (source: core/ui/component/dialog/Dialog.kt — WeDialog / rememberDialogState).
 *
 * WeDialog is the dialog *content* (rounded surface card, centered title/content, divider, cancel | ok
 * row of 56vp cells). DialogHelper opens it as a global custom dialog through
 * `uiCtx.getPromptAction().openCustomDialog(ComponentContent)` (no @CustomDialog, conventions §A).
 *
 *   DialogHelper.showConfirm(this.getUIContext(), $r('app.string.delete_address'),
 *     $r('app.string.delete_address_confirm'), $r('app.string.ok'), $r('app.string.cancel'),
 *     () => { this.vm.deleteAddress(); });
 *
 * Behaviour (DialogState.show defaults): closeOnAction = true → ok/cancel close the dialog, then run the
 * callback; tapping the mask / back closes it without calling onCancel (source onDismiss = hide()).
 */
import { ComponentContent, display, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { LogUtils } from '../../util/LogUtils';
import { WeDivider } from './AppCard';

const TAG: string = 'DialogHelper';

@ComponentV2
export struct WeDialog {
  @Param dialogTitle: ResourceStr = '';
  @Param dialogContent: ResourceStr | undefined = undefined;
  @Param okText: ResourceStr = $r('app.string.confirm');
  @Param cancelText: ResourceStr = $r('app.string.cancel');
  /** undefined = colorScheme.primary (live theme color) */
  @Param okColor: ResourceColor | undefined = undefined;
  /** Source shows the cancel cell only when onCancel != null */
  @Param showCancel: boolean = true;
  /** Source: fillMaxWidth(0.8f) of the window; DialogHelper passes 80% of the display width in vp */
  @Param dialogWidth: Length = '80%';
  @Event onOk: () => void = () => {
  };
  @Event onCancel: () => void = () => {
  };

  build() {
    Column() {
      Text(this.dialogTitle)
        .width('100%')
        .padding({
          top: 32,
          bottom: this.dialogContent !== undefined ? 16 : 0,
          left: 24,
          right: 24
        })
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
      if (this.dialogContent !== undefined) {
        Text(this.dialogContent as ResourceStr)
          .width('100%')
          .padding({ left: 24, right: 24 })
          .fontSize(17)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      // Spacer(height = 32.dp)
      Row()
        .width('100%')
        .height(32)
      WeDivider()
      Row() {
        if (this.showCancel) {
          Row() {
            Text(this.cancelText)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .height(56)
          // source: Box(contentAlignment = Center)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .stateStyles({
            normal: {
              .backgroundColor(Color.Transparent)
            },
            pressed: {
              .backgroundColor($r('app.color.press'))
            }
          })
          .onClick(() => {
            this.onCancel();
          })

          Row()
            .width(0.5)
            .height(56)
            .backgroundColor($r('app.color.border'))
        }
        Row() {
          Text(this.okText)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.okColor !== undefined ? this.okColor : ThemeManager.instance.primary)
        }
        .layoutWeight(1)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .stateStyles({
          normal: {
            .backgroundColor(Color.Transparent)
          },
          pressed: {
            .backgroundColor($r('app.color.press'))
          }
        })
        .onClick(() => {
          this.onOk();
        })
      }
      .width('100%')
      // source: horizontalArrangement = SpaceBetween (cells are weighted, so it is effectively full width)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
    }
    .width(this.dialogWidth)
    // source: Column(horizontalAlignment = CenterHorizontally, verticalArrangement = Center)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .clip(true)
  }
}

/** Arguments of the ComponentContent dialog (plain class: ComponentContent args are a snapshot). */
export class ConfirmDialogParams {
  dialogTitle: ResourceStr = '';
  dialogContent: ResourceStr | undefined = undefined;
  okText: ResourceStr = $r('app.string.confirm');
  cancelText: ResourceStr = $r('app.string.cancel');
  okColor: ResourceColor | undefined = undefined;
  showCancel: boolean = true;
  dialogWidth: number = 288;
  onOk: () => void = () => {
  };
  onCancel: () => void = () => {
  };
}

@Builder
function confirmDialogBuilder(p: ConfirmDialogParams) {
  WeDialog({
    dialogTitle: p.dialogTitle,
    dialogContent: p.dialogContent,
    okText: p.okText,
    cancelText: p.cancelText,
    okColor: p.okColor,
    showCancel: p.showCancel,
    dialogWidth: p.dialogWidth,
    onOk: (): void => p.onOk(),
    onCancel: (): void => p.onCancel()
  })
}

export class DialogHelper {
  /** 80% of the display width in vp (source fillMaxWidth(0.8f) with usePlatformDefaultWidth = false). */
  private static dialogWidthVp(uiCtx: UIContext): number {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      return uiCtx.px2vp(d.width) * 0.8;
    } catch (e) {
      LogUtils.eTag(TAG, 'getDefaultDisplaySync failed: ' + JSON.stringify(e));
      return 288;
    }
  }

  /**
   * Confirm dialog. `content` undefined → title only; `confirm`/`cancel` undefined → `确定`/`取消`.
   * `onCancel` is called after the cancel cell closes the dialog; `showCancel=false` hides that cell.
   * `okColor` undefined → theme primary.
   */
  static showConfirm(uiCtx: UIContext, title: ResourceStr, content: ResourceStr | undefined,
    confirm: ResourceStr | undefined, cancel: ResourceStr | undefined, onConfirm: () => void,
    onCancel?: () => void, okColor?: ResourceColor, showCancel: boolean = true): void {
    const params: ConfirmDialogParams = new ConfirmDialogParams();
    params.dialogTitle = title;
    params.dialogContent = content;
    if (confirm !== undefined) {
      params.okText = confirm;
    }
    if (cancel !== undefined) {
      params.cancelText = cancel;
    }
    params.okColor = okColor;
    params.showCancel = showCancel;
    params.dialogWidth = DialogHelper.dialogWidthVp(uiCtx);

    let node: ComponentContent<ConfirmDialogParams> | null = null;
    let closed: boolean = false;
    const close = (): void => {
      if (closed || node === null) {
        return;
      }
      closed = true;
      uiCtx.getPromptAction().closeCustomDialog(node).catch((err: BusinessError) => {
        LogUtils.eTag(TAG, 'closeCustomDialog failed: ' + err.code + ' ' + err.message);
      });
    };
    params.onOk = (): void => {
      close();
      onConfirm();
    };
    params.onCancel = (): void => {
      close();
      if (onCancel !== undefined) {
        onCancel();
      }
    };

    node = new ComponentContent<ConfirmDialogParams>(uiCtx, wrapBuilder<[ConfirmDialogParams]>(confirmDialogBuilder),
      params);
    const opened: ComponentContent<ConfirmDialogParams> = node;
    uiCtx.getPromptAction().openCustomDialog(opened, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      maskColor: $r('app.color.mask'),
      onDidDisappear: (): void => {
        closed = true;
        opened.dispose();
      }
    }).catch((err: BusinessError) => {
      LogUtils.eTag(TAG, 'openCustomDialog failed: ' + err.code + ' ' + err.message);
      opened.dispose();
    });
  }
}
