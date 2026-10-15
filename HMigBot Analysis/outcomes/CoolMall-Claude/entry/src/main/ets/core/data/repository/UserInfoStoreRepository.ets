/**
 * UserInfoStoreRepository (source: core/data/repository/UserInfoStoreRepository.kt +
 * core/datastore/datasource/userinfo/UserInfoStoreDataSourceImpl.kt).
 *
 * User info is stored as JSON under KV key `user_info` (DATA-A09). Synchronous (KvStore is synchronous).
 */
import { User } from '../../model/User';
import { KvKeys, KvStore } from '../../storage/KvStore';
import { LogUtils } from '../../util/LogUtils';

const TAG: string = 'UserInfoStoreRepository';

/** Value types accepted by updateUserInfo (source Map<String, Any?>: String/Number/Boolean/null) */
export type UserInfoUpdateValue = string | number | boolean | null;

export class UserInfoStoreRepository {
  /** saveUserInfo: encode to JSON and store under `user_info` */
  static saveUserInfo(user: User): void {
    KvStore.putString(KvKeys.USER_INFO, JSON.stringify(user));
  }

  /** getUserInfo: empty / unparsable → null; otherwise a real User instance (missing fields keep defaults) */
  static getUserInfo(): User | null {
    const obj = KvStore.getObject<User>(KvKeys.USER_INFO);
    if (obj === null || obj === undefined) {
      return null;
    }
    return UserInfoStoreRepository.toUser(obj);
  }

  /**
   * updateUserInfo: partial update of the stored JSON (field merge). String/number/boolean values
   * overwrite, null removes the key. No-op when nothing is stored. Memory state (AppState) is NOT
   * touched, same as source.
   */
  static updateUserInfo(updates: Map<string, UserInfoUpdateValue>): void {
    if (UserInfoStoreRepository.getUserInfo() === null) {
      return;
    }
    const json = KvStore.getString(KvKeys.USER_INFO, '');
    if (json.length === 0) {
      return;
    }
    try {
      const current = JSON.parse(json) as Record<string, Object | null>;
      const merged: Record<string, Object | null> = {};
      const keys: string[] = Object.keys(current);
      for (const k of keys) {
        if (updates.has(k) && updates.get(k) === null) {
          continue;
        }
        merged[k] = current[k];
      }
      updates.forEach((value: UserInfoUpdateValue, key: string) => {
        if (value !== null) {
          merged[key] = value as Object;
        }
      });
      KvStore.putString(KvKeys.USER_INFO, JSON.stringify(merged));
    } catch (e) {
      // Source: on failure keep the original data
      LogUtils.wTag(TAG, 'updateUserInfo failed, original data kept');
    }
  }

  /** clearUserInfo: remove `user_info` */
  static clearUserInfo(): void {
    KvStore.remove(KvKeys.USER_INFO);
  }

  static getUserId(): number {
    const u = UserInfoStoreRepository.getUserInfo();
    return u === null ? 0 : u.id;
  }

  static getNickName(): string | null {
    const u = UserInfoStoreRepository.getUserInfo();
    return u === null ? null : u.nickName;
  }

  static getAvatarUrl(): string | null {
    const u = UserInfoStoreRepository.getUserInfo();
    return u === null ? null : u.avatarUrl;
  }

  /** Build a real User instance from a parsed plain object (missing fields keep source defaults) */
  static toUser(obj: User): User {
    const u = new User();
    if (obj.id !== null && obj.id !== undefined) {
      u.id = Number(obj.id);
    }
    if (obj.unionid !== null && obj.unionid !== undefined) {
      u.unionid = obj.unionid;
    }
    if (obj.avatarUrl !== undefined) {
      u.avatarUrl = obj.avatarUrl;
    }
    if (obj.nickName !== undefined) {
      u.nickName = obj.nickName;
    }
    if (obj.phone !== undefined) {
      u.phone = obj.phone;
    }
    if (obj.gender !== null && obj.gender !== undefined) {
      u.gender = obj.gender;
    }
    if (obj.status !== null && obj.status !== undefined) {
      u.status = obj.status;
    }
    if (obj.loginType !== null && obj.loginType !== undefined) {
      u.loginType = obj.loginType;
    }
    if (obj.password !== undefined) {
      u.password = obj.password;
    }
    if (obj.createTime !== undefined) {
      u.createTime = obj.createTime;
    }
    if (obj.updateTime !== undefined) {
      u.updateTime = obj.updateTime;
    }
    return u;
  }
}
