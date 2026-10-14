/**
 * ReadAloudStateHolder.ets —— 源 model/ReadAloudStateHolder.kt（TTSStateHolder：Android TextToSpeech 封装）的鸿蒙实现：
 * `@kit.CoreSpeechKit` textToSpeech 引擎。应用级单例（源 FeederApplication:72），Article / Feed 订阅同一状态（RA-A14）。
 *
 * 行为（照源）：
 *  - 状态 PlaybackStatus：STOPPED / PAUSED / PLAYING，初值 STOPPED（RA-A08）；语言覆盖 LocaleOverride
 *    （AppSetting 默认 / ForcedAuto / ForcedLocale），只存内存（RA-A15）。
 *  - tts(textArray, useDetectLanguage, articleId)：取消启动任务、停发声、清队列、记文章、跳过空白段后入队、play()（RA-A04）。
 *  - play()：互斥（快速连按不重复/并发朗读，RA-A13）；懒建引擎，失败 Toast failed_to_load_text_to_speech（RA-A06）；
 *    成功 → PLAYING、刷新可选语言、speakNext()。
 *  - speakNext()：取队首（不出队），按语言策略得候选序列（RA-A16/A17），逐个尝试（带地区失败再试仅语言码，RA-A18），
 *    然后 speak；onComplete(type=1 播报完成) 出队、队列空 100ms 后仍空 → STOPPED，否则继续下一段（RA-A04）。
 *  - pause()：停发声、PAUSED、队列保留（RA-A09）；resumeIfPausedOn(articleId) 同文章才恢复（从当前段开头，RA-A09/A10）。
 *  - stop()：停发声、清队列、STOPPED（RA-A11）；skipNext()：丢弃当前段，空则 stop() 否则 play()（RA-A12）。
 *  - setLanguage(lang)：停发声、更新语言、play()（从当前段重读，RA-A19）。
 *  - updateAvailableLanguages()：全文检测语言（按置信度）→ 系统语言（按自名）→ 引擎可用语言（按自名），按标签去重（RA-A20）。
 * 平台映射：Android setLanguage(Locale) ↔ 鸿蒙引擎创建时固定 language → 切换语言 = 按 listVoices 结果重建引擎；
 * TextClassifier 语言检测 ↔ TextLanguageDetector 启发式。
 */
import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { FeedPageHooks } from '../feed/FeedHooks';
import { detectLocaleFromText, displaySortKey, getSystemLocales, languageOf, normalizeTag, sortedLocales } from './TextLanguageDetector';
import {
  isBlank, LocaleOverride, LocaleOverrideKind, PlaybackStatus, sameTag, splitForEngine, stableSortByKey, TtsState
} from './ReadAloudTypes';

export { LocaleOverride, LocaleOverrideKind, PlaybackStatus, TtsState } from './ReadAloudTypes';

const LOG_TAG: string = 'FEEDER_TTS';
/** 引擎语音列表为空时的初始语言（鸿蒙 TTS 必有的中文语音） */
const FALLBACK_ENGINE_LANGUAGE: string = 'zh-CN';
/** 引擎模式：1 = 离线（端侧）合成 */
const ENGINE_OFFLINE: number = 1;
/** CompleteResponse.type：1 = 播报（发声）完成；0 = 仅合成完成 */
const SPEECH_COMPLETE_TYPE: number = 1;

/** 源 UtteranceProgressListener */
class HolderSpeakListener implements textToSpeech.SpeakListener {
  private readonly holder: TTSStateHolder;

  constructor(holder: TTSStateHolder) {
    this.holder = holder;
  }

  onStart(requestId: string, response: textToSpeech.StartResponse): void {
    // 源 onStart 为空实现
    console.debug(LOG_TAG, `onStart ${requestId}`);
  }

  onComplete(requestId: string, response: textToSpeech.CompleteResponse): void {
    // CompleteResponse.type：0 = 合成完成（音频仍在播放），1 = 播报完成。
    // 只有播报完成才等同源 onDone；合成完成就出队会导致下一段抢播、暂停/跳段错位、提前 STOPPED。
    if (response.type !== SPEECH_COMPLETE_TYPE) {
      console.debug(LOG_TAG, `onComplete ${requestId} type ${response.type} (synthesis done, still speaking)`);
      return;
    }
    this.holder.onUtteranceDone(requestId);
  }

  onStop(requestId: string, response: textToSpeech.StopResponse): void {
    // stop() 主动停止：状态由调用方维护
    console.debug(LOG_TAG, `onStop ${requestId}`);
  }

