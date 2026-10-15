/**
 * ResetPasswordViewModel (source: feature/auth/viewmodel/ResetPasswordViewModel.kt).
 * Holds the four inputs only. sendVerificationCode() / resetPassword() are empty stubs in the source
 * (no request is made); kept as stubs here.
 */
@ObservedV2
export class ResetPasswordViewModel {
  @Trace phone: string = '';
  @Trace newPassword: string = '';
  @Trace confirmPassword: string = '';
  @Trace verificationCode: string = '';

  updatePhone(value: string): void {
    this.phone = value;
  }

  updateNewPassword(value: string): void {
    this.newPassword = value;
  }

  updateConfirmPassword(value: string): void {
    this.confirmPassword = value;
  }

  updateVerificationCode(value: string): void {
    this.verificationCode = value;
  }

  /** Source: empty implementation ("实现发送验证码逻辑" TODO) — no request */
  sendVerificationCode(): void {
    console.info('TODO:sendVerificationCode:ResetPasswordViewModel (source stub)');
  }

  /** Source: empty implementation ("实现实际重置密码逻辑" TODO) — no request */
  resetPassword(): void {
    console.info('TODO:resetPassword:ResetPasswordViewModel (source stub)');
  }

  /** Source: newPassword.isNotEmpty() && confirmPassword.isNotEmpty() && newPassword != confirmPassword */
  isPasswordMismatch(): boolean {
    return this.newPassword.length > 0 && this.confirmPassword.length > 0 &&
      this.newPassword !== this.confirmPassword;
  }
}
