/**
 * OrderRoutesLogisticsPage — order logistics (source: feature/order/view/OrderLogisticsScreen.kt
 * OrderLogisticsRoute / OrderLogisticsScreen / OrderLogisticsContentView,
 * viewmodel/OrderLogisticsViewModel.kt). Cards ORDA-A31..A35.
 *
 * AppScaffold(large top bar `物流详情`, back → plain back) {                                 A31
 *   NetWorkStateView(order info: skeleton ≥ 320 ms / network error + retry / content)       A31/A32
 *     Scroll { VerticalList(padding 12, spacedBy 12) {
 *       AddressCard(order.address)                                                         A33
 *       `物流信息` card { title + 18vp express logo, `快递公司` (`未知快递`), `物流编号` + `复制`,
 *                        `快递员`, `联系电话` + `拨打`, `运输耗时` }                               A33
 *       `物流轨迹` card { LogisticsSteps(list, padding 12) }                                   A34
 *     } }
 * }
 * Order info and logistics are requested in parallel; a logistics failure only toasts (A32).
 * Route param: OrderLogisticsParam(orderId); missing → stays on the page with an error empty state.
 */
import { Dimens } from '../core/designsystem/Dimens';
import { Logistics, LogisticsItem, Order } from '../core/model/Order';
import { OrderLogisticsParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyError, NetWorkStateView } from '../core/ui/base/StateViews';
import { AddressCard } from '../core/ui/commerce/AddressCard';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { NetWorkImage } from '../core/ui/widget/Images';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { LogUtils } from '../core/util/LogUtils';
import { LogisticsSteps } from '../feature/order/detail/LogisticsSteps';
import { OrderLogisticsLoadingSkeleton } from '../feature/order/detail/OrderLogisticsSkeleton';
import { OrderLogisticsViewModel } from '../feature/order/detail/OrderLogisticsViewModel';

const TAG: string = 'OrderRoutesLogisticsPage';
/** Express logo size 18.dp */
const LOGO_SIZE: number = 18;

@Builder
export function OrderRoutesLogisticsPageBuilder() {
  OrderRoutesLogisticsPage()
}

@ComponentV2
struct OrderRoutesLogisticsPage {
  @Local vm: OrderLogisticsViewModel = new OrderLogisticsViewModel();
  @Local paramMissing: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (p !== undefined && p !== null && p instanceof OrderLogisticsParam) {
      this.paramMissing = false;
      this.vm.init((p as OrderLogisticsParam).orderId);
    } else {
      this.paramMissing = true;
    }
  }

  private order(): Order | null {
    return this.vm.uiState === 'success' ? this.vm.data : null;
  }

  private logistics(): Logistics {
    return this.vm.logistics;
  }

  private str(v: string | null | undefined): string | null {
    return (v !== null && v !== undefined) ? v : null;
  }

  /** Nullable trailing text (null → no trailing text) */
  private orUndefined(v: string | null | undefined): ResourceStr | undefined {
    const s: string | null = this.str(v);
    return s !== null ? s : undefined;
  }

  /** Source `logistics.courierPhone.toString()` (a null phone renders as "null", as in source) */
  private courierPhoneText(): string {
    const phone: string | null = this.str(this.logistics().courierPhone);
    return phone !== null ? phone : 'null';
  }

  private trackItems(): LogisticsItem[] {
    const list: LogisticsItem[] | null | undefined = this.logistics().list;
    return (list !== null && list !== undefined) ? list : [];
  }

  // ------------------------------------------------------------------ pieces

  @Builder
  cardTitle(text: ResourceStr) {
    TitleWithLine({ titleText: text })
  }

  @Builder
  logoTrailing() {
    NetWorkImage({ model: this.str(this.logistics().logo), imageSize: LOGO_SIZE })
  }

  /** Secondary value + link text (source AppText SECONDARY, SpaceHorizontalSmall, AppText LINK, XSmall) */
  @Builder
  valueWithLink(value: string, link: ResourceStr, action: () => void) {
    Text(value)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      .margin({ right: Dimens.spaceHorizontalSmall })
    Text(link)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(AppTextType.LINK))
      .margin({ right: Dimens.spaceHorizontalXSmall })
      .onClick(() => {
        action();
      })
  }

  @Builder
  numberTrailing() {
    this.valueWithLink(this.str(this.logistics().number) ?? '', $r('app.string.copy'), () => {
      // Source: onClick = { /* 复制物流编号 */ } (no-op stub)
      LogUtils.iTag(TAG, 'copy logistics number: source stub, no action');
    })
  }

  @Builder
  phoneTrailing() {
    this.valueWithLink(this.courierPhoneText(), $r('app.string.call'), () => {
      // Source: onClick = { /* 拨打电话 */ } (no-op stub)
      LogUtils.iTag(TAG, 'call courier: source stub, no action');
    })
  }

  @Builder
  infoCard() {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.cardTitle($r('app.string.logistics_info'))
        },
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.logoTrailing()
        }
      })
      AppListItem({
        itemTitle: $r('app.string.express_company'),
        showArrow: false,
        clickable: false,
        trailingText: this.str(this.logistics().expName) ?? $r('app.string.unknown_express')
      })
      // Row stays hit-testable so the `复制` link receives taps
      AppListItem({
        itemTitle: $r('app.string.logistics_number'),
        showArrow: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.numberTrailing()
        }
      })
      AppListItem({
        itemTitle: $r('app.string.courier'),
        showArrow: false,
        clickable: false,
        trailingText: this.orUndefined(this.logistics().courier)
      })
      // Row stays hit-testable so the `拨打` link receives taps
      AppListItem({
        itemTitle: $r('app.string.contact_phone'),
        showArrow: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.phoneTrailing()
        }
      })
      AppListItem({
        itemTitle: $r('app.string.transport_time'),
        showArrow: false,
        clickable: false,
        showDivider: false,
        trailingText: this.orUndefined(this.logistics().takeTime)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  trackCard() {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.cardTitle($r('app.string.logistics_track'))
        }
      })
      Column() {
        LogisticsSteps({ logisticsItems: this.trackItems() })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

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

          this.infoCard()
          this.trackCard()
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
    OrderLogisticsLoadingSkeleton()
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

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.order_logistics'),
          useLargeTopBar: true,
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
  }
}
