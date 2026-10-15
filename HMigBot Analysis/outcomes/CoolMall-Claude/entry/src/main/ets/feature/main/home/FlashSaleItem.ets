/**
 * FlashSaleItem (source: feature/main/component/FlashSaleItem.kt).
 * Column(width 120, clip ShapeSmall 8, clickable → onClick(goods.id)), start-aligned:
 *   image (fillMaxWidth, aspectRatio 1, clip 8) · 4 · title (bodyMedium, 1 line, ellipsis) · 4 · PriceText(BODY_LARGE)
 */
import { Goods } from '../../../core/model/Goods';
import { Dimens } from '../../../core/designsystem/Dimens';
import { NetWorkImage } from '../../../core/ui/widget/Images';
import { AppTextSize, PriceText } from '../../../core/ui/widget/Texts';

/** source .width(120.dp) */
const FLASH_SALE_ITEM_WIDTH: number = 120;

@ComponentV2
export struct FlashSaleItem {
  @Param goods: Goods = new Goods();
  @Event onGoodsClick: (goodsId: number) => void = (goodsId: number) => {
  };

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        NetWorkImage({ model: this.goods.mainPic, cornerRadius: Dimens.radiusSmall })
      }
      .width('100%')
      .aspectRatio(1)
      .borderRadius(Dimens.radiusSmall)
      .clip(true)

      Text(this.goods.title ?? '')
        .width('100%')
        .margin({ top: Dimens.spaceVerticalXSmall })
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        PriceText({ price: this.goods.price ?? 0, integerTextSize: AppTextSize.BODY_LARGE })
      }
      .margin({ top: Dimens.spaceVerticalXSmall })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)
    }
    .width(FLASH_SALE_ITEM_WIDTH)
    // source Column without horizontalAlignment = start
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
    .onClick(() => {
      this.onGoodsClick(this.goods.id);
    })
  }
}
