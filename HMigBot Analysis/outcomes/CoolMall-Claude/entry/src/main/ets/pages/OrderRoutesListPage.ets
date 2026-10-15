/**
 * OrderRoutesListPage — order list (source: feature/order/view/OrderListScreen.kt OrderListRoute /
 * OrderListScreen / OrderListContentView, viewmodel/OrderListViewModel.kt). Cards ORDA-A01..A22.
 *
 * AppScaffold(title `订单列表`, back) {                            ORDA-A01 (top bar takes the status bar inset) / A03
 *   Tabs(scrollable bar: 全部 待付款 待发货 待收货 售后/退款 待评价 已完成, swipeable pages)   ORDA-A04/A05
 *     TabContent × 7 → OrderTabPage(tab state)                    ORDA-A07..A15
 * }
 * + `选择取消原因` DictSelectSheet (dictionary loaded once the sheet is shown)      ORDA-A16/A17
 * + `确认收货` dialog (closed by the view model on success)                         ORDA-A18/A19
 * + `选择要购买的商品` / `选择要评价的商品` OrderGoodsSheet                           ORDA-A20/A21
 * Login wall (ORDA-A02) is enforced by AppNavigator.navigate. Route param: OrderListParam(tab) (ORDA-A06);
 * missing / other param → tab 0. RefreshResult(refresh = true) from child pages resets all tabs (ORDA-A22).
 */
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { DictItem } from '../core/model/Market';
import { OrderListParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { CommerceSheet } from '../core/ui/commerce/CommerceSheet';
import { DictSelectSheet } from '../core/ui/commerce/DictSelectSheet';
import { OrderGoodsSheet } from '../core/ui/commerce/OrderGoodsSheet';
import { ConfirmReceiveDialog } from '../feature/order/common/ConfirmReceiveDialog';
import { ORDER_STATUS_ENTRIES, OrderStatus, OrderStatusUtil } from '../feature/order/common/OrderStatus';
import { OrderListViewModel } from '../feature/order/list/OrderListViewModel';
import { OrderTabPage } from '../feature/order/list/OrderTabPage';

/** M3 TabRow height (48dp) */
const TAB_BAR_HEIGHT: number = 48;
/** M3 Tab horizontal padding (16dp) */
const TAB_PADDING_H: number = 16;
/** M3 TabRowDefaults.SecondaryIndicator height (2dp) */
const TAB_INDICATOR_HEIGHT: number = 2;
/** Pager scroll animation */
const TAB_ANIMATION_MS: number = 300;

@Builder
export function OrderRoutesListPageBuilder() {
  OrderRoutesListPage()
}

@ComponentV2
struct OrderRoutesListPage {
  @Local vm: OrderListViewModel = new OrderListViewModel();

  private receiveDialog: ConfirmReceiveDialog = new ConfirmReceiveDialog();
  /**
   * Initial pager index (plain field, read once when the Tabs are created). Afterwards the Tabs own the
   * index and report it through onAnimationStart / onChange, so re-binding never fights a running animation.
   */
  private initialTabIndex: number = 0;

  aboutToDisappear(): void {
    this.receiveDialog.close();
    this.vm.dispose();
  }

  /** Source `if (showConfirmDialog) WeDialog(...)`: open / close the dialog with the view model flag */
  @Monitor('vm.showConfirmDialog')
  onConfirmDialogVisibleChange(monitor: IMonitor): void {
    if (this.vm.showConfirmDialog) {
      this.receiveDialog.open(this.getUIContext(), (): void => {
        this.vm.confirmReceiveOrder();
      }, (): void => {
        this.vm.hideConfirmReceiveDialog();
      });
    } else {
      this.receiveDialog.close();
    }
  }

  /** ScrollableTabRow tab: selected text_primary / unselected text_secondary (AppText PRIMARY / SECONDARY) */
  private tabBarStyle(status: OrderStatus): SubTabBarStyle {
    const indicator: IndicatorStyle = {
      color: ThemeManager.instance.primary,
      height: TAB_INDICATOR_HEIGHT,
      width: 0,
      borderRadius: 0,
      marginTop: 0
    };
    const font: Font = { size: Dimens.fontBodyLarge, weight: FontWeight.Normal };
    const label: LabelStyle = {
      font: font,
      selectedColor: $r('app.color.text_primary'),
      unselectedColor: $r('app.color.text_secondary')
    };
    const padding: Padding = { left: TAB_PADDING_H, right: TAB_PADDING_H, top: 0, bottom: 0 };
    return SubTabBarStyle.of(OrderStatusUtil.tabLabel(status))
      .indicator(indicator)
      .selectedMode(SelectedMode.INDICATOR)
      .labelStyle(label)
      .padding(padding);
  }

  // ------------------------------------------------------------------ sheets

  @Builder
  cancelSheet() {
    DictSelectSheet({
      sheetTitle: $r('app.string.select_cancel_reason'),
      dictUiState: this.vm.cancelReasonsUiState,
      dictItems: this.vm.cancelReasons,
      selectedItem: this.vm.selectedCancelReason,
      onDismiss: () => {
        this.vm.hideCancelModal();
      },
      onItemSelected: (item: DictItem) => {
        this.vm.selectCancelReason(item);
      },
      onConfirm: (item: DictItem | null) => {
        this.vm.confirmCancelOrder();
      },
      onRetry: () => {
        this.vm.loadCancelReasons();
      }
    })
  }

  @Builder
  rebuySheet() {
    OrderGoodsSheet({
      sheetTitle: $r('app.string.select_goods_to_buy'),
      buttonText: $r('app.string.rebuy'),
      cartList: this.vm.rebuyCartList,
      onItemButtonClick: (goodsId: number) => {
        this.vm.toGoodsDetail(goodsId);
      }
    })
  }

  @Builder
  commentSheet() {
    OrderGoodsSheet({
      sheetTitle: $r('app.string.select_goods_to_comment'),
      buttonText: $r('app.string.go_to_comment'),
      cartList: this.vm.commentCartList,
      onItemButtonClick: (goodsId: number) => {
        this.vm.onCommentGoodsSelected(goodsId);
      }
    })
  }

  // ------------------------------------------------------------------ content

  @Builder
  pagerContent() {
    Column() {
      if (this.vm.initialized) {
        Tabs({ barPosition: BarPosition.Start, index: this.initialTabIndex }) {
          ForEach(ORDER_STATUS_ENTRIES, (status: OrderStatus, index: number) => {
            TabContent() {
              OrderTabPage({ listVm: this.vm, tabVm: this.vm.tab(index) })
            }
            .tabBar(this.tabBarStyle(status))
          }, (status: OrderStatus) => 'order_tab_' + status)
        }
        .width('100%')
        .layoutWeight(1)
        .vertical(false)
        .scrollable(true)
        .barMode(BarMode.Scrollable)
        .barHeight(TAB_BAR_HEIGHT)
        .barBackgroundColor($r('app.color.surface'))
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 0, endMargin: 0 })
        .animationDuration(TAB_ANIMATION_MS)
        .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
          // Tab tap (source updateSelectedTab) / swipe released towards a page (source updateTabByPage)
          this.vm.updateSelectedTab(targetIndex);
        })
        .onChange((index: number) => {
          this.vm.updateSelectedTab(index);
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          Column() {
            AppScaffold({
              titleText: $r('app.string.order_list'),
              content: (): void => {
                this.pagerContent()
              }
            })
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.Start)
          .bindSheet(this.vm.commentModalVisible, this.commentSheet(),
            CommerceSheet.options((): void => {
              this.vm.hideCommentModal();
            }, undefined, $r('app.color.bg_page')))
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .bindSheet(this.vm.rebuyModalVisible, this.rebuySheet(),
          CommerceSheet.options((): void => {
            this.vm.hideRebuyModal();
          }, undefined, $r('app.color.bg_page')))
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet(this.vm.cancelModalVisible, this.cancelSheet(),
        CommerceSheet.options((): void => {
          this.vm.hideCancelModal();
        }, (): void => {
          this.vm.onCancelModalExpanded();
        }))
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      let tab: string | null = null;
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p !== undefined && p !== null && p instanceof OrderListParam) {
        const t: string | null | undefined = (p as OrderListParam).tab;
        tab = (t !== undefined) ? t : null;
      }
      this.vm.init(tab);
      this.initialTabIndex = this.vm.selectedTabIndex;
    })
  }
}
