/**
 * BottomModal / CenterModal + SheetDefaults
 * (source: core/ui/component/modal/BottomModal.kt, core/ui/component/modal/Modal.kt).
 *
 * ModalBottomSheet → ArkUI `bindSheet`. The sheet itself is configured by `SheetDefaults.options(...)`
 * (fit-content height, 16vp top corners, surface background, no system drag bar / close button);
 * `BottomModal` renders the source's sheet *content*: custom 40x4 drag indicator, centered title,
 * horizontally padded content and the 12vp bottom spacer.
 *
 *   @Local showSheet: boolean = false;
 *   @Builder sheetBuilder() {
 *     BottomModal({ sheetTitle: $r('app.string.settings_dark_mode'), sheetContent: (): void => { this.body() } })
 *   }
 *   Column() {...}
 *     .bindSheet(this.showSheet, this.sheetBuilder(),
 *       SheetDefaults.options((): void => { this.showSheet = false; }))
 */
import { Dimens } from '../../designsystem/Dimens';
import { AvoidArea } from '../base/AvoidArea';
import { WidgetColors } from './WidgetColors';

@Builder
function emptySheetSlot() {
}

/** Modal.kt ModalType */
export enum ModalType {
  BOTTOM,
  CENTER
}

export class SheetDefaults {
  /**
   * SheetOptions matching BottomModal: FIT_CONTENT height, top radius 16, `containerColor`
   * (default colorScheme.surface; several source screens pass colorScheme.background = bg_page),
   * M3 scrim, no system drag bar/close. `onDismiss` runs when the sheet has disappeared (drag down,
   * mask tap, back) so the caller can reset its visibility flag.
   */
  static options(onDismiss: () => void, containerColor?: ResourceColor): SheetOptions {
    const opts: SheetOptions = {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      showClose: false,
      preferType: SheetType.BOTTOM,
      backgroundColor: containerColor !== undefined ? containerColor : $r('app.color.surface'),
      maskColor: WidgetColors.SCRIM,
      radius: { topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0 },
      onDisappear: (): void => {
        onDismiss();
      }
    };
    return opts;
  }
}

/** Content of a bottom sheet (BottomModal.kt). Put it at the root of the bindSheet builder. */
@ComponentV2
export struct BottomModal {
  @Param sheetTitle: ResourceStr | undefined = undefined;
  @Param showDragIndicator: boolean = true;
  @Param horizontalPadding: number = Dimens.spacePaddingLarge;
  /** outline @ 0.8 */
  @Param indicatorColor: ResourceColor = $r('app.color.border');
  /**
   * Add the navigation-indicator height below the content (M3 ModalBottomSheet applies navigation-bar
   * insets). Off by default because bindSheet already lays its content out above the system bar;
   * turn on only if a device check shows the content under the indicator.
   */
  @Param avoidBottomInset: boolean = false;
  @BuilderParam sheetContent: () => void = emptySheetSlot;
  @Local avoidArea: AvoidArea = AvoidArea.get();

  build() {
    Column() {
      if (this.showDragIndicator) {
        Row() {
          Row()
            .width(40)
            .height(4)
            .borderRadius(2)
            .backgroundColor(this.indicatorColor)
            .opacity(0.8)
        }
        .width('100%')
        .padding({ top: Dimens.spacePaddingLarge, bottom: Dimens.spacePaddingLarge })
        // source: Box(contentAlignment = Center)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      Column() {
        if (this.sheetTitle !== undefined) {
          Text(this.sheetTitle as ResourceStr)
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(Dimens.fontTitleLarge)
            .lineHeight(Dimens.lineTitleLarge)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: Dimens.spaceVerticalLarge })
        }
        this.sheetContent()
        // SpaceVerticalMedium()
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
      }
      .width('100%')
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      // source: Column without alignment = start
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: this.avoidBottomInset ? this.avoidArea.bottom : 0 })
  }
}

/**
 * Modal.kt CENTER content: surface card with 12vp corners, 24vp horizontal margin.
 * Open it with `getPromptAction().openCustomDialog(ComponentContent)` (see DialogHelper) — the source
 * Modal(CENTER) is not used by any feature screen, so no helper is provided.
 */
@ComponentV2
export struct CenterModal {
  @BuilderParam modalContent: () => void = emptySheetSlot;

  build() {
    Column() {
      Column() {
        this.modalContent()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
