# OpenAI / AI 与翻译 API 卡

## 页面: Settings（`AI and translation` 组：Summary API / Translation API 编辑对话框）
- AI-A01 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:96
- AI-A02 [ui] `AI and translation` 设置组内依次显示两行：`Summary API`、`Translation API`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:866
- AI-A03 [ui] 行副标题：未配置（key 为空且不可作翻译 API）显示 `Not configured`，否则显示 `Provider: %1$s`（提供方名）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:238
- AI-A04 [ui] 点击行打开编辑对话框：标题=行标题，首行灰字 info：Summary 为 `Used for article summaries.`，Translation 为 `Used for translating feed cards and articles.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:117
- AI-A05 [ui] Summary 对话框 `Provider` 下拉选项依次为 `None`、`OpenAI or compatible`、`Azure OpenAI`（不含 DeepL/Local）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1192
- AI-A06 [ui] Translation 对话框 `Provider` 下拉选项依次为 `None`、`DeepL`、`Local offline`（不含 OpenAI/Azure）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1192
- AI-A07 [ui] 打开对话框时提供方由存储推断：全部字段空→None；baseUrl 含 `openai.azure.com`→Azure；baseUrl==`local://translation`→Local；含 `deepl.com`→DeepL；其余→OpenAI or compatible。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1200
- AI-A08 [ui] 区段净化：Summary 区存储为 DeepL/Local 配置时按空配置（None/`Not configured`）显示；Translation 区存储为 OpenAI/Azure 配置时按空配置显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1333
- AI-A09 [backend] 切换提供方立即改写草稿：None 清空 key/modelId/baseUrl/azureApiVersion/azureDeploymentId；OpenAI 清空 baseUrl 与两个 Azure 字段；Azure 仅保留含 openai.azure.com 的 baseUrl；DeepL 设 baseUrl（原 baseUrl 含 api-free.deepl.com 或 key 以 `:fx` 结尾→`https://api-free.deepl.com`，否则 `https://api.deepl.com`）并清空 modelId 与 Azure 字段；Local 清空 key/modelId/Azure 字段且 baseUrl=`local://translation`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1150
- AI-A10 [ui] 字段可见性：OpenAI/Azure/DeepL 显示 key 字段（DeepL 标签 `DeepL auth key`，其余 `API key`）；仅 OpenAI/Azure 显示 `Model Id` 与 `Base URL (optional)`；DeepL 显示只读禁用 `Translation endpoint`=`https://api.deepl.com/v2/translate`；None 只显示 Provider。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:358
- AI-A11 [ui] key 字段掩码显示：长度≥10 时显示前 4 个字符+星号+末 3 个字符（总长不变），长度<10 原样显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/VisualTransformationApiKey.kt:9
- AI-A12 [ui] `Timeout (seconds)` 字段对 OpenAI/Azure/DeepL 显示；输入非 30..600 整数时显示错误 `Timeout must be between 30 and 600 seconds` 且该值不写入草稿。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:501
- AI-A13 [ui] Azure 额外显示 `Azure deployment id` 与 `Azure API version`（占位 `2024-02-15-preview`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:542
- AI-A14 [backend] 草稿或提供方变化后（提供方非 None/Local）防抖 750ms 以当前草稿触发模型列表加载/凭据校验。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:297
- AI-A15 [ui] `Model Id` 尾按钮：加载中显示转圈；加载成功时可点开下拉列出模型 id，点选写入 `Model Id`；其他状态按钮禁用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:412
- AI-A16 [ui] 模型加载成功但列表为空显示 `No models were found`；失败显示 `Unable to load models.` 卡，点击卡片切换展开/收起原始错误消息。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1031
- AI-A17 [ui] 校验提示（Warning 卡）首要规则：需 key 的提供方 key 为空时显示 `Enter a DeepL API key before saving.`（DeepL）或 `Enter an API key before saving.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1271
- AI-A18 [ui] OpenAI or compatible 校验顺序：modelId 空→`Enter a model id before saving.`；未校验/校验中→`Verifying API settings…`；失败→错误原文（空则 `The API settings could not be verified.`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1286
- AI-A19 [ui] Azure 校验顺序：modelId→`Enter a model id before saving.`，baseUrl→`Enter your Azure endpoint before saving.`，deploymentId→`Enter your Azure deployment id before saving.`，apiVersion→`Enter your Azure API version before saving.`，校验中→`Verifying Azure OpenAI settings…`，失败→错误原文或 `The Azure OpenAI settings could not be verified.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1298
- AI-A20 [ui] DeepL 校验：未校验/校验中→`Verifying DeepL key…`；失败→错误原文或 `The DeepL key could not be verified.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:1313
- AI-A21 [ui] `Save` 仅在无校验提示时可点（None 与 Local offline 始终可存）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:191
- AI-A22 [backend] 点 `Save`：Summary 草稿写入 `pref_openai_*`，Translation 草稿写入 `pref_translation_api_*` 并同时保存首选翻译语言、执行待删除的本地语言模型；随后关闭对话框。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:182
- AI-A23 [backend] 点 `Cancel` 或对话框外关闭：丢弃草稿、首选语言改动与待删语言对，不持久化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:118
- AI-A24 [ui] Translation 对话框（提供方非 None）显示只读 `Preferred translation language` 字段+下拉（占位 `Select a language`，条目 `名称 (代码)` 按名称排序）；DeepL 用内置 DeepL 目标语言表，其他用系统 ISO 语言表；非 Local 时说明文字 `Choose the language Feeder should translate into.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:594
- AI-A25 [ui] Local offline 时显示开关 `Show only downloadable languages`（默认开），开启时语言下拉仅含 Bergamot 可下载目标语言。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:491
- AI-A26 [ui] Local offline 说明文字为 `Uses your device's translation service first.`，所选语言在 Bergamot 集合中时追加 `If it is unavailable, Feeder can use its downloadable offline translation engine.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:692
- AI-A27 [ui] Local offline 且可翻译、存在已下载语言对时对话框内显示已下载模型区；删除操作仅标记待删，点 `Save` 才实际删除。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:892
- AI-A28 [ui] `Translate article previews`、`Translate articles by default` 两开关仅在翻译设置为有效 DeepL/Local 且首选翻译语言非空时显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:917

## 域: OpenAI 设置模型与客户端
- AI-A30 [backend] OpenAISettings 字段与默认：modelId=""、baseUrl=""、timeoutSeconds=30、azureApiVersion=""、azureDeploymentId=""、key=""；摘要与翻译各一套独立存储（`pref_openai_key/model_id/url/azure_version/azure_deployment_id/request_timeout_seconds` 与对应 `pref_translation_api_*`），首选翻译语言键 `pref_openai_translation_language`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:909
- AI-A31 [backend] 提供方判定：isAzure=baseUrl 含 `openai.azure.com`；isPerplexity=含 `api.perplexity.ai`；isDeepL=含 `deepl.com`；isLocalTranslation=baseUrl 恰为 `local://translation`（均忽略大小写，Local 除外）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:367
- AI-A32 [backend] 有效性：Local 恒有效；DeepL 需 key 非空；其他需 modelId 与 key 非空且 Azure 还需 apiVersion 与 deploymentId 非空。canSummarize=有效且非 DeepL/Local；canUseAsTranslationApi=有效且为 DeepL 或 Local。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:379
- AI-A33 [backend] listModelIds：Local→成功空列表；key 空→MissingToken；DeepL→执行 key 校验；Perplexity→成功空列表；Azure 缺 apiVersion/deploymentId→对应缺失结果；否则 GET models，按 created 降序返回 id；异常→Error(异常消息)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:125
- AI-A34 [backend] 模型结果映射：MissingToken/Azure 缺字段→None，结果携带发起时的设置，草稿变化后旧结果视为 None（不复用）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/SettingsViewModel.kt:381
- AI-A35 [backend] baseUrl 为空时使用 OpenAI 官方 API 主机；非空时以 baseUrl 追加 `openai` 段作为主机，Azure 对非 models 请求再追加 `deployments/<deploymentId>`，apiVersion 非空时附加查询参数 `api-version`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:408
- AI-A36 [backend] Azure 请求去掉 `Authorization` 头改发 `api-key: <key>`；非 Azure 由客户端库以 Bearer token 鉴权。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIClient.kt:49
- AI-A37 [backend] 网络超时：OpenAI 客户端 socket 超时与 DeepL 调用超时均为 clamp(timeoutSeconds, 30, 600) 秒。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIClient.kt:45
- AI-A38 [backend] 发布版日志对请求头脱敏（仅 Debug 不脱敏），不得输出明文 key。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIClient.kt:46

