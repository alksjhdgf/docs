# edit-search 订阅源添加/编辑/搜索/删除/OPML 导入屏 断言卡

## 页面: SearchFeed
- EF-A01 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:128
- EF-A02 [ui] 顶栏标题 `Add feed`；左侧返回按钮（无障碍 `Go back`）点击返回上一页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:132
- EF-A03 [ui] 单行输入框标签 `Feed URL`（testTag `urlField`），下方 `Search` 按钮；输入为空白时按钮禁用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:391
- EF-A04 [ui] 输入合法判定：原样能解析为 URL，或在前面加 `http://` 后能解析即合法（如 `cowboyprogrammer.org` 合法、按钮可用）；非空且不合法时输入框呈错误态、按钮禁用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:782
- EF-A05 [ui] 点 `Search`、软键盘搜索键或硬件 Enter 均在输入合法时发起搜索（无协议输入按 `http://` 补全）并收起键盘/清除焦点；Escape 清除焦点。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:405
- EF-A06 [ui] 搜索进行中显示圆形进度指示（testTag `searchingIndicator`），此时不显示错误卡；结果卡随每个候选解析完成逐条追加，搜索结束指示消失。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:212
- EF-A07 [ui] 修改输入框内容立即取消进行中的搜索，并清空结果与错误、隐藏进度指示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:204
- EF-A08 [ui] 结果卡（testTag `searchResult`）依次显示：订阅源标题、描述（非空白才显示）、订阅源 URL；点击进入 AddFeed 页并带入该结果的 url、标题、站点图片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:554
- EF-A09 [ui] 仅当无任何结果且未在搜索时显示错误卡（testTag `errorResult`）：错误色标题、URL、错误描述、`Add anyway` 按钮；点 `Add anyway` 进入 AddFeed 页，url 与标题均为该错误的 URL、图片为空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:485
- EF-A10 [ui] 错误卡标题按错误类型映射：FetchError→`Failed to download`、MetaDataParseError→`Failed to parse the page`、NoAlternateFeeds→`No feeds in the page`、NotHTML→`Content is not HTML`、RSSParseError→`Failed to parse RSS feed`、HttpError→`HTTP error`、JsonFeedParseError→`Failed to parse JSON feed`、NoBody→`No body in response`、UnsupportedContentType→`Unsupported content type`、FullTextDecodingFailure→`Failed to parse full article`、FullTextTooLarge→`Article is too large. Open in browser instead?`、NoUrl→`No URL`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:488
- EF-A11 [ui] 输入变化 150ms 防抖后，长度 ≥2 时在结果区顶部显示本地推荐（标题 `Suggestions`，每项为卡片：标题、作者描述、URL），长度 <2 时推荐清空；推荐不受搜索按钮影响，与搜索结果同时显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:187
- EF-A12 [ui] 点推荐项进入 AddFeed 页，带入推荐的 feed_url、headline 作为标题，图片为空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:129
- EF-A13 [ui] 以 `feedUrl` 参数打开本页时输入框预填该值，若合法则自动发起一次搜索（无需点按钮）；参数缺省时输入框为空、不搜索。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:273
- EF-A14 [ui] 宽屏（ScreenType.DUAL）左右两栏：左输入+按钮、右推荐/结果/错误；窄屏单栏上下排列，整体可纵向滚动。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedScreen.kt:295

## 域: 订阅源发现（SearchFeed 搜索管线）
- EF-A15 [backend] 搜索先抓取输入 URL 的站点元数据：成功时对每个 alternate 订阅链接依次产出候选；链接为 YouTube `feeds/videos.xml?channel_id=UC<22位>` 时，紧随其后再产出 `https://www.youtube.com/feeds/videos.xml?playlist_id=UULF<id>`、`UUSH<id>`、`UULV<id>` 三个候选。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:55
- EF-A16 [backend] 站点元数据成功但没有任何 alternate 链接时产出错误 NoAlternateFeeds(输入URL)；元数据失败（如输入本身就是 RSS/Atom 地址、非 HTML）时直接把输入 URL 当作候选订阅源。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:66
- EF-A17 [backend] 每个候选以 parseFeedUrl 解析：成功得结果（title=订阅标题或空串、url=feed_url 或候选 URL、description=订阅描述或空串、feedImage=站点元数据的 feedImage 或空串）；失败产出对应错误。若初始站点元数据失败而订阅含 home_page_url，则改抓该主页的站点元数据以取得图片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:75
- EF-A18 [backend] 搜索中遇到带 Retry-After 的 HTTP 错误时，把同 host 的已订阅源的 retry_after 设为 当前时间+Retry-After 秒。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:102

