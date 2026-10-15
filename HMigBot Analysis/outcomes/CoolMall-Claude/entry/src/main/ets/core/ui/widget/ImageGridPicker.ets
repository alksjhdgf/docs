/**
 * ImageGridPicker (source: core/ui/component/imagepicker/ImageGridPicker.kt).
 * 3-column grid of square cells (8vp gaps): selected images (Cover, 8vp corners, 22vp black@0.6 delete
 * button top-end) followed by an "add" cell while fewer than `maxImages` (default 9) are selected.
 * The add cell opens the system photo picker (`photoAccessHelper.PhotoViewPicker`, images only, one per
 * pick like PickVisualMedia). The component is stateless: the caller owns `selectedImages` (picker URIs)
 * and receives the new list via onImagesChanged.
 * The source wraps cells in AnimatedVisibility(visible = true), whose enter animation never runs for
 * initially-visible content, so no transition is applied here.
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Dimens } from '../../designsystem/Dimens';
import { LogUtils } from '../../util/LogUtils';

const TAG: string = 'ImageGridPicker';
const COLUMNS: number = 3;
const SPACING: number = 8;

class PickerCell {
  uri: string;
  isAdd: boolean;

  constructor(uri: string, isAdd: boolean) {
    this.uri = uri;
    this.isAdd = isAdd;
  }
}

class PickerRow {
  key: string;
  cells: PickerCell[];
  fillers: number[];

  constructor(key: string, cells: PickerCell[], fillers: number[]) {
    this.key = key;
    this.cells = cells;
    this.fillers = fillers;
  }
}

@ComponentV2
export struct ImageGridPicker {
  @Param selectedImages: string[] = [];
  @Param maxImages: number = 9;
  @Event onImagesChanged: (images: string[]) => void = (images: string[]) => {
  };
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  /** allItems.chunked(3): images + one add cell (when below max), padded with fillers. */
  @Computed
  get rows(): PickerRow[] {
    const cells: PickerCell[] = [];
    for (const uri of this.selectedImages) {
      cells.push(new PickerCell(uri, false));
    }
    if (this.selectedImages.length < this.maxImages) {
      cells.push(new PickerCell('', true));
    }
    const result: PickerRow[] = [];
    for (let i = 0; i < cells.length; i += COLUMNS) {
      const rowCells: PickerCell[] = cells.slice(i, i + COLUMNS);
      const fillers: number[] = [];
      for (let f = rowCells.length; f < COLUMNS; f++) {
        fillers.push(f);
      }
      let key: string = 'row' + i;
      for (const c of rowCells) {
        key += '_' + (c.isAdd ? '+' : c.uri);
      }
      result.push(new PickerRow(key, rowCells, fillers));
    }
    return result;
  }

  private removeImage(uri: string): void {
    const next: string[] = this.selectedImages.slice();
    const idx: number = next.indexOf(uri);
    if (idx >= 0) {
      next.splice(idx, 1);
    }
    this.onImagesChanged(next);
  }

  private async pickImage(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (!this.alive || result.photoUris.length === 0) {
        return;
      }
      if (this.selectedImages.length < this.maxImages) {
        const next: string[] = this.selectedImages.slice();
        next.push(result.photoUris[0]);
        this.onImagesChanged(next);
      }
    } catch (e) {
      LogUtils.eTag(TAG, 'photo picker failed: ' + JSON.stringify(e));
    }
  }

  @Builder
  imageCell(uri: string) {
    // delete button anchored top-end (source: .align(Alignment.TopEnd).padding(4))
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(uri)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .draggable(false)
        .accessibilityText($r('app.string.selected_image'))
      Row() {
        Image($r('app.media.ic_close'))
          .width(12)
          .height(12)
          .objectFit(ImageFit.Contain)
          .fillColor(Color.White)
      }
      .width(22)
      .height(22)
      .margin(Dimens.spacePaddingXSmall)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.mask'))
      .borderRadius(11)
      .onClick(() => {
        this.removeImage(uri);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_content'))
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
  }

  @Builder
  addCell() {
    Column() {
      Image($r('app.media.ic_add'))
        .width(32)
        .height(32)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_tertiary'))
        .accessibilityText($r('app.string.add_image'))
      Text($r('app.string.add_image'))
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: Dimens.spaceVerticalXSmall })
    }
    .width('100%')
    .height('100%')
    // source: Box(contentAlignment = Center) > Column(CenterHorizontally, Arrangement.Center)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .border({ width: 1, color: $r('app.color.border'), radius: Dimens.radiusSmall })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(Dimens.radiusSmall)
    .clip(true)
    .onClick(() => {
      this.pickImage();
    })
  }

  build() {
    Column({ space: SPACING }) {
      ForEach(this.rows, (row: PickerRow) => {
        Row({ space: SPACING }) {
          ForEach(row.cells, (cell: PickerCell) => {
            Stack({ alignContent: Alignment.TopStart }) {
              if (cell.isAdd) {
                this.addCell()
              } else {
                this.imageCell(cell.uri)
              }
            }
            .layoutWeight(1)
            .aspectRatio(1)
          }, (cell: PickerCell) => cell.isAdd ? 'add' : 'img_' + cell.uri)
          ForEach(row.fillers, (f: number) => {
            Row()
              .layoutWeight(1)
              .aspectRatio(1)
          }, (f: number) => 'filler_' + f)
        }
        .width('100%')
        // source: Row(horizontalArrangement = spacedBy(8)) → start / top
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)
      }, (row: PickerRow) => row.key)
    }
    .width('100%')
    // source: Column(verticalArrangement = spacedBy(8)) → start
    .alignItems(HorizontalAlign.Start)
  }
}
