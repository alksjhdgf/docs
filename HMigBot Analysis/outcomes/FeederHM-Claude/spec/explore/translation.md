# 探索文档：translation（翻译域）

断言前缀：TR。断言卡：`spec/cards/translation.md`。
源根：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/`（下文简写 `F/`）。

## 1. 范围与文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| `F/model/TranslationManager.kt` | 738 | 翻译编排：缓存（磁盘 JSON）、"已是目标语言"判定、按 provider 分派（Local / DeepL），文章 & 列表卡片两条入口 |
| `F/model/TranslationLanguageUtils.kt` | 194 | 语言检测前文本准备（HTML→纯文本、空白折叠、4000 字截断、三段采样）；检测语言 vs 目标语言的比对（DeepL 名称/代码映射、区域匹配、nb→no） |
| `F/localtranslation/LocalTranslator.kt` | 661 | 本地离线翻译：先走 Android 系统 on-device 翻译（API 31+ `android.view.translation`），失败回退 Bergamot；HTML 按文本节点逐个翻译保留标签 |
| `F/localtranslation/BergamotModelManager.kt` | 713 | Bergamot 模型 registry（Mozilla Remote Settings）拉取/缓存/解析、英语中转路径、模型文件下载（SHA-256 校验、临时文件+原子移动）、WASM 运行时下载、下载进度 StateFlow、已下载语言对列举/删除 |
| `F/localtranslation/BergamotWebTranslator.kt` | 240 | 隐藏 WebView 承载 `assets/bergamot/index.html`，JS 桥 `AndroidBergamot`，调用 `window.FeederBergamot.initialize/translateBatch` |
| `F/localtranslation/TranslationLanguageCodes.kt` | 39 | `normalizeLanguageCode`：语言名/别名→两字母码（norwegian/nb/nn→nb） |
| `input/Feeder/app/src/main/assets/bergamot/` | — | `index.html`(10 行) + `feeder-bergamot.js`(133 行, Feeder 自写胶水) + `translator.js`(34KB, @browsermt/bergamot-translator 改造版) + `worker/translator-worker.js` + `worker/bergamot-translator-worker.js`(Emscripten 胶水, `BERGAMOT_VERSION_FULL = "v0.4.5+4917c11"`)。**WASM 二进制不随包，运行时下载** |

依赖（非本区但为契约所需）：
- `F/openai/OpenAIApi.kt`：`TranslationResult{Success(content, detectedLanguage), Error(content, action)}`、`ErrorAction{None, DownloadBergamotRuntime, OpenSystemTranslationSettings}`（:79-96）；DeepL 翻译 `translateWithDeepL`（:239）；扩展属性 `isDeepL`(baseUrl 含 `deepl.com`, :373)、`isLocalTranslation`(baseUrl == `local://translation`, :376/:503)、`isValid`(:379)、`canTranslate = isValid`(:394)、`canUseAsTranslationApi = canTranslate && (isDeepL || isLocalTranslation)`(:397)。OpenAI/Azure 等 LLM provider **不能作翻译**：`translate()` 对非 DeepL/非 Local 返回 Error（:233-237）。
- `F/model/ReadAloudStateHolder.kt:400` `Context.detectLocaleFromText(text, minConfidence)`：基于 `TextClassificationManager.textClassifier.detectLanguage`，返回置信度≥阈值的 locale 序列（API 29+）。
- `F/archmodel/SettingsStore.kt:553-603,754-764`：`translationApiSettings`（`TranslationApiSettings = OpenAISettings` 类型别名 :918）、`preferredTranslationLanguage`（key `pref_openai_translation_language`）、`translateArticlePreviewsByDefault`（`pref_translate_feed_cards_by_default`, 默认 false）、`translateArticlesByDefault`（`pref_translate_articles_by_default`, 默认 false）。
- DI：`F/di/ArchModelModule.kt:55-58` 四者均 singleton（BergamotModelManager、BergamotWebTranslator、LocalTranslator、TranslationManager）。