  onError(requestId: string, errorCode: number, errorMessage: string): void {
    console.error(LOG_TAG, `onError utteranceId ${requestId}, errorCode ${errorCode} ${errorMessage}`);
    this.holder.onUtteranceError(requestId);
  }
}

export class TTSStateHolder {
  private static inst: TTSStateHolder | null = null;

  static instance(): TTSStateHolder {
    if (TTSStateHolder.inst === null) {
      TTSStateHolder.inst = new TTSStateHolder();
    }
    return TTSStateHolder.inst as TTSStateHolder;
  }

  /** 可观察状态（源 ttsState / language / availableLanguages） */
  readonly state: TtsState = new TtsState();

  private readonly listener: HolderSpeakListener;
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private engineLanguage: string = '';
  private voices: textToSpeech.VoiceInfo[] = [];
  private voicesLoaded: boolean = false;
  private requestCounter: number = 0;
  /** 正在朗读的请求（'' = 无） */
  private currentRequestId: string = '';

  private textToSpeechQueue: string[] = [];
  private queuedArticleId: number | null = null;
  private useDetectLanguage: boolean = true;

  /** 源 startJob：取消 = generation 递增 */
  private generation: number = 0;
  private startJob: Promise<void> | null = null;
  /** 源 mutex */
  private locked: boolean = false;
  private lockedGeneration: number = -1;
  private replayPending: boolean = false;
  private uiContext: UIContext | null = null;

  private constructor() {
    this.listener = new HolderSpeakListener(this);
  }

  get ttsState(): PlaybackStatus {
    return this.state.ttsState;
  }

  get language(): LocaleOverride {
    return this.state.language;
  }

  get availableLanguages(): string[] {
    return this.state.availableLanguages;
  }

  /** 当前队列（只读快照，测试/调试用） */
  queueSnapshot(): string[] {
    return this.textToSpeechQueue.slice();
  }

  queuedArticle(): number | null {
    return this.queuedArticleId;
  }

  /** 提供 Toast 用 UIContext（页面/底栏 aboutToAppear 调用；未提供时取最后窗口） */
  attachUi(ui: UIContext): void {
    this.uiContext = ui;
  }

  /** 源 resumeIfPausedOn(articleId)（:150） */
  resumeIfPausedOn(articleId: number): boolean {
    if (this.state.ttsState !== PlaybackStatus.PAUSED || this.queuedArticleId !== articleId) {
      return false;
    }
    this.play();
    return true;
  }

  /** 源 tts(textArray, useDetectLanguage, articleId)（:158） */
  tts(textArray: string[], useDetectLanguage: boolean, articleId: number): void {
    this.useDetectLanguage = useDetectLanguage;
    this.generation++;
    this.stopSpeaking();
    this.textToSpeechQueue = [];
    this.queuedArticleId = articleId;
    for (let i = 0; i < textArray.length; i++) {
      const text: string = textArray[i];
      if (isBlank(text)) {
        continue;
      }
      const parts: string[] = splitForEngine(text);
      for (let p = 0; p < parts.length; p++) {
        this.textToSpeechQueue.push(parts[p]);
      }
    }
    this.play();
  }

  /** 源 play()（:177） */
  play(): void {
    if (this.locked) {
      // Oops, I was double clicked —— 运行中的启动任务若已被取消，则在其结束后补一次
      if (this.lockedGeneration !== this.generation) {
        this.replayPending = true;
      }
      return;
    }
    this.generation++;
    const gen: number = this.generation;
    this.locked = true;
    this.lockedGeneration = gen;
    this.startJob = this.runPlay(gen).finally(() => {
      this.locked = false;
      this.lockedGeneration = -1;
      if (this.replayPending) {
        this.replayPending = false;
        this.play();
      }
    });
  }

  /** 源 pause()（:223）：队列保留 */
  pause(): void {
    this.generation++;
    this.replayPending = false;
    this.stopSpeaking();
    this.setStatus(PlaybackStatus.PAUSED);
  }

  /** 源 stop()（:229） */
  stop(): void {
    this.generation++;
    this.replayPending = false;
    this.stopSpeaking();
    this.textToSpeechQueue = [];
    this.queuedArticleId = null;
    this.setStatus(PlaybackStatus.STOPPED);
    this.releaseEngine();
  }

  /** 源 skipNext()（:238） */
  skipNext(): void {
    this.skipNextAsync().catch((e: Error) => {
      console.error(LOG_TAG, `skipNext failed: ${e?.message}`);
    });
  }

