/**
 * LinearTable.ets —— 源 LinearStuff.kt 的 LinearTable / Builder / LinearTableCellItem / Coordinate。
 * 坐标 Map key = `${row},${col}`（ArkTS Map 以引用比较对象键）。（LinearArticle.ets 统一再导出）
 */
import { LinearElementType, linearIdsToString, linearElementsToString, LinearElement } from './LinearElements';

// =============================================================================================
// 表格
// =============================================================================================

export enum LinearTableCellItemType {
  HEADER = 'HEADER',
  DATA = 'DATA'
}

/** 源 data class Coordinate(row, col) */
export class Coordinate {
  readonly row: number;
  readonly col: number;

  constructor(row: number, col: number) {
    this.row = row;
    this.col = col;
  }

  key(): string {
    return coordinateKey(this.row, this.col);
  }

  static fromKey(key: string): Coordinate {
    const i: number = key.indexOf(',');
    return new Coordinate(Number(key.substring(0, i)), Number(key.substring(i + 1)));
  }

  toString(): string {
    return 'Coordinate(row=' + this.row + ', col=' + this.col + ')';
  }
}

export function coordinateKey(row: number, col: number): string {
  return row + ',' + col;
}

/** 源 LinearTableCellItem；filler = (DATA, -1, -1, [])，isFiller 只看 colSpan/rowSpan */
export class LinearTableCellItem {
  readonly type: LinearTableCellItemType;
  readonly colSpan: number;
  readonly rowSpan: number;
  readonly content: LinearElement[];

  static readonly FILLER: LinearTableCellItem = new LinearTableCellItem(LinearTableCellItemType.DATA, -1, -1, []);

  constructor(type: LinearTableCellItemType, colSpan: number, rowSpan: number, content: LinearElement[]) {
    this.type = type;
    this.colSpan = colSpan;
    this.rowSpan = rowSpan;
    this.content = content;
  }

  get isFiller(): boolean {
    return this.colSpan === -1 && this.rowSpan === -1;
  }

  toString(): string {
    return 'LinearTableCellItem(type=' + this.type + ', colSpan=' + this.colSpan + ', rowSpan=' + this.rowSpan +
      ', content=' + linearElementsToString(this.content) + ')';
  }
}

/** 源 LinearTable */
export class LinearTable extends LinearElement {
  readonly rowCount: number;
  readonly colCount: number;
  /** key = coordinateKey(row, col) */
  readonly cells: Map<string, LinearTableCellItem>;

  constructor(ids: Set<string>, rowCount: number, colCount: number, cells: Map<string, LinearTableCellItem>) {
    super(LinearElementType.TABLE, ids);
    this.rowCount = rowCount;
    this.colCount = colCount;
    this.cells = cells;
  }

  /** 源次构造：按行优先顺序铺放 cells（RTL 时列镜像） */
  static fromCellList(ids: Set<string>, rowCount: number, colCount: number, cells: LinearTableCellItem[],
    leftToRight: boolean): LinearTable {
    const map: Map<string, LinearTableCellItem> = new Map<string, LinearTableCellItem>();
    for (let index = 0; index < cells.length; index++) {
      const row: number = Math.trunc(index / colCount);
      const col: number = leftToRight ? index % colCount : colCount - 1 - index % colCount;
      map.set(coordinateKey(row, col), cells[index]);
    }
    return new LinearTable(ids, rowCount, colCount, map);
  }

  cellAt(row: number, col: number): LinearTableCellItem | null {
    const c: LinearTableCellItem | undefined = this.cells.get(coordinateKey(row, col));
    return c !== undefined ? c : null;
  }

  /** 按 (row, col) 升序遍历全部单元（含 filler） */
  forEachCell(cb: (coord: Coordinate, cell: LinearTableCellItem) => void): void {
    const coords: Coordinate[] = [];
    this.cells.forEach((_v: LinearTableCellItem, k: string) => {
      coords.push(Coordinate.fromKey(k));
    });
    coords.sort((a: Coordinate, b: Coordinate): number => a.row !== b.row ? a.row - b.row : a.col - b.col);
    for (let i = 0; i < coords.length; i++) {
      cb(coords[i], this.cells.get(coords[i].key()) as LinearTableCellItem);
    }
  }

  collectImageUrls(target: Set<string>): void {
    this.cells.forEach((cell: LinearTableCellItem, _k: string) => {
      if (!cell.isFiller) {
        for (let i = 0; i < cell.content.length; i++) {
          cell.content[i].collectImageUrls(target);
        }
      }
    });
  }

  static build(ids: Set<string>, leftToRight: boolean, block: (builder: LinearTableBuilder) => void): LinearTable {
    const b: LinearTableBuilder = new LinearTableBuilder(ids, leftToRight);
    block(b);
    return b.build();
  }

  toString(): string {
    const parts: string[] = [];
    this.forEachCell((coord: Coordinate, cell: LinearTableCellItem) => {
      parts.push(coord.row + ',' + coord.col + '=' + cell.toString());
    });
    return 'LinearTable(ids=' + linearIdsToString(this.ids) + ', rowCount=' + this.rowCount + ', colCount=' + this.colCount +
      ', cells={' + parts.join(', ') + '})';
  }
}

/** 源 LinearTable.Builder（LinearStuff.kt:180） */
export class LinearTableBuilder {
  readonly ids: Set<string>;
  readonly leftToRight: boolean;
  private cells: Map<string, LinearTableCellItem> = new Map<string, LinearTableCellItem>();
  private rowCount: number = 0;
  private colCount: number = 0;
  private currentRowColCount: number = 0;
  private currentRow: number = 0;

  constructor(ids: Set<string>, leftToRight: boolean) {
    this.ids = ids;
    this.leftToRight = leftToRight;
  }

  add(element: LinearTableCellItem): void {
    if (!(this.rowCount > 0)) {
      throw new Error('Must add a row before adding cells');
    }
    // First find the first empty cell in this row
    while (this.cells.has(coordinateKey(this.currentRow, this.currentRowColCount))) {
      this.currentRowColCount++;
    }
    const cellCol: number = this.currentRowColCount;

    this.currentRowColCount += element.colSpan;
    if (this.currentRowColCount > this.colCount) {
      this.colCount = this.currentRowColCount;
    }

    this.cells.set(coordinateKey(this.currentRow, cellCol), element);

    // Insert filler elements for spanned cells
    for (let r = 0; r < element.rowSpan; r++) {
      for (let c = 0; c < element.colSpan; c++) {
        // Skip first since this is the cell itself
        if (r === 0 && c === 0) {
          continue;
        }
        const fillerKey: string =
          coordinateKey(this.currentRow + r, this.currentRowColCount - element.colSpan + c);
        if (this.cells.has(fillerKey)) {
          throw new Error('Cell at filler ' + fillerKey + ' already exists');
        }
        this.cells.set(fillerKey, LinearTableCellItem.FILLER);
      }
    }
  }

  newRow(): void {
    if (this.rowCount > 0) {
      this.currentRow++;
    }
    this.rowCount++;
    this.currentRowColCount = 0;
  }

  build(): LinearTable {
    if (this.leftToRight) {
      return new LinearTable(this.ids, this.rowCount, this.colCount, this.cells);
    }
    const mirrored: Map<string, LinearTableCellItem> = new Map<string, LinearTableCellItem>();
    this.cells.forEach((item: LinearTableCellItem, k: string) => {
      const c: Coordinate = Coordinate.fromKey(k);
      mirrored.set(coordinateKey(c.row, this.colCount - 1 - c.col), item);
    });
    return new LinearTable(this.ids, this.rowCount, this.colCount, mirrored);
  }
}
