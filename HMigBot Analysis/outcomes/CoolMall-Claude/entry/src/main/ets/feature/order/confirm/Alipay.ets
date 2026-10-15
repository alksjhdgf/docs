/**
 * Alipay — Alipay payment result parsing (source: feature/order/model/Alipay.kt).
 *
 * Built from the raw result map (keys `resultStatus` / `result` / `memo`, as returned by the Alipay
 * PayTask.payV2 on Android; on HarmonyOS the map is produced by AlipayPayTask.payV2).
 * RESULT_STATUS_SUCCESS = "9000", RESULT_STATUS_CANCEL = "6001"; anything else is a failure (ORDB-A19).
 */
export class Alipay {
  static readonly RESULT_STATUS_SUCCESS: string = '9000';
  static readonly RESULT_STATUS_CANCEL: string = '6001';

  /** the resultStatus */
  resultStatus: string | null = null;
  /** the result */
  result: string | null = null;
  /** the memo */
  memo: string | null = null;

  constructor(rawResult: Map<string, string>) {
    if (rawResult.size > 0) {
      rawResult.forEach((value: string, key: string) => {
        if (key === 'resultStatus') {
          this.resultStatus = value;
        } else if (key === 'result') {
          this.result = value;
        } else if (key === 'memo') {
          this.memo = value;
        }
      });
    }
  }

  toString(): string {
    return 'resultStatus={' + this.resultStatus + '};memo={' + this.memo + '};result={' + this.result + '}';
  }
}
