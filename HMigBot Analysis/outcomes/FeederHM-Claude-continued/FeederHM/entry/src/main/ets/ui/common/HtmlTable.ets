/**
 * HtmlTable.ets —— 源 ui/compose/layouts/Table.kt（Table / TableData / TableCell）
 * + LinearArticleContent.kt 的 LinearTable.toTableData（:1512）的鸿蒙实现。
 *
 * - TableData.fromCells：非跨格（按行、再按列）在前，单向跨格其次，双向跨格最后（UC-A46）；
 *   构造校验：跨格之后不得再出现非跨格（源 check → IllegalStateException，这里抛 Error）。
 * - 布局算法（UC-A45 / HU-A23）：列宽 = 该列所有单元格最大宽、行高 = 该行最大高；跨格尺寸均摊到所跨行列；
 *   单元格以已记录列宽/行高之和为最小约束（源 mutableStateMap 跨重组记忆：只增不减）。
 *   源靠 state 写入触发第二次测量；ArkUI onMeasureSize 内显式两遍测量（第一遍得列宽/行高，第二遍带最小约束）。
 * - 0×0 空表：尺寸 0，不崩溃。
 * - 横向滚动由调用方（ArticleBlocks 表格块）用 Scroll(Horizontal) 包裹（HU-A24）。
 */
import { LinearTable, LinearTableCellItem, Coordinate, LinearImage } from '../../core/html/LinearArticle';

// =============================================================================================
// 数据（源 TableData / TableCell）
// =============================================================================================

/** 源 data class TableCell(row, rowSpan, column, colSpan) */
export class TableCell {
  readonly row: number;
  readonly rowSpan: number;
  readonly column: number;
  readonly colSpan: number;

  constructor(row: number, rowSpan: number, column: number, colSpan: number) {
    this.row = row;
    this.rowSpan = rowSpan;
    this.column = column;
    this.colSpan = colSpan;
  }

  isSpanned(): boolean {
    return this.rowSpan > 1 || this.colSpan > 1;
  }

  isDoubleSpanned(): boolean {
    return this.rowSpan > 1 && this.colSpan > 1;
  }

  key(): string {
    return this.row + ',' + this.column + ',' + this.rowSpan + ',' + this.colSpan;
  }
}

/** 源 TableCell 排序比较器（TableData.fromCells） */
export function compareTableCells(a: TableCell, b: TableCell): number {
  // Spanned in both dimensions should come last of all
  const aDouble: boolean = a.isDoubleSpanned();
  const bDouble: boolean = b.isDoubleSpanned();
  if (aDouble && !bDouble) {
    return 1;
  } else if (!aDouble && bDouble) {
    return -1;
  }
  // Spanned cells should come after non-spanned cells
  const aSpanned: boolean = a.isSpanned();
  const bSpanned: boolean = b.isSpanned();
  if (aSpanned && !bSpanned) {
    return 1;
  } else if (!aSpanned && bSpanned) {
    return -1;
  }
  // Then sort by location
  if (a.row !== b.row) {
    return a.row - b.row;
  }
  return a.column - b.column;
}

/** 源 data class TableData（私有主构造 → 构造器 + 静态工厂） */
export class TableData {
  readonly cells: TableCell[];
  readonly rows: number;
  readonly columns: number;

  /** 源私有主构造：校验 "Spanned cells should come after non-spanned cells" */
  constructor(cells: TableCell[]) {
    let lastSpanned: boolean = false;
    for (let i = 0; i < cells.length; i++) {
      const isSpanned: boolean = cells[i].isSpanned();
      if (!((!lastSpanned && !isSpanned) || isSpanned)) {
        throw new Error('Spanned cells should come after non-spanned cells');
      }
      lastSpanned = isSpanned;
    }
    this.cells = cells;
    let rows: number = 0;
    let columns: number = 0;
    for (let i = 0; i < cells.length; i++) {
      rows = Math.max(rows, cells[i].row + cells[i].rowSpan);
      columns = Math.max(columns, cells[i].column + cells[i].colSpan);
    }
    this.rows = rows;
    this.columns = columns;
  }

