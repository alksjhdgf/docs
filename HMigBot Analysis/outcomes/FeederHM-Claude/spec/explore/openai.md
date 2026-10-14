# 探索：openai 区（OpenAI 摘要 + 翻译 API 设置）

断言卡：`/Users/ppp/Projects/migrate-core/output/FeederHM/spec/cards/openai.md`（AI-A01..AI-A61，共 54 条：ui 26 / backend 27 / on_device 1）。

前缀 `P = input/Feeder/app/src/main/java/com/nononsenseapps/feeder`。

## 1. 文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| `P/openai/OpenAIClient.kt` | 68 | `OpenAIClient` 接口（`models()`、`chatCompletion()`）+ `OpenAIClientDefault`（包装 aallam `openai-client`，Azure 拦截器） |
| `P/openai/OpenAIApi.kt` | 503 | `OpenAIApi`：`listModelIds`、`summarize`、`translate`（仅 DeepL）；结果密封类；提供方判定扩展属性；DeepL 基址/语言码规范化；常量 `LOCAL_TRANSLATION_PROVIDER_URL = "local://translation"` |
| `P/ui/compose/settings/OpenAISection.kt` | 1348 | 设置行 + 编辑对话框（Summary / Translation 两种区段）、`AIProviderPreset` 枚举、校验、语言选择、DeepL 语言表、Bergamot 语言集合 |
| `P/ui/compose/settings/VisualTransformationApiKey.kt` | 22 | key 掩码显示 |
| `P/ui/compose/settings/SettingsViewModel.kt:198-216,247-248,381-419,478-525` | | 事件处理、模型加载状态、`OpenAISettingsState`/`OpenAIModelsState`/`OpenAISettingsEvent` |
| `P/ui/compose/settings/Settings.kt:866-930` | | `AI and translation` 设置组的装配 |
| `P/archmodel/SettingsStore.kt:527-570,746-760,815-830,909-918` | | 持久化（SharedPreferences）、键名、`OpenAISettings` 数据类、`TranslationApiSettings` 类型别名 |
| `P/di/ArchModelModule.kt:59-60` | | DI：`bindFactory<OpenAISettings, OpenAIClient>`；`OpenAIApi(appLang = Locale.getDefault().getISO3Language(), factory())` 单例 |
| 消费方 | | `P/ui/compose/feedarticle/ArticleViewModel.kt:226,256,583-604,737-760`（摘要）、`ArticleScreen.kt:362-376,712-830`（摘要 UI）、`P/model/TranslationManager.kt:436-561`（翻译分派与缓存）、`P/model/opml/OPMLImporter.kt:115-158`（设置导入） |
| 测试 | | `input/Feeder/app/src/test/java/com/nononsenseapps/feeder/openai/OpenAIApiTest.kt`（191 行：Lang 解析、DeepL 头/HTML、HTTP 403 错误、Local 无 key 可用） |

依赖：`com.aallam.openai:openai-client` 4.1.0（BOM）（`input/Feeder/gradle/libs.versions.toml:37,60-61`），底层 Ktor；DeepL 走 OkHttp 同步 `execute()`；JSON 用 kotlinx.serialization（`ignoreUnknownKeys`, `explicitNulls=false`）。

## 2. 数据模型

```kotlin
data class OpenAISettings(modelId="", baseUrl="", timeoutSeconds=30, azureApiVersion="", azureDeploymentId="", key="")
typealias TranslationApiSettings = OpenAISettings
```
（`P/archmodel/SettingsStore.kt:909-918`）

两套独立存储（SharedPreferences，StateFlow 暴露）：
- 摘要：`pref_openai_key`、`pref_openai_model_id`、`pref_openai_url`、`pref_openai_azure_version`、`pref_openai_azure_deployment_id`、`pref_openai_request_timeout_seconds`（int，默认 30）。
- 翻译：`pref_translation_api_key/model_id/url/azure_version/azure_deployment_id/request_timeout_seconds`。
- 首选翻译语言：`pref_openai_translation_language`（字符串，DeepL 码如 `EN-GB` 或 ISO 码/语言名）。
- 写入为整体 `apply()` 六键一起。全部 12 键 + 首选语言都在 `UserSettings` 枚举里 → `getAllSettings()` 会被 OPML 导出（**明文 API key 会进入导出的 OPML 文件**），导入时逐键合并（超时非整数→30）。

