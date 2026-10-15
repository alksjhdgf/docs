/**
 * LoginViewModel (source: feature/auth/viewmodel/LoginViewModel.kt) — login method selection page.
 * - WeChat / Alipay: warning toast `三方登录暂时仅支持QQ登录`, no login.
 * - QQ: QQLoginManager.startQQLogin; Success → POST user/login/qq {accessToken, openId} → loginSuccess
 *   (`登录成功`, updateAuth, refreshUserInfo, pop once); Error → `登录失败…`; Cancel → warning `登录取消`;
 *   launch exception → `启动QQ登录失败…` (always the case on HarmonyOS, see QQLoginManager).
 */
import { common } from '@kit.AbilityKit';
import { Auth } from '../../../core/model/Auth';
import { QQLoginRequest } from '../../../core/model/Request';
import { AuthRepository } from '../../../core/data/repository/AuthRepository';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { QQLoginManager, QQLoginResult, QQLoginResultType } from './QQLoginManager';
import { LoginSuccessHandler } from './LoginSuccessHandler';

@ObservedV2
export class LoginViewModel {
  private alive: boolean = true;
  private collectIds: number[] = [];
  private ctx: common.UIAbilityContext | undefined = undefined;

  /** Page aboutToDisappear (source viewModelScope cancellation) */
  dispose(): void {
    this.alive = false;
    this.collectIds.forEach((id: number) => {
      QQLoginManager.getInstance().cancelCollect(id);
    });
    this.collectIds = [];
  }

  startQQLogin(ctx: common.UIAbilityContext | undefined): void {
    this.ctx = ctx;
    try {
      QQLoginManager.getInstance().startQQLogin(ctx);
      // Collect login results (source: a new collector per tap)
      const id: number = QQLoginManager.getInstance().collect((result: QQLoginResult) => {
        this.onQQLoginResult(result);
      });
      this.collectIds.push(id);
    } catch (e) {
      const msg: string = (e instanceof Error) ? (e as Error).message : '';
      ToastUtils.showError(LoginSuccessHandler.format(ctx, $r('app.string.start_qq_login_failed'), msg));
    }
  }

  private onQQLoginResult(result: QQLoginResult): void {
    if (!this.alive) {
      return;
    }
    switch (result.resultType) {
      case QQLoginResultType.SUCCESS:
        this.qqLoginSuccess(result.accessToken, result.openId);
        QQLoginManager.getInstance().clearLoginResult();
        break;
      case QQLoginResultType.ERROR:
        ToastUtils.showError(LoginSuccessHandler.format(this.ctx, $r('app.string.login_failed'), result.errorMessage));
        QQLoginManager.getInstance().clearLoginResult();
        break;
      default:
        ToastUtils.showWarning($r('app.string.login_cancelled'));
        QQLoginManager.getInstance().clearLoginResult();
        break;
    }
  }

  private qqLoginSuccess(accessToken: string, openId: string): void {
    const params: QQLoginRequest = new QQLoginRequest();
    params.accessToken = accessToken;
    params.openId = openId;
    const opts: ResultHandleOptions<Auth> = {
      onSuccess: (authData: Auth): void => {
        if (this.alive) {
          this.loginSuccess(authData);
        }
      }
    };
    ResultHandler.handleAsync<Auth>(AuthRepository.loginByQqApp(params), opts);
  }

  /** QQ login success: pop back once (leaves the selection page) */
  loginSuccess(authData: Auth): void {
    LoginSuccessHandler.complete(authData, 1);
  }

  onWechatLoginClick(): void {
    this.onWechatAndAlipayLoginTipClick();
  }

  onAlipayLoginClick(): void {
    this.onWechatAndAlipayLoginTipClick();
  }

  onWechatAndAlipayLoginTipClick(): void {
    ToastUtils.showWarning($r('app.string.third_party_login_only_qq'));
  }
}
