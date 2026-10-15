/**
 * WeSwiper + BannerSwiper (source: core/ui/component/swiper/Swiper.kt — WeSwiper / WeSwiperDefaults.Indicator).
 *
 * HorizontalPager → ArkUI Swiper (no loop, like the pager). Autoplay follows the source: after each
 * page change wait `interval` ms, then animate to (current + 1) % count (so the last page animates
 * back to the first). Indicator: a count*16 x 3 track (primary @0.2) with a 16 x 3 thumb (primary @0.6)
 * sliding to current*16, bottom-center, lifted 10vp. Both fill the slot the caller sizes.
 *
 * Generic content: pass `pageCount` and a builder taking the page index:
 *   WeSwiper({ pageCount: this.coupons.length, showIndicator: false, autoplay: false,
 *              pageContent: (index: number): void => { this.couponPage(index) } })
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { NetWorkImage } from './Images';

@Builder
function emptySwiperPage(index: number) {
}

@ComponentV2
export struct WeSwiperIndicator {
  @Param indicatorCount: number = 0;
  @Param indicatorCurrent: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(16)
        .height(3)
        .borderRadius(2)
        .backgroundColor(ThemeManager.withAlpha(ThemeManager.instance.primary, 0.6))
        .translate({ x: this.indicatorCurrent * 16 })
        .animation({ duration: 300, curve: Curve.EaseInOut })
    }
    .width(this.indicatorCount * 16)
    .height(3)
    .borderRadius(2)
    .backgroundColor(ThemeManager.withAlpha(ThemeManager.instance.primary, 0.2))
    .clip(true)
  }
}

@ComponentV2
export struct WeSwiper {
  @Param pageCount: number = 0;
  @BuilderParam pageContent: (index: number) => void = emptySwiperPage;
  @Param autoplay: boolean = true;
  @Param interval: number = 3000;
  @Param pageSpacing: number = 0;
  @Param showIndicator: boolean = true;
  @Event onPageChange: (index: number) => void = (index: number) => {
  };
  @Local current: number = 0;
  private controller: SwiperController = new SwiperController();
  private timer: number = -1;
  private alive: boolean = true;

  @Computed
  get pageIndices(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.pageCount; i++) {
      arr.push(i);
    }
    return arr;
  }

  aboutToAppear(): void {
    this.alive = true;
    this.scheduleNext();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.cancelTimer();
  }

  @Monitor('autoplay', 'pageCount', 'interval')
  onAutoplayInputsChanged(): void {
    if (this.current >= this.pageCount) {
      this.current = 0;
    }
    this.scheduleNext();
  }

  private cancelTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  /** LaunchedEffect(settledPage): delay(interval) → animateScrollToPage((current + 1) % pageCount) */
  private scheduleNext(): void {
    this.cancelTimer();
    if (!this.autoplay || this.pageCount <= 1 || !this.alive) {
      return;
    }
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.alive && this.pageCount > 1) {
        this.controller.changeIndex((this.current + 1) % this.pageCount, true);
      }
    }, this.interval);
  }

  build() {
    // indicator anchored bottom-center (source: .align(Alignment.BottomCenter).offset(y = -10.dp))
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper(this.controller) {
        ForEach(this.pageIndices, (index: number) => {
          Stack({ alignContent: Alignment.TopStart }) {
            this.pageContent(index)
          }
          .width('100%')
          .height('100%')
        }, (index: number) => 'page_' + index)
      }
      .width('100%')
      .height('100%')
      .loop(false)
      .autoPlay(false)
      .indicator(false)
      // At the first/last page a horizontal drag passes on to the parent pager (source HorizontalPager nested scroll; HOME-A03)
      .nestedScroll(SwiperNestedScrollMode.SELF_FIRST)
      .itemSpace(this.pageSpacing)
      .onChange((index: number) => {
        this.current = index;
        this.onPageChange(index);
        this.scheduleNext();
      })

      if (this.showIndicator && this.pageCount > 0) {
        Row() {
          WeSwiperIndicator({ indicatorCount: this.pageCount, indicatorCurrent: this.current })
        }
        .offset({ y: -10 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * Banner carousel of image urls (Home / GoodsDetail usage of WeSwiper + NetWorkImage).
 * `bannerRadius` clips the whole carousel (Home: ShapeMedium 12). `bannerClickable` enables onBannerClick.
 */
@ComponentV2
export struct BannerSwiper {
  @Param bannerUrls: string[] = [];
  @Param autoplay: boolean = true;
  @Param interval: number = 3000;
  @Param showIndicator: boolean = true;
  @Param bannerRadius: number = 0;
  @Param contentScale: ImageFit = ImageFit.Cover;
  @Param bannerClickable: boolean = false;
  @Event onBannerClick: (index: number) => void = (index: number) => {
  };
  @Event onPageChange: (index: number) => void = (index: number) => {
  };

  @Builder
  bannerPage(index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      NetWorkImage({
        model: index < this.bannerUrls.length ? this.bannerUrls[index] : '',
        contentScale: this.contentScale
      })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      if (this.bannerClickable) {
        this.onBannerClick(index);
      }
    })
    .hitTestBehavior(this.bannerClickable ? HitTestMode.Default : HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WeSwiper({
        pageCount: this.bannerUrls.length,
        autoplay: this.autoplay,
        interval: this.interval,
        showIndicator: this.showIndicator,
        pageContent: (index: number): void => {
          this.bannerPage(index)
        },
        onPageChange: (index: number): void => this.onPageChange(index)
      })
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.bannerRadius)
    .clip(true)
  }
}
