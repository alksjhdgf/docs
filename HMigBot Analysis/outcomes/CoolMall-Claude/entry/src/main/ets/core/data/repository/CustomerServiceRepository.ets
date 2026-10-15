/**
 * CustomerServiceRepository (source: core/data/repository/CustomerServiceRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { CsMsg, CsSession } from '../../model/Cs';
import { MessagePageRequest, ReadMessageRequest } from '../../model/Request';
import { CustomerServiceService } from '../../network/service/CustomerServiceService';

export class CustomerServiceRepository {
  /** cs/session/create */
  static createSession(): Promise<NetworkResponse<CsSession>> {
    return CustomerServiceService.createSession();
  }

  /** cs/session/detail (unused) */
  static getSessionDetail(): Promise<NetworkResponse<CsSession>> {
    return CustomerServiceService.getSessionDetail();
  }

  /** cs/msg/read */
  static readMessage(params: ReadMessageRequest): Promise<NetworkResponse<boolean>> {
    return CustomerServiceService.readMessage(params);
  }

  /** cs/msg/page */
  static getMessagePage(params: MessagePageRequest): Promise<NetworkResponse<NetworkPageData<CsMsg>>> {
    return CustomerServiceService.getMessagePage(params);
  }

  /** cs/msg/unreadCount (unused) */
  static getUnreadCount(): Promise<NetworkResponse<number>> {
    return CustomerServiceService.getUnreadCount();
  }
}
