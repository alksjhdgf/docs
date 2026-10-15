/**
 * Coupon card (source: core/ui/component/coupon/CouponCard.kt).
 *
 * Exports: CouponCardMode (RECEIVE / SELECT / VIEW), CouponCard, isCouponExpired().
 * Status is derived from the coupon + mode (source CouponStatus, private):
 *  USED (useStatus 1) > EXPIRED (useStatus 2 or endTime date before now) > SELECT + currentPrice + condition:
 *  INSUFFICIENT when currentPrice < fullAmount, else SELECTED/AVAILABLE > SELECT + isSelected → SELECTED > AVAILABLE.
 * Unavailable states (USED / EXPIRED / INSUFFICIENT) get a surface @ 0.4 mask over the card.
 * Action: AVAILABLE → mini button (`立即领取` / `选择` / `去使用` by mode); SELECTED → `已选择` (primary);
 * USED `已使用` / EXPIRED `已过期` / INSUFFICIENT `不满足条件` (tertiary).
 */
import { Coupon } from '../../model/Market';
import { Condition } from '../../model/Goods';
import { Dimens } from '../../designsystem/Dimens';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { WeDivider } from '../widget/AppCard';
import { PriceText, AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { AppButton, AppButtonSize } from '../widget/Buttons';

export enum CouponCardMode {
  /** 领取模式 */
  RECEIVE,
  /** 选择模式 */
  SELECT,
  /** 查看模式（我的优惠券） */
  VIEW
}

enum CouponStatus {
  AVAILABLE,
  SELECTED,
  USED,
  EXPIRED,
  INSUFFICIENT
}

/**
 * Source isExpired(endTime): SimpleDateFormat("yyyy-MM-dd").parse(endTime) (leading date only, local
 * midnight) before now; null/empty/unparseable → false.
 */
export function isCouponExpired(endTime: string | null): boolean {
  if (endTime === null || endTime.length === 0) {
    return false;
  }
  const re: RegExp = new RegExp('^\\s*(\\d{1,4})-(\\d{1,2})-(\\d{1,2})');
  const m: RegExpMatchArray | null = endTime.match(re);
  if (m === null) {
    return false;
  }
  const y: number = Number(m[1]);
  const mo: number = Number(m[2]);
  const d: number = Number(m[3]);
  if (isNaN(y) || isNaN(mo) || isNaN(d)) {
    return false;
  }
  const expire: Date = new Date(y, mo - 1, d, 0, 0, 0, 0);
  return expire.getTime() < Date.now();
}

/** colorScheme.onSurface @ 0.6 for the expand arrow */
function onSurface60(): string {
  return ThemeManager.instance.isDark ? '#99D1D1D1' : '#99181818';
}

@ComponentV2
export struct CouponCard {
  @Param coupon: Coupon = new Coupon();
  @Param mode: CouponCardMode = CouponCardMode.RECEIVE;
  /** Only meaningful in SELECT mode */
  @Param isSelected: boolean = false;
  /** Current order price for the condition check; null = no check */
  @Param currentPrice: number | null = null;
  @Param showDescription: boolean = true;
  @Param expandable: boolean = true;
  @Event onActionClick: () => void = () => {
  };
  @Local isExpanded: boolean = false;

  private status(): CouponStatus {
    const c: Coupon = this.coupon;
    if (c.useStatus === 1) {
      return CouponStatus.USED;
    }
    if (c.useStatus === 2 || isCouponExpired(c.endTime)) {
      return CouponStatus.EXPIRED;
    }
    if (this.mode === CouponCardMode.SELECT && this.currentPrice !== null && c.condition !== null) {
      const condition: Condition = c.condition as Condition;
      if ((this.currentPrice as number) < condition.fullAmount) {
        return CouponStatus.INSUFFICIENT;
      }
      return this.isSelected ? CouponStatus.SELECTED : CouponStatus.AVAILABLE;
    }
    if (this.mode === CouponCardMode.SELECT && this.isSelected) {
      return CouponStatus.SELECTED;
    }
    return CouponStatus.AVAILABLE;
  }

  private isUnavailable(): boolean {
    const s: CouponStatus = this.status();
    return s === CouponStatus.USED || s === CouponStatus.EXPIRED || s === CouponStatus.INSUFFICIENT;
  }

  private actionText(): Resource {
    switch (this.mode) {
      case CouponCardMode.SELECT:
        return $r('app.string.goods_select');
      case CouponCardMode.VIEW:
        return $r('app.string.coupon_use');
      default:
        return $r('app.string.coupon_receive');
    }
  }

  @Builder
  statusText(text: Resource, type: AppTextType) {
    Text(text)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
      .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
      .fontColor(AppTextStyles.color(type))
  }

  @Builder
  actionButton() {
    if (this.status() === CouponStatus.AVAILABLE) {
      AppButton({
        btnText: this.actionText(),
        fullWidth: false,
        btnSize: AppButtonSize.MINI,
        onBtnClick: () => {
          this.onActionClick();
        }
      })
    } else if (this.status() === CouponStatus.SELECTED) {
      this.statusText($r('app.string.selected'), AppTextType.LINK)
    } else if (this.status() === CouponStatus.USED) {
      this.statusText($r('app.string.coupon_used'), AppTextType.TERTIARY)
    } else if (this.status() === CouponStatus.EXPIRED) {
      this.statusText($r('app.string.coupon_expired'), AppTextType.TERTIARY)
    } else {
      this.statusText($r('app.string.coupon_insufficient'), AppTextType.TERTIARY)
    }
  }

  @Builder
  topSection() {
    Row() {
      // coupon icon: 46vp, linear gradient primary .9 → .7, ShapeSmall
      Row() {
        Image($r('app.media.ic_coupon'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_white'))
      }
      .width(46)
      .height(46)
      // source: Box(contentAlignment = Center)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(Dimens.radiusSmall)
      .linearGradient({
        // Brush.linearGradient default: top-left → bottom-right
        direction: GradientDirection.RightBottom,
        colors: [
          [ThemeManager.instance.primaryWithAlpha(0.9), 0.0],
          [ThemeManager.instance.primaryWithAlpha(0.7), 1.0]
        ]
      })

      Column({ space: 4 }) {
        Text(this.coupon.title)
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.coupon.endTime !== null) {
          Text($r('app.string.coupon_valid_until', this.coupon.endTime as string))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
        }
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })
      // source: Column(weight 1) without horizontalAlignment = start
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        PriceText({ price: Math.trunc(this.coupon.amount) })
        if (this.coupon.condition !== null) {
          Text($r('app.string.coupon_conditions', Math.trunc((this.coupon.condition as Condition).fullAmount)))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        }
      }
      // source: horizontalAlignment = End
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    // source: verticalAlignment = CenterVertically, horizontal start
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  bottomSection() {
    // SpaceBetweenRow(padding h 12 / v 12)
    Row() {
      if (this.expandable && this.coupon.description.length > 0) {
        Column() {
          Row() {
            Text($r('app.string.coupon_usage_instructions'))
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
              .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
            Image(this.isExpanded ? $r('app.media.ic_up') : $r('app.media.ic_down'))
              .width(16)
              .height(16)
              .objectFit(ImageFit.Contain)
              .fillColor(onSurface60())
              .margin({ left: Dimens.spaceHorizontalXSmall })
          }
          // source: verticalAlignment = CenterVertically
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Start)
          .onClick(() => {
            // AnimatedVisibility expandVertically / shrinkVertically
            this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.isExpanded = !this.isExpanded;
            });
          })

          if (this.isExpanded) {
            Text(this.coupon.description)
              .margin({ top: 4 })
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
              .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
              .transition(TransitionEffect.OPACITY)
          }
        }
        .layoutWeight(1)
        // source: Column without alignment = start
        .alignItems(HorizontalAlign.Start)
      } else if (this.showDescription && this.coupon.description.length > 0) {
        Text(this.coupon.description)
          .layoutWeight(1)
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      this.actionButton()
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spaceVerticalMedium,
      bottom: Dimens.spaceVerticalMedium
    })
    // source SpaceBetweenRow: SpaceBetween + CenterVertically (a lone action button sits at the start, as in Compose)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  /** Gray mask (surface @ 0.4) over unavailable coupons; display-only, takes no touches. */
  @Builder
  maskLayer() {
    if (this.isUnavailable()) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface'))
        .opacity(0.4)
        .hitTestBehavior(HitTestMode.None)
    }
  }

  build() {
    // Card { Box { content; mask (matchParentSize) } } → content Column + overlay sized to the card
    Column() {
      this.topSection()
      if (this.showDescription || this.expandable) {
        WeDivider()
        this.bottomSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .overlay(this.maskLayer(), { align: Alignment.TopStart })
  }
}
