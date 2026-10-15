/**
 * TopAppBars — top app bars (source: core/ui/component/appbar/{CenterTopAppBar,LargeTopAppBar,SearchTopAppBar}.kt).
 *
 * Exports: CenterTopAppBar, LargeTopAppBar, SearchTopAppBar, TOP_APP_BAR_HEIGHT, LARGE_TOP_APP_BAR_EXPANDED_HEIGHT,
 * LARGE_TOP_APP_BAR_COLLAPSE_RANGE, isBlankTitle().
 *
 * Common behavior:
 *  - The bar paints its container color behind the status bar and pads its content by AvoidArea.top
 *    (M3 TopAppBarDefaults.windowInsets = status bar). `avoidStatusBar: false` turns that off.
 *  - Back button (IconButton 48vp + ArrowLeftIcon ic_left 28vp, tint onSurface) calls `onBack`, whose default
 *    is AppNavigator.back(); pass `onBack` to override (source onBackClick).
 *  - `actions` = source `actions: RowScope.() -> Unit` slot (end aligned).
 */
import { AppNavigator } from '../../navigation/AppNavigator';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';
import { AvoidArea } from './AvoidArea';

/** M3 small / center-aligned TopAppBar container height */
export const TOP_APP_BAR_HEIGHT: number = 64;
/** M3 MediumTopAppBar expanded height */
export const LARGE_TOP_APP_BAR_EXPANDED_HEIGHT: number = 112;
/** Collapsible distance of the large bar (112 - 64) */
export const LARGE_TOP_APP_BAR_COLLAPSE_RANGE: number = LARGE_TOP_APP_BAR_EXPANDED_HEIGHT - TOP_APP_BAR_HEIGHT;

/** M3 IconButton touch target */
const NAV_ICON_BUTTON_SIZE: number = 48;
/** ArrowLeftIcon default size 28.dp */
const ARROW_ICON_SIZE: number = 28;
/** M3 TopAppBarHorizontalPadding */
const BAR_H_PADDING: number = 4;
/** LargeTopAppBar title font lerp(30.sp, 16.sp, collapsedFraction) */
const LARGE_TITLE_EXPANDED_FONT: number = 30;
const LARGE_TITLE_COLLAPSED_FONT: number = 16;

/** Source `finalTitle.isNotBlank()` check: a blank plain string renders no title (Resources always render) */
export function isBlankTitle(title: ResourceStr): boolean {
  if (typeof title === 'string') {
    return (title as string).trim().length === 0;
  }
  return false;
}

function clamp01(v: number): number {
  return v < 0 ? 0 : (v > 1 ? 1 : v);
}

/**
 * Center-aligned top app bar (source CenterTopAppBar → M3 CenterAlignedTopAppBar).
 * Default container color = M3 topAppBarColors() container = surface.
 */
@ComponentV2
export struct CenterTopAppBar {
  @Param titleText: ResourceStr = '';
  @Param showBackIcon: boolean = true;
  @Param barColor: ResourceColor = $r('app.color.surface');
  @Param contentColor: ResourceColor = $r('app.color.text_primary');
  @Param avoidStatusBar: boolean = true;
  @Local avoidArea: AvoidArea = AvoidArea.get();
  @Event onBack: () => void = () => {
    AppNavigator.back();
  };
  @BuilderParam actions: () => void = this.emptyBuilder;

