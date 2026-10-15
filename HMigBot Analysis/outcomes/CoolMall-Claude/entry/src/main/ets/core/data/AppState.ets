/**
 * AppState — global app state singleton (source: core/data/state/AppState.kt).
 *
 * - isLoggedIn / userId / auth / userInfo are @Trace fields (source StateFlows); pages only read them.
 * - initialize() restores from KvStore SYNCHRONOUSLY (source launches a coroutine; here preferences are
 *   read with getSync so the login wall decides correctly on the very first route) — DATA-A10, LAUNCH-A19.
 * - updateUserState(auth, user): persist + memory, isLoggedIn = true — DATA-A11.
 * - logout(): removes only `auth_info` / `user_info`, resets memory (userId = 0); no server call; cart,
 *   footprints, search history and remembered account are kept — DATA-A12, LAUNCH-A21.
 * - refreshUserInfo(): GET user/info/person when logged in, then updateUserInfo(data).
 * - Registers HttpClient's token provider (raw `auth_info` token read from storage per request, like the
 *   source AuthInterceptor's runBlocking getToken()) — DATA-A03.
 *
 * Mutators are `async` only to mirror the source `suspend` signatures: their whole body runs
 * synchronously, so state is already updated when the call returns (awaiting is optional).
 */
import { Auth } from '../model/Auth';
import { User } from '../model/User';
import { HttpClient } from '../network/HttpClient';
import { ResultHandler, ResultHandleOptions } from '../network/ResultHandler';
import { KvStore } from '../storage/KvStore';
import { LogUtils } from '../util/LogUtils';
import { AuthStoreRepository } from './repository/AuthStoreRepository';
import { UserInfoStoreRepository } from './repository/UserInfoStoreRepository';
import { UserInfoRepository } from './repository/UserInfoRepository';

const TAG: string = 'AppState';

@ObservedV2
export class AppState {
  /** Global singleton (source @Singleton) */
  static readonly instance: AppState = new AppState();

  /** User login state */
  @Trace isLoggedIn: boolean = false;
  /** User id (0 when unknown / logged out) */
  @Trace userId: number = 0;
  /** Auth info (token etc.) */
  @Trace auth: Auth | null = null;
  /** User info */
  @Trace userInfo: User | null = null;

  private initialized: boolean = false;

  constructor() {
    AppState.registerTokenProvider();
  }

  /** Inject the Authorization token source into HttpClient (raw token, '' when none) */
  static registerTokenProvider(): void {
    HttpClient.setTokenProvider((): string => {
      const token = AuthStoreRepository.getToken();
      return token === null ? '' : token;
    });
  }

  /**
   * Initialize app state from local storage (call from EntryAbility.onCreate after KvStore.init).
   * Synchronous: when it returns, isLoggedIn/auth/userInfo/userId reflect persisted data.
   */
  initialize(): void {
    if (!KvStore.isInitialized()) {
      LogUtils.eTag(TAG, 'initialize() called before KvStore.init(ctx); login state not restored');
      return;
    }
    AppState.registerTokenProvider();
    const authData = AuthStoreRepository.getAuth();
    const loggedIn = AuthStoreRepository.isLoggedIn();
    this.isLoggedIn = loggedIn;
    this.auth = authData;
    // Only load user info when logged in (source initializeState)
    if (loggedIn) {
      const user = UserInfoStoreRepository.getUserInfo();
      this.userInfo = user;
      this.userId = user === null ? 0 : user.id;
    }
    this.initialized = true;
  }

  /** initialize() once if it has not run yet (safety net for early readers such as the login wall) */
  ensureInitialized(): void {
    if (!this.initialized && KvStore.isInitialized()) {
      this.initialize();
    }
  }

  /** Whether initialize() has completed */
  isInitialized(): boolean {
    return this.initialized;
  }

  /** Update login state after a successful login: persist auth + user, then memory (DATA-A11) */
  async updateUserState(auth: Auth, user: User): Promise<void> {
    AuthStoreRepository.saveAuth(auth);
    UserInfoStoreRepository.saveUserInfo(user);

    this.auth = auth;
    this.userInfo = user;
    this.userId = user.id;
    this.isLoggedIn = true;
  }

  /** Update user info: persist, then memory */
  async updateUserInfo(user: User): Promise<void> {
    UserInfoStoreRepository.saveUserInfo(user);

    this.userInfo = user;
    this.userId = user.id;
  }

  /** Update auth info (e.g. token refresh): persist, memory, isLoggedIn = true */
  async updateAuth(auth: Auth): Promise<void> {
    AuthStoreRepository.saveAuth(auth);

    this.auth = auth;
    this.isLoggedIn = true;
  }

  /** Logout: clear `auth_info` + `user_info` and reset memory state (DATA-A12) */
  async logout(): Promise<void> {
    AuthStoreRepository.clearAuth();
    UserInfoStoreRepository.clearUserInfo();

    this.isLoggedIn = false;
    this.auth = null;
    this.userInfo = null;
    this.userId = 0;
  }

  /** Whether the token should be refreshed (defined but never called in source) */
  async shouldRefreshToken(): Promise<boolean> {
    return AuthStoreRepository.shouldRefreshToken();
  }

  /** Fetch the latest user info (GET user/info/person) and update state; no-op when logged out */
  refreshUserInfo(): void {
    if (!this.isLoggedIn) {
      return;
    }
    // Source handleResultWithData defaults: showToast = true
    const opts: ResultHandleOptions<User> = {
      showToast: true,
      onSuccess: (data: User): void => {
        this.updateUserInfo(UserInfoStoreRepository.toUser(data));
      }
    };
    ResultHandler.handleAsync<User>(UserInfoRepository.getPersonInfo(), opts);
  }
}
