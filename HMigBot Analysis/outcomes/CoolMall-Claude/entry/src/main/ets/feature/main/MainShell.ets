/**
 * MainShell (source: feature/main/view/MainScreen.kt MainRoute / MainScreen / MainScreenContentView +
 * viewmodel/MainViewModel.kt).
 *
 * Scaffold(contentWindowInsets excludes the status bar; bottomBar = BottomNavigationBar) →
 *   Column(bg_page) {
 *     Swiper (horizontal pager, 4 pages, no loop / autoplay / indicator, layoutWeight 1):
 *       0 HomeView · 1 CategoryTab · 2 CartView(showBackIcon = false) · 3 MeTab
 *     BottomNavigationBar(currentPageIndex)   (pads itself by the navigation bar)
 *   }
 * MainViewModel only holds currentPageIndex (initially 0 — Home selected at startup, HOME-A01): swipes write it
 * through onChange (source LaunchedEffect(pageState.currentPage) → updatePageIndex) and tab taps write it and
 * jump with no animation (updateDestination + scrollToPage) (HOME-A02/A03).
 * Pages are composed lazily like HorizontalPager (a page is built the first time it is selected or dragged
 * into view) and then stay alive, so each tab's view model keeps its state across tab switches.
 */
import { CartView } from './cart/CartView';
import { CategoryTab } from './category/CategoryTab';
import { BottomNavigationBar, TopLevelDestination } from './home/BottomNavigationBar';
import { HomeView } from './home/HomeView';
import { MeTab } from './me/MeTab';

/** Page count = TopLevelDestination.entries.size */
const PAGE_COUNT: number = TopLevelDestination.entries().length;

@ComponentV2
export struct MainShell {
  /** source MainViewModel.currentPageIndex */
  @Local currentPageIndex: number = 0;
  /** Pages that have been composed at least once (HorizontalPager composes visible pages only) */
  @Local composedPages: boolean[] = [true, false, false, false];

  private swiperController: SwiperController = new SwiperController();

  /** source MainViewModel.updatePageIndex / updateDestination */
  private updatePageIndex(index: number): void {
    if (index < 0 || index >= PAGE_COUNT) {
      return;
    }
    this.markComposed(index);
    if (this.currentPageIndex !== index) {
      this.currentPageIndex = index;
    }
  }

  private markComposed(index: number): void {
    if (index < 0 || index >= PAGE_COUNT || this.composedPages[index]) {
      return;
    }
    const next: boolean[] = this.composedPages.slice();
    next[index] = true;
    this.composedPages = next;
  }

  /** Bottom tab tap: onNavigationItemSelected(index) + pageState.scrollToPage(index) (no animation) */
  private onNavigationItemSelected(index: number): void {
    this.updatePageIndex(index);
    this.swiperController.changeIndex(index, false);
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.composedPages[0]) {
            HomeView()
          }
        }
        .width('100%')
        .height('100%')

        Stack({ alignContent: Alignment.TopStart }) {
          if (this.composedPages[1]) {
            CategoryTab()
          }
        }
        .width('100%')
        .height('100%')

        Stack({ alignContent: Alignment.TopStart }) {
          if (this.composedPages[2]) {
            CartView({ showBackIcon: false })
          }
        }
        .width('100%')
        .height('100%')

        Stack({ alignContent: Alignment.TopStart }) {
          if (this.composedPages[3]) {
            MeTab()
          }
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .index(0)
      .loop(false)
      .autoPlay(false)
      .indicator(false)
      .onChange((index: number) => {
        this.updatePageIndex(index);
      })
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        // the neighbour being dragged into view gets composed (pager composes visible pages)
        if (extraInfo.currentOffset < 0) {
          this.markComposed(index + 1);
        } else if (extraInfo.currentOffset > 0) {
          this.markComposed(index - 1);
        }
      })
      .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
        this.markComposed(targetIndex);
      })

      BottomNavigationBar({
        currentPageIndex: this.currentPageIndex,
        onNavigateToDestination: (index: number) => {
          this.onNavigationItemSelected(index);
        }
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_page'))
  }
}