提供方没有独立字段，**全靠 baseUrl 推断**：
- Azure：baseUrl 含 `openai.azure.com`（忽略大小写）
- Perplexity：含 `api.perplexity.ai`（仅影响 listModelIds 跳过）
- DeepL：含 `deepl.com`
- Local：baseUrl == `local://translation`（精确）
- 其余：OpenAI 兼容（baseUrl 空=官方）

派生判定（`OpenAIApi.kt:379-406`）：`isValid`、`canSummarize`(有效且非 DeepL/Local)、`canTranslate`(=isValid)、`canUseAsTranslationApi`(有效且 DeepL/Local)、`isBlankConfiguration`(五个字符串字段全空，忽略 timeout)。

结果类型（`OpenAIApi.kt:60-113`）：
- `SummaryResult.Success(id, created, model, content, promptTokens, completeTokens, totalTokens, detectedLanguage)` / `Error(content)`
- `TranslationResult.Success(content, detectedLanguage)` / `Error(content, action: None|DownloadBergamotRuntime|OpenSystemTranslationSettings)`（后两 action 由 LocalTranslator 产生，本区 API 只产 None）
- `ModelsResult.MissingToken | AzureApiVersionRequired | AzureDeploymentIdRequired | Success(ids) | Error(message?)`

UI 状态（`SettingsViewModel.kt:478-525`）：`OpenAISettingsState(settings, modelsResult, isEditMode, showModelsError)`；`OpenAIModelsState.None | Loading(settings) | Success(ids, settings) | Error(message, settings)`；事件 `UpdateSettings / LoadModels / SwitchEditMode / ShowModelsError`。

## 3. 网络行为

### 3.1 OpenAI 兼容 / Azure（`OpenAIClient.kt`, `OpenAIApi.kt:408-443`）
- `OpenAIConfig(token=key, timeout=Timeout(socket=clamp(timeout,30,600)s), logging=Headers 级别, 发布版 sanitize=true, host=toOpenAIHost(false))`。只设 socket 超时（无总调用超时）。
- `toOpenAIHost`：baseUrl 空 → `OpenAIHost.OpenAI`（官方 `https://api.openai.com/v1/`）。非空 → `URLBuilder(baseUrl).appendPathSegments("openai")`（**对所有非空 baseUrl 均追加，不只 Azure**），`withAzureDeploymentId && deploymentId非空` 时再追加 `deployments/<id>`；`api-version` 查询参数（apiVersion 非空时）。生成的 baseUrl **无尾斜杠**，实际请求 URL 由 Ktor `defaultRequest` 的相对路径解析决定（无尾斜杠时最后一段可能被替换）——静态无法百分之百确定最终 URL，**鸿蒙需用真实端点（OpenAI 兼容自定义 baseUrl、Azure）实测/对齐**。建议鸿蒙实现显式拼接并以 Android 实际抓包为准。
- Azure 拦截器（`OpenAIClient.kt:49-65`）：删除 `Authorization`，加 `api-key: <key>`；取原请求 path 中 `openai` 之后的段，重新拼到 `toOpenAIHost(withAzureDeploymentId = 最后段 != "models")`，即 models 列表不带 deployments、chat completions 带。
- `listModelIds` → `client.models()`，按 `created` 降序取 id。
- 摘要请求（`OpenAIApi.kt:280-311`）：`ChatCompletionRequest(model=modelId, messages=[System(一段拼接指令), User("Summarize:\n\n"+content)], responseFormat=Text)`。System 指令要点（逐条原文见源）：RSS 阅读器助手；app 语言 `'$appLang'`（ISO 639-2 三字母，如 `eng`/`zho`）；99% 可识别则用文章语言否则 app 语言；首行严格 `Lang: "ISO code"` 无 markdown；≤100 词、3 段、每段≤3 要点；markdown 粗体/斜体/列表/标题/引用；单一语言；保留完整引用。无 temperature/max_tokens。
- 解析：首行正则 `^Lang: "?([a-zA-Z_-]+)"?$`；正文 = `content.replaceFirst(firstLine, "").trim()`（首行无论是否匹配都会被删）。
- 文章内容来源：`ArticleViewModel.loadArticleContent()`（`:753`）读全文缓存或抓全文；**不截断长度**（可能超模型上下文）。

