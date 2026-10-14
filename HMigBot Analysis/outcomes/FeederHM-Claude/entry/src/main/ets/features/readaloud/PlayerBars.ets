/**
 * PlayerBars.ets —— 源 ui/compose/readaloud/ReadAloudPlayer.kt（HideableTTSPlayer / TTSPlayer）
 * + ui/compose/feedarticle/PodcastPlayerBar.kt（HideablePodcastPlayer / PodcastPlayerBar）的鸿蒙实现，Article / Feed 共用。
 *
 *  - ReadAloudBar（RA-A22/A23）：PaddedBottomAppBar actions = Stop / (Pause | Resume) / Skip to next / Set language（菜单：
 *    Use app default、Detect language、分隔线、每个可选语言自名）；Feed 版可内嵌 FAB（RA-A24）。
 *  - PodcastPlayerBar（RA-A36..A39）：surfaceColorAtElevation(3dp) 容器 > [不定进度条] > [滑块 + 当前…总时长 | 错误文字]
 *    > actions = Stop / (Pause | Play) / Seek back 10s / Seek forward 10s（后两者 canSeek 才可用）。
 *  - ArticlePlayerBottomBar（RA-A21/A35）：播客可见 → 播客栏（优先），否则朗读非 STOPPED → 朗读栏，否则不显示。
 *  - Feed 页底栏通过 FeedPageHooks.setPlayerBarBuilders 注册（本模块加载即注册，RA-A14/A24）。
 * 动画：源 AnimatedVisibility 自下滑入/滑出 256ms → TransitionEffect.move(BOTTOM)。
 */
import { FeederTheme, surfaceAtElevation } from '../../ui/common/Theme';
import { textStyle, M3Type } from '../../ui/common/Typography';
import { PaddedBottomAppBar } from '../../ui/common/CommonWidgets';
import { FeedBottomBarArgs, FeedPageHooks } from '../feed/FeedHooks';
import { formatPodcastDuration, PodcastPlayerState, PodcastPlayerStateHolder } from './PodcastPlayer';
import {
  LocaleOverride, PLAYER_BAR_ANIMATION_MS, PlaybackStatus, PlayerBarCollapseState, TTSStateHolder, TtsState
} from './ReadAloudStateHolder';
import { localeDisplayName } from './TextLanguageDetector';
import { ReadAloudActions } from './ReadAloudActions';
import { PodcastControls } from './PodcastLinks';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';

const BAR_ANIMATION_MS: number = PLAYER_BAR_ANIMATION_MS;

/** '#AARRGGBB' / '#RRGGBB' → 指定 alpha（M3 disabled = 38%） */
function withAlpha(color: string, alphaHex: string): string {
  const hex: string = color.startsWith('#') ? color.substring(1) : color;
  const rgb: string = hex.length === 8 ? hex.substring(2) : hex;
  return '#' + alphaHex + rgb;
}

/** 源 isBottomBarVisible = ttsState != STOPPED || podcastPlayerState.isVisible（ArticleViewModel:201） */
export function isPlayerBottomBarVisible(): boolean {
  return PodcastPlayerStateHolder.instance().playerState.isVisible ||
    TTSStateHolder.instance().state.ttsState !== PlaybackStatus.STOPPED;
}

/**
 * Feed 页独立 FAB 可显示：底栏已完全收起（滑出动画结束，源 FeedScreen.kt:1264 isIdle && !targetState，RA-A24）。
 * 可观察（读 PlayerBarCollapseState.fullyCollapsed @Trace），在 build 中调用即可随状态刷新。
 */
export function isPlayerBottomBarFullyCollapsed(): boolean {
  return PlayerBarCollapseState.instance().fullyCollapsed;
}

/** 源 IconButton + PlainTooltipBox（文案作无障碍描述） */
@ComponentV2
struct BarIconButton {
  @Param icon: Resource = $r('sys.symbol.play_fill');
  @Param label: Resource = $r('app.string.stop_reading');
  @Param isEnabled: boolean = true;
  @Event onTap: () => void = () => {
    console.info('TODO:tap:BarIconButton');
  };

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.icon)
        .fontSize(24)
        .fontColor([this.isEnabled ? FeederTheme.colors.onSurfaceVariant :
          withAlpha(FeederTheme.colors.onSurface, '61')])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(this.isEnabled)
    .accessibilityText(this.label)
    .onClick(() => {
      this.onTap();
    })
  }
}

