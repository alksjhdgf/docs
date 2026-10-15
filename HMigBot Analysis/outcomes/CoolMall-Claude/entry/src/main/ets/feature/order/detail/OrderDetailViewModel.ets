/**
 * OrderDetailViewModel (source: feature/order/viewmodel/OrderDetailViewModel.kt) — ORDA-A23..A30.
 *
 * - order/info/info (GET id = orderId) through BaseNetWorkViewModel, minimum loading 320 ms (ORDA-A23).
 * - success → cartList = order goods grouped by goodsId (shared OrderListViewModel.convertOrderGoodsToCart).
 * - cancel order: `选择取消原因` sheet + orderCancelReason dictionary; success → re-fetch + mark list refresh.
 * - confirm receipt: dialog + order/info/confirm; success → re-fetch + mark list refresh + hide dialog.
 * - rebuy / comment: > 1 goods → sheet of the current order's goods, else navigate directly.
 * - RefreshResult(refresh = true) from child pages (pay ...) → re-fetch + mark list refresh (ORDA-A30).
 * - handleBackClick(): marked → back with RefreshResult(refresh = true), otherwise plain back (ORDA-A30).
 */
import { Routes } from '../../../common/Router';
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { CommonRepository } from '../../../core/data/repository/CommonRepository';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { DictItem } from '../../../core/model/Market';
import { Cart, Order } from '../../../core/model/Order';
import { CancelOrderRequest, DictDataRequest } from '../../../core/model/Request';
import { DictDataResponse, NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import {
  GoodsDetailParam,
  OrderCommentParam,
  OrderLogisticsParam,
  OrderPayParam,
  OrderRefundParam,
  RefreshResult
} from '../../../core/navigation/RouteParams';
import { ResultHandler } from '../../../core/network/ResultHandler';
import { OrderListViewModel } from '../list/OrderListViewModel';

/** Cancel-reason dictionary state (source BaseNetWorkUiState<List<DictItem>>) */
export type DetailCancelReasonsUiState = 'loading' | 'success' | 'error';

@ObservedV2
export class OrderDetailViewModel extends BaseNetWorkViewModel<Order> {
  /** Order goods grouped by goodsId (source cartList) */
  @Trace cartList: Cart[] = [];
  /** Incremented on every successful load (ForEach keys of the goods cards) */
  @Trace dataVersion: number = 0;

  /** Cancel-reason sheet */
  @Trace cancelModalVisible: boolean = false;
  @Trace cancelReasonsUiState: DetailCancelReasonsUiState = 'loading';
  @Trace cancelReasons: DictItem[] = [];
  @Trace selectedCancelReason: DictItem | null = null;

  /** Confirm-receipt dialog */
  @Trace showConfirmDialog: boolean = false;
  /** Rebuy / comment sheets */
  @Trace rebuyModalVisible: boolean = false;
  @Trace commentModalVisible: boolean = false;

  /** Route orderId (source requiredOrderId) */
  private requiredOrderId: number = 0;
  /** Source shouldRefreshListOnBack */
  private shouldRefreshListOnBack: boolean = false;
  /** True while this page dispatches its own back result (ignore our own RefreshResult) */
  private sendingBackResult: boolean = false;
  private started: boolean = false;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  /** Source init { observeRefreshState(); executeRequest() } — call once with the route orderId */
  init(orderId: number): void {
    if (this.started || this.disposed) {
      return;
    }
    this.started = true;
    this.requiredOrderId = orderId;
    this.observeRefreshState();
    this.executeRequest();
  }

  protected requestApiFlow(): Promise<NetworkResponse<Order>> {
    return OrderRepository.getOrderInfo(this.requiredOrderId);
  }

  protected onRequestSuccess(data: Order): void {
    this.cartList = OrderListViewModel.convertOrderGoodsToCart(data);
    this.dataVersion = this.dataVersion + 1;
    super.onRequestSuccess(data);
  }

  /** Source observeRefreshState collector: RefreshResult(refresh = true) → re-fetch + mark */
  onRefreshResult(result: Object): void {
    if (this.disposed || this.sendingBackResult) {
      return;
    }
    if (RefreshResult.isRefresh(result)) {
      this.retryRequest();
      this.shouldRefreshListOnBack = true;
    }
  }

  /** Current order or null (source getSuccessData, without throwing) */
  private currentOrder(): Order | null {
    if (this.uiState !== 'success' || this.data === null) {
      return null;
    }
    return this.data;
  }

  // ------------------------------------------------------------------ back

  /** Top bar back and system back (source handleBackClick + BackHandler) */
  handleBackClick(): void {
    if (this.shouldRefreshListOnBack) {
      this.sendingBackResult = true;
      try {
        AppNavigator.backWithResult(new RefreshResult(true));
      } finally {
        this.sendingBackResult = false;
      }
      this.shouldRefreshListOnBack = false;
    } else {
      AppNavigator.back();
    }
  }

  // ------------------------------------------------------------------ confirm receipt

  /** `确认收货` button (source confirmOrder) */
  confirmOrder(): void {
    this.showConfirmDialog = true;
  }

  hideConfirmReceiveDialog(): void {
    this.showConfirmDialog = false;
  }

  /** Dialog OK: order/info/confirm?orderId= */
  confirmReceiveOrder(): void {
    ResultHandler.handleAsync<boolean>(OrderRepository.confirmReceive(this.requiredOrderId), {
      onSuccess: (data: boolean): void => {
        if (this.disposed) {
          return;
        }
        this.retryRequest();
        this.shouldRefreshListOnBack = true;
        this.hideConfirmReceiveDialog();
      }
    });
  }

  // ------------------------------------------------------------------ cancel order

  /** `取消订单` button (source cancelOrder → showCancelModal) */
  cancelOrder(): void {
    this.cancelModalVisible = true;
  }

  onCancelModalExpanded(): void {
    this.loadCancelReasons();
  }

  /** orderCancelReason dictionary (skipped after a success) */
  loadCancelReasons(): void {
    if (this.cancelReasonsUiState === 'success') {
      return;
    }
    const req: DictDataRequest = new DictDataRequest();
    req.types = ['orderCancelReason'];
    ResultHandler.handleAsync<DictDataResponse>(CommonRepository.getDictData(req), {
      showToast: false,
      onLoading: (): void => {
        if (!this.disposed) {
          this.cancelReasonsUiState = 'loading';
        }
      },
      onSuccess: (data: DictDataResponse): void => {
        if (this.disposed) {
          return;
        }
        const items: DictItem[] | null | undefined = data.orderCancelReason;
        this.cancelReasons = (items !== null && items !== undefined) ? items : [];
        this.cancelReasonsUiState = 'success';
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.cancelReasonsUiState = 'error';
        }
      }
    });
  }

  /** Source hideCancelModal: only hides (the selection is kept, as in the detail source) */
  hideCancelModal(): void {
    this.cancelModalVisible = false;
  }

  selectCancelReason(reason: DictItem): void {
    this.selectedCancelReason = reason;
  }

  /** order/info/cancel { orderId, remark = reason name ?: "" }; success → re-fetch + mark */
  confirmCancelOrder(): void {
    const req: CancelOrderRequest = new CancelOrderRequest();
    req.orderId = this.requiredOrderId;
    const reason: DictItem | null = this.selectedCancelReason;
    req.remark = (reason !== null && reason.name !== null && reason.name !== undefined) ? reason.name as string : '';
    ResultHandler.handleAsync<boolean>(OrderRepository.cancelOrder(req), {
      onSuccess: (data: boolean): void => {
        if (this.disposed) {
          return;
        }
        this.retryRequest();
        this.shouldRefreshListOnBack = true;
      }
    });
  }

  // ------------------------------------------------------------------ navigation

  /** `去支付`: amount = price - discountPrice */
  navigateToPayment(): void {
    const order: Order | null = this.currentOrder();
    if (order === null) {
      return;
    }
    const price: number = (order.price ?? 0) - (order.discountPrice ?? 0);
    AppNavigator.navigate(Routes.ORDER_ROUTES_PAY, new OrderPayParam(order.id ?? 0, price));
  }

  toOrderLogistics(): void {
    const order: Order | null = this.currentOrder();
    if (order !== null) {
      AppNavigator.navigate(Routes.ORDER_ROUTES_LOGISTICS, new OrderLogisticsParam(order.id ?? 0));
    }
  }

  toOrderRefund(): void {
    const order: Order | null = this.currentOrder();
    if (order !== null) {
      AppNavigator.navigate(Routes.ORDER_ROUTES_REFUND, new OrderRefundParam(order.id ?? 0));
    }
  }

  // ------------------------------------------------------------------ rebuy

  hideRebuyModal(): void {
    this.rebuyModalVisible = false;
  }

  /** `再次购买`: > 1 goods → sheet, else goods detail of the only goods (0 when none) */
  handleRebuy(): void {
    if (this.cartList.length > 1) {
      this.rebuyModalVisible = true;
    } else {
      const goodsId: number = this.cartList.length > 0 ? this.cartList[0].goodsId : 0;
      this.toGoodsDetail(goodsId);
    }
  }

  toGoodsDetail(goodsId: number): void {
    this.hideRebuyModal();
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(goodsId));
  }

  // ------------------------------------------------------------------ comment

  hideCommentModal(): void {
    this.commentModalVisible = false;
  }

  /** `去评价`: > 1 goods → sheet, else OrderRoutes.Comment(orderId, goodsId) */
  toOrderComment(): void {
    if (this.cartList.length > 1) {
      this.commentModalVisible = true;
      return;
    }
    const order: Order | null = this.currentOrder();
    if (order === null) {
      return;
    }
    const goodsId: number = this.cartList.length > 0 ? this.cartList[0].goodsId : 0;
    AppNavigator.navigate(Routes.ORDER_ROUTES_COMMENT, new OrderCommentParam(order.id ?? 0, goodsId));
  }

  /** Comment sheet row */
  toOrderCommentForGoods(goodsId: number): void {
    const order: Order | null = this.currentOrder();
    if (order === null) {
      return;
    }
    this.hideCommentModal();
    AppNavigator.navigate(Routes.ORDER_ROUTES_COMMENT, new OrderCommentParam(order.id ?? 0, goodsId));
  }
}
