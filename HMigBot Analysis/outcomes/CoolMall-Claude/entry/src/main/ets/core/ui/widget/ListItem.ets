/**
 * AppListItem / StaticAppListItem (source: core/ui/component/list/ListItem.kt).
 *
 * Row: [leading icon (20vp) | leading slot] + title (+ description) + [trailing text | trailing slot (e.g. Toggle)]
 * + right arrow, with an optional bottom WeDivider.
 * Slots: set `hasLeadingContent` / `hasTrailingContent` and pass the builder in the arrow-wrapped form:
 *   AppListItem({ itemTitle: $r('app.string.x'), hasTrailingContent: true,
 *                 trailingContent: (): void => { this.switchBuilder() }, showArrow: false })
 */
import { Dimens } from '../../designsystem/Dimens';
import { WeDivider } from './AppCard';

@Builder
function emptyListSlot() {
}

function isNonEmpty(v: ResourceStr | undefined): boolean {
  if (v === undefined) {
    return false;
  }
  if (typeof v === 'string') {
    return v.length > 0;
  }
  return true;
}

@ComponentV2
export struct AppListItem {
  @Param itemTitle: ResourceStr = '';
  @Param leadingIcon: Resource | undefined = undefined;
  /** Leading icon tint; default colorScheme.onSurface */
  @Param leadingIconTint: ResourceColor = $r('app.color.text_primary');
  @Param hasLeadingContent: boolean = false;
  @BuilderParam leadingContent: () => void = emptyListSlot;
  @Param description: ResourceStr | undefined = undefined;
  @Param trailingText: ResourceStr | undefined = undefined;
  @Param hasTrailingContent: boolean = false;
  @BuilderParam trailingContent: () => void = emptyListSlot;
  @Param showArrow: boolean = true;
  @Param showDivider: boolean = true;
  @Param verticalPadding: number = Dimens.spaceVerticalMedium;
  @Param horizontalPadding: number = Dimens.spaceHorizontalMedium;
  /** Source rows are always clickable; set false for a display-only row so the parent gets the tap (A2-16). */
  @Param clickable: boolean = true;
  @Event onItemClick: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        if (this.hasLeadingContent) {
          Row() {
            this.leadingContent()
          }
          .alignItems(VerticalAlign.Center)
          .margin({ right: Dimens.spaceHorizontalMedium })
        } else if (this.leadingIcon !== undefined) {
          Image(this.leadingIcon)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .fillColor(this.leadingIconTint)
            .margin({ right: Dimens.spaceHorizontalMedium })
        }

        Column() {
          Text(this.itemTitle)
            .fontSize(Dimens.fontBodyLarge)
            .lineHeight(Dimens.lineBodyLarge)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (isNonEmpty(this.description)) {
            Text(this.description as ResourceStr)
              .fontSize(Dimens.fontBodyMedium)
              .lineHeight(Dimens.lineBodyMedium)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        // source: Column(Modifier.weight(1f)) without alignment = start
        .alignItems(HorizontalAlign.Start)

        if (this.hasTrailingContent) {
          Row() {
            this.trailingContent()
          }
          .alignItems(VerticalAlign.Center)
        } else if (isNonEmpty(this.trailingText)) {
          Text(this.trailingText as ResourceStr)
            .fontSize(Dimens.fontBodyMedium)
            .lineHeight(Dimens.lineBodyMedium)
            .fontColor($r('app.color.text_secondary'))
            .margin({ right: Dimens.spaceHorizontalXSmall })
        }

        if (this.showArrow) {
          Image($r('app.media.ic_right'))
            .width(16)
            .height(16)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.right_arrow_gray'))
        }
      }
      .width('100%')
      .padding({
        top: this.verticalPadding,
        bottom: this.verticalPadding,
        left: this.horizontalPadding,
        right: this.horizontalPadding
      })
      // source: verticalAlignment = CenterVertically; horizontal = start (weight(1) column fills the middle)
      .alignItems(VerticalAlign.Center)
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
        if (this.clickable) {
          this.onItemClick();
        }
      })
      .hitTestBehavior(this.clickable ? HitTestMode.Default : HitTestMode.None)

      if (this.showDivider) {
        WeDivider()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** StaticAppListItem: same layout without click / arrow / trailing; title & description not line-limited. */
@ComponentV2
export struct StaticAppListItem {
  @Param itemTitle: ResourceStr = '';
  @Param leadingIcon: Resource | undefined = undefined;
  @Param leadingIconTint: ResourceColor = $r('app.color.text_primary');
  @Param hasLeadingContent: boolean = false;
  @BuilderParam leadingContent: () => void = emptyListSlot;
  @Param description: ResourceStr | undefined = undefined;
  @Param showDivider: boolean = false;
  @Param verticalPadding: number = Dimens.spaceVerticalMedium;
  @Param horizontalPadding: number = Dimens.spaceHorizontalMedium;

  build() {
    Column() {
      Row() {
        if (this.hasLeadingContent) {
          Row() {
            this.leadingContent()
          }
          .alignItems(VerticalAlign.Center)
          .margin({ right: Dimens.spaceHorizontalMedium })
        } else if (this.leadingIcon !== undefined) {
          Image(this.leadingIcon)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .fillColor(this.leadingIconTint)
            .margin({ right: Dimens.spaceHorizontalMedium })
        }
        Column() {
          Text(this.itemTitle)
            .fontSize(Dimens.fontBodyLarge)
            .lineHeight(Dimens.lineBodyLarge)
            .fontColor($r('app.color.text_primary'))
          if (isNonEmpty(this.description)) {
            Text(this.description as ResourceStr)
              .fontSize(Dimens.fontBodyMedium)
              .lineHeight(Dimens.lineBodyMedium)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        top: this.verticalPadding,
        bottom: this.verticalPadding,
        left: this.horizontalPadding,
        right: this.horizontalPadding
      })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)

      if (this.showDivider) {
        WeDivider()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