消费者（UI 层）：
- `F/ui/compose/feedarticle/ArticleViewModel.kt`（文章翻译状态机）
- `F/ui/compose/feedarticle/FeedViewModel.kt:201-345,734-790`（列表卡片翻译）
- `F/ui/compose/feedarticle/ArticleScreen.kt:380-405`（菜单项）、`:579-640`（两对话框）、`:703-709`、`:795`（进度卡）
- `F/ui/compose/feed/FeedScreen.kt:1308`（下载进度浮层）、`:1460-1466`（卡片 merge + LaunchedEffect 触发翻译）
- `F/ui/compose/components/TranslationProgressContent.kt`（进度文案）
- `F/ui/compose/settings/Settings.kt:866-931`（AI and translation 组）、`:1644+`（DownloadedModelsSection）、`F/ui/compose/settings/OpenAISection.kt:481-498,594-760,910-964,1139-1210`（Provider/语言选择/仅 Bergamot 语言开关）
- `F/ui/compose/settings/SettingsViewModel.kt:218-250`（下载模型列举/删除）

## 2. 数据模型

### 2.1 翻译缓存（TranslationManager）
- 文件：`<cacheDir>/translations/<itemId>.<provider>.<lang>.json`（`TranslationManager.kt:458-480`）
  - provider ∈ `local`/`deepl`/`openai`（实际 openai 分支不可能被翻译用到，但命名保留）
  - lang = 目标语言 trim→lowercase→`[^a-z0-9._-]+`替换为`_`，空则 `default`
- 内容 `CachedTranslations`（`:695-706`，kotlinx JSON，`ignoreUnknownKeys`）：
  `sourceLanguage`(默认"")、`titleHash/translatedTitle`、`snippetHash/translatedSnippet`、`articleHtmlHash/translatedArticleHtml`（摘要/RSS 正文模式）、`fullArticleHtmlHash/translatedFullArticleHtml`（全文模式）。
- Hash = 原文 UTF-8 的 SHA-256 小写 hex（`:482-486`）。原文变化→hash 不匹配→缓存失效。
- 解析失败视为空缓存（`:444`）。无任何清理逻辑（无过期、无删除 item 时联动），仅依赖系统清 cache。
- `isUsableCachedTranslation`（`:714-732`）：缓存译文非空；若译文≠原文直接可用；若译文==原文（"已是目标语言"写入的回声）则仅当 sourceLanguage 为空或 sourceLanguage 匹配目标语言时可用。

### 2.2 Bergamot 模型存储（BergamotModelManager）
- 根：`<filesDir>/translation-models/bergamot/`（`:41`）
  - `registry-v3.json`：registry 原文缓存，7 天新鲜期（`REGISTRY_MAX_AGE_MS`, :552）
  - `bergamot-translator-worker.wasm`：运行时，固定 5,174,294 字节、SHA-256 `95a2b58d…71b2`（:553-557）；下载源 `https://cdn.jsdelivr.net/npm/@browsermt/bergamot-translator@0.4.5/worker/bergamot-translator-worker.wasm`
  - `<from>-<to>/`：每语言对目录，文件名为 registry name 的末段并把 `[^A-Za-z0-9._-]+` 替换为 `_`；下载成功后写 `model.json`（含本地 `file://` url 的 entry）（:428）
- Registry URL：`https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/translations-models/records?_limit=10000`；附件基址 `https://firefox-settings-attachments.cdn.mozilla.net/`；legacy 基址 `https://bergamot.s3.amazonaws.com/models`。
- 解析（`:256-344`）：
  - JSON 根含 `data` → Mozilla 格式：过滤 `filter_expression` 为空或恰为 `env.appinfo.OS == 'Android'` 的记录（:580-585）；按 (from,to,version) 分组；只取 fileType ∈ {model, lex, vocab, srcvocab, trgvocab}；完整性 = model+lex+(vocab 或 srcvocab+trgvocab)（:562）；同 from/to 多版本择优：稳定版（纯数字点分）优先，再按版本号数字段比较（:303-328）。
  - 否则 legacy 格式：key 前 4 字符为 `fromto`，值为 part→{name,size,expectedSha256Hash,config}。
