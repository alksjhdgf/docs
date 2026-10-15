/**
 * AuthStoreRepository (source: core/data/repository/AuthStoreRepository.kt +
 * core/datastore/datasource/auth/AuthStoreDataSourceImpl.kt).
 *
 * Login credentials are stored as JSON under KV key `auth_info` (DATA-A07).
 * Logged in = auth exists, token non-empty and not expired (createdAt + expire seconds) (DATA-A08).
 * Synchronous (KvStore is synchronous) so AppState can restore before the first route decision.
 */
import { Auth } from '../../model/Auth';
import { KvKeys, KvStore } from '../../storage/KvStore';

export class AuthStoreRepository {
  /** saveAuth: encode to JSON and store under `auth_info` */
  static saveAuth(auth: Auth): void {
    KvStore.putString(KvKeys.AUTH_INFO, JSON.stringify(auth));
  }

  /** getAuth: empty / unparsable → null; otherwise a real Auth instance */
  static getAuth(): Auth | null {
    const obj = KvStore.getObject<Auth>(KvKeys.AUTH_INFO);
    if (obj === null || obj === undefined) {
      return null;
    }
    return Auth.from(obj);
  }

  /** getToken: raw token of the stored auth (regardless of expiry, as in source) or null */
  static getToken(): string | null {
    const a = AuthStoreRepository.getAuth();
    return a === null ? null : a.token;
  }

  /** clearAuth: remove `auth_info` */
  static clearAuth(): void {
    KvStore.remove(KvKeys.AUTH_INFO);
  }

  /** isLoggedIn: auth exists, not expired, token non-empty */
  static isLoggedIn(): boolean {
    const a = AuthStoreRepository.getAuth();
    if (a === null) {
      return false;
    }
    return !Auth.checkExpired(a) && a.token.length > 0;
  }

  /** shouldRefreshToken: within 15 min of expiry and refresh token still valid (never called in source) */
  static shouldRefreshToken(): boolean {
    const a = AuthStoreRepository.getAuth();
    if (a === null) {
      return false;
    }
    return Auth.checkShouldRefresh(a);
  }
}
