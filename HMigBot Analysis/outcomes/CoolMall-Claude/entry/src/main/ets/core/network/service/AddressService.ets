/**
 * Address APIs (source: core/network/service/AddressService.kt)
 * Address bodies are sent as AddressBody (kotlinx encodeDefaults=false: default-valued fields omitted,
 * isDefault always sent).
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Address, AddressBody } from '../../model/Market';
import { Id, Ids } from '../../model/Common';
import { PageRequest } from '../../model/Request';

export class AddressService {
  /** Update address (Unit response) */
  static updateAddress(params: Address): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/address/update', AddressBody.from(params));
  }

  /** Address page */
  static getAddressPage(params: PageRequest): Promise<NetworkResponse<NetworkPageData<Address>>> {
    return HttpClient.post<NetworkPageData<Address>>('user/address/page', params);
  }

  /** Address list (unused in source features) */
  static getAddressList(): Promise<NetworkResponse<Address[]>> {
    return HttpClient.post<Address[]>('user/address/list');
  }

  /** Delete addresses (Unit response) */
  static deleteAddress(params: Ids): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('user/address/delete', params);
  }

  /** Add address; data = new id */
  static addAddress(params: Address): Promise<NetworkResponse<Id>> {
    return HttpClient.post<Id>('user/address/add', AddressBody.from(params));
  }

  /** Address info */
  static getAddressInfo(id: number): Promise<NetworkResponse<Address>> {
    const query = new Map<string, string>();
    query.set('id', String(id));
    return HttpClient.get<Address>('user/address/info', query);
  }

  /** Default address (may be null; unused in source features) */
  static getDefaultAddress(): Promise<NetworkResponse<Address | null>> {
    return HttpClient.get<Address | null>('user/address/default');
  }
}
