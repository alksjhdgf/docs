# Common pages (Settings / About / Web / UserAgreement / PrivacyPolicy / Contributors)

Route: CommonRoutes.Settings, CommonRoutes.About, CommonRoutes.Web(url, title?), CommonRoutes.UserAgreement, CommonRoutes.PrivacyPolicy, CommonRoutes.Contributors
Sources: feature/common/src/main/java/com/joker/coolmall/feature/common/{navigation/CommonGraph.kt, view/SettingsScreen.kt, view/AboutScreen.kt, view/WebScreen.kt, view/UserAgreementScreen.kt, view/PrivacyPolicyScreen.kt, view/ContributorsScreen.kt, viewmodel/*.kt, component/ThemeModeModal.kt, component/ThemeColorModal.kt, component/DependencyModal.kt, component/UserContributorCard.kt, data/DependencyDataSource.kt, skeleton/DocumentSkeleton.kt}; core/common/.../manager/ThemePreferenceManager.kt; core/common/.../config/ThemePreference.kt; core/common/.../config/ThemeColorOption.kt; core/navigation/.../common/CommonRoutes.kt; core/network/.../service/CommonService.kt; core/network/.../service/UserContributorService.kt; feature/common/src/main/res/values/strings.xml

## Assertions
- COM-A01 [ui] Settings, About, Web, User Agreement, Privacy Policy and Contributors pages: top content avoids the status bar (title bar / About toolbar is not covered by the status bar)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:102
- COM-A02 [ui] The settings page title is `设置` (large title bar with a back button) and shows groups top to bottom: `账号与安全` card, `外观与语言`, `隐私与协议`, `其他`, `通用`。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:156
- COM-A03 [ui] Tapping `账号与安全` on the settings page navigates to the user profile page (UserRoutes Profile)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:160
- COM-A04 [ui] The `夜间模式` row on the settings page shows the current mode text on the right (`跟随系统`/`浅色模式`/`深色模式`); tapping it opens a bottom sheet titled `夜间模式` with three radio options。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:148
- COM-A05 [backend] Choosing a theme mode in the bottom sheet immediately switches the whole app between light and dark (follow system / force light / force dark) and closes the sheet; reselecting the current mode changes nothing。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/SettingsViewModel.kt:67
- COM-A06 [ui] The `主题颜色` row on the settings page shows a dot in the current theme color on the right; tapping it opens a bottom sheet titled `主题颜色` listing 5 options (`木槿紫`#465CFF, `幻彩紫`#6831FF, `清爽绿`#09BE4F, `暖日橙`#FFB703, `能量红`#FF2B2B), each with a color dot and a radio button。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/component/ThemeColorModal.kt:41
- COM-A07 [backend] Choosing a theme color immediately replaces the app-wide primary color with that color and closes the sheet。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/SettingsViewModel.kt:96
- COM-A08 [on_device] The chosen theme mode and theme color are persisted (KV keys `settings_theme_mode`/`settings_theme_color`, values follow_system/light/dark and default/purple/green/orange/red) and still apply after a cold restart; a missing or invalid value falls back to follow system / `木槿紫`。锚点：core/common/src/main/java/com/joker/coolmall/core/common/manager/ThemePreferenceManager.kt:60
- COM-A09 [ui] The `语言切换` row on the settings page shows a fixed `中文` on the right, and tapping it does nothing (no language switching)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:197
- COM-A10 [ui] In the settings `隐私与协议` group, `隐私政策` opens the privacy policy page and `用户协议` opens the user agreement page。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:217
- COM-A11 [ui] The settings `其他` group has a `不展示启动页` toggle (description `打开后进入应用将跳过启动页`, off by default, only page-local state, not persisted or wired to the launch flow) and `应用引导`, which opens the guide page with fromSettings=true。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:238
- COM-A12 [ui] In the settings `通用` group, `清除缓存` shows a fixed `13.24MB` on the right and is not tappable, `意见反馈` opens the feedback list page, and `关于应用` opens the About page。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/SettingsScreen.kt:269
- COM-A13 [ui] The About page header shows the app logo, the app name, and `Version <versionName>`; the info card lists `应用名称`, `版本号`, and `版本代码` (read from the package info)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:382
- COM-A14 [ui] The About page has a dynamic aurora background (dark/light variants, one light source in the theme color); as the page scrolls, the header fades and shrinks, and the `关于我们` title bar fades in; there is a back button。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:168
- COM-A15 [ui] The About `开发者` group shows the avatar, `Joker.X`, and `joker.x.dev@gmail.com`; tapping it opens the Web page (https://github.com/Joker-x-dev, title Joker.X); the `贡献者` row opens the contributors page。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:487
- COM-A16 [ui] About link rows each open the Web page with a fixed URL/title: `GitHub`, `Gitee`, `API 文档`(https://coolmall.apifox.cn), `Demo 下载`(pgyer), `图标来源`(github.com/tuniaoTech), `GitHub 讨论区`, `翻译`, `支持`, `帮助`, `开源许可`(LICENSE)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:516
- COM-A17 [ui] Tapping `QQ 交流群` and `微信交流群` on the About page does nothing (empty handler)。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:613
- COM-A18 [ui] Under About `其他`, `用户协议`/`隐私政策` open the matching pages; the bottom shows `© 2025 Joker.X & CoolMallKotlin Contributors`。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/AboutScreen.kt:704
- COM-A19 [ui] Tapping `引用` on the About page opens the `引用致谢` bottom sheet, which lists 21 local third-party dependencies (name, description up to 2 lines, category tag); tapping an item with a URL opens the Web page with the dependency name as title and closes the sheet。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/AboutViewModel.kt:58
- COM-A20 [ui] The Web page title bar first shows the route's title (default `网页` when none is given) and is then replaced by the page's real title; a linear progress bar shows below the top while loading progress is under 100。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/WebViewModel.kt:66
- COM-A21 [ui] The Web page's top-right `更多选项` menu holds `刷新` (reload the current page) and `用浏览器打开` (open the route's initial URL in the system browser); the menu closes after either action。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/WebScreen.kt:168
- COM-A22 [on_device] Inside the Web page, http/https links load in place, while non-http schemes (tel:/mailto:/geo:) are handed to system apps; JavaScript and DOM Storage are enabled。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/WebScreen.kt:243
- COM-A23 [backend] On entry, the user agreement page requests GET base/comm/param?key=userAgreement and renders the returned HTML string in a WebView (JS disabled); the title is `用户协议`。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/UserAgreementViewModel.kt:36
- COM-A24 [backend] On entry, the privacy policy page requests GET base/comm/param?key=privacyPolicy and renders the returned HTML; the title is `隐私政策`。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/PrivacyPolicyViewModel.kt:36
- COM-A25 [ui] The agreement/privacy pages show a document skeleton while loading (enforced minimum loading time) and a common error state with retry on failure that re-requests。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/UserAgreementScreen.kt:65
- COM-A26 [backend] The contributors page (title `贡献者`) loads by page via POST user/contributor/page {page,size=10}, supporting pull-to-refresh and scroll-to-load-more, plus loading/empty/error-retry states。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/viewmodel/ContributorsViewModel.kt:33
- COM-A27 [ui] A contributor card shows the avatar, nickname, signature (when non-empty), and a tag row (when non-empty); tapping a card whose websiteUrl is non-empty opens the Web page with the nickname as title, otherwise nothing happens。锚点：feature/common/src/main/java/com/joker/coolmall/feature/common/view/ContributorsScreen.kt:131

## Components and interactions
| Page | Element | Behavior | Anchor |
|---|---|---|---|
| Settings | `账号与安全` | UserNavigator.toProfile | SettingsScreen.kt:160 |
| Settings | `夜间模式` (trailing current mode) | open ThemeModeModal | SettingsScreen.kt:171 |
| Settings | `主题颜色` (trailing color dot) | open ThemeColorModal | SettingsScreen.kt:181 |
| Settings | `语言切换` (trailing `中文`) | no onClick | SettingsScreen.kt:197 |
| Settings | `隐私政策` | CommonNavigator.toPrivacyPolicy | SettingsScreen.kt:213 |
| Settings | `用户协议` | CommonNavigator.toUserAgreement | SettingsScreen.kt:221 |
| Settings | `不展示启动页` + Switch (desc `打开后进入应用将跳过启动页`) | local remember state only, not persisted | SettingsScreen.kt:237 |
| Settings | `应用引导` | LaunchNavigator.toGuide(fromSettings=true) | SettingsScreen.kt:253 |
| Settings | `清除缓存` (trailing `13.24MB` hardcoded) | no onClick | SettingsScreen.kt:269 |
| Settings | `意见反馈` | FeedbackNavigator.toList | SettingsScreen.kt:277 |
| Settings | `关于应用` | CommonNavigator.toAbout | SettingsScreen.kt:285 |
| ThemeModeModal | `跟随系统` / `浅色模式` / `深色模式` (RadioButton; row or radio click selects) | updateThemeMode + dismiss | ThemeModeModal.kt:35 |
| ThemeColorModal | `木槿紫` / `幻彩紫` / `清爽绿` / `暖日橙` / `能量红` (ColorDot + Radio) | updateThemeColor + dismiss | ThemeColorModal.kt:91 |
| About | toolbar back / `关于我们` title (alpha = scroll fraction, threshold 220dp) | navigateBack | AboutScreen.kt:763 |
| About | `应用名称` / `版本号` / `版本代码` (not clickable) | PackageUtils | AboutScreen.kt:424 |
| About | Developer `Joker.X` / `joker.x.dev@gmail.com` | toWeb(https://github.com/Joker-x-dev,"Joker.X") | AboutScreen.kt:488 |
| About | `贡献者` | toContributors | AboutScreen.kt:498 |
| About | `GitHub` (desc URL) | toWeb(https://github.com/Joker-x-dev/CoolMallKotlin,"GitHub") | AboutScreen.kt:517 |
| About | `Gitee` | toWeb(https://gitee.com/Joker-x-dev/CoolMallKotlin,"Gitee") | AboutScreen.kt:532 |
| About | `API 文档` (`查看项目后端接口的详细定义`) | toWeb(https://coolmall.apifox.cn,"API 文档") | AboutScreen.kt:554 |
| About | `Demo 下载` (`不定时更新，可能不会同步最新代码变更`) | toWeb(https://www.pgyer.com/CoolMallKotlinProdRelease) | AboutScreen.kt:566 |
| About | `图标来源` (`项目使用的图标库来自图鸟 Icon`) | toWeb(https://github.com/tuniaoTech) | AboutScreen.kt:581 |
| About | `GitHub 讨论区` | toWeb(.../CoolMallKotlin/discussions) | AboutScreen.kt:600 |
| About | `QQ 交流群`, `微信交流群` | empty onClick | AboutScreen.kt:613, 623 |
| About | `翻译` / `支持` / `帮助` | toWeb(.../issues, ".../CoolMallKotlin", .../issues) | AboutScreen.kt:642, 657, 672 |
| About | `引用` (`项目中使用的第三方库和资源致谢`) | open DependencyModal | AboutScreen.kt:693 |
| About | `用户协议` / `隐私政策` | toUserAgreement / toPrivacyPolicy | AboutScreen.kt:705, 716 |
| About | `开源许可` | toWeb(.../blob/main/LICENSE,"开源许可") | AboutScreen.kt:727 |
| DependencyModal | title `引用致谢`, LazyColumn of DependencyCard (name / desc maxLines 2 / category Tag) | click -> toWeb if url non-empty, then close | DependencyModal.kt:58 |
| Web | `更多选项` icon -> DropdownMenu `刷新` / `用浏览器打开` | reload / Intent.ACTION_VIEW(initial url) | WebScreen.kt:160 |
| UserAgreement / PrivacyPolicy | BaseNetWorkView + DocumentLoadingSkeleton + retry | getParam | UserAgreementScreen.kt:65 / PrivacyPolicyScreen.kt:63 |
| Contributors | RefreshLayout (refresh + load more), UserContributorCard | toWeb(websiteUrl, nickName) if non-blank | ContributorsScreen.kt:119 |

Section headers (TitleWithLine): Settings `外观与语言`/`隐私与协议`/`其他`/`通用`; About `开发者`/`项目地址`/`相关资源`/`讨论`/`支持与帮助`/`其他`.

Dependency list (DependencyDataSource.kt, 21 entries, static): AndroidX Core KTX, AndroidX Lifecycle Runtime KTX, AndroidX Activity Compose, Jetpack Compose BOM, Material3, Navigation Compose, OkHttp, Retrofit, Chucker, Kotlinx Serialization JSON, Hilt, Coil Compose, Timber, MMKV, Room, Lottie Compose, LeakCanary, Toaster, XXPermissions, 支付宝 SDK, AndroidX Core Splashscreen. Fields: name, version, description, websiteUrl, category (e.g. `Android 核心`, `UI 框架`, `导航`, `依赖注入`, `图片加载`, `动画`, `支付`, `启动页`...). The HM version may keep the list as-is (faithful) or swap in HM equivalents; this is a design decision, but the UI must show the list, which is non-empty.

## Data and APIs
- Routes: `CommonRoutes.About`, `Web(url: String, title: String? = null)`, `Settings`, `UserAgreement`, `PrivacyPolicy`, `Contributors` (core/navigation/.../common/CommonRoutes.kt:18-63). CommonNavigator.toWeb(url,title?), toAbout, toSettings, toUserAgreement, toPrivacyPolicy, toContributors.
- Entry points from other modules: MeScreen.kt:565 (toAbout), MeScreen.kt:577 (toSettings), HomeScreen.kt:519 (toAbout).
- GET `base/comm/param?key=<userAgreement|privacyPolicy>` -> NetworkResponse<String> (HTML) (core/network/.../service/CommonService.kt:35).
- POST `user/contributor/page` body PageRequest{page,size} -> NetworkPageData<UserContributor> (UserContributorService.kt:24); pageSize=10 (BaseNetWorkListViewModel.kt:48).
- UserContributor: id: Long, avatarUrl: String, nickName: String, websiteUrl: String?, signature: String?, tags: List<String>?, sortNum: Int, createTime (core/model/.../entity/UserContributor.kt).
- Local storage (MMKV): `settings_theme_mode` (follow_system|light|dark, default follow_system); `settings_theme_color` (default|purple|green|orange|red, default "default"). ThemePreferenceManager is a global singleton StateFlow; MainActivity.kt:45-58 maps it to AppTheme(darkTheme, themeColor=primary).
- UserAgreement/PrivacyPolicy VMs set enableMinLoadingTime = true.
- Strings also exist in English (feature/common/src/main/res/values-en/strings.xml), but the language-switch UI is a placeholder.

## Cross-cutting notes
Theme is global state: ThemePreferenceManager (object) reads MMKV once at init, exposes StateFlows; MainActivity collects them at the root, so a change re-themes every page instantly (FOLLOW_SYSTEM tracks system dark mode live). Settings VM only toggles the modal flags and delegates. The Web VM is assisted-injected with the route key; openInBrowser uses the route's initial URL, not the currently navigated URL; refresh is a one-shot flag consumed by LaunchedEffect → webView.reload(). About's appearance animations (100ms delay, entrance fade/slide, 15s infinite aurora with blur 150dp) are visual only. The "hide splash" switch, clear cache, language, and QQ/WeChat groups are non-functional placeholders in the source: migrate them as placeholders, do not invent behavior.

## Platform risks
- Web: Android WebView → ArkWeb `Web` component (@ohos.web.webview). Need: onTitleReceive, onProgressChange, onLoadIntercept to split http(s) and other schemes (openLink/startAbility for tel:/mailto:), controller.refresh(), javaScriptAccess/domStorageAccess. "Open in browser" → context.startAbility with action ohos.want.action.viewData + uri. Needs the ohos.permission.INTERNET permission.
- Agreement/privacy HTML: loadDataWithBaseURL → ArkWeb loadData(html, 'text/html', 'UTF-8'); JS disabled.
- Theme: dark mode needs ApplicationContext.setColorMode (COLOR_MODE_NOT_SET/LIGHT/DARK) plus a global AppStorage primary color; ArkUI has no Material dynamic color scheme, so the primary color must flow through a custom theme state. Persist via Preferences/MMKV-for-HM.
- Blur 150dp aurora + infinite animation: performance risk with ArkUI blur/radialGradient; visual only, can be simplified.
- PackageUtils app name/versionName/versionCode → bundleManager.getBundleInfoForSelf.
- Bottom sheets (BottomModal) → bindSheet; DropdownMenu → bindMenu/Menu.
- Hardcoded cache size `13.24MB` and language `中文` must be kept as literals to stay faithful.
