# 探索：sync（设备同步 / Feeder Sync 协议 / 加密 / SyncScreen）

断言卡：`output/FeederHM/spec/cards/sync.md`（SY-A01..SY-A52）。

## 1. 文件清单（$SRC = input/Feeder/app/src/main/java/com/nononsenseapps/feeder）

| 文件 | 行数 | 作用 |
|---|---|---|
| sync/FeederSync.kt | 78 | Retrofit 接口：10 个端点 |
| sync/RestBodies.kt | 141 | 请求/响应 DTO、EncryptedFeed 与 Feed 互转 |
| sync/Moshi.kt | 35 | Moshi：Instant↔epoch ms、URL↔String、KotlinJsonAdapterFactory |
| sync/Retrofit.kt | 53 | OkHttp 客户端：Basic 认证拦截器、缓存日志拦截器、baseUrl `/api/v1/` |
| sync/SyncRestClient.kt | 667 | 同步业务核心（create/join/leave/removeDevice/markAsRead/getRead/getFeeds/feedDiffing/sendUpdatedFeeds） |
| crypto/AesCbcWithIntegrity.kt | 551 | AES-CBC + HMAC-SHA256（tozny java-aes-crypto 移植） |
| ui/compose/sync/SyncScreen.kt | 1199 | 同步页 UI（单栏 4 子屏 + 双栏） |
| ui/compose/sync/SyncScreenViewModel.kt | 289 | 页面状态机 |
| ui/compose/sync/LeaveSyncChainDialog.kt | 26 | 离开确认框（ConfirmDialog） |

相关区外文件（只读引用）：
- db/room/SyncRemote.kt（实体、DEFAULT_SERVER_ADDRESS、DEPRECATED_SYNC_HOSTS、generateDeviceName）
- db/room/SyncRemoteDao.kt:60 `replaceWithDefaultSyncRemote`（删 id=1 再插入默认，设备名 `Build.PRODUCT ?: MODEL ?: BRAND`，新密钥）
- archmodel/SyncRemoteStore.kt（getSyncRemote 不存在时创建默认：id=1、generateDeviceName、新密钥）
- archmodel/Repository.kt:681-811（remoteMarkAsRead、applyRemoteReadMarks、join/leave/startNewSyncChain 包装）、:891 isSyncChainConfigured
- background/SyncChainGetUpdatesJob.kt、SyncChainSendReadJob.kt（JobScheduler）
- model/RssLocalSync.kt:121-129（每次 RSS 同步前跑同步链）
- ui/MainActivity.kt:75-85 maybeRequestSync（onResume）
- ui/compose/navigation/NavigationDestinations.kt:495-555 SyncScreenDestination（route `sync?syncCode=&secretKey=`，深链 `https://feederapp.nononsenseapps.com/sync/join?sync_code={syncCode}&key={secretKey}`）
- ui/ManageSettingsActivity.kt:30-39（系统“管理设置”入口用深链 pattern 字面串启动 MainActivity）
- 测试：app/src/test/.../sync/EncryptedFeedTest.kt、app/src/androidTest/.../sync/SyncRestClientTest.kt（MockWebServer）

## 2. 数据模型

### SyncRemote（表 sync_remote，单行 id=1）
`id, url(URL, 默认 https://feeder-sync.nononsenseapps.com:443), syncChainId(String, 64 字符=已入链), latestMessageTimestamp(Instant, INTEGER ms), deviceId(Long), deviceName(String), secretKey(String "aes:hmac"), lastFeedsRemoteHash(Int)`。`hasSyncChain() = syncChainId.length == 64`。
级联：sync_device、remote_feed、remote_read_mark、read_status_synced 均 FK→sync_remote ON DELETE CASCADE，故“离开”（删 id=1 再插入）会清空这四张表。

