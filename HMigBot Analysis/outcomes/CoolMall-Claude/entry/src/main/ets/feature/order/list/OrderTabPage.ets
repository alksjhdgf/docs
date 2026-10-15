/**
 * OrderTabPage — one pager page of the order list (source: OrderListContentView's HorizontalPager page:
 * BaseNetWorkListView(customLoading = OrderListLoadingSkeleton) { OrderTabContent → RefreshLayout { OrderCard } }).
 *
 * - 'loading' → OrderListLoadingSkeleton; 'empty' → EmptyData; 'error' → EmptyNetwork, retry → page 1 (ORDA-A09)
 * - 'success' → RefreshList (pull-to-refresh ORDA-A10, load more within the last 3 items ORDA-A11)
 * - card actions are forwarded to OrderListViewModel (ORDA-A12..A21)
 */
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { Order } from '../../../core/model/Order';
import { NetWorkStateView } from '../../../core/ui/base/StateViews';
import { RefreshList } from '../../../core/ui/base/RefreshList';
import { OrderCard } from './OrderCard';
import { OrderListLoadingSkeleton } from './OrderListSkeleton';
import { OrderListViewModel } from './OrderListViewModel';
import { OrderTabViewModel } from './OrderTabViewModel';

@ComponentV2
export struct OrderTabPage {
  /** Page view model (actions / navigation) */
  @Param listVm: OrderListViewModel | null = null;
  /** This page's tab state */
  @Param tabVm: OrderTabViewModel = new OrderTabViewModel(0, null);

  private listScroller: Scroller = new Scroller();

  @Builder
  skeleton() {
    OrderListLoadingSkeleton()
  }

  @Builder
  orderItem(item: Object, index: number) {
    OrderCard({
      order: item as Order,
      onCardClick: () => {
        this.listVm?.toOrderDetail((item as Order).id);
      },
      onCancelClick: () => {
        this.listVm?.cancelOrder((item as Order).id);
      },
      onPayClick: () => {
        this.listVm?.toPay(item as Order);
      },
      onRefundClick: () => {
        this.listVm?.toRefund((item as Order).id);
      },
      onConfirmClick: () => {
        this.listVm?.showConfirmReceiveDialog((item as Order).id);
      },
      onLogisticsClick: () => {
        this.listVm?.toLogistics((item as Order).id);
      },
      onCommentClick: () => {
        this.listVm?.handleOrderComment(item as Order);
      },
      onRebuyClick: () => {
        this.listVm?.handleRebuy(item as Order);
      }
    })
  }

  @Builder
  listContent() {
    RefreshList({
      listVm: this.tabVm as BaseNetWorkListViewModel<Object>,
      listScroller: this.listScroller,
      itemKey: (item: Object, index: number): string => {
        const o: Order = item as Order;
        return 'order_' + index + '_' + o.id + '_' + o.status + '_' + o.price + '_' + o.orderNum;
      },
      itemBuilder: (item: Object, index: number): void => {
        this.orderItem(item, index)
      }
    })
  }

  build() {
    Column() {
      NetWorkStateView({
        uiState: this.tabVm.uiState,
        useCustomLoading: true,
        onRetry: () => {
          this.tabVm.retryRequest();
        },
        customLoading: (): void => {
          this.skeleton()
        },
        content: (): void => {
          this.listContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
