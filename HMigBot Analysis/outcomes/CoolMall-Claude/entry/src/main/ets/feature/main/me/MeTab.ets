/**
 * MeTab — "我的" tab (source: feature/main/view/MeScreen.kt MeRoute/MeScreen/MeContentView + sections).
 *
 * Layout (source VerticalList: padding 12, spacedBy 12, start-aligned, verticalScroll):
 *   spacer 12 → user area → member card → order card → [footprint card] → function menu card → settings card
 * Lifecycle: the source registers MeViewModel as a LifecycleObserver of the hosting nav entry, so
 * onResume (order statistics) runs when the tab is composed, whenever the main page comes back to the top,
 * and when the app returns to the foreground while the main page is on top. Here: aboutToAppear +
 * NavDestination ON_SHOWN of the hosting page + application foreground (only when the hosting page is top).
 * Status bar: Scaffold(topBar = {}) content padding → AvoidArea.top; navigation bar excluded (shell bottom bar).
 */
import { common, ApplicationStateChangeCallback } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { AppRouter, NoParam, Routes } from '../../../common/Router';
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Footprint } from '../../../core/model/Market';
import { OrderCount } from '../../../core/model/Order';
import { User } from '../../../core/model/User';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { AddressListParam, GoodsDetailParam, OrderListParam } from '../../../core/navigation/RouteParams';
import { AvoidArea } from '../../../core/ui/base/AvoidArea';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { Avatar, NetWorkImage } from '../../../core/ui/widget/Images';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';
import { LogUtils } from '../../../core/util/LogUtils';
import { MeColors } from './MeColors';
import { MeViewModel } from './MeViewModel';
import { OrderStatusItem } from './OrderStatusItem';

const TAG: string = 'MeTab';
/** Two resume triggers (ON_SHOWN + app foreground) closer than this collapse into one onResume */
const RESUME_DEDUP_MS: number = 500;

@ComponentV2
export struct MeTab {
  @Local vm: MeViewModel = new MeViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();

  private lastResumeAt: number = 0;
  private navCallback: ((info: uiObserver.NavDestinationInfo) => void) | null = null;
  private appStateCallback: ApplicationStateChangeCallback | null = null;
  private appContext: common.ApplicationContext | null = null;

  aboutToAppear(): void {
    // Observer added to a resumed owner replays ON_RESUME (source DisposableEffect addObserver)
    this.dispatchResume();
    this.registerLifecycle();
  }

  aboutToDisappear(): void {
    this.unregisterLifecycle();
    this.vm.dispose();
  }

  private dispatchResume(): void {
    const now = Date.now();
    if (now - this.lastResumeAt < RESUME_DEDUP_MS) {
      return;
    }
    this.lastResumeAt = now;
    this.vm.onResume();
  }

  /** Whether the NavDestination hosting this tab is the top of the navigation stack */
  private isHostOnTop(): boolean {
    const info = this.queryNavDestinationInfo();
    if (info === undefined || info === null) {
      return true;
    }
    return info.index === AppRouter.stack.size() - 1;
  }

