/**
 * Customer service APIs (source: core/network/service/CustomerServiceService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { CsMsg, CsSession } from '../../model/Cs';
import { MessagePageRequest, ReadMessageRequest } from '../../model/Request';

export class CustomerServiceService {
  /** Create session */
  static createSession(): Promise<NetworkResponse<CsSession>> {
    return HttpClient.post<CsSession>('cs/session/create');
  }

  /** Session detail (unused in source features) */
  static getSessionDetail(): Promise<NetworkResponse<CsSession>> {
    return HttpClient.get<CsSession>('cs/session/detail');
  }

  /** Mark messages read */
  static readMessage(params: ReadMessageRequest): Promise<NetworkResponse<boolean>> {
    return HttpClient.post<boolean>('cs/msg/read', params);
  }

  /** Message page */
  static getMessagePage(params: MessagePageRequest): Promise<NetworkResponse<NetworkPageData<CsMsg>>> {
    return HttpClient.post<NetworkPageData<CsMsg>>('cs/msg/page', params);
  }

  /** Unread count (unused in source features) */
  static getUnreadCount(): Promise<NetworkResponse<number>> {
    return HttpClient.get<number>('cs/msg/unreadCount');
  }
}
