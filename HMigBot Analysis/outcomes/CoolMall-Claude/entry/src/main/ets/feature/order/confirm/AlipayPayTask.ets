/**
 * AlipayPayTask — HarmonyOS counterpart of the Alipay SDK `PayTask(activity).payV2(orderInfo, true)` used by
 * OrderPayScreen.kt (ORDB-A18).
 *
 * Uses the official Alipay cashier SDK for HarmonyOS, `@cashier_alipay/cashiersdk` (the adjudicated equivalent of
 * com.alipay.sdk:alipaysdk-android, spec/feasibility.json): `new Pay().pay(orderInfo, true)` launches the
 * Alipay app when installed (module.json5 querySchemes `alipay`/`alipays`), otherwise the SDK's H5 cashier, and
 * resolves with the same result map as Android (`resultStatus` / `memo` / `result`), so the source result
 * handling (Alipay / OrderPayViewModel.processAlipayResult: 9000 / 6001 / other) is unchanged.
 * An SDK exception (no result map) is mapped to resultStatus "4000" (Alipay "order payment failed").
 */
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Pay } from '@cashier_alipay/cashiersdk';
import { LogUtils } from '../../../core/util/LogUtils';

const TAG: string = 'AlipayPayTask';
/** Alipay resultStatus for "order payment failed" */
const STATUS_FAILED: string = '4000';

export class AlipayPayTask {
  /**
   * Source: `PayTask(activity).payV2(orderInfo, true)` run off the main thread.
   * @param context kept for signature compatibility with the caller (the SDK resolves its own context)
   * @param orderInfo signed orderString from order/pay/alipayAppPay
   */
  static async payV2(context: common.UIAbilityContext, orderInfo: string): Promise<Map<string, string>> {
    try {
      const result: Map<string, string> = await new Pay().pay(orderInfo, true);
      LogUtils.iTag(TAG, 'pay result resultStatus=' + (result.get('resultStatus') ?? '') + ' memo=' + (result.get('memo') ?? ''));
      return result;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      LogUtils.eTag(TAG, 'pay failed: ' + (err?.code ?? '') + ' ' + (err?.message ?? ''));
      const failed: Map<string, string> = new Map<string, string>();
      failed.set('resultStatus', STATUS_FAILED);
      failed.set('memo', err?.message ?? '');
      failed.set('result', '');
      return failed;
    }
  }
}
