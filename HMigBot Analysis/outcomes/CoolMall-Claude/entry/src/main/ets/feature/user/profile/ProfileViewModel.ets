/**
 * ProfileViewModel (source: feature/user/viewmodel/ProfileViewModel.kt).
 *
 * - isLoggedIn / userInfo: read straight from the AppState singleton (@Trace; source StateFlows).
 * - init: logged in but no cached user info → AppState.refreshUserInfo() once (USER-A07).
 * - logout(): AppState.logout() (clears `auth_info` / `user_info`, isLoggedIn = false; no server call),
 *   then navigateBack() (USER-A06).
 */
import { AppState } from '../../../core/data/AppState';
import { User } from '../../../core/model/User';
import { AppNavigator } from '../../../core/navigation/AppNavigator';

export class ProfileViewModel {
  constructor() {
    const appState = AppState.instance;
    appState.ensureInitialized();
    // source init: if (isLoggedIn.value && userInfo.value == null) appState.refreshUserInfo()
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

  /** Logout: clear local auth + user info, then go back (source logout()) */
  async logout(): Promise<void> {
    await AppState.instance.logout();
    AppNavigator.back();
  }
}
