/**
 * ChatMessageItem (source: ChatScreen.kt Message / AuthorAndTextMessage / AuthorNameTimestamp /
 * ChatItemBubble / DayHeader) — CS-A08 / A09 / A10 / A21.
 *
 * Column {
 *   DayHeader (only when showTimeHeader and the formatted time is not empty)
 *   Row(fillMaxWidth, padding h12, top 8, Start | End) {
 *     agent: Avatar(adminUserHeadImg ?: avatarUrl, 36) + 8
 *     Column(weight(1, fill = false), Start | End) { name (bodyMedium), bubble, 8 }
 *     user:  8 + Avatar(avatarUrl, 36)
 *   }
 * }
 * Bubble: user = primary / onPrimary (white), shape 18/4/18/18; agent = surfaceContainerHigh (surface) /
 * onSurface, shape 4/18/18/18. content.type "image" (any case) → 200x200 cropped NetWorkImage (padding 4,
 * corner 12); otherwise text content.data (bodyLarge, padding h16 v12).
 */
import { Dimens } from '../../core/designsystem/Dimens';
import { ThemeManager } from '../../core/designsystem/ThemeManager';
import { CsMsg } from '../../core/model/Cs';
import { Avatar, NetWorkImage } from '../../core/ui/widget/Images';
import { TimeUtils } from '../../core/util/TimeUtils';

const AVATAR_SIZE: number = 36;
const IMAGE_SIZE: number = 200;
const USER_BUBBLE_RADIUS: BorderRadiuses = { topLeft: 18, topRight: 4, bottomLeft: 18, bottomRight: 18 };
const OTHER_BUBBLE_RADIUS: BorderRadiuses = { topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18 };

@ComponentV2
export struct ChatMessageItem {
  @Param msg: CsMsg = new CsMsg();
  /** type == 0 (user feedback) */
  @Param isUserMe: boolean = false;
  /** TimeUtils.shouldShowTimeHeaderInList result */
  @Param showTimeHeader: boolean = false;

  private agentAvatar(): string {
    return this.msg.adminUserHeadImg.length === 0 ? this.msg.avatarUrl : this.msg.adminUserHeadImg;
  }

  private displayName(): string {
    if (this.isUserMe) {
      return this.msg.nickName;
    }
    return this.msg.adminUserName.length === 0 ? this.msg.nickName : this.msg.adminUserName;
  }

  private isImage(): boolean {
    return this.msg.content.type.toLowerCase() === 'image';
  }

  @Builder
  dayHeader(dayString: string) {
    Row() {
      Text(dayString)
        .fontSize(Dimens.fontBodySmall)
        .lineHeight(Dimens.lineBodySmall)
        .fontColor($r('app.color.text_tertiary'))
        .padding({ left: Dimens.spacePaddingSmall, right: Dimens.spacePaddingSmall, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.surface')) // colorScheme.surfaceContainerHigh
        .borderRadius(8)
        .margin({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
    }
    .width('100%')
    .padding({ top: Dimens.spacePaddingSmall, bottom: Dimens.spacePaddingSmall })
    .justifyContent(FlexAlign.Center) // source Box(contentAlignment = Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  bubble() {
    Column() {
      if (this.isImage()) {
        Column() {
          NetWorkImage({
            model: this.msg.content.data,
            imageSize: IMAGE_SIZE,
            contentScale: ImageFit.Cover, // ContentScale.Crop
            cornerRadius: 12
          })
        }
        .padding(4)
        .alignItems(HorizontalAlign.Start)
      } else {
        Text(this.msg.content.data)
          .fontSize(Dimens.fontBodyLarge)
          .lineHeight(Dimens.lineBodyLarge)
          .fontColor(this.isUserMe ? $r('app.color.text_white') : $r('app.color.text_primary'))
          .padding({
            left: Dimens.spacePaddingLarge,
            right: Dimens.spacePaddingLarge,
            top: Dimens.spacePaddingMedium,
            bottom: Dimens.spacePaddingMedium
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.isUserMe ? ThemeManager.instance.primary : $r('app.color.surface'))
    .borderRadius(this.isUserMe ? USER_BUBBLE_RADIUS : OTHER_BUBBLE_RADIUS)
    .clip(true)
  }

  build() {
    Column() {
      if (this.showTimeHeader && TimeUtils.formatChatTime(this.msg.createTime).length > 0) {
        this.dayHeader(TimeUtils.formatChatTime(this.msg.createTime))
      }
      Row() {
        if (!this.isUserMe) {
          Avatar({ avatarUrl: this.agentAvatar(), avatarSize: AVATAR_SIZE })
        }
        // AuthorAndTextMessage: weight(1f, fill = false) → takes the remaining width, content aligned to its side
        Column() {
          Text(this.displayName())
            .fontSize(Dimens.fontBodyMedium)
            .lineHeight(Dimens.lineBodyMedium)
            .fontColor($r('app.color.text_primary'))
            .padding({ bottom: Dimens.spacePaddingXSmall })
          this.bubble()
        }
        .layoutWeight(1)
        .padding({ bottom: Dimens.spaceVerticalSmall })
        .margin({
          left: this.isUserMe ? 0 : Dimens.spaceHorizontalSmall,
          right: this.isUserMe ? Dimens.spaceHorizontalSmall : 0
        })
        .alignItems(this.isUserMe ? HorizontalAlign.End : HorizontalAlign.Start)

        if (this.isUserMe) {
          Avatar({ avatarUrl: this.msg.avatarUrl, avatarSize: AVATAR_SIZE })
        }
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium, top: Dimens.spaceVerticalSmall })
      .justifyContent(this.isUserMe ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Top) // avatars align(Alignment.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
