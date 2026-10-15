/**
 * BottomNavigationBar (source: feature/main/component/BottomNavigationBar.kt + model/TopLevelDestination.kt).
 *
 * Row(fillMaxWidth, background = surface, navigationBarsPadding): one Column per destination
 * (weight 1, CenterHorizontally, padding vertical 4, tap → onNavigateToDestination(index)):
 *   icon (30 x 30) + label (bodySmall; selected = PrimaryDefault, unselected = onSurface @ 0.5).
 * Order (TopLevelDestination.entries): 主页 / 分类 / 购物车 / 我的 (HOME-A01/A02).
 *
 * Icons (HOME-A04): each tab plays its source Lottie composition (raw/home|category|cart|me.json, embedded verbatim
 * in TabLottieData.ets) through LottieView (Canvas + the LottieComposition / LottieRenderer runtime): the selected
 * tab plays once from the start each time it becomes selected (isPlaying = selected), unselected tabs show
 * frame 0 (progress = 0f). Icon box 30 x 30 (Modifier.size(30.dp)).
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { AvoidArea } from '../../../core/ui/base/AvoidArea';
import { LottieView } from './LottieView';
import { TAB_LOTTIE_CART, TAB_LOTTIE_CATEGORY, TAB_LOTTIE_HOME, TAB_LOTTIE_ME } from './TabLottieData';

/** Lottie view size (source Modifier.size(30.dp)) */
const TAB_ICON_BOX: number = 30;

/** Top-level destination (source enum TopLevelDestination: titleTextId + animationResId) */
export class TopLevelDestination {
  titleRes: Resource;
  /** Lottie composition JSON (source animationResId = R.raw.home | category | cart | me) */
  animationJson: string;

  constructor(titleRes: Resource, animationJson: string) {
    this.titleRes = titleRes;
    this.animationJson = animationJson;
  }

  /** TopLevelDestination.entries — fixed order HOME, CATEGORY, CART, ME */
  static entries(): TopLevelDestination[] {
    return [
      new TopLevelDestination($r('app.string.home'), TAB_LOTTIE_HOME),
      new TopLevelDestination($r('app.string.category'), TAB_LOTTIE_CATEGORY),
      new TopLevelDestination($r('app.string.cart'), TAB_LOTTIE_CART),
      new TopLevelDestination($r('app.string.me'), TAB_LOTTIE_ME)
    ];
  }
}

@ComponentV2
export struct BottomNavigationBar {
  /** Selected page index (source currentPageIndex) */
  @Param currentPageIndex: number = 0;
  /** Tab tap (source onNavigateToDestination) */
  @Event onNavigateToDestination: (index: number) => void = (index: number) => {
  };

  @Local avoidArea: AvoidArea = AvoidArea.get();

  private destinations: TopLevelDestination[] = TopLevelDestination.entries();

  /** onSurface @ 0.5 (unselected label) */
  private unselectedLabelColor(): string {
    return ThemeManager.instance.isDark ? '#80D1D1D1' : '#80181818';
  }

  @Builder
  tabItem(destination: TopLevelDestination, index: number) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        LottieView({
          lottieJson: destination.animationJson,
          lottiePlaying: index === this.currentPageIndex,
          lottieSize: TAB_ICON_BOX
        })
      }
      .width(TAB_ICON_BOX)
      .height(TAB_ICON_BOX)

      Text(destination.titleRes)
        .fontSize(Dimens.fontBodySmall)
        .lineHeight(Dimens.lineBodySmall)
        // source: selected → PrimaryDefault (fixed brand color), else onSurface @ 0.5
        .fontColor(index === this.currentPageIndex ? $r('app.color.primary_default') : this.unselectedLabelColor())
    }
    .layoutWeight(1)
    .padding({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
    .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      this.onNavigateToDestination(index);
    })
  }

  build() {
    Row() {
      ForEach(this.destinations, (destination: TopLevelDestination, index: number) => {
        this.tabItem(destination, index)
      }, (destination: TopLevelDestination, index: number) => 'main_tab_' + index)
    }
    .width('100%')
    .padding({ bottom: this.avoidArea.bottom }) // navigationBarsPadding
    .backgroundColor($r('app.color.surface'))
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top) // source Row without verticalAlignment = top
  }
}