## 页面: Search
- EF-A19 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:27
- EF-A20 [ui] 分享/打开链接进入时显示与 SearchFeed 相同的搜索界面（标题 `Add feed`），输入框预填共享文本，合法时自动发起搜索并显示结果，无需点 `Search`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:43
- EF-A21 [ui] 点结果/推荐/`Add anyway` 进入同一流程内的 AddFeed 页，带入 url、标题、图片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt:48

## 页面: AddFeed
- EF-A22 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:211
- EF-A23 [ui] 顶栏标题为 `Edit feed`（添加与编辑共用同一标题）；返回按钮（`Go back`）回到上一页且不保存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:215
- EF-A24 [ui] 进入时 `URL` 框预填带入的 url，`Title` 框预填并以占位符显示带入的标题；其余开关全关、打开方式为 `Use app default`、规则为空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/CreateFeedScreenViewModel.kt:37
- EF-A25 [ui] 表单自上而下为：`URL`、`Title`、`Tag`；分隔线；开关 `Fetch full articles by default`、`Summarize on open`、`Enhance thumbnails from article metadata`（说明 `Try to improve missing or low-quality thumbnails for this feed`）、`Notify for new items`、`Skip duplicate articles`（说明 `Articles with links or titles identical to existing articles are ignored`）、`Generate extra unique IDs`（说明 `Only enable for feeds with bad IDs`）；分隔线；分组 `Open items by default with`；分隔线；分组 `Article filtering rules`；底部 `Cancel`、`OK`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:489
- EF-A26 [ui] `URL` 框每次输入后自动去除首尾空白；内容不能被 java.net.URL 解析（如缺协议的 `example.com`、空串）时输入框呈错误态并在下方显示 `Not a valid URL`，`OK` 禁用；合法时提示消失、`OK` 可用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:352
- EF-A27 [ui] `URL`、`Title` 框按回车/Next 键焦点移到下一字段；`Tag` 框按 Done/回车收起键盘并把焦点移到第一个开关。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:463
- EF-A28 [ui] `Tag` 框获得焦点时，在其下方显示已有标签候选：仅非空白且以当前输入开头（忽略大小写）的标签，按不区分大小写字母序；点候选把标签填入、关闭候选并把焦点移到第一个开关。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:335
- EF-A29 [ui] `Open items by default with` 为单选组，选项依次 `Use app default`（存 ``）、`Reader`（存 `0`）、`Custom tab`（存 `3`）、`Default browser`（存 `2`）；存量值为 `1`（WebView）时四项均不选中。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:541
- EF-A30 [ui] `Article filtering rules` 分组下有说明文字及 `Block rules`、`Allow rules` 两个多行输入（等宽字体、3–8 行、占位 `Title=(?i)sponsored`，各自带说明文字）；回车插入换行而非跳转焦点。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:582
- EF-A31 [ui] 规则框内容有误时输入框呈错误态并在下方显示首个错误：`Line N: missing '='. Invalid lines are ignored.`／`Line N: 'X' is not a known field. Invalid lines are ignored.`／`Line N: the pattern is empty, which would match everything. Invalid lines are ignored.`／`Line N: not a valid regular expression. Invalid lines are ignored.`／`Line N: only the first 100 rules are used. Later lines are ignored.`；规则错误不禁用 `OK`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:661
- EF-A32 [backend] 规则解析：逐行 trim，空行跳过但行号照计；按首个 `=` 拆分字段名与模式；字段名 Title/URL/Author/Tag/Content 不区分大小写；模式为空报 EmptyPattern；正则编译失败报 InvalidRegex；已有 100 条有效规则后再遇有效行报 TooManyRules 并停止解析。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ArticleFilterRules.kt:149
- EF-A33 [on_device] 结果契约：打开 `Notify for new items` 时若通知权限未授予则先申请，授予后开关才变为开、拒绝则保持关；系统要求先解释时弹出对话框 `Permission must be granted before notifications can be enabled.`，点 `OK` 发起申请、点外部关闭；关闭开关无需权限；鸿蒙实现：notificationManager.isNotificationEnabled + requestEnableNotification；差异：Android 13 以下视为已授权直接打开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:178
- EF-A34 [ui] 点 `Cancel` 等同返回，不保存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:114
- EF-A35 [backend] 点 `OK` 新建订阅源：url=URL 框、title 与 customTitle 均=Title 框、tag、6 个开关、打开方式、两组规则原文、imageUrl=带入图片（不可解析则空）、whenModified=当前时间；随后对该源触发一次非用户触发的同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/CreateFeedScreenViewModel.kt:95
- EF-A36 [ui] 保存后跳转到 Feed 页并显示新订阅源（清空此前返回栈）；分享流程中保存后直接结束分享流程。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:271
- EF-A37 [ui] 宽屏（ScreenType.DUAL）表单分左右两栏：左 URL/Title/Tag，右开关/打开方式/规则；窄屏单栏中间以分隔线隔开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:272

