/**
 * OrderLogisticsViewModel (source: feature/order/viewmodel/OrderLogisticsViewModel.kt) — ORDA-A31/A32.
 *
 * init(orderId) starts both requests in parallel (source init { executeRequest(); getOrderLogistics() }):
 * - order/info/info (GET id) drives the page state (skeleton ≥ 320 ms, error → network error + retry);
 * - order/info/logistics (GET orderId) fills `logistics`; failure only shows the error toast and the
 *   logistics section keeps the defaults (Logistics()).
 * Retry re-requests the order info only (source onRetry = retryRequest).
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { Logistics, Order } from '../../../core/model/Order';
import { NetworkResponse } from '../../../core/model/Response';
import { ResultHandler } from '../../../core/network/ResultHandler';

@ObservedV2
export class OrderLogisticsViewModel extends BaseNetWorkViewModel<Order> {
  /** Source orderLogisticsUiState (default Logistics()) */
  @Trace logistics: Logistics = new Logistics();

  private requiredOrderId: number = 0;
  private started: boolean = false;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  init(orderId: number): void {
    if (this.started || this.disposed) {
      return;
    }
    this.started = true;
    this.requiredOrderId = orderId;
    this.executeRequest();
    this.getOrderLogistics();
  }

  protected requestApiFlow(): Promise<NetworkResponse<Order>> {
    return OrderRepository.getOrderInfo(this.requiredOrderId);
  }

  /** order/info/logistics?orderId= (error toast on failure, default ResultHandler behaviour) */
  getOrderLogistics(): void {
    ResultHandler.handleAsync<Logistics>(OrderRepository.getOrderLogistics(this.requiredOrderId), {
      onSuccess: (data: Logistics): void => {
        if (!this.disposed) {
          this.logistics = data;
        }
      }
    });
  }
}