  /** 源次构造 TableData(row, column)：规则网格 */
  static grid(rowCount: number, columnCount: number): TableData {
    const cells: TableCell[] = [];
    for (let index = 0; index < rowCount * columnCount; index++) {
      cells.push(new TableCell(Math.trunc(index / columnCount), 1, index % columnCount, 1));
    }
    return new TableData(cells);
  }

  /** 源 TableData.fromCells：保证排序正确（Kotlin sortedWith 为稳定排序） */
  static fromCells(cells: TableCell[]): TableData {
    const indexed: TableCell[] = cells.slice();
    const order: Map<TableCell, number> = new Map<TableCell, number>();
    for (let i = 0; i < indexed.length; i++) {
      order.set(indexed[i], i);
    }
    indexed.sort((a: TableCell, b: TableCell): number => {
      const c: number = compareTableCells(a, b);
      if (c !== 0) {
        return c;
      }
      return (order.get(a) as number) - (order.get(b) as number);
    });
    return new TableData(indexed);
  }
}

/**
 * 源 LinearTable.toTableData：跳过 filler；colSpan/rowSpan == 0 表示跨到末尾（colCount-col / rowCount-row）。
 */
export function linearTableToTableData(table: LinearTable): TableData {
  const cells: TableCell[] = [];
  table.forEachCell((coord: Coordinate, cell: LinearTableCellItem) => {
    if (cell.isFiller) {
      return;
    }
    const colSpan: number = cell.colSpan === 0 ? table.colCount - coord.col : cell.colSpan;
    const rowSpan: number = cell.rowSpan === 0 ? table.rowCount - coord.row : cell.rowSpan;
    cells.push(new TableCell(coord.row, rowSpan, coord.col, colSpan));
  });
  return TableData.fromCells(cells);
}

/** 表格任一单元格（顶层内容）含图片（源 LAC:836：则所有行不着色） */
export function tableContainsImage(table: LinearTable): boolean {
  let found: boolean = false;
  table.cells.forEach((cell: LinearTableCellItem, _k: string) => {
    for (let i = 0; i < cell.content.length; i++) {
      if (cell.content[i] instanceof LinearImage) {
        found = true;
      }
    }
  });
  return found;
}

// =============================================================================================
// 纯布局计算（便于单测；与 TableLayout.onMeasureSize 共用）
// =============================================================================================

/** 单元格测得尺寸（vp） */
export class CellSize {
  readonly width: number;
  readonly height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

/** 列宽/行高记忆（源 columnWidths / rowHeights mutableStateMap） */
export class TableMetrics {
  readonly columnWidths: Map<number, number> = new Map<number, number>();
  readonly rowHeights: Map<number, number> = new Map<number, number>();

  clear(): void {
    this.columnWidths.clear();
    this.rowHeights.clear();
  }

  private static getOrZero(m: Map<number, number>, k: number): number {
    const v: number | undefined = m.get(k);
    return v === undefined ? 0 : v;
  }

  columnWidth(col: number): number {
    return TableMetrics.getOrZero(this.columnWidths, col);
  }

  rowHeight(row: number): number {
    return TableMetrics.getOrZero(this.rowHeights, row);
  }

  /** 单元格最小宽 = 所跨列已记录宽之和 */
  minWidthOf(cell: TableCell): number {
    let sum: number = 0;
    for (let i = 0; i < cell.colSpan; i++) {
      sum += this.columnWidth(cell.column + i);
    }
    return sum;
  }

  minHeightOf(cell: TableCell): number {
    let sum: number = 0;
    for (let i = 0; i < cell.rowSpan; i++) {
      sum += this.rowHeight(cell.row + i);
    }
    return sum;
  }

  /** 依赖 cells 已按"非跨格在前"排序：跨格尺寸均摊到所跨行列，取最大 */
  accumulate(cells: TableCell[], sizes: CellSize[]): void {
    for (let index = 0; index < sizes.length && index < cells.length; index++) {
      const cell: TableCell = cells[index];
      const size: CellSize = sizes[index];
      const widthPerColumn: number = size.width / cell.colSpan;
      for (let col = cell.column; col < cell.column + cell.colSpan; col++) {
        this.columnWidths.set(col, Math.max(this.columnWidth(col), widthPerColumn));
      }
      const heightPerRow: number = size.height / cell.rowSpan;
      for (let row = cell.row; row < cell.row + cell.rowSpan; row++) {
        this.rowHeights.set(row, Math.max(this.rowHeight(row), heightPerRow));
      }
    }
  }

