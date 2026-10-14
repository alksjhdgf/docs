# 翻译域卡（translation）

## 域: 翻译 provider 与分派

- TR-A01 [backend] 仅当翻译 API 设置为 DeepL（baseUrl 含 `deepl.com` 且 key 非空）或本地离线（baseUrl == `local://translation`）时可用作翻译；其它 provider（OpenAI/Azure 等）配置不产生任何翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/openai/OpenAIApi.kt:397
- TR-A02 [backend] 本地离线 provider 的翻译请求走 LocalTranslator，DeepL provider 走 DeepL 接口（`Authorization: DeepL-Auth-Key <key>`，HTML 内容带 `tag_handling=html`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:541
- TR-A03 [backend] 首选翻译语言去空白后为空时，文章与卡片翻译均不发起，返回原文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:106

## 域: 翻译缓存

- TR-A04 [backend] 翻译结果按 条目 id + provider(`local`/`deepl`/`openai`) + 规范化目标语言 缓存到 `<cacheDir>/translations/<itemId>.<provider>.<lang>.json`，切换 provider 或目标语言不复用旧缓存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:458
- TR-A05 [backend] 缓存以原文 SHA-256 校验：标题、摘要、文章 HTML（摘要模式）与全文 HTML（全文模式）各自独立，原文变化后对应缓存失效并重新翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:273
- TR-A06 [backend] 文章标题与 HTML 均命中缓存时直接返回缓存，不调用翻译引擎。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:294
- TR-A07 [backend] 缓存文件损坏/不可解析时视为无缓存，不报错。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:444
- TR-A08 [backend] 卡片翻译中标题或摘要只有一项翻译成功时，成功项写入缓存并显示译文，失败项保持原文且保留其旧缓存值。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:216

## 域: 语言检测与"已是目标语言"

- TR-A09 [backend] 内容经检测（置信度≥95%，长文取头/中/尾各 4000 字符样本且全部匹配）已是目标语言时不调用翻译引擎，原文作为结果并记录源语言到缓存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:564
- TR-A10 [backend] 字母少于 20 个的样本不参与语言检测；无可用样本时视为"非目标语言"。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationLanguageUtils.kt:60
- TR-A11 [backend] 语言匹配规则：语言码相同且目标无区域或区域相同才算匹配（如目标 `EN` 匹配 `en-GB`，目标 `EN_GB` 不匹配 `en-US`），`nb` 与 Norwegian 视为同一语言。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationLanguageUtils.kt:62
- TR-A12 [backend] 用于检测的文本：HTML 去标签取文本、连续空白折叠为单空格并去首尾空白。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationLanguageUtils.kt:47
- TR-A13 [backend] 缓存中的译文等于原文时，仅当记录的源语言为空或匹配目标语言才视为可用缓存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TranslationManager.kt:714

## 域: 本地离线翻译

- TR-A14 [backend] 本地翻译源语言未提供时自动检测（置信度≥60%，多样本取出现最多者，失败为 `und`）；源语言等于目标语言时原样返回。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:561
- TR-A15 [backend] 本地翻译先尝试系统设备端翻译，失败时回退到 Bergamot 离线引擎。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:96
- TR-A16 [backend] HTML 本地翻译保留全部标签结构：仅替换字母≥20 的文本节点内容并保留其首尾空白，较短文本节点保持原文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:226
- TR-A17 [backend] 模型列表不可获取时返回错误 `Connect to download model list.`；无该语言对（含英语中转）模型时返回 `No Bergamot model for %1$s -> %2$s. Check system translation languages` 并附"打开系统设置"动作。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:315
- TR-A18 [backend] Bergamot 运行时未下载时不自动下载，返回 `Download the offline translation engine to continue.` 并附"下载运行时"动作。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:334
- TR-A19 [backend] 模型下载失败返回 `Could not download %1$s -> %2$s model.`；Bergamot 翻译超过 5 分钟返回 `Bergamot translation timed out.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:366
- TR-A20 [backend] "无需下载即可翻译"判定仅在 文本为空/同语言/系统有设备端模型/Bergamot 语言对与运行时均已下载 时为真，且判定过程不联网。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/LocalTranslator.kt:113
- TR-A21 [on_device] 已下载模型与运行时后断网，本地离线翻译文章仍能产出译文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotWebTranslator.kt:46

## 域: Bergamot 模型管理

- TR-A22 [backend] 模型列表来自 Mozilla Remote Settings（`translations-models` 集合），缓存为 `registry-v3.json`，7 天内或离线时直接用缓存，过期且联网时刷新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:205
- TR-A23 [backend] 仅采用 `filter_expression` 为空或为 `env.appinfo.OS == 'Android'` 的记录；同语言对多版本时稳定版优先、再取版本号最大者；缺 model/lex/词表 的记录集丢弃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:266
- TR-A24 [backend] 无直连语言对且两端都非英语时，使用 源→`en` + `en`→目标 两段模型中转；一端为英语且无直连则不可用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:375
- TR-A25 [backend] 每个模型文件下载后 SHA-256 必须与模型列表的哈希一致才落盘（临时文件 `.download` 后移动）；哈希不符或模型列表无哈希则判下载失败且不留残文件。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:432
- TR-A26 [backend] 已存在且哈希匹配的模型文件不重复下载。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:409
- TR-A27 [backend] 运行时 `bergamot-translator-worker.wasm` 从 jsDelivr `@browsermt/bergamot-translator@0.4.5` 下载，SHA-256 必须为 `95a2b58dd6773bf1b3f345d71f9149928b9f75f4ec9c9064c0b3e42c298671b2`，已校验则不再下载，哈希不符视为下载失败。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:59
- TR-A28 [backend] 模型与运行时下载全局串行；下载期间对外发布进度（源/目标语言、已下载字节/总字节、是否运行时），结束（成功或失败）后进度清空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:95
- TR-A29 [backend] 模型存于 `<filesDir>/translation-models/bergamot/<from>-<to>/`；已下载语言对列表包含所有文件齐全的条目，大小为该目录文件总字节；删除语言对删除对应目录。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:177

## 域: Bergamot 引擎承载

- TR-A30 [backend] Bergamot 在隐藏 Web 容器中运行，加载应用内置 `bergamot/index.html`，通过桥对象 `AndroidBergamot` 回调 `onReady`/`onTranslationBatchSuccess`/`onTranslationError`；页面 60 秒内未就绪则销毁容器并报错。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotWebTranslator.kt:66
- TR-A31 [backend] 批量翻译以请求 id 匹配回调，一批文本按序返回同等数量译文；5 分钟未回调返回 `Bergamot WebView translation timed out.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotWebTranslator.kt:93
- TR-A32 [backend] 引擎以本地已下载模型文件与 WASM 运行时初始化（中转语言 `en`），模型列表或运行时路径变化时重新初始化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotWebTranslator.kt:80

