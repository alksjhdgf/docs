/**
 * HomeView — the Home tab of the main shell (source: feature/main/view/HomeScreen.kt HomeRoute / HomeScreen /
 * HomeContentView / Banner / Category / CategoryItem / FlashSale / HomeTopAppBar / CouponSection / CouponCard,
 * component/CommonScaffold.kt).
 *
 * Layout (CommonScaffold: background = bg_page, navigation bar excluded — the shell's bottom bar owns it):
 *   Column {
 *     HomeTopAppBar: status-bar padding + 64vp bar (logo → About | search box `搜索商品` → GoodsSearch |
 *       GitHub → Web(`GitHub`)) — enterAlways: the bar height shrinks by the scrolled-up distance and comes back
 *       on any scroll down (HOME-A05/A06/A07)
 *     NetWorkStateView (layoutWeight 1): loading → HomeLoadingSkeleton (HOME-A08), error → EmptyNetwork +
 *       `重新加载` → vm.loadHomeData() (HOME-A10), success → RefreshList(grid):
 *         7 full-line header items (always present, content conditional — HOME-A21):
 *           0 banner (2:1, autoplay 3 s, indicator, no taps — HOME-A11)
 *           1 coupon bar (swipe, no autoplay / indicator, `领取` → sheet — HOME-A12)
 *           2 categories (5 per row, blank fill — HOME-A14/A15)
 *           3 flash sale card (`限时精选` / `查看全部` → featured list, horizontal goods — HOME-A16)
 *           4 `推荐商品` title (when goods != null)   5 recommended goods list (HOME-A17)
 *           6 `全部商品` title (when goods != null)
 *         then the two-column staggered all-goods grid + load-more footer (HOME-A18/A19), pull to refresh (A20)
 *   }
 *   .bindSheet(coupon sheet `领取优惠券`, receive → vm.onCouponAction) (HOME-A12/A13)
 */
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Banner, Category, Goods } from '../../../core/model/Goods';
import { Coupon } from '../../../core/model/Market';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { GoodsCategoryParam, GoodsDetailParam } from '../../../core/navigation/RouteParams';
import { RefreshList } from '../../../core/ui/base/RefreshList';
import { NetWorkStateView } from '../../../core/ui/base/StateViews';
import { TOP_APP_BAR_HEIGHT } from '../../../core/ui/base/TopAppBars';
import { CommerceSheet } from '../../../core/ui/commerce/CommerceSheet';
import { CouponModal } from '../../../core/ui/commerce/CouponSheets';
import { GoodsGridItem, GoodsListItem } from '../../../core/ui/commerce/GoodsItems';
import { AppCard, TitleWithLine } from '../../../core/ui/widget/AppCard';
import { NetWorkImage } from '../../../core/ui/widget/Images';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { BannerSwiper, WeSwiper } from '../../../core/ui/widget/Swiper';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';
import { Routes } from '../../../common/Router';
import { FlashSaleItem } from './FlashSaleItem';
import { HomeLoadingSkeleton } from './HomeSkeleton';
import { HomeTopAppBar } from './HomeTopAppBar';
import { HomeViewModel } from './HomeViewModel';

/** Number of full-line header items before the goods grid (source item(span = FullLine) × 7) */
const HOME_HEADER_COUNT: number = 7;
/** Categories per row (source chunked(5)) */
const CATEGORY_COLUMNS: number = 5;
/** Coupon card row height: 18dp icon + 2 × 4dp box padding */
const COUPON_ROW_HEIGHT: number = 26;

/** Split a list into rows of `size` (source List.chunked) */
function chunkCategories(list: Category[], size: number): Category[][] {
  const rows: Category[][] = [];
  for (let i = 0; i < list.length; i += size) {
    rows.push(list.slice(i, i + size));
  }
  return rows;
}

@ComponentV2
export struct HomeView {
  @Local vm: HomeViewModel = new HomeViewModel();
  /** enterAlways top bar height offset: 0 (expanded) … -TOP_APP_BAR_HEIGHT (collapsed) */
  @Local barOffset: number = 0;

  private gridScroller: Scroller = new Scroller();
  private lastScrollY: number = 0;

  aboutToAppear(): void {
    // source: HomeViewModel init { loadHomeData() }
    this.vm.loadHomeData();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  @Monitor('vm.uiState')
  onUiStateChanged(monitor: IMonitor): void {
    // A different scrollable (skeleton / grid) takes over: restart delta tracking from its offset 0
    this.lastScrollY = 0;
  }

  /** enterAlwaysScrollBehavior: scrolled distance moves the bar offset, clamped to [-64, 0] */
  private onContentScroll(offsetY: number): void {
    const delta: number = offsetY - this.lastScrollY;
    this.lastScrollY = offsetY;
    if (delta === 0) {
      return;
    }
    let next: number = this.barOffset - delta;
    if (next < -TOP_APP_BAR_HEIGHT) {
      next = -TOP_APP_BAR_HEIGHT;
    }
    if (next > 0) {
      next = 0;
    }
    if (next !== this.barOffset) {
      this.barOffset = next;
    }
  }

  // ------------------------------------------------------------------ navigation

  private toGoodsDetail(goodsId: number): void {
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(goodsId));
  }

