# app-shell 应用壳断言卡

## 页面: Main
- APP-A01 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:96
- APP-A02 [ui] 从桌面图标冷启动（无深链参数）首屏为 Feed 页，显示上次打开的 feed/tag（首次安装为默认值 `ID_UNSET`/空 tag）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:110
- APP-A03 [backend] 启动参数 id/tag 均为空时不改写当前 feed/tag；当前 feed/tag 初值取自持久化 `pref_last_feed_id`/`pref_last_feed_tag`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:424
- APP-A04 [ui] 以 `https://feederapp.nononsenseapps.com/feed?id={id}&tag={tag}` 启动或在已运行时再次打开，进入 Feed 页并切换到该 feed/tag，且返回栈被清空（Feed 为唯一栈底）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:369
- APP-A05 [ui] 以 `https://feederapp.nononsenseapps.com/article/{itemId}` 打开时直接显示该文章阅读页，且该文章被标记为已读并已通知。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/NavigationDeepLinkViewModel.kt:24
- APP-A06 [ui] 以 `https://feederapp.nononsenseapps.com/sync/join?sync_code={c}&key={k}` 打开时进入同步页并带入 syncCode 与 secretKey。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:511
- APP-A07 [ui] 应用已在前台/后台时收到新深链（单实例复用），在现有导航栈上导航到目标页而不新建第二个主界面实例；无法识别的链接被忽略且停留当前页、不崩溃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:125
- APP-A08 [ui] 文章页由深链直接进入时点返回（栈中无上一页）落到 Feed 页而非退出应用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:481
- APP-A09 [ui] 同步页由深链直接进入时点返回（栈中无上一页）落到 Settings 页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:546
- APP-A10 [ui] 设置页在栈中无上一页时点返回落到 Feed 页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:334
- APP-A11 [on_device] 开启“恢复时同步”(`pref_sync_on_resume`)且满足联网、(仅充电→正在充电)、(仅 Wi-Fi→非计费网络) 时，应用回到前台自动触发一次同步链更新+RSS 同步（非用户触发、不强制网络）；条件不满足则不触发。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:74
- APP-A12 [on_device] 阅读文章且开启分页模式时，音量上/下键滚动文章内容而不调节音量；非分页模式或不在文章页时音量键保持系统行为。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:59
- APP-A13 [backend] 主界面创建时确保周期 RSS 同步已调度（已存在则不替换），并确保每日孤儿正文文件清理作业已调度（需空闲+充电，已存在则不重复）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:91
- APP-A14 [backend] 主界面处于前台期间持续监听需通知条目：条目消失则取消其通知，列表为空则取消汇总通知；进入后台停止监听。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/notifications/NotificationsWorker.kt:31
- APP-A15 [backend] 每次回到前台记录 resume 时间（会话级）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:51
- APP-A16 [backend] 进入某具体 feed（id>0）时将其登记为最近使用（源为动态桌面快捷方式，最多 3 个，超出淘汰 rank 最低者）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:119
- APP-A17 [backend] 切换到与当前不同的 feed/tag 时持久化新 feed/tag 并把最小已读时间设为当前时刻；相同则不变。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:132

## 页面: ManageSettings
- APP-A20 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt:22
- APP-A21 [ui] 从系统流量管理入口(`MANAGE_NETWORK_USAGE`)进入时直接显示完整设置页（与应用内 Settings 相同内容与行为）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt:26
- APP-A22 [ui] 点返回/向上时打开主界面（Feed）并关闭本页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt:27
- APP-A23 [ui] 点同步设置项时打开主界面的同步页并关闭本页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt:30
- APP-A24 [ui] 点文字设置项时进入文字设置页且不崩溃（源以空深链列表 `.first()` 崩溃，属源缺陷，迁移须修正为打开主界面文字设置页）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt:41

## 页面: ImportOPMLFile
- APP-A30 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt:27
- APP-A31 [on_device] 在文件管理器中打开 MIME 为 `text/xml`/`application/xml`/`text/x-opml`/`application/octet-stream` 的文件时，系统可选择 Feeder 打开并显示 OPML 导入页（标题 `Import feeds from OPML`）。锚点：input/Feeder/app/src/main/AndroidManifest.xml:92
- APP-A32 [ui] 导入页以传入文件 URI 作为导入源。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt:29
- APP-A33 [ui] 导入确认(OK)后打开主界面并定位到“全部订阅”(`id=-10`)Feed，同时关闭导入页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt:51
- APP-A34 [ui] 取消(Dismiss)仅关闭导入页，不打开主界面。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt:48
- APP-A35 [ui] 点向上导航打开主界面并关闭导入页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt:44
- APP-A36 [ui] 导入页不出现在最近任务列表中。锚点：input/Feeder/app/src/main/AndroidManifest.xml:94

## 页面: AddFeedFromShare
- APP-A40 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:27
- APP-A41 [on_device] 从其它应用分享纯文本或 http/https 链接，或打开 MIME 为 `application/rss+xml`/`application/atom+xml`/`text/xml`/`application/xml`/`application/json` 的 http(s) 链接时，可选择 Feeder 接收。锚点：input/Feeder/app/src/main/AndroidManifest.xml:115
- APP-A42 [ui] 接收后首屏为搜索订阅源页，输入框预填 链接数据（优先）或分享文本，首尾空白已去除。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:29
- APP-A43 [ui] 点选搜索结果进入添加订阅页，带入结果的 url、标题、图片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:48
- APP-A44 [ui] 添加订阅页点返回回到搜索页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:69
- APP-A45 [ui] 添加订阅页保存成功后关闭整个分享流程（不跳转主界面）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:73
- APP-A46 [ui] 搜索页点向上导航打开主界面并关闭分享流程。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:44

