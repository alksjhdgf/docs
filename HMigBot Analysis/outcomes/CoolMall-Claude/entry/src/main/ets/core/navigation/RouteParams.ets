/**
 * RouteParams — parameter classes for every route that carries data, plus navigation result classes.
 * Source: core/navigation/**\/XxxRoutes.kt (data class constructor parameters), RefreshResultKey.kt /
 * NavigationResult.kt (RefreshResult), user/SelectAddressResultKey.kt (Address result).
 *
 * Usage (conventions A "Route parameters"): `new` a param, assign/construct fields, pass the instance to
 * AppNavigator.navigate(Routes.X, param). Pages read `ctx.pathInfo.param as Object` and narrow with
 * `instanceof`. Field names and defaults are copied from the source; nullable → `T | null`.
 * Routes without parameters use NoParam (common/Router.ets).
 */
import { Address } from '../model/Market';

// ============================== GoodsRoutes ==============================

/** GoodsRoutes.Detail(goodsId: Long) */
export class GoodsDetailParam {
  goodsId: number = 0;

  constructor(goodsId: number = 0) {
    this.goodsId = goodsId;
  }
}

/** GoodsRoutes.Comment(goodsId: Long) */
export class GoodsCommentParam {
  goodsId: number = 0;

  constructor(goodsId: number = 0) {
    this.goodsId = goodsId;
  }
}

/** GoodsRoutes.Category(typeId?, featured=false, recommend=false, keyword?, minPrice?) */
export class GoodsCategoryParam {
  /** Category ids, comma separated (source String?) */
  typeId: string | null = null;
  featured: boolean = false;
  recommend: boolean = false;
  keyword: string | null = null;
  minPrice: string | null = null;

  constructor(typeId: string | null = null, featured: boolean = false, recommend: boolean = false,
    keyword: string | null = null, minPrice: string | null = null) {
    this.typeId = typeId;
    this.featured = featured;
    this.recommend = recommend;
    this.keyword = keyword;
    this.minPrice = minPrice;
  }
}

// ============================== OrderRoutes ==============================

/** OrderRoutes.List(tab: String? = null) */
export class OrderListParam {
  tab: string | null = null;

  constructor(tab: string | null = null) {
    this.tab = tab;
  }
}

/** OrderRoutes.Detail(orderId: Long) */
export class OrderDetailParam {
  orderId: number = 0;

  constructor(orderId: number = 0) {
    this.orderId = orderId;
  }
}

/** OrderRoutes.Pay(orderId: Long, price: Int, from: String? = null) */
export class OrderPayParam {
  orderId: number = 0;
  /** Payment amount (source Int) */
  price: number = 0;
  /** Origin page marker, e.g. "confirm" */
  from: string | null = null;

  constructor(orderId: number = 0, price: number = 0, from: string | null = null) {
    this.orderId = orderId;
    this.price = price;
    this.from = from;
  }
}

/** OrderRoutes.Refund(orderId: Long) */
export class OrderRefundParam {
  orderId: number = 0;

  constructor(orderId: number = 0) {
    this.orderId = orderId;
  }
}

/** OrderRoutes.Comment(orderId: Long, goodsId: Long) */
export class OrderCommentParam {
  orderId: number = 0;
  goodsId: number = 0;

  constructor(orderId: number = 0, goodsId: number = 0) {
    this.orderId = orderId;
    this.goodsId = goodsId;
  }
}

/** OrderRoutes.Logistics(orderId: Long) */
export class OrderLogisticsParam {
  orderId: number = 0;

  constructor(orderId: number = 0) {
    this.orderId = orderId;
  }
}

// ============================== UserRoutes ==============================

/** UserRoutes.AddressList(isSelectMode: Boolean = false) */
export class AddressListParam {
  isSelectMode: boolean = false;

  constructor(isSelectMode: boolean = false) {
    this.isSelectMode = isSelectMode;
  }
}

/** UserRoutes.AddressDetail(isEditMode: Boolean = false, addressId: Long = 0L) */
export class AddressDetailParam {
  isEditMode: boolean = false;
  addressId: number = 0;

  constructor(isEditMode: boolean = false, addressId: number = 0) {
    this.isEditMode = isEditMode;
    this.addressId = addressId;
  }
}

// ============================== MainRoutes ==============================

/** MainRoutes.Cart(showBackIcon: Boolean = false) */
export class CartParam {
  showBackIcon: boolean = false;

  constructor(showBackIcon: boolean = false) {
    this.showBackIcon = showBackIcon;
  }
}

// ============================== LaunchRoutes ==============================

/** LaunchRoutes.Guide(fromSettings: Boolean = false) */
export class GuideParam {
  fromSettings: boolean = false;

  constructor(fromSettings: boolean = false) {
    this.fromSettings = fromSettings;
  }
}

// ============================== CommonRoutes ==============================

/** CommonRoutes.Web(url: String, title: String? = null) */
export class WebParam {
  url: string = '';
  title: string | null = null;

  constructor(url: string = '', title: string | null = null) {
    this.url = url;
    this.title = title;
  }
}

// ============================== Navigation results ==============================

/**
 * RefreshResult(refresh: Boolean? = null) — sent by AppNavigator.backWithRefresh().
 * refresh == true means the previous page should reload its data.
 */
export class RefreshResult {
  refresh: boolean | null = null;

  constructor(refresh: boolean | null = null) {
    this.refresh = refresh;
  }

  /** True when `r` is a RefreshResult with refresh == true */
  static isRefresh(r: Object | null | undefined): boolean {
    return r !== null && r !== undefined && r instanceof RefreshResult && (r as RefreshResult).refresh === true;
  }
}

/**
 * SelectAddressResultKey equivalent: the address picked in AddressList (isSelectMode = true),
 * returned via AppNavigator.backWithResult(new SelectAddressResult(address)).
 */
export class SelectAddressResult {
  address: Address | null = null;

  constructor(address: Address | null = null) {
    this.address = address;
  }
}