- 路径解析 `resolvePath`（:375-393）：直连对优先；否则若两端都不是 `en`，用 `src→en` + `en→tgt` 两段中转；一端是 en 且无直连 → null（不可用）。
- 数据类：`BergamotModelRegistryEntry(from,to,files)`、`BergamotModelFile(name, remoteUrl, size, expectedSha256Hash, url?, config?)`、`LanguagePairInfo(source,target,sizeBytes)`、`BergamotModelDownloadProgress(sourceLanguage,targetLanguage,fileName,downloadedBytes,totalBytes,isRuntimeDownload)`（`isIndeterminate = totalBytes<=0`, `fraction` 夹到 0..1）。
- 枚举：`BergamotLanguagePairStatus{RegistryMissing, Unavailable, AvailableToDownload, Downloaded}`；`BergamotModelPreparation{Ready(list), Error(reason∈RegistryMissing/NoAppModel/DownloadFailed, src, tgt)}`。

## 3. 行为

### 3.1 TranslationManager
入口：
1. `getCachedTranslatedFeedListItem(item, settings, target)`（:43）：只读缓存，返回 `(item with cached title/snippet, hasCachedTranslation, isFullyCached)`；空白 title/snippet 视为 ready。
2. `translateFeedListItem(item, settings, target)`（:100）：
   - 不可翻译（`!canTranslate` 或 target 空）→原样返回。
   - 缓存全命中→返回缓存。
   - 用 title+snippet 做"已是目标语言"检测（minConfidence 95%，所有样本都需匹配，`:564-606`），是→把原文写入缓存（作为"译文"）并返回原样。
   - 先翻译 snippet（hint=缓存 sourceLanguage），再翻译 title（hint=snippet 检测出的源语言），失败返回 null（不抛）；成功部分写回缓存，失败部分保留旧缓存值。返回译文，空则原文。
3. `getOrTranslateArticle(itemId, title, html, isFullText)`（:260）：
   - 使用 `translationSettings()`：仅当设置 `canUseAsTranslationApi`（DeepL 或 Local）才用，否则空设置（→不可翻译，返回 null）(:488)。
   - 缓存 html（按 isFullText 选字段）+ title 均命中→返回。
   - "已是目标语言"检测（title + html，preserveHtml=true）→命中则写缓存并返回原文 + sourceLanguage。
   - 翻译 html（preserveHtml=true）→再翻译 title；**失败抛异常**：`BergamotRuntimeDownloadRequiredException`（ErrorAction.DownloadBergamotRuntime）、`SystemTranslationSettingsRequiredException`（ErrorAction.OpenSystemTranslationSettings）、其它 `IllegalStateException(message 或 "Translation failed")`（:511-539）。
   - 写缓存（另一模式的 html 字段保持不变）。
4. `hasCachedTranslatedArticle(...)`（:379）：纯缓存判定。
5. `detectArticleAlreadyInTargetLanguage(itemId,title,html,isFullText)`（:416/:608）：先看缓存 sourceLanguage 是否已匹配目标；否则检测；命中写缓存。
- 分派 `translate()`（:541）：`isLocalTranslation` → `LocalTranslator.translate`；否则 `OpenAIApi.translate`（DeepL）。
- 所有工作在 `Dispatchers.IO`。

