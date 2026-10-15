/**
 * QQLoginManager (source: core/common/manager/QQLoginManager.kt — Tencent Android SDK singleton whose
 * login result is delivered through MainActivity.onActivityResult → Tencent.onActivityResultData and
 * exposed as a StateFlow<QQLoginResult?> Success / Error / Cancel).
 *
 * DEGRADATION (no_equiv): the Tencent QQ open SDK is not part of the HarmonyOS SDK and is not a dependency
 * of this project, so there is no API to launch QQ authorization. startQQLogin() therefore throws, which the
 * caller turns into the source's `启动QQ登录失败` error toast (source catch branch). The result channel
 * (collect / dispatch / clearLoginResult) is kept with the source semantics so that wiring a SDK later only
 * needs startQQLogin() + a dispatch() call from the SDK listener.
 */
import { common } from '@kit.AbilityKit';

export enum QQLoginResultType {
  SUCCESS,
  ERROR,
  CANCEL
}

/** Source sealed class QQLoginResult { Success(accessToken, openId) / Error(message) / Cancel } */
export class QQLoginResult {
  resultType: QQLoginResultType = QQLoginResultType.CANCEL;
  accessToken: string = '';
  openId: string = '';
  errorMessage: string = '';
}

export type QQLoginListener = (result: QQLoginResult) => void;

/** Error message of the launch failure (technical detail appended to `启动QQ登录失败: %s`) */
export const QQ_SDK_UNAVAILABLE: string = 'QQ OpenSDK unavailable on HarmonyOS';

export class QQLoginManager {
  private static sInstance: QQLoginManager | null = null;
  private listeners: Map<number, QQLoginListener> = new Map<number, QQLoginListener>();
  private nextListenerId: number = 1;
  /** Source _loginResult StateFlow value (null after clearLoginResult) */
  private loginResult: QQLoginResult | null = null;

  static getInstance(): QQLoginManager {
    if (QQLoginManager.sInstance === null) {
      QQLoginManager.sInstance = new QQLoginManager();
    }
    return QQLoginManager.sInstance as QQLoginManager;
  }

  /** Source startQQLogin(activity): tencent.login(activity, "all", listener). Throws: no SDK on HarmonyOS. */
  startQQLogin(ctx: common.UIAbilityContext | undefined): void {
    console.info(`QQLoginManager.startQQLogin: ctx=${ctx !== undefined}`);
    throw new Error(QQ_SDK_UNAVAILABLE);
  }

  /** Source loginResult.collect { } — the current value is replayed like a StateFlow. Returns an id. */
  collect(listener: QQLoginListener): number {
    const id: number = this.nextListenerId++;
    this.listeners.set(id, listener);
    const current: QQLoginResult | null = this.loginResult;
    if (current !== null) {
      listener(current);
    }
    return id;
  }

  /** Stop collecting (source: viewModelScope cancellation) */
  cancelCollect(id: number): void {
    this.listeners.delete(id);
  }

  /** Called by the SDK login listener (onComplete / onError / onCancel) */
  dispatch(result: QQLoginResult): void {
    this.loginResult = result;
    const all: QQLoginListener[] = [];
    this.listeners.forEach((l: QQLoginListener) => {
      all.push(l);
    });
    all.forEach((l: QQLoginListener) => {
      l(result);
    });
  }

  /** Source clearLoginResult(): reset the StateFlow to null */
  clearLoginResult(): void {
    this.loginResult = null;
  }
}
