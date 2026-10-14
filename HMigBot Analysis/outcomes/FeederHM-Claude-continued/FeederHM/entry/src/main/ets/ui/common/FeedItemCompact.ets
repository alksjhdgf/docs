/*
 * FeedItemCompact — 源 ui/compose/feed/FeedItemCompact.kt（FeedItemStyle.COMPACT）
 * 与 ui/compose/feed/FeedItemCompactCard.kt（FeedItemStyle.COMPACT_CARD）。
 *
 * COMPACT（FI-A24）：Surface（直角，已读整体 75%）→ Row(起始内边距 margin，间距 4vp，行高 = 文本列高)：
 *  文本列（最小高 48vp，上下 8vp）+ 右列：
 *   - 收藏且 bookmarkIndicator → 64vp 宽列，居中 24vp 星标（不显示图片；showThumbnail=false 也显示）；
 *   - 否则 showThumbnail 且 (条目图 ?: 订阅源图标)：宽 imageWidth（外壳传 64，紧凑横屏 196）× 行高，
 *     条目图受限裁切填充、订阅源图标受限完整适配，无障碍不朗读；
 *   - 都没有 → 宽 (margin − 4) 的空白。
 * COMPACT_CARD（FI-A22/A23）：ElevatedCard（12vp 圆角）→ 层叠：
 *   - showThumbnail：有图则 16:9 缩略图（裁切、74% 不透明，不过滤极小图）；无论有无图都叠黑色竖向渐变（0.8→0.38→0.8，
 *     渐变长度 = 宽×9/16），文字白色；showThumbnail=false 为普通卡片配色；
 *   - 右上角 Row（高 24vp，上/左右 8vp 内边距）：收藏星标（收藏且 bookmarkIndicator）、未读圆点（未读）、
 *     订阅源图标（feedImageUrl 为合法 http(s) URL）；
 *   - 底部标题区（顶部 48vp 内边距，底对齐）：FeedItemText，showOnlyTitle 恒为 true。
 */
import { LengthMetrics } from '@kit.ArkUI';
import { FeedListItem } from '../../core/model/FeedItem';
import { FeederTheme } from './Theme';
import { FeederImage, RestrainedScale } from './CommonWidgets';
import {
  FeedItemText,
  FeedItemHandlers,
  FeedItemSavedIndicator,
  FeedItemNewIndicator,
  FeedItemFeedIconIndicator,
  emptyFeedListItem,
  isHttpUrl,
  MINIMUM_TOUCH_SIZE
} from './FeedItemText';
import { FEED_CARD_CORNER_RADIUS, elevatedCardColor } from './FeedItemCard';

const COMPACT_STAR_COLUMN_WIDTH: number = 64;
const COMPACT_CARD_ICON_SIZE: number = 24;
const COMPACT_CARD_ICON_PADDING: number = 8;
const WHITE: string = '#FFFFFFFF';

// ================================================================== COMPACT

@ComponentV2
export struct FeedItemCompact {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param showThumbnail: boolean = true;
  @Param bookmarkIndicator: boolean = true;
  @Param maxLines: number = 2;
  @Param showOnlyTitle: boolean = false;
  @Param showReadingTime: boolean = false;
  @Param menuShown: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  /** 源 imageWidth：64vp；紧凑横屏 196vp（外壳决定） */
  @Param imageWidth: number = 64;
  @Event onDismissMenu: () => void = () => {
    console.debug('FeedItemCompact: dismiss menu');
  };
  /** 源 height(IntrinsicSize.Min)：右列高度 = 文本列测得高度 */
  @Local rowHeight: number = 0;

  private showStar(): boolean {
    return this.item.bookmarked && this.bookmarkIndicator;
  }

  /** 源 item.image?.url ?: item.feedImageUrl */
  private rightImageUrl(): string | null {
    const img = this.item.image;
    if (img !== null) {
      return img.url;
    }
    return this.item.feedImageUrl;
  }

  private showRightColumn(): boolean {
    return this.showStar() || (this.showThumbnail && (this.item.image !== null || this.item.feedImageUrl !== null));
  }

