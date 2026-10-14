/*
 * FeedItemSuperCompact — 源 ui/compose/feed/FeedItemSuperCompact.kt（FeedItemStyle.SUPER_COMPACT，FI-A25）。
 * Surface（直角，最小高 48vp，已读整体 75%）→ Row(垂直居中，间距 8vp，上下 8vp / 左右 margin 内边距)：
 *  指示器 24vp（收藏星标 → 订阅源图标 → 空白）+ FeedItemText。从不显示缩略图。
 */
import { FeedListItem } from '../../core/model/FeedItem';
import { FeederTheme } from './Theme';
import {
  FeedItemText,
  FeedItemEitherIndicator,
  FeedItemHandlers,
  emptyFeedListItem,
  MINIMUM_TOUCH_SIZE
} from './FeedItemText';

@ComponentV2
export struct FeedItemSuperCompact {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param bookmarkIndicator: boolean = true;
  @Param maxLines: number = 2;
  @Param showOnlyTitle: boolean = false;
  @Param showReadingTime: boolean = false;
  @Param menuShown: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Event onDismissMenu: () => void = () => {
    console.debug('FeedItemSuperCompact: dismiss menu');
  };

  build() {
    Row({ space: 8 }) {
      FeedItemEitherIndicator({
        bookmarked: this.item.bookmarked && this.bookmarkIndicator,
        feedImageUrl: this.item.feedImageUrl,
        iconSize: 24
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
    .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
    .padding({
      top: 8,
      bottom: 8,
      left: FeederTheme.dimens.margin,
      right: FeederTheme.dimens.margin
    })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FeederTheme.colors.surface)
    .opacity(this.item.unread ? 1.0 : 0.75)
  }
}
