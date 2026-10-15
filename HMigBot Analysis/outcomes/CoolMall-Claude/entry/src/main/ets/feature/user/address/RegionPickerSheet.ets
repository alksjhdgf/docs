/**
 * RegionPickerSheet — 地区选择底部弹窗内容 (source: feature/user/component/RegionPickerModal.kt).
 *
 * Put it at the root of a `bindSheet` builder (SheetDefaults.options) — the ModalBottomSheet equivalent.
 * BottomModal(title = `请选择所在地区`, drag indicator) {
 *   Row of three capsule tags (province / city / district; unselected level shows `请选择`;
 *     current level = PRIMARY FILLED, others DEFAULT LIGHT; city tag only after a province, district tag
 *     only after a city);
 *   SpaceVerticalMedium + WeDivider;
 *   list of the current level (AppListItem, vertical padding 16, no arrow; selected → 18vp primary circle
 *     with a white ic_success_circle check).
 * }
 * - Picking a province → city level (or finish when it has no children); a city → district level (or finish);
 *   a district → onRegionSelected(`省 市 区`) + onDismiss() (USER-A22).
 * - Province tag: back to the province list, clearing city / district; city tag: back to the city list,
 *   clearing the district; district tag: district list (USER-A23).
 * - initialRegion `省 市 区` restores the selection and the deepest matched level when the sheet opens.
 */
import { display } from '@kit.ArkUI';
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { WeDivider } from '../../../core/ui/widget/AppCard';
import { BottomModal } from '../../../core/ui/widget/BottomSheet';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { Tag, TagSize, TagStyle, TagType } from '../../../core/ui/widget/Tags';
import { LogUtils } from '../../../core/util/LogUtils';
import { Region } from './Region';

const TAG: string = 'RegionPickerSheet';
/** Fallback list max height when the display cannot be queried */
const DEFAULT_LIST_MAX_HEIGHT: number = 480;
/** List max height as a fraction of the screen (M3 sheet content is bounded by the window) */
const LIST_MAX_HEIGHT_FRACTION: number = 0.6;

@ComponentV2
export struct RegionPickerSheet {
  /** Province-level regions */
  @Param regions: Region[] = [];
  /** Initially selected region, `省 市 区` */
  @Param initialRegion: string = '';
  /** Complete region string, e.g. `广西壮族自治区 崇左市 大新县` */
  @Event onRegionSelected: (region: string) => void = (region: string) => {
  };
  /** Close the sheet */
  @Event onDismiss: () => void = () => {
  };

  @Local selectedProvince: Region | null = null;
  @Local selectedCity: Region | null = null;
  @Local selectedDistrict: Region | null = null;
  /** Current level: 0 = province, 1 = city, 2 = district */
  @Local currentLevel: number = 0;

  private listMaxHeight: number = DEFAULT_LIST_MAX_HEIGHT;