### 3.2 语言检测/匹配（TranslationLanguageUtils）
- `prepareTextForLanguageDetection`：preserveHtml 时 Jsoup `.text()`，`\s+`→空格，trim，截 4000 字符（:16-23）。
- `prepareTextSamplesForLanguageDetection`：>4000 时取 头/中/尾 三段各 4000，去重（:25-45）。
- `hasEnoughTextForLanguageDetection`：字母数≥20（:60）。
- `detectedLanguageMatchesTranslationTarget(detected, target, settings)`（:62）：语言相同且（目标无区域或区域相等）。目标解析：DeepL 时用名称/代码映射表（`ENGLISH`/`EN`→en，`EN_GB`→en-GB，`PT_BR`→pt-BR，`NB`/`NORWEGIAN`→no …，:113-155），否则先尝试同表再回退 BCP47 解析；`nb` 规范化为 `no`（:190-194）。检测语言 `_`→`-` 后按 BCP47 解析。
- 测试锚点：`input/Feeder/app/src/test/java/com/nononsenseapps/feeder/model/TranslationLanguageUtilsKtTest.kt`（DeepL 泛英语匹配区域变体、区域目标须精确匹配、nb 匹配 Norwegian、HTML 剥离、长文采样）。

### 3.3 LocalTranslator
- `translate(content, targetLanguage, sourceLangHint, preserveHtml)`（:44）：
  1. SDK < 31 → Error `local_translation_requires_android_12`（"Local translation requires Android 12 or newer."）。（注：minSdk=29）
  2. 准备后文本为空 → Success(原文, "")。
  3. target = `normalizeLanguageCode`；source = hint 或检测（minConfidence 60，多样本取众数，失败 `und`，:561-586）。
  4. source==target → Success(原文)。
  5. 先 Android 系统 on-device 翻译（`TranslationManager.createOnDeviceTranslator`，创建超时 5s，翻译超时 20s，:599-600）；成功即返回。
  6. 否则 Bergamot（HTML 或纯文本）。
- HTML 翻译（两条路径共用思路，:150-197 / :226-274）：`Jsoup.parseBodyFragment`，递归收集所有 TextNode，剥离首尾空白，仅翻译字母≥20 的节点；译文回填并保留首尾空白；输出 `body().html()`。字母<20 的短文本节点（如短链接文字、按钮）**不翻译**。
- Bergamot 前置检查（:303-339）：
  - `languagePairStatus`（允许联网）：RegistryMissing → Error `bergamot_model_registry_unavailable`（"Connect to download model list."）；Unavailable → Error `no_bergamot_translation_model`（"No Bergamot model for %1$s -> %2$s. Check system translation languages"）+ action OpenSystemTranslationSettings。
  - 运行时未下载 → Error `bergamot_runtime_download_required` + action DownloadBergamotRuntime。
  - `prepare()` 下载模型；NoAppModel → 同 Unavailable；RegistryMissing；DownloadFailed → `bergamot_model_download_failed`（"Could not download %1$s -> %2$s model."）。
  - WebView 翻译整体超时 5 分钟 → `bergamot_translation_timed_out`；错误消息取首个非空行截 80 字符，空则 `bergamot_translation_failed`。
- `canTranslateWithoutBergamotDownload`（:113）：文本空 / 同语言 / 有系统模型（STATE_ON_DEVICE）/ Bergamot 语言对已下载且运行时已下载（**不联网**）→ true。用于"自动翻译不触发下载"。
- Android 系统翻译错误：`local_translation_unavailable`、`local_translator_creation_failed`、`local_translation_timed_out`、`local_translation_failed`、`local_translation_empty_result`、`local_translator_not_ready`（IllegalStateException 含 "destroyed"）。

