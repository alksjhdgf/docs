/**
 * Goods items (source: core/ui/component/goods/GoodsGridItem.kt, GoodsListItem.kt, OrderGoodsItem.kt).
 *
 * Exports:
 *  - GoodsGridItem: grid card (image full width with intrinsic aspect ratio, min 100vp; title; subtitle; price + sold)
 *  - GoodsListItem: list card (100vp image + title/subtitle + price/sold)
 *  - OrderGoodsCard: goods title row (AppListItem) + one OrderGoodsItem per spec, deleting specs slide out
 *  - OrderGoodsItem: [select slot] + 90vp image + spec chip + price + (action slot | QuantityStepper | `x{count}`)
 *
 * Slots: ArkTS cannot test a @BuilderParam for presence, so `hasSelectSlot` / `hasActionSlot` mirror the
 * source's nullable slot parameters. Pass slots in the arrow-wrapped form:
 *   OrderGoodsCard({ data: cart, hasSelectSlot: true,
 *                    itemSelectSlot: (spec: CartGoodsSpec): void => { this.checkBuilder(cart.goodsId, spec) } })
 * Builders receive the spec as a snapshot (A2-7): read live selection state from `this.` inside the builder.
 */
import { Goods } from '../../model/Goods';
import { Cart, CartGoodsSpec } from '../../model/Order';
import { Dimens } from '../../designsystem/Dimens';
import { NetWorkImage } from '../widget/Images';
import { PriceText, AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { QuantityStepper } from '../widget/QuantityStepper';
import { AppListItem } from '../widget/ListItem';

/** Color.kt TextTertiaryLight — the source uses the fixed light value for goods subtitles in both modes. */
const TEXT_TERTIARY_LIGHT: string = '#B2B2B2';

@Builder
function emptySpecSlot(spec: CartGoodsSpec) {
}

/** Goods sold text `已售%d件` (onSurface @ 0.6, bodySmall). */
@Builder
function goodsSoldText(sold: number) {
  Text($r('app.string.goods_sold', sold))
    .fontSize(Dimens.fontBodySmall)
    .lineHeight(Dimens.lineBodySmall)
    .fontColor($r('app.color.text_primary'))
    .opacity(0.6)
    .maxLines(1)
}

/**
 * Goods grid card (GoodsGridItem.kt). M3 Card (bg_card, 12vp corners) + Column(padding 8).
 * The image keeps its intrinsic aspect ratio across the full width with a 100vp minimum height
 * (source fillMaxWidth().heightIn(min = 100.dp) on an AsyncImage), clipped to 8vp corners.
 */
@ComponentV2
export struct GoodsGridItem {
  @Param goods: Goods = new Goods();
  @Event onGoodsClick: (goodsId: number) => void = (goodsId: number) => {
  };

  build() {
    Column() {
      Image(this.goods.mainPic)
        .width('100%')
        .constraintSize({ minHeight: 100 })
        .objectFit(ImageFit.Cover) // source ContentScale.Crop (NetWorkImage default)
        .borderRadius(Dimens.radiusSmall)
        .clip(true)
        .draggable(false)
      Text(this.goods.title)
        .width('100%')
        .margin({ top: Dimens.spaceVerticalXSmall })
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
      if (this.goods.subTitle !== null && this.goods.subTitle.length > 0) {
        Text(this.goods.subTitle as string)
          .width('100%')
          .fontSize(Dimens.fontBodySmall)
          .lineHeight(Dimens.lineBodySmall)
          .fontColor(TEXT_TERTIARY_LIGHT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Row() {
        PriceText({ price: this.goods.price })
        goodsSoldText(this.goods.sold)
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalXSmall })
      // source: Arrangement.SpaceBetween + CenterVertically
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(Dimens.spaceHorizontalSmall)
    // source: Column without horizontalAlignment = start
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .onClick(() => {
      this.onGoodsClick(this.goods.id);
    })
  }
}

/** Goods list card (GoodsListItem.kt). Row(padding 8, spacedBy 8): image 100 + info column (height 100). */
@ComponentV2
export struct GoodsListItem {
  @Param goods: Goods = new Goods();
  @Event onGoodsClick: (goodsId: number) => void = (goodsId: number) => {
  };

  build() {
    Row({ space: Dimens.spaceHorizontalSmall }) {
      NetWorkImage({ model: this.goods.mainPic, imageSize: 100, cornerRadius: Dimens.radiusSmall })
      Column() {
        Column() {
          Text(this.goods.title)
            .fontSize(Dimens.fontBodyLarge)
            .lineHeight(Dimens.lineBodyLarge)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.goods.subTitle !== null && this.goods.subTitle.length > 0) {
            Text(this.goods.subTitle as string)
              .margin({ top: Dimens.spaceVerticalXSmall })
              .fontSize(Dimens.fontBodySmall)
              .lineHeight(Dimens.lineBodySmall)
              .fontColor(TEXT_TERTIARY_LIGHT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        // source: inner Column without alignment = start
        .alignItems(HorizontalAlign.Start)

        Row() {
          PriceText({ price: this.goods.price })
          goodsSoldText(this.goods.sold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(100)
      // source: verticalArrangement = SpaceAround, horizontal = start
      .justifyContent(FlexAlign.SpaceAround)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(Dimens.spaceHorizontalSmall)
    // source: Row without verticalAlignment = top; horizontal start
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .onClick(() => {
      this.onGoodsClick(this.goods.id);
    })
  }
}

/**
 * Order goods item (OrderGoodsItem.kt): used by cart, order confirm, order detail, refund.
 * Row(CenterVertically), padding start 16 (0 with a select slot) / end 16 / bottom 16.
 */
@ComponentV2
export struct OrderGoodsItem {
  @Param data: CartGoodsSpec = new CartGoodsSpec();
  @Param goodsId: number = 0;
  @Param goodsName: string = '';
  @Param goodsMainPic: string = '';
  @Param enableQuantityStepper: boolean = true;
  /** source selectSlot != null */
  @Param hasSelectSlot: boolean = false;
  @BuilderParam selectSlot: (spec: CartGoodsSpec) => void = emptySpecSlot;
  /** source actionSlot != null */
  @Param hasActionSlot: boolean = false;
  @BuilderParam actionSlot: (spec: CartGoodsSpec) => void = emptySpecSlot;
  @Event onSpecClick: (specId: number) => void = (specId: number) => {
  };
  @Event onQuantityChanged: (count: number) => void = (count: number) => {
  };

  private imageUrl(): string {
    const images: string[] | null = this.data.images;
    if (images !== null && images.length > 0) {
      return images[0];
    }
    return this.goodsMainPic;
  }

  build() {
    Row() {
      if (this.hasSelectSlot) {
        Row() {
          this.selectSlot(this.data)
        }
        .padding({ left: Dimens.spacePaddingLarge })
        .margin({ right: Dimens.spaceHorizontalMedium })
        .alignItems(VerticalAlign.Center) // source Box (only child, wraps it)
      }

      NetWorkImage({
        model: this.imageUrl(),
        imageSize: 90,
        showBackground: true,
        cornerRadius: Dimens.radiusSmall
      })

      Column() {
        // spec chip (surfaceVariant, 4vp corners, clickable)
        Row() {
          Text(this.data.name)
            .fontSize(Dimens.fontBodySmall)
            .lineHeight(Dimens.lineBodySmall)
            .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        }
        .padding({
          left: Dimens.spacePaddingSmall,
          right: Dimens.spacePaddingSmall,
          top: Dimens.spaceVerticalXSmall,
          bottom: Dimens.spaceVerticalXSmall
        })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.bg_content'))
        .borderRadius(4)
        .onClick(() => {
          this.onSpecClick(this.data.id);
        })

        // SpaceBetweenRow: price + action
        Row() {
          PriceText({ price: this.data.price })
          if (this.hasActionSlot) {
            Row() {
              this.actionSlot(this.data)
            }
            .alignItems(VerticalAlign.Center)
          } else if (this.enableQuantityStepper) {
            QuantityStepper({
              quantity: this.data.count,
              onQuantityChanged: (value: number) => {
                this.onQuantityChanged(value);
              }
            })
          } else {
            Text('x' + this.data.count)
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
              .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
          }
        }
        .width('100%')
        .margin({ top: Dimens.spaceVerticalMedium })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      // source: Column(weight 1) without alignment = start
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: this.hasSelectSlot ? 0 : Dimens.spacePaddingLarge,
      right: Dimens.spacePaddingLarge,
      bottom: Dimens.spacePaddingLarge
    })
    // source: verticalAlignment = CenterVertically, horizontal start
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}

/**
 * Order goods card (OrderGoodsItem.kt `OrderGoodsCard`): M3 Card with the goods name row
 * (AppListItem, click → onGoodsClick(goodsId)), 12vp gap, then each spec as an OrderGoodsItem.
 * Specs whose id is in `deletingSpecIds` slide out to the left and fade (tween 300).
 */
@ComponentV2
export struct OrderGoodsCard {
  @Param data: Cart = new Cart();
  /** source deletingSpecIds: Set<Long> */
  @Param deletingSpecIds: number[] = [];
  @Param enableQuantityStepper: boolean = true;
  @Param hasSelectSlot: boolean = false;
  @BuilderParam itemSelectSlot: (spec: CartGoodsSpec) => void = emptySpecSlot;
  @Param hasActionSlot: boolean = false;
  @BuilderParam itemActionSlot: (spec: CartGoodsSpec) => void = emptySpecSlot;
  @Event onGoodsClick: (goodsId: number) => void = (goodsId: number) => {
  };
  @Event onSpecClick: (specId: number) => void = (specId: number) => {
  };
  /** (specId, newCount) */
  @Event onQuantityChanged: (specId: number, count: number) => void = (specId: number, count: number) => {
  };

  private isDeleting(specId: number): boolean {
    return this.deletingSpecIds.indexOf(specId) >= 0;
  }

  build() {
    Column() {
      AppListItem({
        itemTitle: this.data.goodsName,
        onItemClick: () => {
          this.onGoodsClick(this.data.goodsId);
        }
      })
      // SpaceVerticalMedium
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      ForEach(this.data.spec, (item: CartGoodsSpec) => {
        if (!this.isDeleting(item.id)) {
          Column() {
            OrderGoodsItem({
              data: item,
              goodsId: this.data.goodsId,
              goodsName: this.data.goodsName,
              goodsMainPic: this.data.goodsMainPic,
              enableQuantityStepper: this.enableQuantityStepper,
              hasSelectSlot: this.hasSelectSlot,
              selectSlot: (spec: CartGoodsSpec): void => {
                this.itemSelectSlot(spec)
              },
              hasActionSlot: this.hasActionSlot,
              actionSlot: (spec: CartGoodsSpec): void => {
                this.itemActionSlot(spec)
              },
              onSpecClick: (specId: number) => {
                this.onSpecClick(specId);
              },
              onQuantityChanged: (count: number) => {
                this.onQuantityChanged(item.id, count);
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          // source AnimatedVisibility exit: slideOutHorizontally(-width) + fadeOut, tween(300)
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.IDENTITY,
            TransitionEffect.translate({ x: '-100%' }).combine(TransitionEffect.OPACITY)
              .animation({ duration: 300, curve: Curve.EaseInOut })
          ))
        }
      }, (item: CartGoodsSpec) => item.id + '_' + item.count + '_' + item.price + '_' + item.name)
    }
    .width('100%')
    // source: Card ColumnScope = start
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}
