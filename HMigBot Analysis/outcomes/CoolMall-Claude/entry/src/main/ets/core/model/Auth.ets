/**
 * Auth token model (source: core/model/entity/Auth.kt)
 *
 * NOTE: `JSON.parse(..) as Auth` yields a plain object without methods; use the
 * static helpers (Auth.isExpired(a) etc.) or Auth.from(obj) to get a real instance.
 */
export class Auth {
  /** token */
  token: string = '';
  /** refresh token */
  refreshToken: string = '';
  /** token expire time (seconds) */
  expire: number = 0;
  /** refresh token expire time (seconds) */
  refreshExpire: number = 0;
  /** token created time in ms (client side, not from server) */
  createdAt: number = Date.now();

  /** Build a real Auth instance from a parsed plain object (missing fields keep defaults). */
  static from(obj: Auth | null | undefined): Auth {
    const a = new Auth();
    if (obj === null || obj === undefined) {
      return a;
    }
    if (obj.token !== null && obj.token !== undefined) {
      a.token = obj.token;
    }
    if (obj.refreshToken !== null && obj.refreshToken !== undefined) {
      a.refreshToken = obj.refreshToken;
    }
    if (obj.expire !== null && obj.expire !== undefined) {
      a.expire = obj.expire;
    }
    if (obj.refreshExpire !== null && obj.refreshExpire !== undefined) {
      a.refreshExpire = obj.refreshExpire;
    }
    if (obj.createdAt !== null && obj.createdAt !== undefined) {
      a.createdAt = obj.createdAt;
    }
    return a;
  }

  /** Whether the token is expired (now >= createdAt + expire*1000) */
  static checkExpired(a: Auth): boolean {
    return Date.now() >= a.createdAt + a.expire * 1000;
  }

  /** Whether the refresh token is expired (now >= createdAt + refreshExpire*1000) */
  static checkRefreshTokenExpired(a: Auth): boolean {
    return Date.now() >= a.createdAt + a.refreshExpire * 1000;
  }

  /** Should refresh: within 15 minutes before token expiry and refresh token still valid */
  static checkShouldRefresh(a: Auth): boolean {
    const refreshTime = a.createdAt + a.expire * 1000 - 15 * 60 * 1000;
    return Date.now() >= refreshTime && !Auth.checkRefreshTokenExpired(a);
  }

  isExpired(): boolean {
    return Auth.checkExpired(this);
  }

  isRefreshTokenExpired(): boolean {
    return Auth.checkRefreshTokenExpired(this);
  }

  shouldRefresh(): boolean {
    return Auth.checkShouldRefresh(this);
  }
}
