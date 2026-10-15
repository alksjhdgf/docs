# Data domain (network / repositories / AppState / Room / MMKV / util / result)

Route: domain card, no page
Sources: core/network/src/main/java/com/joker/coolmall/core/network/** ; core/data/src/main/java/com/joker/coolmall/core/data/** ; core/database/src/main/java/com/joker/coolmall/core/database/** ; core/datastore/src/main/java/com/joker/coolmall/core/datastore/** ; core/util/src/main/java/com/joker/coolmall/core/util/** ; core/result/src/main/java/com/joker/coolmall/result/** ; core/model/src/main/java/com/joker/coolmall/core/model/response/** ; build-logic/convention/src/main/kotlin/AndroidLibraryConventionPlugin.kt ; app/src/main/java/com/joker/coolmall/Application.kt

## Assertions
- DATA-A01 [backend] All business requests go to base URL `https://mall.dusksnow.top/app/` (same for the dev and prod flavors) plus a relative path, sent as JSON with unknown response fields ignored。锚点：build-logic/convention/src/main/kotlin/AndroidLibraryConventionPlugin.kt:78
- DATA-A02 [backend] Main API client connect/read/write timeouts are 10 seconds each, and it retries on connection failure。锚点：core/network/src/main/java/com/joker/coolmall/core/network/di/NetworkModule.kt:67
- DATA-A03 [backend] When a token is stored locally, every business request carries header `Authorization` set to the raw token value (no `Bearer` prefix). Without a token the header is omitted。锚点：core/network/src/main/java/com/joker/coolmall/core/network/interceptor/AuthInterceptor.kt:39
- DATA-A04 [backend] Every API response is parsed as an envelope { data, code, message }, and only `code == 1000` counts as success。锚点：core/model/src/main/java/com/joker/coolmall/core/model/response/NetworkResponse.kt:43
- DATA-A05 [backend] On a business failure (code != 1000), the caller gets the server message (fallback `未知错误`), and with showToast on an error toast appears. Exceptions/network errors fall back to `网络请求失败`. There is no 401/token-expiry interception: no auto logout or redirect to login。锚点：core/result/src/main/java/com/joker/coolmall/result/ResultHandler.kt:219
- DATA-A06 [backend] Paged requests default to page=1, size=10, sort=`desc`. Responses are { list, pagination{ total, size, page } }, and there is a next page if `size*page < total`。锚点：core/common/src/main/java/com/joker/coolmall/core/common/base/viewmodel/BaseNetWorkListViewModel.kt:143
- DATA-A07 [backend] Login credentials are stored as JSON (token/refreshToken/expire/refreshExpire/createdAt) under persistence key `auth_info`。锚点：core/datastore/src/main/java/com/joker/coolmall/core/datastore/datasource/auth/AuthStoreDataSourceImpl.kt:17
- DATA-A08 [backend] Logged in = local auth exists, token is non-empty and not expired (createdAt + expire seconds). An expired token counts as not logged in。锚点：core/datastore/src/main/java/com/joker/coolmall/core/datastore/datasource/auth/AuthStoreDataSourceImpl.kt:77
- DATA-A09 [backend] User info (User) is stored as JSON under persistence key `user_info`, and it is read only when logged in。锚点：core/datastore/src/main/java/com/joker/coolmall/core/datastore/datasource/userinfo/UserInfoStoreDataSourceImpl.kt:20
- DATA-A10 [on_device] On cold start the app restores login state and user info from local storage: after login, a restarted app is still logged in and the user's nickname/avatar show without logging in again。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:75
- DATA-A11 [backend] After a successful login, auth and user are written to local storage and memory together, login state becomes true, and then the person-info endpoint is called to refresh user info。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:97
- DATA-A12 [backend] Logging out removes only `auth_info` and `user_info` and resets in-memory login state/userId=0. It calls no server endpoint and does not clear the local cart, footprints, search history or remembered account。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:146
- DATA-A13 [backend] Opening a login-required page (Profile, address list/detail, order list/confirm/detail/pay/refund/comment/logistics, customer-service chat, coupons, feedback list/submit) while not logged in sends the user to the login page instead。锚点：core/navigation/src/main/java/com/joker/coolmall/navigation/RouteInterceptor.kt:29
- DATA-A14 [backend] The cart is purely local (database table `carts`, one row per goodsId, specs stored as a JSON list with count per spec). Adding the same product merges into its row, and the cart is not synced to the server。锚点：core/database/src/main/java/com/joker/coolmall/core/database/entity/CartEntity.kt:24
- DATA-A15 [backend] When changing a cart spec's quantity, the whole product row is deleted once every spec's quantity is ≤0. Deleting one spec deletes the row when no specs remain。锚点：core/database/src/main/java/com/joker/coolmall/core/database/datasource/cart/CartDataSource.kt:64
- DATA-A16 [backend] Viewing a product detail writes a footprint (goodsId as primary key, overwrite, refreshing viewTime). Footprints are sorted by viewTime descending, the "Me" page shows the latest 8, and they can be cleared all at once。锚点：core/database/src/main/java/com/joker/coolmall/core/database/dao/FootprintDao.kt:52
- DATA-A17 [backend] Search history is stored with the trimmed keyword as primary key (blank ignored, a repeated search refreshes its time). It is sorted by time descending and the search page shows the latest 10。锚点：core/data/src/main/java/com/joker/coolmall/core/data/repository/SearchHistoryRepository.kt:30
- DATA-A18 [backend] Checkout data passes through persistence keys `carts` (cart items selected for checkout) and `selectedGoodsList` (selected goods), both cleared after an order is placed. Theme uses `settings_theme_mode`/`settings_theme_color`, the onboarding flag uses `guide_shown`, and remembered account uses `saved_phone`/`saved_password`。锚点：feature/order/src/main/java/com/joker/coolmall/feature/order/viewmodel/OrderConfirmViewModel.kt:154
- DATA-A19 [backend] Image upload works in two steps: first `base/comm/upload` returns temporary credentials and a url, then a multipart POST to that url (fields key=`app/base/{uuid}_image.{ext}`, tmpSecretId, tmpSecretKey, sessionToken, file). On success the image address is url + "/" + key。锚点：core/network/src/main/java/com/joker/coolmall/core/network/service/impl/FileUploadServiceImpl.kt:67
- DATA-A20 [backend] Batch image upload goes one by one; if any image fails, the whole batch fails with an error message prefixed `批量上传失败`. The upload client uses 30-second timeouts and sends no Authorization header。锚点：core/network/src/main/java/com/joker/coolmall/core/network/service/impl/FileUploadServiceImpl.kt:128
- DATA-A21 [on_device] After an SMS code is fetched successfully, the system notification bar shows a high-priority notification titled `验证码` with content `您的验证码是` plus the code (channel `验证码通知`)。锚点：core/util/src/main/java/com/joker/coolmall/core/util/notification/NotificationUtil.kt:147
- DATA-A22 [on_device] SMS login/registration pages request notification permission first. Permanent denial toasts 通知权限被永久拒绝，请手动授予 (built from the `被永久拒绝，请手动授予` template), plain denial toasts 通知权限获取失败 (built from the `获取失败` template)。锚点：core/util/src/main/java/com/joker/coolmall/core/util/permission/PermissionUtils.kt:45
- DATA-A23 [backend] Input validation rules: phone matches 1[3-9] + 9 digits (11 digits), SMS code is 4 digits, image captcha is 4 letters/digits, password is at least 6 characters。锚点：core/util/src/main/java/com/joker/coolmall/core/util/validation/ValidationUtil.kt:19
- DATA-A24 [backend] Chat time formatting: today shows HH:mm, other days show yyyy-MM-dd HH:mm. A time divider appears only when two adjacent messages are more than 10 minutes apart。锚点：core/util/src/main/java/com/joker/coolmall/core/util/time/TimeUtils.kt:96
- DATA-A25 [backend] Local database name is `coolmall-database` (version 1), with the three tables `carts`, `footprints`, `search_history`. List queries are observable, and the UI refreshes automatically when data changes。锚点：core/database/src/main/java/com/joker/coolmall/core/database/AppDatabase.kt:57

## Components and interactions (copy the enumerations from source: buttons/menu items/tabs/dialog options, one row each, with anchors)
This is a domain card with no UI components. Exported capabilities for page cards to reference:
- AppState (global singleton): isLoggedIn / userId / auth / userInfo (StateFlow); initialize() / updateUserState(auth,user) / updateUserInfo(user) / updateAuth(auth) / logout() / shouldRefreshToken() / refreshUserInfo(). core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:36
- Application.onCreate order: Toast → Log → MMKV → QQ SDK → appState.initialize() (AppState depends on MMKV). app/src/main/java/com/joker/coolmall/Application.kt:29-36
- ResultHandler.handleResult / handleResultWithData: Loading→onLoading; Success with code==1000 and data!=null → onSuccessWithData (**data==null gives no callback and no error**); code!=1000 → onError + optional toast; finally → onFinally. core/result/src/main/java/com/joker/coolmall/result/ResultHandler.kt:36-222
- Flow.asResult(): emits Loading first, then Success; exceptions become Error. core/result/src/main/java/com/joker/coolmall/result/ResultExt.kt:15
- BaseNetWorkViewModel: Loading/Success/Error three states, retryRequest(), optional minimum loading time of 320ms, observeRefreshState(RefreshResultKey) triggers a re-request when a page returns with a result. core/common/src/main/java/com/joker/coolmall/core/common/base/viewmodel/BaseNetWorkViewModel.kt:28-188
- BaseNetWorkListViewModel: pageSize=10; LoadMoreState = PullToLoad/Loading/Success/Error/NoMore; load more triggers within the last 3 items (lastIndex >= total-3). core/common/src/main/java/com/joker/coolmall/core/common/base/viewmodel/BaseNetWorkListViewModel.kt:48,253
- ToastUtils: show / showSuccess / showError (Toaster library; white style in dark mode, black in light). core/util/src/main/java/com/joker/coolmall/core/util/toast/ToastUtils.kt:34
- PermissionUtils: requestStorage/Camera/Gallery/Notification/Audio/Location/CameraAndGallery/Custom + hasPermission + openPermissionSettings (XXPermissions). Permission display names: `存储权限` `相机权限` `相册权限` `通知权限` `录音权限` `位置权限` `相机和相册权限`; when no Activity is available it toasts `无法获取Activity实例，权限申请失败`. core/util/src/main/java/com/joker/coolmall/core/util/permission/PermissionUtils.kt:62-300
- NotificationUtil: channels `default_channel` (`默认通知`, IMPORTANCE_DEFAULT) and `verification_code_channel` (`验证码通知`, IMPORTANCE_HIGH); the notification ID is currentTimeMillis().toInt(). core/util/src/main/java/com/joker/coolmall/core/util/notification/NotificationUtil.kt:21-160
- PackageUtils: getCurrentAppName / getCurrentVersionName / getCurrentVersionCode (used by the About page). core/util/src/main/java/com/joker/coolmall/core/util/package/PackageUtils.kt
- LogUtils: Timber wrapper, init(app, isDebug). core/util/src/main/java/com/joker/coolmall/core/util/log/LogUtils.kt:28

## Data and APIs (endpoint paths, request/response fields, local storage keys)
Base URL: `https://mall.dusksnow.top/app/` (build-logic/convention/src/main/kotlin/AndroidLibraryConventionPlugin.kt:78,84). Envelope: `{ data: T?, code: Int(1000=OK), message: String? }`. Paging: request `{page=1,size=10,sort="desc"}` (@EncodeDefault, always sent), response `{ list: T[]?, pagination: { total, size, page } }`.
Header: `Authorization: <token>` (raw token). Chucker + HttpLoggingInterceptor(BODY) only in the dev flavor.

| Service | Method | Path | Request | Response data | Used by features (grep) |
|---|---|---|---|---|---|
| Auth | POST | user/login/wxApp | Map<String,String> | Auth | **unused** |
| Auth | POST | user/login/qq | QQLoginRequest | Auth | yes |
| Auth | POST | user/login/register | Map(phone,password,smsCode...) | Auth | yes |
| Auth | POST | user/login/smsCode | Map(phone,captchaId,code) | String (the code itself, shown via notification) | yes |
| Auth | POST | user/login/refreshToken | Map | Auth | **unused** (refresh never triggered) |
| Auth | POST | user/login/phone | Map | Auth | yes |
| Auth | POST | user/login/password | Map | Auth | yes |
| Auth | GET | user/login/captcha | - | Captcha | yes |
| Banner | POST | info/banner/list | Any | Any | **unused** |
| Common | POST | base/comm/upload | - | OssUpload{credentials{tmpSecretId,tmpSecretKey,sessionToken},requestId,expiration,startTime,expiredTime,url} | yes (upload) |
| Common | GET | base/comm/param?key= | key | String | yes |
| Common | GET | base/comm/eps | - | Any | **unused** |
| Common | POST | dict/info/data | DictDataRequest | DictDataResponse | yes |
| Coupon | POST | market/coupon/user/receive | ReceiveCouponRequest | String | yes |
| Coupon | POST | market/coupon/user/page | PageRequest | Page<Coupon> | yes |
| Coupon | POST | market/coupon/user/list | Any | List<Coupon> | **unused** (by method name) |
| CS | POST | cs/session/create | - | CsSession | yes |
| CS | GET | cs/session/detail | - | CsSession | **unused** |
| CS | POST | cs/msg/read | ReadMessageRequest | Boolean | yes |
| CS | POST | cs/msg/page | MessagePageRequest | Page<CsMsg> | yes |
| CS | GET | cs/msg/unreadCount | - | Int | **unused** |
| Feedback | POST | app/feedback/submit | FeedbackSubmitRequest | Boolean | yes |
| Feedback | POST | app/feedback/page | PageRequest | Page<Feedback> | yes |
| Goods | POST | goods/type/list | - | List<Category> | yes |
| Goods | POST | goods/spec/list | Map(goodsId) | List<GoodsSpec> | yes |
| Goods | POST | goods/search/keyword/list | - | List<GoodsSearchKeyword> | yes |
| Goods | POST | goods/info/page | GoodsSearchRequest | Page<Goods> | yes |
| Goods | GET | goods/info/info?id= | id(String) | Goods | **unused** |
| Goods | POST | goods/comment/submit | GoodsCommentSubmitRequest | Boolean | yes |
| Goods | POST | goods/comment/page | GoodsCommentPageRequest | Page<Comment> | yes |
| Order | POST | order/pay/alipayAppPay | Map(orderId) | String (Alipay orderStr) | yes |
| Order | POST | order/info/update | Any | Any | **unused** |
| Order | POST | order/info/refund | RefundOrderRequest | Boolean | yes |
| Order | POST | order/info/page | OrderPageRequest | Page<Order> | yes |
| Order | POST | order/info/create | CreateOrderRequest | Order | yes |
| Order | POST | order/info/cancel | CancelOrderRequest | Boolean | yes |
| Order | GET | order/info/userCount | - | OrderCount | yes |
| Order | GET | order/info/logistics?orderId= | Long | Logistics | yes |
| Order | GET | order/info/info?id= | Long | Order | yes |
| Order | GET | order/info/confirm?orderId= | Long | Boolean | yes |
| Page | GET | page/home | - | Home | yes |
| Page | GET | page/goodsDetail?goodsId= | Long | GoodsDetail | yes |
| Page | GET | page/confirmOrder | - | ConfirmOrder | yes |
| Contributor | POST | user/contributor/page | PageRequest | Page<UserContributor> | yes |
| UserInfo | POST | user/info/updatePerson | Map<String,Any> | Any | grep found no direct `.updatePersonInfo(` |
| UserInfo | POST | user/info/updatePassword | Map | Any | yes |
| UserInfo | POST | user/info/logoff | Map | Any | **unused** |
| UserInfo | POST | user/info/bindPhone | Map | Any | **unused** |
| UserInfo | GET | user/info/person | - | User | yes (AppState.refreshUserInfo) |
| Address | POST | user/address/update | Address | Unit | yes |
| Address | POST | user/address/page | PageRequest | Page<Address> | yes |
| Address | POST | user/address/list | - | List<Address> | **unused** |
| Address | POST | user/address/delete | Ids | Unit | yes |
| Address | POST | user/address/add | Address | Id | yes |
| Address | GET | user/address/info?id= | Long | Address | yes |
| Address | GET | user/address/default | - | Address? | **unused** (by method name) |

Service source paths: core/network/src/main/java/com/joker/coolmall/core/network/service/*.kt (each annotation line was taken from that file). "Unused" comes from a grep of `.method(` across feature/app/core/common/AppState, for reference only; page cards are the authority.

Third-party upload (Tencent COS, outside base URL): multipart POST `{OssUpload.url}`, fields `key=app/base/{uuid32}_image.{jpg|jpeg|png|webp}`, `tmpSecretId`, `tmpSecretKey`, `sessionToken`, `file`. The final URL is `{url}/app/base/...`. Extension is guessed from the uri string, default jpg; MIME comes from the ContentResolver, default image/jpeg. Errors: `无法读取文件内容`(400) / `上传失败: …` / `上传异常: …`(500) / `上传凭证无效`(400).

Auth model: `{ token, refreshToken, expire(s), refreshExpire(s), createdAt(ms, set locally) }`. isExpired = now >= createdAt+expire*1000. shouldRefresh = within 15 minutes of expiry and refresh token not expired (defined but **never called**). core/model/src/main/java/com/joker/coolmall/core/model/entity/Auth.kt:50-78

Local persistence (MMKV defaultMMKV, everything stored as String/JSON or Boolean):
| key | Content | Written / cleared by |
|---|---|---|
| `auth_info` | Auth JSON | AppState.updateUserState/updateAuth; cleared by logout |
| `user_info` | User JSON (supports partial updates via field merge) | updateUserState/updateUserInfo; cleared by logout |
| `carts` | List<Cart> JSON (cart items selected at checkout) | CartViewModel.kt:286 writes; OrderConfirmViewModel.kt:155 removes |
| `selectedGoodsList` | List<SelectedGoods> JSON | CartViewModel.kt:292 / GoodsDetailViewModel.kt:346 write; OrderConfirmViewModel.kt:154 removes |
| `saved_phone` | Last phone number logged in with | SmsLoginViewModel.kt:266 / AccountLoginViewModel.kt:156 |
| `saved_password` | **Plaintext password** | AccountLoginViewModel.kt:157 |
| `guide_shown` | Boolean, onboarding shown | GuideViewModel.kt:119; read in SplashViewModel.kt:48 |
| `settings_theme_mode` | Theme mode (default FOLLOW_SYSTEM) | core/common/.../ThemePreferenceManager.kt:23 |
| `settings_theme_color` | Theme color | core/common/.../ThemePreferenceManager.kt:28 |

Room `coolmall-database` v1 (exportSchema=false, no migrations):
- `carts`(goodsId PK, goodsName, goodsMainPic, spec TEXT=JSON List<CartGoodsSpec{id,goodsId,name,price(Int),stock,count,images?}>). DAO: insert/insertAll(REPLACE), update, delete, deleteByGoodsId, clear, getAll(Flow), getByGoodsId, count(Flow, counts **product rows**, not item quantity; no feature calls it).
- `footprints`(goodsId PK, goodsName, goodsSubTitle?, goodsMainPic, goodsPrice Int, goodsSold Int, viewTime ms). Ordered by viewTime DESC; getRecent(limit); clearAll; deleteByGoodsId.
- `search_history`(keyword PK, searchTime ms). Ordered by searchTime DESC; getRecent(limit); clearAll; deleteByKeyword.
Repositories run Room Flows on Dispatchers.IO; every network repository wraps the call as flow{emit(api())}.flowOn(IO).

## Cross-cutting notes (state machines/threading/startup timing; one paragraph max)
At startup, Application.onCreate initializes MMKV synchronously and then calls AppState.initialize(), which reads auth_info/user_info asynchronously on applicationScope (SupervisorJob+Default). So for a brief moment after startup isLoggedIn is still false, and the route interceptor (RouteInterceptor + AppNavigator.resolveTargetRoute reading isLoggedIn.value) relies on this StateFlow. AuthInterceptor uses runBlocking to read the token from MMKV for every request. There is no global 401 handling, no token refresh, and no logout broadcast. When a request fails with an expired token, the page only shows an error/toast. Login state is updated only on login success (updateUserState/updateAuth), logout, or when isLoggedIn() finds the token expired at cold start. The cart, footprints and search history are device-level data, not tied to an account, and survive logout or switching accounts. Network repositories and ResultHandler form one chain: Loading → (code==1000 && data!=null ? onData : code!=1000 ? onError+toast : silent).

## Platform risks
- MMKV → HarmonyOS needs @ohos.data.preferences (or the MMKV HarmonyOS build). Keep the key names (auth_info/user_info, etc.) and the JSON structures. preferences is asynchronous and needs flush(); AppState initialization must finish before the first route decision, or the login wall misjudges.
- Room → @ohos.data.relationalStore: create the three tables yourself, with spec stored as a JSON TEXT column. Rebuild the Flow auto-refresh by notifying after writes (an event bus or re-querying), otherwise the cart/footprint/history lists won't refresh after writes.
- Retrofit/OkHttp → @ohos.net.http or @kit.RemoteCommunicationKit: apply the 10s/30s timeouts yourself and inject the `Authorization` raw token yourself. There is no Chucker. The JSON default/ignore-unknown-field semantics (coerceInputValues) must be filled with defaults by hand.
- Upload: Android reads files via ContentResolver Uri; HarmonyOS needs photoAccessHelper/picker file:// or datashare URIs copied into the sandbox before a multipart upload (request.uploadFile or a hand-built multipart body). COS credential field names stay the same.
- Notifications: a HarmonyOS notification needs notificationManager.requestEnableNotification plus a NotificationRequest (SlotType.SOCIAL_COMMUNICATION or SERVICE_INFORMATION mapped to a high-priority channel). Notification permission is a user grant (not a manifest permission), so this is on_device.
- Toaster → promptAction.showToast (success/error styles must be built by hand). XXPermissions → abilityAccessCtrl.requestPermissionsFromUser; storage/gallery permissions on HarmonyOS are usually replaced by the Picker and need no permission request.
- Security: `saved_password` stores the password in plaintext; consider encryption during migration while keeping the behavior equivalent. Auth.createdAt depends on the local clock.
- Unused endpoints (wxApp/refreshToken/logoff/bindPhone/eps/updateOrder, etc.) should not count toward the ledger's must-implement denominator, or should be recorded only as declared but not wired up.
