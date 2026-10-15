/**
 * Shared success / formatting helpers of the login view models (source LoginViewModel / AccountLoginViewModel /
 * SmsLoginViewModel loginSuccess bodies).
 */
import { common } from '@kit.AbilityKit';
import { Auth } from '../../../core/model/Auth';
import { AppState } from '../../../core/data/AppState';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ToastUtils } from '../../../core/util/ToastUtils';

export class LoginSuccessHandler {
  /**
   * ToastUtils.showSuccess(login_success) → appState.updateAuth(auth) (persist `auth_info` + isLoggedIn = true)
   * → appState.refreshUserInfo() → navigateBack() × popCount.
   * The server Auth has no createdAt: Auth.from() stamps it with the local time (source default value).
   */
  static async complete(authData: Auth, popCount: number): Promise<void> {
    const auth: Auth = Auth.from(authData);
    ToastUtils.showSuccess($r('app.string.login_success'));
    await AppState.instance.updateAuth(auth);
    AppState.instance.refreshUserInfo();
    for (let i = 0; i < popCount; i++) {
      AppNavigator.back();
    }
  }

  /** Format a `%s` string resource; falls back to the raw resource when no context is available. */
  static format(ctx: common.Context | undefined, res: Resource, arg: string): ResourceStr {
    if (ctx === undefined) {
      return res;
    }
    try {
      return ctx.resourceManager.getStringSync(res, arg);
    } catch (e) {
      console.error(`LoginSuccessHandler.format failed: ${(e as Error).message}`);
      return res;
    }
  }
}