  @Builder
  emptyBuilder() {
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) { // M3 CenterAlignedTopAppBar centers the title
        Row() {
          if (this.showBackIcon) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              Image($r('app.media.ic_left'))
                .width(ARROW_ICON_SIZE)
                .height(ARROW_ICON_SIZE)
                .objectFit(ImageFit.Contain)
                .fillColor(this.contentColor)
            }
            .width(NAV_ICON_BUTTON_SIZE)
            .height(NAV_ICON_BUTTON_SIZE)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.onBack();
            })
          }
          Blank()
          Row() {
            this.actions()
          }
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding({ left: BAR_H_PADDING, right: BAR_H_PADDING })
        .justifyContent(FlexAlign.Start) // nav icon at start, actions pushed to the end by Blank()
        .alignItems(VerticalAlign.Center)

        if (!isBlankTitle(this.titleText)) {
          Text(this.titleText)
            .fontSize(Dimens.fontTitleLarge)
            .lineHeight(Dimens.lineTitleLarge)
            .fontWeight(Dimens.weightBold)
            .fontColor(this.contentColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 'calc(100% - 112vp)' })
            .hitTestBehavior(HitTestMode.None) // display only: never block the nav / action buttons
        }
      }
      .width('100%')
      .height(TOP_APP_BAR_HEIGHT)
    }
    .width('100%')
    .padding({ top: this.avoidStatusBar ? this.avoidArea.top : 0 })
    .backgroundColor(this.barColor)
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * Large collapsible title bar (source LargeTopAppBar → M3 MediumTopAppBar, exitUntilCollapsed).
 * collapsedFraction 0 = expanded (64 + 48 title row, title 30fp), 1 = collapsed (64, title 16fp in the top row).
 * Background = lerp(expandedBackgroundColor, collapsedBackgroundColor, fraction) (rendered as two stacked
 * layers, the collapsed one at opacity = fraction). The fraction is driven by AppScaffold(useLargeTopBar).
 */
@ComponentV2
export struct LargeTopAppBar {
  @Param titleText: ResourceStr = '';
  @Param showBackIcon: boolean = true;
  @Param collapsedFraction: number = 0;
  @Param expandedBackgroundColor: ResourceColor = $r('app.color.bg_page');
  @Param collapsedBackgroundColor: ResourceColor = $r('app.color.bg_page');
  @Param contentColor: ResourceColor = $r('app.color.text_primary');
  @Param avoidStatusBar: boolean = true;
  @Local avoidArea: AvoidArea = AvoidArea.get();
  @Event onBack: () => void = () => {
    AppNavigator.back();
  };
  @BuilderParam actions: () => void = this.emptyBuilder;

  @Builder
  emptyBuilder() {
  }

  private fraction(): number {
    return clamp01(this.collapsedFraction);
  }

