/**
 * AddressOutlinedField — M3 OutlinedTextField equivalent used by the address form
 * (source: AddressDetailScreen.kt OutlinedTextField(label, placeholder, shape = ShapeMedium)).
 *
 * - Outlined box, 12vp corners; outline 1vp `border`, focused 2vp primary.
 * - Label: inside the box (bodyLarge, secondary) while empty and unfocused; otherwise floated onto the top
 *   border (bodySmall, primary when focused). The placeholder is shown only while focused and empty.
 * - singleLine (TextInput) or multi-line (TextArea, minLines 3 / maxLines 5).
 * - readOnly: plain value text + ArrowRightIcon trailing; the whole field is clickable (source transparent
 *   overlay Box.clickable without indication → onFieldClick).
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';

/** M3 OutlinedTextField min height */
const FIELD_MIN_HEIGHT: number = 56;
/** Body large line height */
const LINE_HEIGHT: number = 24;
const FIELD_H_PADDING: number = 16;
const FIELD_V_PADDING: number = 16;
const MULTI_MIN_LINES: number = 3;
const MULTI_MAX_LINES: number = 5;
/** Floating label: font size / vertical offset onto the border */
const FLOAT_LABEL_FONT: number = 12;
const FLOAT_LABEL_OFFSET: number = -8;

@ComponentV2
export struct AddressOutlinedField {
  @Param fieldLabel: ResourceStr = '';
  @Param fieldPlaceholder: ResourceStr = '';
  @Param fieldValue: string = '';
  /** Multi-line (TextArea, 3..5 lines) instead of singleLine */
  @Param multiLine: boolean = false;
  /** Phone keyboard (KeyboardType.Phone) */
  @Param phoneKeyboard: boolean = false;
  /** IME action: Next (default) / Done */
  @Param imeDone: boolean = false;
  /** Display only, clickable (region field) */
  @Param readOnly: boolean = false;
  /** Container color behind the floating label (the card color) */
  @Param labelBgColor: ResourceColor = $r('app.color.bg_card');
  @Event onValueChange: (value: string) => void = (value: string) => {
  };
  @Event onFieldClick: () => void = () => {
  };

  @Local focused: boolean = false;

  private isFloating(): boolean {
    return this.focused || this.fieldValue.length > 0;
  }

  @Builder
  editor() {
    if (this.readOnly) {
      Row() {
        Text(this.fieldValue)
          .layoutWeight(1)
          .fontSize(Dimens.fontDisplaySmall)
          .lineHeight(LINE_HEIGHT)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // ArrowRightIcon(): ic_right 24vp RightArrowGray
        Image($r('app.media.ic_right'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.right_arrow_gray'))
      }
      .width('100%')
      .constraintSize({ minHeight: FIELD_MIN_HEIGHT })
      .padding({ left: FIELD_H_PADDING, right: 12 })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)
    } else if (this.multiLine) {
      TextArea({ text: this.fieldValue, placeholder: this.focused ? this.fieldPlaceholder : '' })
        .width('100%')
        .constraintSize({
          minHeight: LINE_HEIGHT * MULTI_MIN_LINES + FIELD_V_PADDING * 2,
          maxHeight: LINE_HEIGHT * MULTI_MAX_LINES + FIELD_V_PADDING * 2
        })
        .padding({ left: FIELD_H_PADDING, right: FIELD_H_PADDING, top: FIELD_V_PADDING, bottom: FIELD_V_PADDING })
        .fontSize(Dimens.fontDisplaySmall)
        .lineHeight(LINE_HEIGHT)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .placeholderFont({ size: Dimens.fontDisplaySmall })
        .caretColor(ThemeManager.instance.primary)
        .backgroundColor(Color.Transparent)
        .borderRadius(Dimens.radiusMedium)
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.onValueChange(value);
        })
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
        })
    } else {
      TextInput({ text: this.fieldValue, placeholder: this.focused ? this.fieldPlaceholder : '' })
        .width('100%')
        .height(FIELD_MIN_HEIGHT)
        .padding({ left: FIELD_H_PADDING, right: FIELD_H_PADDING })
        .fontSize(Dimens.fontDisplaySmall)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .placeholderFont({ size: Dimens.fontDisplaySmall })
        .caretColor(ThemeManager.instance.primary)
        .backgroundColor(Color.Transparent)
        .borderRadius(Dimens.radiusMedium)
        .maxLines(1)
        .type(this.phoneKeyboard ? InputType.PhoneNumber : InputType.Normal)
        .enterKeyType(this.imeDone ? EnterKeyType.Done : EnterKeyType.Next)
        .onChange((value: string) => {
          this.onValueChange(value);
        })
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
        })
    }
  }

  @Builder
  fieldLabelView() {
    if (this.isFloating()) {
      // Floated onto the top border, cutting it with the container color
      Text(this.fieldLabel)
        .fontSize(FLOAT_LABEL_FONT)
        .lineHeight(16)
        .fontColor(this.focused ? ThemeManager.instance.primary : $r('app.color.text_secondary'))
        .padding({ left: 4, right: 4 })
        .backgroundColor(this.labelBgColor)
        .margin({ left: FIELD_H_PADDING - 4 })
        .translate({ y: FLOAT_LABEL_OFFSET })
        .hitTestBehavior(HitTestMode.None)
    } else {
      // Resting inside the field like a placeholder
      Text(this.fieldLabel)
        .fontSize(Dimens.fontDisplaySmall)
        .lineHeight(LINE_HEIGHT)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: FIELD_H_PADDING, top: FIELD_V_PADDING })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  fieldBox() {
    Column() {
      this.editor()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(Dimens.radiusMedium)
    .border({
      width: this.focused ? 2 : 1,
      color: this.focused ? ThemeManager.instance.primary : $r('app.color.border')
    })

    this.fieldLabelView()
  }

  build() {
    if (this.readOnly) {
      // Source: transparent overlay Box(matchParentSize).clickable(indication = null)
      Stack({ alignContent: Alignment.TopStart }) {
        this.fieldBox()
      }
      .width('100%')
      .onClick(() => {
        this.onFieldClick();
      })
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        this.fieldBox()
      }
      .width('100%')
    }
  }
}
