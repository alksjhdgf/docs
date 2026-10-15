/**
 * AddressListViewModel — 收货地址列表 (source: feature/user/viewmodel/AddressListViewModel.kt).
 *
 * - Paged list of user/address/page (page / size = 10) through BaseNetWorkListViewModel
 *   (skeleton / error retry / empty `暂无数据` / pull-to-refresh / load-more) — USER-A09 / A10.
 * - enableMinLoadingTime = true (source override).
 * - observeRefreshState(): AddressDetail returning RefreshResult{refresh:true} refreshes the list (USER-A16).
 * - Delete: showDeleteDialog(id) → deleteAddress() → user/address/delete {ids:[id]} → onRefresh() +
 *   hideDeleteDialog() (USER-A13 / A14).
 * - onAddressClick: select mode → return the address (SelectAddressResult) and close; otherwise open
 *   AddressDetail in edit mode (USER-A12 / A15).
 */
import { Routes } from '../../../common/Router';
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { AddressRepository } from '../../../core/data/repository/AddressRepository';
import { Ids } from '../../../core/model/Common';
import { Address } from '../../../core/model/Market';
import { PageRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { AddressDetailParam, SelectAddressResult } from '../../../core/navigation/RouteParams';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';

@ObservedV2
export class AddressListViewModel extends BaseNetWorkListViewModel<Address> {
  /** Select mode (source navKey.isSelectMode, from order confirmation) */
  @Trace isSelectMode: boolean = false;
  /** Whether the delete confirmation dialog is shown */
  @Trace showDeleteDialog: boolean = false;
  /** Address id pending deletion */
  @Trace deleteId: number | null = null;

  private started: boolean = false;

  constructor() {
    super();
    // Source: override val enableMinLoadingTime = true
    this.enableMinLoadingTime = true;
  }

  /**
   * Source init { observeRefreshState(); initLoad() } — called once the route parameter is known
   * (NavDestination.onReady).
   */
  start(isSelectMode: boolean): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.isSelectMode = isSelectMode;
    this.observeRefreshState();
    this.initLoad();
  }

  /** user/address/page with the current page / page size */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Address>>> {
    const req: PageRequest = new PageRequest();
    req.page = this.page;
    req.size = this.pageSize;
    return AddressRepository.getAddressPage(req);
  }

  /** Show the delete confirmation dialog and remember the address id */
  openDeleteDialog(id: number): void {
    this.deleteId = id;
    this.showDeleteDialog = true;
  }

  /** Hide the delete confirmation dialog and clear the pending id */
  hideDeleteDialog(): void {
    this.showDeleteDialog = false;
    this.deleteId = null;
  }

  /** Delete the pending address; on success refresh the list and close the dialog */
  deleteAddress(): void {
    const id: number | null = this.deleteId;
    if (id === null) {
      return;
    }
    const body: Ids = new Ids();
    body.ids = [id];
    const opts: ResultHandleOptions<Object> = {
      // Delete returns Unit: treat any code == 1000 reply as success
      onResponse: (resp: NetworkResponse<Object>): void => {
        if (this.disposed || !ResultHandler.isSuccess(resp)) {
          return;
        }
        this.onRefresh();
        this.hideDeleteDialog();
      }
    };
    ResultHandler.handleAsync<Object>(AddressRepository.deleteAddress(body), opts);
  }

  /** Card tap: select mode returns the address, otherwise opens the edit page */
  onAddressClick(address: Address): void {
    if (this.isSelectMode) {
      // popBackStackWithResult(SelectAddressResultKey, address)
      AppNavigator.backWithResult(new SelectAddressResult(address));
    } else {
      AddressListViewModel.toAddressDetail(true, address.id);
    }
  }

  /** UserNavigator.toAddressDetail(isEditMode, addressId) */
  static toAddressDetail(isEditMode: boolean, addressId: number): void {
    const param: AddressDetailParam = new AddressDetailParam();
    param.isEditMode = isEditMode;
    param.addressId = addressId;
    AppNavigator.navigate(Routes.USER_ROUTES_ADDRESS_DETAIL, param);
  }
}
