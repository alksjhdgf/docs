/**
 * Order goods picker sheet (source: core/ui/component/modal/OrderGoodsModal.kt): used by order list/detail
 * for `再次购买` (title `选择要购买的商品`) and `去评价` (title `选择要评价的商品`).
 * Each goods: card { 60vp image, name (weight 1), mini AppButtonFixed(buttonText) → onItemButtonClick(goodsId) }.
 * Source containerColor = colorScheme.background, indicator onSurface @ 0.1. Bind with:
 *   .bindSheet(this.rebuyVisible, this.rebuySheet(),
 *     CommerceSheet.options(() => { this.vm.hideRebuyModal(); }, undefined, $r('app.color.bg_page')))
 */
import { Cart } from '../../model/Order';
import { Dimens } from '../../designsystem/Dimens';
import { BottomModal } from '../widget/BottomSheet';
import { NetWorkImage } from '../widget/Images';
import { AppButtonFixed, AppButtonSize, AppButtonType } from '../widget/Buttons';
import { AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { CommerceSheet } from './CommerceSheet';

const LIST_MAX_HEIGHT: number = 500;

@ComponentV2
export struct OrderGoodsSheet {
  /** e.g. $r('app.string.select_goods_to_buy') / $r('app.string.select_goods_to_comment') */
  @Param sheetTitle: ResourceStr = '';
  /** e.g. $r('app.string.rebuy') / $r('app.string.go_to_comment') */
  @Param buttonText: ResourceStr = '';
  @Param cartList: Cart[] = [];
  @Event onItemButtonClick: (goodsId: number) => void = (goodsId: number) => {
  };

  @Builder
  goodsRow(cart: Cart) {
    Row({ space: Dimens.spaceHorizontalMedium }) {
      NetWorkImage({
        model: cart.goodsMainPic,
        imageSize: 60,
        cornerRadius: Dimens.radiusSmall,
        showBackground: true
      })
      Text(cart.goodsName)
        .layoutWeight(1)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
      AppButtonFixed({
        btnText: this.buttonText,
        btnType: AppButtonType.DEFAULT,
        btnSize: AppButtonSize.MINI,
        onBtnClick: () => {
          this.onItemButtonClick(cart.goodsId);
        }
      })
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    // source: spacedBy(12) + CenterVertically
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    // M3 Card
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  listContent() {
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        ForEach(this.cartList, (cart: Cart) => {
          this.goodsRow(cart)
        }, (cart: Cart) => cart.goodsId + '_' + cart.goodsName + '_' + cart.goodsMainPic)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxHeight: LIST_MAX_HEIGHT })
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: this.sheetTitle,
        indicatorColor: CommerceSheet.faintIndicatorColor(),
        sheetContent: (): void => {
          this.listContent()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
