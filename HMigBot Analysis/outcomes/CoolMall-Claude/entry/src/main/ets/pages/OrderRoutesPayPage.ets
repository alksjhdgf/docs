/**
 * OrderRoutesPayPage — cashier (source: feature/order/view/OrderPayScreen.kt +
 * viewmodel/OrderPayViewModel.kt) — ORDB-A01, A02, A15~A20.
 *
 * AppScaffold(large top bar `收银台`, back → handleBackClick) {
 *   VerticalList(scroll, padding 12, spacedBy 12) {
 *     8vp · CenterRow(baseline) { `¥` · price (42fp bold, danger) · `.00` } · 8vp
 *     Card { `支付宝支付` (checked) · `微信支付` · `QQ支付` (unchecked, not switchable) }
 *     `提示：实际支付金额经过处理，都是一分钱` (tertiary, bodySmall)
 *   }
 *   bottomBar: AppBottomButton `去支付 ¥<price>` (price > 0) | `去支付` → vm.startAlipayPayment
 * }
 * System back is intercepted (source BackHandler) and routed to vm.handleBackClick (ORDB-A20).
 * Param: OrderPayParam(orderId, price, from). Missing param → stays on the page with an error empty state.
 */
import { common } from '@kit.AbilityKit';
import { Dimens } from '../core/designsystem/Dimens';
import { OrderPayParam } from '../core/navigation/RouteParams';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyError } from '../core/ui/base/StateViews';
import { AppBottomButton, CheckButton } from '../core/ui/widget/Buttons';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { OrderPayViewModel } from '../feature/order/confirm/OrderPayViewModel';

/** Source Text(fontSize = 42.sp, Bold, ColorDanger) */
const PAY_PRICE_FONT_SIZE: number = 42;
const PAY_ICON_SIZE: number = 24;
const PAY_CHECK_SIZE: number = 22;

@Builder
export function OrderRoutesPayPageBuilder() {
  OrderRoutesPayPage()
}

@ComponentV2
struct OrderRoutesPayPage {
  @Local vm: OrderPayViewModel = new OrderPayViewModel();
  /** Route param missing / invalid → empty state */
  @Local paramMissing: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (p !== undefined && p !== null && p instanceof OrderPayParam) {
      this.vm.setRoute(p as OrderPayParam);
      this.paramMissing = false;
    } else {
      this.paramMissing = true;
    }
  }

  private abilityContext(): common.UIAbilityContext | null {
    try {
      const ctx: Context | undefined = this.getUIContext().getHostContext();
      return ctx !== undefined ? (ctx as common.UIAbilityContext) : null;
    } catch (e) {
      return null;
    }
  }

  private onBack(): void {
    if (this.paramMissing) {
      AppNavigator.back();
    } else {
      this.vm.handleBackClick();
    }
  }

  private payButtonText(): ResourceStr {
    const price: number = this.vm.orderPayRoute.price;
    return price > 0 ? $r('app.string.order_pay_button_with_price', price) : $r('app.string.order_pay_button');
  }

  // ============================== Content ==============================

  @Builder
  payIcon(icon: Resource) {
    Image(icon)
      .width(PAY_ICON_SIZE)
      .height(PAY_ICON_SIZE)
      .objectFit(ImageFit.Contain)
  }

  @Builder
  payCheck(selected: boolean) {
    // source CheckButton(onClick = {}): fixed state, not switchable
    CheckButton({ isSelected: selected, checkSize: PAY_CHECK_SIZE, clickable: false })
  }

  @Builder
  alipayIcon() {
    this.payIcon($r('app.media.ic_alipay'))
  }

  @Builder
  wechatIcon() {
    this.payIcon($r('app.media.ic_wechat'))
  }

  @Builder
  qqIcon() {
    this.payIcon($r('app.media.ic_qq'))
  }

  @Builder
  checkedMark() {
    this.payCheck(true)
  }

  @Builder
  uncheckedMark() {
    this.payCheck(false)
  }

  /** CenterRow { `¥` · price · `.00` } baseline aligned (single Text with spans) */
  @Builder
  priceRow() {
    Row() {
      Text() {
        Span('¥')
          .fontSize(AppTextStyles.fontSize(AppTextSize.DISPLAY_LARGE))
          .fontWeight(AppTextStyles.fontWeight(AppTextSize.DISPLAY_LARGE))
          .fontColor(AppTextStyles.color(AppTextType.ERROR))
          .letterSpacing(2) // source padding(end = 2.dp)
        Span(String(this.vm.orderPayRoute.price))
          .fontSize(PAY_PRICE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTextStyles.color(AppTextType.ERROR))
        Span('.00')
          .fontSize(AppTextStyles.fontSize(AppTextSize.DISPLAY_LARGE))
          .fontWeight(AppTextStyles.fontWeight(AppTextSize.DISPLAY_LARGE))
          .fontColor(AppTextStyles.color(AppTextType.ERROR))
      }
      .maxLines(1)
    }
    .width('100%')
    // CenterRow: horizontally centered, vertically centered
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  payMethodCard() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.pay_method_alipay'),
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.alipayIcon()
        },
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.checkedMark()
        },
        showArrow: false,
        clickable: false
      })
      AppListItem({
        itemTitle: $r('app.string.pay_method_wechat'),
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.wechatIcon()
        },
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.uncheckedMark()
        },
        showArrow: false,
        clickable: false
      })
      AppListItem({
        itemTitle: $r('app.string.pay_method_qq'),
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.qqIcon()
        },
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.uncheckedMark()
        },
        showArrow: false,
        clickable: false
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** Source OrderPayContentView: VerticalList(fillMaxSize, verticalScroll) */
  @Builder
  payContent() {
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        // SpaceVerticalSmall
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalSmall)
        this.priceRow()
        // SpaceVerticalSmall
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalSmall)
        this.payMethodCard()
        Text($r('app.string.order_pay_tip'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
          .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
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
  pageContent() {
    if (this.paramMissing) {
      EmptyError()
    } else {
      this.payContent()
    }
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: this.payButtonText(),
      onBtnClick: () => {
        this.vm.startAlipayPayment(this.abilityContext());
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.order_pay'),
          useLargeTopBar: true,
          hasBottomBar: !this.paramMissing,
          onBack: () => {
            this.onBack();
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
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
    .onBackPressed((): boolean => {
      // source BackHandler { viewModel.handleBackClick() }
      this.onBack();
      return true;
    })
  }
}
