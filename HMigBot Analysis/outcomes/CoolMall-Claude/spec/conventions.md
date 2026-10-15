# conventions.md — CoolMallHM implementation conventions (required reading for every implementation unit)

> Source is the absolute source of truth: input/CoolMallKotlin (Kotlin + Compose + Hilt + Retrofit + Room + MMKV, multi-module)
> Target: output/CoolMallHM (single entry module, Stage model, API 24 / HarmonyOS 6.1.1, ArkTS + ArkUI state management V2)
> The work card already embeds these conventions and your unit's SECTION — follow the card; for more background read spec/cards/*.md and the source.
> Read/write only input/CoolMallKotlin (read-only), output/CoolMallHM, and .deveco/. Do not modify spec/ledger directly.

## A. ArkTS hard rules (violation = compile failure)
- No any/unknown; no destructuring; object literals need a declared type (class/interface) everywhere, and nested literals need one too; no computed property names `{[k]: v}`.
- No index signatures; for Record use quoted keys or a Map; async functions explicitly return `Promise<T>`; no function expressions or nested function declarations (use arrow functions/methods).
- No delete/in/for-in/object spread/@ts-ignore; regex via `new RegExp()`; `as T` is allowed, `as const` is not.
- `throw` only takes Error and subclasses; catch parameters are untyped, then narrow with `as`/instanceof.
- No `Object.assign` to build instances, no `{} as T` (use `T | null`); margin/padding have no vertical/horizontal keys.
- Direct children of List/Grid can only be ListItem/GridItem (separators via `.divider()`).
- **Import discipline**: ArkUI components/enums/decorators/NavPathStack/Scroller etc. are used bare with **no import**; real exports used as values must be imported: `AppStorageV2/PersistenceV2/ComponentContent/LengthMetrics/curves/window/promptAction` come from `@kit.ArkUI`, `http` from `@kit.NetworkKit`, `preferences/relationalStore` from `@kit.ArkData`, `util/url/JSON` from `@kit.ArkTS`, `common/abilityAccessCtrl` from `@kit.AbilityKit`, `webview` from `@kit.ArkWeb`, `photoAccessHelper` from `@kit.MediaLibraryKit`, `BusinessError` from `@kit.BasicServicesKit`.
- **V2 throughout**: `@ComponentV2` + `@Local/@Param/@Once/@Event/@Provider()/@Consumer()/@Monitor/@Computed`, data classes `@ObservedV2` + `@Trace`; no V1 decorators (@State/@Prop/@Link/@Observed/@Component). @Param needs a default; @Event needs a default empty implementation.
- **Field name clashes**: component @Local/@Param names must not clash with built-in members (id/title/content/width/height/position/enabled/onClick/visibility/opacity…) → add a domain prefix.
- **Route parameters**: params are **classes**; `new` one, assign fields one by one, pass the instance; read with `ctx.pathInfo.param as Object`, then narrow with `instanceof`. Pages without params use `NoParam`.
- Dialogs: `this.getUIContext().getPromptAction().openCustomDialog(ComponentContent)` or `bindSheet`; **no @CustomDialog/CustomDialogController**; toasts use `this.getUIContext().getPromptAction().showToast`.
- After a custom component call `Comp(){...}`, do not chain common attributes; wrap it in a built-in container and put the attributes on the container.

