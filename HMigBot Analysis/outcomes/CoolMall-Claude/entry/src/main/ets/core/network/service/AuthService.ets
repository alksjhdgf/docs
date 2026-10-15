/**
 * Auth APIs (source: core/network/service/AuthService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse } from '../../model/Response';
import { Auth } from '../../model/Auth';
import { Captcha } from '../../model/Market';
import { QQLoginRequest } from '../../model/Request';

export class AuthService {
  /** WeChat mini-app login (unused in source features) */
  static loginByWxApp(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/wxApp', params);
  }

  /** QQ login */
  static loginByQqApp(params: QQLoginRequest): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/qq', params);
  }

  /** Register */
  static register(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/register', params);
  }

  /** Get SMS code (data = the code itself) */
  static getSmsCode(params: Record<string, string>): Promise<NetworkResponse<string>> {
    return HttpClient.post<string>('user/login/smsCode', params);
  }

  /** Refresh token (unused in source features) */
  static refreshToken(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/refreshToken', params);
  }

  /** Phone + SMS code login */
  static loginByPhone(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/phone', params);
  }

  /** Phone + password login */
  static loginByPassword(params: Record<string, string>): Promise<NetworkResponse<Auth>> {
    return HttpClient.post<Auth>('user/login/password', params);
  }

  /** Image captcha */
  static getCaptcha(): Promise<NetworkResponse<Captcha>> {
    return HttpClient.get<Captcha>('user/login/captcha');
  }
}