  /** 源 setLanguage(lang)（:251）：无论原状态均 play()（源 R5） */
  setLanguage(lang: LocaleOverride): void {
    this.setLanguageAsync(lang).catch((e: Error) => {
      console.error(LOG_TAG, `setLanguage failed: ${e?.message}`);
    });
  }

  /** 源 shutdown()：释放引擎（不复刻源 R1：单例引擎不在页面销毁时关闭，仅进程退出时调用） */
  shutdown(): void {
    this.generation++;
    this.stopSpeaking();
    this.releaseEngine();
  }

  // ------------------------------------------------------------------ 引擎回调

  /** 源 UtteranceProgressListener.onDone */
  onUtteranceDone(requestId: string): void {
    if (requestId !== this.currentRequestId) {
      return;
    }
    this.currentRequestId = '';
    this.textToSpeechQueue.shift();
    if (this.textToSpeechQueue.length === 0) {
      setTimeout(() => {
        if (this.textToSpeechQueue.length === 0) {
          // If still empty after the delay
          this.setStatus(PlaybackStatus.STOPPED);
        }
      }, 100);
    } else {
      const gen: number = this.generation;
      this.speakNext(gen).catch((e: Error) => {
        console.error(LOG_TAG, `speakNext failed: ${e?.message}`);
      });
    }
  }

  /** 源 onError：只出队（不推进、不改状态，照源） */
  onUtteranceError(requestId: string): void {
    if (requestId !== this.currentRequestId) {
      return;
    }
    this.currentRequestId = '';
    this.textToSpeechQueue.shift();
  }

  // ------------------------------------------------------------------ 内部

  private setStatus(s: PlaybackStatus): void {
    this.state.ttsState = s;
    FeedPageHooks.state.ttsActive = s !== PlaybackStatus.STOPPED;
    PlayerBarCollapseState.instance().sync();
  }

  private stopSpeaking(): void {
    this.currentRequestId = '';
    const e: textToSpeech.TextToSpeechEngine | null = this.engine;
    if (e !== null) {
      try {
        e.stop();
      } catch (err) {
        console.warn(LOG_TAG, `stop failed: ${JSON.stringify(err)}`);
      }
    }
  }

  private releaseEngine(): void {
    const e: textToSpeech.TextToSpeechEngine | null = this.engine;
    this.engine = null;
    this.engineLanguage = '';
    if (e !== null) {
      try {
        e.shutdown();
      } catch (err) {
        console.warn(LOG_TAG, `shutdown failed: ${JSON.stringify(err)}`);
      }
    }
  }

  private async skipNextAsync(): Promise<void> {
    this.generation++;
    this.replayPending = false;
    this.stopSpeaking();
    await this.joinStartJob();
    this.textToSpeechQueue.shift();
    if (this.textToSpeechQueue.length === 0) {
      this.stop();
    } else {
      this.play();
    }
  }

  private async setLanguageAsync(lang: LocaleOverride): Promise<void> {
    this.generation++;
    this.replayPending = false;
    this.stopSpeaking();
    await this.joinStartJob();
    this.state.language = lang;
    this.play();
  }

  private async joinStartJob(): Promise<void> {
    const job: Promise<void> | null = this.startJob;
    if (job !== null) {
      try {
        await job;
      } catch (e) {
        console.warn(LOG_TAG, `start job failed: ${JSON.stringify(e)}`);
      }
    }
  }

  private async runPlay(gen: number): Promise<void> {
    try {
      const ok: boolean = await this.ensureEngine();
      if (gen !== this.generation) {
        return;
      }
      if (!ok) {
        this.showLoadFailedToast();
        return;
      }
      if (this.state.ttsState === PlaybackStatus.PLAYING && this.currentRequestId !== '') {
        // 已在朗读：重复的 play 不再并发朗读同一段
        return;
      }
      this.setStatus(PlaybackStatus.PLAYING);
      await this.updateAvailableLanguages();
      if (gen !== this.generation) {
        return;
      }
      await this.speakNext(gen);
    } catch (e) {
      console.error(LOG_TAG, `play failed: ${JSON.stringify(e)}`);
    }
  }

