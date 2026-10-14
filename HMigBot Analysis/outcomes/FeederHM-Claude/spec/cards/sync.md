# 设备同步卡（sync）

## 页面: SyncScreen

- SY-A01 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:128
- SY-A02 [ui] 未加入同步链（本地 `syncChainId` 长度≠64）时显示设置页：标题 `Device sync`，依次显示 `device_sync_description_1`、`device_sync_description_2`、`device_sync_financed_by_community`、（非 play 构建）可点击的 `https://ko-fi.com/spacecowboy`、`device_sync_beta_warning`，以及按钮 `Scan or enter sync code` 和文本按钮 `Start new sync chain`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:587
- SY-A03 [ui] 已加入同步链（`syncChainId` 长度=64）时，即使请求的是设置/加入页，也强制显示设备列表页；未加入时请求设备列表/添加设备页一律回落到设置页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:200
- SY-A04 [ui] 点 `Start new sync chain` 成功创建同步链后切到添加设备页（显示二维码/链接）；失败只记日志，页面不变且无提示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:153
- SY-A05 [ui] 点 `Scan or enter sync code` 切到加入页；若当前同步码为空则拉起扫码器，扫码结果中的 `sync_code=` 后 64 字符写入同步码、`key=` 后至 `&` 的值（含 `%3A` 时先 URL 解码）写入密钥。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:274
- SY-A06 [ui] 无扫码器可用时弹 Toast `Could not find a barcode scanner`，仍停留在加入页可手动输入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:169
- SY-A07 [ui] 加入页标题 `Join sync chain`，含输入框 `Sync code`（单行）与 `Secret key`，以及按钮 `Join sync chain`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:717
- SY-A08 [ui] 同步码输入框在“提取出的同步码”（`sync_code=` 之后或原文的前 64 字符）长度≠64 时显示错误态；`Join sync chain` 按钮仅在其长度=64 时可点。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:723
- SY-A09 [ui] 密钥输入框在密钥不可解码（非 `base64(16字节):base64(32字节)` 形式）时显示错误态，但不禁用加入按钮。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:736
- SY-A10 [ui] 输入同步码时若粘贴整条加入链接，自动提取 64 位同步码；输入密钥时若含 `key=` 则只保留其值。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:62
- SY-A11 [ui] 加入成功后触发一次非用户触发的 RSS 同步并切到添加设备页；加入失败只记日志、无提示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:110
- SY-A12 [ui] 以深链 `/sync/join?sync_code=..&key=..` 进入且本机未入链时，直接显示加入页并预填同步码与密钥。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:54
- SY-A13 [ui] 设备列表页标题 `Device sync`，显示小标题 `Devices on sync chain`，按设备名升序列出设备，本机显示为 `<名称> (this device)`，每行有删除图标（无障碍描述 `Disconnect device from sync chain`），下方为 `device_sync_financed_by_community`、（非 play 构建）Ko-fi 链接与按钮 `Add new device`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:810
- SY-A14 [ui] 进入同步页即向服务器拉取设备列表并刷新本地设备表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:219
- SY-A15 [ui] 点设备删除图标弹出对话框：标题 `Remove device`，正文 `Are you sure you want to delete device <名称>?`，按钮 `OK`/`Cancel`；`Cancel` 关闭不做任何事。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:927
- SY-A16 [ui] 删除确认 `OK`：若目标是本机则执行离开同步链（回到设置页）；否则调用服务器移除该设备并用返回列表替换本地设备列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:263
- SY-A17 [ui] 仅设备列表态的顶栏有溢出菜单（`Open menu`），菜单唯一项 `Leave sync chain`；点后弹确认框标题 `Leave sync chain`、正文 `Are you sure you want to leave the sync chain?`，按钮 `OK`/`Cancel`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:142
- SY-A18 [ui] 确认离开后：清空同步码与密钥输入，页面回到设置页，本地设备列表清空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:125
- SY-A19 [ui] 添加设备页标题 `Add new device`，显示 `press_scan_sync`、`or_open_device_sync_link`、红色 `treat_like_password` 文案、内容为加入链接的二维码（描述 `QR Code`）和加入链接文本。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:1016
- SY-A20 [ui] 加入链接 = `https://feederapp.nononsenseapps.com/sync/join?sync_code=<syncChainId>&key=<URL编码的secretKey>`，二维码与文本均为该链接。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreenViewModel.kt:233
- SY-A21 [on_device] 点添加设备页的链接文本拉起系统分享面板，分享纯文本链接，标题 `Feeder device sync code`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:1050
- SY-A22 [ui] 返回键/返回按钮：加入页→设置页，添加设备页→设备列表页，设置页/设备列表页→退出同步页（无上一页时到 Settings）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:248
- SY-A23 [ui] 宽屏（宽度类非 Compact）时双栏显示：左栏为设置内容或设备列表（双栏下不显示 `Add new device` 按钮），右栏为加入表单或添加设备二维码；标题 `Device sync`，入链后才显示溢出菜单。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/sync/SyncScreen.kt:480
- SY-A24 [ui] 本机被其他设备移出同步链后（服务端回 `Device not registered`），本机自动离开，同步页显示为设置页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:606

