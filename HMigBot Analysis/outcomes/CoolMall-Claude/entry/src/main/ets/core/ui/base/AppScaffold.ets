/**
 * AppScaffold — common page frame (source: core/ui/component/scaffold/AppScaffold.kt → M3 Scaffold).
 *
 * Layout: Column {
 *   [top bar]   custom `topBar` (useCustomTopBar) | LargeTopAppBar (useLargeTopBar) | CenterTopAppBar
 *   [content]   layoutWeight(1), background `bgColor` (source backgroundColor = colorScheme.background = bg_page)
 *   [bottom bar] `bottomBar` (hasBottomBar)
 * }
 * Insets (AvoidArea, written by the window layer; this frame only reads them):
 *  - top: the built-in top bars pad themselves by AvoidArea.top (M3 TopAppBar status-bar insets). A custom
 *    `topBar` must handle the status bar itself (as in source, where e.g. SearchTopAppBar applies its own insets).
 *  - bottom: without a bottom bar the content is padded by AvoidArea.bottom (Scaffold contentWindowInsets);
 *    with a bottom bar the bottom bar owns the navigation-bar padding (source bottom bars use
 *    navigationBarsPadding()).
 *  - contentShouldConsumePadding = true (source): the content is laid out under the top / bottom bars with no
 *    padding; the would-be padding is reported through onContentPadding(top, bottom).
 *
 * Large top bar (source useLargeTopBar + exitUntilCollapsedScrollBehavior): the content sits in an outer
 * vertical Scroll whose first LARGE_TOP_APP_BAR_COLLAPSE_RANGE vp of scroll collapse the bar. For the bar to
 * collapse when the page content scrolls, the content's own scrollable (Scroll/List) must set
 * `.nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })`
 * (Compose did this through nestedScroll(scrollBehavior.nestedScrollConnection)). The content area always has
 * the collapsed-state height (viewport - status bar - 64vp).
 *
 * Usage:
 *   AppScaffold({
 *     titleText: $r('app.string.xxx'),
 *     content: (): void => { this.pageContent() }
 *   })
 */
import { AppNavigator } from '../../navigation/AppNavigator';
import { AvoidArea } from './AvoidArea';
import {
  CenterTopAppBar,
  LargeTopAppBar,
  LARGE_TOP_APP_BAR_COLLAPSE_RANGE,
  LARGE_TOP_APP_BAR_EXPANDED_HEIGHT,
  TOP_APP_BAR_HEIGHT
} from './TopAppBars';

@ComponentV2
export struct AppScaffold {
  /** Top bar title (source title / titleText); '' → no title */
  @Param titleText: ResourceStr = '';
  /** Source showBackIcon */
  @Param showBackIcon: boolean = true;
  /** CenterTopAppBar container color (source topBarColors; default M3 surface) */
  @Param topBarColor: ResourceColor = $r('app.color.surface');
  /** Page background (source backgroundColor, default colorScheme.background) */
  @Param bgColor: ResourceColor = $r('app.color.bg_page');
  /** Source useLargeTopBar */
  @Param useLargeTopBar: boolean = false;
  @Param largeTopBarExpandedBackgroundColor: ResourceColor = $r('app.color.bg_page');
  @Param largeTopBarCollapsedBackgroundColor: ResourceColor = $r('app.color.bg_page');
  /** Use the `topBar` slot instead of the built-in bars (source topBar != null) */
  @Param useCustomTopBar: boolean = false;
  /** Show the `bottomBar` slot (source bottomBar) */
  @Param hasBottomBar: boolean = false;
  /** Source contentShouldConsumePadding */
  @Param contentShouldConsumePadding: boolean = false;

  /** Back click (source onBackClick); default AppNavigator.back() */
  @Event onBack: () => void = () => {
    AppNavigator.back();
  };
  /** Reports the top / bottom padding the content should apply itself (contentShouldConsumePadding) */
  @Event onContentPadding: (top: number, bottom: number) => void = (top: number, bottom: number) => {
  };

  @BuilderParam topBarActions: () => void = this.emptyBuilder;
  @BuilderParam topBar: () => void = this.emptyBuilder;
  @BuilderParam bottomBar: () => void = this.emptyBuilder;
  @BuilderParam content: () => void = this.emptyBuilder;

