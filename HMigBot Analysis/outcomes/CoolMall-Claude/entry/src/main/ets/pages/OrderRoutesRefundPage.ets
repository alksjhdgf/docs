/**
 * OrderRoutesRefundPage — refund application (source: feature/order/view/OrderRefundScreen.kt +
 * viewmodel/OrderRefundViewModel.kt) — ORDB-A21~A24, A30.
 *
 * AppScaffold(large top bar `退款申请`) {
 *   NetWorkStateView(order/info/info) → Scroll { VerticalList(padding 12, spacedBy 12) {
 *     Card { AppListItem(leading TitleWithLine `退款信息`), `申请原因` (selected reason | `请选择`, arrow, click → sheet),
 *            `退款金额` (PriceText realPrice) },
 *     OrderGoodsCard × goods group (no quantity stepper)
 *   } }
 *   bottomBar (only on success): `提交`, enabled once a reason is selected
 * }
 * + DictSelectSheet `选择取消原因` bound with bindSheet; the dictionary loads once the sheet has expanded.
 * Param: OrderRefundParam(orderId). Missing param → stays on the page with an error empty state.
 * Colors are resource tokens (light/dark follow the system / app setting).
 */
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyError, NetWorkStateView } from '../core/ui/base/StateViews';
import { CommerceSheet } from '../core/ui/commerce/CommerceSheet';
import { DictSelectSheet } from '../core/ui/commerce/DictSelectSheet';
import { OrderGoodsCard } from '../core/ui/commerce/GoodsItems';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, PriceText } from '../core/ui/widget/Texts';
import { Dimens } from '../core/designsystem/Dimens';
import { DictItem } from '../core/model/Market';
import { Cart, CartGoodsSpec, Order } from '../core/model/Order';
import { OrderRefundParam } from '../core/navigation/RouteParams';
import { OrderRefundViewModel } from '../feature/order/aftersale/OrderRefundViewModel';

/** ForEach key: goods id + every spec id/count shown on the card */
function cartKey(cart: Cart): string {
  let key: string = 'cart_' + cart.goodsId;
  const specs: CartGoodsSpec[] = cart.spec ?? [];
  for (const s of specs) {
    key += '_' + s.id + ':' + s.count;
  }
  return key;
}

@Builder
export function OrderRoutesRefundPageBuilder() {
  OrderRoutesRefundPage()
}

@ComponentV2
struct OrderRoutesRefundPage {
  @Local vm: OrderRefundViewModel = new OrderRefundViewModel();
  /** Route param missing / invalid → empty state, no request */
  @Local paramMissing: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (p !== undefined && p !== null && p instanceof OrderRefundParam) {
      this.vm.orderId = (p as OrderRefundParam).orderId;
      this.paramMissing = false;
      this.vm.executeRequest();
    } else {
      this.paramMissing = true;
    }
  }

  private reasonText(): ResourceStr {
    const reason: DictItem | null = this.vm.selectedRefundReason;
    if (reason !== null && reason.name !== null && reason.name !== undefined) {
      return reason.name as string;
    }
    return $r('app.string.please_select');
  }

  private realPrice(): number {
    const order: Order | null = this.vm.data;
    return order !== null ? (order.realPrice ?? 0) : 0;
  }

  @Builder
  refundInfoTitle() {
    TitleWithLine({ titleText: $r('app.string.refund_info') })
  }

  @Builder
  refundAmount() {
    PriceText({
      price: this.realPrice(),
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL
    })
  }

  /** Source OrderRefundContentView */
  @Builder
  successContent() {
    Scroll() {
      // source VerticalList: padding 12, spacedBy(12), start-aligned
      Column({ space: Dimens.spaceVerticalMedium }) {
        // M3 Card: refund info
        Column() {
          AppListItem({
            itemTitle: '',
            showArrow: false,
            hasLeadingContent: true,
            leadingContent: (): void => {
              this.refundInfoTitle()
            },
            clickable: false
          })
          AppListItem({
            itemTitle: $r('app.string.refund_reason'),
            trailingText: this.reasonText(),
            showArrow: true,
            onItemClick: () => {
              this.vm.showRefundModal();
            }
          })
          AppListItem({
            itemTitle: $r('app.string.refund_amount'),
            showDivider: false,
            showArrow: false,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.refundAmount()
            },
            clickable: false
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)

        // order goods cards (grouped by goods)
        ForEach(this.vm.cartList, (cart: Cart) => {
          Column() {
            OrderGoodsCard({
              data: cart,
              enableQuantityStepper: false
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (cart: Cart) => cartKey(cart))
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    // lets the large top bar collapse first (AppScaffold contract)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  @Builder
  pageContent() {
    if (this.paramMissing) {
      EmptyError()
    } else {
      NetWorkStateView({
        uiState: this.vm.uiState,
        onRetry: () => {
          this.vm.retryRequest();
        },
        content: (): void => {
          this.successContent()
        }
      })
    }
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.submit'),
      btnEnabled: this.vm.selectedRefundReason !== null,
      onBtnClick: () => {
        this.vm.submitRefundApplication();
      }
    })
  }

  /** Refund reason sheet (source DictSelectModal) */
  @Builder
  reasonSheet() {
    DictSelectSheet({
      sheetTitle: $r('app.string.select_cancel_reason'),
      dictUiState: this.vm.refundReasonsUiState,
      dictItems: this.vm.refundReasons,
      selectedItem: this.vm.selectedRefundReason,
      onDismiss: () => {
        this.vm.hideRefundModal();
      },
      onConfirm: (item: DictItem | null) => {
        this.vm.selectRefundReason(item);
      },
      onRetry: () => {
        this.vm.loadRefundReasons();
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.order_refund'),
          useLargeTopBar: true,
          hasBottomBar: !this.paramMissing && this.vm.uiState === 'success',
          bottomBar: (): void => {
            this.bottomBar()
          },
          content: (): void => {
            this.pageContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet(this.vm.refundModalVisible, this.reasonSheet(),
        CommerceSheet.options(() => {
          this.vm.hideRefundModal();
        }, () => {
          this.vm.onRefundModalExpanded();
        }))
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
