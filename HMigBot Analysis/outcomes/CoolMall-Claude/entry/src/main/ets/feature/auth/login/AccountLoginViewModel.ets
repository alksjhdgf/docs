/**
 * AccountLoginViewModel (source: feature/auth/viewmodel/AccountLoginViewModel.kt).
 * - Prefills `saved_phone` / `saved_password` (KV) on creation.
 * - isLoginEnabled = valid phone && password length >= 6.
 * - login(): `请输入正确的手机号` / `请输入正确的密码` toasts without a request; else POST user/login/password
 *   {phone, password}; success → save phone + password (plaintext, as in source), `登录成功`, updateAuth,
 *   refreshUserInfo, pop twice. Failures: ResultHandler error toast (backend message / `网络请求失败`).
 */
import { Auth } from '../../../core/model/Auth';
import { AuthRepository } from '../../../core/data/repository/AuthRepository';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';
import { KvKeys, KvStore } from '../../../core/storage/KvStore';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { ValidationUtil } from '../../../core/util/ValidationUtil';
import { LoginSuccessHandler } from './LoginSuccessHandler';

@ObservedV2
export class AccountLoginViewModel {
  @Trace account: string = '';
  @Trace password: string = '';
  private alive: boolean = true;

  constructor() {
    this.loadSavedCredentials();
  }

  dispose(): void {
    this.alive = false;
  }

  isLoginEnabled(): boolean {
    return ValidationUtil.isValidPhone(this.account) && ValidationUtil.isValidPassword(this.password);
  }

  updateAccount(value: string): void {
    this.account = value;
  }

  updatePassword(value: string): void {
    this.password = value;
  }

  login(): void {
    if (!ValidationUtil.isValidPhone(this.account)) {
      ToastUtils.showError($r('app.string.invalid_phone_number'));
      return;
    }
    if (!ValidationUtil.isValidPassword(this.password)) {
      ToastUtils.showError($r('app.string.invalid_password'));
      return;
    }
    const params: Record<string, string> = {
      'phone': this.account,
      'password': this.password
    };
    const opts: ResultHandleOptions<Auth> = {
      onSuccess: (authData: Auth): void => {
        if (this.alive) {
          this.loginSuccess(authData);
        }
      }
    };
    ResultHandler.handleAsync<Auth>(AuthRepository.loginByPassword(params), opts);
  }

  private loginSuccess(authData: Auth): void {
    this.saveCredentials(this.account, this.password);
    LoginSuccessHandler.complete(authData, 2);
  }

  private loadSavedCredentials(): void {
    if (!KvStore.isInitialized()) {
      return;
    }
    const savedPhone: string = KvStore.getString(KvKeys.SAVED_PHONE, '');
    const savedPassword: string = KvStore.getString(KvKeys.SAVED_PASSWORD, '');
    if (savedPhone.length > 0) {
      this.account = savedPhone;
    }
    if (savedPassword.length > 0) {
      this.password = savedPassword;
    }
  }

  private saveCredentials(phone: string, password: string): void {
    KvStore.putString(KvKeys.SAVED_PHONE, phone);
    KvStore.putString(KvKeys.SAVED_PASSWORD, password);
  }
}
