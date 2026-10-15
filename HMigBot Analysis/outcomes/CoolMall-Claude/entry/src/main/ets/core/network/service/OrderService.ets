/**
 * Order APIs (source: core/network/service/OrderService.kt)
 */
import { HttpClient } from '../HttpClient';
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Logistics, Order, OrderCount, OrderCountJson } from '../../model/Order';
import { CancelOrderRequest, CreateOrderRequest, OrderPageRequest, RefundOrderRequest } from '../../model/Request';

export class OrderService {
  /** Alipay app pay; params { 'orderId': id }; data = Alipay orderStr */
  static alipayAppPay(params: Record<string, number>): Promise<NetworkResponse<string>> {
    return HttpClient.post<string>('order/pay/alipayAppPay', params);
  }

  /** Update order (unused in source features) */
  static updateOrder(params: Object): Promise<NetworkResponse<Object>> {
    return HttpClient.post<Object>('order/info/update', params);
  }

  /** Apply refund */
  static refundOrder(params: RefundOrderRequest): Promise<NetworkResponse<boolean>> {
    return HttpClient.post<boolean>('order/info/refund', params);
  }

  /** Order page */
  static getOrderPage(params: OrderPageRequest): Promise<NetworkResponse<NetworkPageData<Order>>> {
    return HttpClient.post<NetworkPageData<Order>>('order/info/page', params);
  }

  /** Create order */
  static createOrder(params: CreateOrderRequest): Promise<NetworkResponse<Order>> {
    return HttpClient.post<Order>('order/info/create', params);
  }

  /** Cancel order */
  static cancelOrder(params: CancelOrderRequest): Promise<NetworkResponse<boolean>> {
    return HttpClient.post<boolean>('order/info/cancel', params);
  }

  /** Per-status order counts (wire keys are Chinese @SerialName values; mapped into OrderCount) */
  static async getUserOrderCount(): Promise<NetworkResponse<OrderCount>> {
    const raw = await HttpClient.get<OrderCountJson>('order/info/userCount');
    const r = new NetworkResponse<OrderCount>();
    r.code = raw.code;
    r.message = raw.message;
    r.data = (raw.data === null || raw.data === undefined) ? null : OrderCount.from(raw.data);
    return r;
  }

  /** Order logistics */
  static getOrderLogistics(orderId: number): Promise<NetworkResponse<Logistics>> {
    const query = new Map<string, string>();
    query.set('orderId', String(orderId));
    return HttpClient.get<Logistics>('order/info/logistics', query);
  }

  /** Order info */
  static getOrderInfo(id: number): Promise<NetworkResponse<Order>> {
    const query = new Map<string, string>();
    query.set('id', String(id));
    return HttpClient.get<Order>('order/info/info', query);
  }

  /** Confirm receipt */
  static confirmReceive(orderId: number): Promise<NetworkResponse<boolean>> {
    const query = new Map<string, string>();
    query.set('orderId', String(orderId));
    return HttpClient.get<boolean>('order/info/confirm', query);
  }
}
