/**
 * HomeTopAppBar (source: feature/main/view/HomeScreen.kt HomeTopAppBar — M3 TopAppBar with
 * enterAlwaysScrollBehavior, container = colorScheme.background).
 *
 * Column(padding top = status bar) { Row(height = 64 + barOffset, clipped, slots centered vertically):
 *   navigationIcon: LogoIcon 34 (padding horizontal 8) → CommonRoutes.About
 *   title:          search box (Card ShapeMedium, height 38, ic_search + `搜索商品`) → GoodsRoutes.Search
 *   actions:        IconButton 27 (padding horizontal 8) ic_github → CommonRoutes.Web(url, `GitHub`)
 * } (HOME-A05/A06). `barOffset` (0 … -64) is driven by the content scroll in HomeView (HOME-A07).
 * The splash → home `app_logo` shared element: the logo carries geometryTransition('app_logo'), paired with
 * LaunchRoutesSplashPage (LAUNCH-A08).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { WebParam } from '../../../core/navigation/RouteParams';
import { AvoidArea } from '../../../core/ui/base/AvoidArea';
import { TOP_APP_BAR_HEIGHT } from '../../../core/ui/base/TopAppBars';
import { CommerceSheet } from '../../../core/ui/commerce/CommerceSheet';
import { Routes } from '../../../common/Router';

/** source CommonNavigator.toWeb(url, title = "GitHub") */
const GITHUB_URL: string = 'https://github.com/Joker-x-dev/CoolMallKotlin';
const GITHUB_TITLE: string = 'GitHub';
/** LogoIcon size 34.dp, padding(horizontal = 8.dp) */
const LOGO_SIZE: number = 34;
/** Search box height 38.dp */
const SEARCH_BOX_HEIGHT: number = 38;
/** GitHub IconButton .size(27.dp) with a 24dp icon */
const GITHUB_BUTTON_SIZE: number = 27;
const GITHUB_ICON_SIZE: number = 24;
/** M3 TopAppBarHorizontalPadding 4.dp */
const TOP_BAR_EDGE_PADDING: number = 4;

@ComponentV2
export struct HomeTopAppBar {
  /** enterAlways height offset: 0 (expanded) … -TOP_APP_BAR_HEIGHT (collapsed) */
  @Param barOffset: number = 0;
  @Local avoidArea: AvoidArea = AvoidArea.get();

  private toAbout(): void {
    AppNavigator.navigate(Routes.COMMON_ROUTES_ABOUT);
  }

  private toSearch(): void {
    AppNavigator.navigate(Routes.GOODS_ROUTES_SEARCH);
  }

  private toGithub(): void {
    const param: WebParam = new WebParam();
    param.url = GITHUB_URL;
    param.title = GITHUB_TITLE;
    AppNavigator.navigate(Routes.COMMON_ROUTES_WEB, param);
  }

  /** onSurface @ 0.6 (search icon / placeholder) */
  private onSurface60(): string {
    return CommerceSheet.onSurface60();
  }

  /** M3 default onSurfaceVariant (TopAppBar action icon color; not overridden by the app theme) */
  private onSurfaceVariant(): string {
    return ThemeManager.instance.isDark ? '#CAC4D0' : '#49454F';
  }

  build() {
    Column() {
      Row() {
        // navigationIcon: LogoIcon(34).padding(horizontal = 8).clickable { toAbout() }
        Image($r('app.media.ic_logo'))
          .width(LOGO_SIZE)
          .height(LOGO_SIZE)
          .objectFit(ImageFit.Contain)
          .margin({ left: TOP_BAR_EDGE_PADDING + Dimens.spaceHorizontalSmall, right: Dimens.spaceHorizontalSmall })
          .draggable(false)
          .geometryTransition('app_logo')
          .onClick(() => {
            this.toAbout();
          })

        // title: search box (Card ShapeMedium, fillMaxWidth, height 38) → GoodsSearch
        Row() {
          Image($r('app.media.ic_search'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .fillColor(this.onSurface60())
            .accessibilityText($r('app.string.search'))
          Text($r('app.string.search_goods'))
            .margin({ left: Dimens.spaceHorizontalSmall })
            .fontSize(Dimens.fontBodyMedium)
            .lineHeight(Dimens.lineBodyMedium)
            .fontColor(this.onSurface60())
        }
        .layoutWeight(1)
        .height(SEARCH_BOX_HEIGHT)
        .padding({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })
        .justifyContent(FlexAlign.Center) // source Arrangement.Center
        .alignItems(VerticalAlign.Center) // source CenterVertically
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)
        .onClick(() => {
          this.toSearch();
        })

        // actions: IconButton(size 27, padding horizontal 8) { ic_github } → Web(GitHub)
        Stack({ alignContent: Alignment.Center }) { // IconButton centers its icon
          Image($r('app.media.ic_github'))
            .width(GITHUB_ICON_SIZE)
            .height(GITHUB_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .fillColor(this.onSurfaceVariant())
            .draggable(false)
        }
        .width(GITHUB_BUTTON_SIZE)
        .height(GITHUB_BUTTON_SIZE)
        .margin({ left: Dimens.spaceHorizontalSmall, right: Dimens.spaceHorizontalSmall + TOP_BAR_EDGE_PADDING })
        .onClick(() => {
          this.toGithub();
        })
      }
      .width('100%')
      .height(TOP_APP_BAR_HEIGHT + this.barOffset)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center) // TopAppBarLayout centers its slots vertically
      .clip(true)
    }
    .width('100%')
    .padding({ top: this.avoidArea.top }) // TopAppBar windowInsets = statusBars
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_page')) // container / scrolledContainer = background
  }
}