  build() {
    Row({ space: 4 }) {
      Column() {
        FeedItemText({
          item: this.item,
          maxLines: this.maxLines,
          showOnlyTitle: this.showOnlyTitle,
          showReadingTime: this.showReadingTime,
          menuShown: this.menuShown,
          handlers: this.handlers,
          onDismissMenu: () => {
            this.onDismissMenu();
          }
        })
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
      .padding({ top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.rowHeight = newArea.height as number;
      })

      if (this.showRightColumn()) {
        if (this.showStar()) {
          // 源 Box(fillMaxHeight, TopEnd){ EitherIndicator(fillMaxHeight, width 64) } → 星标在 64×行高 中居中
          Stack({ alignContent: Alignment.Center }) {
            FeedItemSavedIndicator({ iconSize: 24 })
          }
          .width(COMPACT_STAR_COLUMN_WIDTH)
          .height(this.rowHeight)
        } else if (this.rightImageUrl() !== null) {
          Stack({ alignContent: Alignment.TopEnd }) {
            FeederImage({
              url: this.rightImageUrl() as string,
              scaleMode: this.item.image !== null ? RestrainedScale.CROP : RestrainedScale.FIT,
              boxWidth: this.imageWidth,
              boxHeightVp: this.rowHeight,
              iconSize: 24,
              altText: ''
            })
          }
          .width(this.imageWidth)
          .height(this.rowHeight)
          .accessibilityLevel('no')
        }
      } else {
        // Taking Row spacing into account
        Column()
          .width(FeederTheme.dimens.margin - 4)
          .height(1)
      }
    }
    .width('100%')
    .padding({ start: LengthMetrics.vp(FeederTheme.dimens.margin) })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
    .backgroundColor(FeederTheme.colors.surface)
    .opacity(this.item.unread ? 1.0 : 0.75)
  }
}

// ================================================================== COMPACT_CARD

/** 渐变色标（源 gradientColors：黑 0.8 → 0.38 → 0.8，startY=0，endY=图片高） */
function gradientAlphaAt(y: number, imageHeight: number): number {
  if (imageHeight <= 0) {
    return 0.8;
  }
  const t = Math.min(Math.max(y / imageHeight, 0), 1);
  if (t <= 0.5) {
    return 0.8 + (0.38 - 0.8) * (t / 0.5);
  }
  return 0.38 + (0.8 - 0.38) * ((t - 0.5) / 0.5);
}

function blackWithAlpha(alpha: number): string {
  const a = Math.round(Math.min(Math.max(alpha, 0), 1) * 255);
  const hex = a.toString(16).toUpperCase();
  return `#${hex.length < 2 ? '0' + hex : hex}000000`;
}

/** 把以图片高度为长度的渐变换算成以整个卡片高度为基准的 linearGradient 色标（超出部分保持末端色） */
export function compactCardGradientStops(imageHeight: number, boxHeight: number): Array<[ResourceColor, number]> {
  const stops: Array<[ResourceColor, number]> = [];
  if (boxHeight <= 0) {
    stops.push([blackWithAlpha(0.8), 0]);
    stops.push([blackWithAlpha(0.8), 1]);
    return stops;
  }
  const ys: number[] = [0, imageHeight / 2, imageHeight, boxHeight];
  for (let i = 0; i < ys.length; i++) {
    const y = Math.min(ys[i], boxHeight);
    const pos = y / boxHeight;
    if (stops.length > 0 && pos <= stops[stops.length - 1][1]) {
      continue;
    }
    stops.push([blackWithAlpha(gradientAlphaAt(y, imageHeight)), pos]);
  }
  if (stops.length === 1) {
    stops.push([blackWithAlpha(gradientAlphaAt(boxHeight, imageHeight)), 1]);
  }
  return stops;
}

/** 源 data class FeedItemState（仅 COMPACT_CARD 使用的状态风格）；鸿蒙以 @Param 逐项传入 */
@ComponentV2
export struct FeedItemCompactCard {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param showThumbnail: boolean = true;
  @Param bookmarkIndicator: boolean = true;
  @Param maxLines: number = 2;
  @Param showReadingTime: boolean = false;
  @Param menuShown: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Event onDismissMenu: () => void = () => {
    console.debug('FeedItemCompactCard: dismiss menu');
  };
  @Local boxWidth: number = 0;
  @Local boxHeight: number = 0;
  @Local articleImageText: string = '';