### 3.4 BergamotModelManager
- `downloadMutex` 串行化所有下载（运行时 + prepare）。
- `isRuntimeDownloaded()`：文件存在且 SHA 匹配（每次全量计算 SHA，5MB）。
- `downloadRuntime()`（:59）：已校验则不再下载；否则下载→校验→原子移动；结束清空进度。
- `runtimeFileUrl()`：校验通过返回 `file://...` URI。
- `prepare(src,tgt)`（:95）：加载 registry（若需联网先发布 indeterminate 进度 fileName=`registry-v3.json`）→ 路径 → 逐 entry `ensureDownloaded`：任何文件 expectedSha256Hash 为空→失败；本地文件 SHA 匹配跳过（计入已下载字节）；否则下载。进度 totalBytes = 路径上所有文件 size 之和。结束后进度置 null。
- `downloadFile`（:432）：OkHttp 同步请求；非 2xx 失败；写 `<name>.download` 临时文件；每次读块更新进度；SHA 不符删除临时文件并失败；`Files.move` ATOMIC_MOVE 失败退回普通 REPLACE_EXISTING。
- `languagePairStatus(src,tgt,allowNetwork)`：registry 不可得→RegistryMissing；无路径→Unavailable；路径上全部文件 SHA 校验通过→Downloaded；否则 AvailableToDownload。
- `getDownloadedLanguagePairs()`（:177）：registry（不联网）中目录存在且所有文件存在的条目（**仅检查存在，不校验 SHA**），size = 目录下文件总长（含 model.json）。
- `deleteLanguagePair(src,tgt)`（:162）：按 resolvePath 删除路径上的每个目录（**中转对删除会连带删除 src-en 与 en-tgt 两个目录**；但 Settings 列出的是单个 registry entry，故通常是直连对）。
- 测试锚点：`input/Feeder/app/src/test/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManagerTest.kt`（直连下载+删除、Mozilla 瑞典语、选新稳定版、排除非 Android 发布、nightly 忽略、运行时校验/错 hash 拒绝/不重复下载、registry 进度、英语中转、RegistryMissing、Unavailable、hash 不匹配失败、无 hash 失败）。

### 3.5 BergamotWebTranslator（WebView 承载）
- 主线程（`Dispatchers.Main.immediate`）创建 `WebView(application)`：JS on、DOM storage off、`LOAD_NO_CACHE`、`allowFileAccess=true`、`allowFileAccessFromFileURLs=true`、`allowUniversalAccessFromFileURLs=false`；`addJavascriptInterface(bridge, "AndroidBergamot")`；加载 `file:///android_asset/bergamot/index.html`（:122-163）。
- 就绪：JS 模块加载完即调用 `AndroidBergamot.onReady()`；Kotlin 等待最多 60s，超时销毁 WebView 并抛出（:72-79）。
- 初始化：key = runtimeFileUrl + registryJson；变化时 `window.FeederBergamot.initialize(registryJson, wasmUrl)`（删除旧 translator，新建 `BatchTranslator`，options：pivotLanguage `en`、workers 1、batchSize 4、cacheSize 16384、downloadTimeout 0、useNativeIntGemm false）。
- 翻译：`window.FeederBergamot.translateBatch(id, from, to, texts[], html)` → JS 端 `Promise.all` 各文本 → `onTranslationBatchSuccess(id, JSON 数组)` 或 `onTranslationError(id, msg)`；Kotlin 以 `ConcurrentHashMap<id, CompletableDeferred>` 匹配，等待 5 分钟，超时→`bergamot_webview_translation_timed_out`。
- JS 侧要点（`assets/bergamot/feeder-bergamot.js`、`translator.js:130-245`）：
  - 因 Android WebView 中 Worker/`fetch` 不支持 `file://`，用 XHR(arraybuffer) 预读模型文件和 WASM（接受 status 200 或 0）；Worker 脚本经 XHR 读取后把 `importScripts('bergamot-translator-worker.js')` 替换为内联 Emscripten 源码，并 patch `var Module`/`global_object`，以 Blob URL 启动 Worker。
  - gemm-precision 按模型文件名后缀（`intgemm8.bin`→`int8shiftAll`，`intgemm.alphas.bin`→`int8shiftAlphaAll`，`intgemm.bin`→`int8shift`）。
  - 中转（pivot `en`）由 JS `BatchTranslator` 内部完成（registry 里同时传入两段 entry）。
- WebView 生命周期：单例，常驻进程，不主动销毁（仅 init 失败时）。