## A2. Runtime hard rules
0. Pass builder parameters with `@Builder` + `@BuilderParam`, using the arrow-wrapped form `xxx: (): void => { this.xxxBuilder() }`; plain lambdas that construct components crash at runtime.
1. Dialog content goes through `ComponentContent` + `wrapBuilder`; when content changes, call `update()`. Dialogs that push a new page use `levelMode: LevelMode.EMBEDDED`.
2. No throw or side effects inside `build()`/`@Builder`; give missing values explicit fallback rendering.
3. When first-screen async data comes back in `aboutToAppear`, it must be written to `@Local`/`@Trace` state.
4. Timers/subscriptions are cleaned up symmetrically in `aboutToDisappear`; callbacks after the page exits must not touch state.
5. Overlays: geometry = the area it covers in the source; touch blocking via `hitTestBehavior` (pure display layers use Transparent).
6. Scroll containers do not size to content: horizontal lists need an explicit `.height()`; same-direction nested scrolling uses `.nestedScroll(SELF_FIRST)` with bounded outer size.
7. `@Builder` value parameters are a snapshot; for dynamic state read `this.` directly inside the builder.
8. `@ObservedV2` instances must not be passed straight to `JSON.stringify`: write paired `toJson()/fromJson()` methods.
9. ForEach/LazyForEach keys include every mutable field that affects display (`id + '_' + count + '_' + checked`), or modify in place with @Trace.
10. Tabs bottom bar: `Column(){ Tabs().layoutWeight(1) }`; Text wraps by default, so do not add maxLines blindly.
11. `@Local` cannot be initialized from outside; parent→child uses `@Param`, and child changes are passed back via `@Event`.
12. `@ObservedV2` must not go into V1 AppStorage; global state uses `AppStorageV2.connect` or an exported `@ObservedV2` singleton.
13. `@Monitor` must list every linked field.
14. After the app goes to the background, timers slow down: payment/countdown flows must re-check in onPageShow/onForeground.
15. **Image callbacks must not write state synchronously**: use `.alt()` for loading placeholders; if state is truly needed, accept only `loadingStatus === 1` or defer the write with `setTimeout(…,0)` (verified on coolmall: cachedCount pre-build + shared images → cppcrash).
16. **Wrapper components must not bind `.onClick` unconditionally**: when not clickable, don't bind (`if` branch) or use `.hitTestBehavior(clickable ? HitTestMode.Default : HitTestMode.None)`; otherwise they swallow parent row/card clicks (verified on coolmall: "dead clicks inside scroll containers" across the whole app).

## B. Project structure and naming (all under entry/src/main/ets)
- `common/Router.ets` (AppRouter/Routes/NoParam) is **frozen**. Business code navigates only via `core/navigation/AppNavigator` (with the login wall built in: `navigate(Routes.X, param, onResult?)`/`back()`/`backWithRefresh()`/`replace()`/`toMain()`); route parameter classes all live in `core/navigation/RouteParams.ets`. No direct pushPathByName.
- Colors: neutral colors use resource tokens `$r('app.color.bg_page|bg_card|surface|text_primary|text_secondary|text_tertiary|divider|danger')` (light and dark versions); the primary color is dynamic: `ThemeManager.instance.primary` (string, @Trace). Do not hard-code `#465CFF`.
- `pages/<Route>Page.ets`: the deliverable file for a registered page (keep the `@Builder export function <Route>PageBuilder()` entry and `NavDestination` root as-is). Do not create a separate screens/ directory.
- `core/model/` data models (one file per domain, names match source); `core/network/` HttpClient + `*Service.ets`; `core/data/` Repository + global state (UserState/CartState…); `core/storage/` Preferences (MMKV equivalent)/RDB; `core/designsystem/` theme tokens + ThemeManager; `core/ui/` shared components (single implementation, others only import); `core/util/` utilities (toast/time/validation/log).
- `feature/<domain>/` the domain's ViewModel (`@ObservedV2` class) and private components. File name = class name.ets (PascalCase); source class → target class with the same name.
- Single files ≤ 600 lines; split longer ones the way the source splits them.

## C. Data layer
- Model field names/types/semantics match the source (`Long`→number, nullable → `T | null`); JSON field names follow the source's `@SerialName`; outbound JSON omits fields equal to their default values (kotlinx `encodeDefaults=false`).
- MMKV/DataStore → `@kit.ArkData` preferences (one file, `coolmall`); **keys are copied verbatim from the source**; after `putSync`, call `flush()`. Room → relationalStore (table/column names verbatim).
- Global state (login state/user info/cart count) is an `@ObservedV2` singleton in `core/data/state/`; pages only read it and modify it through the Repository.

