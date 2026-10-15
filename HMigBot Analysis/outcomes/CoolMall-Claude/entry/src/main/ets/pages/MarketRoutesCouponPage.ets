/**
 * MarketRoutesCouponPage — my coupons (source: feature/market/view/CouponScreen.kt +
 * viewmodel/CouponViewModel.kt) — USER-A30~A33.
 *
 * AppScaffold(top bar `我的优惠券`, back; the built-in top bar pads the status bar — USER-A30) {
 *   NetWorkStateView(list state: loading → CouponLoadingSkeleton (3 cards) | error → retry | empty → retry)
 *     success → RefreshList (pull to refresh + load more) { CouponCard(mode VIEW, `去使用` → goods category
 *     with minPrice = coupon.condition.fullAmount) }
 * }
 * Coupon receiving (USER-A34) lives on Home / GoodsDetail, not here.
 */
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { Coupon } from '../core/model/Market';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { RefreshList } from '../core/ui/base/RefreshList';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { CouponCard, CouponCardMode } from '../core/ui/commerce/CouponCard';
import { CouponViewModel } from '../feature/market/CouponViewModel';
import { CouponLoadingSkeleton } from '../feature/market/CouponSkeleton';

@Builder
export function MarketRoutesCouponPageBuilder() {
  MarketRoutesCouponPage()
}

@ComponentV2
struct MarketRoutesCouponPage {
  @Local vm: CouponViewModel = new CouponViewModel();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  @Builder
  couponItem(item: Object, index: number) {
    Column() {
      CouponCard({
        coupon: item as Coupon,
        mode: CouponCardMode.VIEW,
        onActionClick: () => {
          this.vm.navigateToGoodsCategory(item as Coupon);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  skeleton() {
    CouponLoadingSkeleton()
  }

  @Builder
  listContent() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      itemKey: (item: Object, index: number): string => {
        const c: Coupon = item as Coupon;
        return 'coupon_' + index + '_' + c.id + '_' + c.useStatus + '_' + c.endTime + '_' + c.amount;
      },
      itemBuilder: (item: Object, index: number): void => {
        this.couponItem(item, index)
      }
    })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      useCustomLoading: true,
      onRetry: () => {
        this.vm.retryRequest();
      },
      customLoading: (): void => {
        this.skeleton()
      },
      content: (): void => {
        this.listContent()
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.coupon_title'),
          content: (): void => {
            this.pageContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
  }
}
