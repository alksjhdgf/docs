/**
 * Tag / TagClosable (source: core/ui/component/tag/Tag.kt).
 *
 * Colors per getTagColors():
 *   FILLED   DEFAULT → onSurfaceVariant on surfaceVariant; others → white on the type color
 *   LIGHT    DEFAULT → same as FILLED; others → type color on the *Light tint (source uses the Light
 *            constants in both themes, kept as fixed values)
 *   OUTLINED transparent background + 1vp border in the text color
 * Padding: SMALL 4 / MEDIUM 8 / LARGE 12 vertical, ×1.5 horizontal. Text = labelSmall (11/16 Medium).
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';
import { WidgetColors } from './WidgetColors';

export enum TagType {
  DEFAULT,
  PRIMARY,
  WARNING,
  DANGER,
  SUCCESS
}

export enum TagStyle {
  /** Filled background */
  FILLED,
  /** Light tinted background */
  LIGHT,
  /** Border only */
  OUTLINED
}

export enum TagSize {
  SMALL,
  MEDIUM,
  LARGE
}

export class TagColorPair {
  textColor: ResourceColor;
  bgColor: ResourceColor;

  constructor(textColor: ResourceColor, bgColor: ResourceColor) {
    this.textColor = textColor;
    this.bgColor = bgColor;
  }
}

export class TagDefaults {
  /** Strong color of a tag type (text on LIGHT/OUTLINED, background on FILLED). */
  static typeColor(type: TagType): ResourceColor {
    switch (type) {
      case TagType.PRIMARY:
        return ThemeManager.instance.primary;
      case TagType.WARNING:
        return $r('app.color.warning');
      case TagType.DANGER:
        return $r('app.color.danger');
      case TagType.SUCCESS:
        return $r('app.color.success');
      default:
        // colorScheme.onSurfaceVariant (not customised in Theme.kt) → nearest neutral token
        return $r('app.color.text_secondary');
    }
  }

  static lightBg(type: TagType): ResourceColor {
    switch (type) {
      case TagType.PRIMARY:
        return WidgetColors.BG_PURPLE_LIGHT;
      case TagType.WARNING:
        return WidgetColors.BG_YELLOW_LIGHT;
      case TagType.DANGER:
        return WidgetColors.BG_RED_LIGHT;
      case TagType.SUCCESS:
        return WidgetColors.BG_GREEN_LIGHT;
      default:
        return $r('app.color.bg_content');
    }
  }

  static colors(type: TagType, style: TagStyle): TagColorPair {
    if (style === TagStyle.OUTLINED) {
      return new TagColorPair(TagDefaults.typeColor(type), Color.Transparent);
    }
    if (type === TagType.DEFAULT) {
      // DEFAULT: onSurfaceVariant on surfaceVariant for FILLED and LIGHT
      return new TagColorPair(TagDefaults.typeColor(type), $r('app.color.bg_content'));
    }
    if (style === TagStyle.LIGHT) {
      return new TagColorPair(TagDefaults.typeColor(type), TagDefaults.lightBg(type));
    }
    return new TagColorPair($r('app.color.text_white'), TagDefaults.typeColor(type));
  }

  /** Vertical padding; horizontal = ×1.5 */
  static padding(size: TagSize): number {
    switch (size) {
      case TagSize.SMALL:
        return Dimens.spacePaddingXSmall;
      case TagSize.LARGE:
        return Dimens.spacePaddingSmall * 1.5;
      default:
        return Dimens.spacePaddingSmall;
    }
  }

  static closeIconSize(size: TagSize): number {
    switch (size) {
      case TagSize.SMALL:
        return 12;
      case TagSize.LARGE:
        return 18;
      default:
        return 16;
    }
  }
}

@ComponentV2
export struct Tag {
  @Param tagText: ResourceStr = '';
  @Param tagType: TagType = TagType.DEFAULT;
  @Param tagStyle: TagStyle = TagStyle.FILLED;
  @Param tagSize: TagSize = TagSize.MEDIUM;
  /** Corner radius; default ShapeSmall (8) */
  @Param tagRadius: number = Dimens.radiusSmall;
  @Param tagFontSize: number = Dimens.fontBodySmall;
  @Param tagFontWeight: FontWeight = FontWeight.Medium;

  build() {
    Row() {
      Text(this.tagText)
        .fontSize(this.tagFontSize)
        .lineHeight(Dimens.lineBodySmall)
        .fontWeight(this.tagFontWeight)
        .fontColor(TagDefaults.colors(this.tagType, this.tagStyle).textColor)
    }
    // source: Box(contentAlignment = Center)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({
      top: TagDefaults.padding(this.tagSize),
      bottom: TagDefaults.padding(this.tagSize),
      left: TagDefaults.padding(this.tagSize) * 1.5,
      right: TagDefaults.padding(this.tagSize) * 1.5
    })
    .backgroundColor(TagDefaults.colors(this.tagType, this.tagStyle).bgColor)
    .border({
      width: this.tagStyle === TagStyle.OUTLINED ? 1 : 0,
      color: TagDefaults.colors(this.tagType, this.tagStyle).textColor
    })
    .borderRadius(this.tagRadius)
    .clip(true)
  }
}

/** Tag with a trailing close icon (only the icon is clickable). */
@ComponentV2
export struct TagClosable {
  @Param tagText: ResourceStr = '';
  @Param tagType: TagType = TagType.DEFAULT;
  @Param tagStyle: TagStyle = TagStyle.FILLED;
  @Param tagSize: TagSize = TagSize.MEDIUM;
  @Param tagRadius: number = Dimens.radiusSmall;
  @Param closeIcon: Resource = $r('app.media.ic_close');
  @Event onClose: () => void = () => {
  };

  build() {
    Row() {
      Text(this.tagText)
        .fontSize(Dimens.fontBodySmall)
        .lineHeight(Dimens.lineBodySmall)
        .fontWeight(FontWeight.Medium)
        .fontColor(TagDefaults.colors(this.tagType, this.tagStyle).textColor)
        .margin({ right: 4 })
      Image(this.closeIcon)
        .width(TagDefaults.closeIconSize(this.tagSize))
        .height(TagDefaults.closeIconSize(this.tagSize))
        .objectFit(ImageFit.Contain)
        .fillColor(TagDefaults.colors(this.tagType, this.tagStyle).textColor)
        .accessibilityText($r('app.string.modal_close'))
        .onClick(() => {
          this.onClose();
        })
    }
    // source: Row(verticalAlignment = CenterVertically), start
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .padding({
      top: TagDefaults.padding(this.tagSize),
      bottom: TagDefaults.padding(this.tagSize),
      left: TagDefaults.padding(this.tagSize) * 1.5,
      right: TagDefaults.padding(this.tagSize)
    })
    .backgroundColor(TagDefaults.colors(this.tagType, this.tagStyle).bgColor)
    .border({
      width: this.tagStyle === TagStyle.OUTLINED ? 1 : 0,
      color: TagDefaults.colors(this.tagType, this.tagStyle).textColor
    })
    .borderRadius(this.tagRadius)
    .clip(true)
  }
}
