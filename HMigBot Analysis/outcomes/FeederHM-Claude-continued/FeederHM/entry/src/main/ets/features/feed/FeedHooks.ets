/**
 * FeedHooks — Feed 页对“非本单元依赖”的反向注入点（conventions §C：setXxxHook，未注册 no-op）。
 *  - 底栏播客条 / 朗读条（源 HideablePodcastPlayer / HideableTTSPlayer，归 core-readaloud-podcast）：
 *    FeedExternalState.podcastPlayerVisible / ttsActive + WrappedBuilder 注册。
 */

/** 外部单元写入、Feed 页只读的可观察状态 */
@ObservedV2
export class FeedExternalState {
  /** 源 podcastPlayerState.isVisible */
  @Trace podcastPlayerVisible: boolean = false;
  /** 源 ttsStateHolder.ttsState != STOPPED */
  @Trace ttsActive: boolean = false;
  /** 底栏 builder 注册版本（setPlayerBarBuilders 每次递增，页面据此重取 builder） */
  @Trace barsVersion: number = 0;
}

/** 底栏 builder 参数（TTS 条可内嵌 FAB；播客条不嵌，源 FeedScreen.kt:1242） */
export class FeedBottomBarArgs {
  showFab: boolean = false;
  bottomInset: number = 0;
  onFabClick: () => void = () => {
    console.info('TODO:onFabClick:FeedBottomBarArgs');
  };
}

export class FeedPageHooks {
  static readonly state: FeedExternalState = new FeedExternalState();
  private static podcastBar: WrappedBuilder<[FeedBottomBarArgs]> | null = null;
  private static ttsBar: WrappedBuilder<[FeedBottomBarArgs]> | null = null;

  static setPlayerBarBuilders(podcast: WrappedBuilder<[FeedBottomBarArgs]> | null,
    tts: WrappedBuilder<[FeedBottomBarArgs]> | null): void {
    FeedPageHooks.podcastBar = podcast;
    FeedPageHooks.ttsBar = tts;
    FeedPageHooks.state.barsVersion = FeedPageHooks.state.barsVersion + 1;
  }

  static podcastBarBuilder(): WrappedBuilder<[FeedBottomBarArgs]> | null {
    return FeedPageHooks.podcastBar;
  }

  static ttsBarBuilder(): WrappedBuilder<[FeedBottomBarArgs]> | null {
    return FeedPageHooks.ttsBar;
  }

  /** 源 isBottomBarVisible = tts != STOPPED || podcast.isVisible（仅在对应底栏已注册时成立） */
  static isPodcastBarVisible(): boolean {
    return FeedPageHooks.state.podcastPlayerVisible && FeedPageHooks.podcastBar !== null;
  }

  static isTtsBarVisible(): boolean {
    return FeedPageHooks.state.ttsActive && FeedPageHooks.ttsBar !== null;
  }

  static isBottomBarVisible(): boolean {
    return FeedPageHooks.isPodcastBarVisible() || FeedPageHooks.isTtsBarVisible();
  }
}
