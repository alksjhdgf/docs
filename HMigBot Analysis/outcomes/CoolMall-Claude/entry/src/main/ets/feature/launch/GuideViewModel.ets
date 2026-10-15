/**
 * GuideViewModel (source: feature/launch/viewmodel/GuideViewModel.kt).
 * fromSettings=false: write guide_shown=true then toMain (closes the guide page) (LAUNCH-A14);
 * fromSettings=true: only navigate back (LAUNCH-A16).
 */
import { AppNavigator } from '../../core/navigation/AppNavigator';
import { KvKeys, KvStore } from '../../core/storage/KvStore';
import { GuidePageData, GuidePageProvider } from './GuidePageData';

@ObservedV2
export class GuideViewModel {
  /** KEY_GUIDE_SHOWN = "guide_shown" */
  static readonly KEY_GUIDE_SHOWN: string = KvKeys.GUIDE_SHOWN;

  /** Entered from the settings page (route param LaunchRoutes.Guide.fromSettings) */
  isFromSettings: boolean = false;
  /** Guide pages */
  readonly guidePages: GuidePageData[] = GuidePageProvider.getGuidePages();
  /** Current page index */
  @Trace currentPageIndex: number = 0;

  setFromSettings(fromSettings: boolean): void {
    this.isFromSettings = fromSettings;
  }

  updatePageIndex(index: number): void {
    this.currentPageIndex = index;
  }

  /** true → caller scrolls to the next page; false → last page, experience started */
  handleNextClick(): boolean {
    if (this.isLastPage()) {
      this.startExperience();
      return false;
    }
    return true;
  }

  getNextPageIndex(): number {
    const next: number = this.currentPageIndex + 1;
    return next < this.guidePages.length ? next : this.currentPageIndex;
  }

  skipGuide(): void {
    this.startExperience();
  }

  isLastPage(): boolean {
    return this.currentPageIndex === this.guidePages.length - 1;
  }

  private startExperience(): void {
    if (this.isFromSettings) {
      AppNavigator.back();
    } else {
      this.markGuideAsShown();
      AppNavigator.toMain();
    }
  }

  private markGuideAsShown(): void {
    KvStore.putBoolean(GuideViewModel.KEY_GUIDE_SHOWN, true);
  }
}