### DTO（RestBodies.kt）
- CreateRequest/JoinRequest {deviceName（密文）}；JoinResponse {syncCode, deviceId}
- DeviceListResponse {devices:[DeviceMessage{deviceId, deviceName（密文）}]}
- EncryptedReadMark {timestamp(ms), encrypted}；SendEncryptedReadMarkBulkRequest {items:[{encrypted}]}；SendReadMarkResponse {timestamp}
- ReadMarkContent {feedUrl, articleGuid}（加密前明文 JSON）
- UpdateFeedsRequest {contentHash:Int, encrypted}；UpdateFeedsResponse {hash}；GetFeedsResponse {hash, encrypted}
- EncryptedFeeds {feeds:[EncryptedFeed]}，EncryptedFeed 12 字段及默认：url, title="", customTitle="", tag="", imageUrl=null, fullTextByDefault=false, openArticlesWith=OPEN_ARTICLE_WITH_APPLICATION_DEFAULT, alternateId=false, fetchOgImages=false, blockRules="", allowRules="", whenModified=EPOCH
- 未加密版 ReadMark / SendReadMarkRequest / `readmark` 端点在接口中定义但客户端未使用（只用 `ereadmark`）。

## 3. 协议（Feeder Sync REST）

- baseUrl：`URL(syncRemote.url, "/api/v1/")`（Retrofit.kt:45）。
- 认证：每请求 `Authorization: Basic base64(feeder_user:feeder_secret_1234)`（注释：仅防扫描）。
- 头：`X-FEEDER-ID`=syncChainId，`X-FEEDER-DEVICE-ID`=deviceId（Long）。
- 乐观并发：`POST feeds` 带 `If-Match: W/"<lastFeedsRemoteHash>"`（`asWeakETagValue`）；412 = 远端已被别的设备更新。
- 共享 OkHttpClient（DI 注入，带 HTTP 缓存），第二拦截器仅打日志。
- 错误码约定（ErrorResponse.code）：HTTP 码；998 成功无 body；999 异常（toEither 内或 join 异常）；1000 业务函数异常；1001 未配置。
- 踢出检测：错误 body 包含 `Device not registered` → `leave()`。

### 流程
1. create（SyncRestClient.kt:99）：取 SyncRemote 中已有 secretKey（默认行创建时已生成）→ 构造客户端 → POST create（加密 generateDeviceName()）→ 存 syncChainId/deviceId/deviceName/ts=EPOCH → Repository 再调 getDevices → 返回 (syncCode, secretKey)。
2. join（:136）：先把 remoteSecretKey 与新 deviceName 写库 → 构造客户端 → POST join(X-FEEDER-ID=syncCode) → 存 syncChainId/deviceId/ts=EPOCH → getDevices。失败时已写入的对方密钥保留在库里（无链）。
3. leave（:204）：safeBlock 内 DELETE devices/{self}；finally `replaceWithDefaultSyncRemote()`（总是重置）。
4. removeDevice（:233）：DELETE devices/{id} → replaceDevices（解密名）。
5. markAsRead（:315）：`getFeedItemsWithoutSyncedReadMark`（已读且不在 read_status_synced，ORDER BY id DESC）分 100 一批 → POST ereadmark；成功即 setSynced。不更新 latestMessageTimestamp。
6. getRead（:377）：since = latestMessageTimestamp+1ms；逐条解密→`remoteMarkAsRead`（总是插 remote_read_mark；若本地有 feedUrl+guid 匹配条目则 setSynced + markAsReadAndNotified）→ 更新时间戳（逐条推进）。
7. getFeeds（:418）+ feedDiffing（:462）：见 SY-A36/37。注意 remote_feed 用 syncRemote=1L 硬编码。
8. sendUpdatedFeeds（:530）：见 SY-A39/40。412 分支递归调用 getFeeds() + sendUpdatedFeeds()，**无次数上限**。
9. getDevices（:339）：GET devices → replaceDevices。

