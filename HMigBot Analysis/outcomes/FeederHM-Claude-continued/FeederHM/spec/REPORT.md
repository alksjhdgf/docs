# Feeder 迁移台账投影

源：input/Feeder　目标：output/FeederHM　更新：2026-10-12T17:16:06.715Z

## 切片进度

| 状态 | 数量 |
|---|---|
| planned | 0 |
| implementing | 0 |
| checked | 0 |
| accepted | 31 |
| failed | 0 |
| waived | 0 |

## 功能断言四态（分子/分母 = 961/1014；ui=393 backend=566 on_device=55）

| 态 | 数量 |
|---|---|
| untested | 49 |
| passed | 961 |
| failed | 4 |
| waived | 0 |

证据来源：passed 2 真机 / 959 静态；failed 4 真机 / 0 静态（静态=验收代理读码判断，真机=4b 走查）
静态 passed 证据可定位（文件:行 / 报告#步 真实存在）：958/959　⚠ 1 条为散文证据，不可回溯

## 门历史（6 次）

- 2026-10-12T11:59:12.540Z [slice] fnd-wave: ✅ 6 波 17 单元；收口 build exit0、closure slice exit0、vectors 241/241
- 2026-10-12T15:04:54.363Z [integration] slices-3b: ✅ 14 切片 checked；阻塞债 8 条全 resolved；降级 59 条裁决（open 51/非降级 8）；全量构建 exit0；closure integration 硬违规 0；补跑冒烟 Article/Settings/AddFeedFromShare 全绿
- 2026-10-12T16:49:40.512Z [integration] acceptance-4a: ✅ acceptance 3 轮（wf_706825bb-4bd / wf_494e698e-bc6 / wf_ff78c6a1-9f9）：31/31 单元收敛 accepted；1 次定向修复轮；对抗否证推翻 NW-A12/A13 后已改实现；过账失败 4 单元由主会话按判词补登
- 2026-10-12T16:51:44.819Z [final] closure-final: ✅ 硬违规0·软立案4已裁决（豁免票 4 张均精确名+文件:行）；dead_file 4 已清（删 3 个重复/降级残留文件；卡片文件经动作常量去重被 FeedFormAbility 引用）；build exit0
- 2026-10-12T16:52:19.934Z [final] closure-final: ✅ 更正前次记录：前次记门时 final 实为 exit 2（7 条立案未裁决）。本次：final exit 0，硬违规 0，豁免票 11 张精确名吸收 11 条（unreachable_route 1、read_path_unused 3、read_unresolvable 6、page_top_unavoided 1，均附文件:行证据）
- 2026-10-12T17:14:45.182Z [integration] runtime-4b: ❌ 核心路径11页·on_device 过账2/转untested 49·失败4（flow-nav/listops/swipe/editdelete/opml/device 失败：bindMenu(isShow) 菜单不弹出、滑动标已读流内不复现）

## 降级与债务

