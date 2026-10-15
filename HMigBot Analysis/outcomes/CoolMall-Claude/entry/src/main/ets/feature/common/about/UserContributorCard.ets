/**
 * UserContributorCard (source: feature/common/component/UserContributorCard.kt).
 *
 * Card(fillMaxWidth, ShapeMedium, clickable → onCardClick(contributor)) {
 *   Row(padding 12, verticalAlignment = Top) {
 *     SmallAvatar(36) · 12 · Column(weight 1) {
 *       nickName (bodyLarge, primary text) · 4
 *       signature (bodyMedium, secondary) · 8      — only when non-empty
 *       FlowRow(spacedBy 8 / 4) of Tag(PRIMARY, FILLED, SMALL)  — only when non-empty
 *     }
 *   }
 * }
 */
import { LengthMetrics } from '@kit.ArkUI';
import { Dimens } from '../../../core/designsystem/Dimens';
import { UserContributor } from '../../../core/model/Market';
import { SmallAvatar } from '../../../core/ui/widget/Images';
import { Tag, TagSize, TagStyle, TagType } from '../../../core/ui/widget/Tags';

@ComponentV2
export struct UserContributorCard {
  @Param contributor: UserContributor = new UserContributor();
  @Event onCardClick: (contributor: UserContributor) => void = (contributor: UserContributor) => {
  };

  private signatureText(): string {
    const s: string | null | undefined = this.contributor.signature;
    return (s === null || s === undefined) ? '' : s;
  }

  private tagList(): string[] {
    const t: string[] | null | undefined = this.contributor.tags;
    return (t === null || t === undefined) ? [] : t;
  }

  build() {
    Row() {
      SmallAvatar({ avatarUrl: this.contributor.avatarUrl ?? '' })

      Column() {
        Text(this.contributor.nickName ?? '')
          .fontSize(Dimens.fontBodyLarge)
          .lineHeight(Dimens.lineBodyLarge)
          .fontColor($r('app.color.text_primary'))

        // SpaceVerticalXSmall
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalXSmall)

        if (this.signatureText().length > 0) {
          Text(this.signatureText())
            .width('100%')
            .fontSize(Dimens.fontBodyMedium)
            .lineHeight(Dimens.lineBodyMedium)
            .fontColor($r('app.color.text_secondary'))
          // SpaceVerticalSmall
          Row()
            .width('100%')
            .height(Dimens.spaceVerticalSmall)
        }

        if (this.tagList().length > 0) {
          Flex({
            wrap: FlexWrap.Wrap,
            justifyContent: FlexAlign.Start,
            alignItems: ItemAlign.Start,
            space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(4) }
          }) {
            ForEach(this.tagList(), (tag: string, index: number) => {
              Tag({
                tagText: tag,
                tagType: TagType.PRIMARY,
                tagStyle: TagStyle.FILLED,
                tagSize: TagSize.SMALL
              })
            }, (tag: string, index: number) => index + '_' + tag)
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      // source Column(Modifier.weight(1f)) = start aligned
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    // source Row(verticalAlignment = Alignment.Top)
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .stateStyles({
      normal: {
        .backgroundColor($r('app.color.bg_card'))
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      this.onCardClick(this.contributor);
    })
  }
}
