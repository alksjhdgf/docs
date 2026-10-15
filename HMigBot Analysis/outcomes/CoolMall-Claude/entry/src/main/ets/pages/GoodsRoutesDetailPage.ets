/**
 * GoodsRoutesDetailPage — goods detail (source: feature/goods/view/GoodsDetailScreen.kt GoodsDetailRoute /
 * GoodsDetailScreen / GoodsDetailContentView / GoodsDetailContentWithScroll / GoodsBanner).
 *
 * Param: GoodsDetailParam(goodsId). A missing / foreign param keeps the page with an empty state.
 *
 * Layout (Scaffold without status / navigation bar insets — edge to edge):
 *   NetWorkStateView: loading → GoodsDetailLoadingSkeleton, error → EmptyNetwork + retry (GOODS-A01)
 *   success → Stack {
 *     List { banner (square, no autoplay, under the status bar) | info card | delivery card | 12 |
 *            [comments card | 12] | `商品详情` header (top corners 12) | detail images (last: bottom corners 12) |
 *            120 spacer }
 *     floating top bar: back / share, background alpha = min(scroll px, 255) (GOODS-A16/A17)
 *     bottom action bar: `客服` / `购物车` / `加入购物车` / `立即购买` (GOODS-A12)
 *   }
 *   + spec sheet (SpecSelectSheet, specs loaded once fully shown — GOODS-A05~A11)
 *   + coupon sheet `领取优惠券` (GOODS-A03/A04)
 */
import { Routes } from '../common/Router';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { CartParam, GoodsCommentParam, GoodsDetailParam } from '../core/navigation/RouteParams';
import { Dimens } from '../core/designsystem/Dimens';
import { Comment, Goods, GoodsDetail, GoodsSpec } from '../core/model/Goods';
import { Coupon } from '../core/model/Market';
import { SelectedGoods } from '../core/model/Order';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { EmptyData, NetWorkStateView } from '../core/ui/base/StateViews';
import { CommerceSheet } from '../core/ui/commerce/CommerceSheet';
import { CouponModal } from '../core/ui/commerce/CouponSheets';
import { SpecSelectSheet, SpecSelectState } from '../core/ui/commerce/SpecSelectSheet';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { NetWorkImage } from '../core/ui/widget/Images';
import { AppListItem } from '../core/ui/widget/ListItem';
import { WeSwiper } from '../core/ui/widget/Swiper';
import { GoodsDetailViewModel } from '../feature/goods/detail/GoodsDetailViewModel';
import { GoodsDetailLoadingSkeleton } from '../feature/goods/detail/GoodsDetailSkeleton';
import {
  GoodsActionBar,
  GoodsCommentsCard,
  GoodsDeliveryCard,
  GoodsDetailTopBar,
  GoodsInfoCard
} from '../feature/goods/detail/GoodsDetailViews';

/** Bottom spacer leaving room for the action bar (source Spacer(120.dp)) */
const BOTTOM_SPACER: number = 120;
/** Minimum height of a detail image (source heightIn(min = 200.dp)) */
const DETAIL_IMAGE_MIN_HEIGHT: number = 200;
/** Top bar alpha upper bound (source coerceIn(0, 255)) */
const MAX_ALPHA: number = 255;

@Builder
export function GoodsRoutesDetailPageBuilder() {
  GoodsRoutesDetailPage()
}

@ComponentV2
struct GoodsRoutesDetailPage {
  @Local vm: GoodsDetailViewModel = new GoodsDetailViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();
  /** Floating top bar background alpha 0..255 */
  @Local topBarAlpha: number = 0;
  /** Required route param missing → empty state */
  @Local paramMissing: boolean = false;

