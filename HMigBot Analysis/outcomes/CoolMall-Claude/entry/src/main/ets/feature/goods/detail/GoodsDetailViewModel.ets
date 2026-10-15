/**
 * GoodsDetailViewModel (source: feature/goods/viewmodel/GoodsDetailViewModel.kt).
 *
 * - Detail request: GET page/goodsDetail?goodsId= (PageRepository.getGoodsDetail) through BaseNetWorkViewModel
 *   (loading → success / error, at least 320 ms of skeleton — enableMinLoadingTime) (GOODS-A01).
 * - onRequestSuccess: the parsed reply is normalized (J2: absent fields → model defaults), then the browsing
 *   footprint is written locally; a failed write only logs (GOODS-A18).
 * - Spec sheet: specModalVisible; the spec list (POST goods/spec/list {goodsId}) is requested from
 *   onSpecModalExpanded (sheet fully shown) and never again after a success (GOODS-A06).
 * - selectSpec toggles: the selected spec again → null (GOODS-A07).
 * - addToCart: local cart merge (no login check), toast `添加购物车成功` / `添加购物车失败` (GOODS-A10).
 * - buyNow: KV `selectedGoodsList` = [SelectedGoods], close the sheet, go to OrderRoutes.Confirm (GOODS-A11).
 * - Coupon sheet: couponModalVisible; receiveCoupon: logged out → close + login page; else receive API and
 *   success toast with the returned text (GOODS-A03/A04).
 * - hasAnimated: top-bar buttons / bottom bar entry animation plays once.
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { AppState } from '../../../core/data/AppState';
import { CartRepository } from '../../../core/data/repository/CartRepository';
import { CouponRepository } from '../../../core/data/repository/CouponRepository';
import { FootprintRepository } from '../../../core/data/repository/FootprintRepository';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { PageRepository } from '../../../core/data/repository/PageRepository';
import { Comment, Goods, GoodsDetail, GoodsSpec } from '../../../core/model/Goods';
import { Coupon, Footprint } from '../../../core/model/Market';
import { CartGoodsSpec, SelectedGoods } from '../../../core/model/Order';
import { ReceiveCouponRequest } from '../../../core/model/Request';
import { NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ResultHandleOptions, ResultHandler } from '../../../core/network/ResultHandler';
import { KvKeys, KvStore } from '../../../core/storage/KvStore';
import { LogUtils } from '../../../core/util/LogUtils';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { Routes } from '../../../common/Router';

const TAG: string = 'GoodsDetailViewModel';

/** Spec list state inside the sheet (source BaseNetWorkUiState<List<GoodsSpec>>) */
export type SpecUiState = 'loading' | 'success' | 'error';

@ObservedV2
export class GoodsDetailViewModel extends BaseNetWorkViewModel<GoodsDetail> {
  /** Route goodsId (source navKey.goodsId) */
  goodsId: number = 0;
  /** Spec sheet visibility */
  @Trace specModalVisible: boolean = false;
  /** Spec list state in the sheet */
  @Trace specUiState: SpecUiState = 'loading';
  /** Loaded specs */
  @Trace specs: GoodsSpec[] = [];
  /** Selected spec (null = none) */
  @Trace selectedSpec: GoodsSpec | null = null;
  /** Entry animation played once */
  @Trace hasAnimated: boolean = false;
  /** Coupon sheet visibility */
  @Trace couponModalVisible: boolean = false;

  /** A spec request is in flight (avoid stacking requests while the sheet reopens) */
  private specRequesting: boolean = false;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  /** Set the route goodsId and start the detail request (source init { executeRequest() }) */
  start(goodsId: number): void {
    this.goodsId = goodsId;
    this.executeRequest();
  }

  protected requestApiFlow(): Promise<NetworkResponse<GoodsDetail>> {
    return PageRepository.getGoodsDetail(this.goodsId);
  }

  protected onRequestSuccess(data: GoodsDetail): void {
    const detail: GoodsDetail = GoodsDetailViewModel.normalizeDetail(data);
    super.onRequestSuccess(detail);
    this.addToFootprint(detail.goodsInfo);
  }

  // ------------------------------------------------------------------ footprint

