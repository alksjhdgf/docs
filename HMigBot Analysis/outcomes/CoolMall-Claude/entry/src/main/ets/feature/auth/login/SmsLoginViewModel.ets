/**
 * SmsLoginViewModel (source: feature/auth/viewmodel/SmsLoginViewModel.kt).
 * - Prefills `saved_phone`.
 * - onSendCodeButtonClick (after the page obtained notification permission): invalid phone → toast
 *   `请输入正确的手机号`; else fetch GET user/login/captcha (fire-and-forget) and show the `安全验证` sheet at once.
 * - onImageCodeConfirm(code): hide sheet + clear image code, POST user/login/smsCode {phone, captchaId, code};
 *   the returned code is posted as the high-priority notification `验证码` / `您的验证码是: <code>`.
 * - login(): `请输入正确的手机号` / `请输入4位验证码`; POST user/login/phone {phone, smsCode};
 *   success → save phone, `登录成功`, updateAuth, refreshUserInfo, pop twice.
 */
import { Auth } from '../../../core/model/Auth';
import { Captcha } from '../../../core/model/Market';
import { AuthRepository } from '../../../core/data/repository/AuthRepository';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';
import { KvKeys, KvStore } from '../../../core/storage/KvStore';
import { NotificationUtil } from '../../../core/util/NotificationUtil';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { ValidationUtil } from '../../../core/util/ValidationUtil';
import { LoginSuccessHandler } from './LoginSuccessHandler';

@ObservedV2
export class SmsLoginViewModel {
  @Trace phone: string = '';
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

  constructor() {
    this.loadSavedPhone();
  }

  dispose(): void {
    this.alive = false;
  }

  isPhoneValid(): boolean {
    return ValidationUtil.isValidPhone(this.phone);
  }

  isLoginEnabled(): boolean {
    return ValidationUtil.isValidPhone(this.phone) && ValidationUtil.isValidSmsCode(this.verificationCode);
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

  updatePhone(value: string): void {
    this.phone = value;
  }

  updateVerificationCode(value: string): void {
    this.verificationCode = value;
  }

  updateImageCode(value: string): void {
    this.imageCode = value;
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
        // The demo backend returns the code itself: deliver it as a local notification
        NotificationUtil.sendVerificationCodeNotification(String(smsCode));
      }
    };
    ResultHandler.handleAsync<string>(AuthRepository.getSmsCode(params), opts);
  }

  login(): void {
    if (!ValidationUtil.isValidPhone(this.phone)) {
      ToastUtils.showError($r('app.string.invalid_phone_number'));
      return;
    }
    if (!ValidationUtil.isValidSmsCode(this.verificationCode)) {
      ToastUtils.showError($r('app.string.invalid_verification_code'));
      return;
    }
    const params: Record<string, string> = {
      'phone': this.phone,
      'smsCode': this.verificationCode
    };
    const opts: ResultHandleOptions<Auth> = {
      onSuccess: (authData: Auth): void => {
        if (this.alive) {
          this.loginSuccess(authData);
        }
      }
    };
    ResultHandler.handleAsync<Auth>(AuthRepository.loginByPhone(params), opts);
  }

  private loginSuccess(authData: Auth): void {
    this.savePhone(this.phone);
    LoginSuccessHandler.complete(authData, 2);
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
        // J2: parsed JSON may miss fields
        this.captchaData = captcha?.data ?? '';
        this.captchaId = captcha?.captchaId !== undefined && captcha?.captchaId !== null ?
          String(captcha.captchaId) : '';
      }
    };
    ResultHandler.handleAsync<Captcha>(AuthRepository.getCaptcha(), opts);
  }

  private loadSavedPhone(): void {
    if (!KvStore.isInitialized()) {
      return;
    }
    const savedPhone: string = KvStore.getString(KvKeys.SAVED_PHONE, '');
    if (savedPhone.length > 0) {
      this.phone = savedPhone;
    }
  }

  private savePhone(phone: string): void {
    KvStore.putString(KvKeys.SAVED_PHONE, phone);
  }
}
