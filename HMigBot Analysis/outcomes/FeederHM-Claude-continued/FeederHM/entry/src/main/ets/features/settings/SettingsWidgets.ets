/*
 * SettingsWidgets — 源 ui/compose/settings/Settings.kt 通用设置行组件与 SliderWithLabel.kt。
 *   GroupTitle(:974) / ActionSetting(:1014) / ExternalSetting(:1053) / MenuSetting(:1100) / ListDialogSetting(:1201) /
 *   RadioButtonSetting(:1383) / SwitchSetting(:1438) / TitleAndSubtitle(:1502) / HorizontalDivider；
 *   SliderWithLabel(:SliderWithLabel.kt:38) / SliderWithEndLabels(:79)。
 * 行宽 = dimens.maxContentWidth（宽度上限），左侧 64vp 图标位，标题 titleMedium、副标题 bodyMedium、间距 2vp。
 * DropdownMenu → bindMenu（外部点击/返回关闭不改值；当前值项粗体 + secondary 色）。
 */
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { MenuOption } from './SettingsOptions';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';

const ICON_BOX: number = 64;
const MIN_ROW_HEIGHT: number = 64;

@Builder
function noIcon() {
}

/** 源 GroupTitle：64vp 起始空白、高 64、labelMedium + primary，heading 语义 */
@ComponentV2
export struct GroupTitle {
  @Param groupTitle: ResourceStr = '';

  build() {
    Row() {
      Column()
        .width(ICON_BOX)
        .height(MIN_ROW_HEIGHT)
      Text(this.groupTitle)
        .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.primary))
    }
    .width('100%')
    .height(MIN_ROW_HEIGHT)
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}

/** 源 HorizontalDivider(Modifier.width(maxContentWidth)) */
@ComponentV2
export struct SettingsDivider {
  build() {
    Divider()
      .width('100%')
      .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
      .strokeWidth(1)
      .color(FeederTheme.colors.outlineVariant)
  }
}

/** 64vp 图标位（源 Box(size 64) + ContentAlpha.medium） */
@ComponentV2
struct IconBox {
  @BuilderParam iconBuilder: () => void = noIcon;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.iconBuilder()
    }
    .width(ICON_BOX)
    .height(ICON_BOX)
    .opacity(0.74)
  }
}

/** 源 RowScope.TitleAndSubtitle：weight(1) 列，标题 titleMedium，可选副标题 bodyMedium，2vp 间距 */
@ComponentV2
export struct TitleAndSubtitle {
  @Param rowTitle: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Param hasSubtitle: boolean = false;
  /** 源 ExternalSetting/MenuSetting/ActionSetting/ListDialog 副标题 maxLines = 1 + 省略；Switch 描述不限行 */
  @Param singleLine: boolean = false;
  @Param titleSingleLine: boolean = false;

  build() {
    Column() {
      Text(this.rowTitle)
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .maxLines(this.titleSingleLine ? 1 : 100)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.hasSubtitle) {
        Column().height(2)
        Text(this.subtitle)
          .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurfaceVariant))
          .maxLines(this.singleLine ? 1 : 100)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }
}

/** 源 ActionSetting：图标 + 单行标题，role=Button */
@ComponentV2
export struct ActionSetting {
  @Param rowTitle: ResourceStr = '';
  @BuilderParam iconBuilder: () => void = noIcon;
  @Event onAction: () => void = () => {
    console.info('TODO:action:ActionSetting');
  };

  build() {
    Row() {
      IconBox({ iconBuilder: (): void => {
        this.iconBuilder()
      } })
      Column() {
        TitleAndSubtitle({ rowTitle: this.rowTitle, titleSingleLine: true })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => {
      this.onAction();
    })
  }
}

/** 源 ExternalSetting：标题 + 副标题（各单行省略），role=Button */
@ComponentV2
export struct ExternalSetting {
  @Param rowTitle: ResourceStr = '';
  @Param currentValue: ResourceStr = '';
  @BuilderParam iconBuilder: () => void = noIcon;
  @Event onAction: () => void = () => {
    console.info('TODO:action:ExternalSetting');
  };

