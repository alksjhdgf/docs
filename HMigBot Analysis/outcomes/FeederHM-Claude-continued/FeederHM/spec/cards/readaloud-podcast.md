# 朗读与播客域卡（readaloud-podcast）

## 域: 朗读入口与文本来源

- RA-A01 [ui] Article 页顶栏溢出菜单含 `Read aloud`（`read_article`）项，点击后关闭菜单并开始朗读当前文章。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:447
- RA-A02 [backend] Article 页朗读文本来源：正在显示翻译时读翻译后 HTML；否则按"全文覆盖值 ?? 该条默认全文"选择全文 blob 或摘要 blob。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:474
- RA-A03 [backend] Feed 页底栏 Play 朗读的是当前文章（getCurrentArticle），全文/摘要按该条默认全文设置选择，不考虑翻译。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/FeedViewModel.kt:582
- RA-A04 [backend] HTML 被切分为按段落的文本列表作为朗读队列，空白段被跳过，逐段串行朗读，全部读完后状态变为 STOPPED。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:158
- RA-A05 [backend] 朗读文本文件缺失或解析失败时不崩溃、不开始朗读（静默）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:527
- RA-A06 [ui] TTS 引擎初始化失败时弹出提示 `Could not load text to speech`（`failed_to_load_text_to_speech`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:197
- RA-A07 [on_device] 在 Article 页点击 `Read aloud` 后设备实际发声朗读文章正文。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:136

## 域: 朗读状态机

- RA-A08 [backend] 朗读状态取值恰为 `STOPPED`/`PAUSED`/`PLAYING`，初始 `STOPPED`；引擎就绪开始朗读后为 `PLAYING`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:431
- RA-A09 [backend] 暂停：停止发声、状态 `PAUSED`、队列保留；对同一文章再次 Play 时从被暂停的段落继续（该段从头读），不从文章开头重读。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:150
- RA-A10 [backend] 暂停状态下对不同文章 Play，则清空旧队列并从新文章开头朗读。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:151
- RA-A11 [backend] 停止：停止发声、清空队列、状态 `STOPPED`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:229
- RA-A12 [backend] 跳到下一段：丢弃当前段并朗读下一段；没有下一段时等同停止。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:238
- RA-A13 [backend] 快速连按 Play 不会产生重复/并发朗读（互斥保护）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:181
- RA-A14 [backend] 朗读与播客状态为应用级单例：在 Article 开始的朗读/播客返回 Feed 后继续，并在 Feed 底栏反映同一状态。结果契约：跨页面共享播放状态；鸿蒙实现：单例对象持有 TTS 引擎/AVPlayer 并以可观察状态供各页订阅；差异：无。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:72

## 域: 朗读语言

- RA-A15 [backend] 语言覆盖取值：`AppSetting`（默认）、`ForcedAuto`、`ForcedLocale(locale)`；仅保存在内存，不持久化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:437
- RA-A16 [backend] `AppSetting` 下：设置 `pref_readaloud_detect_lang`=true 时按文本检测语言（置信度≥80%，按置信度降序）优先，否则按系统语言列表优先；两者后接引擎可用语言作为回退。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:117
- RA-A17 [backend] `ForcedAuto` 始终按文本检测语言；`ForcedLocale` 只使用指定语言。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:103
- RA-A18 [backend] 候选语言逐个尝试，带地区语言不被支持时改试仅语言码（如 `en-GB`→`en`），取第一个成功者。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:295
- RA-A19 [backend] 选择语言后停止当前发声并以新语言从当前段重新开始朗读。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:251
- RA-A20 [backend] 可选语言列表顺序：全文检测出的语言（按置信度）→ 系统语言（按自名排序）→ 引擎全部可用语言（按自名排序），按语言标签去重。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ReadAloudStateHolder.kt:269

## 域: 朗读底栏 UI（Article/Feed 共用）

