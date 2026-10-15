/**
 * AboutViewModel (source: feature/common/viewmodel/AboutViewModel.kt).
 * Holds the `引用致谢` sheet visibility and the dependency list.
 */
import { CommonNavigator } from './CommonNavigator';
import { Dependency } from './Dependency';
import { DependencyDataSource } from './DependencyDataSource';

@ObservedV2
export class AboutViewModel {
  /** Dependency sheet visibility (source showDependencyModal) */
  @Trace showDependencyModal: boolean = false;
  /** Dependency list (source dependencies) */
  readonly dependencies: Dependency[] = DependencyDataSource.getAllDependencies();

  /** `引用` tapped: show the sheet */
  onCitationClick(): void {
    this.showDependencyModal = true;
  }

  /** Sheet dismissed */
  onDismissDependencyModal(): void {
    this.showDependencyModal = false;
  }

  /** Dependency tapped: open its website (when set) in the Web page, then close the sheet */
  onDependencyClick(dependency: Dependency): void {
    if (dependency.websiteUrl.length > 0) {
      CommonNavigator.toWeb(dependency.websiteUrl, dependency.name);
    }
    this.showDependencyModal = false;
  }
}
