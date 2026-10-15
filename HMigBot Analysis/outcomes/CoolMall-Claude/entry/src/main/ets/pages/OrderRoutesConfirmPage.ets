/**
 * OrderRoutesConfirmPage — confirm order (source: feature/order/view/OrderConfirmScreen.kt +
 * viewmodel/OrderConfirmViewModel.kt) — ORDB-A01~A14.
 *
 * AppScaffold(large top bar `确认订单`, avoids the status bar) {
 *   NetWorkStateView(page/confirmOrder; loading → OrderConfirmLoadingSkeleton, error → EmptyNetwork + retry)
 *     → Scroll { VerticalList(padding 12, spacedBy 12) {
 *         AddressCard(addressSelected; click → AddressList(isSelectMode = true), result replaces the address)
 *         OrderGoodsCard × item (no quantity stepper)
 *         Card `价格明细`: `商品总价` · `优惠券` (selected title | `选择`, click → coupon sheet) ·
 *                         `优惠券折扣` (only when > 0, negative) · `合计`
 *         AppCard(`订单备注`) { outlined multi-line input, label `订单备注`, placeholder `选填，付款后商家可见` }
 *     } }
 *   bottomBar (success only): total price + `提交订单`
 * }
 * + CouponModal `选择优惠券` (SELECT mode, currentPrice = goods total) bound with bindSheet.
 * Login wall (ORDB-A02) is applied by AppNavigator when navigating here.
 */
import { Routes } from '../common/Router';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { Coupon } from '../core/model/Market';
import { Cart, CartGoodsSpec } from '../core/model/Order';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AddressListParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AddressCard } from '../core/ui/commerce/AddressCard';
import { CommerceSheet } from '../core/ui/commerce/CommerceSheet';
import { CouponCardMode } from '../core/ui/commerce/CouponCard';
import { CouponModal } from '../core/ui/commerce/CouponSheets';
import { OrderGoodsCard } from '../core/ui/commerce/GoodsItems';
import { AppCard, TitleWithLine } from '../core/ui/widget/AppCard';
import { AppButtonFixed, AppButtonShape, AppButtonSize, AppButtonStyle } from '../core/ui/widget/Buttons';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, AppTextType, PriceText } from '../core/ui/widget/Texts';
import { WidgetColors } from '../core/ui/widget/WidgetColors';
import { OrderConfirmLoadingSkeleton } from '../feature/order/confirm/OrderConfirmSkeleton';
import { OrderConfirmViewModel } from '../feature/order/confirm/OrderConfirmViewModel';

/** Remark field: minLines 3 / maxLines 5 of bodyLarge (22vp line) + 8vp vertical padding each side */
const REMARK_MIN_HEIGHT: number = 3 * Dimens.lineBodyLarge + 16;
const REMARK_MAX_HEIGHT: number = 5 * Dimens.lineBodyLarge + 16;

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
export function OrderRoutesConfirmPageBuilder() {
  OrderRoutesConfirmPage()
}

@ComponentV2
struct OrderRoutesConfirmPage {
  @Local vm: OrderConfirmViewModel = new OrderConfirmViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();
  /** Remark field focus (outlined field focused border / label color) */
  @Local remarkFocused: boolean = false;

  aboutToAppear(): void {
    try {
      const ctx: Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.vm.purchaseTitle = ctx.resourceManager.getStringSync($r('app.string.purchase_goods').id);
      }
    } catch (e) {
      // keep the default `购买商品` title when the resource cannot be resolved
      this.vm.purchaseTitle = '购买商品';
    }
    this.vm.init();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private toAddressList(): void {
    AppNavigator.navigate(Routes.USER_ROUTES_ADDRESS_LIST, new AddressListParam(true), (r: Object): void => {
      this.vm.onNavResult(r);
    });
  }

  private couponTrailingText(): ResourceStr {
    const c: Coupon | null = this.vm.selectedCoupon;
    if (c !== null && c.title !== null && c.title !== undefined) {
      return c.title;
    }
    return $r('app.string.coupon_select');
  }

  private selectedCouponId(): number {
    const c: Coupon | null = this.vm.selectedCoupon;
    return c !== null ? c.id : -1;
  }

  // ============================== Price detail ==============================

  @Builder
  priceDetailTitle() {
    TitleWithLine({ titleText: $r('app.string.price_detail') })
  }

  @Builder
  originalPriceText() {
    PriceText({
      price: this.vm.originalPrice,
      priceType: AppTextType.PRIMARY,
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL
    })
  }

  @Builder
  discountPriceText() {
    PriceText({
      price: -Math.trunc(this.vm.discountAmount),
      priceType: AppTextType.ERROR,
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL
    })
  }

  @Builder
  totalPriceText() {
    PriceText({
      price: this.vm.totalPrice,
      priceType: AppTextType.PRIMARY,
      integerTextSize: AppTextSize.BODY_LARGE,
      decimalTextSize: AppTextSize.BODY_SMALL,
      symbolTextSize: AppTextSize.BODY_SMALL
    })
  }

