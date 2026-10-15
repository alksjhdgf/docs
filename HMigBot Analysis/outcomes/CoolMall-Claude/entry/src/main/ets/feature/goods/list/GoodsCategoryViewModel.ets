/**
 * GoodsCategoryViewModel (source: feature/goods/viewmodel/GoodsCategoryViewModel.kt).
 *
 * - GOODS-A27: constructor reads GoodsCategoryParam — typeId (comma separated, invalid parts dropped) preselects
 *   the category filter, featured / recommend flags, keyword (search box initial text), minPrice (coupon jump).
 * - GOODS-A28: requestListData sends page/size(10) + only the non-empty conditions (typeId list, min/max price,
 *   keyWord, order(sold|price)/sort(asc|desc), recommend/featured only when true).
 * - GOODS-A29: onSortClick three-state cycle, every change refreshes from page 1.
 * - GOODS-A30: showFilters loads the category list only until it succeeds once (340 ms after opening, source
 *   delay(340) waiting for the open animation) and converts it to a tree (sortNum order, nested by parentId).
 * - GOODS-A31: applyFilters / resetFilters / hideFilters. GOODS-A32: isGridLayout (default grid).
 * - GOODS-A34: onSearch(keyword) re-queries with the keyword (blank → no keyword condition), no history write.
 */
import { BaseNetWorkListViewModel } from '../../../core/common/BaseNetWorkListViewModel';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { Category, CategoryTree, Goods } from '../../../core/model/Goods';
import { GoodsSearchRequest } from '../../../core/model/Request';
import { NetworkPageData, NetworkResponse } from '../../../core/model/Response';
import { GoodsCategoryParam } from '../../../core/navigation/RouteParams';
import { ResultHandler, ResultHandleOptions } from '../../../core/network/ResultHandler';
import { SortState } from './SortState';
import { SortType } from './SortType';

/** Source CategoryUiState: Loading / Success(data) / Error */
export type CategoryUiState = 'loading' | 'success' | 'error';

/** Source delay(340) before loading categories (filter dialog open animation) */
const FILTER_LOAD_DELAY_MS: number = 340;

/** Kotlin String.toLongOrNull(): optional sign + digits only */
const LONG_PATTERN: RegExp = new RegExp('^[+-]?\\d+$');

/** order / sort pair of a request (source `val (order, sort) = ...`) */
class SortCondition {
  order: string | null = null;
  sort: string | null = null;

  constructor(order: string | null, sort: string | null) {
    this.order = order;
    this.sort = sort;
  }
}

@ObservedV2
export class GoodsCategoryViewModel extends BaseNetWorkListViewModel<Goods> {
  /** Category (filter dialog) state */
  @Trace categoryUiState: CategoryUiState = 'loading';
  /** Category tree (Success data) */
  @Trace categoryTree: CategoryTree[] = [];
  /** Filter dialog visible */
  @Trace filtersVisible: boolean = false;
  /** Selected category ids */
  @Trace selectedCategoryIds: number[] = [];
  /** Minimum price */
  @Trace minPrice: string = '';
  /** Maximum price */
  @Trace maxPrice: string = '';
  /** Current sort type */
  @Trace currentSortType: SortType = SortType.COMPREHENSIVE;
  /** Current sort direction */
  @Trace currentSortState: SortState = SortState.NONE;
  /** Grid layout (default) or list */
  @Trace isGridLayout: boolean = true;

  private categoryDataLoaded: boolean = false;
  private searchKeyword: string = '';
  private isFeatured: boolean = false;
  private isRecommend: boolean = false;

  constructor(route: GoodsCategoryParam | null) {
    super();
    this.enableMinLoadingTime = true;
    if (route !== null) {
      const typeIdParam: string | null = route.typeId ?? null;
      if (typeIdParam !== null && typeIdParam.trim().length > 0) {
        const ids: number[] = [];
        for (const part of typeIdParam.split(',')) {
          const p = part.trim();
          if (LONG_PATTERN.test(p)) {
            ids.push(Number(p));
          }
        }
        this.selectedCategoryIds = ids;
      }
      this.isFeatured = route.featured === true;
      this.isRecommend = route.recommend === true;
      this.searchKeyword = route.keyword ?? '';
      const minPriceParam: string | null = route.minPrice ?? null;
      if (minPriceParam !== null) {
        this.minPrice = minPriceParam;
      }
    }
    this.initLoad();
  }

  /** Current search keyword (initial text of the page's search box) */
  getCurrentSearchKeyword(): string {
    return this.searchKeyword;
  }

  private sortCondition(): SortCondition {
    let field: string | null = null;
    if (this.currentSortType === SortType.SALES) {
      field = 'sold';
    } else if (this.currentSortType === SortType.PRICE) {
      field = 'price';
    }
    if (field === null) {
      return new SortCondition(null, null);
    }
    if (this.currentSortState === SortState.ASC) {
      return new SortCondition(field, 'asc');
    }
    if (this.currentSortState === SortState.DESC) {
      return new SortCondition(field, 'desc');
    }
    return new SortCondition(null, null);
  }

