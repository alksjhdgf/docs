/**
 * OrderListViewModel (source: feature/order/viewmodel/OrderListViewModel.kt).
 *
 * - 7 tabs (OrderStatus), each with its own OrderTabViewModel (list / page / ui / refresh / load-more state).
 * - Route tab param ("0".."6") picks the initial tab, anything else → 0 (ORDA-A06).
 * - Lazy loading: a tab requests page 1 only the first time it is selected (tabDataLoaded) (ORDA-A08).
 * - refreshSpecificTabs(indices): mark tabs unloaded + page 1; the current tab reloads immediately, the others
 *   when next selected (cancel → 0,1,2 / confirm receipt → 0,3,5 / RefreshResult → all) (ORDA-A17/A19/A22).
 * - Cancel order: sheet visibility, dictionary (orderCancelReason) ui state, selected reason (ORDA-A16/A17).
 * - Confirm receipt: dialog visibility + order/info/confirm (ORDA-A18/A19).
 * - Rebuy / comment: goods grouped by goodsId → sheet when > 1 goods, else navigate directly (ORDA-A20/A21).
 */
import { Routes } from '../../../common/Router';
import { CommonRepository } from '../../../core/data/repository/CommonRepository';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { Goods, GoodsSpec } from '../../../core/model/Goods';
import { DictItem } from '../../../core/model/Market';
import { Cart, CartGoodsSpec, Order, OrderGoods } from '../../../core/model/Order';
import { CancelOrderRequest, DictDataRequest } from '../../../core/model/Request';
import { DictDataResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import {
  GoodsDetailParam,
  OrderCommentParam,
  OrderDetailParam,
  OrderLogisticsParam,
  OrderPayParam,
  OrderRefundParam,
  RefreshResult
} from '../../../core/navigation/RouteParams';
import { ResultHandler } from '../../../core/network/ResultHandler';
import { ORDER_STATUS_ENTRIES, OrderStatusUtil } from '../common/OrderStatus';
import { OrderTabViewModel } from './OrderTabViewModel';

/** Cancel-reason dictionary state (source BaseNetWorkUiState<List<DictItem>>) */
export type CancelReasonsUiState = 'loading' | 'success' | 'error';

/** Tabs affected by cancelling an order: 全部 待付款 待发货 */
const CANCEL_AFFECTED_TABS: number[] = [0, 1, 2];
/** Tabs affected by confirming receipt: 全部 待收货 待评价 */
const CONFIRM_AFFECTED_TABS: number[] = [0, 3, 5];
/** All tabs (RefreshResult from a child page) */
const ALL_TABS: number[] = [0, 1, 2, 3, 4, 5, 6];

@ObservedV2
export class OrderListViewModel {
  /** Current tab (source selectedTabIndex) */
  @Trace selectedTabIndex: number = 0;
  /** Per-tab state holders (source uiStates / listDataMap / loadMoreStates / refreshingStates) */
  @Trace tabs: OrderTabViewModel[] = [];

  /** Cancel-reason sheet visibility */
  @Trace cancelModalVisible: boolean = false;
  /** Cancel-reason dictionary state */
  @Trace cancelReasonsUiState: CancelReasonsUiState = 'loading';
  /** Cancel-reason dictionary items */
  @Trace cancelReasons: DictItem[] = [];
  /** Selected cancel reason */
  @Trace selectedCancelReason: DictItem | null = null;

  /** Confirm-receipt dialog visibility */
  @Trace showConfirmDialog: boolean = false;

  /** Rebuy sheet */
  @Trace rebuyModalVisible: boolean = false;
  @Trace rebuyCartList: Cart[] = [];
  @Trace rebuyCurrentOrder: Order | null = null;

  /** Comment sheet */
  @Trace commentModalVisible: boolean = false;
  @Trace commentCartList: Cart[] = [];
  @Trace commentCurrentOrder: Order | null = null;

  /** Whether each tab has (tried to) load data */
  private tabDataLoaded: boolean[] = [];
  private currentCancelOrderId: number = 0;
  private currentConfirmOrderId: number = 0;
  private refreshSubscriptionId: number = -1;
  private disposed: boolean = false;

  /** True once init(tab) ran (the page renders the pager only after that, so the initial tab is right) */
  @Trace initialized: boolean = false;

  constructor() {
    const tabs: OrderTabViewModel[] = [];
    for (let i = 0; i < ORDER_STATUS_ENTRIES.length; i++) {
      tabs.push(new OrderTabViewModel(i, OrderStatusUtil.statusFilter(ORDER_STATUS_ENTRIES[i])));
      this.tabDataLoaded.push(false);
    }
    this.tabs = tabs;
  }

  /**
   * Source init block: route tab → initial tab (fallback 0), observe RefreshResult, load the initial tab.
   * Call once from the page (NavDestination.onReady); later calls are ignored.
   */
  init(tab: string | null): void {
    if (this.initialized || this.disposed) {
      return;
    }
    this.selectedTabIndex = OrderStatusUtil.parseTab(tab);
    // Source: the minimum first-screen loading time applies to the initial tab only
    this.tabs[this.selectedTabIndex].enableInitialMinLoading();
    this.observeRefreshState();
    this.loadTabDataIfNeeded(this.selectedTabIndex);
    this.initialized = true;
  }

  /** Tab view model of `index` */
  tab(index: number): OrderTabViewModel {
    return this.tabs[index];
  }

  // ------------------------------------------------------------------ tabs / paging

  /** Source observeRefreshState: RefreshResult(refresh = true) from any child page → reset all tabs */
  private observeRefreshState(): void {
    if (this.refreshSubscriptionId >= 0) {
      return;
    }
    this.refreshSubscriptionId = AppNavigator.subscribeResult((r: Object): void => {
      if (!this.disposed && RefreshResult.isRefresh(r)) {
        this.refreshSpecificTabs(ALL_TABS);
      }
    });
  }

  private resetTabLoadState(tabIndex: number): void {
    if (tabIndex >= 0 && tabIndex < this.tabDataLoaded.length) {
      this.tabDataLoaded[tabIndex] = false;
      this.tabs[tabIndex].resetPage();
    }
  }

  /** Reset the given tabs; reload the current one immediately if it is among them */
  refreshSpecificTabs(tabIndices: number[]): void {
    if (this.disposed) {
      return;
    }
    for (const i of tabIndices) {
      this.resetTabLoadState(i);
    }
    if (tabIndices.indexOf(this.selectedTabIndex) >= 0) {
      this.loadTabDataIfNeeded(this.selectedTabIndex);
    }
  }

  private loadTabDataIfNeeded(tabIndex: number): void {
    if (tabIndex < 0 || tabIndex >= this.tabDataLoaded.length) {
      return;
    }
    if (!this.tabDataLoaded[tabIndex]) {
      this.tabDataLoaded[tabIndex] = true;
      this.tabs[tabIndex].load();
    }
  }

  /** Tab tapped or pager settled on `index` (source updateSelectedTab / updateTabByPage) */
  updateSelectedTab(index: number): void {
    if (index < 0 || index >= this.tabs.length) {
      return;
    }
    if (this.selectedTabIndex !== index) {
      this.selectedTabIndex = index;
    }
    this.loadTabDataIfNeeded(index);
  }

  // ------------------------------------------------------------------ navigation (OrderNavigator)

  toOrderDetail(orderId: number): void {
    AppNavigator.navigate(Routes.ORDER_ROUTES_DETAIL, new OrderDetailParam(orderId));
  }

  /** `去支付`: amount = price - discountPrice (ORDA-A15) */
  toPay(order: Order): void {
    const price: number = (order.price ?? 0) - (order.discountPrice ?? 0);
    AppNavigator.navigate(Routes.ORDER_ROUTES_PAY, new OrderPayParam(order.id, price));
  }

  toRefund(orderId: number): void {
    AppNavigator.navigate(Routes.ORDER_ROUTES_REFUND, new OrderRefundParam(orderId));
  }

  toLogistics(orderId: number): void {
    AppNavigator.navigate(Routes.ORDER_ROUTES_LOGISTICS, new OrderLogisticsParam(orderId));
  }

  // ------------------------------------------------------------------ cancel order

  /** `取消订单` (source cancelOrder) */
  cancelOrder(orderId: number): void {
    this.currentCancelOrderId = orderId;
    this.cancelModalVisible = true;
  }

  /** Sheet fully expanded (source onCancelModalExpanded) */
  onCancelModalExpanded(): void {
    this.loadCancelReasons();
  }

  /** Load the orderCancelReason dictionary (skipped after a success) */
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

  hideCancelModal(): void {
    this.cancelModalVisible = false;
    this.selectedCancelReason = null;
  }

  selectCancelReason(reason: DictItem): void {
    this.selectedCancelReason = reason;
  }

  /** Confirm: order/info/cancel { orderId, remark = reason name }; success → refresh 全部/待付款/待发货 */
  confirmCancelOrder(): void {
    const req: CancelOrderRequest = new CancelOrderRequest();
    req.orderId = this.currentCancelOrderId;
    const reason: DictItem | null = this.selectedCancelReason;
    req.remark = (reason !== null && reason.name !== null && reason.name !== undefined) ? reason.name as string : '';
    ResultHandler.handleAsync<boolean>(OrderRepository.cancelOrder(req), {
      onSuccess: (data: boolean): void => {
        this.refreshSpecificTabs(CANCEL_AFFECTED_TABS);
      }
    });
  }

  // ------------------------------------------------------------------ confirm receipt

  showConfirmReceiveDialog(orderId: number): void {
    this.currentConfirmOrderId = orderId;
    this.showConfirmDialog = true;
  }

  hideConfirmReceiveDialog(): void {
    this.showConfirmDialog = false;
    this.currentConfirmOrderId = 0;
  }

  /** order/info/confirm?orderId=; success → hide dialog + refresh 全部/待收货/待评价; failure → error toast */
  confirmReceiveOrder(): void {
    ResultHandler.handleAsync<boolean>(OrderRepository.confirmReceive(this.currentConfirmOrderId), {
      onSuccess: (data: boolean): void => {
        if (this.disposed) {
          return;
        }
        this.hideConfirmReceiveDialog();
        this.refreshSpecificTabs(CONFIRM_AFFECTED_TABS);
      }
    });
  }

  // ------------------------------------------------------------------ rebuy / comment

  hideRebuyModal(): void {
    this.rebuyModalVisible = false;
  }

  hideCommentModal(): void {
    this.commentModalVisible = false;
  }

  /** `再次购买` (source handleRebuy) */
  handleRebuy(order: Order): void {
    this.rebuyCurrentOrder = null;
    this.rebuyCartList = [];
    const cartList: Cart[] = OrderListViewModel.convertOrderGoodsToCart(order);
    if (cartList.length > 1) {
      this.rebuyCurrentOrder = order;
      this.rebuyCartList = cartList;
      this.rebuyModalVisible = true;
    } else {
      const goodsId: number = cartList.length > 0 ? cartList[0].goodsId : 0;
      this.toGoodsDetail(goodsId);
    }
  }

  /** Goods detail for rebuy (source toGoodsDetail) */
  toGoodsDetail(goodsId: number): void {
    this.hideRebuyModal();
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(goodsId));
  }

  /** `去评价` (source handleOrderComment) */
  handleOrderComment(order: Order): void {
    this.commentCurrentOrder = null;
    this.commentCartList = [];
    const cartList: Cart[] = OrderListViewModel.convertOrderGoodsToCart(order);
    if (cartList.length > 1) {
      this.commentCurrentOrder = order;
      this.commentCartList = cartList;
      this.commentModalVisible = true;
    } else {
      const goodsId: number = cartList.length > 0 ? cartList[0].goodsId : 0;
      this.toOrderCommentForGoods(order.id, goodsId);
    }
  }

  /** Comment sheet row → OrderRoutes.Comment(currentOrder.id, goodsId) */
  onCommentGoodsSelected(goodsId: number): void {
    const order: Order | null = this.commentCurrentOrder;
    if (order !== null) {
      this.toOrderCommentForGoods(order.id, goodsId);
    }
  }

  toOrderCommentForGoods(orderId: number, goodsId: number): void {
    this.hideCommentModal();
    AppNavigator.navigate(Routes.ORDER_ROUTES_COMMENT, new OrderCommentParam(orderId, goodsId));
  }

  /** Order goods grouped by goodsId → Cart list (source convertOrderGoodsToCart) */
  static convertOrderGoodsToCart(order: Order): Cart[] {
    const goodsList: OrderGoods[] | null | undefined = order.goodsList;
    if (goodsList === null || goodsList === undefined) {
      return [];
    }
    const goodsIdOrder: number[] = [];
    const groups: Map<number, OrderGoods[]> = new Map<number, OrderGoods[]>();
    for (const g of goodsList) {
      const gid: number = g.goodsId ?? 0;
      const bucket: OrderGoods[] | undefined = groups.get(gid);
      if (bucket === undefined) {
        groups.set(gid, [g]);
        goodsIdOrder.push(gid);
      } else {
        bucket.push(g);
      }
    }
    const result: Cart[] = [];
    for (const gid of goodsIdOrder) {
      const items: OrderGoods[] = groups.get(gid) as OrderGoods[];
      const first: OrderGoods = items[0];
      const cart: Cart = new Cart();
      cart.goodsId = gid;
      const info: Goods | null | undefined = first.goodsInfo;
      cart.goodsName = (info !== null && info !== undefined) ? (info.title ?? '') : '';
      cart.goodsMainPic = (info !== null && info !== undefined) ? (info.mainPic ?? '') : '';
      const specs: CartGoodsSpec[] = [];
      for (const og of items) {
        const spec: GoodsSpec | null | undefined = og.spec;
        if (spec !== null && spec !== undefined) {
          const cs: CartGoodsSpec = new CartGoodsSpec();
          cs.id = spec.id;
          cs.goodsId = spec.goodsId;
          cs.name = spec.name;
          cs.price = spec.price;
          cs.stock = spec.stock;
          cs.count = og.count;
          cs.images = spec.images;
          specs.push(cs);
        }
      }
      cart.spec = specs;
      result.push(cart);
    }
    return result;
  }

  /** Release subscriptions and per-tab timers (page aboutToDisappear) */
  dispose(): void {
    this.disposed = true;
    if (this.refreshSubscriptionId >= 0) {
      AppNavigator.unsubscribeResult(this.refreshSubscriptionId);
      this.refreshSubscriptionId = -1;
    }
    for (const t of this.tabs) {
      t.release();
    }
  }
}
