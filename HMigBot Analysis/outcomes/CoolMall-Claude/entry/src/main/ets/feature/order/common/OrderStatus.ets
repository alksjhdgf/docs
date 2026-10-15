/**
 * OrderStatus (source: feature/order/model/OrderStatus.kt) — the 7 order-list tabs, in source order
 * (ORDA-A04): 全部 待付款 待发货 待收货 售后/退款 待评价 已完成.
 *
 * Also hosts the shared status helpers used by the order list card and the order detail page:
 * - OrderStatusUtil.tabLabel(tab): tab label resource (source labelRes)
 * - OrderStatusUtil.statusFilter(tab): order/info/page status filter (source OrderListViewModel.getStatusFilter, ORDA-A07)
 * - OrderStatusUtil.statusText(status): card status text (source OrderCard trailingText, ORDA-A12)
 * - OrderStatusUtil.parseTab(tab): route param tab → index with fallback 0 (source navKey.tab?.toIntOrNull(), ORDA-A06)
 */

export enum OrderStatus {
  ALL = 0,
  UNPAID = 1,
  UNSHIPPED = 2,
  UNRECEIVED = 3,
  AFTER_SALE = 4,
  UNEVALUATED = 5,
  COMPLETED = 6
}

/** OrderStatus.entries */
export const ORDER_STATUS_ENTRIES: OrderStatus[] = [
  OrderStatus.ALL,
  OrderStatus.UNPAID,
  OrderStatus.UNSHIPPED,
  OrderStatus.UNRECEIVED,
  OrderStatus.AFTER_SALE,
  OrderStatus.UNEVALUATED,
  OrderStatus.COMPLETED
];

export class OrderStatusUtil {
  /** Tab label (source OrderStatus.labelRes) */
  static tabLabel(tab: OrderStatus): Resource {
    switch (tab) {
      case OrderStatus.UNPAID:
        return $r('app.string.order_status_unpaid');
      case OrderStatus.UNSHIPPED:
        return $r('app.string.order_status_unshipped');
      case OrderStatus.UNRECEIVED:
        return $r('app.string.order_status_unreceived');
      case OrderStatus.AFTER_SALE:
        return $r('app.string.order_status_after_sale');
      case OrderStatus.UNEVALUATED:
        return $r('app.string.order_status_unevaluated');
      case OrderStatus.COMPLETED:
        return $r('app.string.order_status_completed_tab');
      default:
        return $r('app.string.order_status_all');
    }
  }

  /**
   * Status filter of a tab (source getStatusFilter): 全部 → null (no status field),
   * 待付款 [0], 待发货 [1], 待收货 [2], 售后/退款 [5, 6], 待评价 [3], 已完成 [4].
   */
  static statusFilter(tab: OrderStatus): number[] | null {
    switch (tab) {
      case OrderStatus.UNPAID:
        return [0];
      case OrderStatus.UNSHIPPED:
        return [1];
      case OrderStatus.UNRECEIVED:
        return [2];
      case OrderStatus.AFTER_SALE:
        return [5, 6];
      case OrderStatus.UNEVALUATED:
        return [3];
      case OrderStatus.COMPLETED:
        return [4];
      default:
        return null;
    }
  }

  /**
   * Order status text (source OrderCard trailingText): 0 待付款, 1 待发货, 2 待收货, 3 待评价, 4 交易完成,
   * 5 退款中, 6 已退款, 7 已关闭, other 未知状态.
   */
  static statusText(status: number): Resource {
    switch (status) {
      case 0:
        return $r('app.string.order_status_unpaid');
      case 1:
        return $r('app.string.order_status_unshipped');
      case 2:
        return $r('app.string.order_status_unreceived');
      case 3:
        return $r('app.string.order_status_unevaluated');
      case 4:
        return $r('app.string.order_status_completed');
      case 5:
        return $r('app.string.order_status_refunding');
      case 6:
        return $r('app.string.order_status_refunded');
      case 7:
        return $r('app.string.order_status_closed');
      default:
        return $r('app.string.order_status_unknown');
    }
  }

  /**
   * Route param tab → initial tab index (source `navKey.tab?.toIntOrNull()?.let { if (it in indices) ... }`):
   * Kotlin toIntOrNull accepts an optional sign followed by decimal digits only; anything else, or an index
   * outside 0..6, falls back to 0 (全部).
   */
  static parseTab(tab: string | null | undefined): number {
    if (tab === null || tab === undefined) {
      return 0;
    }
    const intPattern: RegExp = new RegExp('^[+-]?[0-9]+$');
    if (!intPattern.test(tab)) {
      return 0;
    }
    const value: number = parseInt(tab, 10);
    if (isNaN(value) || value < 0 || value >= ORDER_STATUS_ENTRIES.length) {
      return 0;
    }
    return value;
  }
}