## 域: AI 摘要
- AI-A40 [backend] summarize 对 DeepL/Local 设置直接返回错误 `Summarization is not supported for this translation-only provider`，不发请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:185
- AI-A41 [backend] 摘要请求为 chat completion：model=modelId，system 消息含 app 语言（ISO3，Locale.getDefault().getISO3Language()）与"首行必须为 `Lang: "ISO code"`、≤100 词、markdown"等指令，user 消息 `Summarize:\n\n<文章内容>`，响应格式 text。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:280
- AI-A42 [backend] 解析回复：首行匹配 `^Lang: "?([a-zA-Z_-]+)"?$` 时取出语言码，摘要正文=去掉首行后 trim；首行不匹配时语言为空且首行同样被删除；无 choices/内容为 null 视为错误。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:271
- AI-A43 [backend] 成功结果含 id、created、model、正文、prompt/completion/total tokens（缺省 0）、detectedLanguage；任何异常转为 Error(异常消息)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:191
- AI-A44 [ui] Article 菜单 `Summarize` 仅在摘要设置 canSummarize 且文章链接非空时出现。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:226
- AI-A45 [ui] 摘要卡：加载中显示线性进度条；成功时 markdown 渲染为富文本段落；失败直接显示错误文本。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:807
- AI-A46 [backend] 摘要输入为全文：已有全文缓存则读缓存，否则抓取全文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:753
- AI-A47 [backend] 订阅源 summarizeOnOpen 为真且 canSummarize 时，打开文章自动触发摘要。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:256