  totalWidth(): number {
    let sum: number = 0;
    this.columnWidths.forEach((v: number) => {
      sum += v;
    });
    return sum;
  }

  totalHeight(): number {
    let sum: number = 0;
    this.rowHeights.forEach((v: number) => {
      sum += v;
    });
    return sum;
  }

  /** 单元格左上角 x = 之前各列宽之和 */
  xOf(cell: TableCell): number {
    let x: number = 0;
    for (let c = 0; c < cell.column; c++) {
      x += this.columnWidth(c);
    }
    return x;
  }

  yOf(cell: TableCell): number {
    let y: number = 0;
    for (let r = 0; r < cell.row; r++) {
      y += this.rowHeight(r);
    }
    return y;
  }
}

/** 单元格测量最大约束（源 Constraints.Infinity；ArkUI 用足够大的有限值） */
export const TABLE_UNBOUNDED: number = 100000;

@Builder
function emptyCellsBuilder() {
}

/**
 * 源 Table 的自定义 Layout：子组件 = cellsBuilder 按 tableData.cells 顺序产出的每个单元格（每格一个根组件）。
 * 只有 rowSpan>0 && colSpan>0 的格才应产出（调用方保证；toTableData 已保证 span ≥ 1）。
 */
@ComponentV2
export struct TableLayout {
  @Param tableData: TableData = new TableData([]);
  @BuilderParam cellsBuilder: () => void = emptyCellsBuilder;
  private metrics: TableMetrics = new TableMetrics();
  private metricsFor: TableData | null = null;

  onMeasureSize(selfLayoutInfo: GeometryInfo, children: Array<Measurable>,
    constraint: ConstraintSizeOptions): SizeResult {
    const data: TableData = this.tableData;
    if (this.metricsFor !== data) {
      this.metrics.clear();
      this.metricsFor = data;
    }
    const cells: TableCell[] = data.cells;
    const n: number = Math.min(children.length, cells.length);
    if (n === 0) {
      return { width: 0, height: 0 };
    }
    // 第一遍：以已记录列宽/行高为最小约束测量，累计列宽/行高
    let sizes: CellSize[] = this.measurePass(children, cells, n);
    this.metrics.accumulate(cells, sizes);
    // 第二遍：带更新后的最小约束重测（源由 state 写入触发的再测量），使单元格撑满所在行列
    sizes = this.measurePass(children, cells, n);
    this.metrics.accumulate(cells, sizes);
    const result: SizeResult = { width: this.metrics.totalWidth(), height: this.metrics.totalHeight() };
    return result;
  }

  private measurePass(children: Array<Measurable>, cells: TableCell[], n: number): CellSize[] {
    const sizes: CellSize[] = [];
    for (let i = 0; i < n; i++) {
      const cell: TableCell = cells[i];
      const minW: number = this.metrics.minWidthOf(cell);
      const minH: number = this.metrics.minHeightOf(cell);
      const r: MeasureResult = children[i].measure({
        minWidth: minW,
        maxWidth: Math.max(minW, TABLE_UNBOUNDED),
        minHeight: minH,
        maxHeight: Math.max(minH, TABLE_UNBOUNDED)
      });
      sizes.push(new CellSize(r.width, r.height));
    }
    return sizes;
  }

  onPlaceChildren(selfLayoutInfo: GeometryInfo, children: Array<Layoutable>, constraint: ConstraintSizeOptions): void {
    const cells: TableCell[] = this.tableData.cells;
    const n: number = Math.min(children.length, cells.length);
    for (let i = 0; i < n; i++) {
      children[i].layout({ x: this.metrics.xOf(cells[i]), y: this.metrics.yOf(cells[i]) });
    }
  }

  build() {
    this.cellsBuilder()
  }
}
