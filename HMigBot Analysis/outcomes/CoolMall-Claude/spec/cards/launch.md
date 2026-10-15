# Splash page (LaunchRoutes.Splash)

Route: LaunchRoutes.Splash
Sources: feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt, feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/SplashViewModel.kt, feature/launch/src/main/java/com/joker/coolmall/feature/launch/navigation/LaunchGraph.kt, core/navigation/src/main/java/com/joker/coolmall/navigation/launch/LaunchRoutes.kt, feature/launch/src/main/res/values/strings.xml

## Assertions
- LAUNCH-A01 [ui] On cold start the first page on the app back stack is the splash page (not the home page)。锚点：app/src/main/java/com/joker/coolmall/navigation/AppNavHost.kt:58
- LAUNCH-A02 [ui] The splash page shows the app logo in the center, a large blurred logo as background, the app name `青商城` below it, and the copyright line `© 2025 Joker.X & CoolMallKotlin Contributors`。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt:149
- LAUNCH-A03 [ui] The splash background uses the theme surface color and follows light/dark mode (white in light mode, `#1B1B1B` in dark mode)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt:145
- LAUNCH-A04 [ui] Top content avoids the status bar (the logo and text are laid out centered/at the bottom and are not covered by the status bar)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt:142
- LAUNCH-A05 [ui] After the splash page has shown for about 1.2 seconds it navigates away automatically, with no user action needed。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt:110
- LAUNCH-A06 [backend] When the local storage key `guide_shown` is not true (first install), the splash page goes to the guide page; otherwise it goes straight to the main page (MainRoutes.Main)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/SplashViewModel.kt:31
- LAUNCH-A07 [ui] When the splash page navigates away it removes itself from the back stack; pressing back on the guide/main page does not return to the splash page。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/NavigationService.kt:75
- LAUNCH-A08 [ui] When the splash page goes to the main page, the logo moves via a shared element (key `app_logo`) to the logo position at the top of the home page。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/SplashScreen.kt:221

## Components and interactions
- Logo foreground (LogoIcon size=120, sharedElement `app_logo`) — no click. 锚点：SplashScreen.kt:212
- Background blurred logo (LogoIcon size=240, blur 100dp, alpha .8) — decorative only. 锚点：SplashScreen.kt:169
- Text `app_name_splash`=`青商城` (onSurface). 锚点：SplashScreen.kt:239
- Text `app_copyright`=`© 2025 Joker.X & CoolMallKotlin Contributors` (TERTIARY). 锚点：SplashScreen.kt:248
- No buttons; not skippable. Entrance animation: logo slides up 160dp→0, rotates -15°→0, fades in; text fades in after a 400ms delay (implementation detail, not recorded as an assertion).

## Data and APIs
- No network requests.
- Read local KV: `guide_shown` (Boolean, default false) — MMKVUtils.getBoolean. 锚点：SplashViewModel.kt:23/48
- Navigation: LaunchNavigator.toGuideAndCloseCurrent(Splash) → LaunchRoutes.Guide(fromSettings=false); MainNavigator.toMainAndCloseCurrent(Splash) → MainRoutes.Main. Both = popUpTo(current, inclusive=true, allowPopToEmpty=true) + push.

## Cross-cutting notes
The Android system SplashScreen API (installSplashScreen, MainActivity.kt:39) only shows the window-level launch icon (light background white / dark `#111111`, icon ic_launcher_foreground); setKeepOnScreenCondition{false} hides it immediately, and the real brand splash is the Compose SplashScreen page. Navigation is triggered by a LaunchedEffect(Unit) after delay(1200); the startAnimation state is kept with rememberSaveable. If navigation happens before the NavigationController is attached, AppNavigator queues the command (pendingCommands) and replays it after attach.

## Platform risks
- On HarmonyOS, use the startWindowIcon/startWindowBackground in module.json5 for the system launch screen, then make Index/Splash the first page inside the app; there is no equivalent of installSplashScreen.
- The cross-page shared-element transition (`app_logo`) between Navigation pages in ArkUI needs geometryTransition plus a matching id on the target page (HomeScreen.kt:524), or it can degrade to a fade.
- blur(100dp) background: ArkUI's .blur() looks different; visual differences are acceptable.

# Guide page (LaunchRoutes.Guide)

Route: LaunchRoutes.Guide(fromSettings: Boolean = false)
Sources: feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt, feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/GuideViewModel.kt, feature/launch/src/main/java/com/joker/coolmall/feature/launch/model/GuidePageData.kt, feature/launch/src/main/res/values/strings.xml, core/navigation/src/main/java/com/joker/coolmall/navigation/launch/LaunchNavigator.kt

