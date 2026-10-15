/**
 * OrderPayViewModel (source: feature/order/viewmodel/OrderPayViewModel.kt + the PayTask LaunchedEffect of
 * OrderPayScreen.kt) — ORDB-A17~A20.
 *
 * - startAlipayPayment: order/pay/alipayAppPay({orderId}) → orderString (error toast on failure), then the
 *   Alipay cashier is launched off the UI flow (AlipayPayTask.payV2) and its result map is processed.
 * - processAlipayResult: `9000` → `支付成功`, `6001` → `支付已取消`, else `支付失败`, then handleBackAfterPayment.
 * - handleBackAfterPayment: from == "confirm" → back + open OrderDetail(orderId); otherwise success →
 *   back with RefreshResult(refresh = true), failure / cancel / back → plain back.
 */
import { common } from '@kit.AbilityKit';
import { Routes } from '../../../common/Router';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { OrderDetailParam, OrderPayParam } from '../../../core/navigation/RouteParams';
import { ResultHandler } from '../../../core/network/ResultHandler';
import { LogUtils } from '../../../core/util/LogUtils';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { Alipay } from './Alipay';
import { AlipayPayTask } from './AlipayPayTask';

const TAG: string = 'OrderPayViewModel';

@ObservedV2
export class OrderPayViewModel {
  /** Route params (source orderPayRoute) */
  @Trace orderPayRoute: OrderPayParam = new OrderPayParam();
  /** Alipay orderString (source alipayPayInfo) */
  @Trace alipayPayInfo: string = '';
  /** A payment is being launched / in progress */
  @Trace paying: boolean = false;

  private disposed: boolean = false;

  setRoute(param: OrderPayParam): void {
    const p: OrderPayParam = new OrderPayParam(param.orderId ?? 0, param.price ?? 0, param.from ?? null);
    this.orderPayRoute = p;
  }

  /** Request the Alipay orderString and launch the payment (source startAlipayPayment + LaunchedEffect) */
  startAlipayPayment(context: common.UIAbilityContext | null): void {
    if (this.paying) {
      return;
    }
    const params: Record<string, number> = { 'orderId': this.orderPayRoute.orderId };
    ResultHandler.handleAsync<string>(OrderRepository.alipayAppPay(params), {
      showToast: true,
      onSuccess: (data: string): void => {
        if (this.disposed) {
          return;
        }
        this.alipayPayInfo = data;
        if (data.trim().length > 0) {
          this.launchAlipay(context, data);
        }
      }
    });
  }

  /** PayTask(activity).payV2(orderInfo, true) on a background dispatcher → processAlipayResult */
  private async launchAlipay(context: common.UIAbilityContext | null, orderInfo: string): Promise<void> {
    if (context === null) {
      LogUtils.eTag(TAG, 'no UIAbilityContext, cannot launch Alipay');
      const failed: Map<string, string> = new Map<string, string>();
      failed.set('resultStatus', '4000');
      this.processAlipayResult(failed);
      return;
    }
    this.paying = true;
    const result: Map<string, string> = await AlipayPayTask.payV2(context, orderInfo);
    this.paying = false;
    if (this.disposed) {
      return;
    }
    this.processAlipayResult(result);
  }

  /** Map the Alipay result (ORDB-A19) */
  processAlipayResult(param: Map<string, string>): void {
    const result: Alipay = new Alipay(param);
    LogUtils.iTag(TAG, 'alipay result: ' + result.toString());
    if (result.resultStatus === Alipay.RESULT_STATUS_CANCEL) {
      ToastUtils.showError($r('app.string.payment_cancel'));
      this.handleBackAfterPayment(false);
    } else if (result.resultStatus === Alipay.RESULT_STATUS_SUCCESS) {
      ToastUtils.showSuccess($r('app.string.payment_success'));
      this.handleBackAfterPayment(true);
    } else {
      ToastUtils.showError($r('app.string.payment_failed'));
      this.handleBackAfterPayment(false);
    }
  }

  /** Title-bar back and system back (source handleBackClick) */
  handleBackClick(): void {
    this.handleBackAfterPayment(false);
  }

  private handleBackAfterPayment(isPaySuccess: boolean): void {
    if (this.disposed) {
      return;
    }
    if (this.orderPayRoute.from === 'confirm') {
      // Back to the page before the (closed) confirm page, then open the order detail
      AppNavigator.back();
      AppNavigator.navigate(Routes.ORDER_ROUTES_DETAIL, new OrderDetailParam(this.orderPayRoute.orderId));
    } else if (isPaySuccess) {
      AppNavigator.backWithRefresh();
    } else {
      AppNavigator.back();
    }
  }

  dispose(): void {
    this.disposed = true;
  }
}
