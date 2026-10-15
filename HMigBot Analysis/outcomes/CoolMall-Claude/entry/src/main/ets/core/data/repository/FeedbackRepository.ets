/**
 * FeedbackRepository (source: core/data/repository/FeedbackRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Feedback } from '../../model/Market';
import { FeedbackSubmitRequest, PageRequest } from '../../model/Request';
import { FeedbackService } from '../../network/service/FeedbackService';

export class FeedbackRepository {
  /** app/feedback/submit */
  static submitFeedback(params: FeedbackSubmitRequest): Promise<NetworkResponse<boolean>> {
    return FeedbackService.submitFeedback(params);
  }

  /** app/feedback/page */
  static getFeedbackPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Feedback>>> {
    return FeedbackService.getFeedbackPage(params);
  }
}
