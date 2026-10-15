/**
 * OrderRefundViewModel (source: feature/order/viewmodel/OrderRefundViewModel.kt) — ORDB-A21~A24.
 *
 * - Requests order/info/info?id=orderId (BaseNetWorkViewModel: loading / success / error + retry).
 * - On success the order goods are grouped by goodsId into Cart cards (source convertOrderGoodsToCart).
 * - Refund reason sheet: visibility flag + dictionary state ('loading' | 'success' | 'error'); the dictionary
 *   dict/info/data(types=[orderRefundReason]) is loaded once the sheet is expanded and not reloaded after a
 *   success (source loadRefundReasons). No toast on dictionary failure (showToast = false).
 * - submitRefundApplication(): order/info/refund(orderId, reason = selected reason name) → back with refresh.
 *
 * The page sets `orderId` from its route param, then calls executeRequest(); dispose() from aboutToDisappear.
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { CommonRepository } from '../../../core/data/repository/CommonRepository';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { DictItem } from '../../../core/model/Market';
import { Cart, CartGoodsSpec, Order, OrderGoods } from '../../../core/model/Order';
import { DictDataRequest, RefundOrderRequest } from '../../../core/model/Request';
import { DictDataResponse, NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ResultHandler } from '../../../core/network/ResultHandler';

/** Dictionary type of the refund reasons (source DictDataRequest(types = listOf("orderRefundReason"))) */
const REFUND_REASON_DICT_TYPE: string = 'orderRefundReason';

@ObservedV2
export class OrderRefundViewModel extends BaseNetWorkViewModel<Order> {
  /** Route param orderId (source navKey.orderId) */
  orderId: number = 0;

  /** Refund reason sheet visibility (source refundModalVisible) */
  @Trace refundModalVisible: boolean = false;
  /** Refund reason sheet state (source refundReasonsModalUiState, initially Loading) */
  @Trace refundReasonsUiState: string = 'loading';
  /** Loaded refund reasons (data of the Success state) */
  @Trace refundReasons: DictItem[] = [];
  /** Selected refund reason (source selectedRefundReason) */
  @Trace selectedRefundReason: DictItem | null = null;
  /** Order goods grouped into carts (source cartList) */
  @Trace cartList: Cart[] = [];

  /** order/info/info?id=orderId (source requestApiFlow) */
  protected requestApiFlow(): Promise<NetworkResponse<Order>> {
    return OrderRepository.getOrderInfo(this.orderId);
  }

  /** Convert goods into carts, then success (source onRequestSuccess) */
  protected onRequestSuccess(data: Order): void {
    this.cartList = OrderRefundViewModel.convertOrderGoodsToCart(data);
    super.setSuccessState(data);
  }

  /** Show the refund reason sheet (source showRefundModal) */
  showRefundModal(): void {
    this.refundModalVisible = true;
  }

  /** Sheet fully expanded → load the reasons (source onRefundModalExpanded) */
  onRefundModalExpanded(): void {
    this.loadRefundReasons();
  }

  /** Hide the refund reason sheet (source hideRefundModal) */
  hideRefundModal(): void {
    this.refundModalVisible = false;
  }

  /** Select a refund reason (source selectRefundReason) */
  selectRefundReason(reason: DictItem | null): void {
    this.selectedRefundReason = reason;
  }

  /** Load the refund reason dictionary; skipped once loaded (source loadRefundReasons) */
  loadRefundReasons(): void {
    if (this.disposed || this.refundReasonsUiState === 'success') {
      return;
    }
    const request: DictDataRequest = new DictDataRequest();
    request.types = [REFUND_REASON_DICT_TYPE];
    ResultHandler.handleAsync<DictDataResponse>(CommonRepository.getDictData(request), {
      showToast: false,
      onLoading: (): void => {
        if (!this.disposed) {
          this.refundReasonsUiState = 'loading';
        }
      },
      onSuccess: (data: DictDataResponse): void => {
        if (this.disposed) {
          return;
        }
        const reasons: DictItem[] | null | undefined = data?.orderRefundReason;
        if (reasons === null || reasons === undefined) {
          // source `data.orderRefundReason!!` fails → the flow ends in the error state
          this.refundReasonsUiState = 'error';
          return;
        }
        this.refundReasons = reasons;
        this.refundReasonsUiState = 'success';
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.refundReasonsUiState = 'error';
        }
      }
    });
  }

  /** Submit the refund application (source submitRefundApplication) */
  submitRefundApplication(): void {
    const selectedReason: DictItem | null = this.selectedRefundReason;
    if (selectedReason === null) {
      return;
    }
    const request: RefundOrderRequest = new RefundOrderRequest();
    request.orderId = this.orderId;
    request.reason = selectedReason.name ?? '';
    ResultHandler.handleAsync<boolean>(OrderRepository.refundOrder(request), {
      onSuccess: (data: boolean): void => {
        if (!this.disposed) {
          // source popBackStackWithResult(RefreshResultKey, RefreshResult(refresh = true))
          AppNavigator.backWithRefresh();
        }
      }
    });
  }

  /** order.goodsList grouped by goodsId → Cart list (source convertOrderGoodsToCart) */
  static convertOrderGoodsToCart(order: Order): Cart[] {
    const goodsList: OrderGoods[] | null | undefined = order?.goodsList;
    if (goodsList === null || goodsList === undefined) {
      return [];
    }
    // groupBy keeps first-occurrence order (Map insertion order)
    const grouped: Map<number, OrderGoods[]> = new Map<number, OrderGoods[]>();
    for (const item of goodsList) {
      const goodsId: number = item.goodsId ?? 0;
      let items: OrderGoods[] | undefined = grouped.get(goodsId);
      if (items === undefined) {
        items = [];
        grouped.set(goodsId, items);
      }
      items.push(item);
    }
    const carts: Cart[] = [];
    grouped.forEach((items: OrderGoods[], goodsId: number) => {
      const firstItem: OrderGoods = items[0];
      const cart: Cart = new Cart();
      cart.goodsId = goodsId;
      cart.goodsName = firstItem.goodsInfo?.title ?? '';
      cart.goodsMainPic = firstItem.goodsInfo?.mainPic ?? '';
      const allSpecs: CartGoodsSpec[] = [];
      for (const orderGoods of items) {
        const spec = orderGoods.spec;
        if (spec !== null && spec !== undefined) {
          const cartSpec: CartGoodsSpec = new CartGoodsSpec();
          cartSpec.id = spec.id ?? 0;
          cartSpec.goodsId = spec.goodsId ?? 0;
          cartSpec.name = spec.name ?? '';
          cartSpec.price = spec.price ?? 0;
          cartSpec.stock = spec.stock ?? 0;
          cartSpec.count = orderGoods.count ?? 0;
          cartSpec.images = spec.images ?? null;
          allSpecs.push(cartSpec);
        }
      }
      cart.spec = allSpecs;
      carts.push(cart);
    });
    return carts;
  }
}
