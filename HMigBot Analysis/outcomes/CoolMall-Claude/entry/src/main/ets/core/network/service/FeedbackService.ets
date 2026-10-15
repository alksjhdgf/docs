/**
 * Feedback APIs (source: core/network/service/FeedbackService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Feedback } from '../../model/Market';
import { FeedbackSubmitRequest, PageRequest } from '../../model/Request';

export class FeedbackService {
  /** Submit feedback */
  static submitFeedback(params: FeedbackSubmitRequest): Promise<NetworkResponse<boolean>> {
    return HttpClient.post<boolean>('app/feedback/submit', params);
  }

  /** Feedback page */
  static getFeedbackPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Feedback>>> {
    return HttpClient.post<NetworkPageData<Feedback>>('app/feedback/page', params);
  }
}
