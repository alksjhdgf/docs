/**
 * Skeleton — skeleton placeholders + shimmer (source: core/ui/component/skeleton/Skeleton.kt).
 *
 * Exports: skeletonColor(), SkeletonContent, SkeletonBlock, SkeletonCircle, SkeletonTextLine, SkeletonImage,
 * SkeletonParagraph, SkeletonCard, SkeletonList, SKELETON_* default constants.
 *
 * Shimmer: the com.valentinilk.shimmer library (DstIn alpha mask, 0.25 → 1 → 0.25 band, 15° tilt,
 * tween(800) + 1500 ms delay, bounds = the view) is degraded to: a base layer at 25 % opacity plus a
 * linearGradient band (transparent → color → transparent, 105°) that sweeps across the block with an infinite
 * linear animateTo (2300 ms cycle; the band crosses the block in ~800 ms, then stays off-block ~1500 ms).
 *
 * Sizing (custom components must not be chained with attributes, conventions §A): every block takes
 * its size through params (`skWidth` / `skHeight` / `skAspectRatio`); to take a weight in a Row, wrap the block
 * in `Column() { SkeletonBlock({ skWidth: '100%', ... }) }.layoutWeight(1)`.
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';

/** DefaultSkeletonAvatarSize */
export const SKELETON_AVATAR_SIZE: number = 40;
/** DefaultSkeletonImageSize */
export const SKELETON_IMAGE_SIZE: number = 96;
/** DefaultSkeletonTextLineHeight */
export const SKELETON_TEXT_LINE_HEIGHT: number = 16;
/** DefaultSkeletonLineSpacing = SpaceVerticalSmall */
export const SKELETON_LINE_SPACING: number = Dimens.spaceVerticalSmall;
/** DefaultSkeletonLineFractions */
export const SKELETON_LINE_FRACTIONS: number[] = [0.42, 1, 1, 0.64];

/** Shimmer cycle: 800 ms sweep + 1500 ms delay */
const SHIMMER_CYCLE_MS: number = 2300;
/** translate range of the band (in % of the block width) so that -100 → 100 takes 800 ms of the cycle */
const SHIMMER_FROM: string = '-100%';
const SHIMMER_TO: string = '475%';
/** Base layer alpha under the shimmer mask (valentinilk default shader colors 0.25 / 1 / 0.25) */
const SHIMMER_BASE_ALPHA: number = 0.25;

/**
 * Default skeleton color (source defaultSkeletonColor): onSurface @ 0.14 on dark backgrounds,
 * onSurface @ 0.1 otherwise (onSurface = text_primary: light #181818 / dark #D1D1D1).
 */
export function skeletonColor(): string {
  return ThemeManager.instance.isDark ? '#24D1D1D1' : '#1A181818';
}

/** Width fraction (0..1, clamped) → percentage string (source fillMaxWidth(widthFraction.coerceIn(0f, 1f))) */
function fractionToPercent(fraction: number): string {
  const f: number = fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
  return (f * 100) + '%';
}

/**
 * Rectangular skeleton block (source SkeletonBlock + Modifier.skeleton()).
 * Default shape = MaterialTheme.shapes.medium (ShapeMedium, 12vp).
 */
@ComponentV2
export struct SkeletonBlock {
  @Param skWidth: Length = '100%';
  @Param skHeight: Length = SKELETON_TEXT_LINE_HEIGHT;
  /** > 0: height derived from width (source Modifier.aspectRatio); skHeight is then ignored */
  @Param skAspectRatio: number = 0;
  @Param skRadius: Length | BorderRadiuses = Dimens.radiusMedium;
  /** undefined → skeletonColor() */
  @Param skColor: ResourceColor | undefined = undefined;
  @Param shimmerEnabled: boolean = true;
  @Local shimmerX: string = SHIMMER_FROM;