### 调用时机
- RssLocalSync.syncFeeds（每次 RSS 同步，持 syncMutex）：getFeeds→getRead→getDevices→sendUpdatedFeeds→markAsRead，然后 RSS 抓取，最后 applyRemoteReadMarks（feed-sync 卡 FS-A03/FS-A07 已录）。
- SyncChainSendReadJob：Repository 各 markAsRead* 后 `runOnceSyncChainSendRead`；最小延迟 10s，`getMyPendingJob` 去重；受 syncOnlyWhenCharging/syncOnlyOnWifi。
- SyncChainGetUpdatesJob：MainActivity onResume（syncOnResume && 当前联网/充电/非计费条件满足）→ getRead→applyRemoteReadMarks→getDevices。
- SyncScreen 进入时 updateDeviceList；join 成功后 runOnceRssSync(triggeredByUser=false)。
- markAsUnread：只删 read_status_synced 记录，不发服务器（远端已读会被其它设备保留；applyRemoteReadMarks 末尾删掉指向本地已读条目的远端标记以免覆盖未读）。

## 4. 加密（crypto/AesCbcWithIntegrity.kt）

- 常量：AES/CBC/PKCS5Padding，AES 128 位，IV 16 字节，HMAC=HmacSHA256，HMAC 密钥 32 字节，Base64 = android.util.Base64.NO_WRAP（标准字母表、带 `=` 填充）。
- 密钥串 `SecretKeys.toString()` = `b64(aes):b64(hmac)`；`decodeKey` 校验 2 段与长度（16/32）。
- 密文串 `CipherTextIvMac.toString()` = `b64(iv):b64(mac):b64(ct)`（注意顺序 iv、mac、ct）；MAC 覆盖 iv‖ct。
- 解密：先 HMAC 恒定时间比较，失败抛 GeneralSecurityException。
- PBKDF2（generateKeyFromPassword，PBKDF2WithHmacSHA1，10000 次）/generateSalt 存在但同步流程未使用（generateSalt 实际取 128 **字节**，常量命名为 bits——未用，不影响）。
- 被加密内容：设备名（字符串）、ReadMarkContent JSON、EncryptedFeeds JSON。服务器只见密文。

鸿蒙映射：`@ohos.security.cryptoFramework`：`createSymKeyGenerator('AES128')`、`createCipher('AES128|CBC|PKCS7')`（16 字节块下 PKCS7≡PKCS5）、`createMac('SHA256')`、`createRandom()`；Base64 用 `util.Base64Helper`（标准字母表）。JSON 用 JSON.stringify，但需保证字段名与 Moshi 输出一致（camelCase、Instant→数值 ms、URL→字符串、null 字段默认省略）。

## 5. 内容哈希（互通关键）

`currentContentHash = feeds.hashCode()`，feeds 为 `List<EncryptedFeed>`（按 URL 排序，FeedStore.getFeedsOrderedByUrl）。语义 = Java/Kotlin：
- `List.hashCode`: h=1; h=31*h+e.hashCode()
- data class EncryptedFeed.hashCode: r=url.hashCode(); 依次 r=31*r+field.hashCode()，字段顺序同声明；imageUrl 为 null 时 0
- String.hashCode（UTF-16 码元 s[0]*31^(n-1)+…，int 溢出）；Boolean 1231/1237；Instant.hashCode = `(int)(seconds ^ (seconds>>>32)) + 51*nanos`
- **java.net.URL.hashCode** 由 URLStreamHandler 计算（协议、主机（可能经地址解析）、端口、路径、ref），具体在 Android 运行时的实现需要核实。
服务器把该 hash 作为 ETag/返回值；不同设备若对相同内容算出不同 hash，后果是反复上传（每次同步都 POST feeds），不会丢数据。鸿蒙端应尽量逐位复刻；URL 部分无法保证一致时，会与 Android 设备反复互相覆盖 hash。

## 6. 页面：SyncScreen（Compose 结构）

