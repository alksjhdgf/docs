/**
 * FootprintUiState (source: feature/user/state/FootprintUiState.kt — sealed Loading / Success / Empty).
 */
export enum FootprintUiState {
  /** Loading (initial value before the first query result) */
  Loading = 0,
  /** Has footprints */
  Success = 1,
  /** No footprints */
  Empty = 2
}
