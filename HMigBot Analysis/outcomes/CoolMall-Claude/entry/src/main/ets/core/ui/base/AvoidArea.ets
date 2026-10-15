/**
 * AvoidArea — window safe-area insets for the edge-to-edge layout (source: MainActivity.enableEdgeToEdge()
 * + per-page WindowInsets handling; LAUNCH-A23).
 *
 * Written ONLY by the window layer (EntryAbility.onWindowStageCreate + avoidAreaChange):
 *   top    = status bar height (window.AvoidAreaType.TYPE_SYSTEM, topRect.height) in vp
 *   bottom = navigation indicator height (window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR, bottomRect.height) in vp
 * Pages only read these values and pad manually (do not call expandSafeArea).
 *
 * Usage in a V2 component:
 *   @Local avoidArea: AvoidArea = AvoidArea.get();
 *   Column() { ... }.padding({ top: this.avoidArea.top, bottom: this.avoidArea.bottom })
 */
import { AppStorageV2 } from '@kit.ArkUI';

@ObservedV2
export class AvoidArea {
  /** Status bar height (vp) */
  @Trace top: number = 0;
  /** Bottom navigation indicator / navigation bar height (vp) */
  @Trace bottom: number = 0;

  /** The global AvoidArea instance stored in AppStorageV2 (created on first access). */
  static get(): AvoidArea {
    const area: AvoidArea | undefined = AppStorageV2.connect<AvoidArea>(AvoidArea, (): AvoidArea => new AvoidArea());
    return area !== undefined ? area : new AvoidArea();
  }
}