## 页面: EditFeed
- EF-A38 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:211
- EF-A39 [ui] 顶栏标题 `Edit feed`，返回按钮（`Go back`）回到上一页且不保存；`Cancel` 同返回。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:135
- EF-A40 [ui] 表单字段、顺序、校验、Tag 候选、打开方式单选、规则错误提示、通知权限流程与 AddFeed 页一致（EF-A25～EF-A33、EF-A37）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:152
- EF-A41 [ui] 进入时按 feedId 读取订阅源并预填：URL、Title=显示标题（自定义标题非空白用之，否则原标题）、Tag、6 个开关、打开方式、两组规则；Title 占位符显示订阅源原标题。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreenViewModel.kt:92
- EF-A42 [ui] 已编辑但未保存的字段在旋转/进程重建后保留，不被数据库值覆盖。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreenViewModel.kt:102
- EF-A43 [backend] 点 `OK`：以表单值覆盖 url、title、customTitle、tag、6 个开关、打开方式、规则（imageUrl 等其它字段保持不变）；与原记录完全相同时不写库也不同步；有变化时 whenModified=max(当前时间, 原值+1ms) 后更新并对该源触发一次非用户触发的同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreenViewModel.kt:146
- EF-A44 [ui] 保存后（无论是否有改动）跳转到 Feed 页显示该订阅源并清空返回栈。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:309
- EF-A45 [ui] 清空 Title 后保存，订阅源显示名回退为订阅源原标题（随同步更新）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Feed.kt:73

## 页面: Import
- EF-A46 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:158
- EF-A47 [ui] 顶栏标题 `Import feeds from OPML`，左侧返回按钮（`Go back`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:162
- EF-A48 [ui] 打开即解析文件做预览（不写库、不导入设置）：解析中摘要为空；无文件 URI 或读取/解析抛异常时显示 `Failed to import OPML`；解析出 0 个订阅源显示 `No feeds`；否则显示 `Import <N feed(s)> with <M tag(s)>?`（单数 `1 feed`/`1 tag`，其余 `N feeds`/`M tags`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:213
- EF-A49 [backend] 预览中 N=按 URL 去重后的订阅源数；M=其中 tag 非空白的订阅源个数（非去重标签数）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:286
- EF-A50 [ui] 摘要下方列出预览订阅源（按标题排序），每项显示标题与 URL。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:239
- EF-A51 [ui] 底部 `Cancel`、`OK`；`OK` 仅在预览至少 1 个订阅源时可用；`Cancel` 关闭导入页且不导入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:201
- EF-A52 [backend] 点 `OK` 在应用级后台作用域执行完整 OPML 导入（订阅源按 url 新增或覆盖、导入设置与屏蔽词）并触发一次用户触发的同步，即使导入页随即关闭也会完成。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/ompl/OpmlImportScreen.kt:177

## 域: 删除订阅源对话框（Feed 页 `Delete feed`）
- EF-A53 [ui] 对话框标题 `Delete feed`，右上角溢出按钮（无障碍 `Open menu`）展开菜单仅含带复选框的 `Select all` 项。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/deletefeed/DeleteFeedScreen.kt:112
- EF-A54 [ui] 正文列出当前范围（单个订阅源/某标签/全部）可见订阅源，按原标题不区分大小写排序，每行复选框+显示标题；初始全部未勾选。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1320
- EF-A55 [ui] 点整行或复选框切换该订阅源的勾选状态；行的无障碍状态描述为 `Selected`/`Not selected`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/deletefeed/DeleteFeedScreen.kt:191
- EF-A56 [ui] `Select all` 复选框在全部已勾选时为选中；点击时若未全选则全选，已全选则全部取消；点击后菜单关闭。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/deletefeed/DeleteFeedScreen.kt:131
- EF-A57 [ui] `OK` 删除所有已勾选订阅源并关闭对话框（无勾选时仅关闭）；`Cancel` 或点对话框外部仅关闭不删除。勾选状态在旋转后保留。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/deletefeed/DeleteFeedScreen.kt:71
- EF-A58 [backend] 删除订阅源同时级联删除其全部文章；移除这些订阅源的桌面动态快捷方式；若当前正浏览被删订阅源则切换到“全部订阅”。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:589