/** 源 Translate 图标按钮 + DropdownMenu（RA-A23） */
@ComponentV2
struct LanguageMenuButton {
  @Param languages: string[] = [];
  @Event onSelectLanguage: (lang: LocaleOverride) => void = (lang: LocaleOverride) => {
    console.info('TODO:selectLanguage:LanguageMenuButton');
  };
  @Local showMenu: boolean = false;

  @Builder
  menuRow(label: ResourceStr, action: () => void) {
    Row() {
      Text(label)
        .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      action();
    })
  }

  @Builder
  languageMenuBuilder() {
    Scroll() {
      Column() {
        this.menuRow($r('app.string.use_app_default'), () => {
          this.onSelectLanguage(LocaleOverride.appSetting());
          this.showMenu = false;
        })
        this.menuRow($r('app.string.use_detect_language'), () => {
          this.onSelectLanguage(LocaleOverride.forcedAuto());
          this.showMenu = false;
        })
        Divider().color(FeederTheme.colors.outlineVariant)
        ForEach(this.languages, (lang: string) => {
          this.menuRow(localeDisplayName(lang), () => {
            this.onSelectLanguage(LocaleOverride.forcedLocale(lang));
            this.showMenu = false;
          })
        }, (lang: string) => lang)
      }
      .constraintSize({ minWidth: 112, maxWidth: 280 })
      .padding({ top: 8, bottom: 8 })
    }
    .constraintSize({ maxHeight: 420 })
    .scrollBar(BarState.Auto)
    // UT-A44：源 ReadAloudPlayer.kt:167 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.showMenu = false;
    }))
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.translate'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .accessibilityText($r('app.string.set_language'))
    .onClick(() => {
      this.showMenu = true;
    })
    .bindMenu(this.showMenu, (): void => {
      this.languageMenuBuilder()
    }, {
      onDisappear: () => {
        this.showMenu = false;
      }
    })
  }
}

/** 源 TTSPlayer（ReadAloudPlayer.kt:85） */
@ComponentV2
export struct ReadAloudBar {
  /** 导航条避让（vp） */
  @Param bottomInset: number = 0;
  /** Feed：栏内并入 FAB（源 floatingActionButton） */
  @Param showFab: boolean = false;
  /** 源 onPlay（Article / Feed 的 ttsPlay 不同） */
  @Event onPlay: () => void = () => {
    console.info('TODO:play:ReadAloudBar');
  };
  @Event onFabClick: () => void = () => {
    console.info('TODO:fabClick:ReadAloudBar');
  };
  @Local tts: TtsState = TTSStateHolder.instance().state;

  aboutToAppear(): void {
    TTSStateHolder.instance().attachUi(this.getUIContext());
  }

  @Builder
  barActions() {
    BarIconButton({
      icon: $r('sys.symbol.square_fill'),
      label: $r('app.string.stop_reading'),
      onTap: () => {
        ReadAloudActions.ttsStop();
      }
    })
    if (this.tts.ttsState === PlaybackStatus.PLAYING) {
      BarIconButton({
        icon: $r('sys.symbol.pause'),
        label: $r('app.string.pause_reading'),
        onTap: () => {
          ReadAloudActions.ttsPause();
        }
      })
    } else {
      BarIconButton({
        icon: $r('sys.symbol.play_fill'),
        label: $r('app.string.resume_reading'),
        onTap: () => {
          this.onPlay();
        }
      })
    }
    BarIconButton({
      icon: $r('sys.symbol.forward_end_fill'),
      label: $r('app.string.skip_to_next'),
      onTap: () => {
        ReadAloudActions.ttsSkipNext();
      }
    })
    LanguageMenuButton({
      languages: this.tts.availableLanguages,
      onSelectLanguage: (lang: LocaleOverride) => {
        ReadAloudActions.ttsOnSelectLanguage(lang);
      }
    })
  }