  /** 源 speakNext()（:98） */
  private async speakNext(gen: number): Promise<void> {
    if (this.textToSpeechQueue.length === 0) {
      return;
    }
    const text: string = this.textToSpeechQueue[0];
    const lang: LocaleOverride = this.state.language;
    let localesToUse: string[];
    if (lang.kind === LocaleOverrideKind.FORCED_AUTO) {
      localesToUse = sortedLocales(detectLocaleFromText(text)).concat(this.state.availableLanguages);
    } else if (lang.kind === LocaleOverrideKind.FORCED_LOCALE) {
      localesToUse = [lang.locale];
    } else if (this.useDetectLanguage) {
      // Use app setting
      localesToUse = sortedLocales(detectLocaleFromText(text)).concat(this.state.availableLanguages);
    } else {
      // User has requested un-dynamic so for context locales first
      localesToUse = getSystemLocales().concat(this.state.availableLanguages);
    }
    await this.setFirstBestLocale(localesToUse);
    if (gen !== this.generation || this.state.ttsState !== PlaybackStatus.PLAYING) {
      return;
    }
    if (this.textToSpeechQueue.length === 0 || this.textToSpeechQueue[0] !== text) {
      return;
    }
    this.speak(text);
  }

  private speak(text: string): void {
    const e: textToSpeech.TextToSpeechEngine | null = this.engine;
    if (e === null) {
      return;
    }
    this.requestCounter++;
    const requestId: string = `feeder_tts_${Date.now()}_${this.requestCounter}`;
    this.currentRequestId = requestId;
    const params: textToSpeech.SpeakParams = { requestId: requestId };
    try {
      e.speak(text, params);
    } catch (err) {
      console.error(LOG_TAG, `speak failed: ${JSON.stringify(err)}`);
      this.onUtteranceError(requestId);
    }
  }

  /** 源 setFirstBestLocale（:295）：逐个尝试，带地区失败再试仅语言码 */
  private async setFirstBestLocale(localesToUse: string[]): Promise<void> {
    for (let i = 0; i < localesToUse.length; i++) {
      const locale: string = localesToUse[i];
      if (await this.trySetLanguage(locale)) {
        return;
      }
      // In this case, try without region because the TTS engine lies about what locales are available
      if (await this.trySetLanguage(languageOf(locale))) {
        return;
      }
      console.error(LOG_TAG, `${locale} is not supported`);
    }
    console.error(LOG_TAG, 'None of the locales were supported by text to speech');
  }

  /** 源 textToSpeech.setLanguage(locale) == SUCCESS 的等价：当前引擎已是该语言，或可用该语言语音重建引擎 */
  private async trySetLanguage(tag: string): Promise<boolean> {
    if (tag.length === 0) {
      return false;
    }
    const wantsRegion: boolean = tag.indexOf('-') > 0 || tag.indexOf('_') > 0;
    if (this.engine !== null && this.engineLanguage.length > 0) {
      if (wantsRegion ? sameTag(this.engineLanguage, tag) : languageOf(this.engineLanguage) === languageOf(tag)) {
        return true;
      }
    }
    await this.loadVoices();
    let voice: textToSpeech.VoiceInfo | null = null;
    for (let i = 0; i < this.voices.length; i++) {
      const v: textToSpeech.VoiceInfo = this.voices[i];
      if (wantsRegion ? sameTag(v.language, tag) : languageOf(v.language) === languageOf(tag)) {
        voice = v;
        break;
      }
    }
    if (voice !== null) {
      return await this.switchEngine(voice.language, voice.person);
    }
    if (this.voices.length === 0) {
      // 拿不到语音列表：直接以该语言创建（不支持时引擎报 1002300002）
      return await this.switchEngine(tag, 0);
    }
    return false;
  }

  private async switchEngine(language: string, person: number): Promise<boolean> {
    const created: textToSpeech.TextToSpeechEngine | null = await this.createEngine(language, person);
    if (created === null) {
      return false;
    }
    this.releaseEngine();
    this.engine = created;
    this.engineLanguage = language;
    return true;
  }