## Assertions
- LAUNCH-A09 [ui] The guide page has 4 horizontally swipeable pages; each shows an illustration, a bold title, and a multi-line description (`青商城 - 开源电商学习项目`, `声明式 UI 新体验`, `完整电商业务流程`, `模块化架构设计`)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/model/GuidePageData.kt:34
- LAUNCH-A10 [ui] Top content avoids the status bar (the top-right `跳过` button sits inside the Scaffold safe area and is not covered by the status bar)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt:141
- LAUNCH-A11 [ui] The bottom has a page indicator with 4 dots; the dot for the current page is shown highlighted, elongated and opaque, and it updates in sync as the user swipes。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt:304
- LAUNCH-A12 [ui] On pages that are not the last one, the bottom button says `继续`; tapping it scrolls to the next page with animation。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt:228
- LAUNCH-A13 [ui] On the last page the bottom button text becomes `开始体验` (and the button gets wider)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt:229
- LAUNCH-A14 [backend] In the normal flow (fromSettings=false), tapping `开始体验` or `跳过` writes local storage `guide_shown`=true and then goes to the main page, removing the guide page from the back stack。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/GuideViewModel.kt:102
- LAUNCH-A15 [on_device] After finishing the guide, the next cold start skips the guide page (splash → main page)。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/GuideViewModel.kt:119
- LAUNCH-A16 [ui] When opened from the settings page's `应用引导` entry (fromSettings=true), tapping `开始体验` or `跳过` only goes back to the previous page (settings); it does not write `guide_shown` and does not go to the main page。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/viewmodel/GuideViewModel.kt:103
- LAUNCH-A17 [ui] The guide page follows light/dark mode (surface background), and the indicator/button colors follow the current theme primary color。锚点：feature/launch/src/main/java/com/joker/coolmall/feature/launch/view/GuideScreen.kt:140

## Components and interactions
- TextButton `跳过` (guide_skip), top right → skipGuide() → startExperience(). 锚点：GuideScreen.kt:184
- HorizontalPager, 4 pages, swipeable; currentPage → viewModel.updatePageIndex. 锚点：GuideScreen.kt:132/206
- AppButton `继续` (guide_continue) / `开始体验` (guide_start_experience) → handleNextClick(): not last page → animateScrollToPage(next); last page → startExperience(). 锚点：GuideScreen.kt:238, GuideViewModel.kt:66
- PageIndicator: 4 bars, selected one 24dp/alpha 1, others 8dp/alpha .4, color primary. 锚点：GuideScreen.kt:315
- Page data (title / description / image):
  1. `青商城 - 开源电商学习项目` / `100% Kotlin 开发的现代化电商应用\n完全开源免费，助力开发者快速成长\n提供完整的代码参考和学习资源` / ic_book_writer
  2. `声明式 UI 新体验` / `基于 Jetpack Compose 构建流畅界面\n采用 MVVM + Clean Architecture 架构\nHilt、Coroutines、Flow 等主流技术全整合` / ic_home_screen
  3. `完整电商业务流程` / `用户认证、商品展示、搜索分类\n购物车管理、订单支付全流程实现\n贴近真实商业场景的学习案例` / ic_add_to_cart
  4. `模块化架构设计` / `参考 Google Now in Android 最佳实践\n高内聚低耦合，便于维护与扩展\n适合学习与二次开发的优质项目` / ic_dev_productivity
  (strings.xml:9-19; English values-en/strings.xml exists: Skip / Get Started / Continue …)
- Entry: SettingsScreen.kt:258 `LaunchNavigator.toGuide(fromSettings = true)` (feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt).

## Data and APIs
- Write local KV: `guide_shown`=true (MMKVUtils.putBoolean), only when fromSettings=false. 锚点：GuideViewModel.kt:36/119
- No network requests.
- Navigation: MainNavigator.toMainAndCloseCurrent(LaunchRoutes.Guide()) — note that popUpTo matches by equality with `Guide(fromSettings=false)`; navigateBack() is used when fromSettings=true.

## Cross-cutting notes
The page index is held by GuideViewModel.currentPageIndex (StateFlow) and synced back via snapshotFlow(pager.currentPage); isLastPage = index == size-1. The 4 SVG/vector illustrations (ic_book_writer/ic_home_screen/ic_add_to_cart/ic_dev_productivity) live in feature/launch/src/main/res/drawable and must be converted to HarmonyOS media resources. The system back key behavior on the guide page is not specially handled (normal flow: the back stack has only Guide, so back exits the app).

## Platform risks
- ArkUI Swiper replaces HorizontalPager: turn off the built-in indicator and draw the custom indicator yourself; changeIndex/SwiperController.showNext drives the next-page animation.
- Android vector drawable → HarmonyOS needs conversion to SVG/PNG; missing assets will leave the page blank.

# App startup and global initialization (domain card INIT)