  private startShimmer(): void {
    if (!this.shimmerEnabled) {
      return;
    }
    this.shimmerX = SHIMMER_FROM;
    this.getUIContext().animateTo({ duration: SHIMMER_CYCLE_MS, curve: Curve.Linear, iterations: -1 }, () => {
      this.shimmerX = SHIMMER_TO;
    });
  }

  private resolvedColor(): ResourceColor {
    return this.skColor !== undefined ? this.skColor as ResourceColor : skeletonColor();
  }

  /** Base layer + shimmer band (both pure display layers) */
  @Builder
  layers() {
    // Base layer (faint under the shimmer mask, full color without shimmer)
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(this.resolvedColor())
      .opacity(this.shimmerEnabled ? SHIMMER_BASE_ALPHA : 1)
      .hitTestBehavior(HitTestMode.None)
    if (this.shimmerEnabled) {
      // Moving highlight band
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 105,
          colors: [['rgba(0,0,0,0)', 0], [this.resolvedColor(), 0.5], ['rgba(0,0,0,0)', 1]]
        })
        .translate({ x: this.shimmerX })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  build() {
    if (this.skAspectRatio > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.layers()
      }
      .width(this.skWidth)
      .aspectRatio(this.skAspectRatio)
      .borderRadius(this.skRadius)
      .clip(true)
      .hitTestBehavior(HitTestMode.Transparent)
      .onAppear(() => {
        this.startShimmer();
      })
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        this.layers()
      }
      .width(this.skWidth)
      .height(this.skHeight)
      .borderRadius(this.skRadius)
      .clip(true)
      .hitTestBehavior(HitTestMode.Transparent)
      .onAppear(() => {
        this.startShimmer();
      })
    }
  }
}

/** Circle skeleton (source SkeletonCircle, default 40vp) */
@ComponentV2
export struct SkeletonCircle {
  @Param skSize: number = SKELETON_AVATAR_SIZE;
  @Param skColor: ResourceColor | undefined = undefined;
  @Param shimmerEnabled: boolean = true;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SkeletonBlock({
        skWidth: this.skSize,
        skHeight: this.skSize,
        skRadius: this.skSize / 2,
        skColor: this.skColor,
        shimmerEnabled: this.shimmerEnabled
      })
    }
    .width(this.skSize)
    .height(this.skSize)
  }
}

/**
 * Text line skeleton (source SkeletonTextLine): width = widthFraction of the parent, height 16vp,
 * shape ShapeSmall (8vp).
 */
@ComponentV2
export struct SkeletonTextLine {
  @Param widthFraction: number = 1;
  @Param skHeight: Length = SKELETON_TEXT_LINE_HEIGHT;
  @Param skRadius: Length | BorderRadiuses = Dimens.radiusSmall;
  @Param skColor: ResourceColor | undefined = undefined;
  @Param shimmerEnabled: boolean = true;

  build() {
    Row() {
      SkeletonBlock({
        skWidth: fractionToPercent(this.widthFraction),
        skHeight: this.skHeight,
        skRadius: this.skRadius,
        skColor: this.skColor,
        shimmerEnabled: this.shimmerEnabled
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start) // source fillMaxWidth(fraction) starts at the left edge
    .alignItems(VerticalAlign.Top)
  }
}

/** Image skeleton (source SkeletonImage, default 96vp square, ShapeMedium) */
@ComponentV2
export struct SkeletonImage {
  @Param skSize: number = SKELETON_IMAGE_SIZE;
  @Param skRadius: Length | BorderRadiuses = Dimens.radiusMedium;
  @Param skColor: ResourceColor | undefined = undefined;
  @Param shimmerEnabled: boolean = true;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SkeletonBlock({
        skWidth: this.skSize,
        skHeight: this.skSize,
        skRadius: this.skRadius,
        skColor: this.skColor,
        shimmerEnabled: this.shimmerEnabled
      })
    }
    .width(this.skSize)
    .height(this.skSize)
  }
}

