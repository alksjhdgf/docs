/**
 * Goods domain models (source: core/model/entity/Goods.kt, GoodsSpec.kt, GoodsDetail.kt,
 * GoodsSearchKeyword.kt, Category.kt, CategoryTree.kt, Comment.kt, Banner.kt, Home.kt, Condition.kt)
 */
import { Coupon } from './Market';

/** Goods spec */
export class GoodsSpec {
  id: number = 0;
  goodsId: number = 0;
  name: string = '';
  /** price (integer, yuan) */
  price: number = 0;
  stock: number = 0;
  sortNum: number = 0;
  images: string[] | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Goods */
export class Goods {
  id: number = 0;
  typeId: number = 0;
  title: string = '';
  subTitle: string | null = null;
  mainPic: string = '';
  pics: string[] | null = null;
  price: number = 0;
  sold: number = 0;
  /** rich text detail (deprecated) */
  content: string | null = null;
  contentPics: string[] | null = null;
  recommend: boolean = false;
  featured: boolean = false;
  /** 0 off shelf, 1 on shelf */
  status: number = 0;
  sortNum: number = 0;
  specs: GoodsSpec[] | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Goods comment */
export class Comment {
  id: number = 0;
  userId: number = 0;
  goodsId: number = 0;
  orderId: number = 0;
  content: string = '';
  starCount: number = 5;
  pics: string[] | null = null;
  nickName: string | null = null;
  avatarUrl: string | null = null;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Goods detail */
export class GoodsDetail {
  goodsInfo: Goods = new Goods();
  coupon: Coupon[] = [];
  comment: Comment[] = [];
}

/** Goods search keyword */
export class GoodsSearchKeyword {
  id: number = 0;
  name: string = '';
  sortNum: number = 0;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Goods category */
export class Category {
  id: number = 0;
  name: string = '';
  parentId: number | null = null;
  sortNum: number = 0;
  pic: string | null = null;
  /** 0 disabled, 1 enabled */
  status: number = 1;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Category tree node (client side, not serialized in source) */
export class CategoryTree {
  id: number = 0;
  name: string = '';
  parentId: number | null = null;
  sortNum: number = 0;
  pic: string | null = null;
  status: number = 0;
  createTime: string | null = null;
  updateTime: string | null = null;
  children: CategoryTree[] = [];

  /** Create a tree node (without children) from a Category */
  static fromCategory(category: Category): CategoryTree {
    const t = new CategoryTree();
    t.id = category.id;
    t.name = category.name;
    t.parentId = category.parentId ?? null;
    t.sortNum = category.sortNum;
    t.pic = category.pic ?? null;
    t.status = category.status;
    t.createTime = category.createTime ?? null;
    t.updateTime = category.updateTime ?? null;
    return t;
  }
}

/** Banner */
export class Banner {
  id: number = 0;
  description: string = '';
  /** jump path */
  path: string = '';
  pic: string = '';
  sortNum: number = 0;
  /** 1 enabled, 2 disabled */
  status: number = 1;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Home page data */
export class Home {
  banner: Banner[] | null = null;
  category: Category[] | null = null;
  categoryAll: Category[] | null = null;
  flashSale: Goods[] | null = null;
  recommend: Goods[] | null = null;
  coupon: Coupon[] | null = null;
  goods: Goods[] | null = null;
}

/** Coupon usage condition */
export class Condition {
  /** minimum order amount */
  fullAmount: number = 0;
}