## E. UI
- Pages = `@ComponentV2` struct; UI units must read `spec/ui-layout-semantics.md` and pass its §5 self-check gate.
- User-visible text uses `$r('app.string.*')` (already converted, includes the en locale); wrapper component text parameters are typed `ResourceStr`.
- If a page's required parameter is missing, do not throw and do not auto-pop: stay on the page and show an empty state.
- Icons: prefer the converted `$r('app.media.ic_*')` (75 converted from the source); otherwise use the verified SymbolGlyph list in ui-alignment/README; do not invent resource names.
- Colors go through `core/designsystem` theme tokens (follows light/dark; resources/dark already exists); fixed colors use `$r('app.color.*')`.
- Edge-to-edge layering: the window layer (owned by fnd-app-init) does `setWindowLayoutFullScreen(true)` + `avoidAreaChange` and writes the status bar/navigation bar heights into AppStorageV2 `AvoidArea { top, bottom }` (vp); pages **only read** them and pad manually, and must not call expandSafeArea themselves.
- Skeleton screens/empty states/error retry/pull-to-refresh (`Refresh`)/load-more follow the source, using the shared core/ui components.
- M3 elevation/tonal/shape animations are approximated with surface color levels (recorded as one batch degradation); do not file per-component degradations.

## F. Networking
- HttpClient (`core/network/HttpClient.ets`, `@kit.NetworkKit` http): BASE_URL `https://mall.dusksnow.top/app/`, POST/GET JSON, header `Authorization: <token>` (behavior per the source interceptor), unified `NetworkResponse<T>{code,message,data}` unwrapping; 401 → clear login state and go to the login page (per the source).
- module.json5 declares `ohos.permission.INTERNET` (and GET_NETWORK_INFO); other permissions are added by their owning slices as needed.

## H. Verification duties (before finishing each unit)
1. Self-check §A after writing each .ets file; do not run a whole-project build (the gate runs it).
2. The summary lists: output files + exported symbols per file + unimplemented/degraded points.
3. Event callbacks must not have empty comment bodies; where something can't be wired, use `console.info('TODO:<action>:<component>')` and list it.

## I. Shared files and exclusive ownership
- `common/Router.ets`, `pages/Index.ets`, `resources/base/profile/route_map.json`, `main_pages.json`: frozen; not editable.
- `entryability/EntryAbility.ets`: only fnd-app-init may edit it (add initialization in onCreate/onWindowStageCreate; do not touch smokeRoute pass-through/loadContent).
- `module.json5`: only fnd-app-init edits it; other units report permission needs in their summary `blocked`.
- `resources/base/element/*.json`: append-only (no deleting/renaming existing keys); en/dark stay in sync.
- core/* is created exclusively by foundation units; page slices only import it (symbols must be in interface-manifest.json).

## J. Conventions added during the run
- J1 (fnd wave): **the source of truth for foundation interfaces is `spec/interface-manifest.json` (244 exported symbols)**; import only symbols listed there. Services/repositories are **classes with static methods** (`GoodsRepository.getGoodsDetail(id)` returns `Promise<NetworkResponse<T>>`); handle results with `ResultHandler.handle/handleAsync`; network errors are already turned into `网络请求失败`.
- J2: `JSON.parse` yields plain objects: fields the server doesn't return are `undefined` (not the model default), so null-guard before reading (`x?.y ?? default`). Static helpers like `Auth.from`/`Coupon.normalize`/`OrderCount.from` are already applied in the service layer.
- J3: DAO change notification ≠ Flow: subscribing **does not** push current data. Pages must query once first, then `subscribe(cb)` (cb re-queries), and `unsubscribe` in `aboutToDisappear`.
- J4: There are no 401 interception/auto-logout (same as the source; §F's "401 → clear" is void, follow DATA-A05).
- J5: Toasts use `ToastUtils.show/showSuccess/showError` (ToastUtils is initialized after loadContent); validation uses `ValidationUtil.isValidPhone/isValidSmsCode/isValidImageCode/isValidPassword`; chat time uses `TimeUtils.formatChatTime/shouldShowTimeHeader`.
- J6: Component @Param names must not clash with built-in attribute methods (verified in fnd: `borderColor` → compile error "not assignable to the same property in base type CustomComponent"); likewise for color/backgroundColor/border/padding/margin/opacity, etc.
- J7: Navigation results: the `onResult` callback of `AppNavigator.navigate(..., onResult)`; or the page VM's `observeRefreshState`. When the login wall redirects, onResult is not attached.