  /** M3 Card with the price rows */
  @Builder
  priceDetailCard() {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.priceDetailTitle()
        },
        clickable: false
      })
      AppListItem({
        itemTitle: $r('app.string.goods_total_price'),
        leadingIcon: $r('app.media.ic_shop'),
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.originalPriceText()
        },
        showArrow: false,
        clickable: false
      })
      AppListItem({
        itemTitle: $r('app.string.coupon'),
        leadingIcon: $r('app.media.ic_coupon'),
        trailingText: this.couponTrailingText(),
        showArrow: true,
        onItemClick: () => {
          this.vm.showCouponModal();
        }
      })
      if (this.vm.discountAmount > 0) {
        AppListItem({
          itemTitle: $r('app.string.coupon_discount'),
          leadingIcon: $r('app.media.ic_refund'),
          hasTrailingContent: true,
          trailingContent: (): void => {
            this.discountPriceText()
          },
          showArrow: false,
          clickable: false
        })
      }
      AppListItem({
        itemTitle: $r('app.string.total'),
        leadingIcon: $r('app.media.ic_money'),
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.totalPriceText()
        },
        showArrow: false,
        showDivider: false,
        clickable: false
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  // ============================== Remark ==============================

  /** OutlinedTextField(label, placeholder, minLines 3, maxLines 5, padding top 8) */
  @Builder
  remarkField() {
    Stack({ alignContent: Alignment.TopStart }) {
      TextArea({ text: this.vm.remark, placeholder: $r('app.string.order_remark_placeholder') })
        .width('100%')
        .constraintSize({ minHeight: REMARK_MIN_HEIGHT, maxHeight: REMARK_MAX_HEIGHT })
        .margin({ top: 8 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .fontSize(Dimens.fontBodyLarge)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .placeholderFont({ size: Dimens.fontBodyLarge })
        .caretColor(ThemeManager.instance.primary)
        .backgroundColor(Color.Transparent)
        .borderRadius(Dimens.radiusMedium)
        .border({
          width: this.remarkFocused ? 2 : 1,
          color: this.remarkFocused ? ThemeManager.instance.primary : $r('app.color.text_tertiary')
        })
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.vm.updateRemark(value);
        })
        .onFocus(() => {
          this.remarkFocused = true;
        })
        .onBlur(() => {
          this.remarkFocused = false;
        })

      // Floating label sitting on the outline (M3 OutlinedTextField label)
      Text($r('app.string.order_remark_label'))
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(16)
        .fontColor(this.remarkFocused ? ThemeManager.instance.primary : $r('app.color.text_secondary'))
        .padding({ left: 4, right: 4 })
        .backgroundColor($r('app.color.bg_card'))
        .margin({ left: 12 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .margin({ top: 8 })
  }

  // ============================== Content ==============================

  /** Source OrderConfirmContentView (VerticalList: padding 12, spacedBy 12, start aligned) */
  @Builder
  successContent() {
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        Column() {
          AddressCard({
            address: this.vm.currentAddress(),
            addressSelected: true,
            onCardClick: () => {
              this.toAddressList();
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

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

        this.priceDetailCard()

        Column() {
          AppCard({
            lineTitle: $r('app.string.order_remark_title'),
            cardContent: (): void => {
              this.remarkField()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
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
    OrderConfirmLoadingSkeleton()
  }

  @Builder
  pageContent() {
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

  // ============================== Bottom bar ==============================

  @Builder
  submitButton() {
    AppButtonFixed({
      btnText: $r('app.string.submit_order'),
      btnSize: AppButtonSize.MINI,
      btnStyle: AppButtonStyle.GRADIENT,
      btnShape: AppButtonShape.SQUARE,
      onBtnClick: () => {
        this.vm.onSubmitOrderClick();
      }
    })
  }

  /** Source OrderBottomBar: Surface(shadow 4dp) { SpaceBetweenRow(padding 12) { PriceText, `提交订单` } } */
  @Builder
  bottomBar() {
    Row() {
      PriceText({
        price: this.vm.totalPrice,
        integerTextSize: AppTextSize.DISPLAY_LARGE,
        decimalTextSize: AppTextSize.TITLE_MEDIUM,
        symbolTextSize: AppTextSize.TITLE_MEDIUM
      })
      Row() {
        this.submitButton()
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingMedium,
      // scaffold navigationBarsPadding()
      bottom: Dimens.spacePaddingMedium + this.avoidArea.bottom
    })
    // SpaceBetweenRow: horizontal SpaceBetween, vertical center
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .shadow({ radius: 8, color: WidgetColors.SHADOW, offsetX: 0, offsetY: -2 })
  }

  /** Coupon sheet (source CouponModal, SELECT mode, currentPrice = original price) */
  @Builder
  couponSheet() {
    CouponModal({
      coupons: this.vm.userCoupons(),
      sheetTitle: $r('app.string.select_coupon'),
      mode: CouponCardMode.SELECT,
      currentPrice: this.vm.originalPrice,
      selectedCouponId: this.selectedCouponId(),
      onCouponAction: (couponId: number) => {
        this.vm.selectCouponById(couponId);
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.order_confirm'),
          useLargeTopBar: true,
          contentShouldConsumePadding: true,
          hasBottomBar: this.vm.uiState === 'success',
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
      .bindSheet(this.vm.couponModalVisible, this.couponSheet(),
        CommerceSheet.options(() => {
          this.vm.hideCouponModal();
        }, undefined, $r('app.color.bg_page')))
    }
    .hideTitleBar(true)
  }
}