  /** Paged goods request; empty conditions are not sent (encodeDefaults = false / takeIf) */
  protected requestListData(): Promise<NetworkResponse<NetworkPageData<Goods>>> {
    const cond = this.sortCondition();
    const req = new GoodsSearchRequest();
    req.page = this.page;
    req.size = this.pageSize;
    if (this.isFeatured) {
      req.featured = true;
    }
    if (this.isRecommend) {
      req.recommend = true;
    }
    if (this.selectedCategoryIds.length > 0) {
      req.typeId = this.selectedCategoryIds.slice();
    }
    if (this.minPrice.trim().length > 0) {
      req.minPrice = this.minPrice;
    }
    if (this.maxPrice.trim().length > 0) {
      req.maxPrice = this.maxPrice;
    }
    if (cond.order !== null) {
      req.order = cond.order;
    }
    if (cond.sort !== null) {
      req.sort = cond.sort;
    }
    if (this.searchKeyword.trim().length > 0) {
      req.keyWord = this.searchKeyword;
    }
    return GoodsRepository.getGoodsPage(req);
  }

  /** Open the filter dialog; categories are loaded only until the first success */
  showFilters(): void {
    this.filtersVisible = true;
    if (this.categoryDataLoaded) {
      return;
    }
    this.schedule((): void => {
      this.loadGoodsCategory();
    }, FILTER_LOAD_DELAY_MS);
  }

  /** Close the filter dialog without applying */
  hideFilters(): void {
    this.filtersVisible = false;
  }

  /** Apply the dialog conditions, close it and refresh */
  applyFilters(categoryIds: number[], minPrice: string, maxPrice: string): void {
    this.selectedCategoryIds = categoryIds;
    this.minPrice = minPrice;
    this.maxPrice = maxPrice;
    this.hideFilters();
    this.onRefresh();
  }

  /** Clear the conditions and refresh (dialog stays open) */
  resetFilters(): void {
    this.selectedCategoryIds = [];
    this.minPrice = '';
    this.maxPrice = '';
    this.onRefresh();
  }

  /** Sort bar: 综合 clears; same item NONE → ASC → DESC → back to 综合; other item → ASC */
  onSortClick(sortType: SortType): void {
    if (sortType === SortType.COMPREHENSIVE) {
      this.currentSortType = SortType.COMPREHENSIVE;
      this.currentSortState = SortState.NONE;
    } else if (this.currentSortType === sortType) {
      if (this.currentSortState === SortState.NONE) {
        this.currentSortState = SortState.ASC;
      } else if (this.currentSortState === SortState.ASC) {
        this.currentSortState = SortState.DESC;
      } else {
        this.currentSortState = SortState.NONE;
      }
      if (this.currentSortState === SortState.NONE) {
        this.currentSortType = SortType.COMPREHENSIVE;
      }
    } else {
      this.currentSortType = sortType;
      this.currentSortState = SortState.ASC;
    }
    this.onRefresh();
  }

  /** Page search box: re-query with the keyword (no history write) */
  onSearch(keyword: string): void {
    this.searchKeyword = keyword;
    this.onRefresh();
  }

  /** Grid ↔ list */
  toggleLayoutMode(): void {
    this.isGridLayout = !this.isGridLayout;
  }

  private loadGoodsCategory(): void {
    if (this.disposed) {
      return;
    }
    const opts: ResultHandleOptions<Category[]> = {
      showToast: true,
      onLoading: (): void => {
        if (!this.disposed) {
          this.categoryUiState = 'loading';
        }
      },
      onSuccess: (data: Category[]): void => {
        if (this.disposed) {
          return;
        }
        this.categoryTree = GoodsCategoryViewModel.convertToTree(data);
        this.categoryUiState = 'success';
        this.categoryDataLoaded = true;
      },
      onError: (msg: string, err?: Error): void => {
        if (!this.disposed) {
          this.categoryUiState = 'error';
        }
      }
    };
    ResultHandler.handleAsync<Category[]>(GoodsRepository.getGoodsTypeList(), opts);
  }

  /** Category list → tree: sorted by sortNum, roots = parentId null, children grouped by parentId */
  static convertToTree(categories: Category[]): CategoryTree[] {
    const sorted: Category[] = categories.slice().sort((a: Category, b: Category): number =>
    (a.sortNum ?? 0) - (b.sortNum ?? 0));
    const roots: CategoryTree[] = [];
    const childrenMap: Map<number, CategoryTree[]> = new Map<number, CategoryTree[]>();
    for (const c of sorted) {
      const node = CategoryTree.fromCategory(c);
      const parentId: number | null = node.parentId ?? null;
      if (parentId === null) {
        roots.push(node);
      } else {
        let children: CategoryTree[] | undefined = childrenMap.get(parentId);
        if (children === undefined) {
          children = [];
          childrenMap.set(parentId, children);
        }
        children.push(node);
      }
    }
    return roots.map((root: CategoryTree): CategoryTree => GoodsCategoryViewModel.buildCategoryTree(root,
      childrenMap, 0));
  }

  private static buildCategoryTree(node: CategoryTree, childrenMap: Map<number, CategoryTree[]>,
    depth: number): CategoryTree {
    const children: CategoryTree[] = childrenMap.get(node.id) ?? [];
    // depth guard only protects against malformed cyclic data (source would overflow the stack)
    if (children.length === 0 || depth > 32) {
      return node;
    }
    const copy = new CategoryTree();
    copy.id = node.id;
    copy.name = node.name;
    copy.parentId = node.parentId;
    copy.sortNum = node.sortNum;
    copy.pic = node.pic;
    copy.status = node.status;
    copy.createTime = node.createTime;
    copy.updateTime = node.updateTime;
    copy.children = children.map((child: CategoryTree): CategoryTree => GoodsCategoryViewModel.buildCategoryTree(child,
      childrenMap, depth + 1));
    return copy;
  }
}
