/**
 * EditFeedScreen —— 源 ui/compose/editfeed/EditFeedScreen.kt 的 Scaffold 外壳（AddFeed/EditFeed 两页共用）：
 *  - EF-A22/A38：顶栏 SensibleTopAppBar 吸收状态栏避让（AvoidArea.top），内容不与状态栏重叠；
 *  - EF-A23/A39：标题 `Edit feed`（添加与编辑共用），导航图标返回（无障碍 `Go back`）→ onNavigateUp（不保存）；
 *  - 主体 EditFeedForm；loading/missing 时显示空态（`Nothing to display!` + 返回）。
 */
import { common } from '@kit.AbilityKit';
import { ScreenType } from '../../core/platform/LayoutAdapt';
import { FeederTheme, SensibleTopAppBar } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { EditFeedForm } from './EditFeedForm';
import { EditFeedViewModel } from './EditFeedViewModel';

const LOG_TAG: string = 'EditFeedScreen';

export enum EditFeedScreenPhase {
  LOADING = 0,
  READY = 1,
  MISSING = 2,
}

@ComponentV2
export struct EditFeedScreen {
  @Param vm: EditFeedViewModel = new EditFeedViewModel();
  @Param phase: EditFeedScreenPhase = EditFeedScreenPhase.READY;
  @Param screenType: ScreenType = ScreenType.SINGLE;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Event onNavigateUp: () => void = () => {
    console.info('TODO:onNavigateUp:EditFeedScreen');
  };
  @Event onOk: () => void = () => {
    console.info('TODO:onOk:EditFeedScreen');
  };
  @Event onCancel: () => void = () => {
    console.info('TODO:onCancel:EditFeedScreen');
  };
  @Local barTitle: string = '';

  aboutToAppear(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    try {
      this.barTitle = ctx !== undefined ? ctx.resourceManager.getStringByNameSync('edit_feed') : '';
    } catch (e) {
      console.warn(`${LOG_TAG}: edit_feed string lookup failed: ${JSON.stringify(e)}`);
    }
  }

  @Builder
  backButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.arrow_left'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurface])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .accessibilityText($r('app.string.go_back'))
    .onClick(() => {
      this.onNavigateUp();
    })
  }

  @Builder
  emptyState() {
    Column({ space: 16 }) {
      Text(this.phase === EditFeedScreenPhase.MISSING ? $r('app.string.nothing_to_display') : '')
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurfaceVariant))
        .textAlign(TextAlign.Center)
      if (this.phase === EditFeedScreenPhase.MISSING) {
        Button($r('app.string.go_back'), { type: ButtonType.Capsule })
          .backgroundColor(Color.Transparent)
          .fontColor(FeederTheme.colors.primary)
          .onClick(() => {
            this.onNavigateUp();
          })
      } else {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(FeederTheme.colors.primary)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      SensibleTopAppBar({
        titleText: this.barTitle,
        topInset: this.topInset,
        navigationIconBuilder: (): void => {
          this.backButton()
        }
      })
      if (this.phase === EditFeedScreenPhase.READY) {
        Column() {
          EditFeedForm({
            vm: this.vm,
            screenType: this.screenType,
            bottomInset: this.bottomInset,
            onOk: () => {
              this.onOk();
            },
            onCancel: () => {
              this.onCancel();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        this.emptyState()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.background)
  }
}
