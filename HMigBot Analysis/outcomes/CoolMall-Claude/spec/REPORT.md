# CoolMallHM 迁移台账投影

源：input/CoolMallKotlin　目标：output/CoolMallHM　更新：2026-10-15T09:55:30.215Z

## 切片进度

| 状态 | 数量 |
|---|---|
| planned | 0 |
| implementing | 0 |
| checked | 0 |
| accepted | 29 |
| failed | 0 |
| waived | 0 |

## 功能断言四态（分子/分母 = 327/335；ui=202 on_device=16 backend=117）

| 态 | 数量 |
|---|---|
| untested | 6 |
| passed | 327 |
| failed | 0 |
| waived | 2 |

证据来源：passed 9 真机 / 318 静态；failed 0 真机 / 0 静态（静态=验收代理读码判断，真机=4b 走查）
静态 passed 证据可定位（文件:行 / 报告#步 真实存在）：318/318

## 门历史（3 次）

- 2026-10-14T18:07:40.527Z [slice] fnd-wave: ✅ foundation wave 10 units, final build green after 2 fixes (Context.config, borderColor name clash)
- 2026-10-14T20:02:57.363Z [final] closure-final: ✅ hard violations 0 (4 dead files deleted: BannerRepository/BannerService/AppColors/AboutLink) · 4 soft cases waived (spec/closure-waivers.json 6 waivers) · spec/closure/closure-final.json
- 2026-10-15T09:55:30.214Z [integration] runtime-4b: ✅ Core paths: 8 flows/249 steps all ok, tapsNoChange 0 (spec/4b/flow-*.report.json); 17 per-page plans all alive with no crashes; on_device passed 10/16, untested 6 (AUTH-A22/DATA-A21 verified manually in the notification shade but without a walk report step; CS-A15 sound not observable by the tools; ORDB-A29 needs an order awaiting review; COM-A22 not walked; DATA-A22 denial branch would require reinstall + re-login); 1 fix and re-verify on device (HtmlDocumentView blank page)

## 降级与债务

