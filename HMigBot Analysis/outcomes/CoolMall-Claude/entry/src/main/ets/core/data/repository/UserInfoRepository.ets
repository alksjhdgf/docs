/**
 * UserInfoRepository (source: core/data/repository/UserInfoRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse } from '../../model/Response';
import { User } from '../../model/User';
import { UserInfoService } from '../../network/service/UserInfoService';

export class UserInfoRepository {
  /** user/info/updatePerson */
  static updatePersonInfo(params: Record<string, Object>): Promise<NetworkResponse<Object>> {
    return UserInfoService.updatePersonInfo(params);
  }

  /** user/info/updatePassword */
  static updatePassword(params: Record<string, string>): Promise<NetworkResponse<Object>> {
    return UserInfoService.updatePassword(params);
  }

  /** user/info/logoff (unused) */
  static logoff(params: Record<string, Object>): Promise<NetworkResponse<Object>> {
    return UserInfoService.logoff(params);
  }

  /** user/info/bindPhone (unused) */
  static bindPhone(params: Record<string, string>): Promise<NetworkResponse<Object>> {
    return UserInfoService.bindPhone(params);
  }

  /** user/info/person */
  static getPersonInfo(): Promise<NetworkResponse<User>> {
    return UserInfoService.getPersonInfo();
  }
}