  private toFeaturedCategory(): void {
    const param: GoodsCategoryParam = new GoodsCategoryParam();
    param.featured = true;
    AppNavigator.navigate(Routes.GOODS_ROUTES_CATEGORY, param);
  }

  // ------------------------------------------------------------------ colors

  /** M3 default outlineVariant (VerticalDivider default color) */
  private outlineVariant(): string {
    return ThemeManager.instance.isDark ? '#49454F' : '#CAC4D0';
  }

  /** LocalContentColor (onSurface inside a Card) @ 0.9 */
  private onSurface90(): string {
    return ThemeManager.instance.isDark ? '#E6D1D1D1' : '#E6181818';
  }

  // ------------------------------------------------------------------ sections

  private bannerUrls(): string[] {
    const banners: Banner[] | null = this.vm.pageData.banner;
    const urls: string[] = [];
    if (banners !== null) {
      for (const b of banners) {
        urls.push(b.pic ?? '');
      }
    }
    return urls;
  }

  @Builder
  bannerSection() {
    // WeSwiper.clip(ShapeMedium) { NetWorkImage(fillMaxWidth, aspectRatio 2:1) }, autoplay 3000, indicator
    Stack({ alignContent: Alignment.TopStart }) {
      BannerSwiper({
        bannerUrls: this.bannerUrls(),
        autoplay: true,
        interval: 3000,
        showIndicator: true,
        bannerRadius: Dimens.radiusMedium,
        bannerClickable: false
      })
    }
    .width('100%')
    .aspectRatio(2)
  }

  @Builder
  couponPage(index: number) {
    // CouponCard: Row(CenterVertically, fillMaxWidth) { icon box | title (1 line, weight 1, start 8) }
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_coupon'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
          .fillColor(this.onSurface90())
          .draggable(false)
      }
      .padding(Dimens.spacePaddingXSmall)
      .backgroundColor($r('app.color.bg_content')) // surfaceVariant
      .borderRadius(4)

      Text(this.couponTitle(index))
        .layoutWeight(1)
        .margin({ left: Dimens.spaceVerticalSmall })
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  private couponTitle(index: number): string {
    const coupons: Coupon[] | null = this.vm.pageData.coupon;
    if (coupons === null || index < 0 || index >= coupons.length) {
      return '';
    }
    return coupons[index].title ?? '';
  }

  private couponCount(): number {
    const coupons: Coupon[] | null = this.vm.pageData.coupon;
    return coupons !== null ? coupons.length : 0;
  }

  @Builder
  couponSection() {
    // Card { Row(fillMaxWidth, padding 12, CenterVertically) { swiper (weight 1) | divider | `领取` } }
    Row() {
      Stack({ alignContent: Alignment.TopStart }) {
        WeSwiper({
          pageCount: this.couponCount(),
          autoplay: false,
          showIndicator: false,
          pageContent: (index: number): void => {
            this.couponPage(index)
          }
        })
      }
      .layoutWeight(1)
      .height(COUPON_ROW_HEIGHT)

      // VerticalDivider(height 20, padding horizontal 12, thickness 0.5)
      Column()
        .width(Dimens.spaceDivider)
        .height(20)
        .margin({ left: Dimens.spaceHorizontalMedium, right: Dimens.spaceHorizontalMedium })
        .backgroundColor(this.outlineVariant())

      Text($r('app.string.receive'))
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.LINK))
        .onClick(() => {
          this.vm.showCouponModal();
        })
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  categoryItem(category: Category) {
    // Column(CenterHorizontally).weight(1).clip(ShapeSmall).clickable.padding(vertical = 4)
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        NetWorkImage({ model: category.pic ?? '' })
      }
      .width('80%')
      .aspectRatio(1)
      .borderRadius(Dimens.radiusCircle)
      .clip(true)

      Text(category.name ?? '')
        .margin({ top: Dimens.spaceVerticalXSmall })
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .padding({ top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Center) // source CenterHorizontally
    .justifyContent(FlexAlign.Start)
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
    .onClick(() => {
      this.vm.toGoodsCategoryPage(category.id);
    })
  }

  @Builder
  categoryRow(rowCategories: Category[]) {
    // Row(spacedBy 4, fillMaxWidth); missing cells filled with Spacer(weight 1)
    Row({ space: 4 }) {
      ForEach(rowCategories, (category: Category) => {
        this.categoryItem(category)
      }, (category: Category, i: number) => 'cat_' + category.id + '_' + i + '_' + category.name + '_' +
        category.pic)
      ForEach(this.blankCells(rowCategories.length), (i: number) => {
        Column()
          .layoutWeight(1)
      }, (i: number) => 'cat_blank_' + i)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top) // source Row without verticalAlignment = top
  }

  private blankCells(filled: number): number[] {
    const blanks: number[] = [];
    for (let i = filled; i < CATEGORY_COLUMNS; i++) {
      blanks.push(i);
    }
    return blanks;
  }

