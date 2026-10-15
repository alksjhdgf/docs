/**
 * ChatInputArea + ChatInputBar (source: feature/cs/component/ChatInputArea.kt, ChatInputBar.kt) — CS-A17..A20.
 *
 * Column(surface, bottom padding = navigation bar) {
 *   input bar Row(padding h12 v8, CenterVertically) {
 *     input (weight 1, 36vp, surfaceVariant, ShapeExtraLarge, single line, placeholder `发送消息...`)
 *     8 · emoji button (32 circle, ic_emoji_good 24, primary when the panel is open)
 *     8 · `发送` mini button when there is input, else plus button (ic_add_circle, primary when open)
 *   }
 *   emoji panel (240vp, spring height animation) | function panel (130vp)
 * }
 * Panels are mutually exclusive; opening one hides the keyboard; focusing the input closes both.
 * Function items only collapse the panel (source TODO).
 */
import { curves } from '@kit.ArkUI';
import { Dimens } from '../../core/designsystem/Dimens';
import { ThemeManager } from '../../core/designsystem/ThemeManager';
import { AvoidArea } from '../../core/ui/base/AvoidArea';
import { AppButton, AppButtonSize } from '../../core/ui/widget/Buttons';
import { EmojiSelector } from './EmojiSelector';
import { FunctionSelector } from './FunctionSelector';

const EMOJI_PANEL_HEIGHT: number = 240;
const FUNCTION_PANEL_HEIGHT: number = 130;
const ICON_BUTTON_SIZE: number = 32;
const ICON_SIZE: number = 24;
const INPUT_HEIGHT: number = 36;
/** spring(DampingRatioLowBouncy 0.75, StiffnessLow 200): damping = 2 * 0.75 * sqrt(200) */
const PANEL_SPRING: curves.ICurve = curves.interpolatingSpring(0, 1, 200, 21.2);
const BUTTON_SWITCH_EFFECT: TransitionEffect =
  TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })).animation({ duration: 220 });

@ComponentV2
export struct ChatInputArea {
  @Param inputText: string = '';
  @Event onInputTextChange: (text: string) => void = (text: string) => {
  };
  @Event onSendMessage: () => void = () => {
  };
  @Local showEmojiSelector: boolean = false;
  @Local showFunctionSelector: boolean = false;
  /** Panels stay mounted while their collapse animation runs */
  @Local emojiMounted: boolean = false;
  @Local functionMounted: boolean = false;
  @Local emojiHeight: number = 0;
  @Local functionHeight: number = 0;
  @Local avoidArea: AvoidArea = AvoidArea.get();

  private hideKeyboard(): void {
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (e) {
      console.info('TODO:hideKeyboard:ChatInputArea');
    }
  }

  private setEmojiSelector(show: boolean): void {
    if (this.showEmojiSelector === show && this.emojiMounted === show) {
      return;
    }
    this.showEmojiSelector = show;
    if (show) {
      this.emojiMounted = true;
    }
    this.getUIContext().animateTo({
      curve: PANEL_SPRING,
      onFinish: () => {
        if (!this.showEmojiSelector) {
          this.emojiMounted = false;
        }
      }
    }, () => {
      this.emojiHeight = show ? EMOJI_PANEL_HEIGHT : 0;
    });
  }

  private setFunctionSelector(show: boolean): void {
    if (this.showFunctionSelector === show && this.functionMounted === show) {
      return;
    }
    this.showFunctionSelector = show;
    if (show) {
      this.functionMounted = true;
    }
    this.getUIContext().animateTo({
      curve: PANEL_SPRING,
      onFinish: () => {
        if (!this.showFunctionSelector) {
          this.functionMounted = false;
        }
      }
    }, () => {
      this.functionHeight = show ? FUNCTION_PANEL_HEIGHT : 0;
    });
  }

  /** Source handleEmojiSelectorToggle */
  private handleEmojiSelectorToggle(show: boolean): void {
    if (show) {
      this.hideKeyboard();
      this.setFunctionSelector(false);
    }
    this.setEmojiSelector(show);
  }

