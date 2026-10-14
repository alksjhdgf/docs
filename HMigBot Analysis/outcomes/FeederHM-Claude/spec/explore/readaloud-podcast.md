# 探索：readaloud-podcast（朗读 TTS 与播客播放器）

断言前缀：RA。卡片：`spec/cards/readaloud-podcast.md`。
路径前缀省略：`P = input/Feeder/app/src/main/java/com/nononsenseapps/feeder`

## 1. 文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| P/model/ReadAloudStateHolder.kt | 449 | `TTSStateHolder`（Android TextToSpeech 封装，队列、语言选择）+ `PlaybackStatus`、`LocaleOverride`（`AppSetting`/`ForcedAuto`/`ForcedLocale`）、`detectLocaleFromText`、`getLocales` |
| P/model/PodcastPlayerStateHolder.kt | 222 | `PodcastPlayerStateHolder`（android.media.MediaPlayer 流式播放）+ `PodcastPlayerState` 数据类 |
| P/ui/compose/readaloud/ReadAloudPlayer.kt | 261 | `HideableTTSPlayer` / `TTSPlayer` 底栏 Compose |
| P/ui/compose/feedarticle/PodcastPlayerBar.kt | 220 | `HideablePodcastPlayer` / `PodcastPlayerBar` + `formatPodcastDuration` |
| P/ui/compose/feedarticle/PodcastPlayerLinks.kt | 61 | `shouldOpenInPodcastPlayer`、`audioTitleFromLink`（纯函数） |
| app/src/test/.../feedarticle/PodcastPlayerLinksTest.kt | — | 唯一单测（链接判定与标题解码） |

调用方（不属本区但契约相关）：
- P/FeederApplication.kt:72-73 两个 holder 均为 **Application 级单例**（`applicationCoroutineScope`），:212-213 绑定 Kodein；:225-226 `onTerminate` 调 shutdown。
- P/ui/compose/feedarticle/ArticleViewModel.kt:465-581（ttsPlay/ttsPause/ttsStop/openPodcastPlayer/podcast*/ttsSkipNext/ttsOnSelectLanguage）；:201-205 视图状态映射；:1026-1030 `TSSError`/`TTSFileNotFound`/`TTSUnknownError`。
- P/ui/compose/feedarticle/FeedViewModel.kt:546-646（同名 API，**无** openPodcastPlayer）；:522-526 视图状态映射；:643-646 `onCleared` 调 `ttsStateHolder.shutdown()`。
- P/ui/compose/feedarticle/ArticleScreen.kt:190-202 回调接线（seekBack=-10_000ms，seekForward=+10_000ms）；:269-272 bottomBarVisibleState；:446-460 顶栏溢出菜单项“Read aloud”；:482-506 底栏二选一；:663-670 enclosure 点击；:731-740 正文链接点击。
- P/ui/compose/feed/FeedScreen.kt:314-324 接线；:1184-1187 bottomBarVisibleState；:1242-1268 底栏二选一（TTS 栏带 FAB）；:1272-1279 FAB 仅当底栏收起且空闲时出现；:1421/:1605/:1685 底栏可见时列表 contentPadding 变 0、取消 FAB 占位 Spacer。
- P/archmodel/SettingsStore.kt:281-288 `pref_readaloud_detect_lang`（默认 true）；:400-406 `pref_use_in_app_audio_player`（默认 true）；OPML 导入可设置二者（P/model/opml/OPMLImporter.kt:90,97）。
- P/ui/compose/settings/Settings.kt:805-810（“Play audio links with built-in player” 开关）、:852-861（分组“Text to speech”内“Detect language”开关）。
- P/ui/compose/text/HtmlToAnnotatedString.kt:15 `htmlToAnnotatedString(InputStream, baseUrl): List<AnnotatedString>` —— 把 HTML 按段落切成列表，即 TTS 队列单位。

## 2. TTS（TTSStateHolder）

### 状态
- `ttsState: StateFlow<PlaybackStatus>`，初值 STOPPED（:86）。
- `language: StateFlow<LocaleOverride>` 初值 `AppSetting`（:90）。**只存内存**，不持久化；进程重启回到 AppSetting。
- `availableLanguages: StateFlow<List<Locale>>`（:93），菜单语言列表来源。
- 私有：`textToSpeechQueue: MutableList<CharSequence>`、`queuedArticleId`、`initializedState`、`startJob`、`mutex`、`useDetectLanguage`。

