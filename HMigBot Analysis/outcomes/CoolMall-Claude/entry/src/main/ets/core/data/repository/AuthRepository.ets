/**
 * AuthRepository (source: core/data/repository/AuthRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse } from '../../model/Response';
import { Auth } from '../../model/Auth';
import { Captcha } from '../../model/Market';
import { QQLoginRequest } from '../../model/Request';
import { AuthService } from '../../network/service/AuthService';

export class AuthRepository {
  /** user/login/wxApp (unused) */
  static loginByWxApp(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return AuthService.loginByWxApp(params);
  }

  /** user/login/qq */
  static loginByQqApp(params: QQLoginRequest): Promise<NetworkResponse<Auth>> {
    return AuthService.loginByQqApp(params);
  }

  /** user/login/register */
  static register(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return AuthService.register(params);
  }

  /** user/login/smsCode */
  static getSmsCode(params: Record<string, string>): Promise<NetworkResponse<string>> {
    return AuthService.getSmsCode(params);
  }

  /** user/login/refreshToken (unused) */
  static refreshToken(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return AuthService.refreshToken(params);
  }

  /** user/login/phone */
  static loginByPhone(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return AuthService.loginByPhone(params);
  }

  /** user/login/password */
  static loginByPassword(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return AuthService.loginByPassword(params);
  }

  /** user/login/captcha */
  static getCaptcha(): Promise<NetworkResponse<Captcha>> {
    return AuthService.getCaptcha();
  }
}
