/**
 * OrderButtons (source: feature/order/component/OrderButtons.kt) — order action buttons by status,
 * shared by the order list card and the order detail bottom bar (ORDA-A14).
 *
 * Rules (OrderButtonRules):
 *   status 0          → `取消订单` + `去支付`(primary)
 *   status 1 / 2      → `售后/退款`
 *   status 2          → `确认收货`
 *   status 2..6       → `查看物流` (primary when status == 2)
 *   status 3 / 4      → `去评价`
 *   status != 0 && 2  → `再次购买`(primary)   (status 7 → only `再次购买`)
 * Spacing copies the source SpaceHorizontalSmall (8vp) placement exactly, including the trailing spacer
 * after refund / confirm / logistics / comment.
 *
 * The root is a wrap-content Row; place it in the caller's end-aligned row (source EndRow).
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { AppButtonBordered, AppButtonType } from '../../../core/ui/widget/Buttons';

/** Source OrderButton height = 30.dp */
const ORDER_BUTTON_HEIGHT: number = 30;

export class OrderButtonRules {
  static showCancel(status: number): boolean {
    return status === 0;
  }

  static showPay(status: number): boolean {
    return status === 0;
  }

  static showRefund(status: number): boolean {
    return status === 1 || status === 2;
  }

  static showConfirm(status: number): boolean {
    return status === 2;
  }

  static showLogistics(status: number): boolean {
    return status === 2 || status === 3 || status === 4 || status === 5 || status === 6;
  }

  static logisticsPrimary(status: number): boolean {
    return status === 2;
  }

  static showComment(status: number): boolean {
    return status === 3 || status === 4;
  }

  static showRebuy(status: number): boolean {
    return status !== 0 && status !== 2;
  }
}

@ComponentV2
export struct OrderButtons {
  /** Order status (source order.status) */
  @Param orderStatus: number = 0;
  @Event onCancelClick: () => void = () => {
  };
  @Event onPayClick: () => void = () => {
  };
  @Event onRefundClick: () => void = () => {
  };
  @Event onConfirmClick: () => void = () => {
  };
  @Event onLogisticsClick: () => void = () => {
  };
  @Event onCommentClick: () => void = () => {
  };
  @Event onRebuyClick: () => void = () => {
  };

  /** Non-primary color: colorScheme.onSurface @ 0.85 */
  private secondaryColor(): string {
    return ThemeManager.instance.isDark ? '#D9D1D1D1' : '#D9181818';
  }

  /** Source OrderButton: AppButtonBordered(type DEFAULT, color null|onSurface@0.85, height 30, bodySmall) */
  @Builder
  orderButton(text: ResourceStr, isPrimary: boolean, trailingSpace: boolean, action: () => void) {
    Row() {
      AppButtonBordered({
        btnText: text,
        btnType: AppButtonType.DEFAULT,
        customColor: isPrimary ? undefined : this.secondaryColor(),
        btnHeight: ORDER_BUTTON_HEIGHT,
        btnFontSize: Dimens.fontBodySmall,
        onBtnClick: () => {
          action();
        }
      })
    }
    .margin({ right: trailingSpace ? Dimens.spaceHorizontalSmall : 0 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Row() {
      if (OrderButtonRules.showCancel(this.orderStatus)) {
        this.orderButton($r('app.string.cancel_order'), false, true, () => {
          this.onCancelClick();
        })
      }
      if (OrderButtonRules.showPay(this.orderStatus)) {
        this.orderButton($r('app.string.pay_now'), true, false, () => {
          this.onPayClick();
        })
      }
      if (OrderButtonRules.showRefund(this.orderStatus)) {
        this.orderButton($r('app.string.order_refund_button'), false, true, () => {
          this.onRefundClick();
        })
      }
      if (OrderButtonRules.showConfirm(this.orderStatus)) {
        this.orderButton($r('app.string.confirm_receive'), false, true, () => {
          this.onConfirmClick();
        })
      }
      if (OrderButtonRules.showLogistics(this.orderStatus)) {
        this.orderButton($r('app.string.view_logistics'), OrderButtonRules.logisticsPrimary(this.orderStatus), true,
          () => {
            this.onLogisticsClick();
          })
      }
      if (OrderButtonRules.showComment(this.orderStatus)) {
        this.orderButton($r('app.string.comment_now'), false, true, () => {
          this.onCommentClick();
        })
      }
      if (OrderButtonRules.showRebuy(this.orderStatus)) {
        this.orderButton($r('app.string.rebuy_now'), true, false, () => {
          this.onRebuyClick();
        })
      }
    }
    // Buttons laid out left to right; the caller's EndRow puts the group at the end
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }
}
