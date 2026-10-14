/*
 * FeedItemCard — 源 ui/compose/feed/FeedItemCard.kt FeedItemCard（FeedItemStyle.CARD）。
 *
 * ElevatedCard → Column(间距 4vp，最小高 48vp，已读整体 75% 不透明)：
 *  - showThumbnail 且条目有图且图片已知宽高都 ≥10px（未知视为满足）时：顶部全宽 16:9 缩略图
 *    （受限裁切缩放、surfaceVariant 底、12vp 圆角裁切；加载中占位图标 / 失败错误图标；无障碍 `Article image`，FI-A21）；
 *  - Row(垂直居中，间距 8vp，内边距 8vp)：指示器 16vp（收藏星标 → 订阅源图标 → 空白）+ FeedItemText。
 * 紧凑横屏时由外壳传 showThumbnail=false（FI-A20）。
 */
import { FeedListItem } from '../../core/model/FeedItem';
import { FeederTheme } from './Theme';
import { FeederImage, RestrainedScale } from './CommonWidgets';
import {
  FeedItemText,
  FeedItemEitherIndicator,
  FeedItemHandlers,
  emptyFeedListItem,
  isThumbnailLargeEnough,
  MINIMUM_TOUCH_SIZE
} from './FeedItemText';

/** M3 shapes.medium 圆角 */
export const FEED_CARD_CORNER_RADIUS: number = 12;

/** M3 ElevatedCard 容器色（surfaceContainerLow；旧主题未给时回落 1dp 色调叠加的 surface） */
export function elevatedCardColor(): string {
  const c = FeederTheme.colors.surfaceContainerLow;
  return c !== '' ? c : FeederTheme.colors.surface;
}

@ComponentV2
export struct FeedItemCard {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param showThumbnail: boolean = true;
  @Param bookmarkIndicator: boolean = true;
  @Param maxLines: number = 2;
  @Param showOnlyTitle: boolean = false;
  @Param showReadingTime: boolean = false;
  @Param menuShown: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Event onDismissMenu: () => void = () => {
    console.debug('FeedItemCard: dismiss menu');
  };
  @Local cardWidth: number = 0;
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

  private showImage(): boolean {
    return this.showThumbnail && isThumbnailLargeEnough(this.item.image);
  }

  private imageUrl(): string {
    const img = this.item.image;
    return img === null ? '' : img.url;
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        if (this.showImage()) {
          // 源 alignment = Alignment.Center
          Stack({ alignContent: Alignment.Center }) {
            FeederImage({
              url: this.imageUrl(),
              scaleMode: RestrainedScale.CROP,
              boxWidth: '100%',
              boxHeightVp: this.cardWidth * 9 / 16,
              altText: this.articleImageText
            })
          }
          .width('100%')
          .height(this.cardWidth * 9 / 16)
          .backgroundColor(FeederTheme.colors.surfaceVariant)
          .borderRadius(FEED_CARD_CORNER_RADIUS)
          .clip(true)
          .accessibilityText(this.articleImageText)
        }
        Row({ space: 8 }) {
          FeedItemEitherIndicator({
            bookmarked: this.item.bookmarked && this.bookmarkIndicator,
            feedImageUrl: this.item.feedImageUrl,
            iconSize: 16
          })
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
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(8)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .opacity(this.item.unread ? 1.0 : 0.75)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(elevatedCardColor())
    .borderRadius(FEED_CARD_CORNER_RADIUS)
    .shadow({ radius: 3, color: '#26000000', offsetX: 0, offsetY: 1 })
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.cardWidth = newArea.width as number;
    })
  }
}
