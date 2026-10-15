/**
 * AddressDetailViewModel — 收货地址详情 (source: feature/user/viewmodel/AddressDetailViewModel.kt).
 *
 * - Edit mode with addressId > 0 → user/address/info?id= and fill the form; failure → error + retry.
 *   Otherwise (add mode) the success state is set directly with an empty Address (USER-A18).
 * - Form fields: contact / phone / province / city / district / detail address / default flag.
 * - saveAddress(): edit → user/address/update, add → user/address/add (isDefault always serialized,
 *   no client validation); on success return to the list with RefreshResult{refresh:true} (USER-A21).
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { AddressRepository } from '../../../core/data/repository/AddressRepository';
import { Id } from '../../../core/model/Common';
import { Address } from '../../../core/model/Market';
import { NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';

@ObservedV2
export class AddressDetailViewModel extends BaseNetWorkViewModel<Address> {
  /** Source navKey.isEditMode */
  @Trace isEditMode: boolean = false;
  /** Source navKey.addressId */
  addressId: number = 0;

  /** 联系人 */
  @Trace contactName: string = '';
  /** 手机号 */
  @Trace phone: string = '';
  /** 省 */
  @Trace province: string = '';
  /** 市 */
  @Trace city: string = '';
  /** 区 */
  @Trace district: string = '';
  /** 详细地址 */
  @Trace detailAddress: string = '';
  /** 是否默认地址 */
  @Trace isDefaultAddress: boolean = false;

  private started: boolean = false;

  /** Source init block, called once the route parameter is known (NavDestination.onReady) */
  start(isEditMode: boolean, addressId: number): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.isEditMode = isEditMode;
    this.addressId = addressId;
    if (isEditMode && addressId > 0) {
      this.executeRequest();
    } else {
      // Add mode: success state with an empty address
      this.setSuccessState(new Address());
    }
  }

  /** user/address/info?id= */
  protected requestApiFlow(): Promise<NetworkResponse<Address>> {
    return AddressRepository.getAddressInfo(this.addressId);
  }

  /** Fill the form after a successful load */
  protected onRequestSuccess(data: Address): void {
    this.updateFormData(data);
    super.onRequestSuccess(data);
  }

  private updateFormData(address: Address): void {
    // J2: JSON.parse objects may miss fields → fall back to the model defaults
    this.contactName = AddressDetailViewModel.textOf(address.contact);
    this.phone = AddressDetailViewModel.textOf(address.phone);
    this.province = AddressDetailViewModel.textOf(address.province);
    this.city = AddressDetailViewModel.textOf(address.city);
    this.district = AddressDetailViewModel.textOf(address.district);
    this.detailAddress = AddressDetailViewModel.textOf(address.address);
    this.isDefaultAddress = address.isDefault === true;
  }

  /** Missing / null JSON field → '' (model default) */
  private static textOf(v: string | null | undefined): string {
    return (v === null || v === undefined) ? '' : v;
  }

  updateContactName(value: string): void {
    this.contactName = value;
  }

  updatePhone(value: string): void {
    this.phone = value;
  }

  updateRegion(province: string, city: string, district: string): void {
    this.province = province;
    this.city = city;
    this.district = district;
  }

  updateDetailAddress(value: string): void {
    this.detailAddress = value;
  }

  updateIsDefaultAddress(value: boolean): void {
    this.isDefaultAddress = value;
  }

  /** `省 市 区` when all three parts are set, otherwise '' (source region field value / initialRegion) */
  regionText(): string {
    if (this.province.length > 0 && this.city.length > 0 && this.district.length > 0) {
      return `${this.province} ${this.city} ${this.district}`;
    }
    return '';
  }

  /** Save: update in edit mode, add otherwise */
  saveAddress(): void {
    const address: Address = new Address();
    address.id = this.isEditMode ? this.addressId : 0;
    address.contact = this.contactName;
    address.phone = this.phone;
    address.province = this.province;
    address.city = this.city;
    address.district = this.district;
    address.address = this.detailAddress;
    address.isDefault = this.isDefaultAddress;
    if (this.isEditMode) {
      this.updateAddress(address);
    } else {
      this.addAddress(address);
    }
  }

  private updateAddress(address: Address): void {
    const opts: ResultHandleOptions<Object> = {
      // Source handleResult onSuccess: any code == 1000 reply
      onResponse: (resp: NetworkResponse<Object>): void => {
        if (!this.disposed && ResultHandler.isSuccess(resp)) {
          AppNavigator.backWithRefresh();
        }
      }
    };
    ResultHandler.handleAsync<Object>(AddressRepository.updateAddress(address), opts);
  }

  private addAddress(address: Address): void {
    const opts: ResultHandleOptions<Id> = {
      onResponse: (resp: NetworkResponse<Id>): void => {
        if (!this.disposed && ResultHandler.isSuccess(resp)) {
          AppNavigator.backWithRefresh();
        }
      }
    };
    ResultHandler.handleAsync<Id>(AddressRepository.addAddress(address), opts);
  }
}