### 3.6 UI 层触发规则（与本域契约相关）
文章（`ArticleViewModel.kt`）：
- 菜单"Translate article / Show original (%1$s)"显示条件 `showTranslate = isShowingTranslated || (canRequestTranslation && 未判定为已是目标语言)`；`canRequestTranslation = canUseAsTranslationApi && 首选语言非空 && 文章 link 非空`（:194-228）。
- `translate()`：已显示译文→切回原文（不重新请求）；否则显示译文并翻译（:607-614）。
- `translateCurrentArticle()`（:616-688）：首选语言空→toast `set_translation_language_first`（"Set a preferred translation language in AI settings"）；已是目标语言→进入 AlreadyInPreferredLanguage（菜单隐藏）；否则 Loading→成功则以 HtmlLinearizer 重排译文 html 并显示译文标题；`SystemTranslationSettingsRequiredException`→弹对话框（消息 + "Open settings" 打开系统 `Settings.ACTION_SETTINGS` + Cancel）；`BergamotRuntimeDownloadRequiredException`→弹"Download offline translation engine?"对话框（4.9 MB 警告文案；Download / Cancel）；其它→toast 错误消息并回到原文。
- 下载运行时：`downloadBergamotRuntimeAndTranslate()` 成功则继续翻译，失败 toast `bergamot_runtime_download_failed`（:882-893）。
- 切换全文/摘要时若正在显示译文则重新翻译（:322-327）；译文结果绑定 isFullText，模式不一致不显示。
- 打开文章自动翻译：`translateArticlesByDefault` 且可翻译且（非 Local 或 已有缓存 或 无需下载 Bergamot）（:257-267, :690-724）。**Local 模式下自动翻译不会触发模型/运行时下载。**
- 加载中显示：有下载进度→进度卡（TranslationProgressContent），否则无限进度条（ArticleScreen.kt:703-709）。
- 后台持续检测"已是目标语言"（combine article/fullText/settings/language，:271-321）。
列表（`FeedViewModel.kt`）：
- 开关 `translateArticlePreviewsByDefault` + canUseAsTranslationApi + 首选语言非空才翻译卡片（:754）。
- 每个可见卡片 `LaunchedEffect` 调 `translateFeedCardIfNeeded`（FeedScreen.kt:1465）；先用缓存；Local 模式若需下载则跳过（:269-282）；配置变化清空所有卡片译文并 generation+1（:201-219）；同一请求去重（inFlight set）。
- 列表顶部显示 Bergamot 下载进度浮层（FeedScreen.kt:1308）。
设置（`Settings.kt`/`OpenAISection.kt`）：
- Translation API 区：provider 预设（含 `DEEPL`、`LOCAL_TRANSLATION`="Local offline"）；首选语言下拉（DeepL 用 DeepL 目标语言列表，其它用 ISO 语言列表）；Local 时显示"Show only downloadable languages"开关（默认 true，过滤 BERGAMOT_TARGET_LANGUAGE_CODES，**不含 zh**）；Local 时描述文案拼接 system + bergamot 说明。
- `canTranslate` 时显示 "Translate article previews" / "Translate articles by default" 两开关（Settings.kt:919-931）。
- 已下载模型区（canTranslate 且列表非空）：每对一行 "源 → 目标" + 大小 + 删除图标（确认对话框 "Delete model"），>1 对时 "Delete all downloaded models"。删除为**挂起**状态，在 API 对话框点保存时才真正删除，取消则恢复（Settings.kt:869-916）。

## 4. 鸿蒙迁移要点与平台差异

