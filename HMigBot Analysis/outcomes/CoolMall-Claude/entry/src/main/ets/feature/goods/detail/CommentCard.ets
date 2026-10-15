/**
 * CommentCard (source: feature/goods/component/CommentCard.kt) — GOODS-A21.
 *
 * Card(fillMaxWidth) { Row(padding 12, Top) {
 *   Avatar 40 | 12 | Column(weight 1) {
 *     SpaceBetweenRow { nickname (`匿名用户` when null/empty, bodyLarge primary) | createTime (bodySmall tertiary) }
 *     4 | WeRate(starCount, 5, 16, no animation) | 12
 *     content (when non-empty) + 12
 *     9-grid images (max 9, 3 per row, spacing 8, square, radius 8, surfaceVariant bg)
 *   } } }
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { Comment } from '../../../core/model/Goods';
import { Avatar, NetWorkImage } from '../../../core/ui/widget/Images';
import { WeRate } from '../../../core/ui/widget/Rate';
import { AppTextSize, AppTextStyles, AppTextType } from '../../../core/ui/widget/Texts';

const GRID_COLUMNS: number = 3;
const GRID_MAX_IMAGES: number = 9;
const GRID_SPACING: number = 8;

/** One grid row: image urls with their absolute index; '' = blank filler cell */
class ImageRow {
  key: string = '';
  cells: string[] = [];
}

/** Nickname or `匿名用户` */
export function commentNickName(comment: Comment): ResourceStr {
  const name: string | null | undefined = comment.nickName;
  if (name === null || name === undefined || name.length === 0) {
    return $r('app.string.anonymous_user');
  }
  return name;
}

@ComponentV2
export struct CommentCard {
  @Param comment: Comment = new Comment();

  private hasContent(): boolean {
    const c: string | null | undefined = this.comment.content;
    return c !== null && c !== undefined && c.length > 0;
  }

  private imageRows(): ImageRow[] {
    const pics: string[] | null | undefined = this.comment.pics;
    const rows: ImageRow[] = [];
    if (pics === null || pics === undefined) {
      return rows;
    }
    const display: string[] = pics.slice(0, GRID_MAX_IMAGES);
    for (let i = 0; i < display.length; i += GRID_COLUMNS) {
      const row: ImageRow = new ImageRow();
      for (let j = 0; j < GRID_COLUMNS; j++) {
        row.cells.push(i + j < display.length ? display[i + j] : '');
      }
      row.key = 'row_' + i + '_' + row.cells.join('|');
      rows.push(row);
    }
    return rows;
  }

  @Builder
  imageCell(url: string) {
    if (url.length === 0) {
      // repeat(3 - rowImages.size) { Spacer(weight 1) }
      Column()
        .layoutWeight(1)
    } else {
      Column() {
        NetWorkImage({ model: url, contentScale: ImageFit.Cover })
      }
      .layoutWeight(1)
      .aspectRatio(1)
      .alignItems(HorizontalAlign.Start)
      .borderRadius(Dimens.radiusSmall)
      .backgroundColor($r('app.color.bg_content'))
      .clip(true)
    }
  }

  @Builder
  imageGrid() {
    Column({ space: GRID_SPACING }) {
      ForEach(this.imageRows(), (row: ImageRow) => {
        Row({ space: GRID_SPACING }) {
          ForEach(row.cells, (url: string) => {
            this.imageCell(url)
          }, (url: string, idx: number) => row.key + '_' + idx)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top) // source Row: default top
        .justifyContent(FlexAlign.Start)
      }, (row: ImageRow) => row.key)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Row() {
      Avatar({ avatarUrl: this.comment.avatarUrl, avatarSize: 40 })
      Column() {
        // SpaceBetweenRow: nickname | time
        Row() {
          Text(commentNickName(this.comment))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
            .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
          if (this.comment.createTime !== null && this.comment.createTime !== undefined) {
            Text(this.comment.createTime as string)
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
              .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center) // SpaceBetweenRow: CenterVertically

        Row() {
          WeRate({ value: this.comment.starCount, count: 5, starSize: 16, animationEnabled: false })
        }
        .margin({ top: Dimens.spaceVerticalXSmall, bottom: Dimens.spaceVerticalMedium })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)

        if (this.hasContent()) {
          Text(this.comment.content)
            .width('100%')
            .margin({ bottom: Dimens.spaceVerticalMedium })
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
            .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
        }

        if (this.comment.pics !== null && this.comment.pics !== undefined && this.comment.pics.length > 0) {
          this.imageGrid()
        }
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      .alignItems(HorizontalAlign.Start) // source Column: default start
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(VerticalAlign.Top) // source verticalAlignment = Top
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}