  private registerLifecycle(): void {
    const navCb = (info: uiObserver.NavDestinationInfo): void => {
      if (info.state !== uiObserver.NavDestinationState.ON_SHOWN) {
        return;
      }
      const host = this.queryNavDestinationInfo();
      if (host === undefined || host === null || host.navDestinationId !== info.navDestinationId) {
        return;
      }
      this.dispatchResume();
    };
    this.navCallback = navCb;
    try {
      this.getUIContext().getUIObserver().on('navDestinationUpdate', navCb);
    } catch (e) {
      LogUtils.eTag(TAG, 'register navDestinationUpdate failed: ' + ((e as Error)?.message ?? ''));
    }

    const onForeground = (): void => {
      if (this.isHostOnTop()) {
        this.dispatchResume();
      }
    };
    const appCb: ApplicationStateChangeCallback = {
      onApplicationForeground() {
        onForeground();
      },
      onApplicationBackground() {
        LogUtils.iTag(TAG, 'application background');
      }
    };
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined && ctx !== null) {
        const appCtx = ctx.getApplicationContext();
        appCtx.on('applicationStateChange', appCb);
        this.appContext = appCtx;
        this.appStateCallback = appCb;
      }
    } catch (e) {
      LogUtils.eTag(TAG, 'register applicationStateChange failed: ' + ((e as Error)?.message ?? ''));
    }
  }

  private unregisterLifecycle(): void {
    if (this.navCallback !== null) {
      try {
        this.getUIContext().getUIObserver().off('navDestinationUpdate', this.navCallback);
      } catch (e) {
        LogUtils.eTag(TAG, 'unregister navDestinationUpdate failed: ' + ((e as Error)?.message ?? ''));
      }
      this.navCallback = null;
    }
    if (this.appContext !== null && this.appStateCallback !== null) {
      try {
        this.appContext.off('applicationStateChange', this.appStateCallback);
      } catch (e) {
        LogUtils.eTag(TAG, 'unregister applicationStateChange failed: ' + ((e as Error)?.message ?? ''));
      }
      this.appContext = null;
      this.appStateCallback = null;
    }
  }

  // ============================== state helpers ==============================

  /** Source: (if (isLoggedIn && userInfo != null) userInfo.nickName else not_logged_in).toString();
   * userInfo is `userInfo ?: User()` there, so a logged-in user without cached info renders nickName.toString(). */
  private nickNameText(): ResourceStr {
    if (this.vm.isLoggedIn) {
      const user: User | null = this.vm.userInfo;
      const nick: string | null = user === null ? null : (user.nickName ?? null);
      return String(nick);
    }
    return $r('app.string.not_logged_in');
  }

  private hasPhone(): boolean {
    const user: User | null = this.vm.userInfo;
    if (!this.vm.isLoggedIn || user === null) {
      return false;
    }
    const phone: string | null | undefined = user.phone;
    return phone !== null && phone !== undefined && phone.length > 0;
  }

  private phoneValue(): string {
    const user: User | null = this.vm.userInfo;
    return user === null ? '' : (user.phone ?? '');
  }

  private avatarUrl(): string | null {
    const user: User | null = this.vm.userInfo;
    return user === null ? null : (user.avatarUrl ?? null);
  }

  private count(): OrderCount {
    const c: OrderCount | null = this.vm.orderCount;
    return c === null ? new OrderCount() : c;
  }

  private toOrderList(tab: string | null): void {
    AppNavigator.navigate(Routes.ORDER_ROUTES_LIST, new OrderListParam(tab));
  }

  // ============================== sections ==============================

  /** UserInfoSection — MAIN-A23 */
  @Builder
  userInfoSection() {
    Row() {
      Avatar({ avatarUrl: this.avatarUrl(), avatarSize: 72 })
      Column() {
        Text(this.nickNameText())
          .fontSize(AppTextStyles.fontSize(AppTextSize.DISPLAY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.DISPLAY_MEDIUM))
          .fontWeight(AppTextStyles.fontWeight(AppTextSize.DISPLAY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
        if (this.hasPhone()) {
          // "${stringResource(R.string.phone_number)}: ${userInfo.phone}"
          Text() {
            Span($r('app.string.phone_number'))
            Span(`: ${this.phoneValue()}`)
          }
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
            .margin({ top: Dimens.spaceVerticalXSmall })
        } else {
          Text($r('app.string.click_to_login'))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
            .margin({ top: Dimens.spaceVerticalXSmall })
        }
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalLarge })
      // source: Column(Modifier.weight(1f)) without horizontalAlignment = start
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Image($r('app.media.ic_right'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_secondary'))
    }
    .width('100%')
    // source: Row(verticalAlignment = CenterVertically), horizontal = start
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      // UserNavigator.toProfile(); login wall redirects to the login page when logged out
      AppNavigator.navigate(Routes.USER_ROUTES_PROFILE, new NoParam());
    })
  }

  /** MembershipCard — MAIN-A25 (display only) */
  @Builder
  membershipCard() {
    Row() {
      Row() {
        Image($r('app.media.ic_vip_fill'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .fillColor(MeColors.MEMBER_GOLD)
          .accessibilityText($r('app.string.member'))
        Text($r('app.string.member_benefits'))
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
          .fontWeight(FontWeight.Bold)
          .fontColor(MeColors.MEMBER_GOLD)
          .margin({ left: Dimens.spaceHorizontalSmall })
      }
      // source: plain Row {} = top / start
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)

      Text($r('app.string.activate_now'))
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor(MeColors.MEMBER_GOLD)
        .border({ width: 1, color: MeColors.MEMBER_GOLD, radius: Dimens.radiusLarge })
        .padding({
          left: Dimens.spaceHorizontalMedium,
          right: Dimens.spaceHorizontalMedium,
          top: 6,
          bottom: 6
        })
    }
    .width('100%')
    .padding({
      left: Dimens.spaceHorizontalLarge,
      right: Dimens.spaceHorizontalLarge,
      top: Dimens.spaceVerticalMedium,
      bottom: Dimens.spaceVerticalMedium
    })
    // source: SpaceBetweenRow = SpaceBetween + CenterVertically
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(MeColors.MEMBER_CARD_BG)
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** OrderSection — MAIN-A26 */
  @Builder
  orderSection() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.my_orders'),
        trailingText: $r('app.string.view_all'),
        leadingIcon: $r('app.media.ic_order_fill'),
        leadingIconTint: ThemeManager.instance.primary,
        onItemClick: (): void => this.toOrderList(null)
      })
      Row() {
        Column() {
          OrderStatusItem({
            itemIcon: $r('app.media.ic_pay'),
            itemLabel: $r('app.string.pending_payment'),
            badgeCount: this.count().pendingPayment,
            onItemClick: (): void => this.toOrderList('1')
          })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center) // weight(1f) slot; item fills it

        Column() {
          OrderStatusItem({
            itemIcon: $r('app.media.ic_receipt'),
            itemLabel: $r('app.string.pending_shipment'),
            badgeCount: this.count().pendingShipment,
            onItemClick: (): void => this.toOrderList('2')
          })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center) // weight(1f) slot; item fills it

        Column() {
          OrderStatusItem({
            itemIcon: $r('app.media.ic_logistics'),
            itemLabel: $r('app.string.pending_receipt'),
            badgeCount: this.count().pendingReceive,
            onItemClick: (): void => this.toOrderList('3')
          })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center) // weight(1f) slot; item fills it

        Column() {
          OrderStatusItem({
            itemIcon: $r('app.media.ic_message'),
            itemLabel: $r('app.string.pending_review'),
            badgeCount: this.count().pendingReview,
            onItemClick: (): void => this.toOrderList('5')
          })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center) // weight(1f) slot; item fills it

        Column() {
          OrderStatusItem({
            itemIcon: $r('app.media.ic_refund'),
            itemLabel: $r('app.string.refund_after_sale'),
            badgeCount: this.count().refunding + this.count().refunded,
            onItemClick: (): void => this.toOrderList('4')
          })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center) // weight(1f) slot; item fills it
      }
      .width('100%')
      // source: SpaceEvenlyRow (SpaceEvenly + CenterVertically); all children weight(1f)
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** MyFootprintSection — MAIN-A27 */
  @Builder
  footprintSection() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.my_footprint'),
        trailingText: $r('app.string.view_all'),
        leadingIcon: $r('app.media.ic_footprint_fill'),
        leadingIconTint: MeColors.FOOTPRINT_ORANGE,
        onItemClick: (): void => AppNavigator.navigate(Routes.USER_ROUTES_FOOTPRINT, new NoParam())
      })
      // LazyRow(spacedBy 12, padding 12) of 100x100 items → explicit height 100 + 2 * 12 (A2.6)
      List({ space: 12 }) {
        ForEach(this.vm.recentFootprints, (fp: Footprint) => {
          ListItem() {
            Stack({ alignContent: Alignment.TopStart }) {
              NetWorkImage({
                model: fp.goodsMainPic,
                imageSize: 100,
                contentScale: ImageFit.Cover,
                cornerRadius: Dimens.radiusSmall
              })
            }
            .width(100)
            .height(100)
            .backgroundColor($r('app.color.bg_content'))
            .borderRadius(Dimens.radiusSmall)
            .clip(true)
            .onClick(() => {
              AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(fp.goodsId));
            })
          }
        }, (fp: Footprint) => `${fp.goodsId}_${fp.goodsMainPic}_${fp.viewTime}`)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(100 + Dimens.spacePaddingMedium * 2)
      .padding(Dimens.spacePaddingMedium)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** FunctionMenuSection (menu card) — MAIN-A28 */
  @Builder
  functionMenuSection() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.coupons'),
        leadingIcon: $r('app.media.ic_coupon_fill'),
        leadingIconTint: MeColors.COUPON_BLUE,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: (): void => AppNavigator.navigate(Routes.MARKET_ROUTES_COUPON, new NoParam())
      })
      AppListItem({
        itemTitle: $r('app.string.shipping_address'),
        leadingIcon: $r('app.media.ic_location_fill'),
        leadingIconTint: MeColors.ADDRESS_GREEN,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: (): void => AppNavigator.navigate(Routes.USER_ROUTES_ADDRESS_LIST, new AddressListParam(false))
      })
      AppListItem({
        itemTitle: $r('app.string.online_customer_service'),
        leadingIcon: $r('app.media.ic_service_fill'),
        leadingIconTint: MeColors.SERVICE_RED,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: (): void => AppNavigator.navigate(Routes.CS_ROUTES_CHAT, new NoParam())
      })
      AppListItem({
        itemTitle: $r('app.string.feedback'),
        leadingIcon: $r('app.media.ic_creative_fill'),
        leadingIconTint: MeColors.FEEDBACK_ORANGE,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: (): void => AppNavigator.navigate(Routes.FEEDBACK_ROUTES_LIST, new NoParam())
      })
      AppListItem({
        itemTitle: $r('app.string.about_us'),
        leadingIcon: $r('app.media.ic_tip_fill'),
        leadingIconTint: MeColors.ABOUT_PURPLE,
        verticalPadding: Dimens.spaceVerticalLarge,
        showDivider: false,
        onItemClick: (): void => AppNavigator.navigate(Routes.COMMON_ROUTES_ABOUT, new NoParam())
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** Settings card (separate Card in source FunctionMenuSection) — MAIN-A28 */
  @Builder
  settingsSection() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.settings'),
        leadingIcon: $r('app.media.ic_set_fill'),
        leadingIconTint: MeColors.SETTINGS_TEAL,
        verticalPadding: Dimens.spaceVerticalLarge,
        showDivider: false,
        onItemClick: (): void => AppNavigator.navigate(Routes.COMMON_ROUTES_SETTINGS, new NoParam())
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    Scroll() {
      // VerticalList: spacedBy(12), Alignment.Start, fillMaxWidth, padding 12
      Column({ space: Dimens.spaceVerticalMedium }) {
        // SpaceVerticalMedium()
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
        this.userInfoSection()
        this.membershipCard()
        this.orderSection()
        if (this.vm.recentFootprints.length > 0) {
          this.footprintSection()
        }
        this.functionMenuSection()
        this.settingsSection()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    // source: verticalScroll content is top aligned (ui-layout-semantics §1 rule 7)
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    // Scaffold content padding: status bar on top (topBar = {}); navigation bar excluded
    .padding({ top: this.avoidArea.top })
    .backgroundColor($r('app.color.bg_page'))
  }
}