## 域: 翻译交互契约（文章/列表/设置）

- TR-A33 [ui] 文章菜单仅在可翻译（翻译 API 可用、首选语言非空、文章有链接）且未判定为已是目标语言时显示 `Translate article`；显示译文时菜单项为 `Show original (%1$s)`（源语言未知时为 `original`），点击切回原文不重新请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:380
- TR-A34 [ui] 翻译成功后文章标题与正文同时替换为译文；切换全文/摘要模式时若正在显示译文则对新模式内容重新翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:321
- TR-A35 [ui] 首选语言未设置时点翻译弹出提示 `Set a preferred translation language in AI settings`；其它翻译失败弹出错误消息并恢复原文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:616
- TR-A36 [ui] 需下载运行时时弹出对话框，标题 `Download offline translation engine?`、正文为 4.9 MB WebAssembly 运行时警告、按钮 `Download`/`Cancel`；Download 成功后继续翻译，失败提示 `Could not download the offline translation engine.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:882
- TR-A37 [ui] 无可用模型时弹出对话框显示错误消息，按钮 `Open settings`（打开系统设置）/`Cancel`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:617
- TR-A38 [ui] 翻译进行中文章顶部显示进度：有下载进度时显示进度卡（运行时 `Downloading offline translation engine: %1$d%%`；模型总量未知 `Preparing offline translation model %1$s to %2$s…`；否则 `Downloading offline translation model %1$s to %2$s: %3$d%%`，附 20–50 MB 提示），否则显示无限进度条。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/TranslationProgressContent.kt:17
- TR-A39 [ui] 开启 `Translate articles by default` 后打开文章自动显示译文；本地离线模式下仅当已有缓存或无需下载任何模型/运行时时才自动翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:690
- TR-A40 [ui] 开启 `Translate article previews` 后列表卡片可见时标题与摘要替换为译文（先显示缓存）；本地离线模式下需下载模型的卡片保持原文且不触发下载。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/FeedViewModel.kt:227
- TR-A41 [ui] 翻译开关、provider 或首选语言变化后，列表所有卡片译文清空并按新配置重新翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/FeedViewModel.kt:201
- TR-A42 [ui] 模型下载期间列表页顶部显示同一下载进度卡。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1308
- TR-A43 [ui] 设置中 provider 为 `Local offline` 时语言下拉旁显示 `Show only downloadable languages` 开关（默认开），开启时仅列出 Bergamot 支持的目标语言集合。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/OpenAISection.kt:724
- TR-A44 [ui] 可翻译且有已下载模型时显示 `Downloaded translation models` 区：每对一行 "源 → 目标" 与大小、删除按钮（确认框 `Delete model`，文案含语言与大小）；多于一对时额外显示 `Delete all downloaded models`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:1644
- TR-A45 [ui] 模型删除在翻译 API 对话框点保存后才真正执行，取消则已标记删除的模型恢复显示且不删除。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:892
- TR-A46 [on_device] 首次本地离线翻译某语言对时真实下载模型并显示百分比进度，完成后文章显示译文；再次翻译同语言对不再下载。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:95
- TR-A47 [on_device] 下载的模型与运行时在冷重启后仍在，设置中已下载模型列表保持。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/localtranslation/BergamotModelManager.kt:41
