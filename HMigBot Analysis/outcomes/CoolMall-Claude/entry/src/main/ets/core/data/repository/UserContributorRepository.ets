/**
 * UserContributorRepository (source: core/data/repository/UserContributorRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { UserContributor } from '../../model/Market';
import { PageRequest } from '../../model/Request';
import { UserContributorService } from '../../network/service/UserContributorService';

export class UserContributorRepository {
  /** user/contributor/page */
  static getUserContributorPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<UserContributor>>> {
    return UserContributorService.getUserContributorPage(params);
  }
}
