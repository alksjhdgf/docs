/**
 * Common APIs (source: core/network/service/CommonService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, DictDataResponse } from '../../model/Response';
import { OssUpload } from '../../model/Market';
import { DictDataRequest } from '../../model/Request';

export class CommonService {
  /** File upload credentials (Tencent COS temporary credentials + url) */
  static uploadFile(): Promise<NetworkResponse<OssUpload>> {
    return HttpClient.post<OssUpload>('base/comm/upload');
  }

  /** Get a param value by key (e.g. HTML content) */
  static getParam(key: string): Promise<NetworkResponse<string>> {
    const query = new Map<string, string>();
    query.set('key', key);
    return HttpClient.get<string>('base/comm/param', query);
  }

  /** Entity path info (unused in source features) */
  static getEntityPathInfo(): Promise<NetworkResponse<Object>> {
    return HttpClient.get<Object>('base/comm/eps');
  }

  /** Dictionary data by types */
  static getDictData(request: DictDataRequest): Promise<NetworkResponse<DictDataResponse>> {
    return HttpClient.post<DictDataResponse>('dict/info/data', request);
  }
}
