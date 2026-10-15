/**
 * HomeViewModel (source: feature/main/viewmodel/HomeViewModel.kt).
 *
 * Extends BaseNetWorkListViewModel<Goods> but overrides the first load / refresh (HOME-A08/A09/A20):
 *  - loadHomeData(): GET page/home (PageRepository.getHomeData). Any code == 1000 reply fills pageData
 *    (banner / coupon / category / categoryAll / flashSale / recommend / goods) and replaces the all-goods list
 *    with home.goods; loadMoreState = PullToLoad when goods is non-empty, else NoMore; uiState = success
 *    (never 'empty'). The first load keeps the skeleton for at least 320 ms.
 *    Failure → uiState = 'error' (source: isRefreshing is NOT reset on failure — kept as in source).
 *  - onRefresh(): ignored while loadMoreState == Loading; else isRefreshing = true, page = 1, loadHomeData().
 *  - Load more uses the base onLoadMore → page 2.. → requestListData() = POST goods/info/page {page, size=10}
 *    (append after 400 ms, NoMore when no next page, Error + page rollback on failure) (HOME-A19).
 *  - Coupon sheet visibility (couponModalVisible) lives here like the source.
 *  - receiveCoupon(): logged out → close the sheet + go to login; else POST market/coupon/user/receive and
 *    show the server message as a success toast (errors toast too, showToast = true) (HOME-A13).
 *  - toGoodsCategoryPage(id): typeId = ids of categoryAll whose parentId == id, joined with ',' (HOME-A15).
 */