  @Builder
  categoryContent() {
    Column() {
      ForEach(chunkCategories(this.vm.pageData.category ?? [], CATEGORY_COLUMNS), (row: Category[], i: number) => {
        this.categoryRow(row)
      }, (row: Category[], i: number) => 'cat_row_' + i + '_' + row.map((c: Category) => c.id).join('-'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  flashSaleSection() {
    // Card { AppListItem(`限时精选`, `查看全部`, ic_time) ; LazyRow(spacedBy 8).padding(12) { FlashSaleItem } }
    Column() {
      AppListItem({
        itemTitle: $r('app.string.flash_sale'),
        trailingText: $r('app.string.view_all'),
        leadingIcon: $r('app.media.ic_time'),
        onItemClick: () => {
          this.toFeaturedCategory();
        }
      })
      Column() {
        Scroll() {
          Row({ space: Dimens.spaceHorizontalSmall }) {
            ForEach(this.vm.pageData.flashSale ?? [], (goods: Goods) => {
              FlashSaleItem({
                goods: goods,
                onGoodsClick: (goodsId: number) => {
                  this.toGoodsDetail(goodsId);
                }
              })
            }, (goods: Goods, i: number) => 'flash_' + i + '_' + goods.id + '_' + goods.price + '_' + goods.title)
          }
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
        // at either end the swipe goes on to the main pager (Compose nested scroll)
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  sectionTitle(titleRes: Resource) {
    // TitleWithLine(modifier = padding(vertical = 8))
    Row() {
      TitleWithLine({ titleText: titleRes })
    }
    .width('100%')
    .padding({ top: Dimens.spaceVerticalSmall, bottom: Dimens.spaceVerticalSmall })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  recommendList() {
    // VerticalList(padding = 0): Column(fillMaxWidth, spacedBy 12, start)
    Column({ space: Dimens.spaceVerticalMedium }) {
      ForEach(this.vm.pageData.recommend ?? [], (goods: Goods) => {
        GoodsListItem({
          goods: goods,
          onGoodsClick: (goodsId: number) => {
            this.toGoodsDetail(goodsId);
          }
        })
      }, (goods: Goods, i: number) => 'rec_' + i + '_' + goods.id + '_' + goods.price + '_' + goods.title)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** Full-line header item #index; null sections render nothing (zero height) like the source `?.let` */
  @Builder
  headerItem(index: number) {
    Column() {
      if (index === 0) {
        if (this.vm.pageData.banner !== null) {
          this.bannerSection()
        }
      } else if (index === 1) {
        if (this.vm.pageData.coupon !== null) {
          this.couponSection()
        }
      } else if (index === 2) {
        if (this.vm.pageData.category !== null) {
          AppCard({
            cardContent: (): void => {
              this.categoryContent()
            }
          })
        }
      } else if (index === 3) {
        if (this.vm.pageData.flashSale !== null) {
          this.flashSaleSection()
        }
      } else if (index === 4) {
        if (this.vm.pageData.goods !== null) {
          this.sectionTitle($r('app.string.recommend_goods'))
        }
      } else if (index === 5) {
        this.recommendList()
      } else if (index === 6) {
        if (this.vm.pageData.goods !== null) {
          this.sectionTitle($r('app.string.all_goods'))
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  gridItem(item: Object, index: number) {
    GoodsGridItem({
      goods: item as Goods,
      onGoodsClick: (goodsId: number) => {
        this.toGoodsDetail(goodsId);
      }
    })
  }

  @Builder
  homeContent() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      isGrid: true,
      gridScroller: this.gridScroller,
      gridHeaderCount: HOME_HEADER_COUNT,
      itemKey: (item: Object, index: number): string => {
        const g: Goods = item as Goods;
        return 'goods_' + index + '_' + g.id + '_' + g.price + '_' + g.title;
      },
      gridHeaderBuilder: (index: number): void => {
        this.headerItem(index)
      },
      gridItemBuilder: (item: Object, index: number): void => {
        this.gridItem(item, index)
      },
      onScrollOffset: (offsetY: number) => {
        this.onContentScroll(offsetY);
      }
    })
  }

  @Builder
  loadingSkeleton() {
    HomeLoadingSkeleton({
      onScrollOffset: (offsetY: number) => {
        this.onContentScroll(offsetY);
      }
    })
  }

  @Builder
  couponSheet() {
    Column() {
      CouponModal({
        coupons: this.vm.pageData.coupon ?? [],
        onCouponAction: (couponId: number) => {
          this.vm.onCouponAction(couponId);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      HomeTopAppBar({ barOffset: this.barOffset })
      Stack({ alignContent: Alignment.TopStart }) {
        NetWorkStateView({
          uiState: this.vm.uiState,
          useCustomLoading: true,
          customLoading: (): void => {
            this.loadingSkeleton()
          },
          content: (): void => {
            this.homeContent()
          },
          onRetry: () => {
            // source onRetry = viewModel::loadHomeData
            this.vm.loadHomeData();
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.vm.couponModalVisible, this.couponSheet(),
      CommerceSheet.options(() => {
        this.vm.hideCouponModal();
      }, undefined, $r('app.color.bg_page')))
  }
}