### 3.2 DeepL（`OpenAIApi.kt:157-179,239-269,313-362,431-501`）
- OkHttp 同步 POST，`callTimeout = clamp(timeout,30,600)s`，每次新建 OkHttpClient（未复用应用全局客户端）。
- URL：`normalizedDeepLBaseUrl()/v2/translate`；默认/官方地址按 key `:fx` 后缀在 free/pro 间自动切换。
- Header：`Content-Type: application/json`、`Authorization: DeepL-Auth-Key <key>`。
- Body：`{"text":[content],"target_lang":CODE,"tag_handling":"html"?,"split_sentences":"nonewlines","preserve_formatting":true}`（`tag_handling` 为 null 时省略，`explicitNulls=false`）。
- 响应：`{"translations":[{"detected_source_language","text"}]}` 取首个。
- 错误字符串：`DeepL request failed: HTTP <code>[ <message>]`、`DeepL returned no translations`、`DeepL verification failed...`。
- 校验 key = 真实翻译 "Hello"→DE（消耗额度；设置对话框每次编辑草稿后 750ms 防抖都会发一次）。
- 语言码映射 `toDeepLTargetLanguageCode`（`:445-484`）：常见英文名/码 → DeepL 码；未知 → `_`→`-` 大写原样（如 `ZH-HANS`）。

### 3.3 不支持的组合
- `summarize` 对 DeepL/Local → 固定错误文案；`translate` 对 Local → `Local translation is not available through this API`（Local 实际由 `TranslationManager` 直接走 `LocalTranslator`），对 OpenAI/Azure → `Translation is not supported for this provider`。**OpenAI 兼容模型不用于翻译**（翻译提供方仅 DeepL / Local）。

## 4. 设置页 UI 结构（Compose）

`Settings.kt:866` `SettingsGroup(title=R.string.openai_settings "AI and translation")`：
1. `OpenAISection(title "Summary API", info "Used for article summaries.", section=Summary)`
2. `TranslationApiSection(title "Translation API", info "Used for translating feed cards and articles.")`
3. 若 `canTranslate`（VM:363 = 翻译设置 canUseAsTranslationApi && 首选语言非空）：`SwitchSetting "Translate article previews"`（`pref_translate_feed_cards_by_default`）、`SwitchSetting "Translate articles by default"`（`pref_translate_articles_by_default`）。

### 4.1 行（`OpenAISectionItem`, `OpenAISection.kt:231-270`）
Row(宽 maxContentWidth, clickable, role=Button)：64dp 空占位 Box + 标题/副标题（`Not configured` 或 `Provider: <名>`）。点击 → `SwitchEditMode(true)`。

### 4.2 编辑对话框（`OpenAISection.kt:100-199`）
`Dialog(usePlatformDefaultWidth=false)` → Surface（fillMaxWidth、高 92%、padding 24、imePadding、extraLarge 圆角）→ Column：标题(headlineSmall) / `OpenAISectionEdit`（可滚动，weight 1）/ 右对齐按钮行 `Cancel`（android.R.string.cancel）+ `Save`（enabled = validationMessage == null）。
草稿 `current` 仅在本地 state，`UpdateSettings` 事件被对话框拦截改草稿；Save 时才发给 VM 持久化。

