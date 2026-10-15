/**
 * FeedbackRoutesSubmitPage — submit feedback (source: feature/feedback/view/FeedbackSubmitScreen.kt +
 * viewmodel/FeedbackSubmitViewModel.kt) — USER-A39~A44.
 *
 * AppScaffold(large top bar `我要反馈`, back; the top bar pads the status bar — USER-A39,
 *   bottomBar `提交` only on success: enabled = form valid && !submitting, loading = submitting — USER-A42) {
 *   NetWorkStateView(dict/info/data feedbackType: loading | error → retry) success →
 *   Scroll { VerticalList(padding 12, spacedBy 12) {
 *     AppCard(`反馈类型`)  { FlowRow(spacedBy 8 / 8, top 8) { FilterChip per dictionary item (single select) } }
 *     AppCard(`反馈内容`)  { OutlinedTextField(3..5 lines, placeholder hint, top 8) }
 *     AppCard(`联系方式（选填）`) { OutlinedTextField(single line, placeholder hint, top 8) }
 *     AppCard(`问题截图（选填）`) { ImageGridPicker(max 9, top 8) }   — USER-A40/A41
 *   } }
 * }
 * Submit flow (upload → app/feedback/submit → toast → back with refresh) lives in FeedbackSubmitViewModel.
 */
import { LengthMetrics } from '@kit.ArkUI';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { DictItem } from '../core/model/Market';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AppCard } from '../core/ui/widget/AppCard';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { ImageGridPicker } from '../core/ui/widget/ImageGridPicker';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { FeedbackSubmitViewModel } from '../feature/feedback/FeedbackSubmitViewModel';

/** FilterChip height (source Modifier.height(32.dp)) */
const CHIP_HEIGHT: number = 32;
/** M3 FilterChip horizontal label padding (no icons) */
const CHIP_PADDING_H: number = 16;
/** M3 FilterChip corner radius */
const CHIP_RADIUS: number = 8;
/** OutlinedTextField min height (M3 56dp) */
const FIELD_MIN_HEIGHT: number = 56;
/** OutlinedTextField inner padding (M3 16dp) */
const FIELD_PADDING: number = 16;
/** Content field: minLines = 3 (bodyLarge line height 22) */
const CONTENT_MIN_HEIGHT: number = 3 * 22 + 2 * FIELD_PADDING;
/** Content field: maxLines = 5 */
const CONTENT_MAX_LINES: number = 5;

@Builder
export function FeedbackRoutesSubmitPageBuilder() {
  FeedbackRoutesSubmitPage()
}

@ComponentV2
struct FeedbackRoutesSubmitPage {
  @Local vm: FeedbackSubmitViewModel = new FeedbackSubmitViewModel();
  @Local contentFocused: boolean = false;
  @Local contactFocused: boolean = false;

