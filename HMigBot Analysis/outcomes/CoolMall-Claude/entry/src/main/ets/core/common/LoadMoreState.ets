/**
 * LoadMoreState (source: core/common/base/state/LoadMoreState.kt).
 */
export enum LoadMoreState {
  /** Can pull/scroll to load more */
  PullToLoad = 0,
  /** Loading */
  Loading = 1,
  /** Load succeeded (shown briefly before the data is appended) */
  Success = 2,
  /** Load failed (tap to retry) */
  Error = 3,
  /** No more data */
  NoMore = 4
}