`OpenAISectionEdit` 字段顺序（条件可见）：
1. info 文本（outline 色）
2. 校验提示 OutlinedCard（Warning 图标 + 文案）
3. `Provider` 只读 TextField + DropdownMenu（`AIProviderPreset.availableFor(section)`）
4. key（`API key` / `DeepL auth key`；Ascii，Next；掩码）— OpenAI/Azure/DeepL
5. `Model Id`（尾按钮：Loading 转圈 / ExpandMore + 模型下拉，contentDescription `List of available models`）+ 模型状态卡 — OpenAI/Azure
6. `Base URL (optional)`（占位官方 baseUrl，Uri 键盘）— OpenAI/Azure；DeepL 改为只读禁用 `Translation endpoint`（固定显示 `https://api.deepl.com/v2/translate`，即使实际使用 api-free）
7. Translation 区且非 None：`Preferred translation language`（只读 + 下拉）+ 说明；Local 时再 `Show only downloadable languages` 开关（本地 state，默认 true，不持久化）+ 已下载模型区
8. `Timeout (seconds)`（数字键盘，占位 `Timeout for AI requests`）— 非 None/Local
9. Azure：`Azure deployment id`、`Azure API version`（占位 `2024-02-15-preview`）

### 4.3 提供方预设（`AIProviderPreset`, `:1094-1218`）
| 预设 | 文案 | Summary | Translation | 需 key | applyTo |
|---|---|---|---|---|---|
| NONE | `None` | ✓ | ✓ | 否 | 清空 5 个字符串字段 |
| OPENAI_COMPATIBLE | `OpenAI or compatible` | ✓ | ✗ | 是 | 清 baseUrl + Azure 字段 |
| AZURE_OPENAI | `Azure OpenAI` | ✓ | ✗ | 是 | baseUrl 仅保留含 openai.azure.com 的 |
| DEEPL | `DeepL` | ✗ | ✓ | 是 | baseUrl=api-free/api，清 model/Azure |
| LOCAL_TRANSLATION | `Local offline` | ✗ | ✓ | 否 | baseUrl=`local://translation`，清其他 |

`fromSettings` 推断顺序：blank→NONE；azure→AZURE；local→LOCAL；deepl→DEEPL；else→OPENAI_COMPATIBLE。

区段净化 `sanitizeSettings`（`:1333-1348`）：Summary 区遇到 DeepL/Local 存储 → 显示为 `OpenAISettings()`；Translation 区遇到非 DeepL/Local 非空 → 显示为 `OpenAISettings()`（历史上两区可能共用过配置，此为兼容）。

### 4.4 校验（`validationMessage`, `:1262-1323`）
NONE→null；需 key 且 key 空→key 提示；`timeoutSeconds` 非 30..600 → 超时错误；按提供方：
- OpenAI：modelId 空 → 模型提示；模型状态 None/Loading → `Verifying API settings…`；Error → message 或 `The API settings could not be verified.`；Success（含空列表）→ null。
- Azure：model → endpoint(baseUrl) → deployment → apiVersion → `Verifying Azure OpenAI settings…` → 失败文案。
- DeepL：`Verifying DeepL key…` / 失败文案。
- Local：null。
注意：**Save 依赖远端校验成功**——离线时无法保存 OpenAI/Azure/DeepL 配置。

模型状态与草稿匹配：`modelsResult.matches(current)` 要求 settings 完全相等，否则当作 None（=“验证中”）。

### 4.5 语言下拉
- DeepL：内置 120 项左右的 `deepLTargetLanguageOptions()`（`:785-908`，码+英文名，按名排序；名称为硬编码英文，不本地化）。
- 其他：`Locale.getISOLanguages()` 用系统默认 Locale 显示名，按 code 去重、按名排序。
- Local 且开关开：过滤到 `BERGAMOT_TARGET_LANGUAGE_CODES`（`:910-964`，52 个两字母码，nb/nn→nb）。
- 选中值显示 `selectedLanguage.label`（`名称 (代码)`），找不到时尝试 `Locale.forLanguageTag` 解析，否则原样字符串。

### 4.6 已知静态可见的细节/怪异
- 超时输入非法时字段报错，但草稿保留上一次合法值，`validationMessage` 用草稿值 → **Save 仍可点击**，保存的是旧的合法超时。
- `MissingToken` / Azure 缺字段映射为 None，UI 由前置字段校验先拦截，不会卡死。
- Perplexity：模型列表恒空 → 显示 `No models were found`，但 Success 可保存。
- `OpenAIModelsStatus` 错误卡点击切换 `showModelsError`（VM 中按区持久在 viewState，跨打开保持）。
- VM 模型加载在 `Dispatchers.IO` 上 launch，无取消；快速连续编辑可能乱序覆盖（以最后完成者为准，但有 settings 匹配兜底）。