| 源能力 | 结果契约 | 鸿蒙候选实现 | 差异/风险 |
|---|---|---|---|
| Android 系统 on-device 翻译 `android.view.translation.TranslationManager`（API 31+） | 本地离线把文本从 src 翻到 tgt | HarmonyOS 无公开等价的通用系统翻译 API（Core Speech/AI Kit 中有文本翻译能力需核实可用性与语言覆盖） | 若无等价，直接走 Bergamot；"Open settings"对话框意义减弱 |
| `TextClassifier.detectLanguage`（置信度） | 语言检测（95%/60% 阈值） | 需寻找鸿蒙语言识别（如 AI 能力或自带轻量库如 CLD/franc 的 JS 实现） | **核心风险**：检测缺失会导致"已是目标语言"判定、本地翻译源语言全部失效（本地翻译 source=`und` → 无模型） |
| 隐藏 WebView + JS Worker + WASM | Bergamot 离线翻译 | ArkWeb `Web` 组件（需挂在组件树，或离屏 `NodeController`）+ `javaScriptProxy`/`registerJavaScriptProxy` 代替 `addJavascriptInterface`；`runJavaScript` 代替 `evaluateJavascript` | ArkWeb 对 `file://`/rawfile、Blob Worker、WASM、XHR status 0 的支持需实测；Android 的 `file:///android_asset/` 需改为 `resource://rawfile/` 或拷贝到沙箱；本地模型文件需 `fileAccess` 权限 |
| OkHttp 同步下载 + SHA-256 | 下载/校验/原子替换 | `@ohos.net.http`(或 `rcp`) 流式下载 + `cryptoFramework` SHA-256 + `fs.moveFile` | 进度回调、大文件（20–50 MB）需流式写盘 |
| `Dispatchers.IO` + `Mutex` | 串行下载、后台执行 | TaskPool/Worker + Promise 互斥队列 | SHA 计算与大文件 IO 需放 TaskPool 避免卡 UI |
| `cacheDir/translations` JSON | 翻译缓存 | `context.cacheDir` + fs | 一致 |
| Jsoup TextNode 遍历 | HTML 保标签逐节点翻译 | 需 ArkTS 侧 HTML 解析器（与 html-model 区共用） | 节点筛选规则（字母≥20）须一致 |

## 5. 降级候选
1. **Android 系统 on-device 翻译**：鸿蒙无确定等价 → 降级为仅 Bergamot；`ErrorAction.OpenSystemTranslationSettings` 对话框改为提示无模型（或打开系统设置作占位）。
2. **SDK<31 检查**：鸿蒙无此分支，移除。
3. **Bergamot WebView 方案**：若 ArkWeb 无法跑 Blob Worker + WASM，则本地离线翻译整体降级为"不可用"（只保留 DeepL）。需早期 PoC。
4. **语言检测置信度**：若无带置信度的检测 API，"已是目标语言"跳过逻辑可降级为不跳过（多一次翻译调用，结果仍正确但浪费）。

## 6. 风险 Top
1. ArkWeb 承载 Bergamot（file/rawfile 访问、Blob Worker、WASM 5MB、XHR arraybuffer status 0、JS 桥）——整条本地翻译链路的可行性门槛。
2. 语言检测能力缺失 → 本地翻译 source=`und`，Bergamot 无路径 → 报 "No Bergamot model for und -> xx"。
3. 外部依赖：Mozilla Remote Settings registry 格式与 `filter_expression` 过滤（只认空或 Android 表达式）、jsDelivr WASM 固定 SHA；网络不可达时 registry 缺失提示 "Connect to download model list."。
4. 下载进度是全局单一 StateFlow，文章页与列表页同时展示；必须在完成/失败时置空，否则进度卡残留。
5. 本地模式自动翻译（列表/文章默认翻译）**不得触发下载**，仅手动翻译才下载；迁移时易漏。
6. BERGAMOT_TARGET_LANGUAGE_CODES 不含 `zh`：本地模式默认"仅显示可下载语言"下无中文目标，对中文用户需注意（保持源行为或产品决策）。
7. 缓存无清理；鸿蒙 cacheDir 清理策略不同，仅影响空间。
8. `getDownloadedLanguagePairs` 只看文件存在不校验 SHA，与 `languagePairStatus` 判定可能不一致（源行为，保持即可）。