### 行为
- `tts(textArray, useDetectLanguage, articleId)`（:158）：取消 startJob，engine.stop，清空队列，记 articleId，**跳过空白段**（isBlank）后入队，调用 play()。
- `play()`（:177）：协程中，若 mutex 已锁直接返回（防双击）；懒创建 `TextToSpeech(context, this)`；每 100ms 轮询直到 onInit 回调；失败→主线程 Toast `failed_to_load_text_to_speech`（“Could not load text to speech”）并返回（状态保持不变）；成功→状态 PLAYING，挂 UtteranceProgressListener，`updateAvailableLanguages()`，`speakNext()`。
- `speakNext()`（:98）：取队首（不出队），按语言策略得到 Locale 序列，`setFirstBestLocale` 逐个尝试 `setLanguage`（失败再试去掉地区的 `Locale.forLanguageTag(locale.language)`），然后 `speak(text, QUEUE_ADD, null, "0")`。
  - `ForcedAuto`：文本语言检测（置信度≥80，降序）+ availableLanguages。
  - `ForcedLocale(l)`：仅 l。
  - `AppSetting`：若设置 useDetectLanguage=true 同 ForcedAuto；否则系统 locale 列表 + availableLanguages。
- `onDone`（:40）：出队；队列空则 100ms 后仍空→STOPPED；否则 speakNext（逐段串行朗读）。
- `onError`：只出队，不推进下一段、不改状态（见风险 R4）。
- `pause()`（:223）：engine.stop、状态 PAUSED；**队列保留**，当前段仍在队首 → 恢复时从当前段**开头**重读。
- `resumeIfPausedOn(articleId)`（:150）：仅当 PAUSED 且队列属于同一文章时 play() 并返回 true。
- `stop()`（:229）：清队、articleId=null、STOPPED、textToSpeech=null（未 shutdown，泄漏引擎连接）。
- `skipNext()`（:238）：停当前、出队一段；空→stop()，否则 play()。
- `setLanguage(lang)`（:251）：停当前、更新 language、play()（从当前段重读）。**即使原状态是 PAUSED/STOPPED 也会触发 play()**；若队列空则变 PLAYING 后什么都不说——但 onDone 不会触发，状态卡在 PLAYING（风险 R5）。
- `updateAvailableLanguages()`（:269）：排序 = 对整个队列文本的语言检测（minConfidence=0，降序）→ 系统 locales（按自名排序）→ 引擎 availableLanguages（按自名排序），按 languageTag 去重。
- `detectLocaleFromText`（:399）使用 Android `TextClassificationManager.textClassifier.detectLanguage`（API 29+，minSdk=29），置信度×100。
- `PUNCTUATION` 常量（:332）**未被使用**（死代码）。
- 未使用 `queuedArticleId` 以外的任何持久化；无前台服务、无 MediaSession、无音频焦点处理、无通知。

### ViewModel 文本来源（ArticleViewModel.ttsPlay :465）
1. 先 `stopPodcastPlayback()`（与播客互斥）。
2. `resumeIfPausedOn(itemId)` 为真则结束。
3. IO 线程：取当前文章；`readFullText = displayFullTextOverride ?: feedItem.fullTextByDefault`；
   - 若正在显示翻译 → 朗读 `loadTranslatedArticle(...).translatedHtml`；
   - 否则 false → 摘要 blob（`blobInputStream(id, articleDir)`），true → 全文 blob（`blobFullInputStream(id, fullArticleDir)`）。
4. 失败（FileNotFound/其它）被 `Either.catching` 吞掉，`// TODO show error some message`：**无任何用户提示**。
FeedViewModel.ttsPlay（:582）：同理，但取 `repository.getCurrentArticle()`，全文判定用 `shouldDisplayFullTextForItemByDefault`，**不考虑翻译**。Feed 页没有“Read aloud”入口（grep 无 `read_article`），只能通过 TTS 底栏 Play 键恢复/重新朗读当前文章。

## 3. 播客播放器（PodcastPlayerStateHolder）

`PodcastPlayerState`（:211）：audioUrl=""、isVisible=false、isLoading、isBuffering、isPlaying、canSeek、durationMillis=0、positionMillis=0、errorMessage=null。

- `playLink(link)`（:30）：空白忽略；释放旧播放器；状态重置为 {audioUrl, isVisible=true, isLoading=true}；`initializePlayer`。
- `initializePlayer`：MediaPlayer，AudioAttributes(CONTENT_TYPE_MUSIC, USAGE_MEDIA)，`setDataSource(app, Uri)` + `prepareAsync()`。
  - onPrepared：**自动开始播放**；isLoading/isBuffering=false、isPlaying=true、canSeek=duration>0（直播流/未知时长不可拖动）、durationMillis、errorMessage=null；启动进度轮询。
  - onCompletion：停轮询，isPlaying=false，position=duration（栏保持可见）。
  - onInfo BUFFERING_START/END → isBuffering。
  - onError / 构造异常：isPlaying=false、errorMessage=`audio_playback_failed`（“Unable to play this audio file”）。
