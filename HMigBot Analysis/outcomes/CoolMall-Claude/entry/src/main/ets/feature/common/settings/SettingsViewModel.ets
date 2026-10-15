/**
 * SettingsViewModel (source: feature/common/viewmodel/SettingsViewModel.kt).
 * themeMode / themeColor come straight from ThemeManager (ThemePreferenceManager equivalent);
 * this VM only owns the two bottom-sheet visibility flags.
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { ThemeMode } from '../../../core/designsystem/ThemePreference';
import { ThemeColorOption } from '../../../core/designsystem/ThemeColorOption';

@ObservedV2
export class SettingsViewModel {
  /** 主题模式弹窗 */
  @Trace showThemeModal: boolean = false;
  /** 主题颜色弹窗 */
  @Trace showThemeColorModal: boolean = false;

  /** 显示主题选择弹窗 */
  onDarkModeClick(): void {
    this.showThemeModal = true;
  }

  /** 隐藏主题选择弹窗 */
  dismissThemeModal(): void {
    this.showThemeModal = false;
  }

  /** 选择主题（ThemeManager.setMode 自身对未变化的值不做处理） */
  onThemeModeSelected(mode: ThemeMode): void {
    ThemeManager.instance.setMode(mode);
    this.dismissThemeModal();
  }

  /** 显示主题颜色选择弹窗 */
  onThemeColorClick(): void {
    this.showThemeColorModal = true;
  }

  /** 隐藏主题颜色弹窗 */
  dismissThemeColorModal(): void {
    this.showThemeColorModal = false;
  }

  /** 选择主题颜色 */
  onThemeColorSelected(option: ThemeColorOption): void {
    ThemeManager.instance.setColor(option.storageValue);
    this.dismissThemeColorModal();
  }
}
