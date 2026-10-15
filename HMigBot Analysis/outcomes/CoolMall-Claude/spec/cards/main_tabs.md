# Main tabs: Category / Cart / Me (MainRoutesMain tabs 1-3 + standalone MainRoutesCart)

Route: MainRoutes.Main (pager page 1 = CategoryRoute, page 2 = CartRoute(MainRoutes.Cart()), page 3 = MeRoute); MainRoutes.Cart(showBackIcon) is also registered standalone (feature/main/.../navigation/MainGraph.kt:28)
Sources: feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt, view/CartScreen.kt, view/MeScreen.kt, viewmodel/CategoryViewModel.kt, viewmodel/CartViewModel.kt, viewmodel/MeViewModel.kt, state/CategoryUiState.kt, skeleton/CategorySkeleton.kt, component/CommonScaffold.kt, navigation/MainGraph.kt; core/database/.../datasource/cart/CartDataSource.kt; core/navigation/.../RouteInterceptor.kt

## Assertions
- MAIN-A01 [ui] Top content of the Category, Cart and Me tabs avoids the status bar (Scaffold content insets, navigation bar excluded only)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/component/CommonScaffold.kt:36
- MAIN-A02 [ui] The Category tab shows a centered title bar `分类` with no back button。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:111
- MAIN-A03 [backend] Opening the Category tab requests the category list once (POST goods/type/list) and builds a tree sorted by sortNum: items with null parentId are first-level categories, the rest attach under their parent by parentId。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CategoryViewModel.kt:81
- MAIN-A04 [ui] While category data loads, the page shows the category skeleton (left/right two-column placeholders); loading lasts at least 320ms。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:118
- MAIN-A05 [ui] When category loading fails, the page shows the network error state `网络连接失败`/`请检查网络连接后重试` with a `重新加载` button; tapping it requests again。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:117
- MAIN-A06 [ui] After loading, the left column lists all first-level category names, with the first selected by default; the selected item is highlighted with a left indicator bar and cannot be tapped again。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:251
- MAIN-A07 [ui] The right column is one continuously scrolling list: each first-level category shows a lined title (category name) followed by a 3-column grid of its second-level categories (image + name); a category with no children shows only the title。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:486
- MAIN-A08 [ui] Tapping a first-level category on the left scrolls the right list to that category's section。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:190
- MAIN-A09 [ui] When the user scrolls the right list by hand, the left selection follows the category section currently in view (the two are linked, with no feedback loop)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:181
- MAIN-A10 [ui] Tapping a second-level category goes to the goods category/list page (GoodsRoutes.Category) with that subcategory id as typeId。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CategoryScreen.kt:526
- MAIN-A11 [ui] The Cart page title is `购物车`; the back arrow shows only when opened standalone with showBackIcon=true (e.g. from the goods detail page's cart entry), and tapping it goes back; on the tab page there is no back arrow。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CartScreen.kt:167
- MAIN-A12 [backend] Cart data comes from the local database (Room table carts, not tied to the account, no network) and is observed live; any add/remove/count change refreshes the list automatically。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:65
- MAIN-A13 [ui] When the cart is empty, it shows the empty state `购物车是空的`/`快去添加商品吧` (no button) and hides both the top-right edit button and the bottom checkout bar。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CartScreen.kt:197
- MAIN-A14 [ui] When the cart has items, each goods entry is a card grouped by goods (name/image) listing each spec row: select box, spec name, price (¥ + integer + .00), quantity stepper; tapping the goods card goes to that goods' detail page。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CartScreen.kt:257
- MAIN-A15 [ui] The select box on each spec row toggles that spec's selected state independently (selection is by goodsId+specId)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:191
- MAIN-A16 [backend] The quantity stepper changes count by ±1 with a minimum of 1 (minus disabled at 1, no stock cap); the change is written to the local database right away。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:226
- MAIN-A17 [ui] The bottom bar has a `全选` select box: it shows checked when every spec is selected; tapping it when all are selected clears the selection, otherwise it selects every spec。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:163
- MAIN-A18 [ui] In normal mode the bottom bar shows `合计:` + the selected total (Σ price×count of selected specs) and a checkout button: `结算` when nothing is selected (disabled), `结算(%d)` (with the selected spec count) when specs are selected。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CartScreen.kt:328
- MAIN-A19 [ui] The top-right `编辑` button enters edit mode and changes to `完成`; entering or leaving edit mode clears the current selection; in edit mode the bottom bar replaces total/checkout with a red `删除`/`删除(%d)` button (disabled when nothing is selected)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/CartScreen.kt:171
- MAIN-A20 [backend] Tapping delete plays a slide-out animation and then deletes the selected specs: when all specs of a goods are selected the whole goods is deleted, otherwise only the selected specs; a goods whose last spec is removed is deleted too; after deletion the selection is cleared and edit mode ends。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:237
- MAIN-A21 [backend] On checkout, it toasts `请选择要结算的商品` when nothing is selected; otherwise it writes the selected cart items (selected specs only) to MMKV key `carts`, writes them converted into a SelectedGoods list to MMKV key `selectedGoodsList`, then goes to the confirm-order page (OrderRoutes.Confirm)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/CartViewModel.kt:270
- MAIN-A22 [ui] When not logged in, tapping checkout goes to the login page instead of the confirm-order page (Confirm is a login-required route)。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/RouteInterceptor.kt:34
- MAIN-A23 [ui] The Me page user area: when logged in it shows avatar, nickname and `手机号` + phone number; when not logged in it shows the default avatar, `未登录` and `点击登录账号`; tapping the area goes to the profile page (when not logged in, to the login page)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MeScreen.kt:264
- MAIN-A24 [backend] On entering the Me page, if logged in but with no cached user info, it fetches user info; on every page resume (onResume) it requests order counts when logged in (GET order/info/userCount) and resets all counts to 0 when not logged in。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/viewmodel/MeViewModel.kt:85
- MAIN-A25 [ui] The Me page shows a member card `会员立享5大权益!` + `立即开通` (display only, no tap behavior)。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MeScreen.kt:315
- MAIN-A26 [ui] The order area title `我的订单` + `查看全部` goes to the all-orders list; the five entries `待付款`/`待发货`/`待收货`/`待评价`/`退款/售后` go to the order list with tab=1/2/3/5/4; each entry with count>0 shows a red badge (退款/售后 = 退款中 + 已退款); when not logged in, every order entry goes to the login page。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MeScreen.kt:345
- MAIN-A27 [ui] When local footprints exist, it shows the `我的足迹` area: `查看全部` goes to the footprint page, below it a horizontal list of up to 8 most recent footprint images (by browse time, newest first), tapping one goes to goods detail; when there are no footprints the area is hidden。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MeScreen.kt:205
- MAIN-A28 [ui] The function menu has, in order, `优惠券`→coupon page, `收货地址`→address list, `在线客服`→customer-service chat, `意见反馈`→feedback list, `关于我们`→about page; a separate card holds `设置`→settings page; coupon/address/chat/feedback go to the login page when not logged in。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/MeScreen.kt:525

## Components and interactions
| Page | Element | Behavior | Anchor |
|---|---|---|---|
| Category | Title bar `分类` | No back button | CategoryScreen.kt:111 |
| Category | Left first-level item | Not selected: tap → selectCategory(index) → right list animateScrollToItem; selected: not tappable | CategoryScreen.kt:258, :365 |
| Category | Right second-level grid item (image + name) | GoodsNavigator.toCategory(typeId = id.toString()) | CategoryScreen.kt:526 |
| Category | Error state `重新加载` | viewModel.retryRequest | CategoryScreen.kt:88 |
| Cart | Top-right TextButton `编辑`/`完成` | toggleEditMode (clears selection); hidden when empty | CartScreen.kt:170-176 |
| Cart | Back arrow | Only when showBackIcon=true; navigateBack() | CartScreen.kt:167-168 |
| Cart | Goods card | GoodsNavigator.toDetail(goodsId) | CartScreen.kt:260 |
| Cart | Spec row CheckButton | toggleItemSelection(goodsId, specId) | CartScreen.kt:270 |
| Cart | QuantityStepper -/+ | updateCartItemCount; min 1, max Int.MAX | core/ui/.../stepper/QuantityStepper.kt:44 |
| Cart | Bottom bar `全选` CheckButton | toggleSelectAll | CartScreen.kt:317-324 |
| Cart | `结算`/`结算(%d)` button | enabled = selectedCount>0; onCheckoutClick | CartScreen.kt:333-345 |
| Cart | `删除`/`删除(%d)` button (DANGER) | Edit mode only; 300ms animation then deleteSelectedItems | CartScreen.kt:347-359, :156-161 |
| Me | User info row (avatar/nickname/phone/arrow) | UserNavigator.toProfile() (login required) | MeScreen.kt:237 |
| Me | Member card `会员立享5大权益!`/`立即开通` | No tap behavior | MeScreen.kt:293-330 |
| Me | `我的订单` `查看全部` | OrderNavigator.toList() | MeScreen.kt:349 |
| Me | `待付款` | OrderNavigator.toList(tab="1"), badge pendingPayment | MeScreen.kt:358 |
| Me | `待发货` | toList(tab="2"), badge pendingShipment | MeScreen.kt:366 |
| Me | `待收货` | toList(tab="3"), badge pendingReceive | MeScreen.kt:374 |
| Me | `待评价` | toList(tab="5"), badge pendingReview | MeScreen.kt:382 |
| Me | `退款/售后` | toList(tab="4"), badge refunding+refunded | MeScreen.kt:390 |
| Me | `我的足迹` `查看全部` | UserNavigator.toFootprint() (no login required) | MeScreen.kt:412 |
| Me | Footprint thumbnail | GoodsNavigator.toDetail(goodsId) | MeScreen.kt:422 |
| Me | `优惠券` | MarketNavigator.toCoupon() (login required) | MeScreen.kt:532 |
| Me | `收货地址` | UserNavigator.toAddressList() (login required) | MeScreen.kt:540 |
| Me | `在线客服` | CsNavigator.toChat() (login required) | MeScreen.kt:548 |
| Me | `意见反馈` | FeedbackNavigator.toList() (login required) | MeScreen.kt:556 |
| Me | `关于我们` | CommonNavigator.toAbout() | MeScreen.kt:565 |
| Me | `设置` (separate card) | CommonNavigator.toSettings() | MeScreen.kt:577 |

Strings (feature/main/src/main/res/values/strings.xml): 分类/购物车/我的, 编辑/完成/删除/删除(%d)/全选/合计:/结算/结算(%d), 未登录/点击登录账号/手机号, 会员/会员立享5大权益!/立即开通, 我的订单/查看全部/待付款/待发货/待收货/待评价/退款/售后, 我的足迹/优惠券/收货地址/在线客服/意见反馈/关于我们/设置, toasts 请选择要结算的商品/获取选中商品失败. Defined but unused in these screens: cart_empty `购物车空空如也~`, go_shopping, category_all, category_empty, price_format. Empty cart text comes from core/ui strings: `购物车是空的`/`快去添加商品吧` (empty_cart_btn `去逛逛` is not shown because onRetryClick=null, core/ui/.../empty/Empty.kt:77).

## Data and APIs
- Category: `POST goods/type/list` → NetworkResponse<List<Category>> (core/network/.../service/GoodsService.kt:31). Category{id:Long,name,parentId:Int?,sortNum,pic?,status,createTime?,updateTime?}; client builds CategoryTree (children) — sort by sortNum, roots = parentId==null, recursive. Base class BaseNetWorkViewModel (enableMinLoadingTime=true → 320ms min, BaseNetWorkViewModel.kt:100); state Loading/Success/Error (BaseNetWorkUiState; CategoryUiState.kt exists but is unused by the screen). Selected index lives in ViewModel (`selectedCategoryIndex`, default 0).
- Cart: local Room table `carts` (CartDao.kt:81 `SELECT * FROM carts`, no ORDER BY → insertion/rowid order). Cart{goodsId,goodsName,goodsMainPic,spec:List<CartGoodsSpec>}, CartGoodsSpec{id,goodsId,name,price:Int,stock,count,images?}. Price is integer yuan; PriceText renders `¥` + int + literal `.00`. DataSource semantics: updateCartSpecCount deletes the cart row if all specs count<=0 (CartDataSource.kt:64); removeSpecFromCart deletes the row when no spec remains (CartDataSource.kt:96). Selection state = Map<goodsId, Set<specId>>, in memory only (not persisted).
- Checkout handoff: MMKV `carts` = List<Cart> (selected specs only), MMKV `selectedGoodsList` = List<SelectedGoods{goodsId,count,spec:GoodsSpec{id,goodsId,name,price,stock,images},goodsInfo:Goods{id,title,mainPic}}> (CartViewModel.kt:286, :292). Then navigate(OrderRoutes.Confirm). Selection is NOT cleared after checkout.
- Me: AppState.isLoggedIn/userInfo (StateFlow, global); AppState.refreshUserInfo → userInfoRepository.getPersonInfo (AppState.kt:173). Order count `GET order/info/userCount` (OrderService.kt:90) → OrderCount with Chinese JSON keys `待付款`,`待发货`,`待收货`,`待评价`,`退款中`,`已退款` (core/model/.../entity/OrderCount.kt). Footprints: Room `SELECT * FROM footprints ORDER BY viewTime DESC LIMIT 8` (FootprintDao.kt:71).
- Login wall list (RouteInterceptor.kt:29-44): UserRoutes.Profile/AddressList/AddressDetail, OrderRoutes.List/Confirm/Detail/Pay/Refund/Comment/Logistics, CsRoutes.Chat, MarketRoutes.Coupon, FeedbackRoutes.List/Submit → redirected to AuthRoutes.Login when not logged in (AppNavigator.kt:172). Footprint, About, Settings, Goods routes are open.

## Cross-cutting notes
The three tabs are pages of a HorizontalPager in MainScreen (MainScreen.kt:139-152); the tab Cart instance is constructed as MainRoutes.Cart() (showBackIcon=false), while GoodsDetailScreen.kt:350 opens a separate MainRoutes.Cart(showBackIcon=true) route with its own ViewModel instance (selection/edit state not shared, data shared through Room). MeViewModel is registered as a LifecycleObserver of the hosting entry (MeScreen.kt:97-101): order counts refresh on each ON_RESUME (e.g. returning from the order pages), not on tab switching within the pager. All flows use stateIn(WhileSubscribed(5000)); isAllSelected compares the total spec count with the selected spec count (a stale selection after external deletion could miscount). Category left/right linkage uses an isScrollingFromLeftClick flag plus lastSelectedIndex to avoid loops. Dark mode: Cart/Me/Category all have dark previews and use theme colors; member card is fixed dark (#242424) in both modes.

## Platform risks
- Category bidirectional scroll linkage (center-item detection from LazyList layoutInfo) must be re-implemented with ArkUI List onScrollIndex/Scroller.scrollToIndex while avoiding feedback loops.
- Cart local persistence: Room table with spec list stored as a converted column → needs a HarmonyOS RDB/preferences equivalent with live observation (Flow → emitter/@StorageLink or a manual refresh after writes).
- The MMKV handoff keys `carts`/`selectedGoodsList` are a contract with the order Confirm page; the HM implementation must use the same key names/shapes in the shared KV store.
- OrderCount JSON uses Chinese field names; ArkTS parsing must access them via bracket keys.
- Me order count refresh is tied to lifecycle onResume; in ArkUI tabs use onPageShow of the host page plus a tab-change trigger to stay equivalent at minimum on return from subpages.
- Login interception is centralized in navigation (RouteInterceptor); HM router must apply the same route list or Me/Cart entries will bypass login.
- Delete animation (300ms slide-out before the actual delete) and shared-element avatar transition (`user_avatar` key) are visual only; do not block on them.