  build() {
    Row() {
      IconBox({ iconBuilder: (): void => {
        this.iconBuilder()
      } })
      Column() {
        TitleAndSubtitle({
          rowTitle: this.rowTitle,
          subtitle: this.currentValue,
          hasSubtitle: true,
          singleLine: true,
          titleSingleLine: true
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: MIN_ROW_HEIGHT })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => {
      this.onAction();
    })
  }
}

/**
 * 源 MenuSetting<T>：整行点击切换展开；DropdownMenu 每值一项，点击 → 关闭并 onSelection；
 * 当前值项 bodyLarge 粗体 + secondary 色；外部点击/返回关闭不改值（ST-A04）。
 */
@ComponentV2
export struct MenuSetting {
  @Param rowTitle: ResourceStr = '';
  /** 副标题 = 当前值文本（源 currentValue.toString()） */
  @Param currentLabel: ResourceStr = '';
  @Param currentKey: string = '';
  @Param options: MenuOption[] = [];
  @Event onSelection: (optionKey: string) => void = (optionKey: string) => {
    console.info(`TODO:select:MenuSetting ${optionKey}`);
  };
  @Local expanded: boolean = false;

  @Builder
  menuBuilder() {
    Menu() {
      ForEach(this.options, (opt: MenuOption) => {
        MenuItem({ content: opt.label })
          .contentFont({
            size: M3Type.bodyLarge.size,
            weight: opt.optionKey === this.currentKey ? FontWeight.Bold : FontWeight.Normal
          })
          .contentFontColor(opt.optionKey === this.currentKey ? FeederTheme.colors.secondary :
          FeederTheme.colors.onSurface)
          .onClick(() => {
            this.expanded = false;
            this.onSelection(opt.optionKey);
          })
      }, (opt: MenuOption) => `${opt.optionKey}|${opt.optionKey === this.currentKey}`)
    }
    // UT-A44：源 Settings.kt:1151 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.expanded = false;
    }))
  }

  build() {
    Row() {
      Column()
        .width(ICON_BOX)
        .height(ICON_BOX)
      Column() {
        TitleAndSubtitle({
          rowTitle: this.rowTitle,
          subtitle: this.currentLabel,
          hasSubtitle: true,
          singleLine: true,
          titleSingleLine: true
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: MIN_ROW_HEIGHT })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => {
      this.expanded = !this.expanded;
    })
    .bindMenu(this.expanded, this.menuBuilder, {
      onDisappear: () => {
        this.expanded = false;
      }
    })
  }
}

/** 源 ListDialogSetting 的行部分：标题 + 单行副标题；点击由调用方打开 EditableListDialog */
@ComponentV2
export struct ListDialogSetting {
  @Param rowTitle: ResourceStr = '';
  @Param currentValue: ResourceStr = '';
  @Event onOpen: () => void = () => {
    console.info('TODO:open:ListDialogSetting');
  };

  build() {
    Row() {
      Column()
        .width(ICON_BOX)
        .height(ICON_BOX)
      Column() {
        TitleAndSubtitle({
          rowTitle: this.rowTitle,
          subtitle: this.currentValue,
          hasSubtitle: true,
          singleLine: true
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: MIN_ROW_HEIGHT })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => {
      this.onOpen();
    })
  }
}

/**
 * 源 SwitchSetting：整行点击 → onCheckedChange(!checked)；enabled=false 时行与开关都不可点（ST-A05）；
 * role=Switch，stateDescription On/Off；可选 description 作副标题。开关本身不拦截点击（整行统一处理）。
 */
@ComponentV2
export struct SwitchSetting {
  @Param rowTitle: ResourceStr = '';
  @Param checked: boolean = false;
  @Param description: ResourceStr = '';
  @Param hasDescription: boolean = false;
  @Param rowEnabled: boolean = true;
  @Event onCheckedChange: (value: boolean) => void = (value: boolean) => {
    console.info(`TODO:checkedChange:SwitchSetting ${value}`);
  };

  build() {
    Row() {
      Column()
        .width(ICON_BOX)
        .height(ICON_BOX)
      Column() {
        TitleAndSubtitle({ rowTitle: this.rowTitle, subtitle: this.description, hasSubtitle: this.hasDescription })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column().width(8)

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(FeederTheme.colors.primary)
        .enabled(this.rowEnabled)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: MIN_ROW_HEIGHT })
    .alignItems(VerticalAlign.Center)
    .opacity(this.rowEnabled ? 1 : 0.6)
    .hitTestBehavior(this.rowEnabled ? HitTestMode.Default : HitTestMode.None)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.SWITCH)
    .accessibilityChecked(this.checked)
    .accessibilityStateDescription(this.checked ? $r('app.string.on') : $r('app.string.off'))
    .onClick(() => {
      this.onCheckedChange(!this.checked);
    })
  }
}

