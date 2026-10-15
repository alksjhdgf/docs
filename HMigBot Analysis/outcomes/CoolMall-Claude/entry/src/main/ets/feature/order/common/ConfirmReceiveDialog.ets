/**
 * ConfirmReceiveDialog — the `确认收货` dialog of the order list / order detail
 * (source: OrderListScreen / OrderDetailScreen `if (showConfirmDialog) WeDialog(...)`, ORDA-A18/A19).
 *
 * Unlike DialogHelper.showConfirm (close-on-action), the source dialog stays visible until the view model
 * hides it: `确认` only calls confirmReceiveOrder(), which hides the dialog on success; on failure the dialog
 * stays open (error toast from ResultHandler). `取消` / mask tap / back call onDismiss (hideConfirmReceiveDialog).
 *
 *   private receiveDialog: ConfirmReceiveDialog = new ConfirmReceiveDialog();
 *   @Monitor('vm.showConfirmDialog') ... vm.showConfirmDialog ? receiveDialog.open(ctx, ok, dismiss) : receiveDialog.close()
 */
import { ComponentContent, display, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { WeDialog } from '../../../core/ui/widget/Dialog';
import { LogUtils } from '../../../core/util/LogUtils';

const TAG: string = 'ConfirmReceiveDialog';

/** ComponentContent args (plain class snapshot) */
export class ConfirmReceiveDialogArgs {
  dialogWidth: number = 288;
  onOk: () => void = () => {
  };
  onCancel: () => void = () => {
  };
}

@Builder
function confirmReceiveDialogBuilder(args: ConfirmReceiveDialogArgs) {
  WeDialog({
    dialogTitle: $r('app.string.confirm_receipt'),
    dialogContent: $r('app.string.confirm_receipt_message'),
    // feature/order R.string.confirm = 确认 (app.string.ok), R.string.cancel = 取消
    okText: $r('app.string.ok'),
    cancelText: $r('app.string.cancel'),
    dialogWidth: args.dialogWidth,
    onOk: (): void => args.onOk(),
    onCancel: (): void => args.onCancel()
  })
}

export class ConfirmReceiveDialog {
  private node: ComponentContent<ConfirmReceiveDialogArgs> | null = null;
  private uiCtx: UIContext | null = null;

  isOpen(): boolean {
    return this.node !== null;
  }

  /** Open the dialog (no-op when already open). `onDismiss` runs for 取消 / mask / back. */
  open(uiCtx: UIContext, onOk: () => void, onDismiss: () => void): void {
    if (this.node !== null) {
      return;
    }
    const args: ConfirmReceiveDialogArgs = new ConfirmReceiveDialogArgs();
    args.dialogWidth = ConfirmReceiveDialog.dialogWidthVp(uiCtx);
    args.onOk = (): void => {
      onOk();
    };
    args.onCancel = (): void => {
      onDismiss();
    };
    const node: ComponentContent<ConfirmReceiveDialogArgs> =
      new ComponentContent<ConfirmReceiveDialogArgs>(uiCtx, wrapBuilder<[ConfirmReceiveDialogArgs]>(
        confirmReceiveDialogBuilder), args);
    this.node = node;
    this.uiCtx = uiCtx;
    uiCtx.getPromptAction().openCustomDialog(node, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      maskColor: $r('app.color.mask'),
      onDidDisappear: (): void => {
        const wasCurrent: boolean = this.node === node;
        if (wasCurrent) {
          this.node = null;
          this.uiCtx = null;
        }
        node.dispose();
        if (wasCurrent) {
          // Mask tap / back (source onDismissRequest = hideConfirmReceiveDialog)
          onDismiss();
        }
      }
    }).catch((err: BusinessError) => {
      LogUtils.eTag(TAG, 'openCustomDialog failed: ' + err.code + ' ' + err.message);
      if (this.node === node) {
        this.node = null;
        this.uiCtx = null;
      }
      node.dispose();
    });
  }

  /** Close the dialog if open (called when the view model hides it) */
  close(): void {
    const node: ComponentContent<ConfirmReceiveDialogArgs> | null = this.node;
    const ctx: UIContext | null = this.uiCtx;
    this.node = null;
    this.uiCtx = null;
    if (node === null || ctx === null) {
      return;
    }
    ctx.getPromptAction().closeCustomDialog(node).catch((err: BusinessError) => {
      LogUtils.eTag(TAG, 'closeCustomDialog failed: ' + err.code + ' ' + err.message);
    });
  }

  /** Source WeDialog width = 80% of the window */
  private static dialogWidthVp(uiCtx: UIContext): number {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      return uiCtx.px2vp(d.width) * 0.8;
    } catch (e) {
      LogUtils.eTag(TAG, 'getDefaultDisplaySync failed: ' + JSON.stringify(e));
      return 288;
    }
  }
}