  /** Source handleFunctionSelectorToggle */
  private handleFunctionSelectorToggle(show: boolean): void {
    if (show) {
      this.hideKeyboard();
      this.setEmojiSelector(false);
    }
    this.setFunctionSelector(show);
  }

  @Builder
  iconButton(icon: Resource, label: Resource, active: boolean, onTap: () => void) {
    Stack({ alignContent: Alignment.Center }) { // source contentAlignment = Center
      Image(icon)
        .width(ICON_SIZE)
        .height(ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .fillColor(active ? ThemeManager.instance.primary : $r('app.color.text_secondary'))
        .accessibilityText(label)
    }
    .width(ICON_BUTTON_SIZE)
    .height(ICON_BUTTON_SIZE)
    .borderRadius(ICON_BUTTON_SIZE / 2)
    .clip(true)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  inputBar() {
    Row() {
      TextInput({ text: this.inputText, placeholder: $r('app.string.input_message_hint') })
        .layoutWeight(1)
        .height(INPUT_HEIGHT)
        .maxLines(1)
        .backgroundColor($r('app.color.bg_content')) // colorScheme.surfaceVariant
        .borderRadius(Dimens.radiusExtraLarge)
        .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium, top: 0, bottom: 0 })
        .fontSize(Dimens.fontBodyMedium)
        .fontColor($r('app.color.text_primary'))
        .placeholderFont({ size: Dimens.fontBodySmall })
        .placeholderColor($r('app.color.text_tertiary'))
        .caretColor(ThemeManager.instance.primary)
        .onChange((value: string) => {
          this.onInputTextChange(value);
        })
        .onFocus(() => {
          // close both panels before the keyboard shows
          this.setEmojiSelector(false);
          this.setFunctionSelector(false);
        })

      Row() {
        this.iconButton($r('app.media.ic_emoji_good'), $r('app.string.emoji'), this.showEmojiSelector, () => {
          this.handleEmojiSelectorToggle(!this.showEmojiSelector);
        })
      }
      .margin({ left: Dimens.spaceHorizontalSmall })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        if (this.inputText.length > 0) {
          Row() {
            AppButton({
              btnText: $r('app.string.send'),
              btnSize: AppButtonSize.MINI,
              fullWidth: false,
              onBtnClick: () => {
                this.onSendMessage();
              }
            })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .transition(BUTTON_SWITCH_EFFECT)
        } else {
          Row() {
            this.iconButton($r('app.media.ic_add_circle'), $r('app.string.more_functions'),
              this.showFunctionSelector, () => {
                this.handleFunctionSelectorToggle(!this.showFunctionSelector);
              })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .transition(BUTTON_SWITCH_EFFECT)
        }
      }
      .margin({ left: Dimens.spaceHorizontalSmall })
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingSmall,
      bottom: Dimens.spacePaddingSmall
    })
    .backgroundColor($r('app.color.surface'))
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
  }

  build() {
    Column() {
      this.inputBar()

      if (this.emojiMounted) {
        Column() {
          EmojiSelector({
            onEmojiSelected: (emoji: string) => {
              this.onInputTextChange(this.inputText + emoji);
            }
          })
        }
        .width('100%')
        .height(this.emojiHeight)
        .clip(true)
        .backgroundColor($r('app.color.surface')) // surfaceContainerLow
        .alignItems(HorizontalAlign.Start)
      }

      if (this.functionMounted) {
        Column() {
          FunctionSelector({
            onFunctionSelected: (fn: string) => {
              // source: TODO 处理功能选择 — only collapses the panel
              console.info('TODO:functionSelected:' + fn + ':FunctionSelector');
              this.setFunctionSelector(false);
            }
          })
        }
        .width('100%')
        .height(this.functionHeight)
        .clip(true)
        .backgroundColor($r('app.color.surface'))
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({ bottom: this.avoidArea.bottom }) // windowInsetsPadding(navigationBars)
    .backgroundColor($r('app.color.surface'))
    .alignItems(HorizontalAlign.Start)
  }
}
