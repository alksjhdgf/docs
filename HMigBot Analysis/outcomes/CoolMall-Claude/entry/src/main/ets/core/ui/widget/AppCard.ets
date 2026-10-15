/**
 * AppCard + TitleWithLine + WeDivider
 * (source: core/ui/component/card/AppCard.kt, core/ui/component/title/TitleWithLine.kt,
 * core/ui/component/divider/Divider.kt).
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';

@Builder
function emptyCardSlot() {
}

/** Horizontal 0.5vp divider in colorScheme.outline (WeDivider). Fills the parent width. */
@ComponentV2
export struct WeDivider {
  @Param dividerColor: ResourceColor = $r('app.color.divider');

  build() {
    Divider()
      .width('100%')
      .strokeWidth(Dimens.spaceDivider)
      .color(this.dividerColor)
  }
}

/** Title with a 4x20 vertical primary-colored bar on the left (TitleWithLine). */
@ComponentV2
export struct TitleWithLine {
  @Param titleText: ResourceStr = '';
  /** Text color; default onSurface (text_primary) */
  @Param textColor: ResourceColor = $r('app.color.text_primary');
  /** Bar color; undefined = live theme primary (colorScheme.primary) */
  @Param lineColor: ResourceColor | undefined = undefined;

  build() {
    Row() {
      Row()
        .width(4)
        .height(20)
        .borderRadius(2)
        .backgroundColor(this.lineColor !== undefined ? this.lineColor : ThemeManager.instance.primary)
        .margin({ right: Dimens.spaceHorizontalSmall })
      // AppText default size BODY_LARGE (14/22) with TitleLarge.fontWeight (Bold)
      Text(this.titleText)
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
    }
    // source: Row(verticalAlignment = CenterVertically), horizontal = start
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}

/**
 * Generic card (M3 Card: surfaceContainerHighest = bg_card, shape medium 12vp) with an inner
 * Column(fillMaxWidth, padding 12). `lineTitle` wins over `cardTitle`. Content goes in the trailing closure.
 * The card fills the width of its slot; give outer spacing through the parent's padding.
 */
@ComponentV2
export struct AppCard {
  /** Plain title (TitleLarge), shown when lineTitle is undefined */
  @Param cardTitle: ResourceStr | undefined = undefined;
  /** Title with decorative line */
  @Param lineTitle: ResourceStr | undefined = undefined;
  @BuilderParam cardContent: () => void = emptyCardSlot;

  build() {
    Column() {
      if (this.lineTitle !== undefined) {
        TitleWithLine({ titleText: this.lineTitle as ResourceStr })
      } else if (this.cardTitle !== undefined) {
        Text(this.cardTitle as ResourceStr)
          .fontSize(Dimens.fontTitleLarge)
          .lineHeight(Dimens.lineTitleLarge)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      this.cardContent()
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    // source: Column without horizontalAlignment = start
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}
