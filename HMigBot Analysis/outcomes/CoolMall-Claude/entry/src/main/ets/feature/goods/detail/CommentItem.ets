/**
 * CommentItem (source: feature/goods/component/CommentItem.kt) — compact comment row of the detail page's
 * `商品评价` card (GOODS-A14).
 *
 * Row(fillMaxWidth, clickable when onClick, padding 12, Top) {
 *   Avatar 32 | 12 | Column(weight 1) { nickname (`匿名用户`) bodyMedium | 4 | WeRate(14) | 4 | content bodyMedium }
 *   [pics] 12 | 60x60 first image (radius 8, surfaceVariant) + `+N` badge (N = count - 1) bottom-end
 * }
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { Comment } from '../../../core/model/Goods';
import { Avatar, NetWorkImage } from '../../../core/ui/widget/Images';
import { WeRate } from '../../../core/ui/widget/Rate';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';
import { commentNickName } from './CommentCard';

const PREVIEW_SIZE: number = 60;

@ComponentV2
export struct CommentItem {
  @Param comment: Comment = new Comment();
  /** Source onClick != null */
  @Param itemClickable: boolean = false;
  @Event onItemClick: () => void = () => {
  };

  private hasContent(): boolean {
    const c: string | null | undefined = this.comment.content;
    return c !== null && c !== undefined && c.length > 0;
  }

  private pics(): string[] {
    const p: string[] | null | undefined = this.comment.pics;
    return (p === null || p === undefined) ? [] : p;
  }

  @Builder
  imagePreview() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      NetWorkImage({ model: this.pics()[0], contentScale: ImageFit.Cover })
      if (this.pics().length > 1) {
        Row() {
          Text('+' + (this.pics().length - 1))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
            .fontColor(Color.White)
        }
        .margin(4)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor('#66000000') // Color.Black.copy(alpha = 0.4f)
        .borderRadius(Dimens.radiusSmall)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width(PREVIEW_SIZE)
    .height(PREVIEW_SIZE)
    .margin({ left: Dimens.spaceHorizontalMedium })
    .borderRadius(Dimens.radiusSmall)
    .backgroundColor($r('app.color.bg_content'))
    .clip(true)
  }

  @Builder
  rowContent() {
    Avatar({ avatarUrl: this.comment.avatarUrl, avatarSize: 32 })
    Column() {
      Text(commentNickName(this.comment))
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
      Row() {
        WeRate({ value: this.comment.starCount, count: 5, starSize: 14, animationEnabled: false })
      }
      .margin({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalXSmall })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)
      if (this.hasContent()) {
        Text(this.comment.content)
          .width('100%')
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
      }
    }
    .layoutWeight(1)
    .margin({ left: Dimens.spaceHorizontalMedium })
    .alignItems(HorizontalAlign.Start)

    if (this.pics().length > 0) {
      this.imagePreview()
    }
  }

  build() {
    if (this.itemClickable) {
      Row() {
        this.rowContent()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(VerticalAlign.Top) // source verticalAlignment = Top
      .justifyContent(FlexAlign.Start)
      .stateStyles({
        normal: {
          .backgroundColor(Color.Transparent)
        },
        pressed: {
          .backgroundColor($r('app.color.press'))
        }
      })
      .onClick(() => {
        this.onItemClick();
      })
    } else {
      Row() {
        this.rowContent()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
    }
  }
}
