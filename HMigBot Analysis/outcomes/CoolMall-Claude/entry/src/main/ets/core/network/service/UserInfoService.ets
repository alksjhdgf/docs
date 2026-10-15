/**
 * User info APIs (source: core/network/service/UserInfoService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse } from '../../model/Response';
import { User } from '../../model/User';

export class UserInfoService {
  /** Update personal info (Map<String, Any> in source) */
  static updatePersonInfo(params: Record<string, Object>): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/info/updatePerson', params);
  }

  /** Update password */
  static updatePassword(params: Record<string, string>): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/info/updatePassword', params);
  }

  /** Log off account (unused in source features) */
  static logoff(params: Record<string, Object>): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/info/logoff', params);
  }

  /** Bind phone (unused in source features) */
  static bindPhone(params: Record<string, string>): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/info/bindPhone', params);
  }

  /** Personal info */
  static getPersonInfo(): Promise<NetworkResponse<User>> {
    return HttpClient.get<User>('user/info/person');
  }
}