  private addToFootprint(goods: Goods): void {
    try {
      const fp: Footprint = new Footprint();
      fp.goodsId = goods.id;
      fp.goodsName = goods.title;
      fp.goodsSubTitle = goods.subTitle;
      fp.goodsMainPic = goods.mainPic;
      fp.goodsPrice = goods.price;
      fp.goodsSold = goods.sold;
      fp.viewTime = Date.now();
      FootprintRepository.addFootprint(fp).catch((e: Error) => {
        LogUtils.eTag(TAG, 'addFootprint failed: ' + (e?.message ?? ''));
      });
    } catch (e) {
      // A failed footprint write never affects the page (source printStackTrace)
      LogUtils.eTag(TAG, 'addFootprint failed: ' + ((e as Error)?.message ?? ''));
    }
  }

  // ------------------------------------------------------------------ specs

  /** Load the spec list; no-op after a success (source loadGoodsSpecs; also the sheet retry) */
  loadGoodsSpecs(): void {
    if (this.disposed || this.specUiState === 'success' || this.specRequesting) {
      return;
    }
    this.specRequesting = true;
    const params: Record<string, number> = { 'goodsId': this.goodsId };
    const opts: ResultHandleOptions<GoodsSpec[]> = {
      showToast: false,
      onLoading: (): void => {
        if (!this.disposed) {
          this.specUiState = 'loading';
        }
      },
      onSuccess: (data: GoodsSpec[]): void => {
        if (!this.disposed) {
          this.specs = GoodsDetailViewModel.normalizeSpecs(data);
          this.specUiState = 'success';
        }
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.specUiState = 'error';
        }
      },
      onFinally: (): void => {
        this.specRequesting = false;
      }
    };
    ResultHandler.handleAsync<GoodsSpec[]>(GoodsRepository.getGoodsSpecList(params), opts);
  }

  /** Tap a spec: the selected one again → deselect */
  selectSpec(spec: GoodsSpec): void {
    const current: GoodsSpec | null = this.selectedSpec;
    if (current !== null && current.id === spec.id) {
      this.selectedSpec = null;
    } else {
      this.selectedSpec = spec;
    }
  }

  showSpecModal(): void {
    this.specModalVisible = true;
  }

  /** Sheet fully expanded → load the specs (avoids network work during the show animation) */
  onSpecModalExpanded(): void {
    this.loadGoodsSpecs();
  }

  hideSpecModal(): void {
    this.specModalVisible = false;
  }

  triggerAnimation(): void {
    if (!this.hasAnimated) {
      this.hasAnimated = true;
    }
  }

  // ------------------------------------------------------------------ coupons

  showCouponModal(): void {
    this.couponModalVisible = true;
  }

  hideCouponModal(): void {
    this.couponModalVisible = false;
  }

  /** Coupon sheet action: find the coupon by id among the detail coupons, then receive it */
  onCouponAction(couponId: number): void {
    const detail: GoodsDetail | null = this.data;
    if (detail === null) {
      return;
    }
    const found: Coupon | undefined = detail.coupon.find((c: Coupon): boolean => c.id === couponId);
    if (found !== undefined) {
      this.receiveCoupon(found);
    }
  }

  receiveCoupon(coupon: Coupon): void {
    AppState.instance.ensureInitialized();
    if (!AppState.instance.isLoggedIn) {
      this.hideCouponModal();
      AppNavigator.navigate(Routes.AUTH_ROUTES_LOGIN);
      return;
    }
    const req: ReceiveCouponRequest = new ReceiveCouponRequest();
    req.couponId = coupon.id;
    const opts: ResultHandleOptions<string> = {
      showToast: true,
      onSuccess: (data: string): void => {
        ToastUtils.showSuccess(data);
      }
    };
    ResultHandler.handleAsync<string>(CouponRepository.receiveCoupon(req), opts);
  }

  // ------------------------------------------------------------------ cart / buy

  /** Add to the local cart (no login check) */
  addToCart(selectedGoods: SelectedGoods): void {
    const spec: GoodsSpec | null = selectedGoods.spec;
    if (selectedGoods.goodsId <= 0 || spec === null || selectedGoods.count <= 0) {
      ToastUtils.showError($r('app.string.add_to_cart_failed'));
      return;
    }
    const detail: GoodsDetail | null = this.data;
    const goodsInfo: Goods = detail !== null ? detail.goodsInfo : new Goods();
    const cartSpec: CartGoodsSpec = GoodsDetailViewModel.toCartGoodsSpec(spec, selectedGoods.count);
    CartRepository.mergeAddToCart(selectedGoods.goodsId, goodsInfo.title, goodsInfo.mainPic, cartSpec)
      .then(() => {
        if (!this.disposed) {
          this.hideSpecModal();
        }
        ToastUtils.showSuccess($r('app.string.add_to_cart_success'));
      })
      .catch((e: Error) => {
        LogUtils.eTag(TAG, 'addToCart failed: ' + (e?.message ?? ''));
        ToastUtils.showError($r('app.string.add_to_cart_failed'));
      });
  }

  /** Buy now: KV selectedGoodsList = [selectedGoods] → OrderRoutes.Confirm */
  buyNow(selectedGoods: SelectedGoods): void {
    const list: SelectedGoods[] = [selectedGoods];
    KvStore.putObject(KvKeys.SELECTED_GOODS_LIST, list);
    this.hideSpecModal();
    AppNavigator.navigate(Routes.ORDER_ROUTES_CONFIRM);
  }

  private static toCartGoodsSpec(spec: GoodsSpec, count: number): CartGoodsSpec {
    const s: CartGoodsSpec = new CartGoodsSpec();
    s.id = spec.id;
    s.goodsId = spec.goodsId;
    s.name = spec.name ?? '';
    s.price = spec.price ?? 0;
    s.stock = spec.stock ?? 0;
    s.count = count;
    s.images = spec.images ?? null;
    return s;
  }

  // ------------------------------------------------------------------ normalization (J2)

  private static normalizeDetail(d: GoodsDetail | null | undefined): GoodsDetail {
    const out: GoodsDetail = new GoodsDetail();
    if (d === null || d === undefined) {
      return out;
    }
    out.goodsInfo = GoodsDetailViewModel.normalizeGoods(d.goodsInfo);
    const coupons: Coupon[] | null | undefined = d.coupon;
    out.coupon = (coupons !== null && coupons !== undefined) ? coupons : [];
    const comments: Comment[] | null | undefined = d.comment;
    out.comment = (comments !== null && comments !== undefined) ?
    comments.map((c: Comment): Comment => GoodsDetailViewModel.normalizeComment(c)) : [];
    return out;
  }

  static normalizeGoods(g: Goods | null | undefined): Goods {
    const out: Goods = new Goods();
    if (g === null || g === undefined) {
      return out;
    }
    out.id = g.id ?? 0;
    out.typeId = g.typeId ?? 0;
    out.title = g.title ?? '';
    out.subTitle = g.subTitle ?? null;
    out.mainPic = g.mainPic ?? '';
    out.pics = g.pics ?? null;
    out.price = g.price ?? 0;
    out.sold = g.sold ?? 0;
    out.content = g.content ?? null;
    out.contentPics = g.contentPics ?? null;
    out.recommend = g.recommend ?? false;
    out.featured = g.featured ?? false;
    out.status = g.status ?? 0;
    out.sortNum = g.sortNum ?? 0;
    out.specs = g.specs ?? null;
    out.createTime = g.createTime ?? null;
    out.updateTime = g.updateTime ?? null;
    return out;
  }

  /** Comment with absent fields mapped to the model defaults (shared with the comment page) */
  static normalizeComment(c: Comment | null | undefined): Comment {
    const out: Comment = new Comment();
    if (c === null || c === undefined) {
      return out;
    }
    out.id = c.id ?? 0;
    out.userId = c.userId ?? 0;
    out.goodsId = c.goodsId ?? 0;
    out.orderId = c.orderId ?? 0;
    out.content = c.content ?? '';
    out.starCount = c.starCount ?? 5;
    out.pics = c.pics ?? null;
    out.nickName = c.nickName ?? null;
    out.avatarUrl = c.avatarUrl ?? null;
    out.createTime = c.createTime ?? null;
    out.updateTime = c.updateTime ?? null;
    return out;
  }

  private static normalizeSpecs(list: GoodsSpec[] | null | undefined): GoodsSpec[] {
    if (list === null || list === undefined) {
      return [];
    }
    return list.map((s: GoodsSpec): GoodsSpec => {
      const out: GoodsSpec = new GoodsSpec();
      out.id = s.id ?? 0;
      out.goodsId = s.goodsId ?? 0;
      out.name = s.name ?? '';
      out.price = s.price ?? 0;
      out.stock = s.stock ?? 0;
      out.sortNum = s.sortNum ?? 0;
      out.images = s.images ?? null;
      out.createTime = s.createTime ?? null;
      out.updateTime = s.updateTime ?? null;
      return out;
    });
  }
}