- [降级·approx] dg-compose-m3-visual: Compose/Material3 elevation/tonal color levels/shape animations have no 1:1 ArkUI API; approximated with surface color levels/static styling (batch-level approximation per the feasibility yellow items androidx.compose.*/material3)（Batch exemption for visual approximation; behavior contracts are not exempt；查证：feasibility.json summary.yellow）
- [降级·approx] deg-page-cart-hvdit6: The bottom bar copies the source Surface (shadowElevation 1dp, 1dp outline border at 0.6 alpha) as a surface background, a 1vp top border in app.color.divider, （实现期登记（切片 page-cart）·待裁决）
- [降级·approx] deg-page-cart-115kmd: Edge-to-edge insets: on the standalone page (showBackIcon=true) the bottom bar, or the empty-state content, is padded by AvoidArea.bottom, following the AppScaf（实现期登记（切片 page-cart）·待裁决）
- [降级·approx] deg-page-cart-zy490k: `合计:` is rendered as Span($r( app.string.total )) + Span( : ), because the merged app.string.total is `合计` (core/ui and feature/order key collision) while the s（实现期登记（切片 page-cart）·待裁决）
- [降级·approx] deg-page-tab-category-vkni6p: Left item animations are close to the source but not identical. Text colour and size use an implicit .animation of 300ms ease-in-out; the source uses a colour t（实现期登记（切片 page-tab-category）·待裁决；查证：Visual and animation approximation only; the behaviour contract stays the same.）
- [降级·approx] deg-page-tab-category-6ppfpt: The rule for which right-side section counts as  in view  uses Scroller.getItemRect positions, with the 16vp content offset subtracted so they match Compose s L（实现期登记（切片 page-tab-category）·待裁决；查证：Geometry approximation of derivedStateOf(currentVisibleIndex); the linking contr）
- [降级·approx] deg-page-tab-me-18y40o: Source avatar uses Compose sharedElement(key= user_avatar ) transition between Me tab and Profile page; target renders the avatar without a shared-element trans（实现期登记（切片 page-tab-me）·待裁决）
- [降级·approx] deg-page-tab-me-4o97s2: Android LifecycleObserver.onResume is approximated by aboutToAppear + NavDestination ON_SHOWN of the hosting page (uiObserver navDestinationUpdate) + applicatio（实现期登记（切片 page-tab-me）·待裁决）
- [降级·approx·已退回] deg-page-main-shell-home-1ego8h: HOME-A04: the project has no Lottie runtime (oh-package has no @ohos/lottie). Each tab shows a static SymbolGlyph instead (house / square_grid_2x2 / cart(_fill)（实现期登记（切片 page-main-shell-home）·待裁决；查证：entry/oh-package.json5 dependencies are empty, so there is no lottie library. Bo）
- [降级·approx] deg-page-main-shell-home-afwn9a: HOME-A07: enterAlways is rebuilt from the content scroll offset delta (RefreshList onScrollOffset / skeleton onDidScroll). The bar height is 64 + offset, clampe（实现期登记（切片 page-main-shell-home）·待裁决；查证：core/ui/base/RefreshList.ets hard-codes nestedScroll({scrollForward: PARENT_FIRS）
- [降级·approx·已退回] deg-page-main-shell-home-e5b693: The splash-to-home `app_logo` shared-element transition is not reproduced. The logo is shown statically; tapping it still opens About. Visual only.（实现期登记（切片 page-main-shell-home）·待裁决；查证：Pairing would require editing LaunchRoutesSplashPage, which is outside this slic）
- [降级·approx] deg-page-main-shell-home-b10nql: The banner and coupon carousels use the shared core WeSwiper, whose inner Swiper keeps the default nestedScroll (SELF_ONLY). At their first/last page a horizont（实现期登记（切片 page-main-shell-home）·待裁决；查证：core/ui/widget/Swiper.ets WeSwiper exposes no nestedScroll parameter, and core i）
- [降级·approx] deg-page-main-shell-home-w9euuk: HOME-A19 `没有更多了`: the source LoadMore NoMore branch (core/ui/.../loading/LoadMore.kt:122) draws divider, 4dp dot, divider with no text. The shared LoadMoreFoote（实现期登记（切片 page-main-shell-home）·待裁决；查证：grep of LoadMore.kt: the NoMore branch has no stringResource; load_more_no_more ）
- [降级·approx] deg-page-user-profile-footprint-1n8srb: The source plays a shared-element animation on the avatar (key  user_avatar ) between the Me tab and the Profile page. I did not reproduce it: the Me-tab side i（实现期登记（切片 page-user-profile-footprint）·待裁决）
- [降级·approx] deg-page-user-profile-footprint-1kcfpv: The source uses M3 Card ripple and TextButton visuals. I approximated them with a bg_card or transparent background, a 12vp corner radius and a pressed-state ba（实现期登记（切片 page-user-profile-footprint）·待裁决）
- [降级·approx·已退回] deg-page-launch-1h1kjq: Shared element app_logo (LAUNCH-A08): the splash logo has geometryTransition( app_logo ), but the home top-bar logo has no matching tag (it is outside this slic（实现期登记（切片 page-launch）·待裁决；查证：Ran grep for  app_logo|geometryTransition  across ets: the only hit outside the ）
- [降级·approx] deg-page-launch-ntmxja: Splash background blur: Compose Modifier.blur(100.dp) is mapped to ArkUI .blur(100) on the 240 logo container, and the blur kernel and units differ somewhat. Th（实现期登记（切片 page-launch）·待裁决；查证：Compared against the source SplashScreen.kt BackgroundLogoSection: blur(radius =）
- [降级·approx] deg-page-order-refund-comment-11yhkh: The review input uses ArkUI TextArea in place of the M3 TextField (transparent colors on surfaceVariant). minLines 6 / maxLines 8 is done with constraintSize: l（实现期登记（切片 page-order-refund-comment）·待裁决）
- [降级·approx] deg-page-goods-search-list-1dtfd7: Opening FilterDialog uses the source s sharedBounds morph from the 筛选 pill into the panel (RemeasureToBounds). Here it is a 300ms opacity fade of the whole over（实现期登记（切片 page-goods-search-list）·待裁决）
- [降级·approx] deg-page-goods-search-list-1fflhn: The source TopAppBarDefaults.enterAlwaysScrollBehavior collapses the bar through nestedScroll pre-scroll. Here the RefreshList onScrollOffset deltas drive a -64（实现期登记（切片 page-goods-search-list）·待裁决）
- [降级·approx] deg-page-goods-search-list-f1xzp5: The 重置 button is drawn locally (34vp, primary border, bodyMedium text) because the shared AppButtonBordered has no fill-width option, while the source sizes it （实现期登记（切片 page-goods-search-list）·待裁决）
- [降级·no_equiv] deg-page-auth-login-128f0j: QQ login (AUTH-A05/A06): the source uses the Tencent QQ Android SDK. The HarmonyOS SDK has no QQ authorization API, and no third-party QQ ohpm dependency can be（实现期登记（切片 page-auth-login）·待裁决；查证：grep -rlE  Tencent|QQOpenApi|IQQOpenApi|startQQLogin|qqopensdk  over /Applicatio）
- [降级·approx] deg-page-auth-login-myzfc8: Entrance animations are approximated with ArkUI transitions: the logo uses TransitionEffect.move(TOP) with curves.interpolatingSpring(0,1,200,14.14) for Spring （实现期登记（切片 page-auth-login）·待裁决）
- [降级·approx] deg-page-auth-login-1n2hjn: The digit-only, max-4 filters on the SMS code and image-code inputs use TextInput.inputFilter( [0-9] ) + maxLength(4). On paste this strips the non-digit charac（实现期登记（切片 page-auth-login）·待裁决）
- [降级·approx] deg-page-auth-login-1x3opm: The QQ launch-failure toast fills the source s `%s` placeholder with a technical English detail ( QQ OpenSDK unavailable on HarmonyOS ), because this slice cann（实现期登记（切片 page-auth-login）·待裁决）
- [降级·source_stub] deg-page-goods-detail-152gtp: Share button in the detail top bar: source onShareClick = { /* TODO: 分享功能 */ } does nothing; target logs console.info( TODO:share:GoodsDetailTopBar ) (GOODS-A16（实现期登记（切片 page-goods-detail）·待裁决；查证：Source GoodsDetailScreen.kt GoodsDetailContentView passes onShareClick = { /* TO）
- [降级·approx] deg-page-goods-detail-1lfiu9: Bottom action bar Surface(shadowElevation = 4.dp) approximated with .shadow({radius 8, #1A000000}) on a surface-colored Row; entry animations use Curve.FastOutS（实现期登记（切片 page-goods-detail）·待裁决；查证：Visual only; behavior contract unchanged.）
- [降级·approx] deg-page-goods-detail-1wmlrl: Detail List uses EdgeEffect.None instead of Android s stretch overscroll so the scroll-driven top bar alpha stays within 0..255 at the top edge.（实现期登记（切片 page-goods-detail）·待裁决；查证：Visual only.）
- [降级·approx·已退回] deg-page-order-confirm-pay-1l4lzn: ORDB-A18: Alipay Android SDK PayTask.payV2 is replaced by Payment Kit thirdPaymentService.ThirdPayClient(PayMethod.ALI_PAY), which does exist in the HarmonyOS S（实现期登记（切片 page-order-confirm-pay）·待裁决；查证：grep in DevEco SDK hms/ets/api/@hms.core.payment.thirdPaymentService.d.ts: Third）
- [降级·approx] deg-page-order-confirm-pay-1donjw: ORDB-A09: CouponModal is given selectedCouponId = the selected coupon s id, so the selected card shows `已选择` as the assertion card requires. The source CouponMo（实现期登记（切片 page-order-confirm-pay）·待裁决；查证：Source core/ui/component/modal/CouponModal.kt CouponModalContent calls CouponCar）
- [降级·approx] deg-page-order-confirm-pay-53juew: ORDB-A10: the M3 OutlinedTextField floating-label animation is approximated by a static label on the outline above a TextArea (3 to 5 lines, focus changes the b（实现期登记（切片 page-order-confirm-pay）·待裁决；查证：Visual only; covered by the batch M3 animation approximation.）
- [降级·approx] deg-page-market-feedback-73knvg: The feedback content field (source M3 OutlinedTextField with minLines = 3 and maxLines = 5) is a TextArea with maxLines(5). Because text_area.d.ts has no minLin（实现期登记（切片 page-market-feedback）·待裁决）
- [降级·approx] deg-page-market-feedback-doj0tw: The M3 FilterChip feedback-type chips are a Row 32 vp high with 8 vp corners and 16 vp horizontal padding. Selected: primary background and border, white text. （实现期登记（切片 page-market-feedback）·待裁决）
- [降级·approx] deg-page-market-feedback-hfm9b1: In the skeletons, the source s wrap-content columns of fractional SkeletonTextLines (coupon card right column; feedback time line) use a fixed 72 vp slot with f（实现期登记（切片 page-market-feedback）·待裁决）
- [降级·approx] deg-page-address-1ed9l5: M3 OutlinedTextField is approximated by AddressOutlinedField (TextInput / TextArea, 12vp outlined box, 1vp outline or 2vp primary when focused). The label rests（实现期登记（切片 page-address）·待裁决；查证：Visual-only approximation; ArkUI TextInput has no outlined floating-label style.）
- [降级·approx] deg-page-address-1vmg42: The region picker sheet uses bindSheet with FIT_CONTENT height, and its region list is capped at 60% of the screen height and scrolls internally. This stands in（实现期登记（切片 page-address）·待裁决；查证：Visual and height approximation only; bindSheet has no M3 partial-expand drag se）
- [降级·approx] deg-page-order-list-1dcel1: Visual approximation of the order tab bar: M3 ScrollableTabRow is mapped to Tabs + SubTabBarStyle (BarMode.Scrollable, 48vp bar, 16vp tab padding, 2vp primary i（实现期登记（切片 page-order-list）·待裁决；查证：tab_content.d.ts SubTabBarStyle offers indicator({color,height,width,borderRadiu）
- [降级·approx] deg-page-order-list-1lc3oh: Visual approximation of the pager animation: instead of HorizontalPager.animateScrollToPage and the isAnimatingTabChange guard, Tabs  own content animation is u（实现期登记（切片 page-order-list）·待裁决；查证：tabs.d.ts: onAnimationStart(OnTabsAnimationStartCallback) and onChange are avail）
- [降级·approx] deg-page-settings-bcclm5: Radio buttons in the theme sheets are shown inside a 48vp touch box but do not take taps themselves; the whole row handles the tap and calls onSelect (in the so（实现期登记（切片 page-settings）·待裁决）
- [降级·approx] deg-page-settings-1xk6o9: The sheet drag-handle color (onSurface at 10% alpha) is approximated with 10% black or white chosen by ThemeManager.isDark.（实现期登记（切片 page-settings）·待裁决）
- [降级·approx] deg-page-cs-chat-qay4ju: Compose LazyColumn(reverseLayout=true) is expressed as List.stackFromEnd(true) over the newest-first data reversed, with the load-more item first. Newest stays （实现期登记（切片 page-cs-chat）·待裁决；查证：list.d.ts declares stackFromEnd (since 19) and onScrollIndex; scroll.d.ts declar）
- [降级·approx] deg-page-cs-chat-5phro9: Animations are approximated with ArkUI equivalents: new-message slide-in plus fade via a ListItem TransitionEffect (400/300 ms FastOutSlowIn); panel height spri（实现期登记（切片 page-cs-chat）·待裁决）
- [降级·approx] deg-page-cs-chat-1hujii: Compose imePadding is reproduced by switching UIContext.setKeyboardAvoidMode(RESIZE) while the chat NavDestination is shown, and restoring the previous mode onH（实现期登记（切片 page-cs-chat）·待裁决；查证：@ohos.arkui.UIContext.d.ts declares both (lines ~4397/4406)）
- [降级·source_stub] deg-page-cs-chat-18mj3n: Function panel items `相册`/`拍摄` only collapse the panel because the source has `// TODO: 处理功能选择`. The tap logs console.info( TODO:functionSelected:<fn>:FunctionS（实现期登记（切片 page-cs-chat）·待裁决）
- [降级·approx] deg-page-about-web-contributors-n6qlkw: About aurora: the five orbiting radial-gradient light sources use the source formulas, re-evaluated by a ~30fps timer. The source s blur(150dp) is omitted becau（实现期登记（切片 page-about-web-contributors）·待裁决；查证：Visual approximation of Compose drawBehind + Modifier.blur; behaviour contract u）
- [降级·approx] deg-page-about-web-contributors-1vyt86: About header and toolbar: alpha/scale come straight from the scroll fraction (clamp(scrollY/220,0,1)) instead of being smoothed with animateFloatAsState. The en（实现期登记（切片 page-about-web-contributors）·待裁决；查证：Same fade/shrink/title fade-in thresholds as source; only the spring smoothing i）
- [降级·approx] deg-page-about-web-contributors-xeja5t: 引用致谢 sheet: bindSheet with FIT_CONTENT height and the list capped at about 90% of page height minus the status bar and sheet chrome, so the 21 items scroll insi（实现期登记（切片 page-about-web-contributors）·待裁决；查证：Same content, order and click/close behaviour; only the sheet height detent beha）
- [降级·approx] deg-page-about-web-contributors-1614kd: Web: a non-http scheme is always intercepted (returns true) and handed to startAbility(viewData, uri), which is async. The source returns false when no app can （实现期登记（切片 page-about-web-contributors）·待裁决；查证：COM-A22 behaviour (http in place, other schemes to system, JS + DOM Storage on) ）
- [降级·source_stub] deg-page-about-web-contributors-18kh6a: The QQ 交流群 and 微信交流群 rows have empty onClick handlers in the source. They are wired to console.info( TODO:noop-as-source:... ) only, to satisfy convention H3.（实现期登记（切片 page-about-web-contributors）·待裁决；查证：AboutScreen.kt: onClick = { } for about_qq_group / about_wechat_group.）
- [降级·source_stub] deg-page-auth-register-reset-13vo7u: In the source, ResetPasswordViewModel.sendVerificationCode() and resetPassword() are empty (TODO) and the reset button has enabled=false. Here they are kept as （实现期登记（切片 page-auth-register-reset）·待裁决；查证：Checked the source ResetPasswordViewModel.kt: both functions are an empty viewMo）
- [降级·source_stub] deg-page-order-detail-logistics-v1lihy: In the source, the order number  复制  link, the logistics number  复制  link, the  拨打  link and the 优惠金额 row all have empty onClick bodies (/* 复制订单号 */, /* 复制物流编号 （实现期登记（切片 page-order-detail-logistics）·待裁决；查证：OrderDetailScreen.kt lines for the order number copy and discount row, and Order）
- [降级·approx] deg-page-order-detail-logistics-l587wg: LogisticsSteps used drawBehind (drawCircle and drawLine) in the source. The port rebuilds it with layout: a Flex with ItemAlign.Stretch holding a 24vp gutter co（实现期登记（切片 page-order-detail-logistics）·待裁决；查证：Visual approximation only; the behavior contract is unchanged.）
- [降级·no_equiv] deg-fnd-app-init-qq-init: LAUNCH-A34 QQ SDK startup init (AppId 102756675) + Activity-result callback: the HarmonyOS SDK has no QQ OpenSDK; AppId kept as a constant, no init (same root cause as deg-page-auth-login-128f0j)（Ruled in 4a: holds (no_equiv)；查证：grep -rlE Tencent|QQOpenApi over sdk/default *.d.ts: no matches）
- [降级·policy] deg-fnd-app-init-toast-before-ui: INIT-A01/LAUNCH-A18: the toast needs a UIContext, which only exists after the loadContent callback; toasts fired between onCreate and loadContent are dropped and logged (Android Toaster.init can toast right after Application.onCreate)（Ruled in 4a: holds (platform UI context timing)；查证：EntryAbility.ets ToastUtils.init is in the loadContent callback; promptAction re）
- [降级·policy] deg-fnd-app-init-toast-forced-mode: LAUNCH-A32: when the in-app theme is forced to light/dark (ApplicationContext.setColorMode), the Configuration.colorMode the app receives is the app-level value, so a system dark-mode toggle cannot be observed; the toast style then follows the forced app mode; in follow-system mode it switches with the system as in the source（Ruled in 4a: holds (platform color-mode override policy)；查证：ApplicationContext.setColorMode sets the app-level color mode; onConfigurationUp）
- [降级·policy] deg-fnd-util-sms-no-banner: DATA-A21/AUTH-A22: the Android verification_code_channel (IMPORTANCE_HIGH) shows a heads-up banner; on HarmonyOS the SOCIAL_COMMUNICATION slot notification only enters the shade by default, and banners must be enabled by the user under Settings > Notifications > 青商城 (apps cannot enable them programmatically)（Ruled in 4b: holds (system notification banner policy)；查证：Device 77UYD26331000973: after publish the shade has the notification but no ban）
- [债务] blk-page-tab-category: CategoryTab is not shown in the app yet. pages/MainRoutesMainPage.ets is still a placeholder, and it is outside the directory I was allowed to edit. The main page slice needs to import it with `import { CategoryTab } from  ../feature/main/category/CategoryTab ` and put `CategoryTab()` inside the Cat — resolved
- [债务] blk-page-user-profile-footprint: USER-A28 requires a footprint to be written each time goods detail opens. In the source, GoodsDetailViewModel.addToFootprint(goods) builds a Footprint (goodsId, goodsName, goodsSubTitle, goodsMainPic, goodsPrice, goodsSold, viewTime = now) and calls footprintRepository.addFootprint after the detail  — resolved
- [债务] blk-page-launch: LAUNCH-A08 pairing: feature/main/home/HomeTopAppBar.ets (outside this slice) has to add .geometryTransition( app_logo ) to its LogoIcon Image so the splash logo has a target. — resolved
- [债务] blk-page-auth-login: Optional: append a localized string resource such as `qq_login_unavailable` (zh/en) to resources/base/element/string.json and its en counterpart, so the QQ toast can explain in Chinese/English that QQ login is unavailable on HarmonyOS. This slice may not edit resources. No module.json5 permission is — resolved

## 场景走查（output/CoolMallHM/spec/4b：计划 0 份含场景、已跑 0、计划全过 0；场景 0/0 已走、0 通过，⚠ 分母只是计划里提到的场景（缺 scenarios.txt 全集））

| 场景 | 结果 | 所在计划 |
|---|---|---|

⚠ --walks 目录里没有带 scenarios 字段的计划——有 PRD 时每份流计划须写 "scenarios":["S1","S2"]

走查形态：流计划 8 份（已跑 8、全过 8）· 骨架计划 18 份（直达/存活/出现率，不计"已走"）

真机可见性（静态 passed 且带字面量的 ui 断言 140 条）：字面量在走查中出现过 98 条 · 从未出现 42 条（静态判断、真机未见：AUTH-A15 AUTH-A20 AUTH-A29 COM-A17 COM-A19 COM-A20 COM-A21 CS-A10 CS-A11 CS-A19 GOODS-A02 GOODS-A15 …）

## 源模块覆盖（按断言锚点归模块；源工程 23 个 Gradle 模块）

| 模块 | 断言数 |
|---|---|
| feature/order | 62 |
| feature/main | 48 |
| feature/goods | 33 |
| feature/auth | 28 |
| feature/common | 26 |
| feature/user | 25 |
| feature/cs | 19 |
| feature/launch | 15 |
| core/navigation | 10 |
| app | 9 |
| feature/feedback | 9 |
| core/data | 8 |
| core/ui | 8 |
| core/util | 7 |
| core/database | 6 |
| core/network | 5 |
| core/common | 5 |
| core/datastore | 4 |
| feature/market | 3 |
| core/result | 2 |
| build-logic/convention | 1 |
| core/model | 1 |
| core/designsystem | 1 |