  private async createEngine(language: string, person: number): Promise<textToSpeech.TextToSpeechEngine | null> {
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: language,
        person: person,
        online: ENGINE_OFFLINE
      };
      const e: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine(params);
      // Can only set this once engine has been initialized
      e.setListener(this.listener);
      return e;
    } catch (err) {
      const be: BusinessError = err as BusinessError;
      console.error(LOG_TAG, `Failed to load TextToSpeech object (${language}): ${be?.code} ${be?.message}`);
      return null;
    }
  }

  private async loadVoices(): Promise<void> {
    if (this.voicesLoaded) {
      return;
    }
    try {
      this.requestCounter++;
      const query: textToSpeech.VoiceQuery = {
        requestId: `feeder_tts_voices_${Date.now()}_${this.requestCounter}`,
        online: ENGINE_OFFLINE
      };
      this.voices = await textToSpeech.listVoices(query);
      this.voicesLoaded = true;
    } catch (err) {
      console.warn(LOG_TAG, `listVoices failed: ${JSON.stringify(err)}`);
      this.voices = [];
    }
  }

  /** 源 TextToSpeech(context, this) + onInit：成功返回 true（initializedState == SUCCESS） */
  private async ensureEngine(): Promise<boolean> {
    if (this.engine !== null) {
      return true;
    }
    await this.loadVoices();
    if (this.voices.length > 0) {
      for (let i = 0; i < this.voices.length; i++) {
        if (await this.switchEngine(this.voices[i].language, this.voices[i].person)) {
          return true;
        }
      }
      return false;
    }
    return await this.switchEngine(FALLBACK_ENGINE_LANGUAGE, 0);
  }

  /** 源 updateAvailableLanguages()（:269） */
  private async updateAvailableLanguages(): Promise<void> {
    await this.loadVoices();
    const engineLanguages: string[] = [];
    for (let i = 0; i < this.voices.length; i++) {
      engineLanguages.push(this.voices[i].language);
    }
    const all: string[] = sortedLocales(detectLocaleFromText(this.textToSpeechQueue.join('\n\n'), 0))
      .concat(stableSortByKey(getSystemLocales(), displaySortKey))
      .concat(stableSortByKey(engineLanguages, displaySortKey));
    const seen: Set<string> = new Set<string>();
    const sortedLanguages: string[] = [];
    for (let i = 0; i < all.length; i++) {
      const tag: string = normalizeTag(all[i]);
      if (seen.has(tag)) {
        continue;
      }
      seen.add(tag);
      sortedLanguages.push(tag);
    }
    this.state.availableLanguages = sortedLanguages;
  }

  /** 源 Toast.makeText(context, R.string.failed_to_load_text_to_speech, LENGTH_SHORT)（RA-A06） */
  private showLoadFailedToast(): void {
    this.showLoadFailedToastAsync().catch((e: Error) => {
      console.warn(LOG_TAG, `toast failed: ${e?.message}`);
    });
  }

  private async showLoadFailedToastAsync(): Promise<void> {
    let ui: UIContext | null = this.uiContext;
    if (ui === null) {
      const ctx: common.UIAbilityContext | null = AppBootstrap.context();
      if (ctx === null) {
        return;
      }
      const w: window.Window = await window.getLastWindow(ctx);
      ui = w.getUIContext();
    }
    ui.getPromptAction().showToast({
      message: $r('app.string.failed_to_load_text_to_speech'),
      duration: 2000
    });
  }
}

/** 底栏（播客栏 / 朗读栏）滑入滑出动画时长（源 AnimatedVisibility 默认 256ms） */
export const PLAYER_BAR_ANIMATION_MS: number = 256;

/**
 * 底栏"完全收起"状态（源 FeedScreen.kt:1264：bottomBarVisibleState.isIdle && !targetState，RA-A24）。
 *  - 底栏可见（播客可见 || 朗读非 STOPPED）→ fullyCollapsed=false（立即）；
 *  - 底栏转为不可见 → 等待滑出动画（PLAYER_BAR_ANIMATION_MS）结束后 fullyCollapsed=true；期间再次可见则取消。
 * Feed 页独立 FAB 应以 `vm.showFab && fullyCollapsed` 为显示条件，而不是 `!bottomBarVisible`。
 * 由 TTSStateHolder.setStatus / PodcastPlayerStateHolder.publish 在写 FeedPageHooks.state 后调用 sync()。
 */
@ObservedV2
export class PlayerBarCollapseState {
  private static inst: PlayerBarCollapseState | null = null;
  @Trace fullyCollapsed: boolean = true;
  private timerId: number = -1;

  static instance(): PlayerBarCollapseState {
    if (PlayerBarCollapseState.inst === null) {
      PlayerBarCollapseState.inst = new PlayerBarCollapseState();
    }
    return PlayerBarCollapseState.inst as PlayerBarCollapseState;
  }

  private static barVisible(): boolean {
    return FeedPageHooks.state.podcastPlayerVisible || FeedPageHooks.state.ttsActive;
  }

  sync(): void {
    if (PlayerBarCollapseState.barVisible()) {
      this.cancelTimer();
      if (this.fullyCollapsed) {
        this.fullyCollapsed = false;
      }
      return;
    }
    if (this.fullyCollapsed || this.timerId !== -1) {
      return;
    }
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      if (!PlayerBarCollapseState.barVisible()) {
        this.fullyCollapsed = true;
      }
    }, PLAYER_BAR_ANIMATION_MS);
  }

  private cancelTimer(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }
}
