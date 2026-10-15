/**
 * MeViewModel — "我的" tab view model (source: feature/main/viewmodel/MeViewModel.kt).
 *
 * - isLoggedIn / userInfo: read straight from the AppState singleton (@Trace, source StateFlows).
 * - recentFootprints: latest 8 footprints (viewTime DESC), queried once and re-queried after every
 *   FootprintDao write (Room Flow equivalent, J3) — MAIN-A27.
 * - init: logged in but no cached user info → AppState.refreshUserInfo() — MAIN-A24.
 * - onResume(): getUserOrderStatistics() — logged in: GET order/info/userCount; otherwise reset to 0 — MAIN-A24.
 * - dispose(): unsubscribe the footprint observer; late callbacks never touch state (A2.4).
 */
import { AppState } from '../../../core/data/AppState';
import { FootprintRepository } from '../../../core/data/repository/FootprintRepository';
import { OrderRepository } from '../../../core/data/repository/OrderRepository';
import { Footprint } from '../../../core/model/Market';
import { OrderCount } from '../../../core/model/Order';
import { User } from '../../../core/model/User';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';

@ObservedV2
export class MeViewModel {
  /** Latest 8 footprints (source recentFootprints, initial emptyList()) */
  @Trace recentFootprints: Footprint[] = [];
  /** Order statistics (source _orderCount, initial null) */
  @Trace orderCount: OrderCount | null = null;

  private footprintObserverId: number = -1;
  private disposed: boolean = false;

  constructor() {
    // source: recentFootprints = footprintRepository.getRecentFootprints(8).stateIn(...)
    this.footprintObserverId = FootprintRepository.observeRecentFootprints(FootprintRepository.ME_RECENT_LIMIT,
      (list: Footprint[]): void => {
        if (!this.disposed) {
          this.recentFootprints = list;
        }
      });
    // source init: refresh user info when logged in but no user info is cached
    const appState = AppState.instance;
    appState.ensureInitialized();
    if (appState.isLoggedIn && appState.userInfo === null) {
      appState.refreshUserInfo();
    }
  }

  /** User login state (source isLoggedIn) */
  get isLoggedIn(): boolean {
    return AppState.instance.isLoggedIn;
  }

  /** User info (source userInfo) */
  get userInfo(): User | null {
    return AppState.instance.userInfo;
  }

  /** Lifecycle onResume (source DefaultLifecycleObserver.onResume) */
  onResume(): void {
    this.getUserOrderStatistics();
  }

  /** User order statistics: only requested when logged in, otherwise cleared (all 0) */
  getUserOrderStatistics(): void {
    if (!AppState.instance.isLoggedIn) {
      this.orderCount = new OrderCount();
      return;
    }
    // source handleResultWithData defaults: showToast = true
    const opts: ResultHandleOptions<OrderCount> = {
      showToast: true,
      onSuccess: (data: OrderCount): void => {
        if (!this.disposed) {
          this.orderCount = data;
        }
      }
    };
    ResultHandler.handleAsync<OrderCount>(OrderRepository.getUserOrderCount(), opts);
  }

  /** Release the footprint subscription (source viewModelScope cancellation) */
  dispose(): void {
    this.disposed = true;
    if (this.footprintObserverId >= 0) {
      FootprintRepository.unsubscribe(this.footprintObserverId);
      this.footprintObserverId = -1;
    }
  }
}
