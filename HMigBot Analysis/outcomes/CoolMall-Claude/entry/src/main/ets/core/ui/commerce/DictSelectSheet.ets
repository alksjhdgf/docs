/**
 * Dictionary single-select sheet (source: core/ui/component/modal/DictSelectModal.kt) — ORDA-A16,
 * used for cancel reasons (order list/detail) and refund reasons.
 *
 * States: 'loading' → PageLoading (300vp), 'error' → EmptyNetwork + retry (300vp), 'success' → radio list
 * (max 400vp, spacedBy 12) + `确定` button (enabled only with a selection). Confirm → onConfirm(item)
 * then onDismiss. The dictionary is loaded by the page from onExpanded:
 *   .bindSheet(this.cancelVisible, this.cancelSheet(),
 *     CommerceSheet.options(() => { this.vm.hideCancelModal(); }, () => { this.vm.loadCancelReasons(); }))
 */
import { DictItem } from '../../model/Market';
import { Dimens } from '../../designsystem/Dimens';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { BottomModal } from '../widget/BottomSheet';
import { AppButton, AppButtonSize } from '../widget/Buttons';
import { AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { PageLoading, EmptyNetwork } from '../base/StateViews';

const STATE_HEIGHT: number = 300;
const LIST_MAX_HEIGHT: number = 400;

@ComponentV2
export struct DictSelectSheet {
  /** Sheet title (source title: Int = R.string.please_select) */
  @Param sheetTitle: ResourceStr = $r('app.string.please_select');
  /** 'loading' | 'success' | 'error' */
  @Param dictUiState: string = 'loading';
  @Param dictItems: DictItem[] = [];
  @Param selectedItem: DictItem | null = null;
  @Event onDismiss: () => void = () => {
  };
  @Event onItemSelected: (item: DictItem) => void = (item: DictItem) => {
  };
  @Event onConfirm: (item: DictItem | null) => void = (item: DictItem | null) => {
  };
  @Event onRetry: () => void = () => {
  };
  /** remember(selectedItem) { selectedItem } */
  @Local internalSelectedItem: DictItem | null = null;

  aboutToAppear(): void {
    this.internalSelectedItem = this.selectedItem;
  }

  @Monitor('selectedItem')
  onSelectedItemChanged(): void {
    this.internalSelectedItem = this.selectedItem;
  }

  private isSelected(item: DictItem): boolean {
    return this.internalSelectedItem !== null && (this.internalSelectedItem as DictItem).id === item.id;
  }

  /** Custom radio: 20vp circle, 2vp border primary/outline, filled primary with an 8vp onPrimary dot. */
  @Builder
  radio(item: DictItem) {
    Stack({ alignContent: Alignment.Center }) { // source Box(contentAlignment = Center)
      if (this.isSelected(item)) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.text_white'))
      }
    }
    .width(20)
    .height(20)
    .borderRadius(10)
    .clip(true)
    .border({
      width: 2,
      color: this.isSelected(item) ? ThemeManager.instance.primary : $r('app.color.border'),
      radius: 10
    })
    .backgroundColor(this.isSelected(item) ? ThemeManager.instance.primary : Color.Transparent)
    // the whole row handles the tap (source: radio and row both call onItemClick)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  listContent() {
    Column() {
      Scroll() {
        Column({ space: Dimens.spaceVerticalMedium }) {
          ForEach(this.dictItems, (item: DictItem) => {
            // SpaceBetweenRow(clip 8, clickable, padding h12 v12) { StartRow { radio, 12, name } }
            Row() {
              this.radio(item)
              Text(item.name !== null ? item.name as string : '')
                .layoutWeight(1)
                .margin({ left: Dimens.spaceHorizontalMedium })
                .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
                .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
                .fontColor(AppTextStyles.color(this.isSelected(item) ? AppTextType.PRIMARY : AppTextType.SECONDARY))
            }
            .width('100%')
            .padding({
              left: Dimens.spaceHorizontalMedium,
              right: Dimens.spaceHorizontalMedium,
              top: Dimens.spaceVerticalMedium,
              bottom: Dimens.spaceVerticalMedium
            })
            // source StartRow: Start + CenterVertically
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .borderRadius(Dimens.radiusSmall)
            .clip(true)
            .stateStyles({
              normal: {
                .backgroundColor(Color.Transparent)
              },
              pressed: {
                .backgroundColor($r('app.color.press'))
              }
            })
            .onClick(() => {
              this.internalSelectedItem = item;
              this.onItemSelected(item);
            })
          }, (item: DictItem) => item.id + '_' + item.value + '_' + item.name)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ maxHeight: LIST_MAX_HEIGHT })
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      Row() {
        AppButton({
          btnText: $r('app.string.confirm'),
          btnEnabled: this.internalSelectedItem !== null,
          btnSize: AppButtonSize.MEDIUM,
          onBtnClick: () => {
            this.onConfirm(this.internalSelectedItem);
            this.onDismiss();
          }
        })
      }
      .width('100%')
      .margin({ top: Dimens.spaceVerticalLarge })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    // source WrapColumn: Top + Start
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  body() {
    if (this.dictUiState === 'loading') {
      Column() {
        PageLoading()
      }
      .width('100%')
      .height(STATE_HEIGHT)
      .alignItems(HorizontalAlign.Center)
    } else if (this.dictUiState === 'error') {
      Column() {
        EmptyNetwork({
          showRetry: true,
          onRetryClick: () => {
            this.onRetry();
          }
        })
      }
      .width('100%')
      .height(STATE_HEIGHT)
      .alignItems(HorizontalAlign.Center)
    } else {
      this.listContent()
    }
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: this.sheetTitle,
        sheetContent: (): void => {
          this.body()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
