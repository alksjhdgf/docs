/**
 * UserAgreementViewModel (source: feature/common/viewmodel/UserAgreementViewModel.kt).
 * GET base/comm/param?key=userAgreement → HTML string; minimum loading time enabled.
 * The page calls executeRequest() in aboutToAppear (source init { executeRequest() }) and dispose() on exit.
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { NetworkResponse } from '../../../core/model/Response';
import { CommonRepository } from '../../../core/data/repository/CommonRepository';

@ObservedV2
export class UserAgreementViewModel extends BaseNetWorkViewModel<string> {
  constructor() {
    super();
    // 启用最少加载时间
    this.enableMinLoadingTime = true;
  }

  /** 请求用户协议数据 */
  protected requestApiFlow(): Promise<NetworkResponse<string>> {
    return CommonRepository.getParam('userAgreement');
  }
}