状态机（ViewModel）：`SyncScreenToShow {SETUP, DEVICELIST, ADD_DEVICE, JOIN}`，存 SavedStateHandle（keys `syncCode`、`secretKey`、`syncScreen`）。actualScreen 规则见 SY-A03。左右栏：Left {SETUP, DEVICELIST}、Right {JOIN, ADD_DEVICE}。
初始化：nav 参数 syncCode/secretKey 非空且无 syncScreen → JOIN；若 state 中无 syncCode，则用 SyncRemote.syncChainId 回填。
viewState = combine(syncCode, syncRemoteFlow, screen, devicesFlow, secretKey)，addNewDeviceUrl 由 syncRemote 计算。

SyncScaffold（SyncScreen.kt:109）：Scaffold + enterAlways 折叠顶栏 SensibleTopAppBar；导航图标 ArrowBack（`Go back`）；leaveSyncVisible 时 MoreVert（tooltip/desc `Open menu`）→ DropdownMenu[`Leave sync chain`，0 高度无障碍项 `Close menu`]；contentWindowInsets=statusBars，水平 navigationBars 内边距。

子屏：
- SyncSetupScreen/Content（:545/:571）：Column 居中、spacedBy 8dp、水平 dimens.margin；文案 desc_1、desc_2、financed_by_community、Ko-fi（非 play 构建，`BuildConfig.BUILD_TYPE` 不含 "play"）、beta_warning（titleMedium）；Spacer 24dp；Button `Scan or enter sync code`；TextButton `Start new sync chain`。
- SyncJoinScreen/Content（:667/:699）：TextField `Sync code`（singleLine，min 64dp）、TextField `Secret key`、Button `Join sync chain`。
- SyncDeviceListScreen/Content（:757/:788）：标题 `Devices on sync chain`；DeviceEntry 行（Row，min 触控高，名称 titleMedium weight1 + IconButton Delete）；financed 文案、Ko-fi；`Add new device` Button（仅单栏）；DeleteDeviceDialog（AlertDialog，title `Remove device`，text `remove_device_question`，按钮 android OK/Cancel）。
- SyncAddNewDeviceScreen/Content（:964/:988）：三段文案（treat_like_password 红色），QRGen `QRCode.from(Url(url)).withSize(1000,1000)` 显示 250dp，链接文本（LinkTextStyle）点击 → `Intent.createChooser(ACTION_SEND text/plain, EXTRA_TEXT=url, EXTRA_TITLE="Feeder device sync code")`。
- DualSyncScreen（:453）：宽度类非 Compact（WindowSize.kt:80）时 Row 两栏 weight 1:1，整体 verticalScroll；左栏切换时滚到顶部。
- 动画：AnimatedVisibility fadeIn/fadeOut（不入账）。

返回：每个子屏 BackHandler，见 SY-A22。导航 up：popBackStack 失败则 SettingsDestination。
入口：Settings `Device sync` 项（settings/Settings.kt:658）；深链；ManageSettingsActivity（把 `uriPattern` 字面串含 `{syncCode}` 占位符原样作为 URI 启动，导航参数可能成为字面 `{syncCode}`——属源码怪癖，需运行时核实，未录卡）。

文案 key（res/values/strings.xml）：device_sync(190)、add_new_device(191)、device_sync_financed_by_community(192)、this_device(193)、disconnect_device_from_sync(194)、devices_on_sync_chain(195)、remove_device(197)、remove_device_question(198)、press_scan_sync(199)、or_open_device_sync_link(200)、treat_like_password(201)、qr_code(202)、feeder_device_sync_code(203)、leave_sync_chain(204)、device_sync_description_1(205)、device_sync_description_2(206)、scan_or_enter_code(207)、start_new_sync_chain(208)、sync_code(209)、secret_key(210)、join_sync_chain(211)、are_you_sure_leave_sync_chain(216)、no_barcode_scanner_installed(217)、device_sync_beta_warning(332)、open_menu(163)、close_menu(290)、go_back(162)。

