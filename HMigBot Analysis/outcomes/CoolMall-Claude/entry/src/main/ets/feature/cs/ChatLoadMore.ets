/**
 * ChatLoadMore (source: feature/cs/component/ChatLoadMore.kt) — CS-A07.
 * Row(fillMaxWidth, vertical padding 16, centered):
 *  PullToLoad: divider · `加载更多历史消息` (secondary) · divider
 *  Loading:    WeLoading + 8 + `正在加载历史消息...`
 *  Success:    divider · `加载成功` · divider
 *  Error:      divider · `加载失败，点击重试` (danger, clickable → onRetry) · divider
 *  NoMore:     divider · `没有更多消息了` (secondary) · divider
 */
import { LoadMoreState } from '../../core/common/LoadMoreState';
import { Dimens } from '../../core/designsystem/Dimens';
import { WeLoading } from '../../core/ui/base/StateViews';
import { WeDivider } from '../../core/ui/widget/AppCard';

@ComponentV2
export struct ChatLoadMore {
  @Param loadState: LoadMoreState = LoadMoreState.PullToLoad;
  @Event onRetry: () => void = () => {
  };

  @Builder
  dividerSlot() {
    // WeDivider(modifier = Modifier.weight(1f))
    Row() {
      WeDivider()
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  label(text: ResourceStr, color: ResourceColor) {
    Text(text)
      .fontSize(Dimens.fontBodyLarge)
      .lineHeight(Dimens.lineBodyLarge)
      .fontColor(color)
      .margin({ left: 8, right: 8 })
  }

  build() {
    Row() {
      if (this.loadState === LoadMoreState.Loading) {
        WeLoading()
        Text($r('app.string.loading_history'))
          .fontSize(Dimens.fontBodyLarge)
          .lineHeight(Dimens.lineBodyLarge)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
      } else if (this.loadState === LoadMoreState.Error) {
        this.dividerSlot()
        Text($r('app.string.load_failed_retry'))
          .fontSize(Dimens.fontBodyLarge)
          .lineHeight(Dimens.lineBodyLarge)
          .fontColor($r('app.color.danger'))
          .padding({ top: 4, bottom: 4 })
          .borderRadius(Dimens.radiusSmall)
          .margin({ left: 8, right: 8 })
          .onClick(() => {
            this.onRetry();
          })
        this.dividerSlot()
      } else if (this.loadState === LoadMoreState.Success) {
        this.dividerSlot()
        this.label($r('app.string.load_success'), $r('app.color.text_primary'))
        this.dividerSlot()
      } else if (this.loadState === LoadMoreState.NoMore) {
        this.dividerSlot()
        this.label($r('app.string.no_more_messages'), $r('app.color.text_secondary'))
        this.dividerSlot()
      } else {
        this.dividerSlot()
        this.label($r('app.string.load_more_history'), $r('app.color.text_secondary'))
        this.dividerSlot()
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .justifyContent(FlexAlign.Center) // source horizontalArrangement = Center
    .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
  }
}