import { BaseNetWorkListViewModel, LoadMoreState } from '../../../core/common/BaseNetWorkListViewModel';
import { MIN_LOADING_TIME_MS } from '../../../core/common/BaseNetWorkViewModel';
import { AppState } from '../../../core/data/AppState';
import { CouponRepository } from '../../../core/data/repository/CouponRepository';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { PageRepository } from '../../../core/data/repository/PageRepository';
import { Banner, Category, Goods, Home } from '../../../core/model/Goods';
import { Coupon } from '../../../core/model/Market';
import { GoodsSearchRequest, ReceiveCouponRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { GoodsCategoryParam } from '../../../core/navigation/RouteParams';
import { ResultHandleOptions, ResultHandler } from '../../../core/network/ResultHandler';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { Routes } from '../../../common/Router';

@ObservedV2
export class HomeViewModel extends BaseNetWorkListViewModel<Goods> {
  /** Home aggregate data (source pageData, initially Home()) */
  @Trace pageData: Home = new Home();
  /** Coupon receive sheet visibility (source couponModalVisible) */
  @Trace couponModalVisible: boolean = false;

  /** First-load start time (source homeRequestStartTime) */
  private homeRequestStartTime: number = 0;

  constructor() {
    super();
  }

  /** Load-more request: POST goods/info/page { page = currentPage, size = pageSize (10) } */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Goods>>> {
    const req: GoodsSearchRequest = new GoodsSearchRequest();
    req.page = this.page;
    req.size = this.pageSize;
    return GoodsRepository.getGoodsPage(req);
  }

  /** Load the home aggregate data (source loadHomeData; also the error-view retry) */
  loadHomeData(): void {
    if (this.disposed) {
      return;
    }
    const isFirstLoading: boolean = this.page === 1 && this.list.length === 0 && !this.isRefreshing;
    if (isFirstLoading) {
      this.homeRequestStartTime = Date.now();
      this.uiState = 'loading';
      this.loadMoreState = LoadMoreState.Loading;
    }
    let request: Promise<NetworkResponse<Home>>;
    try {
      request = PageRepository.getHomeData();
    } catch (e) {
      request = Promise.reject(e as Error);
    }
    const opts: ResultHandleOptions<Home> = {
      showToast: false,
      // source handleResult onSuccess(response): any code == 1000 reply, even when data == null
      onResponse: (resp: NetworkResponse<Home>): void => {
        if (this.disposed || !ResultHandler.isSuccess(resp)) {
          return;
        }
        this.onHomeLoaded(resp.data, isFirstLoading);
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.uiState = 'error';
        }
      }
    };
    ResultHandler.handleAsync<Home>(request, opts);
  }

  private onHomeLoaded(data: Home | null | undefined, isFirstLoading: boolean): void {
    const home: Home = HomeViewModel.normalizeHome(data);
    this.pageData = home;
    this.isRefreshing = false;
    // The all-goods list starts with the home goods
    const goods: Goods[] = home.goods !== null ? home.goods : [];
    this.list = goods;
    this.loadMoreState = goods.length > 0 ? LoadMoreState.PullToLoad : LoadMoreState.NoMore;

    if (isFirstLoading) {
      const elapsed: number = Date.now() - this.homeRequestStartTime;
      if (elapsed < MIN_LOADING_TIME_MS) {
        this.schedule((): void => {
          this.uiState = 'success';
        }, MIN_LOADING_TIME_MS - elapsed);
        return;
      }
    }
    this.uiState = 'success';
  }

  /** Parsed JSON leaves absent fields undefined (J2): map them to the model's null */
  private static normalizeHome(d: Home | null | undefined): Home {
    const h: Home = new Home();
    if (d === null || d === undefined) {
      return h;
    }
    const banner: Banner[] | null | undefined = d.banner;
    const category: Category[] | null | undefined = d.category;
    const categoryAll: Category[] | null | undefined = d.categoryAll;
    const flashSale: Goods[] | null | undefined = d.flashSale;
    const recommend: Goods[] | null | undefined = d.recommend;
    const coupon: Coupon[] | null | undefined = d.coupon;
    const goods: Goods[] | null | undefined = d.goods;
    h.banner = banner === undefined ? null : banner;
    h.category = category === undefined ? null : category;
    h.categoryAll = categoryAll === undefined ? null : categoryAll;
    h.flashSale = flashSale === undefined ? null : flashSale;
    h.recommend = recommend === undefined ? null : recommend;
    h.coupon = coupon === undefined ? null : coupon;
    h.goods = goods === undefined ? null : goods;
    return h;
  }

  /** Pull to refresh (source onRefresh override): ignored while a load is in progress */
  onRefresh(): void {
    if (this.loadMoreState === LoadMoreState.Loading) {
      return;
    }
    this.isRefreshing = true;
    this.page = 1;
    this.loadHomeData();
  }

  /** Category tap → GoodsRoutes.Category(typeId = child ids joined by ',') */
  toGoodsCategoryPage(categoryId: number): void {
    const all: Category[] = this.pageData.categoryAll !== null ? this.pageData.categoryAll : [];
    const childIds: number[] = HomeViewModel.findChildCategoryIds(categoryId, all);
    const param: GoodsCategoryParam = new GoodsCategoryParam();
    param.typeId = childIds.join(',');
    AppNavigator.navigate(Routes.GOODS_ROUTES_CATEGORY, param);
  }

  /** Show the coupon receive sheet */
  showCouponModal(): void {
    this.couponModalVisible = true;
  }

  /** Hide the coupon receive sheet */
  hideCouponModal(): void {
    this.couponModalVisible = false;
  }

  /** Sheet action: find the coupon by id among the home coupons and receive it (source onCouponAction) */
  onCouponAction(couponId: number): void {
    const coupons: Coupon[] = this.pageData.coupon !== null ? this.pageData.coupon : [];
    const found: Coupon | undefined = coupons.find((c: Coupon): boolean => c.id === couponId);
    if (found !== undefined) {
      this.receiveCoupon(found);
    }
  }

  /** Receive a coupon (login wall → login page) */
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

  /** Child category ids of `parentId` (source findChildCategoryIds) */
  private static findChildCategoryIds(parentId: number, allCategories: Category[]): number[] {
    const result: number[] = [];
    for (const c of allCategories) {
      if (c !== null && c !== undefined && c.parentId === parentId) {
        result.push(c.id);
      }
    }
    return result;
  }
}