Route: domain card, no page
Sources: app/src/main/java/com/joker/coolmall/Application.kt, app/src/main/java/com/joker/coolmall/MainActivity.kt, app/src/main/java/com/joker/coolmall/navigation/AppNavHost.kt, app/src/main/AndroidManifest.xml, app/src/main/res/values-v31/themes.xml, app/src/main/res/values-night-v31/themes.xml, core/common/src/main/java/com/joker/coolmall/core/common/manager/ThemePreferenceManager.kt, core/common/src/main/java/com/joker/coolmall/core/common/config/ThemePreference.kt, core/common/src/main/java/com/joker/coolmall/core/common/config/ThemeColorOption.kt, core/common/src/main/java/com/joker/coolmall/core/common/config/AppConfig.kt, core/designsystem/src/main/java/com/joker/coolmall/core/designsystem/theme/Theme.kt, core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt, core/navigation/src/main/java/com/joker/coolmall/navigation/AppNavigator.kt, core/navigation/src/main/java/com/joker/coolmall/navigation/RouteInterceptor.kt, core/navigation/src/main/java/com/joker/coolmall/navigation/NavigationService.kt, core/navigation/src/main/java/com/joker/coolmall/navigation/BackStackNavigationController.kt

## Assertions
- LAUNCH-A18 [backend] At app startup, initialization runs in order: Toast → Log → local KV storage (MMKV) → QQ SDK, and the global login state (AppState.initialize) is restored only after KV storage is ready。锚点：app/src/main/java/com/joker/coolmall/Application.kt:29
- LAUNCH-A19 [backend] At startup, login state is restored from the local `auth_info` record: it counts as logged in only when the token is non-empty and not expired (createdAt + expire seconds); only when logged in is user info read from local `user_info` and userId set。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:75
- LAUNCH-A20 [on_device] After logging in and cold-restarting the app, the logged-in state and user info are kept (no need to log in again)。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:97
- LAUNCH-A21 [backend] On logout, local `auth_info` and `user_info` are cleared and the in-memory login state is reset to not logged in (userId=0)。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:146
- LAUNCH-A22 [backend] Global route login wall: when not logged in, navigating to profile/address list/address detail/order list/confirm order/order detail/payment/refund/review/logistics/support chat/coupons/feedback list/submit feedback is redirected to the login page (AuthRoutes.Login)。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/RouteInterceptor.kt:29
- LAUNCH-A23 [ui] The app is edge-to-edge: page content draws under the status bar and navigation bar, and each page handles safe-area insets itself。锚点：app/src/main/java/com/joker/coolmall/MainActivity.kt:42
- LAUNCH-A24 [ui] Theme mode supports three modes: `follow_system`/`light`/`dark`; the default is follow system, and dark mode is applied according to the setting。锚点：app/src/main/java/com/joker/coolmall/MainActivity.kt:47
- LAUNCH-A25 [backend] Theme mode and theme color are persisted to local keys `settings_theme_mode` and `settings_theme_color`; unknown or missing values fall back to follow system / default color。锚点：core/common/src/main/java/com/joker/coolmall/core/common/manager/ThemePreferenceManager.kt:23
- LAUNCH-A26 [ui] The theme color offers 5 choices: default `#465CFF`, purple `#6831FF`, green `#09BE4F`, orange `#FFB703`, red `#FF2B2B`; the chosen color replaces the global primary color and takes effect right away, without a restart。锚点：core/common/src/main/java/com/joker/coolmall/core/common/config/ThemeColorOption.kt:16
- LAUNCH-A27 [on_device] After changing the theme mode/theme color and cold-restarting, the last selection is kept。锚点：core/common/src/main/java/com/joker/coolmall/core/common/manager/ThemePreferenceManager.kt:88
- LAUNCH-A28 [ui] Light/dark color tokens: light page background `#F1F4FA`, light card `#FFFFFF`; dark page background `#111111`, dark card `#1B1B1B`; dynamic color (Monet) is off。锚点：core/designsystem/src/main/java/com/joker/coolmall/core/designsystem/theme/Theme.kt:82
- LAUNCH-A29 [ui] Page transitions use horizontal slides: going forward the new page slides in from the right, going back it slides out to the right; predictive back uses the same back animation。锚点：app/src/main/java/com/joker/coolmall/navigation/AppNavHost.kt:87
- LAUNCH-A30 [backend] Navigation commands issued before the navigation host is ready are queued and run in order once the host is attached, so none are lost。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/AppNavigator.kt:151
- LAUNCH-A31 [ui] When the back stack has only one page, the in-app back action does not pop the last page (the root page is kept)。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/BackStackNavigationController.kt:62
- LAUNCH-A32 [ui] The toast style follows the system dark mode: a light/white toast in dark mode and a black toast in light mode, switching when the system theme changes。锚点：app/src/main/java/com/joker/coolmall/Application.kt:94
- LAUNCH-A33 [ui] The app display name is `青商城`; the launcher shows the app icon。锚点：app/src/main/res/values/strings.xml:2
- LAUNCH-A34 [backend] At startup the QQ login SDK is initialized with AppId `102756675`, and the QQ login result callback is returned to the login flow through Activity results。锚点：app/src/main/java/com/joker/coolmall/MainActivity.kt:84

