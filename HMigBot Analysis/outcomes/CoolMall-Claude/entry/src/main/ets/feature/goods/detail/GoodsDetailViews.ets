/**
 * Goods detail private views (source: feature/goods/view/GoodsDetailScreen.kt — GoodsDetailTopBar,
 * CircleIconButton, GoodsInfoCard, SoldCountTag, CouponList, CouponTag, SpecSelection, GoodsCommentsCard,
 * GoodsDeliveryCard, GoodsActionBar).
 */
import { LengthMetrics } from '@kit.ArkUI';
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Comment, Goods, GoodsSpec } from '../../../core/model/Goods';
import { Coupon } from '../../../core/model/Market';
import { CommerceSheet } from '../../../core/ui/commerce/CommerceSheet';
import { AppCard, TitleWithLine, WeDivider } from '../../../core/ui/widget/AppCard';
import {
  AppButtonBordered,
  AppButtonFixed,
  AppButtonShape,
  AppButtonSize,
  AppButtonStyle,
  AppButtonType
} from '../../../core/ui/widget/Buttons';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType, PriceText } from '../../../core/ui/widget/Texts';
import { CommentItem } from './CommentItem';

/** Top bar button entry animation (source tween(600)) */
const BUTTON_SCALE_MS: number = 600;
/** Bottom bar entry animation (source tween(800)) */
const BOTTOM_BAR_MS: number = 800;
/** Bottom bar start offset (source Offset(0f, 200f) in px) */
const BOTTOM_BAR_OFFSET_PX: number = 200;

// =====================================================================================================
// Floating top bar (GOODS-A16 / A17)
// =====================================================================================================

@ComponentV2
export struct GoodsDetailTopBar {
  /** Background alpha 0..255 (scroll driven) */
  @Param topBarAlpha: number = 0;
  @Param hasAnimated: boolean = false;
  /** Status bar height (statusBarsPadding) */
  @Param statusBarTop: number = 0;
  @Event onBackClick: () => void = () => {
  };
  @Event onShareClick: () => void = () => {
  };

  /** isSystemInDarkTheme ? Color(0,0,0,a) : Color(255,255,255,a) */
  private barColor(): string {
    const a: number = Math.min(255, Math.max(0, Math.round(this.topBarAlpha))) / 255;
    return ThemeManager.instance.isDark ? `rgba(0,0,0,${a})` : `rgba(255,255,255,${a})`;
  }

