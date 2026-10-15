/**
 * Request models (source: core/model/request/*.kt)
 *
 * Wire rule (source Json has encodeDefaults=false): fields whose value equals the source default are
 * NOT sent. Such fields are declared optional (`?:`) so JSON.stringify omits them while undefined;
 * leave them unset when the value would equal the source default. Fields annotated @EncodeDefault in
 * the source (page/size/order/sort) carry their defaults and are always sent.
 * Kotlin nested class CreateOrderRequest.CreateOrder is flattened to CreateOrder.
 */
import { Comment } from './Goods';
import { SelectedGoods } from './Order';

/** Generic page request (all fields always sent) */
export class PageRequest {
  page: number = 1;
  size: number = 10;
  sort: string = 'desc';
}

/** Cancel order */
export class CancelOrderRequest {
  orderId: number = 0;
  remark: string = '';
}

/** Create order payload (CreateOrderRequest.CreateOrder) */
export class CreateOrder {
  /** source default "" (omit when empty) */
  remark?: string;
  addressId: number = 0;
  goodsList: SelectedGoods[] = [];
  /** source default null */
  couponId?: number;
  /** source default "" (omit when empty) */
  title?: string;
}

/** Create order */
export class CreateOrderRequest {
  data: CreateOrder = new CreateOrder();
}

/** Dict data by types */
export class DictDataRequest {
  types: string[] = [];
}

/** Submit feedback */
export class FeedbackSubmitRequest {
  /** source default "" (omit when empty) */
  contact?: string;
  type: number = 0;
  content: string = '';
  /** source default null */
  images?: string[];
}

/** Goods comment page (page/size always sent) */
export class GoodsCommentPageRequest {
  goodsId: string = '';
  page: number = 1;
  size: number = 20;
}

/** Submit goods comment */
export class GoodsCommentSubmitRequest {
  orderId: number = 0;
  data: Comment = new Comment();
}

/** Goods search (page/size always sent; others omitted when unset) */
export class GoodsSearchRequest {
  page: number = 1;
  size: number = 20;
  typeId?: number[];
  minPrice?: string;
  maxPrice?: string;
  keyWord?: string;
  order?: string;
  sort?: string;
  /** source default false (set only when true) */
  recommend?: boolean;
  /** source default false (set only when true) */
  featured?: boolean;
}

/** Customer service message page (page/size/order/sort always sent) */
export class MessagePageRequest {
  /** source default 0 (omit when 0) */
  sessionId?: number;
  page: number = 1;
  size: number = 20;
  order: string = 'createTime';
  sort: string = 'desc';
}

/** Order page (page/size always sent) */
export class OrderPageRequest {
  page: number = 1;
  size: number = 10;
  status?: number[];
}

/** QQ login */
export class QQLoginRequest {
  accessToken: string = '';
  openId: string = '';
}

/** Mark messages read */
export class ReadMessageRequest {
  ids: number[] = [];
}

/** Receive coupon */
export class ReceiveCouponRequest {
  couponId: number = 0;
}

/** Apply order refund */
export class RefundOrderRequest {
  orderId: number = 0;
  reason: string = '';
}
