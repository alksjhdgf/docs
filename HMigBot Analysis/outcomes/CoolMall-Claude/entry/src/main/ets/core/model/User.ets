/**
 * User model (source: core/model/entity/User.kt)
 */
export class User {
  id: number = 0;
  unionid: string = '';
  avatarUrl: string | null = null;
  nickName: string | null = null;
  phone: string | null = null;
  /** 0 unknown, 1 male, 2 female */
  gender: number = 0;
  /** 0 disabled, 1 normal, 2 deregistered */
  status: number = 1;
  /** 0 mini program, 1 official account, 2 H5 */
  loginType: string = '0';
  password: string | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}
