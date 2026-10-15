/**
 * CommonRepository (source: core/data/repository/CommonRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, DictDataResponse } from '../../model/Response';
import { DictDataRequest } from '../../model/Request';
import { CommonService } from '../../network/service/CommonService';

export class CommonRepository {
  /** base/comm/param?key= */
  static getParam(key: string): Promise<NetworkResponse<string>> {
    return CommonService.getParam(key);
  }

  /** dict/info/data */
  static getDictData(request: DictDataRequest): Promise<NetworkResponse<DictDataResponse>> {
    return CommonService.getDictData(request);
  }
}