## 页面: OpenLinkInDefault
- APP-A50 [ui] 顶部内容避让状态栏，不与状态栏重叠（本页无自有界面，不得闪现空白页；拉起的主界面满足避让）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:58
- APP-A51 [on_device] 点击汇总通知：通知所含条目全部标记为已通知（不标已读），随后打开主界面并定位到通知 URI 指定的 feed/tag。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:35
- APP-A52 [on_device] 点击单篇通知（打开方式为浏览器/CustomTab 且有链接）：该条目标记为已读并已通知、对应通知被取消，并用默认浏览器（CustomTab 动作则用应用内浏览标签）打开文章链接。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:61
- APP-A53 [backend] 通知代理中的“标记已读/已通知”写库必须完成，不得因代理页立即关闭而被取消。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:65
- APP-A54 [ui] 无可处理链接的应用时弹出 Toast `Install something to open this link with first`，不崩溃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:86
- APP-A55 [ui] 代理处理完毕立即结束自身，不在最近任务/主任务栈中留下额外页面。锚点：input/Feeder/app/src/main/AndroidManifest.xml:164

## 域: 导航路由
- APP-A60 [backend] 路由集合与参数：`feed?id={id}&tag={tag}`(id 默认 0, tag 默认 "")、`reader/{itemId}`、`edit/feed/{feedId}`、`search/feed?feedUrl={feedUrl}`、`add/feed/{feedUrl}?feedTitle=&feedImage=`、`settings`、`sync?syncCode=&secretKey=`、`font/add`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:141
- APP-A61 [backend] 深链只有三种：`/feed?id=&tag=`→Feed、`/article/{itemId}`→Article、`/sync/join?sync_code=&key=`→SyncScreen，基址 `https://feederapp.nononsenseapps.com`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:110
- APP-A62 [backend] 查询参数构造跳过 null/空值，值做 URI 编码；AddFeed 的 feedUrl 作为路径段编码。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:564
- APP-A63 [ui] 导航到 Feed 时清空整个返回栈并避免重复实例；其它目的地均 singleTop（重复导航到同一目的地不叠加）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:388
- APP-A64 [ui] 应用内添加订阅或编辑订阅保存后跳转到该订阅的 Feed 页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:270
- APP-A65 [backend] 进入 Feed 页设置 isArticleOpen=false，进入 Article 页设置 isArticleOpen=true 与当前文章 id。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/NavigationDeepLinkViewModel.kt:21

## 域: 应用初始化
- APP-A70 [backend] 进程级单例：数据库与全部 DAO、HTTP 客户端、图片加载器、Repository 及各 Store、同步/解析/全文/翻译组件在应用内唯一；Feed 解析器每次使用新实例。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/di/NetworkModule.kt:20
- APP-A71 [backend] Feed HTTP 客户端带 200MB 磁盘缓存，依次应用 UserAgent、限速、部分失败强制用缓存、429 处理拦截器。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:122
- APP-A72 [backend] 开启“仅 Wi-Fi 加载图片”且当前为计费网络时，图片请求只走缓存（无缓存则不加载）；图片使用独立 300MB 网络缓存与 200MB 磁盘缓存，支持 .ico 图标解码。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:161
- APP-A73 [backend] 所有设置持久化在单一默认键值存储（SharedPreferences）中，各 Store 共享。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:112
- APP-A74 [ui] 所有带界面的入口（Main/ManageSettings/ImportOPMLFile/AddFeedFromShare）统一应用用户选择的主题、暗色偏好、动态取色、文字缩放与字体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ComposeProviders.kt:22
- APP-A75 [backend] 存储目录约定：摘要正文 `files/articles`、全文 `cache/full_articles`、字体 `files/fonts`、HTTP 缓存 `cache/http`、图片缓存 `cache/image_cache`/`cache/http_image_cache`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/FilePathProvider.kt:47
- APP-A76 [backend] 全局后台作用域使用监督式任务（单个子任务失败不取消其它）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ApplicationCoroutineScope.kt:8
- APP-A77 [on_device] 允许订阅明文 http 源（cleartext 放行）。锚点：input/Feeder/app/src/main/AndroidManifest.xml:49

## 域: 对外数据接口
- APP-A80 [backend] 只读接口 `feeds` 返回列 id,title，按 title 排序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:117
- APP-A81 [backend] 只读接口 `articles` 返回未屏蔽文章的 id,title,text(纯文本摘要)，按 primary_sort_time、pub_date 降序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:115
- APP-A82 [backend] 只读接口 `articles/{feedId}` 返回该 feed 下未屏蔽文章（同列同序）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:125
- APP-A83 [backend] 对外接口拒绝插入/更新/删除；访问需 `<applicationId>.permission.read` 读权限。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/contentprovider/RSSContentProvider.kt:44

## 域: Blob
- APP-A90 [backend] 文章摘要正文存为 `<itemId>.txt.gz`（gzip）于 articleDir。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/blob/Blob.kt:13
- APP-A91 [backend] 文章全文存为 `<itemId>.full.html.gz`（gzip）于 fullArticleDir。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/blob/Blob.kt:30