## 域: 同步协议（REST）

- SY-A25 [backend] 客户端基址为 `<syncRemote.url>/api/v1/`，默认 `https://feeder-sync.nononsenseapps.com:443`；所有请求带 Basic 认证 `feeder_user` / `feeder_secret_1234`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/Retrofit.kt:45
- SY-A26 [backend] 初始化时若已存远端 URL 含废弃主机 `feederapp.nononsenseapps.com` 或 `feeder-sync.nononsenseapps.workers.dev`，改写为默认地址并持久化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:56
- SY-A27 [backend] 端点契约：`POST create` {deviceName}→{syncCode,deviceId}；`POST join`（头 `X-FEEDER-ID`）{deviceName}→{syncCode,deviceId}；`GET devices`、`DELETE devices/{deviceId}`→{devices:[{deviceId,deviceName}]}；`GET ereadmark?since=<ms>`→{readMarks:[{timestamp,encrypted}]}；`POST ereadmark` {items:[{encrypted}]}→{timestamp}；`GET feeds`→{hash,encrypted}；`POST feeds`（头 `If-Match`）{contentHash,encrypted}→{hash}。除 create/join 外均带 `X-FEEDER-ID`=syncChainId 与 `X-FEEDER-DEVICE-ID`=deviceId。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/FeederSync.kt:12
- SY-A28 [backend] JSON 字段为 camelCase 属性名，`Instant` 序列化为 epoch 毫秒整数，`URL` 为字符串；解析时忽略未知字段、缺失字段取默认值。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/Moshi.kt:11
- SY-A29 [backend] 新建同步链：使用本地 SyncRemote 已有密钥，发送加密后的设备名；成功后保存 syncChainId=syncCode、deviceId、明文 deviceName、latestMessageTimestamp=EPOCH，并返回 (syncCode, secretKey) 后刷新设备列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:99
- SY-A30 [backend] 加入同步链：先持久化对方密钥与新生成设备名，再以该密钥加密设备名请求 join；成功后保存 syncChainId、deviceId、latestMessageTimestamp=EPOCH 并拉取设备列表；异常返回错误码 999。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:136
- SY-A31 [backend] 离开同步链：对本机 deviceId 调 `DELETE devices/{id}`，无论成功失败都清空内存客户端并把 SyncRemote 重置为默认（新随机密钥、无链），级联删除本地设备表、远端订阅表、远端已读标记与已同步记录。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:204
- SY-A32 [backend] 设备列表：服务器返回的设备名为密文，解密后整体替换本地 `sync_device` 表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:352
- SY-A33 [backend] 未配置同步链（syncChainId 长度≠64 或客户端/密钥未初始化）时所有链内操作直接返回错误码 1001，不发请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:81
- SY-A34 [backend] 上传已读：取所有已读但未记已同步的条目，每 100 条一批，每条加密 `{"feedUrl","articleGuid"}` 后 `POST ereadmark`；某批成功即把该批条目记为已同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:315
- SY-A35 [backend] 拉取已读：`GET ereadmark?since=latestMessageTimestamp+1ms`；逐条解密后写入远端已读标记、若本地有匹配条目则标为已读+已通知+已同步，并把 latestMessageTimestamp 推进到该条时间戳；解密结果为空的条目也推进时间戳后跳过。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:377
- SY-A36 [backend] 拉取订阅：`GET feeds` 的 hash 等于本地 `lastFeedsRemoteHash` 时什么也不做；否则解密 EncryptedFeeds 做差异合并，然后保存新 hash。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:418
- SY-A37 [backend] 订阅差异合并：曾在远端出现而本次远端列表中没有的 URL→本地删除该源；远端新 URL 且本地无且从未见过→新建源；本地无但曾见过→视为本地已删、不恢复；本地有→仅当远端 whenModified 更新时覆盖 12 个同步字段；最后用本次远端 URL 列表替换“远端已见”表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:462
- SY-A38 [backend] 同步的订阅字段固定为：url、title、customTitle、tag、imageUrl、fullTextByDefault、openArticlesWith、alternateId、fetchOgImages、blockRules、allowRules、whenModified。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/RestBodies.kt:96
- SY-A39 [backend] 上传订阅：本地源按 URL 排序转为 EncryptedFeed 列表，计算内容哈希（Java `List.hashCode` 语义），与 `lastFeedsRemoteHash` 相同则不上传；否则加密后 `POST feeds`，`If-Match: W/"<lastFeedsRemoteHash>"`，成功后保存返回的 hash。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:530
- SY-A40 [backend] 上传订阅收到 412 时先拉取订阅合并，再重新上传。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:580
- SY-A41 [backend] 任何链内请求失败且错误体包含 `Device not registered`（忽略大小写）时自动执行离开同步链。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:608
- SY-A42 [backend] HTTP 结果映射：2xx 但无 body→错误码 998 `No body but success`；非 2xx→(状态码, 错误体)；解析异常→999。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/sync/SyncRestClient.kt:635
- SY-A43 [backend] 本机设备名 = 型号以厂商开头时取型号，否则 `厂商 型号`，首字母大写；为空时取 0–99999 随机数字串。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/SyncRemote.kt:59