  /** 源 FeedScreen FloatingActionButton（DoneAll，mark_all_as_read） */
  @Builder
  barFab() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onPrimaryContainer])
    }
    .width(56)
    .height(56)
    .borderRadius(16)
    .backgroundColor(FeederTheme.colors.primaryContainer)
    .shadow({ radius: 6, color: '#33000000', offsetX: 0, offsetY: 3 })
    .accessibilityText($r('app.string.mark_all_as_read'))
    .onClick(() => {
      this.onFabClick();
    })
  }

  build() {
    Column() {
      PaddedBottomAppBar({
        bottomInset: this.bottomInset,
        hasFab: this.showFab,
        actionsBuilder: (): void => {
          this.barActions()
        },
        fabBuilder: (): void => {
          this.barFab()
        }
      })
    }
    .width('100%')
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: BAR_ANIMATION_MS }))
  }
}

/** 源 LinearProgressIndicator()（不定进度） */
@ComponentV2
struct PodcastIndeterminateProgress {
  @Local trackWidth: number = 0;
  @Local pos: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('30%')
        .height(4)
        .backgroundColor(FeederTheme.colors.primary)
        .translate({ x: this.pos * this.trackWidth * 1.3 - this.trackWidth * 0.3 })
    }
    .width('100%')
    .height(4)
    .clip(true)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .onAreaChange((o: Area, n: Area) => {
      this.trackWidth = n.width as number;
    })
    .onAppear(() => {
      this.getUIContext().animateTo({ duration: 1500, iterations: -1, curve: Curve.EaseInOut }, () => {
        this.pos = 1;
      });
    })
  }
}

/** 源 PodcastPlayerBar（PodcastPlayerBar.kt:74） */
@ComponentV2
export struct PodcastPlayerBar {
  @Param bottomInset: number = 0;
  @Local podcast: PodcastPlayerState = PodcastPlayerStateHolder.instance().playerState;
  /** 源 remember(viewState.audioUrl) { sliderPosition / isDragging } */
  @Local sliderPosition: number = 0;
  @Local isDragging: boolean = false;

  @Monitor('podcast.audioUrl')
  onAudioUrlChanged(): void {
    this.sliderPosition = 0;
    this.isDragging = false;
  }

  private maxPosition(): number {
    return Math.max(this.podcast.durationMillis, 0);
  }

  /** 拖动期间不被进度刷新覆盖（源 LaunchedEffect(positionMillis, isDragging)） */
  private sliderValue(): number {
    const v: number = this.isDragging ? this.sliderPosition : this.podcast.positionMillis;
    return Math.min(Math.max(v, 0), this.maxPosition());
  }

  private containerColor(): string {
    return surfaceAtElevation(FeederTheme.colors, 3);
  }

