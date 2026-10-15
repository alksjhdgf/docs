/**
 * User contributor APIs (source: core/network/service/UserContributorService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { UserContributor } from '../../model/Market';
import { PageRequest } from '../../model/Request';

export class UserContributorService {
  /** Contributor page */
  static getUserContributorPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<UserContributor>>> {
    return HttpClient.post<NetworkPageData<UserContributor>>('user/contributor/page', params);
  }
}
