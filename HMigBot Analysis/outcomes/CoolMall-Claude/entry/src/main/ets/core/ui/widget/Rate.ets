/**
 * WeRate — star rating (source: core/ui/component/rate/Rate.kt).
 * `count` (default 5) ic_star_fill icons of `starSize` (26), active #FF6700 / inactive #C0C0C0.
 * Interactive only when `changeable` (source: onChange != null): tap a star → index + 1, horizontal drag →
 * round(x / starSize) clamped to [0, count]. Animations: tapped star springs to 1.3x for 200ms; active
 * stars do a staggered (index * 50ms) 1.2x "fill" bounce when the value changes.
 * Read-only stars do not take part in hit testing, so a parent row/card keeps its clicks (A2-16).
 */
import { curves } from '@kit.ArkUI';
import { WidgetColors } from './WidgetColors';

@ComponentV2
export struct WeRate {
  @Param value: number = 0;
  @Param count: number = 5;
  @Param starSize: number = 26;
  @Param changeable: boolean = false;
  @Param animationEnabled: boolean = true;
  @Event onRateChange: (value: number) => void = (value: number) => {
  };
  @Local starScales: number[] = [];
  private clickedIndex: number = -1;
  private timers: number[] = [];
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.resetScales();
    this.bumpActive();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.clearTimers();
  }

  @Monitor('count')
  onCountChanged(): void {
    this.resetScales();
  }

  @Monitor('value')
  onValueChanged(): void {
    this.bumpActive();
  }

  private resetScales(): void {
    const arr: number[] = [];
    for (let i = 0; i < this.count; i++) {
      arr.push(1);
    }
    this.starScales = arr;
  }

  private clearTimers(): void {
    for (const t of this.timers) {
      clearTimeout(t);
    }
    this.timers = [];
  }

  private later(delay: number, action: () => void): void {
    const id: number = setTimeout(() => {
      if (this.alive) {
        action();
      }
    }, delay);
    this.timers.push(id);
  }

  private setScale(index: number, scale: number): void {
    if (index >= 0 && index < this.starScales.length) {
      this.starScales[index] = scale;
    }
  }

  /** LaunchedEffect(isActive, animationTrigger): active stars bounce 1.2 → 1 after index * 50ms. */
  private bumpActive(): void {
    if (!this.animationEnabled) {
      return;
    }
    for (let i = 0; i < this.count && i < this.value; i++) {
      const index: number = i;
      this.later(index * 50, () => {
        if (index !== this.clickedIndex) {
          this.setScale(index, 1.2);
        }
        this.later(150, () => {
          if (index !== this.clickedIndex) {
            this.setScale(index, 1);
          }
        });
      });
    }
  }

  private onStarTap(index: number): void {
    if (!this.changeable) {
      return;
    }
    if (this.animationEnabled) {
      this.clickedIndex = index;
      this.setScale(index, 1.3);
      this.later(200, () => {
        this.clickedIndex = -1;
        this.setScale(index, 1);
      });
    }
    this.onRateChange(index + 1);
  }

  private onDrag(localX: number): void {
    if (!this.changeable || this.starSize <= 0) {
      return;
    }
    const raw: number = Math.min(Math.max(localX / this.starSize, 0), this.count);
    const newValue: number = Math.min(Math.max(Math.round(raw), 0), this.count);
    if (newValue !== this.value) {
      this.onRateChange(newValue);
    }
  }

  private starScale(index: number): number {
    return index < this.starScales.length ? this.starScales[index] : 1;
  }

  build() {
    Row() {
      ForEach(this.starScales, (scale: number, index: number) => {
        Image($r('app.media.ic_star_fill'))
          .width(this.starSize)
          .height(this.starSize)
          .objectFit(ImageFit.Contain)
          .fillColor(index < this.value ? WidgetColors.STAR_ACTIVE : WidgetColors.STAR_INACTIVE)
          .accessibilityText($r('app.string.rate_star'))
          .scale({ x: this.starScale(index), y: this.starScale(index) })
          .animation({ curve: curves.springMotion(0.25, 0.55) })
          .onClick(() => {
            this.onStarTap(index);
          })
          .hitTestBehavior(this.changeable ? HitTestMode.Default : HitTestMode.None)
      }, (scale: number, index: number) => 'star_' + index)
    }
    // source: plain Row → start / top
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionUpdate((event: GestureEvent) => {
          if (event.fingerList.length > 0) {
            this.onDrag(event.fingerList[0].localX);
          }
        })
    )
    .hitTestBehavior(this.changeable ? HitTestMode.Default : HitTestMode.None)
  }
}