  private onSliderChange(value: number, mode: SliderChangeMode): void {
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.isDragging = true;
      this.sliderPosition = value;
    } else if (mode === SliderChangeMode.End) {
      this.sliderPosition = value;
      this.isDragging = false;
      PodcastControls.seekTo(Math.trunc(this.sliderPosition));
    } else if (mode === SliderChangeMode.Click) {
      this.sliderPosition = value;
      this.isDragging = false;
      PodcastControls.seekTo(Math.trunc(value));
    }
  }

  @Builder
  barActions() {
    BarIconButton({
      icon: $r('sys.symbol.square_fill'),
      label: $r('app.string.stop_audio'),
      onTap: () => {
        PodcastControls.stop();
      }
    })
    if (this.podcast.isPlaying) {
      BarIconButton({
        icon: $r('sys.symbol.pause'),
        label: $r('app.string.pause_audio'),
        onTap: () => {
          PodcastControls.pause();
        }
      })
    } else {
      BarIconButton({
        icon: $r('sys.symbol.play_fill'),
        label: $r('app.string.play_audio'),
        onTap: () => {
          PodcastControls.play();
        }
      })
    }
    BarIconButton({
      icon: $r('sys.symbol.gobackward_10'),
      label: $r('app.string.seek_back_10_seconds'),
      isEnabled: this.podcast.canSeek,
      onTap: () => {
        PodcastControls.seekBack();
      }
    })
    BarIconButton({
      icon: $r('sys.symbol.goforward_10'),
      label: $r('app.string.seek_forward_10_seconds'),
      isEnabled: this.podcast.canSeek,
      onTap: () => {
        PodcastControls.seekForward();
      }
    })
  }

  build() {
    Column() {
      if (this.podcast.isLoading || this.podcast.isBuffering) {
        PodcastIndeterminateProgress()
      }

      if (this.podcast.errorMessage === null) {
        Slider({
          value: this.sliderValue(),
          min: 0,
          max: this.maxPosition() > 0 ? this.maxPosition() : 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .padding({ left: 12, right: 12, top: 8 })
          .enabled(this.podcast.canSeek)
          .selectedColor(FeederTheme.colors.primary)
          .trackColor(FeederTheme.colors.surfaceContainerHighest)
          .blockColor(FeederTheme.colors.primary)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.onSliderChange(value, mode);
          })
        Row() {
          Text(formatPodcastDuration(this.podcast.positionMillis))
            .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
          Blank()
          Text(formatPodcastDuration(this.podcast.durationMillis))
            .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      } else {
        Text(this.podcast.errorMessage as Resource)
          .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.error))
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      PaddedBottomAppBar({
        bottomInset: this.bottomInset,
        containerColor: this.containerColor(),
        actionsBuilder: (): void => {
          this.barActions()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.containerColor())
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: BAR_ANIMATION_MS }))
  }
}

/**
 * Article 页底栏（源 ArticleScreen.kt:482-506）：播客可见 → 播客栏；否则朗读非 STOPPED → 朗读栏（RA-A21/A35）。
 * onTtsPlay 由 Article 页传 ReadAloudActions.articleTtsPlay(请求)。
 */
@ComponentV2
export struct ArticlePlayerBottomBar {
  @Param bottomInset: number = 0;
  @Event onTtsPlay: () => void = () => {
    console.info('TODO:ttsPlay:ArticlePlayerBottomBar');
  };
  @Local tts: TtsState = TTSStateHolder.instance().state;
  @Local podcast: PodcastPlayerState = PodcastPlayerStateHolder.instance().playerState;

  build() {
    Column() {
      if (this.podcast.isVisible) {
        PodcastPlayerBar({ bottomInset: this.bottomInset })
      } else if (this.tts.ttsState !== PlaybackStatus.STOPPED) {
        ReadAloudBar({
          bottomInset: this.bottomInset,
          onPlay: () => {
            this.onTtsPlay();
          }
        })
      }
    }
    .width('100%')
  }
}

// ================================================================== Feed 页底栏注册（RA-A14/A24）

@Builder
function feedPodcastBarBuilder(args: FeedBottomBarArgs) {
  PodcastPlayerBar({ bottomInset: args.bottomInset })
}

@Builder
function feedTtsBarBuilder(args: FeedBottomBarArgs) {
  ReadAloudBar({
    bottomInset: args.bottomInset,
    showFab: args.showFab,
    onPlay: () => {
      ReadAloudActions.feedTtsPlay();
    },
    onFabClick: () => {
      args.onFabClick();
    }
  })
}

let feedBarsRegistered: boolean = false;

/** 向 Feed 页注册播客栏 / 朗读栏（幂等；本模块加载时自动调用） */
export function registerFeedPlayerBars(): void {
  if (feedBarsRegistered) {
    return;
  }
  feedBarsRegistered = true;
  FeedPageHooks.setPlayerBarBuilders(wrapBuilder(feedPodcastBarBuilder), wrapBuilder(feedTtsBarBuilder));
  // 同步当前播放状态（单例可能先于注册已在播放）
  FeedPageHooks.state.podcastPlayerVisible = PodcastPlayerStateHolder.instance().playerState.isVisible;
  FeedPageHooks.state.ttsActive = TTSStateHolder.instance().state.ttsState !== PlaybackStatus.STOPPED;
  PlayerBarCollapseState.instance().sync();
}

registerFeedPlayerBars();
