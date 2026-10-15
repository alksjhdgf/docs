# Goods domain (product detail / comment list / search / category product list)

Route: GoodsRoutes.Detail(goodsId), GoodsRoutes.Comment(goodsId), GoodsRoutes.Search, GoodsRoutes.Category(typeId?, featured, recommend, keyword?, minPrice?)
Sources: feature/goods/src/main/java/com/joker/coolmall/feature/goods/{view/GoodsDetailScreen.kt, view/GoodsCommentScreen.kt, view/GoodsSearchScreen.kt, view/GoodsCategoryScreen.kt, viewmodel/GoodsDetailViewModel.kt, viewmodel/GoodsCommentViewModel.kt, viewmodel/GoodsSearchViewModel.kt, viewmodel/GoodsCategoryViewModel.kt, component/FilterDialog.kt, component/CommentCard.kt, component/CommentItem.kt, model/SortType.kt, model/SortState.kt, state/CategoryUiState.kt, skeleton/*.kt, navigation/GoodsGraph.kt}; core/ui/src/main/java/com/joker/coolmall/core/ui/component/modal/SpecSelectModal.kt; core/ui/.../modal/CouponModal.kt; core/ui/.../appbar/SearchTopAppBar.kt; navigation/goods/GoodsRoutes.kt + GoodsNavigator.kt (core/navigation); core/network/.../service/GoodsService.kt, PageService.kt, CouponService.kt; feature/goods/src/main/res/values/strings.xml

## Assertions
- GOODS-A01 [backend] When the detail page opens, it requests the product detail by goodsId (goodsInfo + coupon list + comment list); while loading it shows the detail skeleton screen, and on failure it shows the network error state with a retry button that requests again。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:116
- GOODS-A02 [ui] When the detail loads successfully, it shows from top to bottom: the image carousel (no autoplay), the price (the selected spec's price if a spec is selected, otherwise the product price) with the sold tag `已售 %d`, the title, the subtitle, and the spec selection row。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:637
- GOODS-A03 [ui] When the detail returns a non-empty coupon list, coupon tags `满%d减%d元` are shown below the price; tapping any tag opens the coupon bottom sheet `领取优惠券`。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:765
- GOODS-A04 [backend] Tapping claim in the coupon sheet: when not logged in, it closes the sheet and goes to the login page; when logged in, it calls the claim-coupon API with couponId and shows a success toast with the returned text。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:263
- GOODS-A05 [ui] The spec row shows `选择规格` when no spec is selected and `已选：%s` (the spec name) when one is; tapping it opens the spec selection bottom sheet titled `选择规格`。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:815
- GOODS-A06 [backend] The spec list is requested by goodsId only after the spec sheet has fully expanded; once loaded successfully it is not requested again, and inside the sheet loading shows a loading indicator while failure shows the network error state with retry。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:163
- GOODS-A07 [ui] In the spec sheet, tapping a spec selects it and tapping the selected spec again deselects it; the header shows `¥` price, `已选`/`未选择`, and `库存`; the spec area can switch between grid and list views。锚点：core/ui/src/main/java/com/joker/coolmall/core/ui/component/modal/SpecSelectModal.kt:184
- GOODS-A08 [ui] The `数量` stepper in the spec sheet appears only after a spec is selected; quantity defaults to 1 and cannot go below 1。锚点：core/ui/src/main/java/com/joker/coolmall/core/ui/component/modal/SpecSelectModal.kt:346
- GOODS-A09 [ui] The sheet's `加入购物车` and `立即购买` buttons are enabled only when a spec is selected and its stock is > 0; otherwise they are disabled。锚点：core/ui/src/main/java/com/joker/coolmall/core/ui/component/modal/SpecSelectModal.kt:651
- GOODS-A10 [backend] Add to cart writes to the local cart (no login check): if the same product and spec already exist, the quantity adds up; same product with a new spec appends that spec; otherwise a new cart entry is created; on success the sheet closes and `添加购物车成功` is shown, and invalid parameters show `添加购物车失败`。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:287
- GOODS-A11 [backend] Buy now writes [SelectedGoods(goodsId, goodsInfo, spec, count)] into local storage key `selectedGoodsList`, closes the spec sheet, and goes to the order confirm page。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:344
- GOODS-A12 [ui] Bottom action bar of the detail page: `客服` goes to the support chat page, `购物车` goes to the cart page (with a back button), and both `加入购物车` and `立即购买` open the spec selection sheet。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:344
- GOODS-A13 [ui] The detail page shows the `发货与服务` card: `发货` `云南省 昆明市`, `服务` `7天无理由退货 · 运费险 · 48小时发货`。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:885
- GOODS-A14 [ui] Only when the detail has comments does it show the `商品评价` card (right side `查看全部`); each comment shows the nickname (`匿名用户` when empty), star rating, content, and first image with a `+N` count badge; tapping the title or any comment goes to that product's comment page。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:511
- GOODS-A15 [ui] At the bottom of the detail page, the `商品详情` section shows all rich-text detail images in order。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:534
- GOODS-A16 [ui] The detail page has a floating top bar (back button returns to the previous page; the share button does nothing); the top bar background goes from transparent to opaque as the page scrolls (white in light mode, black in dark mode)。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:365
- GOODS-A17 [ui] Detail page: top content avoids the status bar (the carousel extends under the status bar, and the floating top bar buttons avoid it)。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsDetailScreen.kt:386
- GOODS-A18 [backend] After the detail loads successfully, a browsing footprint is written locally (goodsId as unique key, with name/subtitle/main image/price/sold count/browse time); a failed write does not affect the page。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsDetailViewModel.kt:138
- GOODS-A19 [ui] The comment page title is `商品评论` with a back button; while loading it shows the comment skeleton screen, with no data it shows the empty state, and on failure it shows the network error state with retry。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsCommentScreen.kt:86
- GOODS-A20 [backend] The comment page requests comment pages by goodsId (10 per page) and supports pull-to-refresh and load-more near the bottom; when every page has loaded it shows no more data。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCommentViewModel.kt:48
- GOODS-A21 [ui] Each comment card shows the nickname (`匿名用户` when empty), comment time, 5-star rating, content (when non-empty), and an image grid (at most 9 images, 3 per row)。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/component/CommentCard.kt:70
- GOODS-A22 [ui] Comment page: top content avoids the status bar。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsCommentScreen.kt:85
- GOODS-A23 [backend] When the search page opens, it requests the recommended search keyword list and also subscribes to the 10 most recent local search history entries (newest first; the list refreshes as soon as it changes)。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsSearchViewModel.kt:37
- GOODS-A24 [ui] The search page top bar has a back button, an input box (placeholder `输入内容进行搜索`), and a `搜索` button (keyboard search also submits); below it, `搜索历史` is shown only when history exists (a delete icon on the right clears all history), followed by the `推荐搜索` tags。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsSearchScreen.kt:179
- GOODS-A25 [backend] Submitting a non-blank keyword (input box / history tag / recommended tag) first writes search history (trimmed, deduplicated by keyword with the time refreshed), then goes to the category product list carrying that keyword; a blank keyword does nothing。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsSearchViewModel.kt:71
- GOODS-A26 [ui] Search page: top content avoids the status bar。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsSearchScreen.kt:94
- GOODS-A27 [backend] The category product list reads route parameters: typeId (comma-separated category ids, preselected as filters), featured, recommend, keyword (also pre-filled in the search box), and minPrice (pre-filled as the minimum price when arriving from a coupon)。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCategoryViewModel.kt:127
- GOODS-A28 [backend] The product list requests by page (10 per page) with: category ids, min/max price, keyword, sort field (sold/price) and direction (asc/desc), recommend, featured; empty conditions are not sent。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCategoryViewModel.kt:195
- GOODS-A29 [ui] The sort bar has `综合`, `销量`, and `价格`: tapping `综合` clears sorting; first tap on `销量`/`价格` sorts ascending, tapping again sorts descending, and a third tap goes back to `综合`; the up/down arrows highlight the current direction, and every sort change refreshes the list from page 1。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCategoryViewModel.kt:272
- GOODS-A30 [backend] Tapping `筛选` opens the filter overlay; on first open only, the category list is requested and built into a parent-child tree (sorted by sortNum, nested by parentId); the overlay shows loading while the request is in progress and the network error state on failure。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCategoryViewModel.kt:216
- GOODS-A31 [ui] The filter overlay has the title `筛选` and a close button, a `价格区间` row with numeric inputs `最低价`/`最高价`, and one card per top-level category whose child categories are multi-select chips (icon + name); `重置` clears the conditions and refreshes the list (the overlay stays open), `确定` applies the conditions, closes the overlay and refreshes the list, and tapping the mask closes it without applying。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/component/FilterDialog.kt:329
- GOODS-A32 [ui] The category page defaults to a two-column grid; the button at the right of the top bar toggles grid/list, and when the top bar collapses on scroll, the toggle button appears at the right end of the sort bar。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsCategoryScreen.kt:398
- GOODS-A33 [ui] The category page shows a skeleton screen while loading, the empty state with no data, and the network error state with retry on failure; the list supports pull-to-refresh and load-more, and tapping a product goes to its detail page。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsCategoryScreen.kt:286
- GOODS-A34 [backend] Submitting from the category page's own search box re-queries the list with the new keyword (no keyword condition when empty) and does not write search history。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/viewmodel/GoodsCategoryViewModel.kt:309
- GOODS-A35 [ui] Category product list page: top content avoids the status bar。锚点：feature/goods/src/main/java/com/joker/coolmall/feature/goods/view/GoodsCategoryScreen.kt:197

## Components and interactions
Detail page (GoodsDetailScreen.kt)
- Top bar back button (circle) → navigateBack — GoodsDetailScreen.kt:389
- Top bar share button (circle) → no-op (`/* TODO: 分享功能 */`) — GoodsDetailScreen.kt:337
- Coupon tag `满%d减%d元` → open CouponModal — GoodsDetailScreen.kt:754
- Spec row `选择规格` / `已选：%s` → open SpecSelectModal — GoodsDetailScreen.kt:797
- Comment card header `商品评价` + `查看全部` → GoodsNavigator.toComment(goodsId) — GoodsDetailScreen.kt:848
- Comment item (CommentItem) → GoodsNavigator.toComment — GoodsDetailScreen.kt:858
- Bottom bar `客服` → CsNavigator.toChat — GoodsDetailScreen.kt:349
- Bottom bar `购物车` → MainNavigator.toCart(showBackIcon = true) — GoodsDetailScreen.kt:350
- Bottom bar `加入购物车` → showSpecModal — GoodsDetailScreen.kt:346
- Bottom bar `立即购买` → showSpecModal — GoodsDetailScreen.kt:347
SpecSelectModal (core/ui/.../modal/SpecSelectModal.kt)
- Spec item (grid/list) tap → select/deselect — SpecSelectModal.kt:473, :570
- View toggle icon (ic_menu_list/ic_menu) → grid⇄list — SpecSelectModal.kt:289
- `数量` QuantityStepper +/- (min 1) — SpecSelectModal.kt:349
- `加入购物车` (bordered) → onAddToCart(SelectedGoods) then onDismiss — SpecSelectModal.kt:655
- `立即购买` (gradient) → onBuyNow(SelectedGoods) then onDismiss — SpecSelectModal.kt:665
CouponModal (core/ui/.../modal/CouponModal.kt): title `领取优惠券`, each coupon action → onCouponAction(coupon.id) — CouponModal.kt:98
Comment page: back button; list of CommentCard (non-clickable) — GoodsCommentScreen.kt:87
Search page (GoodsSearchScreen.kt + SearchTopAppBar)
- Back arrow → navigateBack — GoodsSearchScreen.kt:97
- Input `输入内容进行搜索`, IME Search / `搜索` button → onSearch(text) — SearchTopAppBar.kt:101
- `搜索历史` delete icon → clearSearchHistory (no confirm) — GoodsSearchScreen.kt:190
- History tag → onSearchHistoryClick — GoodsSearchScreen.kt:205
- `推荐搜索` tag → onKeywordClick(keyword.name) — GoodsSearchScreen.kt:238
Category page (GoodsCategoryScreen.kt)
- SearchTopAppBar (prefilled keyword) → viewModel.onSearch — GoodsCategoryScreen.kt:203
- Layout toggle (top-bar actions) — GoodsCategoryScreen.kt:209; duplicate in filter bar when collapsedFraction ≥ 0.8 — :398
- `筛选` button (shared-element morph into dialog) → showFilters — GoodsCategoryScreen.kt:344
- `综合` — :366; `销量` with arrows — :380; `价格` with arrows — :388
- Goods grid item / list item → GoodsNavigator.toDetail(id) — :286, :293
FilterDialog (component/FilterDialog.kt)
- Mask tap → onDismiss — FilterDialog.kt:121
- Close icon → onDismiss — FilterDialog.kt:223
- `最低价` / `最高价` numeric inputs (KeyboardType.Number, no validation) — FilterDialog.kt:255, :271
- Child category chip toggle (multi-select; only children of top-level categories are selectable) — FilterDialog.kt:300
- `重置` → clears local + onResetFilters (dialog stays open) — FilterDialog.kt:329
- `确定` → onApplyFilters(ids, min, max) → hides + refresh — FilterDialog.kt:344

## Data and APIs
- GET `page/goodsDetail?goodsId=` → GoodsDetail{goodsInfo: Goods, coupon: List<Coupon>, comment: List<Comment>} (core/network/.../service/PageService.kt:33). Goods.pics / contentPics are force-unwrapped (!!) in the UI; subTitle also !!.
- POST `goods/spec/list` body {goodsId: Long} → List<GoodsSpec{id, goodsId, name, price:Int, stock:Int, sortNum, images?}> (GoodsService.kt:41)
- POST `market/coupon/user/receive` body {couponId: Long} → String message (CouponService.kt:25)
- POST `goods/comment/page` body {goodsId: String, page, size} → NetworkPageData<Comment{id,userId,goodsId,orderId,content,starCount=5,pics?,nickName?,avatarUrl?,createTime?}> (GoodsService.kt:90)
- POST `goods/search/keyword/list` → List<GoodsSearchKeyword{id,name,sortNum}> (GoodsService.kt:50)
- POST `goods/info/page` body GoodsSearchRequest{page, size, typeId: List<Long>?, minPrice: String?, maxPrice: String?, keyWord: String?, order: "sold"|"price"|null, sort: "asc"|"desc"|null, recommend: Boolean, featured: Boolean} → NetworkPageData<Goods> (GoodsService.kt:60). Note the field is `keyWord` (camel W) and typeId is an array.
- POST `goods/type/list` → List<Category{id, name, parentId?, sortNum, pic}> converted to CategoryTree (GoodsService.kt:31)
- Page size: BaseNetWorkListViewModel.pageSize = 10 (core/common/.../BaseNetWorkListViewModel.kt:48); hasNextPage = size*page < total; load-more triggers when lastIndex ≥ total-3.
- Room `search_history` (PK keyword, searchTime; insert REPLACE; recent query ORDER BY searchTime DESC LIMIT 10).
- Room `carts` (CartRepository.getCartByGoodsId / updateCartSpecCount / updateCart / addToCart; Cart{goodsId, goodsName, goodsMainPic, spec: List<CartGoodsSpec{id,goodsId,name,price,stock,count,images}>}).
- Room `footprints` (PK goodsId; Footprint{goodsId, goodsName, goodsSubTitle, goodsMainPic, goodsPrice, goodsSold, viewTime}).
- MMKV key `selectedGoodsList` = List<SelectedGoods> JSON (consumed by order confirm page).
- Routes: GoodsRoutes.Detail(goodsId: Long), Search, Category(typeId: String? comma list, featured, recommend, keyword?, minPrice?), Comment(goodsId: Long); GoodsNavigator.toDetail/toSearch/toCategory/toComment.

## Cross-cutting notes
Detail/Comment/Category viewmodels enable a minimum loading time (enableMinLoadingTime = true) so skeletons don't flash. Detail spec state lives in two places: the VM's selectedSpec (drives the price and `已选` text on the page) and the modal-local currentSpec/selectedSpecIndex/quantity (quantity resets only when the modal composable leaves composition). Spec loading is lazy and triggered by sheet expansion; the filter category tree is loaded lazily 340ms after the first open (wait for the animation). Category sort state machine: COMPREHENSIVE/NONE; SALES|PRICE cycles NONE→ASC→DESC→NONE (NONE falls back to COMPREHENSIVE); switching type sets ASC. Any sort/filter/search change calls onRefresh (page 1). The detail entry animation (top bar buttons scale 0→1, bottom bar slides up) runs only once (hasAnimated). Every page has light/dark previews; dark mode must work.

## Platform risks
- The task description mentions "favorite", but the goods module has **no favorite feature** (no favorite button/API in the detail page); do not invent one. Share is a no-op TODO.
- Add to cart has no login check and writes only to the local Room cart; buy now passes data through MMKV `selectedGoodsList` — on HarmonyOS, use a relational store + preferences and keep the same key/JSON structure so the order confirm page can read it.
- The shared-element morph from the `筛选` button to FilterDialog (SharedTransitionLayout.sharedBounds) and the exitAlways collapsing of the TopAppBar need ArkUI equivalents such as geometryTransition/nested scrolling; record only the behavior: the toggle button appears after collapse.
- ModalBottomSheet "load specs after fully expanded" timing: ArkUI bindSheet should load in onAppear/after the open animation completes, avoiding duplicate requests.
- Detail content uses !! on pics/contentPics/subTitle; HarmonyOS should handle nulls defensively rather than crash.
- Price is Int (displayed with PriceText); unit consistency follows the core/ui PriceText convention.
- On the category page, an empty-keyword search sends no keyWord (returns all products), unlike the search page, which ignores blank keywords.
