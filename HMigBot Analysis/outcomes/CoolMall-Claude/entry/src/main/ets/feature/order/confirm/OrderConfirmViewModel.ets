/**
 * OrderConfirmViewModel (source: feature/order/viewmodel/OrderConfirmViewModel.kt) — ORDB-A04~A14.
 *
 * - requestApiFlow: page/confirmOrder (defaultAddress + userCoupon), enableMinLoadingTime.
 * - Items: KV `carts` (from the cart) first, else KV `selectedGoodsList` (buy now) grouped by goodsId into
 *   Cart cards; both keys are removed right after reading (ORDB-A05).
 * - Prices: originalPrice = Σ spec.price × count; discount = coupon.amount only when a condition exists and
 *   originalPrice ≥ condition.fullAmount; totalPrice = max(0, original − discount) (ORDB-A08).
 * - Address: result of AddressList (select mode) replaces defaultAddress (ORDB-A06).
 * - Submit: no address → `请选择收货地址`; else order/info/create → remove ordered cart items (cart origin)
 *   → replace with Pay(orderId, price − discountPrice, from = "confirm") (ORDB-A12~A14).
 *
 * Usage: `@Local vm = new OrderConfirmViewModel()`; aboutToAppear → vm.init(); aboutToDisappear → vm.dispose().
 */
