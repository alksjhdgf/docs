/**
 * Marketing / user-service models (source: core/model/entity/Coupon.kt, DictItem.kt, Feedback.kt,
 * UserContributor.kt, Address.kt, Captcha.kt, OssUpload.kt, Footprint.kt, SearchHistory.kt)
 */
import { Condition } from './Goods';

/**
 * Coupon.
 * The server may send `condition` either as an object or as a JSON string (source ConditionSerializer);
 * call Coupon.normalize / Coupon.normalizeList after JSON.parse to get a Condition object (or null).
 */
export class Coupon {
  id: number = 0;
  title: string = '';
  description: string = '';
  /** 0 full reduction */
  type: number = 0;
  amount: number = 0;
  num: number = 0;
  receivedNum: number = 0;
  startTime: string | null = null;
  endTime: string | null = null;
  /** 0 disabled, 1 enabled */
  status: number = 0;
  condition: Condition | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
  /** 0 unused, 1 used, 2 expired; only returned by "my coupons" API */
  useStatus: number | null = null;

  /** Parse a raw condition value (object | JSON string | blank) like the source ConditionSerializer */
  static parseCondition(raw: Object | null | undefined): Condition | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    try {
      if (typeof raw === 'string') {
        const s = (raw as string).trim();
        if (s.length === 0) {
          return null;
        }
        const parsed = JSON.parse(s) as Condition;
        const c = new Condition();
        c.fullAmount = Number(parsed.fullAmount ?? 0);
        return c;
      }
      const obj = raw as Condition;
      const c = new Condition();
      c.fullAmount = Number(obj.fullAmount ?? 0);
      return c;
    } catch (e) {
      return null;
    }
  }

  /** Normalize `condition` in place (string → Condition object) and return the same coupon */
  static normalize(coupon: Coupon): Coupon {
    coupon.condition = Coupon.parseCondition(coupon.condition as Object | null);
    return coupon;
  }

  /** Normalize a coupon list in place; null/undefined → [] */
  static normalizeList(list: Coupon[] | null | undefined): Coupon[] {
    if (list === null || list === undefined) {
      return [];
    }
    list.forEach((c: Coupon) => {
      Coupon.normalize(c);
    });
    return list;
  }
}

/** Dictionary item */
export class DictItem {
  typeId: number | null = 0;
  parentId: number | null = 0;
  name: string | null = '';
  id: number | null = 0;
  value: number | null = 0;
}

/** Feedback */
export class Feedback {
  id: number = 0;
  userId: number = 0;
  contact: string = '';
  type: number = 0;
  content: string = '';
  images: string[] | null = null;
  /** 0 unhandled, 1 handled */
  status: number = 0;
  handlerId: number | null = null;
  remark: string | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** User contributor */
export class UserContributor {
  id: number = 0;
  avatarUrl: string = '';
  nickName: string = '';
  /** GitHub / Gitee / blog url */
  websiteUrl: string | null = null;
  signature: string | null = null;
  tags: string[] | null = null;
  sortNum: number = 0;
  /** 1 enabled, 2 disabled */
  status: number = 1;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** User shipping address */
export class Address {
  id: number = 0;
  userId: number = 0;
  contact: string = '';
  phone: string = '';
  province: string = '';
  city: string = '';
  district: string = '';
  address: string = '';
  /** always serialized (source @EncodeDefault(ALWAYS)) */
  isDefault: boolean = false;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/**
 * Outbound wire form of Address (add/update address body).
 * Mirrors kotlinx encodeDefaults=false: fields equal to their default are left undefined so
 * JSON.stringify omits them; isDefault is always sent. Build with AddressBody.from(address).
 */
export class AddressBody {
  id?: number;
  userId?: number;
  contact?: string;
  phone?: string;
  province?: string;
  city?: string;
  district?: string;
  address?: string;
  isDefault: boolean = false;
  createTime?: string;
  updateTime?: string;

  static from(a: Address): AddressBody {
    const b = new AddressBody();
    if (a.id !== 0) {
      b.id = a.id;
    }
    if (a.userId !== 0) {
      b.userId = a.userId;
    }
    if (a.contact !== '') {
      b.contact = a.contact;
    }
    if (a.phone !== '') {
      b.phone = a.phone;
    }
    if (a.province !== '') {
      b.province = a.province;
    }
    if (a.city !== '') {
      b.city = a.city;
    }
    if (a.district !== '') {
      b.district = a.district;
    }
    if (a.address !== '') {
      b.address = a.address;
    }
    b.isDefault = a.isDefault === true;
    if (a.createTime !== null && a.createTime !== undefined) {
      b.createTime = a.createTime;
    }
    if (a.updateTime !== null && a.updateTime !== undefined) {
      b.updateTime = a.updateTime;
    }
    return b;
  }
}

/** Image captcha */
export class Captcha {
  /** base64 encoded captcha image */
  data: string = '';
  captchaId: string = '';
}

/** Tencent COS temporary credentials */
export class TencentCredentials {
  tmpSecretId: string | null = null;
  tmpSecretKey: string | null = null;
  sessionToken: string | null = null;
}

/** OSS upload config */
export class OssUpload {
  credentials: TencentCredentials | null = null;
  requestId: string | null = null;
  expiration: string | null = null;
  startTime: number | null = null;
  expiredTime: number | null = null;
  url: string | null = null;
}

/** Browsing footprint (local storage) */
export class Footprint {
  goodsId: number = 0;
  goodsName: string = '';
  goodsSubTitle: string | null = null;
  goodsMainPic: string = '';
  goodsPrice: number = 0;
  goodsSold: number = 0;
  viewTime: number = Date.now();
}

/** Search history (local storage) */
export class SearchHistory {
  keyword: string = '';
  searchTime: number = Date.now();
}
