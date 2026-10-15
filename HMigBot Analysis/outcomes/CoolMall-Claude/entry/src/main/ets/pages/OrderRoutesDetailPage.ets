/**
 * OrderRoutesDetailPage — order detail (source: feature/order/view/OrderDetailScreen.kt OrderDetailRoute /
 * OrderDetailScreen / OrderDetailContentView, viewmodel/OrderDetailViewModel.kt). Cards ORDA-A23..A30, A35.
 *
 * AppScaffold(large top bar: `订单详情` until success, then the status title; back → handleBackClick) {   A24/A30
 *   NetWorkStateView(skeleton ≥ 320 ms / network error + retry / content)                              A23
 *     Scroll { VerticalList(padding 12, spacedBy 12) {
 *       AddressCard · OrderGoodsCard × goods (no stepper) · `价格明细` · [`退款信息`] · `订单信息` } }        A25..A27
 *   bottomBar (success only): Surface(shadow) { EndRow(padding 12 + nav bar) { OrderButtons } }          A28
 * }
 * + `选择取消原因` DictSelectSheet, `确认收货` dialog, `选择要购买的商品` / `选择要评价的商品` OrderGoodsSheet  A28/A29
 * System back (onBackPressed) goes through the same handleBackClick as the top bar back.                 A30
 * Route param: OrderDetailParam(orderId); missing → stays on the page with an error empty state.
 */
import { Dimens } from '../core/designsystem/Dimens';
import { DictItem } from '../core/model/Market';
import { Cart, CartGoodsSpec, Order, OrderRefund } from '../core/model/Order';
import { OrderDetailParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { EmptyError, NetWorkStateView } from '../core/ui/base/StateViews';
import { AddressCard } from '../core/ui/commerce/AddressCard';
import { CommerceSheet } from '../core/ui/commerce/CommerceSheet';
import { DictSelectSheet } from '../core/ui/commerce/DictSelectSheet';
import { OrderGoodsCard } from '../core/ui/commerce/GoodsItems';
import { OrderGoodsSheet } from '../core/ui/commerce/OrderGoodsSheet';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType, PriceText } from '../core/ui/widget/Texts';
import { WidgetColors } from '../core/ui/widget/WidgetColors';
import { LogUtils } from '../core/util/LogUtils';
import { ConfirmReceiveDialog } from '../feature/order/common/ConfirmReceiveDialog';
import { OrderButtons } from '../feature/order/common/OrderButtons';
import { OrderDetailLoadingSkeleton } from '../feature/order/detail/OrderDetailSkeleton';
import { OrderDetailViewModel } from '../feature/order/detail/OrderDetailViewModel';

const TAG: string = 'OrderRoutesDetailPage';

@Builder
export function OrderRoutesDetailPageBuilder() {
  OrderRoutesDetailPage()
}

/** Goods card key: data version + goods + every spec id/count */
function cartKey(cart: Cart, version: number): string {
  let k: string = version + '_' + cart.goodsId;
  const specs: CartGoodsSpec[] = cart.spec ?? [];
  for (const s of specs) {
    k += '_' + s.id + ':' + s.count;
  }
  return k;
}

@ComponentV2
struct OrderRoutesDetailPage {
  @Local vm: OrderDetailViewModel = new OrderDetailViewModel();
  @Local paramMissing: boolean = false;
  @Local avoidArea: AvoidArea = AvoidArea.get();

  private receiveDialog: ConfirmReceiveDialog = new ConfirmReceiveDialog();

  aboutToDisappear(): void {
    this.receiveDialog.close();
    this.vm.dispose();
  }

  /** Source `if (showConfirmDialog) WeDialog(...)` */
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

  private onParam(p: Object | undefined): void {
    if (p !== undefined && p !== null && p instanceof OrderDetailParam) {
      this.paramMissing = false;
      this.vm.init((p as OrderDetailParam).orderId);
    } else {
      this.paramMissing = true;
    }
  }

  // ------------------------------------------------------------------ helpers

  private order(): Order | null {
    return this.vm.uiState === 'success' ? this.vm.data : null;
  }