import { Routes } from '../../../common/Router';
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { CartRepository } from '../../../core/data/repository/CartRepository';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { PageRepository } from '../../../core/data/repository/PageRepository';
import { GoodsSpec } from '../../../core/model/Goods';
import { Address, Coupon } from '../../../core/model/Market';
import { Cart, CartGoodsSpec, ConfirmOrder, Order, SelectedGoods } from '../../../core/model/Order';
import { CreateOrder, CreateOrderRequest } from '../../../core/model/Request';
import { NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { OrderPayParam, SelectAddressResult } from '../../../core/navigation/RouteParams';
import { ResultHandler } from '../../../core/network/ResultHandler';
import { KvKeys, KvStore } from '../../../core/storage/KvStore';
import { LogUtils } from '../../../core/util/LogUtils';
import { ToastUtils } from '../../../core/util/ToastUtils';

const TAG: string = 'OrderConfirmViewModel';

@ObservedV2
export class OrderConfirmViewModel extends BaseNetWorkViewModel<ConfirmOrder> {
  /** Order remark (source remark) */
  @Trace remark: string = '';
  /** Coupon sheet visibility (source couponModalVisible) */
  @Trace couponModalVisible: boolean = false;
  /** Selected coupon (source selectedCoupon) */
  @Trace selectedCoupon: Coupon | null = null;
  /** Goods original price (yuan) */
  @Trace originalPrice: number = 0;
  /** Coupon discount (yuan) */
  @Trace discountAmount: number = 0;
  /** Final price (yuan) */
  @Trace totalPrice: number = 0;
  /** Item cards shown on the page (source cartList) */
  @Trace cartList: Cart[] = [];

  /** Items coming from the cart (KV `carts`), null when the order comes from buy-now */
  cachedCarts: Cart[] | null = null;
  /** Goods submitted with the order (KV `selectedGoodsList`), kept as read (JSON wire form) */
  selectedGoodsList: SelectedGoods[] | null = null;

  /**
   * Order title (source context.getString(R.string.purchase_goods) = `购买商品`); the page resolves the
   * localized string resource through its UIContext in aboutToAppear.
   */
  purchaseTitle: string = '购买商品';

  private addressResultId: number = -1;
  private initialized: boolean = false;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  /** Source init { observeSelectedAddressResult(); executeRequest(); remove caches; calculate prices } */
  init(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.cachedCarts = OrderConfirmViewModel.readCarts();
    this.selectedGoodsList = OrderConfirmViewModel.readSelectedGoods();
    this.cartList = this.cachedCarts !== null ? this.cachedCarts :
      (this.selectedGoodsList !== null ? OrderConfirmViewModel.groupSelectedGoods(this.selectedGoodsList) : []);

    this.observeSelectedAddressResult();
    this.executeRequest();
    // Clear the checkout caches so they are not reused
    KvStore.remove(KvKeys.SELECTED_GOODS_LIST);
    KvStore.remove(KvKeys.CARTS);

    this.calculateOriginalPrice();
    this.calculatePrices(this.selectedCoupon);
  }

  protected requestApiFlow(): Promise<NetworkResponse<ConfirmOrder>> {
    return PageRepository.getConfirmOrder();
  }

  /** userCoupon of the loaded page (empty when not loaded) */
  userCoupons(): Coupon[] {
    const d: ConfirmOrder | null = this.uiState === 'success' ? this.data : null;
    if (d === null || d.userCoupon === null || d.userCoupon === undefined) {
      return [];
    }
    return d.userCoupon;
  }

  /** defaultAddress of the loaded page */
  currentAddress(): Address | null {
    const d: ConfirmOrder | null = this.data;
    if (d === null || d.defaultAddress === null || d.defaultAddress === undefined) {
      return null;
    }
    return d.defaultAddress;
  }

  // ============================== Address ==============================

  /** Source observeSelectedAddressResult: resultEvents(SelectAddressResultKey) */
  private observeSelectedAddressResult(): void {
    if (this.addressResultId >= 0) {
      return;
    }
    this.addressResultId = AppNavigator.subscribeResult((r: Object): void => {
      this.onNavResult(r);
    });
  }

  /** Navigation result (global bus or the AddressList onResult): only SelectAddressResult is handled */
  onNavResult(r: Object): void {
    if (this.disposed || r === null || r === undefined || !(r instanceof SelectAddressResult)) {
      return;
    }
    const address: Address | null = (r as SelectAddressResult).address;
    if (address !== null && address !== undefined) {
      this.onAddressSelected(address);
    }
  }

  /** Replace the page's address with the selected one (source onAddressSelected) */
  onAddressSelected(address: Address): void {
    if (this.uiState !== 'success' || this.data === null) {
      LogUtils.wTag(TAG, 'address selected while page data is not loaded');
      return;
    }
    const current: ConfirmOrder = this.data;
    const updated: ConfirmOrder = new ConfirmOrder();
    updated.defaultAddress = address;
    updated.userCoupon = current.userCoupon;
    this.setSuccessState(updated);
  }

  // ============================== Remark / coupon ==============================

  updateRemark(newRemark: string): void {
    this.remark = newRemark;
  }

  showCouponModal(): void {
    this.couponModalVisible = true;
  }

  hideCouponModal(): void {
    this.couponModalVisible = false;
  }

  /** Select a coupon (null = none), close the sheet and recalculate prices */
  selectCoupon(coupon: Coupon | null): void {
    this.selectedCoupon = coupon;
    this.calculatePrices(coupon);
    this.hideCouponModal();
  }

  /** CouponModal onCouponAction(couponId): find it in userCoupon (source OrderConfirmScreen) */
  selectCouponById(couponId: number): void {
    const found: Coupon | undefined = this.userCoupons().find((c: Coupon): boolean => c.id === couponId);
    this.selectCoupon(found !== undefined ? found : null);
  }

  private calculateOriginalPrice(): void {
    let price: number = 0;
    for (const cart of this.cartList) {
      for (const spec of cart.spec) {
        price += spec.price * spec.count;
      }
    }
    this.originalPrice = price;
  }

  private calculatePrices(coupon: Coupon | null): void {
    const originalPriceValue: number = this.originalPrice;
    let discountValue: number = 0;
    if (coupon !== null && coupon.condition !== null && coupon.condition !== undefined) {
      const fullAmount: number = coupon.condition.fullAmount ?? 0;
      discountValue = originalPriceValue >= fullAmount ? (coupon.amount ?? 0) : 0;
    }
    this.discountAmount = discountValue;
    this.totalPrice = Math.max(0, originalPriceValue - discountValue);
  }

  // ============================== Submit ==============================

  /** Submit order (source onSubmitOrderClick) */
  onSubmitOrderClick(): void {
    const address: Address | null = this.uiState === 'success' ? this.currentAddress() : null;
    const addressId: number | null = (address !== null && address.id !== undefined && address.id !== null) ?
      address.id : null;
    if (addressId === null) {
      ToastUtils.showError($r('app.string.select_address'));
      return;
    }
    const data: CreateOrder = new CreateOrder();
    data.addressId = addressId;
    data.goodsList = this.selectedGoodsList !== null ? this.selectedGoodsList : [];
    data.title = this.purchaseTitle;
    if (this.remark.length > 0) {
      data.remark = this.remark;
    }
    if (this.selectedCoupon !== null) {
      data.couponId = this.selectedCoupon.id;
    }
    const params: CreateOrderRequest = new CreateOrderRequest();
    params.data = data;

    ResultHandler.handleAsync<Order>(OrderRepository.createOrder(params), {
      showToast: true,
      onSuccess: (order: Order): void => {
        // From the cart: remove the ordered items
        if (this.cachedCarts !== null && this.cachedCarts.length > 0) {
          this.deleteCartItems(this.cachedCarts);
        }
        this.navigateToPayment(order);
      }
    });
  }

  /** Close this page and open Pay(orderId, price − discountPrice, from = "confirm") */
  navigateToPayment(order: Order): void {
    const orderId: number = order.id ?? 0;
    const paymentPrice: number = (order.price ?? 0) - (order.discountPrice ?? 0);
    AppNavigator.replace(Routes.ORDER_ROUTES_PAY, new OrderPayParam(orderId, paymentPrice, 'confirm'));
  }

  /** Remove ordered goods from the local cart: whole goods when every spec was ordered, else per spec */
  private async deleteCartItems(carts: Cart[]): Promise<void> {
    for (const cart of carts) {
      try {
        const goodsId: number = cart.goodsId;
        const specIds: number[] = OrderConfirmViewModel.distinct(cart.spec.map((s: CartGoodsSpec): number => s.id));
        const fullCart: Cart | null = await CartRepository.getCartByGoodsId(goodsId);
        if (fullCart === null) {
          continue;
        }
        const allSpecIds: number[] =
          OrderConfirmViewModel.distinct((fullCart.spec ?? []).map((s: CartGoodsSpec): number => s.id));
        const containsAll: boolean = allSpecIds.every((id: number): boolean => specIds.indexOf(id) >= 0);
        if (specIds.length === allSpecIds.length && containsAll) {
          await CartRepository.removeFromCart(goodsId);
        } else {
          for (const specId of specIds) {
            await CartRepository.removeSpecFromCart(goodsId, specId);
          }
        }
      } catch (e) {
        LogUtils.eTag(TAG, 'deleteCartItems failed: ' + ((e as Error)?.message ?? ''));
      }
    }
  }

  dispose(): void {
    super.dispose();
    if (this.addressResultId >= 0) {
      AppNavigator.unsubscribeResult(this.addressResultId);
      this.addressResultId = -1;
    }
  }

  // ============================== Helpers ==============================

  private static distinct(ids: number[]): number[] {
    const out: number[] = [];
    for (const id of ids) {
      if (out.indexOf(id) < 0) {
        out.push(id);
      }
    }
    return out;
  }

  /** KV `carts` → Cart instances (plain JSON objects; missing fields fall back to model defaults) */
  private static readCarts(): Cart[] | null {
    const raw: Cart[] | null = KvStore.getObject<Cart[]>(KvKeys.CARTS);
    if (raw === null || raw === undefined || !Array.isArray(raw)) {
      return null;
    }
    const result: Cart[] = [];
    for (const r of raw) {
      if (r === null || r === undefined) {
        continue;
      }
      const cart: Cart = new Cart();
      cart.goodsId = r.goodsId ?? 0;
      cart.goodsName = r.goodsName ?? '';
      cart.goodsMainPic = r.goodsMainPic ?? '';
      const specs: CartGoodsSpec[] = [];
      const rawSpecs: CartGoodsSpec[] = r.spec ?? [];
      for (const s of rawSpecs) {
        specs.push(OrderConfirmViewModel.copySpec(s));
      }
      cart.spec = specs;
      result.push(cart);
    }
    return result;
  }

  /** KV `selectedGoodsList` (kept in wire form: it is sent as goodsList of order/info/create) */
  private static readSelectedGoods(): SelectedGoods[] | null {
    const raw: SelectedGoods[] | null = KvStore.getObject<SelectedGoods[]>(KvKeys.SELECTED_GOODS_LIST);
    if (raw === null || raw === undefined || !Array.isArray(raw)) {
      return null;
    }
    return raw;
  }

  /** Source: groupBy goodsId (insertion order), one Cart per goods with every selected spec */
  private static groupSelectedGoods(goods: SelectedGoods[]): Cart[] {
    const groups: Map<number, SelectedGoods[]> = new Map<number, SelectedGoods[]>();
    for (const g of goods) {
      if (g === null || g === undefined) {
        continue;
      }
      const goodsId: number = g.goodsId ?? 0;
      const list: SelectedGoods[] | undefined = groups.get(goodsId);
      if (list !== undefined) {
        list.push(g);
      } else {
        groups.set(goodsId, [g]);
      }
    }
    const result: Cart[] = [];
    groups.forEach((items: SelectedGoods[], goodsId: number) => {
      const firstItem: SelectedGoods = items[0];
      const cart: Cart = new Cart();
      cart.goodsId = goodsId;
      cart.goodsName = firstItem.goodsInfo?.title ?? '';
      cart.goodsMainPic = firstItem.goodsInfo?.mainPic ?? '';
      const allSpecs: CartGoodsSpec[] = [];
      for (const selectedItem of items) {
        const spec: GoodsSpec | null = selectedItem.spec;
        if (spec !== null && spec !== undefined) {
          const cartSpec: CartGoodsSpec = new CartGoodsSpec();
          cartSpec.id = spec.id ?? 0;
          cartSpec.goodsId = spec.goodsId ?? 0;
          cartSpec.name = spec.name ?? '';
          cartSpec.price = spec.price ?? 0;
          cartSpec.stock = spec.stock ?? 0;
          cartSpec.count = selectedItem.count ?? 0;
          cartSpec.images = spec.images ?? null;
          allSpecs.push(cartSpec);
        }
      }
      cart.spec = allSpecs;
      result.push(cart);
    });
    return result;
  }

  private static copySpec(s: CartGoodsSpec): CartGoodsSpec {
    const spec: CartGoodsSpec = new CartGoodsSpec();
    spec.id = s.id ?? 0;
    spec.goodsId = s.goodsId ?? 0;
    spec.name = s.name ?? '';
    spec.price = s.price ?? 0;
    spec.stock = s.stock ?? 0;
    spec.count = s.count ?? 0;
    spec.images = s.images ?? null;
    return spec;
  }
}
