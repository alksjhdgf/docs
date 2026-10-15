/**
 * CategoryViewModel (source: feature/main/viewmodel/CategoryViewModel.kt).
 *
 * - Requests goods/type/list once (executeRequest from the tab's aboutToAppear), minimum loading 320 ms.
 * - Converts the flat Category list into a CategoryTree list: sorted by sortNum (stable), items with
 *   parentId == null are roots, the rest attach to their parent (recursive).
 * - selectedCategoryIndex: the selected first-level category on the left (default 0).
 */
import { BaseNetWorkViewModel } from '../../../core/common/BaseNetWorkViewModel';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { Category, CategoryTree } from '../../../core/model/Goods';
import { NetworkResponse } from '../../../core/model/Response';

@ObservedV2
export class CategoryViewModel extends BaseNetWorkViewModel<CategoryTree[]> {
  /** Currently selected left (first-level) category index */
  @Trace selectedCategoryIndex: number = 0;

  constructor() {
    super();
    this.enableMinLoadingTime = true;
  }

  /** Category request: map the flat list into a tree (source requestApiFlow) */
  protected requestApiFlow(): Promise<NetworkResponse<CategoryTree[]>> {
    return GoodsRepository.getGoodsTypeList().then((response: NetworkResponse<Category[]>): NetworkResponse<CategoryTree[]> => {
      const mapped = new NetworkResponse<CategoryTree[]>();
      const list: Category[] | null | undefined = response?.data;
      mapped.data = (list !== null && list !== undefined) ? CategoryViewModel.convertToTree(list) : [];
      mapped.code = response?.code ?? -1;
      mapped.message = response?.message ?? null;
      return mapped;
    });
  }

  /** Load the category data (source loadCategoryData) */
  loadCategoryData(): void {
    this.executeRequest();
  }

  /** Select a category (source selectCategory) */
  selectCategory(index: number): void {
    this.selectedCategoryIndex = index;
  }

  /** Flat list → tree (source convertToTree) */
  static convertToTree(categories: Category[]): CategoryTree[] {
    const sortedList: Category[] = categories.slice();
    sortedList.sort((a: Category, b: Category): number => (a.sortNum ?? 0) - (b.sortNum ?? 0));
    const trees: CategoryTree[] = sortedList.map((c: Category): CategoryTree => CategoryTree.fromCategory(c));

    const roots: CategoryTree[] = [];
    const childrenMap: Map<number, CategoryTree[]> = new Map<number, CategoryTree[]>();
    for (const t of trees) {
      const parentId: number | null | undefined = t.parentId;
      if (parentId === null || parentId === undefined) {
        roots.push(t);
      } else {
        let children: CategoryTree[] | undefined = childrenMap.get(parentId);
        if (children === undefined) {
          children = [];
          childrenMap.set(parentId, children);
        }
        children.push(t);
      }
    }
    return roots.map((root: CategoryTree): CategoryTree => CategoryViewModel.buildCategoryTree(root, childrenMap,
      new Set<number>()));
  }

  /** Recursive tree build (source buildCategoryTree); `visiting` guards against cyclic parentIds */
  private static buildCategoryTree(node: CategoryTree, childrenMap: Map<number, CategoryTree[]>,
    visiting: Set<number>): CategoryTree {
    const children: CategoryTree[] | undefined = childrenMap.get(node.id);
    if (children === undefined || children.length === 0 || visiting.has(node.id)) {
      return node;
    }
    visiting.add(node.id);
    node.children = children.map((child: CategoryTree): CategoryTree =>
      CategoryViewModel.buildCategoryTree(child, childrenMap, visiting));
    visiting.delete(node.id);
    return node;
  }
}
