/**
 * SortType (source: feature/goods/model/SortType.kt) — sort bar item of the category goods list.
 */
export enum SortType {
  /** 综合 (no sort condition) */
  COMPREHENSIVE = 0,
  /** 销量 (order = sold) */
  SALES = 1,
  /** 价格 (order = price) */
  PRICE = 2
}