- 进度轮询：每 500ms 更新 position/duration（:175）。
- `play()`/`pause()`：start/pause + 轮询开关 + isPlaying。
- `seekBy(delta)`/`seekTo(pos)`：仅 canSeek 时；目标钳到 [0, duration]。
- `stop()`：释放并重置为默认状态（isVisible=false → 底栏隐藏）。
- 无标题/封面元数据（`audioTitleFromLink` 只在单测使用，主代码未引用）；无后台服务/通知/锁屏控制/音频焦点/耳机拔出处理；无播放速度；无断点续播持久化。

### 链接判定（PodcastPlayerLinks.kt）
`shouldOpenInPodcastPlayer(link, enclosure)`：空白或以 `#` 开头 → false；`link == enclosure.link && enclosure.type startsWith "audio/"` → true；否则取去掉 `#`/`?` 后最后路径段的小写扩展名，属于 {aac, flac, m4a, m4b, mp3, mp4, oga, ogg, opus, wav, weba} → true。
`audioTitleFromLink(link, fallback="")`：URL 解码最后路径段并 trim；空则 fallback；再空则 link。

### 入口（ArticleScreen）
- enclosure 点击（:663）：`useInAppAudioPlayer && shouldOpenInPodcastPlayer(enclosure.link, enclosure)` → `openPodcastPlayer`，否则 `openLinkInBrowser`。
- 正文链接点击（:731）：非锚点链接，同条件 → 内置播放器，否则 `activityLauncher.openLink`（custom tab/浏览器）。
- `openPodcastPlayer`（ArticleViewModel:546）：先 `ttsStop()`，再 `playLink`。

## 4. UI 结构

### TTS 底栏 `TTSPlayer`（ReadAloudPlayer.kt:85）
`PaddedBottomAppBar(actions=…, floatingActionButton=可选)`，actions 顺序：
1. Stop（Icons.Stop，cd/tooltip `stop_reading` “Stop reading”）
2. Crossfade：播放中→Pause（`pause_reading` “Pause reading”）；否则→PlayArrow（`resume_reading` “Resume reading”）
3. SkipNext（`skip_to_next` “Skip to next”）
4. Translate 图标（`set_language` “Set language”）→ DropdownMenu：
   - 隐藏 0dp 高“Close menu”项（TalkBack 用，`close_menu`）
   - `use_app_default` “Use app default” → AppSetting
   - `use_detect_language` “Detect language” → ForcedAuto
   - HorizontalDivider
   - availableLanguages 每项，文案 `locale.getDisplayName(locale)`（自名）→ ForcedLocale
   - Esc 键关闭（onKeyEventLikeEscape）
菜单不显示当前选中项（无勾选）。
`HideableTTSPlayer`：AnimatedVisibility 自下滑入/滑出 256ms。

### 播客底栏 `PodcastPlayerBar`（PodcastPlayerBar.kt:74）
Surface(surfaceColorAtElevation 3dp) > Column：
1. isLoading||isBuffering → 不定进度 LinearProgressIndicator。
2. errorMessage==null：Slider（范围 0..duration，enabled=canSeek；拖动中不被进度覆盖，松手 `onSeekTo`）+ Row[当前时间 … 总时长]（`m:ss`，≥1h 时 `h:mm:ss`）；否则显示错误文字（error 色）。
3. PaddedBottomAppBar actions：Stop（`stop_audio`）、Crossfade Pause(`pause_audio`)/Play(`play_audio`)、Replay10（`seek_back_10_seconds`，enabled=canSeek）、Forward10（`seek_forward_10_seconds`，enabled=canSeek）。

### 底栏选择与可见性（Article / Feed 相同模式）
- `isBottomBarVisible = ttsState != STOPPED || podcastPlayerState.isVisible`（ArticleViewModel:201，FeedViewModel:524）。
- `isTTSPlaying = ttsState == PLAYING`。
- bottomBar：`podcastPlayerState.isVisible` → 播客栏，否则 TTS 栏；两者共用同一 visibleState 动画。
- Feed：TTS 栏携带 FAB（showFab 时）；独立 FAB 仅在底栏完全收起后出现；底栏可见时列表/网格去掉底部导航栏 inset padding 和 FAB 占位。
- 因 holder 是应用级单例，在 Article 开始的朗读/播客在返回 Feed 后仍然继续且底栏在 Feed 显示（FeedViewModel 订阅同一 flow）；反之亦然。

## 5. 设置
| key | 默认 | UI | 作用 |
|---|---|---|---|
| `pref_readaloud_detect_lang` | true | Settings 分组 `text_to_speech` “Text to speech” > `use_detect_language` “Detect language”，描述 `description_for_read_aloud` “Automatically detects article language” | AppSetting 模式下是否检测文本语言 |
| `pref_use_in_app_audio_player` | true | `use_in_app_audio_player` “Play audio links with built-in player”，描述 “When disabled, audio links open with your default app instead” | 是否用内置播放器打开音频链接 |