/** 源 RadioButtonSetting（本页未用；供同族页面复用）：role=RadioButton，最小高 64 */
@ComponentV2
export struct RadioButtonSetting {
  @Param rowTitle: ResourceStr = '';
  @Param selected: boolean = false;
  @Param minRowHeight: number = MIN_ROW_HEIGHT;
  @Event onSelect: () => void = () => {
    console.info('TODO:select:RadioButtonSetting');
  };

  build() {
    Row() {
      Column()
        .width(ICON_BOX)
        .height(ICON_BOX)
      Column() {
        TitleAndSubtitle({ rowTitle: this.rowTitle })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column().width(8)

      Radio({ value: 'settings', group: 'settings' })
        .checked(this.selected)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth, minHeight: this.minRowHeight })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.RADIO)
    .accessibilityChecked(this.selected)
    .onClick(() => {
      this.onSelect();
    })
  }
}

/** Compose Slider(steps)：steps>0 → 区间等分 steps+1 段；0 → 连续（取 1/100 区间近似） */
export function sliderStep(start: number, end: number, steps: number): number {
  const span = Math.abs(end - start);
  if (span === 0) {
    return 1;
  }
  return steps > 0 ? span / (steps + 1) : span / 100;
}

/** 源 SliderWithLabel 的气泡偏移：(boxWidth - (labelMinWidth + 8)) * fraction，fraction 钳 0..1，区间宽 0 → 0 */
export function sliderLabelOffset(boxWidth: number, labelMinWidth: number, value: number, start: number,
  end: number): number {
  const span = end - start;
  let fraction = 0;
  if (span !== 0) {
    const v = Math.min(Math.max(value, start), end);
    fraction = Math.min(Math.max((v - start) / span, 0), 1);
  }
  return (boxWidth - (labelMinWidth + 8)) * fraction;
}

/** 源 SliderWithLabel：滑块上方随值水平移动的气泡（primary 底、圆角 10、onPrimary 字、labelMedium） */
@ComponentV2
export struct SliderWithLabel {
  @Param value: number = 0;
  @Param valueLabel: string = '';
  @Param rangeStart: number = 0;
  @Param rangeEnd: number = 1;
  @Param steps: number = 0;
  @Param labelMinWidth: number = 28;
  @Event onValueChange: (v: number) => void = (v: number) => {
    console.info(`TODO:valueChange:SliderWithLabel ${v}`);
  };
  @Local boxWidth: number = 0;

  build() {
    Column() {
      Row() {
        Text(this.valueLabel)
          .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.onPrimary))
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: this.labelMinWidth })
          .padding(4)
          .backgroundColor(FeederTheme.colors.primary)
          .borderRadius(10)
          .margin({
            left: sliderLabelOffset(this.boxWidth, this.labelMinWidth, this.value, this.rangeStart, this.rangeEnd)
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Slider({
        value: this.value,
        min: this.rangeStart,
        max: this.rangeEnd,
        step: sliderStep(this.rangeStart, this.rangeEnd, this.steps),
        style: SliderStyle.InSet
      })
        .width('100%')
        .showSteps(this.steps > 0)
        .selectedColor(FeederTheme.colors.primary)
        .blockColor(FeederTheme.colors.primary)
        .onChange((v: number, mode: SliderChangeMode) => {
          this.onValueChange(v);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.boxWidth = newArea.width as number;
    })
  }
}

/** 源 SliderWithEndLabels：滑块上方左右两端标签（SpaceBetween、底部对齐） */
@ComponentV2
export struct SliderWithEndLabels {
  @Param value: number = 0;
  @Param rangeStart: number = 0;
  @Param rangeEnd: number = 1;
  @Param steps: number = 0;
  @BuilderParam startLabel: () => void = noIcon;
  @BuilderParam endLabel: () => void = noIcon;
  @Event onValueChange: (v: number) => void = (v: number) => {
    console.info(`TODO:valueChange:SliderWithEndLabels ${v}`);
  };

  build() {
    Column() {
      Row() {
        this.startLabel()
        this.endLabel()
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)

      Slider({
        value: this.value,
        min: this.rangeStart,
        max: this.rangeEnd,
        step: sliderStep(this.rangeStart, this.rangeEnd, this.steps),
        style: SliderStyle.InSet
      })
        .width('100%')
        .showSteps(this.steps > 0)
        .selectedColor(FeederTheme.colors.primary)
        .blockColor(FeederTheme.colors.primary)
        .onChange((v: number, mode: SliderChangeMode) => {
          this.onValueChange(v);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
