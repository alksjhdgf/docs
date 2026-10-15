/**
 * AddressDeleteDialog — delete confirmation of the address list (source: AddressListScreen.kt
 * `if (showDeleteDialog && deleteId != null) WeDialog(...)`).
 *
 * Title `删除地址`, content `确认删除该地址吗？`, ok `确认`, cancel `取消` (USER-A13).
 * Unlike DialogHelper.showConfirm (close-on-action), the source dialog stays open after `确认` until the
 * delete succeeds (viewModel.hideDeleteDialog()), so the page owns visibility: open() shows it,
 * close() hides it when AddressListViewModel.showDeleteDialog turns false. Mask tap / back → onDismiss
 * (source onDismiss = hideDeleteDialog).
 */
import { ComponentContent, display, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { WeDialog } from '../../../core/ui/widget/Dialog';
import { LogUtils } from '../../../core/util/LogUtils';

const TAG: string = 'AddressDeleteDialog';
/** Fallback dialog width (vp) when the display cannot be queried */
const DEFAULT_DIALOG_WIDTH: number = 288;

/** ComponentContent arguments (plain class) */
class AddressDeleteDialogArgs {
  dialogWidth: number = DEFAULT_DIALOG_WIDTH;
  onOk: () => void = () => {
  };
  onCancel: () => void = () => {
  };
}

@Builder
function addressDeleteDialogBuilder(args: AddressDeleteDialogArgs) {
  WeDialog({
    dialogTitle: $r('app.string.delete_address'),
    dialogContent: $r('app.string.delete_address_confirm'),
    okText: $r('app.string.ok'),
    cancelText: $r('app.string.cancel'),
    showCancel: true,
    dialogWidth: args.dialogWidth,
    onOk: (): void => args.onOk(),
    onCancel: (): void => args.onCancel()
  })
}

export class AddressDeleteDialog {
  private uiCtx: UIContext;
  private node: ComponentContent<AddressDeleteDialogArgs> | null = null;
  private onDismissCb: () => void;

  /**
   * @param uiCtx page UIContext
   * @param onDismiss called when the dialog disappears without the page closing it (mask / back)
   */
  constructor(uiCtx: UIContext, onDismiss: () => void) {
    this.uiCtx = uiCtx;
    this.onDismissCb = onDismiss;
  }

  isOpen(): boolean {
    return this.node !== null;
  }

  /** Show the dialog; `onOk` → delete, `onCancel` → hide */
  open(onOk: () => void, onCancel: () => void): void {
    if (this.node !== null) {
      return;
    }
    const args: AddressDeleteDialogArgs = new AddressDeleteDialogArgs();
    args.dialogWidth = this.dialogWidthVp();
    args.onOk = onOk;
    args.onCancel = onCancel;
    const node: ComponentContent<AddressDeleteDialogArgs> = new ComponentContent<AddressDeleteDialogArgs>(
      this.uiCtx, wrapBuilder<[AddressDeleteDialogArgs]>(addressDeleteDialogBuilder), args);
    this.node = node;
    this.uiCtx.getPromptAction().openCustomDialog(node, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      maskColor: $r('app.color.mask'),
      onDidDisappear: (): void => {
        const wasOpen: boolean = this.node === node;
        if (wasOpen) {
          this.node = null;
        }
        node.dispose();
        if (wasOpen) {
          // Dismissed by mask / back, not by close()
          this.onDismissCb();
        }
      }
    }).catch((err: BusinessError) => {
      LogUtils.eTag(TAG, 'openCustomDialog failed: ' + err.code + ' ' + err.message);
      if (this.node === node) {
        this.node = null;
      }
      node.dispose();
    });
  }

  /** Hide the dialog (no onDismiss callback) */
  close(): void {
    const node: ComponentContent<AddressDeleteDialogArgs> | null = this.node;
    if (node === null) {
      return;
    }
    this.node = null;
    this.uiCtx.getPromptAction().closeCustomDialog(node).catch((err: BusinessError) => {
      LogUtils.eTag(TAG, 'closeCustomDialog failed: ' + err.code + ' ' + err.message);
    });
  }

  /** Source fillMaxWidth(0.8f) of the window */
  private dialogWidthVp(): number {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      return this.uiCtx.px2vp(d.width) * 0.8;
    } catch (e) {
      LogUtils.eTag(TAG, 'getDefaultDisplaySync failed: ' + JSON.stringify(e));
      return DEFAULT_DIALOG_WIDTH;
    }
  }
}