  aboutToAppear(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      this.listMaxHeight = this.getUIContext().px2vp(d.height) * LIST_MAX_HEIGHT_FRACTION;
    } catch (e) {
      LogUtils.eTag(TAG, 'getDefaultDisplaySync failed: ' + JSON.stringify(e));
    }
    this.restoreInitialRegion();
  }

  /** Source LaunchedEffect(initialRegion, regions) */
  private restoreInitialRegion(): void {
    if (this.initialRegion.trim().length === 0 || this.regions.length === 0) {
      return;
    }
    const parts: string[] = this.initialRegion.split(' ');
    if (parts.length === 0) {
      return;
    }
    const province: Region | undefined = this.regions.find((r: Region): boolean => r.name === parts[0]);
    this.selectedProvince = province !== undefined ? province : null;
    if (parts.length > 1 && province !== undefined) {
      const city: Region | undefined = province.children.find((r: Region): boolean => r.name === parts[1]);
      this.selectedCity = city !== undefined ? city : null;
      if (parts.length > 2 && city !== undefined) {
        const district: Region | undefined = city.children.find((r: Region): boolean => r.name === parts[2]);
        this.selectedDistrict = district !== undefined ? district : null;
      }
    }
    if (this.selectedDistrict !== null) {
      this.currentLevel = 2;
    } else if (this.selectedCity !== null) {
      this.currentLevel = 1;
    } else {
      this.currentLevel = 0;
    }
  }

  /** Regions of the current level */
  private displayRegions(): Region[] {
    if (this.currentLevel === 0) {
      return this.regions;
    }
    if (this.currentLevel === 1) {
      return this.selectedProvince !== null ? (this.selectedProvince as Region).children : [];
    }
    if (this.currentLevel === 2) {
      return this.selectedCity !== null ? (this.selectedCity as Region).children : [];
    }
    return [];
  }

  private isSelected(region: Region): boolean {
    if (this.currentLevel === 0) {
      return this.selectedProvince !== null && region.id === (this.selectedProvince as Region).id;
    }
    if (this.currentLevel === 1) {
      return this.selectedCity !== null && region.id === (this.selectedCity as Region).id;
    }
    if (this.currentLevel === 2) {
      return this.selectedDistrict !== null && region.id === (this.selectedDistrict as Region).id;
    }
    return false;
  }

  private onRegionClick(region: Region): void {
    if (this.currentLevel === 0) {
      this.selectedProvince = region;
      this.selectedCity = null;
      this.selectedDistrict = null;
      if (region.children.length > 0) {
        this.currentLevel = 1;
      } else {
        this.onRegionSelected(region.name);
        this.onDismiss();
      }
    } else if (this.currentLevel === 1) {
      this.selectedCity = region;
      this.selectedDistrict = null;
      if (region.children.length > 0) {
        this.currentLevel = 2;
      } else {
        const provinceName: string = this.selectedProvince !== null ? (this.selectedProvince as Region).name : 'null';
        this.onRegionSelected(`${provinceName} ${region.name}`);
        this.onDismiss();
      }
    } else if (this.currentLevel === 2) {
      this.selectedDistrict = region;
      const provinceName: string = this.selectedProvince !== null ? (this.selectedProvince as Region).name : 'null';
      const cityName: string = this.selectedCity !== null ? (this.selectedCity as Region).name : 'null';
      this.onRegionSelected(`${provinceName} ${cityName} ${region.name}`);
      this.onDismiss();
    }
  }

  /** Tag text of a level: the selected name, or `请选择` */
  private tagLabel(level: number): ResourceStr {
    const r: Region | null = level === 0 ? this.selectedProvince : (level === 1 ? this.selectedCity :
      this.selectedDistrict);
    return r !== null ? (r as Region).name : $r('app.string.please_select');
  }

  @Builder
  levelTag(level: number) {
    Row() {
      Tag({
        tagText: this.tagLabel(level),
        tagType: this.currentLevel === level ? TagType.PRIMARY : TagType.DEFAULT,
        tagStyle: this.currentLevel === level ? TagStyle.FILLED : TagStyle.LIGHT,
        tagSize: TagSize.MEDIUM,
        tagRadius: Dimens.radiusCircle
      })
    }
    .alignItems(VerticalAlign.Center)
    .borderRadius(Dimens.radiusCircle)
    .clip(true)
    .onClick(() => {
      this.onTagClick(level);
    })
  }

  private onTagClick(level: number): void {
    if (level === 0) {
      this.currentLevel = 0;
      this.selectedCity = null;
      this.selectedDistrict = null;
    } else if (level === 1) {
      if (this.selectedProvince !== null) {
        this.currentLevel = 1;
        this.selectedDistrict = null;
      }
    } else if (this.selectedCity !== null) {
      this.currentLevel = 2;
    }
  }

  @Builder
  checkMark() {
    Row() {
      Image($r('app.media.ic_success_circle'))
        .width(14)
        .height(14)
        .objectFit(ImageFit.Contain)
        .fillColor(Color.White)
    }
    .width(18)
    .height(18)
    .borderRadius(9)
    .clip(true)
    .backgroundColor(ThemeManager.instance.primary)
    // source: Box(contentAlignment = Center)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  pickerBody() {
    // Tag bar (source Row(fillMaxWidth) without arrangement = start / top)
    Row() {
      this.levelTag(0)
      if (this.selectedProvince !== null) {
        Row()
          .width(Dimens.spaceHorizontalSmall)
          .height(1)
        this.levelTag(1)
        if (this.selectedCity !== null) {
          Row()
            .width(Dimens.spaceHorizontalSmall)
            .height(1)
          this.levelTag(2)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)

    // SpaceVerticalMedium()
    Row()
      .width('100%')
      .height(Dimens.spaceVerticalMedium)
    WeDivider()

    List() {
      ForEach(this.displayRegions(), (region: Region) => {
        ListItem() {
          AppListItem({
            itemTitle: region.name,
            showArrow: false,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: this.isSelected(region),
            trailingContent: (): void => {
              this.checkMark()
            },
            onItemClick: () => {
              this.onRegionClick(region);
            }
          })
        }
        .width('100%')
      }, (region: Region): string => this.currentLevel + '_' + region.id + '_' + this.isSelected(region))
    }
    .width('100%')
    .constraintSize({ maxHeight: this.listMaxHeight })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: $r('app.string.please_select_region'),
        showDragIndicator: true,
        sheetContent: (): void => {
          this.pickerBody()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