## 域: 加密

- SY-A44 [backend] 密钥串格式 `base64(16字节AES密钥):base64(32字节HMAC密钥)`（标准 Base64、无换行）；段数≠2 或长度不符即判为不可解码。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/crypto/AesCbcWithIntegrity.kt:83
- SY-A45 [backend] 新密钥 = 随机 128 位 AES 密钥 + 随机 32 字节 HMAC-SHA256 密钥（SecureRandom）；首次创建/重置 SyncRemote 时生成。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/crypto/AesCbcWithIntegrity.kt:121
- SY-A46 [backend] 加密：UTF-8 明文，随机 16 字节 IV，AES/CBC/PKCS5Padding；MAC = HMAC-SHA256(IV‖密文)；输出 `base64(IV):base64(MAC):base64(密文)`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/crypto/AesCbcWithIntegrity.kt:283
- SY-A47 [backend] 解密先恒定时间比较 MAC，不匹配抛 `GeneralSecurityException`、不解密；格式段数≠3 抛参数错误。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/crypto/AesCbcWithIntegrity.kt:355
- SY-A48 [backend] 与 Android 端互通：鸿蒙端用同一密钥加密的设备名/已读标记/订阅列表可被 Android 端解密，反之亦然。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/crypto/AesCbcWithIntegrity.kt:243

## 域: 同步调度

- SY-A49 [backend] 每次 RSS 同步前依次执行 getFeeds→getRead→getDevices→sendUpdatedFeeds→markAsRead，异常只记日志。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:121
- SY-A50 [on_device] 结果契约：本地标记已读（单条/全部/之前/之后）后约 10 秒内（受“仅充电/仅 Wi-Fi”约束）把已读标记上传，重复触发不重复排队；仅在已入链时调度。鸿蒙实现：WorkScheduler 一次性任务或前台延时任务。差异：JobScheduler minimumLatency/去重语义需自行实现。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/SyncChainSendReadJob.kt:52
- SY-A51 [on_device] 结果契约：应用回到前台且开启“恢复时同步”且网络/充电条件满足时，拉取远端已读→应用远端已读→刷新设备列表；仅在已入链时调度。鸿蒙实现：UIAbility onForeground 触发。差异：无 JobScheduler 网络条件，需前置检查。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/SyncChainGetUpdatesJob.kt:31
- SY-A52 [backend] 本地把条目标为未读时删除其已同步记录（不向服务器发未读事件）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:527
