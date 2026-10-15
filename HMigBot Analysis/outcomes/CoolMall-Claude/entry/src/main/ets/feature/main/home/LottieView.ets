/**
 * LottieView — plays a Lottie composition on a Canvas (source: BottomNavigationBar.kt TabLottieAnimation:
 * rememberLottieComposition(RawRes) + animateLottieCompositionAsState(isPlaying = isSelected) +
 * LottieAnimation(progress = if (!isSelected) 0f else progress, Modifier.size(30.dp)), HOME-A04).
 *
 * - lottiePlaying true  → plays once from the first frame to the end at the composition frame rate
 *   (restartOnPlay: every false → true change starts over), then holds the last frame
 * - lottiePlaying false → stops and shows the first frame
 * Frames are rendered by LottieRenderer; the playback timer is cleared in aboutToDisappear.
 */
import { LottieComposition } from './LottieComposition';
import { drawLottieFrame } from './LottieRenderer';

/** Playback timer step (~60 fps) */
const LOTTIE_FRAME_MS: number = 16;

@ComponentV2
export struct LottieView {
  /** Bodymovin JSON text */
  @Param lottieJson: string = '';
  /** Source isPlaying (= tab selected) */
  @Param lottiePlaying: boolean = false;
  /** View size in vp (source Modifier.size) */
  @Param lottieSize: number = 30;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private composition: LottieComposition | null = null;
  private canvasReady: boolean = false;
  private currentFrame: number = 0;
  private timerId: number = -1;
  private playStartMs: number = 0;

  aboutToAppear(): void {
    this.composition = LottieComposition.parse(this.lottieJson);
    this.currentFrame = this.composition !== null ? this.composition.inPoint : 0;
    if (this.lottiePlaying) {
      this.play();
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.canvasReady = false;
  }

  @Monitor('lottiePlaying')
  onPlayingChanged(monitor: IMonitor): void {
    if (this.lottiePlaying) {
      this.play();
    } else {
      // progress = 0f when not selected
      this.stopTimer();
      this.currentFrame = this.composition !== null ? this.composition.inPoint : 0;
      this.render();
    }
  }

  private play(): void {
    this.stopTimer();
    const comp: LottieComposition | null = this.composition;
    if (comp === null) {
      return;
    }
    this.currentFrame = comp.inPoint;
    this.playStartMs = Date.now();
    this.render();
    const duration: number = comp.durationMs();
    this.timerId = setInterval(() => {
      const progress: number = duration > 0 ? Math.min(1, (Date.now() - this.playStartMs) / duration) : 1;
      this.currentFrame = comp.inPoint + (comp.outPoint - comp.inPoint) * progress;
      this.render();
      if (progress >= 1) {
        this.stopTimer();
      }
    }, LOTTIE_FRAME_MS);
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private render(): void {
    if (!this.canvasReady || this.composition === null) {
      return;
    }
    drawLottieFrame(this.ctx, this.composition, this.currentFrame, this.lottieSize, this.lottieSize);
  }

  build() {
    Canvas(this.ctx)
      .width(this.lottieSize)
      .height(this.lottieSize)
      .hitTestBehavior(HitTestMode.Transparent) // display only: taps go to the tab item
      .onReady(() => {
        this.canvasReady = true;
        this.render();
      })
  }
}