- RA-A21 [ui] 朗读状态非 `STOPPED` 时页面底部出现朗读栏，`STOPPED` 时隐藏。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:201
- RA-A22 [ui] 朗读栏按钮依次为：`Stop reading`、播放中显示 `Pause reading` 否则显示 `Resume reading`、`Skip to next`、`Set language`（均为图标按钮，文案为无障碍描述/提示）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/readaloud/ReadAloudPlayer.kt:104
- RA-A23 [ui] `Set language` 菜单项依次为：`Use app default`、`Detect language`、分隔线、每个可选语言（以该语言自身名称显示）；点选后菜单关闭并应用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/readaloud/ReadAloudPlayer.kt:185
- RA-A24 [ui] Feed 页朗读栏可见时 FAB 并入栏内；栏完全收起后独立 FAB 才显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1264

## 域: 播客链接判定与入口

- RA-A25 [backend] 链接为空或以 `#` 开头不进内置播放器；等于附件链接且附件 MIME 以 `audio/` 开头则进入；否则最后路径段（去 `?`/`#`）扩展名（不分大小写）属于 aac/flac/m4a/m4b/mp3/mp4/oga/ogg/opus/wav/weba 时进入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/PodcastPlayerLinks.kt:21
- RA-A26 [backend] 点击附件或正文链接：设置 `pref_use_in_app_audio_player`（默认 true）开启且判定为音频时用内置播放器播放，否则走外部打开（附件→浏览器，正文链接→按链接打开方式）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:665
- RA-A27 [backend] 开始播客会先停止朗读；开始朗读会先停止播客（二者互斥）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:546
- RA-A28 [backend] 播客只能从 Article 页（附件或正文音频链接）启动；Feed 页只展示/控制已在播放的播客。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/FeedViewModel.kt:550

## 域: 播客播放器

- RA-A29 [backend] 打开音频链接：释放旧播放器，状态置为可见+加载中，准备完成后自动开始播放并记录时长；时长>0 才允许拖动/快进快退。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:30
- RA-A30 [backend] 播放中每约 500ms 更新当前位置与时长。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:175
- RA-A31 [backend] 快退/快进按钮分别为 -10 秒/+10 秒，拖动/跳转目标钳在 [0, 时长] 内；不可拖动时忽略。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:200
- RA-A32 [backend] 播放结束：停止、位置=时长，播放栏保持可见。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:117
- RA-A33 [backend] 停止：释放播放器、状态重置为默认（不可见）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:59
- RA-A34 [on_device] 点击文章中的音频附件后设备实际播放该远程音频，暂停/继续/拖动生效。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:156

## 域: 播客底栏 UI（Article/Feed 共用）

- RA-A35 [ui] 播客可见时底栏显示播客栏（优先于朗读栏），停止后底栏隐藏。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:483
- RA-A36 [ui] 加载中或缓冲中在栏顶部显示不定进度条。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/PodcastPlayerBar.kt:100
- RA-A37 [ui] 无错误时显示进度滑块与"当前时间…总时长"，时间格式 `m:ss`，满 1 小时为 `h:mm:ss`；拖动期间滑块不被进度刷新覆盖，松手后跳转。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/PodcastPlayerBar.kt:104
- RA-A38 [ui] 播放失败时以错误色显示 `Unable to play this audio file`（`audio_playback_failed`）替代滑块与时间。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/PodcastPlayerStateHolder.kt:150
- RA-A39 [ui] 播客栏按钮依次为：`Stop audio`、播放中 `Pause audio` 否则 `Play audio`、`Seek back 10 seconds`、`Seek forward 10 seconds`；后两者在不可拖动时禁用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/PodcastPlayerBar.kt:152

## 域: 相关设置

- RA-A40 [ui] Settings 含开关 `Play audio links with built-in player`（描述 `When disabled, audio links open with your default app instead`），默认开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:806
- RA-A41 [ui] Settings 分组 `Text to speech` 含开关 `Detect language`（描述 `Automatically detects article language`），默认开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:853