/**
 * Paragraph skeleton (source SkeletonParagraph): optional avatar + `rows` text lines whose widths come from
 * lineFractions (missing entries repeat the last one; empty list → all 1.0).
 */
@ComponentV2
export struct SkeletonParagraph {
  @Param rows: number = 4;
  @Param lineFractions: number[] = SKELETON_LINE_FRACTIONS;
  @Param lineHeight: Length = SKELETON_TEXT_LINE_HEIGHT;
  @Param lineSpacing: number = SKELETON_LINE_SPACING;
  @Param avatar: boolean = false;
  @Param avatarSize: number = SKELETON_AVATAR_SIZE;
  @Param skColor: ResourceColor | undefined = undefined;
  @Param shimmerEnabled: boolean = true;

  private widths(): number[] {
    const result: number[] = [];
    for (let i = 0; i < this.rows; i++) {
      if (this.lineFractions.length === 0) {
        result.push(1);
      } else if (i < this.lineFractions.length) {
        result.push(this.lineFractions[i]);
      } else {
        result.push(this.lineFractions[this.lineFractions.length - 1]);
      }
    }
    return result;
  }

  build() {
    // Source Row(fillMaxWidth, spacedBy(SpaceHorizontalMedium)) with default Top alignment
    Row({ space: Dimens.spaceHorizontalMedium }) {
      if (this.avatar) {
        SkeletonCircle({ skSize: this.avatarSize, skColor: this.skColor, shimmerEnabled: this.shimmerEnabled })
      }
      Column({ space: this.lineSpacing }) {
        ForEach(this.widths(), (w: number, index: number) => {
          SkeletonTextLine({
            widthFraction: w,
            skHeight: this.lineHeight,
            skColor: this.skColor,
            shimmerEnabled: this.shimmerEnabled
          })
        }, (w: number, index: number) => index + '_' + w)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }
}

/** Card skeleton (source SkeletonCard): image block (160vp) + 3 lines 0.72 / 1 / 0.48, spacedBy 12 */
@ComponentV2
export struct SkeletonCard {
  @Param imageHeight: number = 160;
  @Param shimmerEnabled: boolean = true;

  build() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      SkeletonBlock({
        skWidth: '100%',
        skHeight: this.imageHeight,
        skRadius: Dimens.radiusMedium,
        shimmerEnabled: this.shimmerEnabled
      })
      SkeletonTextLine({ widthFraction: 0.72, shimmerEnabled: this.shimmerEnabled })
      SkeletonTextLine({ widthFraction: 1, shimmerEnabled: this.shimmerEnabled })
      SkeletonTextLine({ widthFraction: 0.48, shimmerEnabled: this.shimmerEnabled })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** List skeleton (source SkeletonList): `count` paragraphs (3 rows, avatar, 0.48 / 1 / 0.68), spacedBy 12 */
@ComponentV2
export struct SkeletonList {
  @Param count: number = 3;
  @Param shimmerEnabled: boolean = true;

  private indices(): number[] {
    const result: number[] = [];
    for (let i = 0; i < this.count; i++) {
      result.push(i);
    }
    return result;
  }

  build() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      ForEach(this.indices(), (i: number) => {
        SkeletonParagraph({
          rows: 3,
          avatar: true,
          lineFractions: [0.48, 1, 0.68],
          shimmerEnabled: this.shimmerEnabled
        })
      }, (i: number) => 'sk_list_' + i)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Skeleton / content switch (source SkeletonContent) */
@ComponentV2
export struct SkeletonContent {
  @Param loading: boolean = true;
  @BuilderParam skeleton: () => void = this.emptyBuilder;
  @BuilderParam content: () => void = this.emptyBuilder;

  @Builder
  emptyBuilder() {
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loading) {
        this.skeleton()
      } else {
        this.content()
      }
    }
    .width('100%')
  }
}
