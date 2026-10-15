/**
 * AddressRepository (source: core/data/repository/AddressRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Address } from '../../model/Market';
import { Id, Ids } from '../../model/Common';
import { PageRequest } from '../../model/Request';
import { AddressService } from '../../network/service/AddressService';

export class AddressRepository {
  /** user/address/update */
  static updateAddress(params: Address): Promise<NetworkResponse<Object>> {
    return AddressService.updateAddress(params);
  }

  /** user/address/page */
  static getAddressPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Address>>> {
    return AddressService.getAddressPage(params);
  }

  /** user/address/list (unused in source features) */
  static getAddressList(): Promise<NetworkResponse<Address[]>> {
    return AddressService.getAddressList();
  }

  /** user/address/delete */
  static deleteAddress(params: Ids): Promise<NetworkResponse<Object>> {
    return AddressService.deleteAddress(params);
  }

  /** user/address/add */
  static addAddress(params: Address): Promise<NetworkResponse<Id>> {
    return AddressService.addAddress(params);
  }

  /** user/address/info?id= */
  static getAddressInfo(id: number): Promise<NetworkResponse<Address>> {
    return AddressService.getAddressInfo(id);
  }

  /** user/address/default (unused in source features) */
  static getDefaultAddress(): Promise<NetworkResponse<Address | null>> {
    return AddressService.getDefaultAddress();
  }
}