  /** Top bar title: success → by status, otherwise `订单详情` (ORDA-A24) */
  private titleRes(): Resource {
    const order: Order | null = this.order();
    if (order === null) {
      return $r('app.string.order_detail');
    }
    switch (order.status ?? 0) {
      case 0:
        return $r('app.string.order_status_pending_payment');
      case 1:
        return $r('app.string.order_status_pending_shipment');
      case 2:
        return $r('app.string.order_status_pending_receipt');
      case 3:
        return $r('app.string.order_status_pending_comment');
      case 4:
        return $r('app.string.order_status_completed');
      case 5:
        return $r('app.string.order_status_refunding');
      case 6:
        return $r('app.string.order_status_refunded');
      case 7:
        return $r('app.string.order_status_closed');
      default:
        return $r('app.string.order_detail');
    }
  }

  private str(v: string | null | undefined): string | null {
    return (v !== null && v !== undefined) ? v : null;
  }

  /** `value ?: stringResource(none)` */
  private orNone(v: string | null | undefined): ResourceStr {
    const s: string | null = this.str(v);
    return s !== null ? s : $r('app.string.none');
  }

  /** Nullable trailing text (null → no trailing text, as AppListItem(trailingText = null)) */
  private orUndefined(v: string | null | undefined): ResourceStr | undefined {
    const s: string | null = this.str(v);
    return s !== null ? s : undefined;
  }

  private refundStatusText(status: number | null | undefined): Resource {
    switch (status) {
      case 0:
        return $r('app.string.refund_status_applying');
      case 1:
        return $r('app.string.refund_status_refunded');
      case 2:
        return $r('app.string.refund_status_rejected');
      default:
        return $r('app.string.refund_status_unknown');
    }
  }

  // ------------------------------------------------------------------ card pieces

  @Builder
  cardTitle(text: ResourceStr) {
    TitleWithLine({ titleText: text })
  }

  @Builder
  primaryPrice(price: number) {
    PriceText({
      price: price,
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL,
      priceType: AppTextType.PRIMARY
    })
  }

  @Builder
  discountPrice(price: number) {
    PriceText({
      price: price,
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL
    })
  }

