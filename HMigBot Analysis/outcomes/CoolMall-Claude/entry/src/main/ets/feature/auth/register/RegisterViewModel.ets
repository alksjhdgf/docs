/**
 * RegisterViewModel (source: feature/auth/viewmodel/RegisterViewModel.kt).
 * - isRegisterEnabled = valid phone && 4-digit sms code && password length >= 6 && password == confirmPassword.
 * - onSendCodeButtonClick (after the page obtained notification permission): invalid phone → toast
 *   `请输入正确的手机号`; else fetch GET user/login/captcha and show the `安全验证` sheet.
 * - onImageCodeConfirm(code): hide sheet + clear image code, POST user/login/smsCode {phone, captchaId, code};
 *   the returned code is posted as a local notification.
 * - register(): validates in order (`请输入正确的手机号` / `请输入4位验证码` / `请输入正确的密码` /
 *   `两次输入的密码不一致`), then POST user/login/register {phone, smsCode, password, confirmPassword};
 *   success → `注册成功`, updateAuth (persist + logged in), refreshUserInfo, navigateBack() once.
 */
import { Auth } from '../../../core/model/Auth';
import { Captcha } from '../../../core/model/Market';
import { AuthRepository } from '../../../core/data/repository/AuthRepository';
import { AppState } from '../../../core/data/AppState';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';
import { NotificationUtil } from '../../../core/util/NotificationUtil';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { ValidationUtil } from '../../../core/util/ValidationUtil';

@ObservedV2
export class RegisterViewModel {
  @Trace phone: string = '';
  @Trace password: string = '';
  @Trace confirmPassword: string = '';
  @Trace verificationCode: string = '';
  @Trace showImageCodePopup: boolean = false;
  /** Captcha.data (base64 image) */
  @Trace captchaData: string = '';
  /** Captcha.captchaId */
  @Trace captchaId: string = '';
  @Trace imageCode: string = '';
  /** Collected but not rendered in source */
  @Trace isLoadingCaptcha: boolean = false;
  private alive: boolean = true;

  dispose(): void {
    this.alive = false;
  }

  isPhoneValid(): boolean {
    return ValidationUtil.isValidPhone(this.phone);
  }

  isRegisterEnabled(): boolean {
    return ValidationUtil.isValidPhone(this.phone) &&
      ValidationUtil.isValidSmsCode(this.verificationCode) &&
      ValidationUtil.isValidPassword(this.password) &&
      this.password === this.confirmPassword;
  }

  updatePhone(value: string): void {
    this.phone = value;
  }

  updatePassword(value: string): void {
    this.password = value;
  }

  updateConfirmPassword(value: string): void {
    this.confirmPassword = value;
  }

  updateVerificationCode(value: string): void {
    this.verificationCode = value;
  }

  updateImageCode(value: string): void {
    this.imageCode = value;
  }

  onSendCodeButtonClick(): void {
    if (!ValidationUtil.isValidPhone(this.phone)) {
      ToastUtils.showError($r('app.string.invalid_phone_number'));
      return;
    }
    this.isLoadingCaptcha = true;
    this.fetchCaptcha();
    this.isLoadingCaptcha = false;
    this.showImageCodePopup = true;
  }

  onHideImageCodePopup(): void {
    this.showImageCodePopup = false;
    this.imageCode = '';
  }

  onImageCodeConfirm(imageCode: string): void {
    this.updateImageCode(imageCode);
    this.sendVerificationCode();
  }

  sendVerificationCode(): void {
    const currentImageCode: string = this.imageCode;
    this.onHideImageCodePopup();
    const params: Record<string, string> = {
      'phone': this.phone,
      'captchaId': this.captchaId,
      'code': currentImageCode
    };
    const opts: ResultHandleOptions<string> = {
      onSuccess: (smsCode: string): void => {
        NotificationUtil.sendVerificationCodeNotification(String(smsCode));
      }
    };
    ResultHandler.handleAsync<string>(AuthRepository.getSmsCode(params), opts);
  }

  /** Refresh the captcha (image tap / `点击刷新`) */
  getCaptcha(): void {
    this.isLoadingCaptcha = true;
    this.fetchCaptcha();
    this.isLoadingCaptcha = false;
  }

  private fetchCaptcha(): void {
    const opts: ResultHandleOptions<Captcha> = {
      onSuccess: (captcha: Captcha): void => {
        if (!this.alive) {
          return;
        }
        this.captchaData = captcha?.data ?? '';
        this.captchaId = captcha?.captchaId !== undefined && captcha?.captchaId !== null ?
          String(captcha.captchaId) : '';
      }
    };
    ResultHandler.handleAsync<Captcha>(AuthRepository.getCaptcha(), opts);
  }

  register(): void {
    if (!ValidationUtil.isValidPhone(this.phone)) {
      ToastUtils.showError($r('app.string.invalid_phone_number'));
      return;
    }
    if (!ValidationUtil.isValidSmsCode(this.verificationCode)) {
      ToastUtils.showError($r('app.string.invalid_verification_code'));
      return;
    }
    if (!ValidationUtil.isValidPassword(this.password)) {
      ToastUtils.showError($r('app.string.invalid_password'));
      return;
    }
    if (this.password !== this.confirmPassword) {
      ToastUtils.showError($r('app.string.password_mismatch'));
      return;
    }
    const params: Record<string, string> = {
      'phone': this.phone,
      'smsCode': this.verificationCode,
      'password': this.password,
      'confirmPassword': this.confirmPassword
    };
    const opts: ResultHandleOptions<Auth> = {
      onSuccess: (authData: Auth): void => {
        if (this.alive) {
          this.registerSuccess(authData);
        }
      }
    };
    ResultHandler.handleAsync<Auth>(AuthRepository.register(params), opts);
  }

  private async registerSuccess(authData: Auth): Promise<void> {
    const auth: Auth = Auth.from(authData);
    ToastUtils.showSuccess($r('app.string.register_success'));
    await AppState.instance.updateAuth(auth);
    AppState.instance.refreshUserInfo();
    AppNavigator.back();
  }
}