  private titleFontSize(): number {
    const f = this.fraction();
    return LARGE_TITLE_EXPANDED_FONT + (LARGE_TITLE_COLLAPSED_FONT - LARGE_TITLE_EXPANDED_FONT) * f;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Background layers (display only)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.expandedBackgroundColor)
        .hitTestBehavior(HitTestMode.None)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.collapsedBackgroundColor)
        .opacity(this.fraction())
        .hitTestBehavior(HitTestMode.None)

      Column() {
        // Top row: nav icon + collapsed title + actions
        Row() {
          if (this.showBackIcon) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              Image($r('app.media.ic_left'))
                .width(ARROW_ICON_SIZE)
                .height(ARROW_ICON_SIZE)
                .objectFit(ImageFit.Contain)
                .fillColor(this.contentColor)
            }
            .width(NAV_ICON_BUTTON_SIZE)
            .height(NAV_ICON_BUTTON_SIZE)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.onBack();
            })
          }
          Row() {
            if (!isBlankTitle(this.titleText)) {
              Text(this.titleText)
                .fontSize(LARGE_TITLE_COLLAPSED_FONT)
                .fontWeight(Dimens.weightBold)
                .fontColor(this.contentColor)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .opacity(this.fraction())
            }
          }
          .layoutWeight(1)
          .padding({ left: this.showBackIcon ? 4 : 12, right: 4 })
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
          Row() {
            this.actions()
          }
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height(TOP_APP_BAR_HEIGHT)
        .padding({ left: BAR_H_PADDING, right: BAR_H_PADDING })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        // Expanded title row (shrinks to 0 while collapsing)
        Row() {
          if (!isBlankTitle(this.titleText)) {
            Text(this.titleText)
              .fontSize(this.titleFontSize())
              .fontWeight(Dimens.weightBold)
              .fontColor(this.contentColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .opacity(1 - this.fraction())
          }
        }
        .width('100%')
        .height(LARGE_TOP_APP_BAR_COLLAPSE_RANGE * (1 - this.fraction()))
        .padding({ left: Dimens.spacePaddingLarge, right: Dimens.spacePaddingLarge })
        .justifyContent(FlexAlign.Start) // M3 medium title is start aligned
        .alignItems(VerticalAlign.Center)
        .clip(true)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .padding({ top: this.avoidStatusBar ? this.avoidArea.top : 0 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height((this.avoidStatusBar ? this.avoidArea.top : 0) + TOP_APP_BAR_HEIGHT +
      LARGE_TOP_APP_BAR_COLLAPSE_RANGE * (1 - this.fraction()))
  }
}

/**
 * Search top bar (source SearchTopAppBar → M3 TopAppBar, container = surface).
 * Rounded search box (surfaceVariant = bg_content): ic_search 16vp, single-line input (hint `输入内容进行搜索`,
 * IME action Search), inner `搜索` button (34vp high, primary background, white text, 24vp horizontal padding).
 * Submitting (IME or button) calls onSearch(text) and clears focus.
 */
@ComponentV2
export struct SearchTopAppBar {
  /** Initial text (source rememberSaveable(initialSearchText)) */
  @Param @Once initialSearchText: string = '';
  @Param avoidStatusBar: boolean = true;
  @Local searchText: string = '';
  @Local avoidArea: AvoidArea = AvoidArea.get();
  @Event onBack: () => void = () => {
    AppNavigator.back();
  };
  @Event onSearch: (text: string) => void = (text: string) => {
  };
  @BuilderParam actions: () => void = this.emptyBuilder;

  @Builder
  emptyBuilder() {
  }

  aboutToAppear(): void {
    this.searchText = this.initialSearchText;
  }

  private performSearch(): void {
    this.onSearch(this.searchText);
    this.getUIContext().getFocusController().clearFocus();
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_left'))
            .width(ARROW_ICON_SIZE)
            .height(ARROW_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.text_primary'))
        }
        .width(NAV_ICON_BUTTON_SIZE)
        .height(NAV_ICON_BUTTON_SIZE)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onBack();
        })

        // Search box (source Box(fillMaxWidth, clip(ShapeCircle), background(surfaceVariant)))
        Row() {
          Image($r('app.media.ic_search'))
            .width(16)
            .height(16)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.text_secondary'))
          TextInput({ text: this.searchText!!, placeholder: $r('app.string.search_hint') })
            .layoutWeight(1)
            .height(34)
            .margin({ left: Dimens.spaceHorizontalSmall, right: Dimens.spaceHorizontalSmall })
            .padding(0)
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .fontSize(Dimens.fontBodyLarge)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .placeholderFont({ size: Dimens.fontBodyLarge })
            .caretColor(ThemeManager.instance.primary)
            .enterKeyType(EnterKeyType.Search)
            .onSubmit(() => {
              this.performSearch();
            })
          // Inner search button
          Stack({ alignContent: Alignment.Center }) { // source contentAlignment = Alignment.Center
            Text($r('app.string.search'))
              .fontSize(Dimens.fontBodyLarge)
              .fontColor(Color.White)
          }
          .height(34)
          .padding({ left: Dimens.spaceHorizontalXLarge, right: Dimens.spaceHorizontalXLarge })
          .borderRadius(17)
          .backgroundColor(ThemeManager.instance.primary)
          .onClick(() => {
            this.performSearch();
          })
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 4, top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
        .margin({ left: 4, right: 12 })
        .borderRadius(Dimens.radiusCircle)
        .backgroundColor($r('app.color.bg_content'))
        .justifyContent(FlexAlign.Start) // source CenterRow: start arrangement, vertically centered
        .alignItems(VerticalAlign.Center)

        Row() {
          this.actions()
        }
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(TOP_APP_BAR_HEIGHT)
      .padding({ left: BAR_H_PADDING, right: BAR_H_PADDING })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: this.avoidStatusBar ? this.avoidArea.top : 0 })
    .backgroundColor($r('app.color.surface'))
    .alignItems(HorizontalAlign.Start)
  }
}