## 5. 文章页使用（交叉，Article 区应另有卡）
- `showSummarize = summarySettings.canSummarize && !article.link.isNullOrEmpty()`（`ArticleViewModel.kt:226`）；菜单项 `Summarize`（AutoFixHigh 图标，`ArticleScreen.kt:362-376`）。
- `summarize()`：状态 Loading → Result(SummaryResult, annotatedStrings)；成功经 `MarkdownToHtmlConverter` → `htmlToAnnotatedString`；错误直接文本。
- `SummarySection`（`ArticleScreen.kt:807`）OutlinedCard；Empty 不显示。
- 自动摘要：`feed.summarizeOnOpen && canSummarize`（`:256`），开关在 EditFeed（`summarize_on_open`）。
- 摘要结果不持久化（仅内存 StateFlow）。

## 6. 翻译管理器交叉（`P/model/TranslationManager.kt`）
- `translationSettings()` = 翻译设置若 `canUseAsTranslationApi` 否则空设置（`:487`）。
- `translate()`：Local → `LocalTranslator.translate`；否则 `openAIApi.translate`（`:541-561`）。
- 缓存：`cacheDir/translations/<itemId>.<local|deepl|openai>.<规范化目标语言>.json`（`:458-479`）。
- `ErrorAction` 抛出专用异常（Bergamot 运行时下载 / 打开系统翻译设置）。

## 7. 鸿蒙映射建议
- HTTP：`@ohos.net.http` 或 `@kit.RemoteCommunicationKit (rcp)`；需自行实现 OpenAI REST（无 aallam 库）：`GET {base}/models`、`POST {base}/chat/completions`，Bearer 鉴权；Azure：`{endpoint}/openai/deployments/{id}/chat/completions?api-version=..`，`api-key` 头；models：`{endpoint}/openai/models?api-version=..`。
- 超时：http `connectTimeout/readTimeout` 映射 socket 超时；DeepL 用总超时。
- 存储：Preferences（两组键名保持一致以兼容 OPML 设置导入）；API key 建议考虑 Asset Store / HUKS 加密（Android 原版为明文 SharedPreferences，结果契约只要求持久与回显）。
- Markdown→富文本：需 ArkTS markdown 渲染（或转 HTML 后用本项目 HTML 渲染管线）。
- 系统语言列表：`i18n.System.getSystemLanguages()` / `i18n.getDisplayLanguage`，与 Java `Locale.getISOLanguages()` 集合不同，需固化列表或接受差异。
- `appLang` ISO3：ArkTS 无 `getISO3Language`，需自建 ISO 639-1→639-2 映射表。
- 对话框：CustomDialog / bindSheet，高度 92%，键盘避让。

### 降级候选
- `Local offline` 提供方依赖 Android 系统翻译服务 + Bergamot WebView 引擎（LocalTranslator 区负责）——鸿蒙若无等价，Translation 下拉中该选项可能需降级/隐藏；本区卡 AI-A25/26/27 随之受影响。
- Ktor 相对 URL 解析的精确行为（AI-A35）若与实测不符，以实测 Android 请求 URL 为准。

## 8. Top 风险
1. URL 拼接依赖 Ktor 语义（非空 baseUrl 一律追加 `openai` 段），自定义 OpenAI 兼容端点的最终 URL 需实测确认。
2. Save 门槛依赖在线校验（模型列表 / DeepL 实际翻译），离线或端点无 `/models` 的兼容服务无法保存（Perplexity 为特例跳过）。
3. 提供方仅由 baseUrl 子串推断：Azure 自定义域名（非 openai.azure.com）会被当作 OpenAI 兼容，鉴权头错误。
4. 明文 API key 进入 OPML 设置导出。
5. DeepL 校验会消耗真实字符额度，且每次草稿变更都触发。
6. 摘要输入不截断，长文可能超上下文；摘要不缓存。
