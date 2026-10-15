/**
 * ContributorsViewModel (source: feature/common/viewmodel/ContributorsViewModel.kt).
 * Paged list: POST user/contributor/page { page, size = 10 }.
 */
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { UserContributorRepository } from '../../../core/data/repository/UserContributorRepository';
import { UserContributor } from '../../../core/model/Market';
import { PageRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';

@ObservedV2
export class ContributorsViewModel extends BaseNetWorkListViewModel<UserContributor> {
  constructor() {
    super();
    // source init { initLoad() }
    this.initLoad();
  }

  protected requestListData(): Promise<NetworkResponse<NetworkPageData<UserContributor>>> {
    const req: PageRequest = new PageRequest();
    req.page = this.page;
    req.size = this.pageSize;
    return UserContributorRepository.getUserContributorPage(req);
  }
}