## Components and interactions
- No UI components of its own. Global consumers:
  - SettingsViewModel reads/writes ThemePreferenceManager.themeMode/themeColor (feature/common/.../SettingsViewModel.kt:24/29/68/97).
  - appState.refreshUserInfo() is called after successful login and on Me/Profile pages (SmsLoginViewModel.kt:241, AccountLoginViewModel.kt:125, LoginViewModel.kt:104, RegisterViewModel.kt:313, ProfileViewModel.kt:45, MeViewModel.kt:70); appState.logout() in ProfileViewModel.kt:57.
- Navigation graph registration order (AppNavHost.kt:131): main, goods, auth, user, order, cs, common, market, feedback, launch.

## Data and APIs
- Local KV (MMKV, default instance, MMKVUtils.init → MMKV.initialize):
  - `guide_shown` Boolean (Splash/Guide)
  - `settings_theme_mode` String ∈ {follow_system, light, dark}, default follow_system
  - `settings_theme_color` String ∈ {default, purple, green, orange, red}, default default
  - `auth_info` String (JSON of Auth{token, refreshToken, expire(s), refreshExpire(s), createdAt(ms)}) — core/datastore/.../auth/AuthStoreDataSourceImpl.kt:17
  - `user_info` String (JSON of User) — core/datastore/.../userinfo/UserInfoStoreDataSourceImpl.kt:20
- Auth.isExpired: now >= createdAt + expire*1000; shouldRefresh: now >= createdAt + expire*1000 - 15min && refresh not expired (core/model/.../entity/Auth.kt:50/74).
- AppState exposes StateFlows: isLoggedIn, userId, auth, userInfo; methods updateUserState/updateUserInfo/updateAuth/logout/shouldRefreshToken/refreshUserInfo (refreshUserInfo calls userInfoRepository.getPersonInfo(), only when logged in).
- AppConfig.QQ_APP_ID = "102756675".
- Manifest permissions: INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS; usesCleartextTraffic=true (plain HTTP backend).
- Android 12+ system launch screen: light windowSplashScreenBackground=white, dark=`#FF111111`, icon=ic_launcher_foreground.

## Cross-cutting notes
Startup timing: Application.onCreate synchronously does initToast/initLog/initMMKV/initQQ, then appState.initialize() runs initializeState asynchronously on applicationScope (SupervisorJob + Dispatchers.Default). So isLoggedIn is briefly false at first frame / when the splash starts; the splash's 1.2s delay covers this in practice, but in theory the route interceptor (AppNavigator.resolveTargetRoute reads appState.isLoggedIn.value synchronously) may misjudge before restore finishes. ThemePreferenceManager is an object singleton whose StateFlow initial value reads MMKV lazily at first access (first access is in MainActivity setContent, after MMKV init); the MMKV read is wrapped in runCatching. AppNavigator is a @Singleton, attached to the BackStackNavigationController in AppNavHost's DisposableEffect and bound to NavigationService (global navigate functions); calling navigate while unbound throws "AppNavigator is not bound". MainActivityViewModel is an empty class with no behavior. Timber logs only in DEBUG.

## Platform risks
- MMKV → HarmonyOS needs @tencent/mmkv (ohpm) or Preferences; Preferences is async/needs a context, so the restore order in AbilityStage/EntryAbility.onCreate must be kept (storage ready → AppState restore → theme read) to avoid a light-mode flash on the first frame.
- Theme: ArkUI needs ColorMode set at the app level (applicationContext.setColorMode) for follow system/light/dark; the custom primary color has no Material ColorScheme equivalent and needs a global AppStorage/@StorageProp-driven color token system.
- Toaster (hjq) dark/light styles → promptAction.showToast is system-styled; custom success/error/warning toasts need a custom component (other cards cover this).
- QQ SDK (Tencent.createInstance/onActivityResult) has no equivalent HarmonyOS QQ login SDK, or needs the Tencent HarmonyOS SDK; likely downgraded/stubbed (to be decided with the auth card).
- Edge-to-edge → window.setWindowLayoutFullScreen(true) + get avoidArea for status-bar/navigation-bar insets, applied to every page.
- Navigation 3 back stack + popUpTo(allowPopToEmpty) → Navigation/NavPathStack's replacePath/removeByName needs a matching semantic for "navigate and close current"; the route login-wall interception must be built into the unified navigation wrapper layer.
- usesCleartextTraffic: HarmonyOS needs network_config cleartext allowed for HTTP, or requests fail.
