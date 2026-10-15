/**
 * OrderRepository (source: core/data/repository/OrderRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse, NetworkPageData } from '../../model/Response';
import { Logistics, Order, OrderCount } from '../../model/Order';
import { CancelOrderRequest, CreateOrderRequest, OrderPageRequest, RefundOrderRequest } from '../../model/Request';
import { OrderService } from '../../network/service/OrderService';

export class OrderRepository {
  /** order/pay/alipayAppPay */
  static alipayAppPay(params: Record<string, number>): Promise<NetworkResponse<string>> {
    return OrderService.alipayAppPay(params);
  }

  /** order/info/refund */
  static refundOrder(params: RefundOrderRequest): Promise<NetworkResponse<boolean>> {
    return OrderService.refundOrder(params);
  }

  /** order/info/page */
  static getOrderPage(params: OrderPageRequest): Promise<NetworkResponse<NetworkPageData<Order>>> {
    return OrderService.getOrderPage(params);
  }

  /** order/info/create */
  static createOrder(params: CreateOrderRequest): Promise<NetworkResponse<Order>> {
    return OrderService.createOrder(params);
  }

  /** order/info/cancel */
  static cancelOrder(params: CancelOrderRequest): Promise<NetworkResponse<boolean>> {
    return OrderService.cancelOrder(params);
  }

  /** order/info/userCount */
  static getUserOrderCount(): Promise<NetworkResponse<OrderCount>> {
    return OrderService.getUserOrderCount();
  }

  /** order/info/logistics?orderId= */
  static getOrderLogistics(orderId: number): Promise<NetworkResponse<Logistics>> {
    return OrderService.getOrderLogistics(orderId);
  }

  /** order/info/info?id= */
  static getOrderInfo(id: number): Promise<NetworkResponse<Order>> {
    return OrderService.getOrderInfo(id);
  }

  /** order/info/confirm?orderId= */
  static confirmReceive(orderId: number): Promise<NetworkResponse<boolean>> {
    return OrderService.confirmReceive(orderId);
  }
}
