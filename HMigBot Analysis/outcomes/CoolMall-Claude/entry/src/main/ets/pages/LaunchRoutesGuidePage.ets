/**
 * LaunchRoutesGuidePage (source: feature/launch/view/GuideScreen.kt).
 *
 * Scaffold(surface, padding = system bars) → Box {
 *   top-right TextButton `跳过` (padding 16, tertiary BodyMedium) → skipGuide
 *   Column(fillMaxSize, SpaceBetween, centerH) { 32 + 16 / HorizontalPager weight(1) / 32 /
 *     PageIndicator (padding vertical 16 + 16; dots 24|8 x 8, r4, primary alpha 1|0.4, 300ms; gap 12) /
 *     AppButton(`继续` | `开始体验`, width 120 → 160 animated 300ms) / 32 }
 * }
 * Page content: Image 240 / 32 / title DisplayMedium Bold center / 24 / desc BodyLarge secondary,
 * lineHeight 24, center, padding horizontal 32.
 */
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { GuideParam } from '../core/navigation/RouteParams';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { AppButton } from '../core/ui/widget/Buttons';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { GuidePageData } from '../feature/launch/GuidePageData';
import { GuideViewModel } from '../feature/launch/GuideViewModel';

const GUIDE_IMAGE_SIZE: number = 240;
const DOT_SELECTED_WIDTH: number = 24;
const DOT_WIDTH: number = 8;
const DOT_HEIGHT: number = 8;
const BUTTON_WIDTH: number = 120;
const BUTTON_WIDTH_LAST: number = 160;
const ANIM_DURATION: number = 300;
/** M3 TextButton: min height 40, content padding 12 x 8 */
const TEXT_BUTTON_MIN_HEIGHT: number = 40;
const TEXT_BUTTON_PADDING_H: number = 12;

@Builder
export function LaunchRoutesGuidePageBuilder() {
  LaunchRoutesGuidePage()
}

@ComponentV2
struct LaunchRoutesGuidePage {
  @Local vm: GuideViewModel = new GuideViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();
  private swiperController: SwiperController = new SwiperController();

  private onNextClick(): void {
    if (this.vm.handleNextClick()) {
      const next: number = this.vm.getNextPageIndex();
      if (next !== this.vm.currentPageIndex) {
        // pagerState.animateScrollToPage(nextPage)
        this.swiperController.showNext();
      }
    }
  }

  private onSkipClick(): void {
    this.vm.skipGuide();
  }

  @Builder
  pageContent(page: GuidePageData) {
    Column() {
      Image(page.image)
        .width(GUIDE_IMAGE_SIZE)
        .height(GUIDE_IMAGE_SIZE)
        .objectFit(ImageFit.Contain)
        .draggable(false)

      Blank()
        .height(Dimens.spaceVerticalXXLarge)

      Text(page.title)
        .fontSize(AppTextStyles.fontSize(AppTextSize.DISPLAY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.DISPLAY_MEDIUM))
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
        .textAlign(TextAlign.Center)

      Blank()
        .height(Dimens.spaceVerticalXLarge)

      Text(page.description)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(24)
        .fontWeight(AppTextStyles.fontWeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        .textAlign(TextAlign.Center)
        .padding({ left: Dimens.spaceHorizontalXXLarge, right: Dimens.spaceHorizontalXXLarge })
    }
    // CenterColumn: fillMaxSize, centered both ways
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  pageIndicator() {
    Row() {
      ForEach(this.vm.guidePages, (item: GuidePageData, index: number) => {
        Row()
          .width(index === this.vm.currentPageIndex ? DOT_SELECTED_WIDTH : DOT_WIDTH)
          .height(DOT_HEIGHT)
          .borderRadius(DOT_HEIGHT / 2)
          .backgroundColor(ThemeManager.withAlpha(ThemeManager.instance.primary,
            index === this.vm.currentPageIndex ? 1 : 0.4))
          .margin({ left: index > 0 ? Dimens.spaceHorizontalMedium : 0 })
          .animation({ duration: ANIM_DURATION })
      }, (item: GuidePageData, index: number) => index.toString())
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .width('100%')
    // modifier.padding(vertical = SpaceVerticalLarge) + inner padding(vertical = SpacePaddingLarge)
    .padding({
      top: Dimens.spaceVerticalLarge + Dimens.spacePaddingLarge,
      bottom: Dimens.spaceVerticalLarge + Dimens.spacePaddingLarge
    })
  }

  @Builder
  contentColumn() {
    Column() {
      Blank()
        .height(Dimens.spaceVerticalXXLarge + Dimens.spaceVerticalLarge)

      Swiper(this.swiperController) {
        ForEach(this.vm.guidePages, (item: GuidePageData) => {
          this.pageContent(item)
        }, (item: GuidePageData, index: number) => 'guide_' + index.toString())
      }
      .loop(false)
      .autoPlay(false)
      .indicator(false)
      .duration(ANIM_DURATION)
      .width('100%')
      .layoutWeight(1)
      .onAnimationStart((index: number, targetIndex: number) => {
        this.vm.updatePageIndex(targetIndex);
      })
      .onChange((index: number) => {
        this.vm.updatePageIndex(index);
      })

      Blank()
        .height(Dimens.spaceVerticalXXLarge)

      this.pageIndicator()

      Column() {
        AppButton({
          btnText: this.vm.isLastPage() ? $r('app.string.guide_start_experience') : $r('app.string.guide_continue'),
          fullWidth: true,
          onBtnClick: () => {
            this.onNextClick();
          }
        })
      }
      .width(this.vm.isLastPage() ? BUTTON_WIDTH_LAST : BUTTON_WIDTH)
      .animation({ duration: ANIM_DURATION })

      Blank()
        .height(Dimens.spaceVerticalXXLarge)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopEnd }) {
        this.contentColumn()

        // Top-right skip TextButton (padding SpacePaddingLarge)
        Row() {
          Text($r('app.string.guide_skip'))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .constraintSize({ minHeight: TEXT_BUTTON_MIN_HEIGHT, minWidth: 58 })
        .padding({ left: TEXT_BUTTON_PADDING_H, right: TEXT_BUTTON_PADDING_H })
        .borderRadius(TEXT_BUTTON_MIN_HEIGHT / 2)
        .stateStyles({
          normal: {
            .backgroundColor(Color.Transparent)
          },
          pressed: {
            .backgroundColor($r('app.color.press'))
          }
        })
        .margin({
          top: Dimens.spacePaddingLarge,
          right: Dimens.spacePaddingLarge,
          bottom: Dimens.spacePaddingLarge,
          left: Dimens.spacePaddingLarge
        })
        .onClick(() => {
          this.onSkipClick();
        })
      }
      .width('100%')
      .height('100%')
      // Scaffold content padding = system bar insets (LAUNCH-A10)
      .padding({ top: this.avoidArea.top, bottom: this.avoidArea.bottom })
      .backgroundColor($r('app.color.surface'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.surface'))
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object;
      if (p !== undefined && p !== null && p instanceof GuideParam) {
        this.vm.setFromSettings((p as GuideParam).fromSettings);
      }
    })
  }
}