  aboutToAppear(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.articleImageText = ctx.resourceManager.getStringSync($r('app.string.article_image').id);
      }
    } catch (e) {
      this.articleImageText = 'Article image';
    }
  }

  private imageUrl(): string | null {
    const img = this.item.image;
    return img === null ? null : img.url;
  }

  private hasImage(): boolean {
    return this.showThumbnail && this.imageUrl() !== null;
  }

  /** 16:9 图片高度（源 sizePx.height，渐变长度也取此值） */
  private imageHeight(): number {
    return this.boxWidth * 9 / 16;
  }

  private textColor(): string {
    return this.showThumbnail ? WHITE : '';
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.hasImage()) {
          Column() {
            FeederImage({
              url: this.imageUrl() as string,
              scaleMode: RestrainedScale.CROP,
              boxWidth: '100%',
              boxHeightVp: this.imageHeight(),
              altText: this.articleImageText
            })
          }
          .width('100%')
          .height(this.imageHeight())
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .borderRadius(FEED_CARD_CORNER_RADIUS)
          .clip(true)
          .opacity(0.74)
          .accessibilityText(this.articleImageText)
        }
        if (this.showThumbnail) {
          // 源 Box(matchParentSize).background(verticalGradient)：纯装饰层，不拦截点击
          Column()
            .position({ x: 0, y: 0 })
            .width(this.boxWidth)
            .height(this.boxHeight)
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: compactCardGradientStops(this.imageHeight(), this.boxHeight)
            })
            .hitTestBehavior(HitTestMode.None)
        }
        // 底部标题区：source Box(width = maxWidth, padding top 48, align BottomCenter)
        Column() {
          Row() {
            Column() {
              FeedItemText({
                item: this.item,
                maxLines: this.maxLines,
                showOnlyTitle: true,
                showReadingTime: this.showReadingTime,
                textColor: this.textColor(),
                menuShown: this.menuShown,
                handlers: this.handlers,
                onDismissMenu: () => {
                  this.onDismissMenu();
                }
              })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(8)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .constraintSize({ minHeight: this.hasImage() ? this.imageHeight() : 0 })
        .padding({ top: 48 })
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.Center)
        // 右上角指示器（源 Row.height(24).padding(top 8, end 8, start 8).align(TopEnd)）
        Row() {
          if (this.item.bookmarked && this.bookmarkIndicator) {
            FeedItemSavedIndicator({ iconSize: COMPACT_CARD_ICON_SIZE - COMPACT_CARD_ICON_PADDING })
          }
          if (this.item.unread) {
            FeedItemNewIndicator({ iconSize: COMPACT_CARD_ICON_SIZE - COMPACT_CARD_ICON_PADDING })
          }
          if (isHttpUrl(this.item.feedImageUrl)) {
            FeedItemFeedIconIndicator({
              feedImageUrl: this.item.feedImageUrl as string,
              iconSize: COMPACT_CARD_ICON_SIZE - COMPACT_CARD_ICON_PADDING
            })
          }
        }
        .width('100%')
        .height(COMPACT_CARD_ICON_SIZE)
        .padding({ top: COMPACT_CARD_ICON_PADDING, left: COMPACT_CARD_ICON_PADDING, right: COMPACT_CARD_ICON_PADDING })
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Top)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
      .opacity(this.item.unread ? 1.0 : 0.75)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.boxWidth = newArea.width as number;
        this.boxHeight = newArea.height as number;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(elevatedCardColor())
    .borderRadius(FEED_CARD_CORNER_RADIUS)
    .clip(true)
    .shadow({ radius: 3, color: '#26000000', offsetX: 0, offsetY: 1 })
  }
}
