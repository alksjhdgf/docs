/**
 * UserRoutesAddressDetailPage — 收货地址详情 (source: feature/user/view/AddressDetailScreen.kt +
 * viewmodel/AddressDetailViewModel.kt).
 *
 * AppScaffold(useLargeTopBar, title `编辑地址` / `添加地址`): the large top bar pads itself by the status
 * bar (USER-A17). bottomBar `保存` only in the success state → saveAddress() (USER-A21).
 * BaseNetWorkView: edit mode loads user/address/info (loading / error + retry); add mode shows the empty form
 * directly (USER-A18).
 * VerticalList(verticalScroll, padding 12, spacedBy 12) {
 *   Card(ShapeMedium) { Column(padding 12, spacedBy 12) { 联系人, 手机号码 (phone keyboard),
 *     省市区 (read-only, opens RegionPickerSheet), 详细地址 (3..5 lines) } }   (USER-A19)
 *   Card { AppListItem(`设置默认地址`, `下单会优先使用该地址`, Switch) }       (USER-A20)
 * }
 * RegionPickerSheet (bindSheet): initial `省 市 区`; a complete `省 市 区` result updates the form (USER-A22/A23).
 */
import { RegionData } from '../feature/user/address/RegionData';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { AddressDetailParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { SheetDefaults } from '../core/ui/widget/BottomSheet';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AddressDetailViewModel } from '../feature/user/address/AddressDetailViewModel';
import { AddressOutlinedField } from '../feature/user/address/AddressOutlinedField';
import { Region } from '../feature/user/address/Region';
import { RegionPickerSheet } from '../feature/user/address/RegionPickerSheet';

@Builder
export function UserRoutesAddressDetailPageBuilder() {
  UserRoutesAddressDetailPage()
}

@ComponentV2
struct UserRoutesAddressDetailPage {
  @Local vm: AddressDetailViewModel = new AddressDetailViewModel();
  /** Region picker visibility (source showRegionPicker) */
  @Local showRegionPicker: boolean = false;

  private regions: Region[] = RegionData.getProvinces();

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  /** Source UserRoutes.AddressDetail(isEditMode = false, addressId = 0L) */
  private onParam(p: Object | undefined): void {
    let isEditMode: boolean = false;
    let addressId: number = 0;
    if (p !== undefined && p !== null && p instanceof AddressDetailParam) {
      isEditMode = (p as AddressDetailParam).isEditMode === true;
      const id: number | null | undefined = (p as AddressDetailParam).addressId;
      addressId = (id === null || id === undefined) ? 0 : id;
    }
    this.vm.start(isEditMode, addressId);
  }

  /** Source onRegionSelected: split(" ") and update only when there are exactly 3 parts */
  private onRegionSelected(selectedRegion: string): void {
    const parts: string[] = selectedRegion.split(' ');
    if (parts.length === 3) {
      this.vm.updateRegion(parts[0], parts[1], parts[2]);
    }
  }

  @Builder
  regionSheet() {
    RegionPickerSheet({
      regions: this.regions,
      initialRegion: this.vm.regionText(),
      onRegionSelected: (region: string) => {
        this.onRegionSelected(region);
      },
      onDismiss: () => {
        this.showRegionPicker = false;
      }
    })
  }

  @Builder
  formCard() {
    // Card(fillMaxWidth, ShapeMedium) { Column(fillMaxWidth, padding 12, spacedBy 12) }
    Column({ space: Dimens.spaceVerticalMedium }) {
      AddressOutlinedField({
        fieldLabel: $r('app.string.contact_person'),
        fieldPlaceholder: $r('app.string.please_input_contact'),
        fieldValue: this.vm.contactName,
        onValueChange: (value: string) => {
          this.vm.updateContactName(value);
        }
      })
      AddressOutlinedField({
        fieldLabel: $r('app.string.user_phone_number'),
        fieldPlaceholder: $r('app.string.please_input_phone'),
        fieldValue: this.vm.phone,
        phoneKeyboard: true,
        onValueChange: (value: string) => {
          this.vm.updatePhone(value);
        }
      })
      AddressOutlinedField({
        fieldLabel: $r('app.string.region'),
        fieldPlaceholder: $r('app.string.please_select_region'),
        fieldValue: this.vm.regionText(),
        readOnly: true,
        onFieldClick: () => {
          this.showRegionPicker = true;
        }
      })
      AddressOutlinedField({
        fieldLabel: $r('app.string.detail_address'),
        fieldPlaceholder: $r('app.string.street_number_etc'),
        fieldValue: this.vm.detailAddress,
        multiLine: true,
        imeDone: true,
        onValueChange: (value: string) => {
          this.vm.updateDetailAddress(value);
        }
      })
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
  }

  @Builder
  defaultSwitch() {
    Toggle({ type: ToggleType.Switch, isOn: this.vm.isDefaultAddress })
      .selectedColor(ThemeManager.instance.primary)
      .onChange((isOn: boolean) => {
        this.vm.updateIsDefaultAddress(isOn);
      })
  }

  @Builder
  defaultAddressCard() {
    // DefaultAddressSwitch: Card { AppListItem(title, description, showArrow = false, trailing Switch) }
    Column() {
      AppListItem({
        itemTitle: $r('app.string.set_default_address'),
        description: $r('app.string.default_address_tip'),
        showArrow: false,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.defaultSwitch()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  formContent() {
    // VerticalList(Modifier.verticalScroll): Column(fillMaxWidth, padding 12, spacedBy 12, start)
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        this.formCard()
        this.defaultAddressCard()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      onRetry: () => {
        this.vm.retryRequest();
      },
      content: (): void => {
        this.formContent()
      }
    })
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.save_address'),
      onBtnClick: () => {
        this.vm.saveAddress();
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        AppScaffold({
          titleText: this.vm.isEditMode ? $r('app.string.edit_address') : $r('app.string.add_address'),
          useLargeTopBar: true,
          hasBottomBar: this.vm.uiState === 'success',
          bottomBar: (): void => {
            this.bottomBar()
          },
          content: (): void => {
            this.pageContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet(this.showRegionPicker, this.regionSheet(),
        SheetDefaults.options((): void => {
          this.showRegionPicker = false;
        }))
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