  @Local avoidArea: AvoidArea = AvoidArea.get();
  /** Measured top bar height (consume-padding mode) */
  @Local topBarHeight: number = 0;
  /** Measured bottom bar height (consume-padding mode) */
  @Local bottomBarHeight: number = 0;
  /** Large bar: viewport height of the content region */
  @Local viewportHeight: number = 0;
  /** Large bar: collapse offset 0..LARGE_TOP_APP_BAR_COLLAPSE_RANGE */
  @Local collapseOffset: number = 0;

  private largeScroller: Scroller = new Scroller();

  @Builder
  emptyBuilder() {
  }

  /** Bottom inset applied when there is no bottom bar */
  private contentBottomInset(): number {
    return this.hasBottomBar ? 0 : this.avoidArea.bottom;
  }

  private reportPadding(): void {
    const bottom: number = this.hasBottomBar ? this.bottomBarHeight : this.avoidArea.bottom;
    this.onContentPadding(this.topBarHeight, bottom);
  }

  @Builder
  standardTopBar() {
    if (this.useCustomTopBar) {
      this.topBar()
    } else {
      CenterTopAppBar({
        titleText: this.titleText,
        showBackIcon: this.showBackIcon,
        barColor: this.topBarColor,
        onBack: () => {
          this.onBack();
        },
        actions: (): void => {
          this.topBarActions()
        }
      })
    }
  }

  @Builder
  bottomSlot() {
    if (this.hasBottomBar) {
      Column() {
        this.bottomBar()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.bottomBarHeight = Number(newArea.height);
        if (this.contentShouldConsumePadding) {
          this.reportPadding();
        }
      })
    }
  }

  /** Standard frame: top bar + content + bottom bar */
  @Builder
  standardFrame() {
    if (this.contentShouldConsumePadding) {
      // Content under the bars (source: root Box not padded); bars overlay the content
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          this.content()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)

        Column() {
          Column() {
            this.standardTopBar()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.topBarHeight = Number(newArea.height);
            this.reportPadding();
          })
          Blank()
            .layoutWeight(1)
            .hitTestBehavior(HitTestMode.None) // spacer between the bars: never blocks the content
          this.bottomSlot()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgColor)
    } else {
      Column() {
        this.standardTopBar()
        Column() {
          this.content()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: this.contentBottomInset() })
        .alignItems(HorizontalAlign.Start)
        .clip(true)
        this.bottomSlot()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgColor)
      .alignItems(HorizontalAlign.Start)
    }
  }

  /** Large collapsible frame */
  @Builder
  largeFrame() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll(this.largeScroller) {
          Column() {
            // Space under the (overlaid) expanded bar
            Column()
              .width('100%')
              .height(this.avoidArea.top + LARGE_TOP_APP_BAR_EXPANDED_HEIGHT)
            Column() {
              this.content()
            }
            .width('100%')
            .height(Math.max(0, this.viewportHeight - this.avoidArea.top - TOP_APP_BAR_HEIGHT))
            .alignItems(HorizontalAlign.Start)
            .clip(true)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart) // source content is top aligned
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .onDidScroll(() => {
          const y: number = this.largeScroller.currentOffset().yOffset;
          this.collapseOffset = Math.min(LARGE_TOP_APP_BAR_COLLAPSE_RANGE, Math.max(0, y));
        })

        LargeTopAppBar({
          titleText: this.titleText,
          showBackIcon: this.showBackIcon,
          collapsedFraction: this.collapseOffset / LARGE_TOP_APP_BAR_COLLAPSE_RANGE,
          expandedBackgroundColor: this.largeTopBarExpandedBackgroundColor,
          collapsedBackgroundColor: this.largeTopBarCollapsedBackgroundColor,
          onBack: () => {
            this.onBack();
          },
          actions: (): void => {
            this.topBarActions()
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ bottom: this.contentBottomInset() })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.viewportHeight = Number(newArea.height) - this.contentBottomInset();
      })
      this.bottomSlot()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.useLargeTopBar && !this.useCustomTopBar) {
      this.largeFrame()
    } else {
      this.standardFrame()
    }
  }
}
