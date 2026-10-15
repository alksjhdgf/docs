/**
 * OrderRoutesCommentPage — goods review (source: feature/order/view/OrderCommentScreen.kt +
 * viewmodel/OrderCommentViewModel.kt) — ORDB-A25~A30.
 *
 * AppScaffold(large top bar `商品评价`, surface background) {
 *   Scroll { VerticalList(CenterHorizontally, padding 12, spacedBy 12) {
 *     32vp spacer, WeRate(5 stars, interactive), rating text (`很差`…`非常满意`, 0 → `请点击星星进行评分`),
 *     4vp spacer, content input (surfaceVariant, 12vp corners, 6..8 lines, placeholder `请输入您的评价内容...`),
 *     ImageGridPicker(max 9), 4vp spacer
 *   } }
 *   bottomBar: AppBottomButton `提交评价` (enabled = form valid && !submitting, loading while submitting)
 * }
 * Param: OrderCommentParam(orderId, goodsId). Missing param → stays on the page with an error empty state.
 * Colors are resource tokens (light/dark follow the system / app setting).
 */
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { EmptyError } from '../core/ui/base/StateViews';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { ImageGridPicker } from '../core/ui/widget/ImageGridPicker';
import { WeRate } from '../core/ui/widget/Rate';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { OrderCommentParam } from '../core/navigation/RouteParams';
import { OrderCommentViewModel } from '../feature/order/aftersale/OrderCommentViewModel';

/** M3 TextField: 16vp inner padding; minLines 6 / maxLines 8 of bodyLarge lines */
const INPUT_PADDING_H: number = 16;
const INPUT_PADDING_V: number = 16;
const INPUT_MIN_LINES: number = 6;
const INPUT_MAX_LINES: number = 8;
/** WeRate count */
const STAR_COUNT: number = 5;
/** ImageGridPicker maxImages */
const MAX_IMAGES: number = 9;

@Builder
export function OrderRoutesCommentPageBuilder() {
  OrderRoutesCommentPage()
}

@ComponentV2
struct OrderRoutesCommentPage {
  @Local vm: OrderCommentViewModel = new OrderCommentViewModel();
  /** Route param missing / invalid → empty state */
  @Local paramMissing: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (p !== undefined && p !== null && p instanceof OrderCommentParam) {
      const param: OrderCommentParam = p as OrderCommentParam;
      this.vm.orderId = param.orderId;
      this.vm.goodsId = param.goodsId;
      this.paramMissing = false;
    } else {
      this.paramMissing = true;
    }
  }

  /** Rating text (source when(rating)) */
  private ratingText(): Resource {
    switch (this.vm.rating) {
      case 1:
        return $r('app.string.rating_very_poor');
      case 2:
        return $r('app.string.rating_poor');
      case 3:
        return $r('app.string.rating_average');
      case 4:
        return $r('app.string.rating_good');
      case 5:
        return $r('app.string.rating_excellent');
      default:
        return $r('app.string.please_rate');
    }
  }

  /** Source OrderCommentContentView */
  @Builder
  formContent() {
    Scroll() {
      // source VerticalList(horizontalAlignment = CenterHorizontally): padding 12, spacedBy(12)
      Column({ space: Dimens.spaceVerticalMedium }) {
        // SpaceVerticalXXLarge
        Column()
          .height(Dimens.spaceVerticalXXLarge)

        WeRate({
          value: this.vm.rating,
          count: STAR_COUNT,
          changeable: true,
          onRateChange: (value: number) => {
            this.vm.updateRating(value);
          }
        })

        // AppText (BODY_LARGE, PRIMARY)
        Text(this.ratingText())
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
          .fontColor(AppTextStyles.color(AppTextType.PRIMARY))

        // SpaceVerticalXSmall
        Column()
          .height(Dimens.spaceVerticalXSmall)

        // comment content input (M3 TextField with transparent colors on surfaceVariant)
        TextArea({
          text: this.vm.commentContent,
          placeholder: $r('app.string.comment_placeholder')
        })
          .width('100%')
          .constraintSize({
            minHeight: INPUT_MIN_LINES * Dimens.lineBodyLarge + INPUT_PADDING_V * 2,
            maxHeight: INPUT_MAX_LINES * Dimens.lineBodyLarge + INPUT_PADDING_V * 2
          })
          .padding({
            left: INPUT_PADDING_H,
            right: INPUT_PADDING_H,
            top: INPUT_PADDING_V,
            bottom: INPUT_PADDING_V
          })
          .fontSize(Dimens.fontBodyLarge)
          .lineHeight(Dimens.lineBodyLarge)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .placeholderFont({ size: Dimens.fontBodyLarge })
          .caretColor(ThemeManager.instance.primary)
          .backgroundColor($r('app.color.bg_content'))
          .borderRadius(Dimens.radiusMedium)
          .enterKeyType(EnterKeyType.Done)
          .onChange((value: string) => {
            this.vm.updateCommentContent(value);
          })

        // image picker (max 9)
        Column() {
          ImageGridPicker({
            selectedImages: this.vm.selectedImages,
            maxImages: MAX_IMAGES,
            onImagesChanged: (images: string[]) => {
              this.vm.updateSelectedImages(images);
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // SpaceVerticalXSmall
        Column()
          .height(Dimens.spaceVerticalXSmall)
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Center)
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
      this.formContent()
    }
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.submit_comment'),
      btnEnabled: this.vm.isFormValid() && !this.vm.isSubmitting,
      loading: this.vm.isSubmitting,
      onBtnClick: () => {
        this.vm.onSubmitButtonClick();
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.order_comment'),
          useLargeTopBar: true,
          bgColor: $r('app.color.surface'),
          largeTopBarExpandedBackgroundColor: $r('app.color.surface'),
          largeTopBarCollapsedBackgroundColor: $r('app.color.surface'),
          hasBottomBar: !this.paramMissing,
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
  }
}