  @Builder
  circleButton(icon: Resource, iconSize: number, onTap: () => void) {
    // Box(contentAlignment = Center) 38 circle, black @ 0.3
    Stack({ alignContent: Alignment.Center }) {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .objectFit(ImageFit.Contain)
        .fillColor(Color.White)
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .clip(true)
    .backgroundColor('#4D000000')
    .onClick(() => {
      onTap();
    })
    .scale({ x: this.hasAnimated ? 1 : 0, y: this.hasAnimated ? 1 : 0 })
    .animation({ duration: BUTTON_SCALE_MS, curve: Curve.FastOutSlowIn })
  }

  build() {
    Row() {
      this.circleButton($r('app.media.ic_left'), 28, () => {
        this.onBackClick();
      })
      Blank()
        .layoutWeight(1)
        .hitTestBehavior(HitTestMode.Transparent)
      this.circleButton($r('app.media.ic_share_triangle'), 20, () => {
        this.onShareClick();
      })
    }
    .width('100%')
    .padding({
      top: this.statusBarTop + Dimens.spacePaddingSmall,
      bottom: Dimens.spacePaddingSmall,
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium
    })
    .backgroundColor(this.barColor())
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top) // source Row default top
    // the bar has no click handler of its own: let scroll gestures reach the list below
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

// =====================================================================================================
// Info card (GOODS-A02 / A03 / A05)
// =====================================================================================================

@ComponentV2
export struct GoodsInfoCard {
  @Param goods: Goods = new Goods();
  @Param coupons: Coupon[] = [];
  @Param selectedSpec: GoodsSpec | null = null;
  @Event onShowSpecModal: () => void = () => {
  };
  @Event onShowCouponModal: () => void = () => {
  };

  private priceValue(): number {
    const spec: GoodsSpec | null = this.selectedSpec;
    return spec !== null ? spec.price : this.goods.price;
  }

  private couponText(coupon: Coupon): Resource {
    const full: number = coupon.condition !== null && coupon.condition !== undefined ?
    Math.trunc(coupon.condition.fullAmount) : 0;
    return $r('app.string.coupon_text', full, Math.trunc(coupon.amount ?? 0));
  }

  private specText(): Resource {
    const spec: GoodsSpec | null = this.selectedSpec;
    return spec !== null ? $r('app.string.selected_spec', spec.name) : $r('app.string.select_spec');
  }

  @Builder
  soldTag() {
    Row() {
      Text($r('app.string.sold_count', this.goods.sold))
        .fontSize(Dimens.fontBodySmall) // labelSmall
        .fontColor(Color.White)
    }
    .padding({
      left: Dimens.spacePaddingSmall,
      right: Dimens.spacePaddingSmall,
      top: Dimens.spacePaddingXSmall,
      bottom: Dimens.spacePaddingXSmall
    })
    .backgroundColor(ThemeManager.instance.primary)
    .borderRadius(Dimens.radiusCircle)
    .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  couponTag(coupon: Coupon) {
    Row() {
      Image($r('app.media.ic_coupon'))
        .width(Dimens.spaceVerticalMedium)
        .height(Dimens.spaceVerticalMedium)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.danger'))
      Text(this.couponText(coupon))
        .margin({ left: Dimens.spaceVerticalXSmall })
        .fontSize(Dimens.fontBodySmall) // labelSmall
        .fontColor($r('app.color.danger'))
    }
    .padding({
      left: Dimens.spacePaddingSmall,
      right: Dimens.spacePaddingSmall,
      top: Dimens.spaceVerticalXSmall,
      bottom: Dimens.spaceVerticalXSmall
    })
    .border({ width: Dimens.spaceDivider, color: $r('app.color.danger'), radius: Dimens.spaceVerticalXSmall })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onShowCouponModal();
    })
  }

  @Builder
  couponList() {
    if (this.coupons.length > 0) {
      // FlowRow(spacedBy 8 / 8)
      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Start,
        space: { main: LengthMetrics.vp(Dimens.spaceHorizontalSmall), cross: LengthMetrics.vp(Dimens.spaceVerticalSmall) }
      }) {
        ForEach(this.coupons, (coupon: Coupon) => {
          this.couponTag(coupon)
        }, (coupon: Coupon) => coupon.id + '_' + coupon.amount + '_' + (coupon.condition?.fullAmount ?? 0))
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalSmall })
    }
  }

  @Builder
  specSelection() {
    Row() {
      Row() {
        Image($r('app.media.ic_cube'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .fillColor(CommerceSheet.onSurface60())
          .accessibilityText($r('app.string.spec'))
        Text(this.specText())
          .margin({ left: Dimens.spaceHorizontalXSmall })
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor($r('app.color.text_primary'))
          .opacity(0.8)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_right'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .opacity(0.4)
      }
      .width(Dimens.spaceVerticalLarge)
      .height(Dimens.spaceVerticalLarge)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .border({ width: 1.2, color: $r('app.color.border'), radius: Dimens.radiusSmall })
    .clip(true)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      this.onShowSpecModal();
    })
  }

  @Builder
  cardBody() {
    // price + sold tag
    Row() {
      PriceText({ price: this.priceValue(), integerTextSize: AppTextSize.DISPLAY_LARGE })
      this.soldTag()
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)

    this.couponList()

    Text(this.goods.title)
      .width('100%')
      .margin({ top: Dimens.spaceVerticalMedium })
      .fontSize(Dimens.fontTitleLarge)
      .lineHeight(Dimens.lineTitleLarge)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })

    if (this.goods.subTitle !== null && this.goods.subTitle !== undefined) {
      Text(this.goods.subTitle as string)
        .width('100%')
        .margin({ top: Dimens.spaceVerticalXSmall })
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor($r('app.color.text_primary'))
        .opacity(0.7)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)
    } else {
      Column()
        .width('100%')
        .height(Dimens.spaceVerticalXSmall + Dimens.spaceVerticalMedium)
    }

    this.specSelection()
  }

  build() {
    Column() {
      AppCard({
        cardContent: (): void => {
          this.cardBody()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// =====================================================================================================
// Delivery card (GOODS-A13)
// =====================================================================================================

@ComponentV2
export struct GoodsDeliveryCard {
  @Builder
  titleRow() {
    TitleWithLine({ titleText: $r('app.string.shipping_and_service') })
  }

  build() {
    Column() {
      AppListItem({
        itemTitle: '',
        showArrow: false,
        clickable: false,
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.titleRow()
        }
      })
      AppListItem({
        itemTitle: $r('app.string.shipping'),
        showArrow: false,
        clickable: false,
        trailingText: $r('app.string.shipping_location')
      })
      AppListItem({
        itemTitle: $r('app.string.service'),
        showArrow: false,
        showDivider: false,
        clickable: false,
        trailingText: $r('app.string.service_details')
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }
}

// =====================================================================================================
// Comments card (GOODS-A14)
// =====================================================================================================

@ComponentV2
export struct GoodsCommentsCard {
  @Param comments: Comment[] = [];
  @Event onCommentClick: () => void = () => {
  };

  @Builder
  titleRow() {
    TitleWithLine({ titleText: $r('app.string.goods_reviews') })
  }

  build() {
    Column() {
      AppListItem({
        itemTitle: '',
        trailingText: $r('app.string.view_all'),
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.titleRow()
        },
        onItemClick: () => {
          this.onCommentClick();
        }
      })
      ForEach(this.comments, (comment: Comment, index: number) => {
        Column() {
          CommentItem({
            comment: comment,
            itemClickable: true,
            onItemClick: () => {
              this.onCommentClick();
            }
          })
          if (index < this.comments.length - 1) {
            WeDivider()
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (comment: Comment, index: number) => index + '_' + comment.id + '_' + comment.starCount + '_' +
        (comment.pics?.length ?? 0) + '_' + this.comments.length)
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }
}

// =====================================================================================================
// Bottom action bar (GOODS-A12)
// =====================================================================================================

@ComponentV2
export struct GoodsActionBar {
  @Param hasAnimated: boolean = false;
  /** Navigation bar height (navigationBarsPadding) */
  @Param navBarBottom: number = 0;
  @Event onAddToCartClick: () => void = () => {
  };
  @Event onBuyNowClick: () => void = () => {
  };
  @Event onCsClick: () => void = () => {
  };
  @Event onCartClick: () => void = () => {
  };

  @Builder
  iconAction(icon: Resource, label: Resource, onTap: () => void) {
    Column() {
      Image(icon)
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
        .maxLines(1)
    }
    .width(40)
    .padding({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
    .alignItems(HorizontalAlign.Center) // source CenterHorizontally
    .justifyContent(FlexAlign.Center)
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      onTap();
    })
  }

  build() {
    // Surface(shadowElevation 4) { SpaceBetweenRow(padding vertical 8 + navigationBarsPadding) }
    Row() {
      Row() {
        this.iconAction($r('app.media.ic_customer_service'), $r('app.string.customer_service'), () => {
          this.onCsClick();
        })
        this.iconAction($r('app.media.ic_cart'), $r('app.string.shopping_cart'), () => {
          this.onCartClick();
        })
      }
      .padding({ left: Dimens.spaceHorizontalSmall })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top) // source Row default top

      Row() {
        AppButtonBordered({
          btnText: $r('app.string.add_to_cart'),
          btnType: AppButtonType.LINK,
          btnShape: AppButtonShape.SQUARE,
          btnSize: AppButtonSize.MINI,
          onBtnClick: () => {
            this.onAddToCartClick();
          }
        })
        Row() {
          AppButtonFixed({
            btnText: $r('app.string.buy_now'),
            btnSize: AppButtonSize.MINI,
            btnStyle: AppButtonStyle.GRADIENT,
            btnShape: AppButtonShape.SQUARE,
            onBtnClick: () => {
              this.onBuyNowClick();
            }
          })
        }
        .margin({ left: Dimens.spaceHorizontalLarge })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)
      }
      .padding({ right: Dimens.spaceHorizontalLarge })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top) // source Row default top
    }
    .width('100%')
    .padding({ top: Dimens.spaceVerticalSmall, bottom: Dimens.spaceVerticalSmall + this.navBarBottom })
    .justifyContent(FlexAlign.SpaceBetween) // SpaceBetweenRow
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 0 })
    .translate({ y: this.hasAnimated ? 0 : this.getUIContext().px2vp(BOTTOM_BAR_OFFSET_PX) })
    .animation({ duration: BOTTOM_BAR_MS, curve: Curve.FastOutSlowIn })
  }
}
