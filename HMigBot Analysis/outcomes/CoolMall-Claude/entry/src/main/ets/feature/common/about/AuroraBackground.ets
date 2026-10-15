/**
 * AuroraBackground (source: AboutScreen.kt AnimatedAuroraBackground) — animated aurora behind the About header.
 *
 * Source: five radial-gradient light sources orbiting on a 15 s linear loop (time 0..2π), blurred 150dp,
 * drawn on black (dark) / background (light), with a vertical gradient mask (transparent at 10% →
 * background at 100%). Colors (HyperCeiler palette):
 *   dark : #004F94 · #874A26 · #750F45 · #291F73     light: #91C2FA · #FAD9AD · #FABFED · #BAB3FA
 *   5th light source = theme primary (ThemeManager.instance.primary).
 * Port: each light source is a circle node with a radialGradient (color@alpha → transparent) whose position
 * follows the same cos/sin formulas, re-evaluated by a ~30 fps timer (cleared in aboutToDisappear).
 * The 150dp Gaussian blur is omitted (radial gradients are already soft; full-screen blur per frame is too
 * costly) — visual approximation only.
 * Display only: never takes touches.
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';

/** One loop (source tween 15000 ms, LinearEasing, Restart) */
const AURORA_PERIOD_MS: number = 15000;
/** Timer step (~30 fps) */
const AURORA_FRAME_MS: number = 33;

const DARK_COLORS: string[] = ['#004F94', '#874A26', '#750F45', '#291F73'];
const LIGHT_COLORS: string[] = ['#91C2FA', '#FAD9AD', '#FABFED', '#BAB3FA'];

class AuroraLight {
  cx: number = 0;
  cy: number = 0;
  radius: number = 0;
  color: string = '';
  alpha: number = 0.9;

  constructor(cx: number, cy: number, radius: number, color: string, alpha: number) {
    this.cx = cx;
    this.cy = cy;
    this.radius = radius;
    this.color = color;
    this.alpha = alpha;
  }
}

@ComponentV2
export struct AuroraBackground {
  /** Animation time 0..2π */
  @Local auroraTime: number = 0;
  @Local areaWidth: number = 0;
  @Local areaHeight: number = 0;

  private timerId: number = -1;
  private startMs: number = 0;

  aboutToAppear(): void {
    this.startMs = Date.now();
    this.timerId = setInterval(() => {
      const elapsed: number = (Date.now() - this.startMs) % AURORA_PERIOD_MS;
      this.auroraTime = elapsed / AURORA_PERIOD_MS * 2 * Math.PI;
    }, AURORA_FRAME_MS);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private lights(): AuroraLight[] {
    const w: number = this.areaWidth;
    const h: number = this.areaHeight;
    const t: number = this.auroraTime;
    const pi: number = Math.PI;
    const palette: string[] = ThemeManager.instance.isDark ? DARK_COLORS : LIGHT_COLORS;
    const primary: string = ThemeManager.instance.primary;
    const result: AuroraLight[] = [];
    // Light 1
    result.push(new AuroraLight(w * (0.3 + 0.2 * Math.cos(t)), h * (0.4 + 0.2 * Math.sin(t)), w * 0.7,
      palette[0], 0.9));
    // Light 2
    result.push(new AuroraLight(w * (0.7 + 0.2 * Math.cos(t * 1.5 + pi)), h * (0.6 + 0.15 * Math.sin(t * 1.5 + pi)),
      w * 0.6, palette[1], 0.9));
    // Light 3
    result.push(new AuroraLight(w * (0.6 + 0.2 * Math.cos(t * 0.8 + pi / 2)),
      h * (0.3 + 0.2 * Math.sin(t * 0.8 + pi / 2)), w * 0.8, palette[2], 0.85));
    // Light 4
    result.push(new AuroraLight(w * (0.2 + 0.1 * Math.cos(t * 1.2 + pi / 4)),
      h * (0.7 + 0.1 * Math.sin(t * 1.2 + pi / 4)), w * 0.5, palette[3], 0.9));
    // Light 5: theme primary
    result.push(new AuroraLight(w * (0.8 + 0.15 * Math.cos(t * 0.9 + pi * 1.5)),
      h * (0.2 + 0.15 * Math.sin(t * 0.9 + pi * 1.5)), w * 0.7, primary, 0.9));
    return result;
  }

  /** Light source #index for the current frame (reads @Local state so the node updates every frame) */
  private lightAt(index: number): AuroraLight {
    return this.lights()[index];
  }

  /** Index-based builder (A2-7: read dynamic state through `this`, not through a value parameter) */
  @Builder
  lightSource(index: number) {
    Column()
      .width(this.lightAt(index).radius * 2)
      .height(this.lightAt(index).radius * 2)
      .position({
        x: this.lightAt(index).cx - this.lightAt(index).radius,
        y: this.lightAt(index).cy - this.lightAt(index).radius
      })
      .radialGradient({
        center: [this.lightAt(index).radius, this.lightAt(index).radius],
        radius: this.lightAt(index).radius,
        colors: [
          [ThemeManager.withAlpha(this.lightAt(index).color, this.lightAt(index).alpha), 0.0],
          [ThemeManager.withAlpha(this.lightAt(index).color, 0), 1.0]
        ]
      })
      .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Light sources (dark: on black for vividness; light: on the page background)
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.areaWidth > 0 && this.areaHeight > 0) {
          this.lightSource(0)
          this.lightSource(1)
          this.lightSource(2)
          this.lightSource(3)
          this.lightSource(4)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.instance.isDark ? Color.Black : $r('app.color.bg_page'))
      .clip(true)

      // Gradient mask: smooth transition into the page background
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [Color.Transparent, 0.1],
            [$r('app.color.bg_page'), 1.0]
          ]
        })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.areaWidth = Number(newArea.width);
      this.areaHeight = Number(newArea.height);
    })
  }
}