- [降级·no_equiv] deg-core-readaloud-podcast-14yshj: Text language detection: the source uses Android s TextClassificationManager.detectLanguage, with confidence multiplied by 100. The SDK has no text language ide（实现期登记（切片 core-readaloud-podcast）·待裁决；查证：I grepped openharmony/ets/api, hms/ets/api and both kits directories in /Applica）
- [降级·approx] deg-core-readaloud-podcast-1vth25: Switching TTS language: Android TextToSpeech.setLanguage(Locale) switches language at runtime. On HarmonyOS the language is fixed when createEngine is called, s（实现期登记（切片 core-readaloud-podcast）·待裁决）
- [降级·approx] deg-core-readaloud-podcast-4ysh55: Bottom bar visuals: the AnimatedVisibility 256 ms slide in/out is done with TransitionEffect.move(BOTTOM) plus a 256 ms animation. Crossfade between play and pa（实现期登记（切片 core-readaloud-podcast）·待裁决）
- [降级·approx] deg-core-readaloud-podcast-1682r8: The HarmonyOS speak() call accepts at most 10000 characters per request; longer text fails with error 1002300001. Any paragraph over 9000 characters is split at（实现期登记（切片 core-readaloud-podcast）·待裁决）
- [降级·policy] deg-core-readaloud-podcast-zcjsfp: Background playback: the source has no foreground service or MediaSession either. On HarmonyOS, continuing audio in the background requires AVSession plus a lon（实现期登记（切片 core-readaloud-podcast）·待裁决）
- [降级·no_equiv] deg-core-translation-1yt5wa: TR-A15: the source tries Android s on-device translation first. HarmonyOS has no on-device text translation API, so that step always returns the  Local translat（实现期登记（切片 core-translation）·待裁决；查证：grep -rl for each symbol under the SDK s openharmony/ets and hms/ets directories）
- [降级·no_equiv] deg-core-translation-1d5wbw: TR-A09/A14: the source detects language with Android s TextClassifier (Context.detectLocaleFromText). HarmonyOS has no text language-detection API. LanguageDete（实现期登记（切片 core-translation）·待裁决；查证：grep -rl in the SDK s openharmony/ets and hms/ets directories: 0 hits for each; ）
- [降级·approx] deg-core-translation-18pgpg: TR-A30: Android s hidden WebView becomes an off-screen ArkWeb Web component created with BuilderNode. The rawfile bergamot/* assets are copied to <filesDir>/ber（实现期登记（切片 core-translation）·待裁决）
- [降级·approx·已退回] deg-core-translation-18qsqf: TR-A25/A27/A28: model and runtime files download through request.agent (written straight to <dest>.download, with progress events) instead of OkHttp streaming. （实现期登记（切片 core-translation）·待裁决）
- [降级·approx] deg-core-translation-159plg: TR-A37:  Open settings  uses Android s Intent(Settings.ACTION_SETTINGS) in the source. Here it opens the HarmonyOS Settings app (com.huawei.hmos.settings MainAb（实现期登记（切片 core-translation）·待裁决）
- [降级·approx·已退回] deg-page-feed-4somvi: FD-A34：列表数据以快照替换（IDataSource.onDataReloaded）提交，不做条目增删动画；因此同步中关闭动画这一契约天然成立。非同步时源 animateItem 的位移动画在此近似为无动画。（实现期登记（切片 page-feed）·待裁决；查证：LazyForEach 整体 reload 不带 item 位移动画；行为契约（同步时无动画）不变）
- [降级·approx] deg-page-feed-u8eise: FD-A38：Compose LazyVerticalStaggeredGrid 用 ArkUI WaterFlow + columnsTemplate 还原（列数 2/3/4 或 forceSingleColumn=1），视觉近似。M3 TopAppBar/DropdownMenu/FAB/SearchBar 视觉按（实现期登记（切片 page-feed）·待裁决；查证：WaterFlow 为鸿蒙瀑布流等价容器）
- [降级·approx] deg-page-feed-1v7yxm: FD-A28..A31：SAF 的 MIME 过滤（text/xml、text/x-opml、application/json、*/* 等）改为 DocumentViewPicker 的后缀过滤 fileSuffixFilters（含  .*  表示任意文件）；新建文档用 newFileNames + fileSuff（实现期登记（切片 page-feed）·待裁决；查证：picker.DocumentViewPicker 只支持按后缀过滤，不支持按 MIME 过滤）
- [降级·approx·已退回] deg-page-main-1jpahq: The source MainActivity onStart/onStop/onResume are replaced by ApplicationContext  applicationStateChange  (onApplicationForeground/onApplicationBackground) in（实现期登记（切片 page-main）·待裁决；查证：Checked ets/api/application/ApplicationContext.d.ts:301 on(type:  applicationSta）
- [降级·approx] deg-page-main-ydn0n1: Android onKeyDown consumes volume keys per key event. Here inputConsumer.on( keyPressed , {key: KEYCODE_VOLUME_UP/DOWN, action: 1, isRepeat: true}) is subscribe（实现期登记（切片 page-main）·待裁决；查证：Checked @ohos.multimodalInput.inputConsumer.d.ts on( keyPressed , options, Callb）
- [降级·policy] deg-page-import-1h67lr: APP-A36 (keep the import page out of recents): the app has a single UIAbility and the import screen is a page inside it, not its own ability. HarmonyOS excludeF（实现期登记（切片 page-import）·待裁决；查证：Read UIAbilityContext.d.ts: it has moveAbilityToBackground and setMissionContinu）
- [降级·approx·已退回] deg-page-import-bd4w5p: EF-A48: in the source,  No feeds  cannot appear (initial only turns false inside saveFeed), and a parse failure without an exception leaves the summary empty. F（实现期登记（切片 page-import）·待裁决）
- [降级·approx·已退回] deg-page-import-1qz9qk: The source shows the R.string.failed_to_import_OPML resource without its quote marks (Android strips them). The HarmonyOS resource value still contains the lite（实现期登记（切片 page-import）·待裁决）
- [降级·approx] deg-page-text-settings-1abxtl: TS-A29: ArkUI Text has no per-axis font variation setting (FontVariation exists only in the @ohos.graphics.text paragraph API, not on TextAttribute). For user f（实现期登记（切片 page-text-settings）·待裁决；查证：grep  fontVariation|FontVariation  in sdk/default/openharmony/ets/component/*.d.）
- [降级·approx] deg-page-text-settings-1ecnse: M3 look is approximated: MenuSetting/DropdownMenu became bindMenu+Menu/MenuItem, MultiChoiceSegmentedButton is a custom-drawn two-segment Row with check icon an（实现期登记（切片 page-text-settings）·待裁决）
- [降级·policy] deg-page-text-settings-1x9csr: TS-A07: the source filters OpenDocument by MIME [ application/x-font-ttf , font/ttf ]; HarmonyOS DocumentViewPicker filters by suffix, so fileSuffixFilters=[ .t（实现期登记（切片 page-text-settings）·待裁决；查证：DocumentSelectOptions in @ohos.file.picker.d.ts only has fileSuffixFilters (no M）
- [降级·approx] deg-page-search-feed-ea512x: M3 visuals are approximated: the filled TextField (floating label above the input, indicator line, surfaceContainerHighest container), Card (surfaceContainerHig（实现期登记（切片 page-search-feed）·待裁决；查证：Visual approximation; belongs under the batch-level M3 degradation entry.）
- [降级·approx] deg-page-search-feed-16ul5k: The top bar does not use TopAppBarDefaults.enterAlwaysScrollBehavior (collapse on scroll). SensibleTopAppBar stays fixed while the content scrolls. Title, back （实现期登记（切片 page-search-feed）·待裁决；查证：Visual/animation approximation; behaviour contract unchanged.）
- [降级·approx·已退回] deg-page-search-feed-19s30o: SearchPage top-bar back: the source s onNavigateUpFromIntentActivities (start MainActivity and finish the share Activity) is mapped to AppRouter.goHome(). Syste（实现期登记（切片 page-search-feed）·待裁决；查证：Single-Activity Navigation model has no separate Activity; mapped to the equival）
- [降级·approx] deg-page-feed-edit-1bb7jg: EF-A33: HarmonyOS has no equivalent of Android s shouldShowRationale. As a stand-in, the first time the switch is turned on the app calls requestEnableNotificat（实现期登记（切片 page-feed-edit）·待裁决）
- [降级·approx] deg-page-feed-edit-103tuc: EF-A55/A56 and the radio rows: the screen-reader state text `Selected`/`Not selected` (Compose stateDescription) is replaced by accessibilityChecked/accessibili（实现期登记（切片 page-feed-edit）·待裁决）
- [降级·approx] deg-page-feed-edit-hisxey: Material 3 visual approximation for this batch: TextField/OutlinedTextField floating labels are drawn as a static label above a TextInput, with filled/outlined （实现期登记（切片 page-feed-edit）·待裁决）
- [降级·policy] deg-backend-notifications-widget-z0t40e: The ArkTS widget file FeedWidgetForm.ets has to use the widget-only @Entry(LocalStorage) / @Component / @LocalStorageProp decorators, because the platform deliv（实现期登记（切片 backend-notifications-widget）·待裁决；查证：Checked SDK component/common.d.ts: ComponentV2/Local are tagged @form, but the o）
- [降级·policy] deg-backend-notifications-widget-vokbok: NW-A06: HarmonyOS notification slots cannot be renamed, so the  Unread feeds  channel name and description are not shown. The CONTENT_INFORMATION slot is used (（实现期登记（切片 backend-notifications-widget）·待裁决；查证：@ohos.notificationManager.d.ts: SlotType is a fixed enum (UNKNOWN_TYPE, SOCIAL_C）
- [降级·approx] deg-backend-notifications-widget-kv64n8: NW-A08: HarmonyOS has no group-summary notification or GROUP_ALERT_SUMMARY. The summary is published as a separate MULTILINE notification (id 2147483646) in the（实现期登记（切片 backend-notifications-widget）·待裁决）
- [降级·policy·已退回] deg-backend-notifications-widget-19grve: NW-A12/A13:  Mark as read  and swipe-away (removalWantAgent) use the WantAgent SEND_COMMON_EVENT type with the app s own event names, handled by a dynamic subsc（实现期登记（切片 backend-notifications-widget）·待裁决；查证：@ohos.app.ability.wantAgent.d.ts OperationType offers only START_ABILITY / START）
- [降级·policy] deg-backend-notifications-widget-1gee0u: NW-A22: the widget s sync button runs RssLocalSync.syncFeeds() inside the FormExtensionAbility process. That process only lives for a short time after onFormEve（实现期登记（切片 backend-notifications-widget）·待裁决；查证：FormExtensionAbility.d.ts has no keep-alive or long-task API; onFormEvent(formId）
- [降级·approx] deg-backend-notifications-widget-1minl6: NW-A10/A11: there are no Custom Tabs on HarmonyOS, so the CUSTOM_TAB opener uses ActivityLauncher.openLinkInCustomTab: the in-app browser hook if one is registe（实现期登记（切片 backend-notifications-widget）·待裁决）
- [降级·approx] deg-backend-notifications-widget-7b0j1o: NW-A18/A19: the widget uses system colour tokens (sys.color.font_primary, font_secondary, background_primary, comp_background_secondary; they follow light/dark （实现期登记（切片 backend-notifications-widget）·待裁决）
- [降级·approx·已退回] deg-backend-notifications-widget-1tgcdm: NW-A25: feed icons are sent to the widget as formImages file descriptors. An icon larger than 512 KB is treated as a failed load and not shown, to stay within w（实现期登记（切片 backend-notifications-widget）·待裁决）
- [降级·approx] deg-backend-notifications-widget-wuz5ea: NW-A23: the widget s settings icon opens FeedWidgetSettings inside the main app s navigation stack (on a cold start, after Main has taken over), so Back returns（实现期登记（切片 backend-notifications-widget）·待裁决）
- [降级·approx] deg-page-sync-atboz7: Barcode scanning: the source launches an external zxing app via Intent com.google.zxing.client.android.SCAN. HarmonyOS uses the system ScanKit scanBarcode.start（实现期登记（切片 page-sync）·待裁决；查证：Checked hms/ets/api/@hms.core.scan.scanBarcode.d.ts: startScanForResult(context,）
- [降级·approx] deg-page-sync-o8tcaf: Long deviceId: core SyncRemote.deviceId and SyncDevice.deviceId are number columns, so ids above 2^53 lose precision there. Mitigation: before JSON parsing, dev（实现期登记（切片 page-sync）·待裁决；查证：core/db/SyncDaos.ets defines deviceId: number; there is no string column.）
- [降级·approx] deg-page-sync-oh36v8: M3 visuals approximated at batch level: TextField is drawn as a label plus TextInput/TextArea with a colored bottom border for the error state; the TopAppBar en（实现期登记（切片 page-sync）·待裁决）
- [降级·approx] deg-page-sync-1fj1af: EncryptedFeed content hash: URL.hashCode uses core JavaUrl.javaHashCode, the Android variant that does no DNS lookup. It has not been cross-checked against a re（实现期登记（切片 page-sync）·待裁决）
- [降级·approx·已退回] deg-core-openai-1l3ts6: AI-A35: the source relies on Ktor defaultRequest to resolve relative paths against the base URL. Here the URL is joined explicitly instead: base URL with traili（实现期登记（切片 core-openai）·待裁决）
- [降级·approx] deg-core-openai-1lx2cc: Visual approximation, logged once for the batch: the M3 filled TextField, OutlinedCard, DropdownMenu, Dialog Surface and LinearProgressIndicator are drawn with （实现期登记（切片 core-openai）·待裁决）
- [降级·approx] deg-core-openai-1mv4fy: AI-A11: ArkUI has no VisualTransformation. The TextInput shows maskApiKey(raw), and each edit is mapped back to the raw key using TextChangeOptions.rangeBefore/（实现期登记（切片 core-openai）·待裁决）
- [降级·approx] deg-core-openai-clzkxr: AI-A24/A41: there is no Locale.getISOLanguages()/getISO3Language(). The ISO 639-1 list and its 639-2/T mapping are hard-coded to the Java set (legacy in/iw/ji r（实现期登记（切片 core-openai）·待裁决）
- [降级·approx·已退回] deg-core-openai-1iixfc: Error text from OpenAI-compatible requests: error.message from the JSON body is used, as in the source. When the body is not JSON, the message falls back to  HT（实现期登记（切片 core-openai）·待裁决）
- [降级·no_equiv] deg-page-shells-55omn3: HarmonyOS has no system  data usage → app settings  entry point like Android MANAGE_NETWORK_USAGE. The ManageSettings route is fully implemented, but the system（实现期登记（切片 page-shells）·待裁决；查证：grep -rli over sdk/default/openharmony/ets and hms/ets for MANAGE_NETWORK_USAGE|）
- [降级·approx] deg-page-shells-1m8uji: OpenLinkInDefault: the source is a singleInstance transparent Activity in its own taskAffinity. Here it is a DIALOG-mode transparent NavDestination in the main （实现期登记（切片 page-shells）·待裁决）
- [降级·approx] deg-page-shells-1wymoj: ManageSettings: the source renders SettingsScreen directly inside its own Activity. Here a host page pushes the in-app Settings page on top of itself, and a UIO（实现期登记（切片 page-shells）·待裁决）
- [降级·approx] deg-page-shells-o1ni0d: AddFeedFromShare: the source s private NavHost (search → add/feed) becomes two screens inside one page, using a 300ms opacity fade in place of fadeIn/fadeOut. T（实现期登记（切片 page-shells）·待裁决）
- [降级·no_equiv] deg-page-settings-2hz13a: ST-A22: the public SDK has no way to ask whether this app is exempt from battery optimisation, so isIgnoringBatteryOptimizations() always returns false and the （实现期登记（切片 page-settings）·待裁决；查证：Grepped openharmony/ets/api and hms/ets/api in /Applications/DevEco-Studio.app/C）
- [降级·approx] deg-page-settings-1tc8m2: ST-A22 click: there is no equivalent of the Android  ignore battery optimisation  list page. The click opens this app s info page in the Settings app (com.huawe（实现期登记（切片 page-settings）·待裁决）
- [降级·approx] deg-page-settings-17i3jk: ST-A10: there is no shouldShowRationale equivalent. The page keeps an in-process flag recording that the system notification request was refused once; while it （实现期登记（切片 page-settings）·待裁决）
- [降级·approx] deg-page-settings-1vi6g9: Visual batch (M3 approximation): the source top bar hides while scrolling down; here it stays fixed and only changes colour once scrolled. The source BugReport （实现期登记（切片 page-settings）·待裁决）
- [降级·policy] deg-page-settings-11rdpo: ST-A19: after a change to sync frequency, Wi-Fi-only or charging-only, the store setter calls the scheduler hook to reschedule with replace=true (Manually cance（实现期登记（切片 page-settings）·待裁决）
- [降级·approx] deg-page-article-1xqs4c: The top bar stays fixed instead of hiding while scrolling (source uses enterAlwaysScrollBehavior). It switches to the scrolled container color once the content （实现期登记（切片 page-article）·待裁决；查证：Visual only; covered by the batch-level M3 visual-approximation entry.）
- [降级·approx] deg-page-article-1tudt2: Several Compose details are approximated: the nanihadesuka ColumnScrollbar becomes the native Scroll scrollbar in outlineVariant; PlainTooltipBox tooltips becom（实现期登记（切片 page-article）·待裁决；查证：Visual/a11y approximation; behavior (selectable/copyable text, clickable feed ti）
- [降级·approx] deg-page-article-1cr73p: Android Custom Tabs are replaced by an in-app browser: a full-screen ArkWeb dialog (ComponentContent + openCustomDialog) with a toolbar in the toolbar color and（实现期登记（切片 page-article）·待裁决；查证：Custom Tabs do not exist on HarmonyOS; ArkWeb Web component used instead.）
- [降级·approx] deg-page-article-102lif: Volume-key paging uses MainViewModel s existing inputConsumer  keyPressed  capture (active when in foreground, paging mode on and an article open). The page sub（实现期登记（切片 page-article）·待裁决；查证：inputConsumer.on( keyPressed , KeyPressedConfig) exists since API 16 in @ohos.mu）
- [降级·approx] deg-page-article-1v0xym: Scroll position and menu open state are kept in a SavedStateRegistry handle (ArticleViewModel.<itemId>). They survive the page being rebuilt; surviving a proces（实现期登记（切片 page-article）·待裁决；查证：HarmonyOS has no SavedStateHandle that survives a process restart; SavedStateReg）
- [降级·no_equiv] deg-acc-content-provider: APP-A80..A83: no external read-only ContentProvider/<appId>.permission.read; RssReadOnlyApi queries stay in-process only（4a 验收收口登记·裁决成立；查证：find sdk -iname '*DataShareExtensionAbility*' → 0 hits; ets/api/@ohos.data.dataS）
- [降级·approx] deg-acc-dynamic-shortcuts: RP-A08/UT-A34: no dynamic shortcuts; 3 static slots feed_slot_0..2 shown/hidden by MRU, label 'Recent feed N' + app icon, not feed title/letter icon（4a 验收收口登记·裁决成立；查证：@ohos.bundle.shortcutManager.d.ts has only setShortcutVisibleForSelf/getAllShort）
- [降级·no_equiv·已退回] deg-acc-process-text: UT-A40/A41: menu order Copy/Paste/Cut/Select all is kept; third-party PROCESS_TEXT apps can't be listed/launched, only system items + in-app processors（4a 验收收口登记·裁决成立；查证：@ohos.bundle.bundleManager.d.ts: 0 hits queryAbilityInfo; component/text_common.）
- [降级·no_equiv] deg-acc-new-tab: UT-A25: DEFAULT_BROWSER opens viewData Want without Browser.EXTRA_CREATE_NEW_TAB (browser decides tab reuse)（4a 验收收口登记·裁决成立；查证：@ohos.app.ability.wantConstant.d.ts Params: no new-tab key (grep -i 'new_tab|new）
- [降级·approx] deg-acc-drawer-a11y: UC-A14/UM-A10: 'Toggle tag expansion' custom action → separate arrow button; paneTitle → announce on open + accessibilityText; dismiss = system back（4a 验收收口登记·裁决成立；查证：component/common.d.ts:3601 enum AccessibilityAction = UNDEFINED_ACTION|ACCESSIBI）
- [降级·approx] deg-acc-readability: HM-A44: net.dankito.readability4j 1.0.8 (JVM, Jsoup) re-implemented in ArkTS; extracted HTML not byte-identical to Android (serialization/scoring details)（4a 验收收口登记·裁决成立；查证：input/Feeder/gradle/libs.versions.toml:23,116 readability4j=1.0.8 (JVM jar, no s）
- [降级·policy] deg-acc-notify-action: NW-A12/A13: Mark as read uses START_ABILITY→NotificationActionAbility (start window flashes); swipe while dead is reconciled at next start/notify（4a 验收收口登记·裁决成立；查证：@ohos.app.ability.wantAgent.d.ts OperationType = UNKNOWN_TYPE/START_ABILITY/STAR）
- [降级·no_equiv] deg-acc-process-text-v2: UT-A40/A41: menu order Copy/Paste/Cut/Select all is kept; third-party PROCESS_TEXT apps can't be listed/launched, only system items + in-app processors（4a 验收收口登记·裁决成立；查证：grep SDK openharmony/ets/api + hms/ets/api：ACTION_PROCESS_TEXT、queryAbilityInfo ）
- [债务] blk-core-readaloud-podcast: These criteria need pages owned by other units; this unit supplies the APIs and the pages still have to be wired. (1) page-article (pages/ArticlePage.ets, features/article/*): RA-A01 — the overflow menu item `read_article` should call setToolbarMenuVisible(false) and then ReadAloudActions.articleTts — resolved
- [债务] blk-core-translation: The bergamot assets need copying. Nothing under entry/src/main/resources is in my allowed file list. Copy input/Feeder/app/src/main/assets/bergamot/** (index.html, feeder-bergamot.js, translator.js, worker/bergamot-translator-worker.js, worker/translator-worker.js) to output/FeederHM/entry/src/main/ — resolved
- [债务] blk-page-import: module.json5 (owned by fnd-app-init): for APP-A31, the OPML file-open skill (viewData/sendData) has no entry for MIME type application/octet-stream. Add { scheme : file , type : application/octet-stream }, and consider the content/datashare schemes too. The intent filter in the source AndroidManifes — resolved
- [债务] blk-page-text-settings: TS-A02 needs pages/SettingsPage.ets, which belongs to the page-settings slice and is not mine to edit. Under its `Text` group, the `Text settings` item must call AppRouter.push(Routes.TEXT_SETTINGS, new TextSettingsRouteParam()). Its subtitle can use fontDisplayLabel(Repository.instance().font), exp — resolved
- [债务] blk-page-sync: core/app/AppBootstrap.ets (fnd-owned) has to call `installSyncChain(ctx)` from `features/sync/SyncChain.ets` right after registerRepositoryHooks() in step 5 of run(). core/sync/SyncScheduler.bootstrapHeadless (the WorkScheduler extension process) needs the same call after SyncScheduler.init(ctx). Wi — resolved
- [债务] blk-page-shells: A41 (owned by fnd-app-init, module.json5): the viewData skill lists only application/rss+xml, application/atom+xml and application/json for http(s). It is missing text/xml and application/xml, which the source AndroidManifest.xml:115 intent-filter (1) declares; fnd-app-init needs to add both MIME ty — resolved
- [债务] blk-page-article: The in-app browser hook (features/article/InAppBrowser.ets) registers when its module loads, which happens when the Article page loads. Because route_map loads pages lazily, a link opened with the CUSTOM_TAB setting from the Feed page before any article has been opened falls back to the system browser — resolved
- [债务] blk-backend-notifications-widget: Main session (fnd-app-init / owners of the shared files) needs to add: 1) entryability/EntryAbility.ets    - onCreate: call `NotificationActions.install(this.context)`, then `NotificationActions.onWant(want)`, both BEFORE `DeepLinkRouter.onCreateWant(want)`.    - onNewWant: call `NotificationActions — resolved

⚠ --anchors 报告无 prdCoverage（跑 check-anchors 时未定位到 PRD）

## 场景走查（output/FeederHM/spec/4b：计划 0 份含场景、已跑 0、计划全过 0；场景 0/0 已走、0 通过，⚠ 分母只是计划里提到的场景（缺 scenarios.txt 全集））

| 场景 | 结果 | 所在计划 |
|---|---|---|

⚠ --walks 目录里没有带 scenarios 字段的计划——有 PRD 时每份流计划须写 "scenarios":["S1","S2"]

走查形态：流计划 11 份（已跑 11、全过 5）· 骨架计划 11 份（直达/存活/出现率，不计"已走"）　⚠ 连续失败≥2 的计划：flow-editdelete×3 flow-listops×2 flow-opml×3 flow-swipe×3（同一缺陷只许一次修+一次复验）

真机可见性（静态 passed 且带字面量的 ui 断言 228 条）：字面量在走查中出现过 142 条 · 从未出现 86 条（静态判断、真机未见：APP-A02 APP-A21 APP-A24 APP-A33 APP-A54 AR-A10 AR-A11 AR-A14 AR-A17 AR-A18 AR-A30 AR-A34 …）

## 源模块覆盖（按断言锚点归模块；源工程 1 个 Gradle 模块）

| 模块 | 断言数 |
|---|---|
| input/Feeder/app | 1013 |
| app | 1 |