/**
 * ValidationUtil (source: core/util/validation/ValidationUtil.kt) — DATA-A23 / AUTH-A10.
 * Phone: 11 digits matching ^1[3-9]\d{9}$; SMS code: exactly 4 digits;
 * image captcha: exactly 4 letters/digits; password: length >= 6.
 * Source names (isValidXxx) are kept; short aliases (isPhone/isSmsCode/isCaptcha/isPassword) per the work card.
 */
const PHONE_REGEX: RegExp = new RegExp('^1[3-9]\\d{9}$');
const SMS_CODE_REGEX: RegExp = new RegExp('^\\d{4}$');
// Kotlin Char.isDigit/isLetterOrDigit are Unicode-aware; restricted to ASCII here (inputs are ASCII keyboards/captchas).
const IMAGE_CODE_REGEX: RegExp = new RegExp('^[A-Za-z0-9]{4}$');
const EMAIL_REGEX: RegExp = new RegExp('^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$');

export class ValidationUtil {
  static isValidPhone(phone: string): boolean {
    return phone.length === 11 && PHONE_REGEX.test(phone);
  }

  static isValidSmsCode(code: string): boolean {
    return SMS_CODE_REGEX.test(code);
  }

  static isValidImageCode(code: string): boolean {
    return IMAGE_CODE_REGEX.test(code);
  }

  static isValidEmail(email: string): boolean {
    return EMAIL_REGEX.test(email);
  }

  static isValidPassword(password: string): boolean {
    return password.length >= 6;
  }

  // ===== aliases named in the work card =====
  static isPhone(phone: string): boolean {
    return ValidationUtil.isValidPhone(phone);
  }

  static isSmsCode(code: string): boolean {
    return ValidationUtil.isValidSmsCode(code);
  }

  static isCaptcha(code: string): boolean {
    return ValidationUtil.isValidImageCode(code);
  }

  static isPassword(password: string): boolean {
    return ValidationUtil.isValidPassword(password);
  }
}