  /** Order number + `复制` link (source onClick is an empty stub) */
  @Builder
  orderNumTrailing() {
    Text(this.order()?.orderNum ?? '')
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      .margin({ right: Dimens.spaceHorizontalSmall })
    Text($r('app.string.copy'))
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(AppTextType.LINK))
      .margin({ right: Dimens.spaceHorizontalXSmall })
      .onClick(() => {
        // Source: onClick = { /* 复制订单号 */ } (no-op stub)
        LogUtils.iTag(TAG, 'copy order number: source stub, no action');
      })
  }

  @Builder
  priceCard(order: Order) {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.cardTitle($r('app.string.price_detail'))
        }
      })
      AppListItem({
        itemTitle: $r('app.string.goods_total_price'),
        leadingIcon: $r('app.media.ic_shop'),
        showArrow: false,
        clickable: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.primaryPrice(this.order()?.price ?? 0)
        }
      })
      AppListItem({
        itemTitle: $r('app.string.discount_amount'),
        leadingIcon: $r('app.media.ic_coupon'),
        description: this.order()?.discountSource?.info?.title ?? '',
        showArrow: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.discountPrice(this.order()?.discountPrice ?? 0)
        },
        onItemClick: () => {
          // Source: onClick = { /* 选择优惠券 */ } (no-op stub)
          LogUtils.iTag(TAG, 'discount row: source stub, no action');
        }
      })
      AppListItem({
        itemTitle: $r('app.string.actual_payment'),
        leadingIcon: $r('app.media.ic_money'),
        showArrow: false,
        showDivider: false,
        clickable: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.primaryPrice((this.order()?.price ?? 0) - (this.order()?.discountPrice ?? 0))
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  refundCard(refund: OrderRefund) {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.cardTitle($r('app.string.refund_info'))
        }
      })
      AppListItem({
        itemTitle: $r('app.string.refund_amount'),
        showArrow: false,
        clickable: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          // refund.amount?.toInt() ?: 0
          this.primaryPrice(Math.trunc(this.order()?.refund?.amount ?? 0))
        }
      })
      AppListItem({
        itemTitle: $r('app.string.refund_status'),
        showArrow: false,
        clickable: false,
        trailingText: this.refundStatusText(refund.status)
      })
      AppListItem({
        itemTitle: $r('app.string.refund_reason'),
        showArrow: false,
        clickable: false,
        trailingText: this.orNone(refund.reason)
      })
      if (refund.status === 2) {
        AppListItem({
          itemTitle: $r('app.string.refund_reject_reason'),
          showArrow: false,
          clickable: false,
          showDivider: false,
          trailingText: this.orNone(refund.refuseReason)
        })
      } else {
        AppListItem({
          itemTitle: $r('app.string.refund_apply_time'),
          showArrow: false,
          clickable: false,
          showDivider: false,
          trailingText: this.orNone(refund.applyTime)
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  infoCard(order: Order) {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.cardTitle($r('app.string.order_info'))
        }
      })
      // Row stays hit-testable so the `复制` link receives taps (the row itself has no action)
      AppListItem({
        itemTitle: $r('app.string.order_number'),
        showArrow: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.orderNumTrailing()
        }
      })
      AppListItem({
        itemTitle: $r('app.string.payment_method'),
        showArrow: false,
        clickable: false,
        trailingText: $r('app.string.wechat')
      })
      AppListItem({
        itemTitle: $r('app.string.payment_time'),
        showArrow: false,
        clickable: false,
        trailingText: this.str(order.payTime) ?? $r('app.string.unpaid')
      })
      AppListItem({
        itemTitle: $r('app.string.order_time'),
        showArrow: false,
        clickable: false,
        trailingText: this.orUndefined(order.createTime)
      })
      AppListItem({
        itemTitle: $r('app.string.order_remark'),
        showArrow: false,
        clickable: false,
        trailingText: this.orNone(order.remark)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  // ------------------------------------------------------------------ content

  @Builder
  successContent() {
    Scroll() {
      if (this.order() !== null) {
        Column({ space: Dimens.spacePaddingMedium }) {
          Column() {
            AddressCard({ address: this.order()?.address ?? null })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          ForEach(this.vm.cartList, (cart: Cart) => {
            Column() {
              OrderGoodsCard({ data: cart, enableQuantityStepper: false })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (cart: Cart) => cartKey(cart, this.vm.dataVersion))

          this.priceCard(this.order() as Order)

          if (this.order()?.refund !== null && this.order()?.refund !== undefined) {
            this.refundCard(this.order()?.refund as OrderRefund)
          }

          this.infoCard(this.order() as Order)
        }
        .width('100%')
        .padding(Dimens.spacePaddingMedium)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
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
  loadingSkeleton() {
    OrderDetailLoadingSkeleton()
  }

  @Builder
  pageContent() {
    if (this.paramMissing) {
      EmptyError()
    } else {
      NetWorkStateView({
        uiState: this.vm.uiState,
        useCustomLoading: true,
        customLoading: (): void => {
          this.loadingSkeleton()
        },
        onRetry: () => {
          this.vm.retryRequest();
        },
        content: (): void => {
          this.successContent()
        }
      })
    }
  }

  /** Source bottomBar: Surface(shadow 4dp) { EndRow(padding 12, navigationBarsPadding) { OrderButtons } } */
  @Builder
  bottomBar() {
    Row() {
      OrderButtons({
        orderStatus: this.order()?.status ?? 0,
        onCancelClick: () => {
          this.vm.cancelOrder();
        },
        onPayClick: () => {
          this.vm.navigateToPayment();
        },
        onRefundClick: () => {
          this.vm.toOrderRefund();
        },
        onConfirmClick: () => {
          this.vm.confirmOrder();
        },
        onLogisticsClick: () => {
          this.vm.toOrderLogistics();
        },
        onCommentClick: () => {
          this.vm.toOrderComment();
        },
        onRebuyClick: () => {
          this.vm.handleRebuy();
        }
      })
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingMedium,
      bottom: Dimens.spacePaddingMedium + this.avoidArea.bottom
    })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .shadow({ radius: 8, color: WidgetColors.SHADOW, offsetX: 0, offsetY: -2 })
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
      cartList: this.vm.cartList,
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
      cartList: this.vm.cartList,
      onItemButtonClick: (goodsId: number) => {
        this.vm.toOrderCommentForGoods(goodsId);
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          Column() {
            AppScaffold({
              titleText: this.titleRes(),
              useLargeTopBar: true,
              hasBottomBar: !this.paramMissing && this.vm.uiState === 'success',
              onBack: () => {
                this.vm.handleBackClick();
              },
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
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
    .onBackPressed((): boolean => {
      // source BackHandler { viewModel.handleBackClick() }
      this.vm.handleBackClick();
      return true;
    })
  }
}