  /** Spec sheet remember{} state (quantity, grid/list) kept across openings */
  private specSheetState: SpecSelectState = new SpecSelectState();
  private listScroller: Scroller = new Scroller();
  private started: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (this.started) {
      return;
    }
    this.started = true;
    if (p !== undefined && p !== null && p instanceof GoodsDetailParam) {
      this.vm.start((p as GoodsDetailParam).goodsId);
    } else {
      this.paramMissing = true;
    }
  }

  // ------------------------------------------------------------------ data helpers

  private detail(): GoodsDetail {
    const d: GoodsDetail | null = this.vm.data;
    return d !== null ? d : new GoodsDetail();
  }

  private goods(): Goods {
    return this.detail().goodsInfo;
  }

  private bannerPics(): string[] {
    const pics: string[] | null = this.goods().pics;
    return pics !== null && pics !== undefined ? pics : [];
  }

  private contentPics(): string[] {
    const pics: string[] | null = this.goods().contentPics;
    return pics !== null && pics !== undefined ? pics : [];
  }

  private comments(): Comment[] {
    return this.detail().comment;
  }

  private coupons(): Coupon[] {
    return this.detail().coupon;
  }

  /** The last detail image gets the bottom corners (source clip(RoundedCornerShape(bottomStart/End = 12))) */
  private detailImageRadius(index: number): BorderRadiuses {
    const last: boolean = index === this.contentPics().length - 1;
    const r: BorderRadiuses = {
      topLeft: 0,
      topRight: 0,
      bottomLeft: last ? Dimens.radiusMedium : 0,
      bottomRight: last ? Dimens.radiusMedium : 0
    };
    return r;
  }

  /** LazyListState → alpha: first item scrolled by N px → N (≤ 255); later items → 255 */
  private onListScroll(): void {
    const yVp: number = this.listScroller.currentOffset().yOffset;
    const px: number = this.getUIContext().vp2px(Math.max(0, yVp));
    const alpha: number = Math.min(MAX_ALPHA, Math.round(px));
    if (alpha !== this.topBarAlpha) {
      this.topBarAlpha = alpha;
    }
  }

  // ------------------------------------------------------------------ navigation

  private toComment(): void {
    AppNavigator.navigate(Routes.GOODS_ROUTES_COMMENT, new GoodsCommentParam(this.goods().id));
  }

  private toCsChat(): void {
    AppNavigator.navigate(Routes.CS_ROUTES_CHAT);
  }

  private toCart(): void {
    AppNavigator.navigate(Routes.MAIN_ROUTES_CART, new CartParam(true));
  }

  // ------------------------------------------------------------------ builders

  @Builder
  loadingSkeleton() {
    GoodsDetailLoadingSkeleton()
  }

  @Builder
  bannerPage(index: number) {
    NetWorkImage({ model: this.bannerPics()[index] })
  }

  @Builder
  detailHeaderTitle() {
    TitleWithLine({ titleText: $r('app.string.goods_detail') })
  }

  @Builder
  listContent() {
    List({ scroller: this.listScroller }) {
      // carousel at the very top, under the status bar (no padding)
      ListItem() {
        Column() {
          WeSwiper({
            pageCount: this.bannerPics().length,
            autoplay: false,
            pageContent: (index: number): void => {
              this.bannerPage(index)
            }
          })
        }
        .width('100%')
        .aspectRatio(1)
        .alignItems(HorizontalAlign.Start)
      }

      // basic info
      ListItem() {
        Column() {
          GoodsInfoCard({
            goods: this.goods(),
            coupons: this.coupons(),
            selectedSpec: this.vm.selectedSpec,
            onShowSpecModal: () => {
              this.vm.showSpecModal();
            },
            onShowCouponModal: () => {
              this.vm.showCouponModal();
            }
          })
        }
        .width('100%')
        .padding(Dimens.spacePaddingMedium)
        .alignItems(HorizontalAlign.Start)
      }

      // delivery
      ListItem() {
        Column() {
          GoodsDeliveryCard()
        }
        .width('100%')
        .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
        .alignItems(HorizontalAlign.Start)
      }

      ListItem() {
        Column()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
      }

      // comments
      if (this.comments().length > 0) {
        ListItem() {
          Column() {
            GoodsCommentsCard({
              comments: this.comments(),
              onCommentClick: () => {
                this.toComment();
              }
            })
          }
          .width('100%')
          .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          Column()
            .width('100%')
            .height(Dimens.spaceVerticalMedium)
        }
      }

      // `商品详情` header (Surface, top corners 12)
      ListItem() {
        Column() {
          Column() {
            AppListItem({
              itemTitle: '',
              showArrow: false,
              clickable: false,
              hasLeadingContent: true,
              leadingContent: (): void => {
                this.detailHeaderTitle()
              }
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius({ topLeft: Dimens.radiusMedium, topRight: Dimens.radiusMedium })
          .clip(true)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
        .alignItems(HorizontalAlign.Start)
      }

      // rich-text detail images, in order (GOODS-A15)
      ForEach(this.contentPics(), (pic: string, index: number) => {
        ListItem() {
          Column() {
            Column() {
              Image(pic)
                .width('100%')
                .constraintSize({ minHeight: DETAIL_IMAGE_MIN_HEIGHT })
                .objectFit(ImageFit.Cover) // NetWorkImage default ContentScale.Crop
                .draggable(false)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .borderRadius(this.detailImageRadius(index))
            .clip(true)
          }
          .width('100%')
          .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
          .alignItems(HorizontalAlign.Start)
        }
      }, (pic: string, index: number) => index + '_' + pic + '_' + this.contentPics().length)

      // room for the bottom action bar
      ListItem() {
        Column()
          .width('100%')
          .height(BOTTOM_SPACER)
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .onDidScroll(() => {
      this.onListScroll();
    })
  }

  @Builder
  detailContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.listContent()

      // floating top bar
      Column() {
        GoodsDetailTopBar({
          topBarAlpha: this.topBarAlpha,
          hasAnimated: this.vm.hasAnimated,
          statusBarTop: this.avoidArea.top,
          onBackClick: () => {
            AppNavigator.back();
          },
          onShareClick: () => {
            // source: onShareClick = { /* TODO: 分享功能 */ }
            console.info('TODO:share:GoodsDetailTopBar');
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .hitTestBehavior(HitTestMode.Transparent)

      // bottom action bar anchored to the bottom (Alignment.BottomCenter)
      Column() {
        Blank()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.None)
        GoodsActionBar({
          hasAnimated: this.vm.hasAnimated,
          navBarBottom: this.avoidArea.bottom,
          onAddToCartClick: () => {
            this.vm.showSpecModal();
          },
          onBuyNowClick: () => {
            this.vm.showSpecModal();
          },
          onCsClick: () => {
            this.toCsChat();
          },
          onCartClick: () => {
            this.toCart();
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      // LaunchedEffect(Unit) { onTriggerAnimation() }
      this.vm.triggerAnimation();
    })
  }

  @Builder
  specSheet() {
    Column() {
      SpecSelectSheet({
        goods: this.vm.data !== null ? this.goods() : null,
        specUiState: this.vm.specUiState,
        specs: this.vm.specs,
        selectedSpec: this.vm.selectedSpec,
        sheetState: this.specSheetState,
        onDismiss: () => {
          this.vm.hideSpecModal();
        },
        onSpecSelected: (spec: GoodsSpec) => {
          this.vm.selectSpec(spec);
        },
        onAddToCart: (sg: SelectedGoods) => {
          this.vm.addToCart(sg);
        },
        onBuyNow: (sg: SelectedGoods) => {
          this.vm.buyNow(sg);
        },
        onRetry: () => {
          this.vm.loadGoodsSpecs();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  couponSheet() {
    Column() {
      CouponModal({
        coupons: this.coupons(),
        onCouponAction: (couponId: number) => {
          this.vm.onCouponAction(couponId);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  paramMissingContent() {
    EmptyData()
  }

  build() {
    NavDestination() {
      Column() {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.paramMissing) {
            // conventions §E: missing goodsId → stay on the page with an empty state + back button
            AppScaffold({
              titleText: '',
              showBackIcon: true,
              onBack: () => {
                AppNavigator.back();
              },
              content: (): void => {
                this.paramMissingContent()
              }
            })
          } else {
            NetWorkStateView({
              uiState: this.vm.uiState,
              useCustomLoading: true,
              customLoading: (): void => {
                this.loadingSkeleton()
              },
              content: (): void => {
                this.detailContent()
              },
              onRetry: () => {
                this.vm.retryRequest();
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .bindSheet(this.vm.specModalVisible, this.specSheet(),
          CommerceSheet.options(() => {
            this.vm.hideSpecModal();
          }, () => {
            // spec list requested only once the sheet is fully shown (GOODS-A06)
            this.vm.onSpecModalExpanded();
          }))
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
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
