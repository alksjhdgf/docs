/**
 * WeBadge (source: core/ui/component/badge/Badge.kt).
 * A dot (content undefined) or a pill with white 10fp text, `badgeSize` tall (min width = badgeSize),
 * drawn over the `holder` content at `badgeAlignment` and pushed half outside it exactly like the source
 * offsets (TopEnd: +½ own width, −½ size; CenterStart/End: ∓(own width + 8)). The badge is purely
 * decorative and never takes touches, so the holder / parent keep their clicks.
 *
 *   WeBadge({ badgeContent: String(count), badgeSize: 16, badgeColor: $r('app.color.danger'),
 *             holder: (): void => { this.iconBuilder() } })
 */
import { WidgetColors } from './WidgetColors';

@Builder
function emptyBadgeHolder() {
}

@ComponentV2
export struct WeBadge {
  @Param badgeContent: string | undefined = undefined;
  @Param badgeSize: number = 10;
  @Param badgeColor: ResourceColor = WidgetColors.BADGE_RED;
  @Param badgeAlignment: Alignment = Alignment.TopEnd;
  @BuilderParam holder: () => void = emptyBadgeHolder;

  /** translate x relative to the badge's own width (percent string) */
  private translateX(): string {
    switch (this.badgeAlignment) {
      case Alignment.TopEnd:
      case Alignment.BottomEnd:
        return '50%';
      case Alignment.Top:
      case Alignment.Bottom:
      case Alignment.Center:
        return '0%';
      case Alignment.Start:
        return '-100%';
      case Alignment.End:
        return '100%';
      default:
        return '-50%';
    }
  }

  /** extra fixed x offset (CenterStart/CenterEnd add 8dp) */
  private extraX(): number {
    if (this.badgeAlignment === Alignment.Start) {
      return -8;
    }
    if (this.badgeAlignment === Alignment.End) {
      return 8;
    }
    return 0;
  }

  /** y offset = ±size/2 (badge height == size) */
  private translateY(): number {
    switch (this.badgeAlignment) {
      case Alignment.BottomStart:
      case Alignment.Bottom:
      case Alignment.BottomEnd:
        return this.badgeSize / 2;
      case Alignment.Start:
      case Alignment.End:
      case Alignment.Center:
        return 0;
      default:
        return -this.badgeSize / 2;
    }
  }

  /** Source pads 6dp horizontally once the text makes the badge wider than tall. */
  private isWide(): boolean {
    return this.badgeContent !== undefined && (this.badgeContent as string).length > 1;
  }

  build() {
    // Box { holder; badge.align(alignment) } — Stack alignContent places the badge
    Stack({ alignContent: this.badgeAlignment }) {
      this.holder()
      Row() {
        if (this.badgeContent !== undefined) {
          Text(this.badgeContent as string)
            .fontSize(10)
            .lineHeight(10)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .maxLines(1)
        }
      }
      .height(this.badgeSize)
      .constraintSize({ minWidth: this.badgeSize })
      .padding({ left: this.isWide() ? 6 : 0, right: this.isWide() ? 6 : 0 })
      // source: Box(contentAlignment = Center)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.badgeColor)
      .borderRadius(this.badgeSize / 2)
      .translate({ x: this.translateX(), y: this.translateY() })
      .offset({ x: this.extraX(), y: 0 })
      .hitTestBehavior(HitTestMode.None)
    }
  }
}
