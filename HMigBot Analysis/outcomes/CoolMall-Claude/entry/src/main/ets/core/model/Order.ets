/**
 * Order / cart domain models (source: core/model/entity/Order.kt, OrderGoods.kt, OrderCount.kt,
 * Logistics.kt, LogisticsItem.kt, ConfirmOrder.kt, SelectedGoods.kt, Cart.kt, CartGoodsSpec.kt)
 *
 * Kotlin nested classes Order.DiscountSource / DiscountInfo / Logistics / Refund are flattened to
 * OrderDiscountSource / OrderDiscountInfo / OrderLogistics / OrderRefund (ArkTS has no nested classes).
 */
import { Goods, GoodsSpec } from './Goods';
import { Address, Coupon } from './Market';

/** Order discount coupon info (Order.DiscountInfo) */
export class OrderDiscountInfo {
  id: number | null = null;
  num: number | null = null;
  type: number | null = null;
  title: string | null = null;
  description: string | null = null;
  amount: number | null = null;
  minAmount: number | null = null;
  startTime: string | null = null;
  endTime: string | null = null;
}

/** Order discount source (Order.DiscountSource) */
export class OrderDiscountSource {
  type: number | null = null;
  objectId: number | null = null;
  info: OrderDiscountInfo | null = null;
}

/** Order logistics summary (Order.Logistics) */
export class OrderLogistics {
  company: string | null = null;
  num: string | null = null;
}

/** Order refund info (Order.Refund) */
export class OrderRefund {
  orderNum: string | null = null;
  amount: number | null = null;
  realAmount: number | null = null;
  status: number | null = null;
  applyTime: string | null = null;
  time: string | null = null;
  reason: string | null = null;
  refuseReason: string | null = null;
}

/** Order goods line */
export class OrderGoods {
  id: number = 0;
  orderId: number = 0;
  goodsId: number = 0;
  price: number = 0;
  discountPrice: number = 0;
  count: number = 0;
  remark: string | null = null;
  goodsInfo: Goods | null = null;
  spec: GoodsSpec | null = null;
  /** 0 not commented, 1 commented */
  isComment: number = 0;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Order */
export class Order {
  id: number = 0;
  userId: number = 0;
  title: string | null = null;
  /** 0 unpaid, 1 wechat, 2 alipay */
  payType: number = 0;
  payTime: string | null = null;
  orderNum: string = '';
  /** 0 pending payment, 1 pending shipment, 2 pending receive, 3 pending review, 4 completed, 5 refunding, 6 refunded, 7 closed */
  status: number = 0;
  price: number = 0;
  discountPrice: number = 0;
  realPrice: number = 0;
  discountSource: OrderDiscountSource | null = null;
  address: Address | null = null;
  logistics: OrderLogistics | null = null;
  refund: OrderRefund | null = null;
  refundStatus: number | null = null;
  refundApplyTime: string | null = null;
  remark: string | null = null;
  closeRemark: string | null = null;
  /** 0 not invoiced, 1 invoiced */
  invoice: number = 0;
  /** 0 mini program, 1 official account, 2 app */
  wxType: number = 0;
  goodsList: OrderGoods[] | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/**
 * Order counts per status. JSON keys are the source @SerialName values (Chinese).
 * Use OrderCount.from(raw) to map the server JSON into this class.
 */
export class OrderCount {
  /** @SerialName("待付款") */
  pendingPayment: number = 0;
  /** @SerialName("待发货") */
  pendingShipment: number = 0;
  /** @SerialName("待收货") */
  pendingReceive: number = 0;
  /** @SerialName("待评价") */
  pendingReview: number = 0;
  /** @SerialName("退款中") */
  refunding: number = 0;
  /** @SerialName("已退款") */
  refunded: number = 0;

  /** Map the raw server object (Chinese keys) into an OrderCount */
  static from(raw: OrderCountJson | null | undefined): OrderCount {
    const c = new OrderCount();
    if (raw === null || raw === undefined) {
      return c;
    }
    c.pendingPayment = raw.待付款 ?? 0;
    c.pendingShipment = raw.待发货 ?? 0;
    c.pendingReceive = raw.待收货 ?? 0;
    c.pendingReview = raw.待评价 ?? 0;
    c.refunding = raw.退款中 ?? 0;
    c.refunded = raw.已退款 ?? 0;
    return c;
  }
}

/** Raw wire shape of OrderCount (keys = source @SerialName) */
export interface OrderCountJson {
  待付款?: number;
  待发货?: number;
  待收货?: number;
  待评价?: number;
  退款中?: number;
  已退款?: number;
}

/** Logistics trace item */
export class LogisticsItem {
  time: string | null = null;
  status: string | null = null;
}

/** Logistics detail */
export class Logistics {
  number: string | null = null;
  type: string | null = null;
  list: LogisticsItem[] | null = null;
  deliverystatus: string | null = null;
  issign: string | null = null;
  expName: string | null = null;
  expSite: string | null = null;
  expPhone: string | null = null;
  logo: string | null = null;
  courier: string | null = null;
  courierPhone: string | null = null;
  updateTime: string | null = null;
  takeTime: string | null = null;
}

/** Confirm order data */
export class ConfirmOrder {
  defaultAddress: Address | null = null;
  userCoupon: Coupon[] | null = [];
}

/** Selected goods for order confirmation / creation */
export class SelectedGoods {
  goodsId: number = 0;
  goodsInfo: Goods | null = null;
  spec: GoodsSpec | null = null;
  count: number = 0;
}

/** Cart goods spec */
export class CartGoodsSpec {
  id: number = 0;
  goodsId: number = 0;
  name: string = '';
  price: number = 0;
  stock: number = 0;
  count: number = 0;
  images: string[] | null = null;
}

/** Cart item (goods + specs) */
export class Cart {
  goodsId: number = 0;
  goodsName: string = '';
  goodsMainPic: string = '';
  spec: CartGoodsSpec[] = [];
}
