/**
 * FeedbackCard (source: feature/feedback/component/FeedbackCard.kt) — USER-A37.
 *
 * Card { Column(padding 12) {
 *   SpaceBetweenRow { Row(spacedBy 8, centerV){ Tag(type name, PRIMARY, SMALL), Tag(`已处理` SUCCESS |
 *     `未处理` WARNING, SMALL) }, createTime (secondary, bodySmall) }
 *   12 · content (fill width)
 *   [images] 12 · 3-column grid (≤ 9, rows spacedBy 8, square cells, 12 corners, blank-filled last row)
 *   [remark] 12 · Box(surfaceVariant, small corners, padding 12){ `客服回复` (secondary, bodySmall) · 8 · remark }
 * } }
 */
import { Dimens } from '../../core/designsystem/Dimens';
import { Feedback } from '../../core/model/Market';
import { NetWorkImage } from '../../core/ui/widget/Images';
import { Tag, TagSize, TagType } from '../../core/ui/widget/Tags';
import { AppTextSize, AppTextStyles, AppTextType } from '../../core/ui/widget/Texts';

/** Grid gap (source spacing = 8.dp) */
const IMAGE_SPACING: number = 8;
/** Grid columns */
const IMAGE_COLUMNS: number = 3;

/** One row of the image grid: images + number of blank fillers */
class FeedbackImageRow {
  key: string;
  images: string[];
  fillers: number[];

  constructor(key: string, images: string[], fillers: number[]) {
    this.key = key;
    this.images = images;
    this.fillers = fillers;
  }
}

/** images.take(maxImages).chunked(3) with blank fillers */
function buildImageRows(images: string[] | null | undefined, maxImages: number): FeedbackImageRow[] {
  const rows: FeedbackImageRow[] = [];
  if (images === null || images === undefined) {
    return rows;
  }
  const display: string[] = images.slice(0, maxImages);
  for (let i = 0; i < display.length; i += IMAGE_COLUMNS) {
    const chunk: string[] = display.slice(i, i + IMAGE_COLUMNS);
    const fillers: number[] = [];
    for (let f = chunk.length; f < IMAGE_COLUMNS; f++) {
      fillers.push(f);
    }
    rows.push(new FeedbackImageRow('row_' + i + '_' + chunk.join('|'), chunk, fillers));
  }
  return rows;
}

@ComponentV2
export struct FeedbackCard {
  @Param feedback: Feedback = new Feedback();
  /** Type name shown in the primary tag */
  @Param typeName: ResourceStr = '';

  private isProcessed(): boolean {
    return this.feedback.status === 1;
  }

  private hasImages(): boolean {
    const imgs: string[] | null | undefined = this.feedback.images;
    return imgs !== null && imgs !== undefined && imgs.length > 0;
  }

  private hasRemark(): boolean {
    const r: string | null | undefined = this.feedback.remark;
    return r !== null && r !== undefined && r.length > 0;
  }

  @Builder
  imageGrid() {
    Column({ space: IMAGE_SPACING }) {
      ForEach(buildImageRows(this.feedback.images, 9), (row: FeedbackImageRow) => {
        Row({ space: IMAGE_SPACING }) {
          ForEach(row.images, (url: string, idx: number) => {
            Column() {
              NetWorkImage({
                model: url,
                showBackground: true,
                cornerRadius: Dimens.radiusMedium,
                contentScale: ImageFit.Cover
              })
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .alignItems(HorizontalAlign.Start)
          }, (url: string, idx: number) => row.key + '_' + idx + '_' + url)
          ForEach(row.fillers, (f: number) => {
            Column()
              .layoutWeight(1)
          }, (f: number) => row.key + '_filler_' + f)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: FeedbackImageRow) => row.key)
    }
    .width('100%')
    .margin({ top: Dimens.spaceVerticalMedium })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  replyBox() {
    Column() {
      Text($r('app.string.customer_service_reply'))
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
        .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      Text(this.feedback.remark ?? '')
        .width('100%')
        .margin({ top: Dimens.spaceVerticalSmall })
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
    }
    .width('100%')
    .margin({ top: Dimens.spaceVerticalMedium })
    .padding(Dimens.spacePaddingMedium)
    .backgroundColor($r('app.color.bg_content'))
    .borderRadius(Dimens.radiusSmall)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // top: type tag + status tag + create time
      Row() {
        Row({ space: Dimens.spaceHorizontalSmall }) {
          Tag({ tagText: this.typeName, tagType: TagType.PRIMARY, tagSize: TagSize.SMALL })
          Tag({
            tagText: this.isProcessed() ? $r('app.string.status_processed') : $r('app.string.status_unprocessed'),
            tagType: this.isProcessed() ? TagType.SUCCESS : TagType.WARNING,
            tagSize: TagSize.SMALL
          })
        }
        .alignItems(VerticalAlign.Center)

        Text(this.feedback.createTime ?? '')
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_SMALL))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_SMALL))
          .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // content
      Text(this.feedback.content ?? '')
        .width('100%')
        .margin({ top: Dimens.spaceVerticalMedium })
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.PRIMARY))

      if (this.hasImages()) {
        this.imageGrid()
      }

      if (this.hasRemark()) {
        this.replyBox()
      }
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}
