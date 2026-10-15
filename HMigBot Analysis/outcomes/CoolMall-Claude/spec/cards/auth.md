# Auth domain (AuthRoutesLogin / AccountLogin / SmsLogin / Register / ResetPassword)

Route: AuthRoutes.Login, AuthRoutes.AccountLogin, AuthRoutes.SmsLogin, AuthRoutes.Register, AuthRoutes.ResetPassword (registered in feature/auth/src/main/java/com/joker/coolmall/feature/auth/navigation/AuthGraph.kt:17-32)
Sources: feature/auth/src/main/java/com/joker/coolmall/feature/auth/{view/LoginScreen.kt, view/AccountLoginScreen.kt, view/SmsLoginScreen.kt, view/RegisterScreen.kt, view/ResetPasswordScreen.kt, viewmodel/*.kt, component/*.kt}; feature/auth/src/main/res/values/strings.xml; core/util/src/main/java/com/joker/coolmall/core/util/validation/ValidationUtil.kt; core/network/src/main/java/com/joker/coolmall/core/network/service/AuthService.kt; core/data/src/main/java/com/joker/coolmall/core/data/repository/AuthRepository.kt; core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt; core/datastore/src/main/java/com/joker/coolmall/core/datastore/datasource/auth/AuthStoreDataSourceImpl.kt; core/common/src/main/java/com/joker/coolmall/core/common/manager/QQLoginManager.kt; core/navigation/src/main/java/com/joker/coolmall/navigation/auth/{AuthRoutes.kt,AuthNavigator.kt}

## Assertions
- AUTH-A01 [ui] On all five auth pages, top content (back button bar / title) avoids the status bar (edge-to-edge app; page uses AppScaffold with a back button that returns to the previous page)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/AnimatedAuthPage.kt:69
- AUTH-A02 [ui] The login method selection page shows the app logo, primary button `验证码登录` (goes to SMS login) and outlined button `账号密码登录` (goes to account login)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/LoginScreen.kt:187
- AUTH-A03 [ui] The login method selection page shows the `其他登录方式` heading and three third-party entries `微信`, `QQ`, `支付宝` (icon + name)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/LoginScreen.kt:212
- AUTH-A04 [ui] Tapping `微信` or `支付宝` on the selection page only shows the warning toast `三方登录暂时仅支持QQ登录` and does not log in。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/LoginViewModel.kt:132
- AUTH-A05 [on_device] Tapping `QQ` starts the QQ SDK authorization; on success it calls the QQ login API with accessToken+openId, and when the user cancels it shows the warning toast `登录取消`; when it fails it shows an error toast starting with `登录失败`; when launching throws it shows `启动QQ登录失败`。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/LoginViewModel.kt:38
- AUTH-A06 [backend] After QQ login succeeds, it shows the success toast `登录成功`, persists Auth, sets the logged-in state, refreshes user info, and pops back once (leaves the login selection page)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/LoginViewModel.kt:100
- AUTH-A07 [ui] The selection page, account login, and SMS login pages show the user agreement line `登录即代表您已阅读并同意` + `《用户协议》` + `和` + `《隐私政策》`; tapping either link opens the user agreement / privacy policy page respectively (register page prefix is `注册即代表您已阅读并同意`)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/UserAgreement.kt:79
- AUTH-A08 [ui] Account login, SMS login, and register pages show the two-line title `你好，` + `欢迎登录青商城` / `欢迎注册青商城`; the reset password page title is `重置密码`。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/AccountLoginScreen.kt:81
- AUTH-A09 [ui] The phone input field shows the `+86` prefix and the placeholder `请输入手机号`; the password field placeholder is `请输入密码` and it is masked by default; tapping the eye icon toggles show/hide password。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/PasswordInputField.kt:90
- AUTH-A10 [backend] Phone validation rule: exactly 11 digits matching ^1[3-9]\d{9}$; SMS code: exactly 4 digits; password: at least 6 characters (no other strength rules)。锚点：core/util/src/main/java/com/joker/coolmall/core/util/validation/ValidationUtil.kt:18
- AUTH-A11 [ui] The account login page `登录` button is disabled until the phone is valid and the password is at least 6 characters。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/AccountLoginViewModel.kt:58
- AUTH-A12 [backend] Account login submits phone+password to POST user/login/password; when the phone is invalid it shows the toast `请输入正确的手机号`, and when the password is invalid it shows `请输入正确的密码` without sending a request。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/AccountLoginViewModel.kt:87
- AUTH-A13 [backend] After account login succeeds, it saves the phone and password locally (MMKV keys saved_phone / saved_password), shows `登录成功`, persists Auth and sets the logged-in state, refreshes user info, then pops back twice (back past the selection page to the page before login)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/AccountLoginViewModel.kt:118
- AUTH-A14 [backend] When the account login page opens, it prefills the phone number and password saved from the last successful login。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/AccountLoginViewModel.kt:136
- AUTH-A15 [ui] The account login page bottom has `去注册` | `忘记密码`; tapping them goes to the register page / reset password page respectively。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/AccountLoginScreen.kt:157
- AUTH-A16 [ui] The SMS code input accepts digits only and at most 4 characters; the `获取验证码` text on its right is clickable only when the phone is valid (greyed and not clickable otherwise); there is no countdown after sending。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/VerificationCodeField.kt:84
- AUTH-A17 [on_device] On the SMS login and register pages, tapping `获取验证码` first requests notification permission; when denied it shows the toast `需要通知权限才能接收验证码` and does not continue。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/SmsLoginScreen.kt:66
- AUTH-A18 [backend] After permission is granted and the phone is valid, it calls GET user/login/captcha to fetch the image captcha (captchaId + base64 image) and then opens the image captcha dialog; when the phone is invalid it shows `请输入正确的手机号`。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/SmsLoginViewModel.kt:103
- AUTH-A19 [ui] The image captcha dialog (bottom sheet) has title `安全验证`, input placeholder `请输入图形验证码` (digits only, at most 4), the captcha image on the right, and button `完成验证` which is enabled only when 4 characters are entered。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/ImageCaptchaDialog.kt:115
- AUTH-A20 [ui] Tapping the captcha image fetches a new captcha; when the image is empty or fails to decode, it shows a `点击刷新` placeholder that refreshes when tapped。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/component/ImageCaptchaDialog.kt:138
- AUTH-A21 [backend] After tapping `完成验证`, the dialog closes and clears the image captcha input, and it calls POST user/login/smsCode with phone, captchaId, code (image captcha)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/SmsLoginViewModel.kt:176
- AUTH-A22 [on_device] After the SMS code API succeeds, the returned code is shown as a high-priority system notification titled `验证码` with content `您的验证码是: <code>` (the demo backend returns the code directly instead of sending a real SMS)。锚点：core/util/src/main/java/com/joker/coolmall/core/util/notification/NotificationUtil.kt:131
- AUTH-A23 [backend] The SMS login `登录` button is enabled only when the phone is valid and the code is 4 digits; tapping it calls POST user/login/phone (phone, smsCode); an invalid code shows the toast `请输入4位验证码`。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/SmsLoginViewModel.kt:204
- AUTH-A24 [backend] After SMS login succeeds, it saves the phone (saved_phone), shows `登录成功`, persists Auth/logged-in state, refreshes user info, and pops back twice; on next entry to SMS login the phone is prefilled。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/SmsLoginViewModel.kt:234
- AUTH-A25 [ui] The SMS login page bottom shows `短信不可用？` with `使用三方登录`; tapping the latter returns to the login method selection page。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/SmsLoginScreen.kt:234
- AUTH-A26 [ui] The register page has, in order: phone, code (with `获取验证码`), `请设置密码`, `请确认密码`, the register agreement line, and the `注册` button; the bottom has `已有账号？` `去登录` (tapping goes back)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/RegisterScreen.kt:224
- AUTH-A27 [backend] The `注册` button is enabled only when the phone is valid, the code is 4 digits, the password is at least 6 characters, and both passwords match; on submit it validates in order and shows `请输入正确的手机号`/`请输入4位验证码`/`请输入正确的密码`/`两次输入的密码不一致`, then calls POST user/login/register (phone, smsCode, password, confirmPassword)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/RegisterViewModel.kt:264
- AUTH-A28 [backend] After registration succeeds, it shows the success toast `注册成功`, persists Auth and sets the logged-in state, refreshes user info, and pops back once (back to the account login page)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/viewmodel/RegisterViewModel.kt:309
- AUTH-A29 [ui] The reset password page shows phone, code, `请设置新密码`, `请确认新密码`, and the hint `重置密码后，请使用新密码登录`; when both passwords are non-empty and differ it shows the red hint `两次输入的密码不一致`。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/ResetPasswordScreen.kt:205
- AUTH-A30 [ui] The reset password page `重置密码` button is always disabled, and its `获取验证码` makes no request (both are empty stub implementations in the source)。锚点：feature/auth/src/main/java/com/joker/coolmall/feature/auth/view/ResetPasswordScreen.kt:216
- AUTH-A31 [backend] All login/register success paths persist Auth{token, refreshToken, expire, refreshExpire, createdAt} as JSON under the local key auth_info and set isLoggedIn=true; logged-in means auth_info exists, token is non-empty, and it is not past createdAt+expire seconds。锚点：core/datastore/src/main/java/com/joker/coolmall/core/datastore/datasource/auth/AuthStoreDataSourceImpl.kt:28
- AUTH-A32 [backend] After login, every request carries the stored token in the Authorization header (raw token, no Bearer prefix)。锚点：core/network/src/main/java/com/joker/coolmall/core/network/interceptor/AuthInterceptor.kt:37
- AUTH-A33 [on_device] After a successful login, the app is still logged in after a cold restart (state restored from auth_info at startup)。锚点：core/data/src/main/java/com/joker/coolmall/core/data/state/AppState.kt:75
- AUTH-A34 [backend] When an auth API returns an unsuccessful business response or a network error, it shows the backend message (or `网络请求失败`) as an error toast and stays on the current page。锚点：core/result/src/main/java/com/joker/coolmall/result/ResultHandler.kt:215

## Components and interactions
| Page | Element | Behavior | Anchor |
|---|---|---|---|
| Login | Back (AppScaffold) | navigateBack | view/LoginScreen.kt:97 |
| Login | `验证码登录` (primary) | AuthNavigator.toSmsLogin | view/LoginScreen.kt:187 |
| Login | `账号密码登录` (OUTLINED) | AuthNavigator.toAccountLogin | view/LoginScreen.kt:195 |
| Login | `微信` | toast `三方登录暂时仅支持QQ登录` | view/LoginScreen.kt:214 |
| Login | `QQ` | QQLoginManager.startQQLogin(activity) | view/LoginScreen.kt:221 |
| Login | `支付宝` | toast `三方登录暂时仅支持QQ登录` | view/LoginScreen.kt:228 |
| Login | `《用户协议》`/`《隐私政策》` | CommonNavigator.toUserAgreement / toPrivacyPolicy | view/LoginScreen.kt:236 |
| AccountLogin | Phone field (+86, KeyboardType.Phone, no length limit) | updateAccount | view/AccountLoginScreen.kt:120 |
| AccountLogin | Password field + eye toggle | updatePassword | view/AccountLoginScreen.kt:131 |
| AccountLogin | `登录` (enabled=isLoginEnabled) | login() | view/AccountLoginScreen.kt:150 |
| AccountLogin | `去注册` / `|` / `忘记密码` | toRegister / toResetPassword | view/AccountLoginScreen.kt:157 |
| SmsLogin | Phone field | updatePhone | view/SmsLoginScreen.kt:194 |
| SmsLogin | Code field (digits ≤4) + `获取验证码` (clickable iff isPhoneValid) | permission → onSendCodeButtonClick | view/SmsLoginScreen.kt:205 |
| SmsLogin | `登录` (ROUND shape, enabled=isLoginEnabled) | login() | view/SmsLoginScreen.kt:226 |
| SmsLogin | `短信不可用？` + `使用三方登录` | navigateBack | view/SmsLoginScreen.kt:234 |
| SmsLogin/Register | ImageCaptchaDialog (BottomModal `安全验证`) | input digits ≤4, image click refresh, `完成验证` enabled iff len==4 → onImageCodeConfirm; dismiss → hide+clear | component/ImageCaptchaDialog.kt:54 |
| Register | Phone / code / `请设置密码` / `请确认密码` | update* | view/RegisterScreen.kt:224 |
| Register | `注册` (enabled=isRegisterEnabled) | register() | view/RegisterScreen.kt:278 |
| Register | `已有账号？` + `去登录` | navigateBack | view/RegisterScreen.kt:285 |
| ResetPassword | Phone / code (`获取验证码` always clickable, isPhoneValid default true) / `请设置新密码` / `请确认新密码` | update*; sendVerificationCode is a stub | view/ResetPasswordScreen.kt:151 |
| ResetPassword | Hint `重置密码后，请使用新密码登录`; mismatch hint `两次输入的密码不一致` | display | view/ResetPasswordScreen.kt:196 |
| ResetPassword | `重置密码` button | enabled=false hardcoded | view/ResetPasswordScreen.kt:216 |

Animations (not asserted): Login page logo slides down with a spring and the button area slides up (tween 500ms, delay 100); AnimatedAuthPage content slides up (400ms); played only once per page instance (rememberSaveable).

## Data and APIs
- AuthService (core/network/.../service/AuthService.kt), all wrapped in NetworkResponse<T> (isSucceeded/data/message):
  - POST `user/login/password` body {phone, password} → Auth (:85)
  - POST `user/login/phone` body {phone, smsCode} → Auth (:75)
  - POST `user/login/smsCode` body {phone, captchaId, code} → String (the SMS code itself, shown via a notification) (:55)
  - GET `user/login/captcha` → Captcha{data: base64 image (may have a `data:...;base64,` prefix), captchaId} (:94)
  - POST `user/login/register` body {phone, smsCode, password, confirmPassword} → Auth (:45)
  - POST `user/login/qq` body QQLoginRequest{accessToken, openId} → Auth (:35)
  - Defined but not called from feature/auth: POST `user/login/wxApp` (:25), POST `user/login/refreshToken` (:65).
- Auth model (core/model/.../entity/Auth.kt): token, refreshToken, expire(s), refreshExpire(s), createdAt(ms, default = local time at deserialization/creation); isExpired, isRefreshTokenExpired, shouldRefresh (refresh 15 minutes early).
- Local storage (MMKV): `auth_info` (Auth JSON, AuthStoreDataSourceImpl.kt:17); `saved_phone` (AccountLogin + SmsLogin share the same key); `saved_password` (AccountLogin, **plaintext password**) (AccountLoginViewModel.kt:34-35).
- AppState.updateAuth(auth): saveAuth + _auth + _isLoggedIn=true (AppState.kt:130); refreshUserInfo() calls userInfoRepository.getPersonInfo() and saves user info (AppState.kt:173).
- Header: `Authorization: <token>` (AuthInterceptor.kt:39).
- QQ: QQLoginManager singleton, Tencent SDK init(appId=AppConfig.QQ_APP_ID) in Application.kt:77; result delivered via MainActivity.onActivityResult → Tencent.onActivityResultData (MainActivity.kt:85); loginResult StateFlow Success/Error/Cancel.
- Notification channel `verification_code_channel` ("验证码通知", IMPORTANCE_HIGH) (NotificationUtil.kt:22,131).
- Login entry: RouteInterceptor.getLoginRoute() = AuthRoutes.Login (core/navigation/.../RouteInterceptor.kt:64) for login-required routes; HomeViewModel.kt:206 and GoodsDetailViewModel.kt:268 navigate directly to AuthRoutes.Login.
- i18n: feature/auth/src/main/res/values-en/strings.xml mirrors all strings (English).

## Cross-cutting notes
Login flow is a two-level stack: Login (selection) → AccountLogin/SmsLogin; on success Account/SMS login call navigateBack() twice so the user lands on the page before Login, whereas QQ login (from Login) and Register (from AccountLogin) pop only once — Register therefore lands back on AccountLogin while already logged in. All network calls go through ResultHandler.handleResultWithData (error toast automatic; no loading indicator in auth pages, isLoadingCaptcha is collected but not rendered). The captcha fetch inside onSendCodeButtonClick is fire-and-forget, so the dialog opens immediately and the image shows `点击刷新` until data arrives. The QQ result collector is launched each time QQ is tapped (multiple taps → multiple collectors). The QQ Error toast uses R.string.login_failed whose text has a `%s` placeholder but no argument is passed. There is no SMS countdown/resend timer anywhere.

## Platform risks
- QQ login depends on the Tencent Android SDK + onActivityResult; HarmonyOS needs the QQ HarmonyOS SDK (or a stub that keeps the button + cancel/fail toasts); real authorization only verifiable on a device.
- Notification permission (POST_NOTIFICATIONS via XXPermissions) → HarmonyOS notificationManager.requestEnableNotification; verification code delivered as a local notification (notificationManager.publish, SlotType SOCIAL_COMMUNICATION / high importance).
- Captcha image is base64 (possibly with data URI prefix) → ArkTS Image can render a `data:image/...;base64,` string directly; keep the strip/fallback `点击刷新` behavior.
- MMKV → @ohos.data.preferences (or MMKV-HarmonyOS); keys `auth_info`, `saved_phone`, `saved_password` must be kept; storing the plaintext password is a source behavior (consider keeping it for parity; note it as a security smell).
- Navigation: double navigateBack semantics must map to NavPathStack.pop() twice / popToName; edge-to-edge requires avoiding the status bar on HarmonyOS (expandSafeArea / systemBar avoidance).
- Keyboard types (Phone/Number/Password) → TextInput type InputType.PhoneNumber/Number/Password; the code field filter (digits, ≤4) must be done in onChange, the image captcha input also digits-only although ValidationUtil.isValidImageCode allows letters (unused).
