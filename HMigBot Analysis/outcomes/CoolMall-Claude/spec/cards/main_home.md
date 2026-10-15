# Home page (MainRoutes.Main shell / Home tab)

Route: MainRoutes.Main (the main shell, registered in feature/main/.../navigation/MainGraph.kt:22; the Home tab is pager page 0; MainRoutes.Home is only TopLevelDestination metadata and has no standalone entry)
Sources: feature/main/src/main/java/com/joker/coolmall/feature/main/view/MainScreen.kt, view/HomeScreen.kt, viewmodel/MainViewModel.kt, viewmodel/HomeViewModel.kt, component/BottomNavigationBar.kt, component/FlashSaleItem.kt, component/CommonScaffold.kt, skeleton/HomeSkeleton.kt, model/TopLevelDestination.kt, state/HomeUiState.kt (unused), core/common/.../base/viewmodel/BaseNetWorkListViewModel.kt, core/ui/.../network/BaseNetWorkListView.kt, core/ui/.../modal/CouponModal.kt, core/ui/.../swiper/Swiper.kt, core/network/.../service/PageService.kt, GoodsService.kt, CouponService.kt, core/model/.../entity/Home.kt

## Assertions
- HOME-A01 [ui] The main shell has a bottom navigation bar with 4 tabs in a fixed order: `主页`, `分类`, `购物车`, `我的`; the Home tab is selected by default at startup。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/model/TopLevelDestination.kt:21
- HOME-A02 [ui] Tapping a bottom tab switches to that tab's page, and the selected tab's label shows in the primary color while unselected labels are dimmed。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/component/BottomNavigationBar.kt:71
- HOME-A03 [ui] The four tab pages can also be switched by swiping left or right (horizontal pager), and the selected bottom tab stays in sync with the page swiped to。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MainScreen.kt:89
- HOME-A04 [ui] The selected tab icon plays its animation once (Lottie: home/category/cart/me), and unselected icons stay on the first frame。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/component/BottomNavigationBar.kt:111
- HOME-A05 [ui] The home top content avoids the status bar (TopAppBar handles the status bar inset; the bottom bar avoids the navigation bar)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:513
- HOME-A06 [ui] The home top bar has the app logo on the left (tapping opens the About page), a search box in the middle with the placeholder `搜索商品` (tapping opens the goods search page), and a GitHub icon on the right (tapping opens a built-in web page with the title `GitHub` loading https://github.com/Joker-x-dev/CoolMallKotlin)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:519
- HOME-A07 [ui] The home top bar collapses as the content scrolls up and reappears on scroll down (enterAlways)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:183
- HOME-A08 [ui] During the first load the home page shows a dedicated skeleton screen (banner/coupon/category/flash sale/title/recommended placeholders) instead of a generic loader, and it stays at least 320ms。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:123
- HOME-A09 [backend] When the home page opens it requests the home aggregate API (GET page/home), and the response fills the banner, coupon, category, flash sale, recommended goods and first page of all goods all at once。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:107
- HOME-A10 [ui] When the home data fails to load, the page shows the network error state `网络连接失败`/`请检查网络连接后重试`, and tapping `重新加载` requests the home data again。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:197
- HOME-A11 [ui] The banner carousel shows the banner images at a 2:1 ratio, autoplays every 3 seconds in a loop with page indicators, and banners do not respond to taps。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:366
- HOME-A12 [ui] When there are coupons, the coupon bar shows coupon titles you can swipe through (no autoplay, no indicator), with a `领取` link on the right; tapping it opens the `领取优惠券` bottom sheet listing all home coupons。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:636
- HOME-A13 [backend] Tapping receive on a coupon in the sheet: when not logged in, the sheet closes and the app goes to the login page; when logged in, it calls POST market/coupon/user/receive (couponId), and on success shows the success toast message returned by the server。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:203
- HOME-A14 [ui] The category area shows categories in a grid of 5 per row (round image + name), with blank space filling any incomplete row。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:403
- HOME-A15 [backend] Tapping a home category goes to the goods category list page, passing as typeId the comma-joined IDs of all child categories in categoryAll whose parentId equals that category。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:164
- HOME-A16 [ui] The flash sale card has the title `限时精选` with a `查看全部` entry on the right (tapping opens the goods category list with featured=true), and below it a horizontally scrolling list of goods (image/one-line title/price); tapping a good opens its detail page。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:475
- HOME-A17 [ui] When home goods data exists, it shows a `推荐商品` section title followed by the recommended goods as a vertical list (horizontal list rows), and tapping one opens goods detail。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:310
- HOME-A18 [ui] Under the `全部商品` section title, all goods show as a two-column staggered grid, and tapping a good opens goods detail。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:332
- HOME-A19 [backend] Scrolling to within 3 items of the end of the grid triggers load more: it requests POST goods/info/page (page starting at 2, size=10) and appends the results to the all goods list; when there is no next page it shows `没有更多了`, and on failure it shows a tap-to-retry state and rolls back the page number。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:81
- HOME-A20 [backend] Pull-to-refresh resets the page number to 1 and requests page/home again, replacing all the home section data and the all goods list; refresh is ignored while a load is in progress。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/HomeViewModel.kt:147
- HOME-A21 [ui] Home sections are shown conditionally: when banner/coupon/category/flashSale/goods in the home data is null, that section (or its section title) is not shown。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:272

## Components and interactions
| Element | Text/ID | Behavior | Anchor |
|---|---|---|---|
| Bottom tab 1 | `主页` (R.string.home, raw/home Lottie) | switch to pager page 0 HomeRoute | model/TopLevelDestination.kt:21 |
| Bottom tab 2 | `分类` (raw/category) | page 1 CategoryRoute | model/TopLevelDestination.kt:26 |
| Bottom tab 3 | `购物车` (raw/cart) | page 2 CartRoute(MainRoutes.Cart()) | model/TopLevelDestination.kt:31 |
| Bottom tab 4 | `我的` (raw/me) | page 3 MeRoute | model/TopLevelDestination.kt:36 |
| Top-left logo | LogoIcon (sharedElement key `app_logo`) | CommonNavigator.toAbout() → CommonRoutes.About | view/HomeScreen.kt:519 |
| Top search box | `搜索商品`, icon contentDescription `搜索` | GoodsNavigator.toSearch() → GoodsRoutes.Search | view/HomeScreen.kt:543 |
| Top-right GitHub | ic_github | CommonNavigator.toWeb(url, title=`GitHub`) | view/HomeScreen.kt:571 |
| Banner | Banner.pic list | autoplay 3000ms loop, indicators, no tap | view/HomeScreen.kt:366 |
| Coupon bar | coupon.title swipe + `领取` | showCouponModal() | view/HomeScreen.kt:636 |
| Coupon sheet | title `领取优惠券`, CouponCardMode.RECEIVE | onCouponAction(id) → receiveCoupon; onDismiss → hideCouponModal | view/HomeScreen.kt:217 |
| Category item | category.pic + name | toGoodsCategoryPage(id) → GoodsRoutes.Category(typeId="child ids joined") | view/HomeScreen.kt:415 |
| Flash sale header | `限时精选` / `查看全部`, ic_time | GoodsNavigator.toCategory(featured=true) | view/HomeScreen.kt:475 |
| Flash sale item | FlashSaleItem(mainPic, title, price) | GoodsNavigator.toDetail(id) | component/FlashSaleItem.kt:40 |
| Recommended section | `推荐商品` + GoodsListItem | toDetail | view/HomeScreen.kt:310 |
| All goods | `全部商品` + GoodsGridItem | toDetail | view/HomeScreen.kt:332 |
| Load-more footer | `上拉加载更多`/`正在加载...`/`加载成功`/`加载失败，点击重试`/`没有更多了` (core/ui strings) | RefreshLayout | view/HomeScreen.kt:260 |
| Error state | `网络连接失败`/`请检查网络连接后重试`/`重新加载` | onRetry=loadHomeData | core/ui/.../network/BaseNetWorkListView.kt:69 |

## Data and APIs
- `GET page/home` → `NetworkResponse<Home>`; Home fields: banner: List<Banner>(pic), category: List<Category>(id, name, pic, parentId), categoryAll: List<Category>, flashSale: List<Goods>, recommend: List<Goods>, coupon: List<Coupon>(id, title…), goods: List<Goods> (the first page of all goods). Anchors core/network/.../service/PageService.kt:23, core/model/.../entity/Home.kt:18.
- `POST goods/info/page` body GoodsSearchRequest{page, size(default 20; home passes 10), typeId?, minPrice?, maxPrice?, keyWord?, order?} → NetworkPageData<Goods>{list, pagination{page,size,total}}; hasNextPage = size*page < total. Anchor core/network/.../service/GoodsService.kt:60.
- `POST market/coupon/user/receive` body {couponId: Long} → NetworkResponse<String> (data is the success message, shown as a success toast; showToast=true shows a toast on error too). Anchor core/network/.../service/CouponService.kt:25.
- Login state: AppState.isLoggedIn (in-memory StateFlow, see the auth domain card). No local storage keys used directly on this page.
- Goods fields used: id, title, mainPic, price.

## Cross-cutting notes
MainViewModel only keeps currentPageIndex (initially 0); tab taps and swipes both write to it; tab taps use scrollToPage (jump with no animation). HomeViewModel extends BaseNetWorkListViewModel<Goods> but overrides first load/refresh: loadHomeData is called from init, success sets uiState=Success directly (never Empty, even when goods is empty), loadMoreState=PullToLoad if goods is non-empty else NoMore; load more uses the base onLoadMore (currentPage++ → page 2 → requestListData) and handleSuccess (show `加载成功` first, append after 400ms). Load more triggers when lastIndex >= total-3, it is not Loading/NoMore, and the list is non-empty. The coupon sheet open state lives in the ViewModel. HomeUiState.kt (Loading/Success/Error) is not referenced by the home page; it actually uses BaseNetWorkListUiState. Dark mode follows the global AppTheme; the top bar uses colorScheme.background.

## Platform risks
- Nested pagers: the outer 4-tab HorizontalPager + inner banner/coupon swipers; in ArkTS, Swiper/Tabs nested gesture conflicts need handling (inner Swiper should claim horizontal swipes first). Each tab page stays alive in the pager (HomeViewModel does not refetch on tab switch).
- The loaded-from-home first page + load more starting at page 2 (size=10) relies on the server returning 10 items for home goods per page; if counts differ, items may be duplicated or skipped. Faithful reproduction is enough.
- Source defect: when a home refresh fails, onError only sets uiState=Error without resetting isRefreshing (the whole page switches to the error view). Keep or fix it, and record the decision in the design doc.
- Bottom tab icons are Lottie raw resources (home/category/cart/me.json); HarmonyOS needs @ohos/lottie or an alternative (static icons count as visual degradation).
- Shared-element transition (`app_logo` between splash and home) and the top bar enterAlways collapse need replacements via ArkUI geometryTransition / scroll offset.
- The staggered grid (two-column waterfall) mixed with full-width sections → use WaterFlow + sections in ArkUI or List+header; pull-to-refresh uses Refresh.
