# CoolMallHM implementation work cards (instructions.md)

Shared notes (every unit/slice):
- The work card is self-contained: conventions.md + this file's header + your SECTION are already embedded. Specifications come from the assertion cards `output/CoolMallHM/spec/cards/<card>.md` (assertion lines/component enumerations/APIs/storage keys), and source code is the absolute source of truth (`input/CoolMallKotlin/...`; card anchors are relative to that directory).
- Target code root `output/CoolMallHM/entry/src/main/ets/` (abbreviated `ets/` below). Resources are already converted: `$r('app.string.*')` (Chinese base + en), `$r('app.media.ic_*')` (75 svgs + avatar.jpg/logo etc.), `$r('app.color.*')`. Before using a string, grep `resources/base/element/string.json` to confirm the key; when a key is missing, append it to both base and en (append-only).
- **Navigation**: business code only navigates via `AppNavigator` (`ets/core/navigation/AppNavigator.ets`, provided by fnd-data); it has the login wall built in (DATA-A13 list). Back with `AppNavigator.back()`; back with a refresh signal via `AppNavigator.backWithRefresh()`; the caller receives it through the `onResult` callback of `AppNavigator.navigate(route, param, onResult)`. Route parameter classes all live in `ets/core/navigation/RouteParams.ets` (provided by fnd-data; the field names match the source's `XxxRoutes.Y(...)` data class constructor parameters).
- **Global state**: `AppState.instance` (login state/user info), `ThemeManager.instance` (theme mode/primary color), `AvoidArea` (in AppStorageV2: status bar/navigation bar height in vp); pages only read them.
- **Page skeleton**: a registered page `pages/<Route>Page.ets` keeps the existing `@Builder export function <Route>PageBuilder()` + `NavDestination(){...}.hideTitleBar(true)` structure; the page body may be split into the `ets/feature/<domain>/` directory (components/ViewModel). Read route parameters in `NavDestination().onReady((ctx: NavDestinationContext) => {...})`.
- Do not modify frozen files (Router.ets / Index.ets / route_map.json / main_pages.json); permission declarations and shared-file needs go into the summary's `blocked`/`sharedEdits`.

---

## SECTION: fnd-model
**Goal**: migrate `core/model` (entity/request/response/common, 49 classes) into ArkTS data classes. Output `ets/core/model/`:
- `Common.ets` (Id/Ids), `Auth.ets` (Auth + `isExpired()`/`shouldRefresh()` helpers, behavior per source Auth.kt:50-78), `User.ets`, `Goods.ets` (Goods/GoodsSpec/GoodsDetail/GoodsSearchKeyword/Category/CategoryTree/Comment/Banner/Home/Condition), `Order.ets` (Order/OrderGoods/OrderCount/Logistics/LogisticsItem/ConfirmOrder/SelectedGoods/Cart/CartGoodsSpec), `Market.ets` (Coupon/DictItem/Feedback/UserContributor/Address/Captcha/OssUpload/Footprint/SearchHistory), `Cs.ets` (CsConn/CsMsg/CsSession), `Request.ets` (all 14 Request classes + PageRequest), `Response.ets` (`NetworkResponse<T>{data?,code,message?}`, `NetworkPageData<T>{list?,pagination?}`, `NetworkPageMeta{total,size,page}`, DictDataResponse).
**Spec source**: `core/model/src/main/java/com/joker/coolmall/core/model/**` (JSON field names follow `@SerialName`; nullable → `?`/`| null`; defaults per source).
**Notes**: models are plain `export class` (no @ObservedV2, so `JSON.parse(..) as T` works directly); fields with source defaults keep those defaults; for request classes, optional fields use `?:` so `JSON.stringify` omits undefined; PageRequest defaults to page=1,size=10,sort='desc' (always sent). Preview data classes are not migrated.
**Done when**: every entity/request/response class is exported under the same name as the source; there are no UI/network dependencies; the summary lists the exports per file.

## SECTION: fnd-util
**Goal**: migrate `core/util`. Output `ets/core/util/`:
- `ToastUtils.ets`: `show(msg: ResourceStr)/showSuccess/showError`, via `promptAction` (needs a UIContext: provided by `ToastUtils.init(uiContext)`, called by fnd-app-init after loadContent).
- `ValidationUtil.ets`: isPhone (`^1[3-9]\d{9}$`) / isSmsCode (4 digits) / isCaptcha (4 letters/digits) / isPassword (≥6) (DATA-A23).
- `TimeUtils.ets`: chat time formatting + `shouldShowTime(prev,cur)` 10-minute rule (DATA-A24), plus the other functions in source TimeUtils.
- `NotificationUtil.ets`: `requestEnable(ctx)`, `showVerificationCode(code)` (title `验证码`, content `您的验证码是`+code, SlotType SOCIAL_COMMUNICATION high priority) (DATA-A21); `@kit.NotificationKit`.
- `PermissionUtils.ets`: requestNotification etc., toast copy per DATA-A22; `@kit.AbilityKit` abilityAccessCtrl.
- `PackageUtils.ets`: app name/versionName/versionCode (`bundleManager.getBundleInfoForSelf`). `LogUtils.ets`: hilog wrapper.
**Spec source**: cards/data_domain.md + `core/util/src/main/java/com/joker/coolmall/core/util/**`.
**Done when**: the functions above are exported; DATA-A21~A24 are covered.

## SECTION: fnd-network
**Goal**: migrate `core/network` + `core/result`. Output `ets/core/network/`:
- `HttpClient.ets`: BASE_URL `https://mall.dusksnow.top/app/`; `get<T>(path, query?: Map<string,string>)`/`post<T>(path, body?: Object)` → `Promise<NetworkResponse<T>>`; 10s timeouts; Authorization raw token (read `KvStore` key `auth_info`'s token synchronously, or inject `HttpClient.setTokenProvider(fn)` registered by fnd-data, to avoid a reverse dependency); network exceptions are turned into `code=-1,message='网络请求失败'`.
- `ResultHandler.ets`: `isSuccess(r)` (code==1000), `handle<T>(r, opts{showToast?, onSuccess(data:T), onError(msg)})` with semantics per DATA-A04/A05 (data==null on success gives no callback).
- `service/*.ets`: one service per source Service (Auth/Common/Coupon/Cs/Feedback/Goods/Order/Page/Contributor/UserInfo/Address/Banner), with method names and paths per the card's table (all 50+ endpoints, including unused ones).
- `FileUploadService.ets`: `uploadImage(fileUri)`/`uploadImages(uris)` per DATA-A19/A20 (base/comm/upload for credentials → `@kit.NetworkKit` http multipart (`multiFormDataList`) POST to url; copy the file into cacheDir before uploading).
**Spec source**: cards/data_domain.md §Data and APIs + `core/network/**`, `core/result/**`.
**Notes**: depends on fnd-model; may import `core/storage/KvStore` (fnd-storage, same wave: agree on the interface `KvStore.getString(key): string`); declaring the INTERNET permission is fnd-app-init's job.
**Done when**: every service method is exported; DATA-A01~A06, A19, A20 are covered.

## SECTION: fnd-storage
**Goal**: migrate `core/database` + `core/datastore` + MMKV. Output `ets/core/storage/`:
- `KvStore.ets`: Preferences file `coolmall`; `init(ctx)` (sync `getPreferencesSync`), `getString/putString/getBoolean/putBoolean/remove/getObject<T>/putObject` (sync API + `flush()`); `KvKeys` constants verbatim: `auth_info`,`user_info`,`carts`,`selectedGoodsList`,`saved_phone`,`saved_password`,`guide_shown`,`settings_theme_mode`,`settings_theme_color`.
- `AppDatabase.ets`: relationalStore `coolmall-database.db`, three tables `carts`(goodsId PK, goodsName, goodsMainPic, spec TEXT JSON), `footprints`, `search_history` (column names verbatim from the source entities); `init(ctx)`.
- `CartDao.ets` / `FootprintDao.ets` / `SearchHistoryDao.ets`: methods per the source DAOs/DataSources (CartDataSource merge/count changes/delete-spec semantics DATA-A14/A15; footprint REPLACE + getRecent(limit) + clearAll DATA-A16; search history trim/dedupe/getRecent(10) DATA-A17); **change notification**: each DAO provides `subscribe(cb: () => void): number` / `unsubscribe(id)` and calls back after every write (replaces Room Flow observation).
**Spec source**: cards/data_domain.md + `core/database/**`, `core/datastore/**`, `core/util/storage/MMKVUtils.kt`.
**Done when**: KV + 3 DAOs exported; DATA-A14~A18, A25 covered.

## SECTION: fnd-data
**Goal**: migrate `core/data` + `core/common/base` + `core/navigation`. Output:
- `ets/core/data/AppState.ets`: `@ObservedV2` singleton `AppState.instance`, `@Trace isLoggedIn/userId/auth/userInfo`; `initialize()` (**synchronously** restores from KvStore, so the login wall decides correctly on first launch), `updateUserState(auth,user)`, `updateUserInfo`, `updateAuth`, `logout()`, `refreshUserInfo()` (user/info/person) — DATA-A07~A12, LAUNCH-A19/A21.
- `ets/core/data/repository/*.ets`: thin repository wrappers per source repository (can delegate to services/DAOs directly; Cart/Footprint/SearchHistory repositories expose subscribe).
- `ets/core/common/BaseNetWorkViewModel.ets` / `BaseNetWorkListViewModel.ets`: `@ObservedV2` base classes: `uiState: 'loading'|'success'|'error'`, 320ms minimum loading, `retryRequest()`; list version adds `list/page/hasNext(size*page<total)/loadMoreState(PullToLoad|Loading|Success|Error|NoMore)/isRefreshing/onRefresh()/onLoadMore()/shouldLoadMore(lastIndex,total)` (last 3 items), 400ms delayed append on success, page rollback on failure — DATA-A06, cards/main_home.md HOME-A19/A20 semantics.
- `ets/core/navigation/AppNavigator.ets`: `navigate(route: Routes, param?: Object, onResult?: (r: Object) => void)`: when the route is in the login-required list (14 kinds, DATA-A13/LAUNCH-A22) and not logged in → push `AuthRoutesLogin` instead; `back()`, `backWithRefresh()` (pops `RefreshResult{refresh:true}`), `replace(route,param)`, `toMain()` (clear the stack and replace with MainRoutesMain); internally only calls `AppRouter`.
- `ets/core/navigation/RouteParams.ets`: param classes for all routes with parameters (GoodsDetailParam{goodsId}, GoodsCommentParam, GoodsCategoryParam{typeId?,featured,recommend,keyword?,minPrice?}, OrderListParam{tab?}, OrderDetailParam{orderId}, OrderPayParam{orderId,price,from?}, OrderRefundParam, OrderCommentParam{orderId,goodsId}, OrderLogisticsParam, AddressListParam{isSelectMode}, AddressDetailParam{isEditMode,addressId}, CartParam{showBackIcon}, GuideParam{fromSettings}, WebParam{url,title?}) + `RefreshResult` + `SelectAddressResult`; field names per source `*Routes.kt`.
**Spec source**: cards/data_domain.md, cards/launch.md §INIT, `core/data/**`, `core/common/src/main/.../base/**`, `core/navigation/**`.
**Done when**: the symbols above are exported; HttpClient token injection registered (if fnd-network provides setTokenProvider).

## SECTION: fnd-designsystem
**Goal**: migrate `core/designsystem` + `core/common/config` + ThemePreferenceManager. Output `ets/core/designsystem/`:
- `ThemeManager.ets`: `@ObservedV2` singleton, `@Trace mode: 'follow_system'|'light'|'dark'`, `@Trace colorKey` (5 colors: default `#465CFF`, purple `#6831FF`, green `#09BE4F`, orange `#FFB703`, red `#FF2B2B`, names per ThemeColorOption.kt), `@Trace primary: string`; `init(appCtx)` reads KvStore (`settings_theme_mode`/`settings_theme_color`, unknown → default), `setMode()` applies `ApplicationContext.setColorMode` + persists, `setColor()` persists and switches primary immediately — LAUNCH-A24~A27, COM-A05/A07.
- `AppColors.ets`: neutral tokens via resources: append to `resources/base/element/color.json` and `resources/dark/element/color.json`: `bg_page`(light `#F1F4FA`/dark `#111111`), `bg_card`(`#FFFFFF`/`#1B1B1B`), `surface`(`#FFFFFF`/`#1B1B1B`), `text_primary`, `text_secondary`, `text_tertiary`, `divider`, `danger`(`#FF2B2B`) etc. (taken from Color.kt) — LAUNCH-A28; export resource constants (`AppColors.bgPage = $r('app.color.bg_page')`).
- `Dimens.ets` (spacing/radius/font sizes from Size.kt/Type.kt/Shape.kt).
**Spec source**: cards/launch.md A24~A28, cards/common.md A04~A08, `core/designsystem/**`, `core/common/.../config/**`, `ThemePreferenceManager.kt`.

## SECTION: fnd-ui-base
**Goal**: migrate the "page frame" layer of core/ui. UI unit: must read `spec/ui-layout-semantics.md` and pass the §5 self-check. Output `ets/core/ui/base/`:
- `AppScaffold.ets` (top bar slot + content + bottom bar, reads AvoidArea top/bottom padding), `TopAppBars.ets` (CenterTopAppBar / LargeTopAppBar (collapsible large title) / SearchTopAppBar, back button calls `AppNavigator.back()` by default, `@Event onBack` can override).
- `StateViews.ets`: `EmptyData`/`EmptyNetwork` (`网络连接失败`/`请检查网络连接后重试`/`重新加载`)/`EmptyError`/`EmptyCart` (`购物车是空的`/`快去添加商品吧`), `PageLoading`, `LoadMoreFooter` (`加载失败，点击重试`/`没有更多了` etc., copy per source LoadMore.kt), and `NetWorkStateView` (Loading/Success/Error three-state container, @BuilderParam content, error retry).
- `Skeleton.ets`: skeleton blocks + shimmer animation (shimmer library degraded to linearGradient animation), plus the generic skeleton parts the source uses.
- `RefreshList.ets`: pull-to-refresh (`Refresh`) + load-more trigger (last 3 items) list frame driven by a `BaseNetWorkListViewModel`.
**Spec source**: `core/ui/src/main/java/com/joker/coolmall/core/ui/component/{scaffold,appbar,empty,loading,network,refresh,skeleton}/**`.

## SECTION: fnd-ui-widgets
**Goal**: migrate the base widgets of core/ui. UI unit: must read `spec/ui-layout-semantics.md` and pass the §5 self-check. Output `ets/core/ui/widget/`:
- `Buttons.ets` (AppButton filled/outline/text/loading state, CheckButton), `AppCard.ets` (card + TitleWithLine + Divider), `ListItem.ets` (row: icon/title/description/right text/arrow/switch slot), `Tags.ets` (Tag with color variants), `Texts.ets` (PriceText: `¥` + integer + `.00` style per source PriceText.kt), `Dialog.ets` (confirm dialog content + `DialogHelper.showConfirm(uiCtx,title,content,confirm,cancel,onConfirm)`), `BottomSheet.ets` (bindSheet wrapper style), `QuantityStepper.ets` (min 1), `Rate.ets` (5 stars), `Swiper.ets` (Banner carousel), `Images.ets` (NetWorkImage: Image(url).alt(placeholder), **callbacks must not write state synchronously** A2-15; Avatar), `ImageGridPicker.ets` (3-column, at most 9 images, via `photoAccessHelper.PhotoViewPicker`), `Badge.ets`.
**Spec source**: `core/ui/src/main/java/com/joker/coolmall/core/ui/component/{button,card,list,tag,text,dialog,modal/BottomModal,modal/Modal,stepper,rate,swiper,image,imagepicker,badge,divider,title,bottombar}/**`.
**Notes**: wrapper components must not bind onClick unconditionally (A2-16).

## SECTION: fnd-ui-commerce
**Goal**: migrate core/ui's business components. UI unit: must read `spec/ui-layout-semantics.md` and pass the §5 self-check. Output `ets/core/ui/commerce/`:
- `GoodsItems.ets` (GoodsGridItem/GoodsListItem/OrderGoodsItem), `AddressCard.ets` (+AddressSkeleton), `CouponCard.ets` (`满%1$d元可用`, `有效期至`, expandable `使用说明`, used/expired states), `SpecSelectSheet.ets` (spec sheet content: header price/selected/stock, grid/list toggle, tap-again-to-deselect, quantity appears after selection, `加入购物车`/`立即购买` enabled only when stock>0 — GOODS-A06~A09), `CouponSheets.ets` (CouponModal select coupon/CouponReceiveModal claim coupon `领取优惠券`), `DictSelectSheet.ets` (dictionary single-select: loading/error/list, used by cancel/refund reasons), `OrderGoodsSheet.ets` (`选择要购买的商品`/`选择要评价的商品`).
**Spec source**: `core/ui/src/main/java/com/joker/coolmall/core/ui/component/{goods,address,coupon,modal}/**`, cards/goods.md, cards/order_a.md.

## SECTION: fnd-app-init
**Goal**: application-level initialization and window layer (owns EntryAbility/module.json5/AppScope). Output:
- `ets/entryability/EntryAbility.ets`: onCreate adds, in order: `KvStore.init` → `AppDatabase.init` (async is fine but must finish before first use) → `ThemeManager.init` → `AppState.initialize()` (LAUNCH-A18, INIT-A01; Toast init after loadContent; Log uses hilog; QQ SDK has no HarmonyOS equivalent → record a degradation in the summary and keep AppId 102756675 as a constant); onWindowStageCreate: `setWindowLayoutFullScreen(true)`, read `getWindowAvoidArea(TYPE_SYSTEM / TYPE_NAVIGATION_INDICATOR)` and write AppStorageV2 `AvoidArea{top,bottom}` (vp), subscribe to `avoidAreaChange` to refresh; status bar text color follows dark/light (`setWindowSystemBarProperties`, also re-applied on ThemeManager changes). **Do not touch the smokeRoute pass-through and `loadContent('pages/Index')`**.
- `ets/core/ui/base/AvoidArea.ets` (`@ObservedV2 class AvoidArea { @Trace top: number = 0; @Trace bottom: number = 0 }` + `AvoidArea.get()` = AppStorageV2.connect) — created by this unit (fnd-ui-base and pages import it).
- `module.json5`: requestPermissions INTERNET, GET_NETWORK_INFO (with reason resources); AppScope `app.json5`/string: app name `青商城` (LAUNCH-A33), versionName `1.1.2`, versionCode per source.
**Spec source**: cards/launch.md §INIT (A18~A34), `app/src/main/java/com/joker/coolmall/{Application.kt,MainActivity.kt}`.
**Done when**: INIT-A01 sub-items handled one by one (written into summary); the build passes.

---

## SECTION: page-launch
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: splash page + guide page. Files: `pages/LaunchRoutesSplashPage.ets`, `pages/LaunchRoutesGuidePage.ets`, `feature/launch/`.
- Splash: logo/blurred background/`青商城`/copyright; after 1.2s reads `guide_shown`: false → `AppNavigator.replace(Guide)`, otherwise `AppNavigator.toMain()` (removes itself from the stack). Shared-element logo `app_logo` uses `geometryTransition('app_logo')` (if it can't line up, record as approx).
- Guide: 4-page Swiper (copy from strings), custom 4-dot indicator, `跳过`/`继续`/`开始体验`; when fromSettings=false, write `guide_shown=true` then `toMain()`; when true, just `back()`.
**Spec**: cards/launch.md A01~A17; source `feature/launch/**`.

## SECTION: page-main-shell-home
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: main shell (4-tab bottom navigation + swipeable pages) + home tab. Files: `pages/MainRoutesMainPage.ets`, `feature/main/MainShell.ets`, `feature/main/home/` (HomeView/HomeViewModel/HomeSkeleton/FlashSaleItem/BottomNavigationBar).
- Shell: `Tabs` (swipeable, `barPosition End`) or Swiper + custom bottom bar; tab order `主页`/`分类`/`购物车`/`我的`; selected label in the primary color; icons: Lottie has no equivalent → static icons + selected-state transition, recorded as approx (HOME-A04). Tabs 1~3 embed `CategoryTab` (feature/main/category/CategoryTab.ets, page-tab-category), `CartView` (feature/main/cart/CartView.ets, page-cart, param `showBackIcon=false`), `MeTab` (feature/main/me/MeTab.ets, page-tab-me).
- Home: GET page/home (HomeViewModel extends BaseNetWorkListViewModel<Goods>), skeleton ≥320ms, error state retry, collapsible top bar (logo→About, search box `搜索商品`→GoodsSearch, GitHub→Web), Banner 2:1 autoplay every 3s, coupon bar + `领取` → CouponReceiveSheet, 5-column categories, `限时精选`+`查看全部`, `推荐商品`, `全部商品` two-column staggered grid (WaterFlow) + load more + pull-to-refresh, conditional sections.
**Spec**: cards/main_home.md HOME-A01~A21; source `feature/main/**/{MainScreen,HomeScreen,HomeViewModel,MainViewModel}.kt`, `component/**`.

## SECTION: page-tab-category
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: Category tab component `feature/main/category/` (CategoryTab.ets + CategoryViewModel.ets + CategorySkeleton.ets). Centered title `分类`; goods/type/list builds the tree; skeleton/error state; left first-level list ↔ right linked scrolling list (title + 3-column subcategories), tapping a subcategory → `GoodsRoutesCategory(typeId)`. Status-bar avoidance for the three tabs (MAIN-A01: Category/Cart/Me).
**Spec**: cards/main_tabs.md MAIN-A01~A10; source `feature/main/**/{CategoryScreen,CategoryViewModel,CategorySkeleton}.kt`.

## SECTION: page-cart
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: cart. Files: `pages/MainRoutesCartPage.ets` (standalone route, CartParam.showBackIcon=true), `feature/main/cart/` (CartView.ets: the component reused by both the tab and the standalone page, `@Param showBackIcon`; CartViewModel.ets subscribes to CartDao change notifications so both instances refresh).
- Empty state `购物车是空的`, grouped by goods, spec rows select/price/stepper (min 1, written to DB immediately), `全选`, `合计:`, `结算`/`结算(%d)`, `编辑`/`完成` edit mode + `删除(%d)` (slide-out animation then delete), checkout writes KV `carts` + `selectedGoodsList` → `AppNavigator.navigate(OrderRoutesConfirm)` (when not logged in, the login wall goes to the login page).
**Spec**: cards/main_tabs.md MAIN-A11~A22; source `feature/main/**/{CartScreen,CartViewModel}.kt`.

## SECTION: page-tab-me
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: Me tab `feature/main/me/` (MeTab.ets + MeViewModel.ets). User area (logged in: avatar/nickname/`手机号`; not logged in: `未登录`/`点击登录账号`), member card display, `我的订单` + 5 entries (tab=1/2/3/5/4, badge counts from order/info/userCount, refreshed on page show), `我的足迹` (latest 8, horizontal list), function menu (`优惠券`/`收货地址`/`在线客服`/`意见反馈`/`关于我们`) + settings card.
**Spec**: cards/main_tabs.md MAIN-A23~A28; source `feature/main/**/{MeScreen,MeViewModel}.kt`.

## SECTION: page-goods-detail
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: goods detail + comment list. Files: `pages/GoodsRoutesDetailPage.ets`, `pages/GoodsRoutesCommentPage.ets`, `feature/goods/detail/`.
- Detail: page/goodsDetail, skeleton/error; carousel, price/`已售`, coupon tags `满%d减%d元` → claim sheet (login wall), spec row `选择规格`/`已选：%s` → SpecSelectSheet (spec list requested only after the sheet fully opens, only once), add to cart (local merge, no login check, toast), buy now (KV `selectedGoodsList` → Confirm), `发货与服务` card, `商品评价` card, `商品详情` image list, floating top bar opacity changes with scroll, bottom bar `客服`/`购物车`(CartParam showBackIcon=true), write footprint on success.
- Comment page: `商品评论`, paging/refresh/load-more/skeleton/empty/error, comment card (nickname `匿名用户`/time/stars/content/9-image grid).
**Spec**: cards/goods.md GOODS-A01~A22; source `feature/goods/**/{GoodsDetail*,GoodsComment*,CommentCard,CommentItem}.kt`.

## SECTION: page-goods-search-list
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: search page + category goods list. Files: `pages/GoodsRoutesSearchPage.ets`, `pages/GoodsRoutesCategoryPage.ets`, `feature/goods/list/`.
- Search: recommended keywords + 10 history entries (live subscription), input `输入内容进行搜索` + `搜索`, history/recommended tags; submit writes history → GoodsRoutesCategory(keyword).
- List: route params pre-fill; paged query (empty conditions not sent); sort bar `综合`/`销量`/`价格` three-state; `筛选` overlay (category tree loaded once + `价格区间` `最低价`/`最高价` + multi-select chips); grid/list toggle; skeleton/empty/error/refresh/load-more; the page's own search box does not write history.
**Spec**: cards/goods.md GOODS-A23~A35; source `feature/goods/**/{GoodsSearch*,GoodsCategory*,FilterDialog,SortType,SortState}.kt`.

## SECTION: page-order-list
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: order list. Files: `pages/OrderRoutesListPage.ets`, `feature/order/list/` (+ `feature/order/common/OrderButtons.ets`, `OrderStatus.ets`, shared with the detail page; created by this slice).
- `订单列表`; 7 tabs (`全部` `待付款` `待发货` `待收货` `售后/退款` `待评价` `已完成`, per card ORDA-A04) linked with swipeable pages; tab param fallback; each tab lazy-loaded with its own paging state; order card/status text/action buttons by status; cancel (dictionary sheet → cancel), confirm receipt dialog, buy again / review (multi-item sheet), go to pay (amount=price-discountPrice), refund, logistics; reset all tabs when a child page returns a RefreshResult.
**Spec**: cards/order_a.md ORDA-A01~A22; source `feature/order/**/{OrderList*,OrderButtons,OrderStatus,OrderTabState}.kt`.

## SECTION: page-order-detail-logistics
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: order detail + logistics. Files: `pages/OrderRoutesDetailPage.ets`, `pages/OrderRoutesLogisticsPage.ets`, `feature/order/detail/`. Reuse `feature/order/common/` (from page-order-list).
**Spec**: cards/order_a.md ORDA-A23~A35; source `feature/order/**/{OrderDetail*,OrderLogistics*,LogisticsSteps}.kt`.

## SECTION: page-order-confirm-pay
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: confirm order + checkout. Files: `pages/OrderRoutesConfirmPage.ets`, `pages/OrderRoutesPayPage.ets`, `feature/order/confirm/`.
- Confirm: page/confirmOrder; items from KV `carts` first, else `selectedGoodsList` (behavior per ORDB-A05 source); address card (select mode → AddressList, receives SelectAddressResult); `价格明细`/coupon threshold; `订单备注`; submit (`请选择收货地址`) → order/info/create → remove ordered items from the cart → `replace` to Pay.
- Pay: `收银台`, `¥<price>.00`, `支付宝支付`, `去支付 ¥<price>`; calls order/pay/alipayAppPay to get the orderString; **Alipay SDK has no installed equivalent**: try `@kit.PaymentKit`/opening the Alipay H5 is not used; record as a no_equiv degradation (toast `支付失败` or per source mapping), and keep the result-code mapping function (9000/6001/other); back behavior per ORDB-A20 (from=confirm → replace to OrderDetail).
**Spec**: cards/order_b.md ORDB-A01~A20; source `feature/order/**/{OrderConfirm*,OrderPay*,Alipay}.kt`.

## SECTION: page-order-refund-comment
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: refund request + goods review. Files: `pages/OrderRoutesRefundPage.ets`, `pages/OrderRoutesCommentPage.ets`, `feature/order/aftersale/`.
- Refund `退款申请`: order info, reason sheet (dictionary orderRefundReason), `提交` disabled until a reason is chosen, submit → backWithRefresh.
- Review `商品评价`: 5 stars (default 5, `很差`…`非常满意`), content, ImageGridPicker; submit uploads first (FileUploadService) then goods/comment/submit; `评价提交成功` → backWithRefresh.
**Spec**: cards/order_b.md ORDB-A21~A30; source `feature/order/**/{OrderRefund*,OrderComment*}.kt`.

## SECTION: page-auth-login
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: login selection + account login + SMS login. Files: `pages/AuthRoutesLoginPage.ets`, `pages/AuthRoutesAccountLoginPage.ets`, `pages/AuthRoutesSmsLoginPage.ets`, `feature/auth/` (shared components: PhoneInputField/PasswordInputField/VerificationCodeField/UserAgreement/ImageCaptchaSheet/AuthHeader; reused by page-auth-register-reset).
- Selection: logo, `验证码登录`/`账号密码登录`, `其他登录方式` `微信`/`QQ`/`支付宝` (WeChat/Alipay toast `三方登录暂时仅支持QQ登录`; QQ SDK has no equivalent → no_equiv degradation, tapping shows a toast explaining it is unavailable).
- Account login: prefill saved_phone/saved_password, validation, POST user/login/password, on success save credentials + AppState.updateUserState + refresh + `登录成功` + pop back.
- SMS login: notification permission → image captcha sheet `安全验证` → user/login/smsCode → notification shows the code → user/login/phone.
**Spec**: cards/auth.md AUTH-A01~A25, A31~A34; source `feature/auth/**`.

## SECTION: page-auth-register-reset
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: register + reset password. Files: `pages/AuthRoutesRegisterPage.ets`, `pages/AuthRoutesResetPasswordPage.ets`, `feature/auth/register/`. Reuse page-auth-login's feature/auth components. Reset password keeps the source's empty implementation (button always disabled, getting a code makes no request).
**Spec**: cards/auth.md AUTH-A26~A30; source `feature/auth/**/{Register*,ResetPassword*}.kt`.

## SECTION: page-user-profile-footprint
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: profile + footprints. Files: `pages/UserRoutesProfilePage.ets`, `pages/UserRoutesFootprintPage.ets`, `feature/user/profile/`.
**Spec**: cards/user_market_feedback.md USER-A01(Profile part)~A07, A25~A29; source `feature/user/**/{Profile*,Footprint*}.kt`.

## SECTION: page-address
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: address list + edit. Files: `pages/UserRoutesAddressListPage.ets`, `pages/UserRoutesAddressDetailPage.ets`, `feature/user/address/` (including RegionPickerSheet + RegionData static data for 13 provinces).
**Spec**: cards/user_market_feedback.md USER-A08~A24; source `feature/user/**/{Address*,RegionPickerModal,Region,RegionData}.kt`.

## SECTION: page-market-feedback
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: my coupons + feedback list + submit feedback. Files: `pages/MarketRoutesCouponPage.ets`, `pages/FeedbackRoutesListPage.ets`, `pages/FeedbackRoutesSubmitPage.ets`, `feature/market/`, `feature/feedback/`.
**Spec**: cards/user_market_feedback.md USER-A30~A44; source `feature/market/**`, `feature/feedback/**`.

## SECTION: page-cs-chat
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: customer service chat. Files: `pages/CsRoutesChatPage.ets`, `feature/cs/` (ChatViewModel, WebSocketManager (`@kit.NetworkKit` webSocket, Socket.IO v4 frames handled by hand: `40/cs,{token}` auth, `42/cs,["send",...]`, respond to ping `2`→`3`), ChatSoundManager (SoundPool/AVPlayer playing the send/receive sounds from rawfile; if the source audio files were not converted, copy them from `res/raw` into `resources/rawfile`), input bar/emoji panel/function panel).
**Spec**: cards/cs_chat.md CS-A01~A21; source `feature/cs/**`.

## SECTION: page-settings
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: settings + user agreement + privacy policy. Files: `pages/CommonRoutesSettingsPage.ets`, `pages/CommonRoutesUserAgreementPage.ets`, `pages/CommonRoutesPrivacyPolicyPage.ets`, `feature/common/settings/` (ThemeModeSheet/ThemeColorSheet).
- Settings groups and rows per COM-A02~A12 (`夜间模式` three options → ThemeManager.setMode; `主题颜色` 5 colors → setColor; `语言切换` fixed `中文`; `不展示启动页` page-local toggle; `清除缓存` fixed `13.24MB`; `应用引导` → Guide(fromSettings=true)).
- Agreement/privacy: base/comm/param?key=userAgreement|privacyPolicy → render the HTML in a Web component (`loadData`, JS disabled), document skeleton, error retry.
**Spec**: cards/common.md COM-A01~A12, A23~A25; source `feature/common/**/{Settings*,ThemeModeModal,ThemeColorModal,UserAgreement*,PrivacyPolicy*,DocumentSkeleton}.kt`.

## SECTION: page-about-web-contributors
Required reading: `spec/ui-layout-semantics.md`, pass the §5 self-check. **Goal**: About + Web page + contributors. Files: `pages/CommonRoutesAboutPage.ets`, `pages/CommonRoutesWebPage.ets`, `pages/CommonRoutesContributorsPage.ets`, `feature/common/about/`.
- About: logo/name/`Version x`, info card (PackageUtils), aurora background (approximated with a gradient + animation, approx), header fades on scroll, developer/link rows (fixed URL → Web), `引用` → `引用致谢` sheet listing 21 dependencies (DependencyDataSource), copyright.
- Web: `@kit.ArkWeb` Web component, title replaced by the page title, progress bar, `更多选项` menu `刷新`/`用浏览器打开` (opens the system browser via `startAbility` + uri), non-http schemes handed to the system.
- Contributors: user/contributor/page paging, cards, tapping with a websiteUrl → Web.
**Spec**: cards/common.md COM-A13~A22, A26~A27; source `feature/common/**/{About*,Web*,Contributors*,DependencyModal,UserContributorCard,Dependency,AboutLink,WebViewData,DependencyDataSource}.kt`.