## 域: 翻译 API（DeepL）
- AI-A50 [backend] translate 分派：DeepL→DeepL 接口；Local→错误 `Local translation is not available through this API`；其他→错误 `Translation is not supported for this provider`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:219
- AI-A51 [backend] DeepL 请求：POST `<base>/v2/translate`，头 `Authorization: DeepL-Auth-Key <key>`、JSON 体 {text:[内容], target_lang, tag_handling:"html"(仅 preserveHtml), split_sentences:"nonewlines", preserve_formatting:true}，null 字段省略。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:247
- AI-A52 [backend] DeepL 基址：baseUrl 去空白、去尾 `/` 与 `/v2/translate`；为空或等于官方 api/api-free 地址时按 key 是否以 `:fx` 结尾选 `https://api-free.deepl.com` 或 `https://api.deepl.com`，否则使用自定义地址。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:486
- AI-A53 [backend] 目标语言码规范化：trim、大写、`-`→`_`，按表映射（如 ENGLISH/EN→EN、EN_GB→EN-GB、PT_BR→PT-BR、CHINESE/ZH→ZH、NORWEGIAN/NB→NB），未命中则 `_`→`-` 原样。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:445
- AI-A54 [backend] DeepL 成功返回首个译文与 detected_source_language；HTTP 非 2xx→错误 `DeepL request failed: HTTP <code>[ <message>]`；译文列表为空→`DeepL returned no translations`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:260
- AI-A55 [backend] DeepL key 校验：以 "Hello"→DE 发真实翻译请求，成功且有译文→通过；无译文→`DeepL verification failed: no translation was returned`；HTTP 失败前缀 `DeepL verification failed`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:157
- AI-A56 [backend] 翻译管理器仅当翻译设置 canUseAsTranslationApi 时使用之（否则视为空设置）；Local 走本地翻译器，其余走 OpenAIApi.translate；译文缓存文件按提供方 `local`/`deepl`/`openai` 区分。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:487

## 域: AI 设置导入导出与持久
- AI-A60 [backend] OPML 设置导出/导入包含 12 个 `pref_openai_*`/`pref_translation_api_*` 键（含明文 key）；导入超时非整数时取 30。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OPMLImporter.kt:115
- AI-A61 [on_device] 保存后的摘要/翻译 API 设置（含 key）冷重启后仍在且对话框回显一致。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:540
