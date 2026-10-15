/**
 * OrderCard (source: OrderListScreen.kt private OrderCard) — ORDA-A12..A15.
 *
 * Card(clip ShapeMedium, clickable → detail) {
 *   AppListItem(title = orderNum, trailing = status text, no arrow, click → detail)
 *   Box(fillMaxWidth) {
 *     HorizontalScroll(padding 12, end 80) { 80vp images (spec image first, else goods main pic), 8 apart }
 *     CenterColumn(CenterEnd, width 80, end padding 12) { PriceText(price, BODY_LARGE), 4, `共 N 件` }
 *   }
 *   WeDivider
 *   EndRow(padding 12) { OrderButtons }
 * }
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { Order, OrderGoods } from '../../../core/model/Order';
import { WeDivider } from '../../../core/ui/widget/AppCard';
import { NetWorkImage } from '../../../core/ui/widget/Images';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType, PriceText } from '../../../core/ui/widget/Texts';
import { OrderButtons } from '../common/OrderButtons';
import { OrderStatusUtil } from '../common/OrderStatus';

/** Goods thumbnail size (source size = 80.dp) */
const THUMB_SIZE: number = 80;
/** Right price column width (source width(80.dp)) */
const PRICE_COLUMN_WIDTH: number = 80;

@ComponentV2
export struct OrderCard {
  @Param order: Order = new Order();
  @Event onCardClick: () => void = () => {
  };
  @Event onCancelClick: () => void = () => {
  };
  @Event onPayClick: () => void = () => {
  };
  @Event onRefundClick: () => void = () => {
  };
  @Event onConfirmClick: () => void = () => {
  };
  @Event onLogisticsClick: () => void = () => {
  };
  @Event onCommentClick: () => void = () => {
  };
  @Event onRebuyClick: () => void = () => {
  };

  private goodsList(): OrderGoods[] {
    const list: OrderGoods[] | null | undefined = this.order.goodsList;
    return (list !== null && list !== undefined) ? list : [];
  }

  /** spec?.images?.firstOrNull() ?: goodsInfo?.mainPic */
  private goodsImage(goods: OrderGoods): string | null {
    const spec = goods.spec;
    if (spec !== null && spec !== undefined) {
      const images: string[] | null | undefined = spec.images;
      if (images !== null && images !== undefined && images.length > 0) {
        return images[0];
      }
    }
    const info = goods.goodsInfo;
    if (info !== null && info !== undefined) {
      const pic: string | null | undefined = info.mainPic;
      return (pic !== null && pic !== undefined) ? pic : null;
    }
    return null;
  }

  private orderNum(): string {
    const n: string | null | undefined = this.order.orderNum;
    return (n !== null && n !== undefined) ? n : '';
  }

  private orderStatus(): number {
    const s: number | null | undefined = this.order.status;
    return (s !== null && s !== undefined) ? s : -1;
  }

  build() {
    Column() {
      AppListItem({
        itemTitle: this.orderNum(),
        trailingText: OrderStatusUtil.statusText(this.orderStatus()),
        showArrow: false,
        onItemClick: () => {
          this.onCardClick();
        }
      })

      // Box(fillMaxWidth): goods scroller + price column anchored at CenterEnd
      Stack({ alignContent: Alignment.End }) {
        Scroll() {
          Row() {
            ForEach(this.goodsList(), (goods: OrderGoods, index: number) => {
              Row() {
                NetWorkImage({
                  model: this.goodsImage(goods),
                  imageSize: THUMB_SIZE,
                  showBackground: true,
                  cornerRadius: Dimens.radiusSmall
                })
              }
              .margin({ right: Dimens.spaceHorizontalSmall })
              .alignItems(VerticalAlign.Center)
            }, (goods: OrderGoods, index: number) => index + '_' + goods.id + '_' + (this.goodsImage(goods) ?? ''))
          }
          // source HorizontalScroll: Arrangement.Start + CenterVertically
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
        .padding({
          top: Dimens.spacePaddingMedium,
          bottom: Dimens.spacePaddingMedium,
          left: Dimens.spacePaddingMedium,
          right: Dimens.spacePaddingMedium + PRICE_COLUMN_WIDTH
        })

        // CenterColumn(width 80, end padding 12): content centered horizontally and vertically
        Column() {
          PriceText({ price: this.order.price ?? 0, integerTextSize: AppTextSize.BODY_LARGE })
          Text($r('app.string.total_items', this.goodsList().length))
            .margin({ top: Dimens.spaceVerticalXSmall })
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
            .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
        }
        .width(PRICE_COLUMN_WIDTH)
        .padding({ right: Dimens.spacePaddingMedium })
        .alignItems(HorizontalAlign.Center) // source CenterColumn = CenterHorizontally + Center
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent) // display only: taps reach the card
      }
      .width('100%')

      WeDivider()

      // EndRow(padding 12) { OrderButtons }
      Row() {
        OrderButtons({
          orderStatus: this.orderStatus(),
          onCancelClick: () => {
            this.onCancelClick();
          },
          onPayClick: () => {
            this.onPayClick();
          },
          onRefundClick: () => {
            this.onRefundClick();
          },
          onConfirmClick: () => {
            this.onConfirmClick();
          },
          onLogisticsClick: () => {
            this.onLogisticsClick();
          },
          onCommentClick: () => {
            this.onCommentClick();
          },
          onRebuyClick: () => {
            this.onRebuyClick();
          }
        })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // M3 Card (container color surface variant level) + clip ShapeMedium
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .onClick(() => {
      this.onCardClick();
    })
  }
}
