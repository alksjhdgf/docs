/**
 * EditFeedFormRows —— EditFeedForm 的行组件：源 settings/Settings.kt 的 SwitchSetting / RadioButtonSetting（icon = null）
 * 与 editfeed/EditFeedScreen.kt 的 RulesField + ruleErrorText。
 */
import { common } from '@kit.AbilityKit';
import { ArticleRuleError, TooManyRules, UnknownField } from '../../core/sync/ArticleFilterRules';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, monoFamily, textStyle } from '../../ui/common/Typography';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

const LOG_TAG: string = 'EditFeedFormRows';

/** 资源字符串 → 带位置参数替换（%1$d / %2$s / %2$d） */
export function formatRuleError(ctx: common.Context | undefined, err: ArticleRuleError): string {
  let name: string = 'rule_error_invalid_regex';
  if (err.kind === 'MissingSeparator') {
    name = 'rule_error_missing_separator';
  } else if (err.kind === 'UnknownField') {
    name = 'rule_error_unknown_field';
  } else if (err.kind === 'EmptyPattern') {
    name = 'rule_error_empty_pattern';
  } else if (err.kind === 'TooManyRules') {
    name = 'rule_error_too_many_rules';
  }
  let s: string = '';
  try {
    s = ctx !== undefined ? ctx.resourceManager.getStringByNameSync(name) : '';
  } catch (e) {
    console.warn(`${LOG_TAG}: getStringByNameSync(${name}) failed: ${JSON.stringify(e)}`);
  }
  s = s.split('%1$d').join(`${err.lineNumber}`);
  if (err instanceof UnknownField) {
    s = s.split('%2$s').join((err as UnknownField).fieldName);
  }
  if (err instanceof TooManyRules) {
    s = s.split('%2$d').join(`${(err as TooManyRules).maxRules}`);
  }
  return s;
}

// ====================================================================== 行组件（源 SwitchSetting / RadioButtonSetting）

/** 源 SwitchSetting(icon = null)：整行可点切换，最小高 64；标题 titleMedium，说明 bodyMedium */
@ComponentV2
export struct FormSwitchRow {
  @Param labelText: ResourceStr = '';
  @Param descText: ResourceStr = '';
  @Param hasDesc: boolean = false;
  @Param checked: boolean = false;
  @Param rowKey: string = '';
  @Event onToggle: (value: boolean) => void = (value: boolean) => {
    console.info(`TODO:onToggle:FormSwitchRow ${value}`);
  };

  build() {
    Row() {
      Column() {
        Text(this.labelText)
          .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        if (this.hasDesc) {
          Column().height(2)
          Text(this.descText)
            .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurfaceVariant))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      Column().width(8)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(FeederTheme.colors.primary)
        .hitTestBehavior(HitTestMode.None)
        .focusable(false)
        .accessibilityLevel('no')
    }
    .id(this.rowKey)
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .accessibilityGroup(true)
    .accessibilityChecked(this.checked)
    .onClick(() => {
      this.onToggle(!this.checked);
    })
  }
}

/** 源 RadioButtonSetting(icon = null, minHeight = 48) */
@ComponentV2
export struct FormRadioRow {
  @Param labelText: ResourceStr = '';
  @Param isSelected: boolean = false;
  @Param groupName: string = 'editFeedOpener';
  @Param radioValue: string = '';
  @Event onSelect: () => void = () => {
    console.info('TODO:onSelect:FormRadioRow');
  };

  build() {
    Row() {
      Text(this.labelText)
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .layoutWeight(1)
      Column().width(8)
      Radio({ value: this.radioValue, group: this.groupName })
        .checked(this.isSelected)
        .radioStyle({ checkedBackgroundColor: FeederTheme.colors.primary })
        .hitTestBehavior(HitTestMode.None)
        .focusable(false)
        .accessibilityLevel('no')
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .accessibilityGroup(true)
    .accessibilitySelected(this.isSelected)
    .onClick(() => {
      this.onSelect();
    })
  }
}

/** 源 RulesField：多行、等宽、3–8 行、占位 `Title=(?i)sponsored`；回车插入换行；有误呈错误态并显示首个错误 */
@ComponentV2
export struct RulesFieldView {
  @Param labelText: ResourceStr = '';
  @Param supportText: ResourceStr = '';
  @Param value: string = '';
  @Param error: ArticleRuleError | null = null;
  @Event onValueChange: (value: string) => void = (value: string) => {
    console.info(`TODO:onValueChange:RulesFieldView ${value.length}`);
  };

  private errorText(): string {
    const err: ArticleRuleError | null = this.error;
    if (err === null) {
      return '';
    }
    return formatRuleError(this.getUIContext().getHostContext(), err);
  }

  build() {
    Column() {
      Text(this.labelText)
        .attributeModifier(textStyle(M3Type.bodySmall, false,
          this.error !== null ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant))
        .padding({ left: 4, bottom: 4 })
      TextArea({ text: this.value, placeholder: $r('app.string.article_rules_placeholder') })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.value))
        .fontFamily(monoFamily())
        .fontSize(16)
        .lineHeight(24)
        .fontColor(FeederTheme.colors.onSurface)
        .placeholderColor(FeederTheme.colors.onSurfaceVariant)
        .placeholderFont({ size: 16, family: monoFamily() })
        .caretColor(FeederTheme.colors.primary)
        .enterKeyType(EnterKeyType.NEW_LINE)
        .backgroundColor(Color.Transparent)
        .borderRadius(4)
        .border({
          width: this.error !== null ? 2 : 1,
          color: this.error !== null ? FeederTheme.colors.error : FeederTheme.colors.outline,
          radius: 4
        })
        .constraintSize({ minHeight: 3 * 24 + 32, maxHeight: 8 * 24 + 32 })
        .width('100%')
        .onChange((v: string) => {
          this.onValueChange(v);
        })
      if (this.error !== null) {
        Text(this.errorText())
          .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.error))
          .transition(TransitionEffect.OPACITY)
      }
      Text(this.supportText)
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
