/**
 * FeedbackListViewModel (source: feature/feedback/viewmodel/FeedbackListViewModel.kt) — USER-A36.
 *
 * - BaseNetWorkListViewModel<Feedback>: POST app/feedback/page { page, size = 10 }, minimum first-load time.
 * - init: observeRefreshState() (a submit page returning RefreshResult{refresh:true} → onRefresh),
 *   initLoad(), loadFeedbackTypes().
 * - loadFeedbackTypes(): POST dict/info/data { types: ["feedbackType"] } without toast; stores the items.
 * - getFeedbackTypeName(type): dictionary name of `value == type`, else `未知类型`.
 * The page calls dispose() from aboutToDisappear.
 */
import { BaseNetWorkListViewModel } from '../../core/common/BaseNetWorkListViewModel';
import { CommonRepository } from '../../core/data/repository/CommonRepository';
import { FeedbackRepository } from '../../core/data/repository/FeedbackRepository';
import { DictItem, Feedback } from '../../core/model/Market';
import { DictDataRequest, PageRequest } from '../../core/model/Request';
import { DictDataResponse, NetworkPageData, NetworkResponse } from '../../core/model/Response';
import { ResultHandler } from '../../core/network/ResultHandler';

/** Dictionary type of the feedback types */
export const FEEDBACK_TYPE_DICT: string = 'feedbackType';

@ObservedV2
export class FeedbackListViewModel extends BaseNetWorkListViewModel<Feedback> {
  /** Feedback type dictionary (source _feedbackTypes) */
  @Trace feedbackTypes: DictItem[] = [];

  constructor() {
    super();
    this.enableMinLoadingTime = true;
    this.observeRefreshState();
    this.initLoad();
    this.loadFeedbackTypes();
  }

  /** app/feedback/page (source requestListData) */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Feedback>>> {
    const req: PageRequest = new PageRequest();
    req.page = this.page;
    req.size = this.pageSize;
    return FeedbackRepository.getFeedbackPage(req);
  }

  /** Load the feedbackType dictionary (source loadFeedbackTypes, showToast = false) */
  loadFeedbackTypes(): void {
    const request: DictDataRequest = new DictDataRequest();
    request.types = [FEEDBACK_TYPE_DICT];
    ResultHandler.handleAsync<DictDataResponse>(CommonRepository.getDictData(request), {
      showToast: false,
      onSuccess: (data: DictDataResponse): void => {
        if (this.disposed) {
          return;
        }
        const items: DictItem[] | null | undefined = data?.feedbackType;
        this.feedbackTypes = (items !== null && items !== undefined) ? items : [];
      }
    });
  }

  /** Dictionary name of a type value; null / not found → `未知类型` (source getFeedbackTypeName) */
  getFeedbackTypeName(typeValue: number | null | undefined): ResourceStr {
    const unknownType: Resource = $r('app.string.unknown_type');
    if (typeValue === null || typeValue === undefined) {
      return unknownType;
    }
    for (const item of this.feedbackTypes) {
      if (item.value === typeValue) {
        const name: string | null | undefined = item.name;
        return (name !== null && name !== undefined) ? name : unknownType;
      }
    }
    return unknownType;
  }
}