解析辅助（SyncScreen.kt:645-664）：
- `syncCodeQueryParam = substringAfter("sync_code=").take(64)`（无分隔符时取原串前 64）
- `secretKeyQueryParam = substringAfter("key=").substringBefore("&")`，含 `%3A` 才 URLDecoder.decode（深链已解码，扫码未解码）
- 生成链接时 secretKey 经 `URLEncoder.encode(…, "UTF-8")`（`+`→`%2B`，`/`→`%2F`，`=`→`%3D`，`:`→`%3A`）。

## 7. 平台差异 / 鸿蒙实现

| Android | 结果契约 | 鸿蒙实现 | 差异 |
|---|---|---|---|
| Retrofit+OkHttp+Moshi | REST 契约 SY-A25..42 | @ohos.net.http（或 rcp）+ 手写 JSON 映射 | 需手写 Basic 头、If-Match、错误体读取 |
| javax.crypto | SY-A44..48 | cryptoFramework AES128 CBC PKCS7 + HMAC SHA256 | 字节级互通须用 Android 生成的测试向量验证 |
| zxing SCAN Intent | 扫码填入 | ScanKit `scanBarcode.startScanForResult` | 无“找不到扫码器”场景，Toast 分支基本不可达 |
| QRGen bitmap | 显示二维码 | ArkUI `QRCode` 组件 | — |
| ACTION_SEND chooser | 分享文本 | `@kit.ShareKit` systemShare | — |
| JobScheduler（SendRead 10s 延迟、去重；GetUpdates 一次性） | SY-A50/51 | WorkScheduler 一次性 / 应用内 setTimeout 去重 | WorkScheduler 最小间隔/延迟语义不同 |
| Build.MANUFACTURER/MODEL/PRODUCT | 设备名 | deviceInfo.manufacture / productModel / marketName | 名字文本不同，非契约 |
| SavedStateHandle | 子屏状态跨重建 | AppStorage/页面状态 | — |
| WindowSizeClass | 双栏 | 断点（宽 ≥600vp） | — |
| SyncRestClient init `runBlocking` | 构造时读库初始化 | 异步 init + 就绪标志 | 避免主线程阻塞 |

### 降级候选
- 后台 10 秒批量上传已读（SyncChainSendReadJob）在鸿蒙可降级为“应用内延时任务 + 下次 RSS 同步时补传”（markAsRead 在 RssLocalSync 中也会执行，数据最终一致）。
- onResume 的 GetUpdates job 可降级为前台直接调用。
- “无扫码器” Toast：ScanKit 系统内置，可不实现。
- Ko-fi 链接（play 构建隐藏）：鸿蒙构建是否显示需产品决定。

## 8. 风险
1. **互通**：AES/HMAC/Base64/JSON 字段名、Instant 毫秒、URL 字符串化（`java.net.URL.toString` 原样保留，如 `https://foo.bar` 无尾斜杠）必须逐字节兼容，否则与 Android 设备同链即失败（解密 MAC 失败）。
2. **内容哈希**依赖 Java hashCode 语义（含 java.net.URL.hashCode），鸿蒙复刻困难 → 跨设备反复上传 feeds；需决定是否接受。
3. 412 → getFeeds → sendUpdatedFeeds 无限递归可能（源码行为），鸿蒙应加上限（不改变契约）。
4. 错误几乎全部静默（join/create 失败无 UI 提示）——保持一致即可，勿当缺陷“修复”成不同契约。
5. leave 总是重置本地（即使网络失败），服务器侧设备仍残留。
6. feedDiffing 会删除本地源（远端删除传播）——实现错误会造成数据丢失；`remote_feed` 表语义必须正确。
7. 时间戳：latestMessageTimestamp 存毫秒，since=+1ms；Instant 精度鸿蒙用 number 毫秒即可。
8. 硬编码 Basic 凭据与服务器地址需原样保留。