  aboutToAppear(): void {
    // source init { super.executeRequest() }
    this.vm.executeRequest();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private isSelected(item: DictItem): boolean {
    const selected: DictItem | null = this.vm.selectedFeedbackType;
    return selected !== null && selected.value === item.value;
  }

  private fieldBorderColor(focused: boolean): ResourceColor {
    return focused ? ThemeManager.instance.primary : $r('app.color.border');
  }

  @Builder
  feedbackTypeChip(item: DictItem) {
    Row() {
      if (item.name !== null && item.name !== undefined) {
        Text(item.name as string)
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(this.isSelected(item) ? Color.White : $r('app.color.text_primary'))
      }
    }
    .height(CHIP_HEIGHT)
    .padding({ left: CHIP_PADDING_H, right: CHIP_PADDING_H })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .borderRadius(CHIP_RADIUS)
    .borderWidth(1)
    .borderColor(this.isSelected(item) ? ThemeManager.instance.primary : $r('app.color.border'))
    .backgroundColor(this.isSelected(item) ? ThemeManager.instance.primary : $r('app.color.surface'))
    .onClick(() => {
      this.vm.selectFeedbackType(item);
    })
  }

  @Builder
  typeChips() {
    Flex({
      wrap: FlexWrap.Wrap,
      justifyContent: FlexAlign.Start,
      alignItems: ItemAlign.Start,
      space: { main: LengthMetrics.vp(Dimens.spaceHorizontalSmall), cross: LengthMetrics.vp(Dimens.spaceVerticalSmall) }
    }) {
      ForEach(this.vm.feedbackTypes(), (item: DictItem, index: number) => {
        this.feedbackTypeChip(item)
      }, (item: DictItem, index: number) => 'type_' + index + '_' + item.value + '_' + item.name + '_' +
        this.isSelected(item))
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  contentField() {
    TextArea({ text: this.vm.content, placeholder: $r('app.string.feedback_content_hint') })
      .width('100%')
      .margin({ top: 8 })
      .constraintSize({ minHeight: CONTENT_MIN_HEIGHT })
      .maxLines(CONTENT_MAX_LINES)
      .padding(FIELD_PADDING)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
      .fontColor($r('app.color.text_primary'))
      .placeholderColor(AppTextStyles.color(AppTextType.TERTIARY))
      .placeholderFont({ size: AppTextStyles.fontSize(AppTextSize.BODY_LARGE) })
      .caretColor(ThemeManager.instance.primary)
      .backgroundColor(Color.Transparent)
      .borderRadius(Dimens.radiusMedium)
      .borderWidth(this.contentFocused ? 2 : 1)
      .borderColor(this.fieldBorderColor(this.contentFocused))
      .enterKeyType(EnterKeyType.Done)
      .onChange((value: string) => {
        this.vm.updateContent(value);
      })
      .onFocus(() => {
        this.contentFocused = true;
      })
      .onBlur(() => {
        this.contentFocused = false;
      })
  }

  @Builder
  contactField() {
    TextInput({ text: this.vm.contact, placeholder: $r('app.string.contact_info_hint') })
      .width('100%')
      .height(FIELD_MIN_HEIGHT)
      .margin({ top: 8 })
      .padding({ left: FIELD_PADDING, right: FIELD_PADDING })
      .type(InputType.Normal)
      .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
      .fontColor($r('app.color.text_primary'))
      .placeholderColor(AppTextStyles.color(AppTextType.TERTIARY))
      .placeholderFont({ size: AppTextStyles.fontSize(AppTextSize.BODY_LARGE) })
      .caretColor(ThemeManager.instance.primary)
      .backgroundColor(Color.Transparent)
      .borderRadius(Dimens.radiusMedium)
      .borderWidth(this.contactFocused ? 2 : 1)
      .borderColor(this.fieldBorderColor(this.contactFocused))
      .enterKeyType(EnterKeyType.Next)
      .onChange((value: string) => {
        this.vm.updateContact(value);
      })
      .onFocus(() => {
        this.contactFocused = true;
      })
      .onBlur(() => {
        this.contactFocused = false;
      })
  }

  @Builder
  screenshotPicker() {
    Column() {
      ImageGridPicker({
        selectedImages: this.vm.selectedImages,
        maxImages: 9,
        onImagesChanged: (images: string[]) => {
          this.vm.updateSelectedImages(images);
        }
      })
    }
    .width('100%')
    .margin({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  /** Source FeedbackSubmitContentView */
  @Builder
  successContent() {
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        AppCard({
          lineTitle: $r('app.string.feedback_type'),
          cardContent: (): void => {
            this.typeChips()
          }
        })
        AppCard({
          lineTitle: $r('app.string.feedback_content'),
          cardContent: (): void => {
            this.contentField()
          }
        })
        AppCard({
          lineTitle: $r('app.string.contact_info_optional'),
          cardContent: (): void => {
            this.contactField()
          }
        })
        AppCard({
          lineTitle: $r('app.string.problem_screenshot_optional'),
          cardContent: (): void => {
            this.screenshotPicker()
          }
        })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    // lets the large top bar collapse first (AppScaffold contract)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      onRetry: () => {
        this.vm.retryRequest();
      },
      content: (): void => {
        this.successContent()
      }
    })
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.submit'),
      btnEnabled: this.vm.isFormValid() && !this.vm.isSubmitting,
      loading: this.vm.isSubmitting,
      onBtnClick: () => {
        this.vm.onSubmitButtonClick();
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: $r('app.string.feedback_submit'),
          useLargeTopBar: true,
          hasBottomBar: this.vm.uiState === 'success',
          bottomBar: (): void => {
            this.bottomBar()
          },
          content: (): void => {
            this.pageContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
  }
}
