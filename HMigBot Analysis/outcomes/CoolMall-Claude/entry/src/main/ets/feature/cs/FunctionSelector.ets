/**
 * FunctionSelector (source: feature/cs/component/FunctionSelector.kt) — CS-A19.
 * Surface { 1vp top border ; Row(padding 12, Start) { FunctionItem(相册, "gallery"), 12, FunctionItem(拍摄, "camera") } }
 * FunctionItem: Column(ShapeSmall, clickable, padding 8, centered) { 56vp circle (surfaceVariant) + 28vp icon, 8, label }
 */
import { Dimens } from '../../core/designsystem/Dimens';

@ComponentV2
export struct FunctionSelector {
  @Event onFunctionSelected: (fn: string) => void = (fn: string) => {
  };

  @Builder
  functionItem(icon: Resource, label: Resource, key: string) {
    Column() {
      Stack({ alignContent: Alignment.Center }) { // source contentAlignment = Center
        Image(icon)
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .accessibilityText(label)
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.bg_content')) // colorScheme.surfaceVariant

      Text(label)
        .fontSize(Dimens.fontBodySmall)
        .lineHeight(Dimens.lineBodySmall)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: Dimens.spaceVerticalSmall })
    }
    .padding(Dimens.spacePaddingSmall)
    .borderRadius(Dimens.radiusSmall)
    .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
    .onClick(() => {
      this.onFunctionSelected(key);
    })
  }

  build() {
    Column() {
      Divider()
        .width('100%')
        .strokeWidth(1)
        .color($r('app.color.divider'))

      Row() {
        this.functionItem($r('app.media.ic_image_fill'), $r('app.string.gallery'), 'gallery')
        Row()
          .width(Dimens.spaceHorizontalMedium)
          .height(1)
        this.functionItem($r('app.media.ic_camera_fill'), $r('app.string.camera'), 'camera')
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .justifyContent(FlexAlign.Start) // source Arrangement.Start
      .alignItems(VerticalAlign.Center) // source CenterVertically
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
    .alignItems(HorizontalAlign.Start)
  }
}