## 6. 平台差异与鸿蒙映射

| 源（Android） | 结果契约 | 鸿蒙实现建议 | 差异 |
|---|---|---|---|
| `android.speech.tts.TextToSpeech` + UtteranceProgressListener | 按段串行朗读、可暂停/停止/跳段 | `@kit.CoreSpeechKit` `textToSpeech.createEngine` + `speak(text, {requestId})` + `setListener(onComplete/onError/onStop)` | 鸿蒙 TTS 引擎语言支持面窄（主要 zh-CN，部分版本有 en-US），无“可用语言列表”API 对等；ForcedLocale 菜单可能只能列出极少项 |
| `TextToSpeech.availableLanguages` / `setLanguage` 回退去地区 | 菜单列出可选语言、选择后生效 | `createEngine` 参数 language 固定，切语言需重建引擎；`listVoices` 可查音色 | 语言切换语义需降级 |
| `TextClassificationManager.detectLanguage` | 按文本检测语言 | 无直接等价；可用 `@kit.NaturalLanguageKit`（若有语言识别）或简单启发式（CJK 字符比例） | 降级候选 |
| `MediaPlayer` 流式 + prepareAsync + onInfo buffering | 播放远程音频、进度、拖动、缓冲提示、错误提示 | `@kit.MediaKit` `media.createAVPlayer()`，`url` 赋值→`prepared` 状态自动/手动 play；`timeUpdate`、`durationUpdate`、`bufferingUpdate`、`error` 事件；`seek` | AVPlayer 状态机严格（idle→initialized→prepared→playing），需在正确状态调用 |
| Application 单例 + CoroutineScope | 播放跨页面持续 | AppStorage/单例 class 持有 AVPlayer/TTS 引擎 | 等价 |
| 无前台服务（Android 下进程存活即继续） | App 在前台时播放 | 鸿蒙后台播放需 `AVSession` + 长时任务 `backgroundTaskManager.startBackgroundRunning(AUDIO_PLAYBACK)`，否则切后台会被暂停/静音 | 源也不保证后台，不入卡；可降级为“仅前台播放” |
| Toast | 引擎初始化失败提示 | `promptAction.showToast` | 等价 |
| AnimatedVisibility slide | 底栏显隐动画 | `transition`/`animateTo` | 视觉不入卡 |

## 7. 降级候选
1. TTS 自动语言检测（ForcedAuto / AppSetting+detect）：鸿蒙无 TextClassifier；降级为启发式或固定引擎语言。
2. TTS 语言菜单的“全部可用语言”列表：鸿蒙引擎语言极少，菜单可能只剩“Use app default / Detect language”+ 1~2 项。
3. 后台持续播放（源无此保证，鸿蒙需 AVSession+长时任务，否则后台被系统暂停）。
4. “Detect language”设置项若语言检测降级，其效果不可观察。

## 8. 风险 / 源码怪癖（实现须知）
- R1 FeedViewModel.onCleared（:643）调用**应用单例** TTS 的 `shutdown()`，但不置空 `textToSpeech`，之后 play() 会复用已 shutdown 的引擎（静默无声或异常）。迁移时不应复刻；改为不在页面销毁时关闭单例引擎。
- R2 `pause()` 后恢复从当前段开头重读（不是精确断点续读）。
- R3 朗读文本提取失败无任何提示（TODO）。
- R4 `onError` 只出队不推进，状态停留 PLAYING，朗读卡住；迁移可改为推进下一段（不入卡）。
- R5 `setLanguage` 会无条件 play()；在 PAUSED 时切换语言会自动恢复朗读。
- R6 TTS 与播客互斥：开始朗读停播客；打开播客停朗读。底栏同一时刻只显示一种（播客优先）。
- R7 language override 只在内存，跨冷启动丢失；`useDetectLanguage` 在每次 `tts()` 时从设置读取一次快照。
- R8 播客 `onCompletion` 后栏仍可见、position=duration；再按 Play 由 MediaPlayer 从头重播（Android 行为）；AVPlayer 在 completed 状态需 `seek(0)` 再 play 才等价。
- R9 canSeek 取决于 duration>0；直播流无拖动、±10s 按钮禁用。
- R10 `audioTitleFromLink`、`PUNCTUATION` 未被主代码使用。
- R11 FeedViewModel 无 openPodcastPlayer：播客只能从 Article 页（enclosure 或正文音频链接）启动。（已核实：`ArticleContent(` 与 `onOpenAudioPlayer` 仅在 ArticleScreen.kt 中出现。）
