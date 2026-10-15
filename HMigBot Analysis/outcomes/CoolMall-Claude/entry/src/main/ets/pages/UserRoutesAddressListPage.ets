/**
 * UserRoutesAddressListPage — 收货地址列表 (source: feature/user/view/AddressListScreen.kt +
 * viewmodel/AddressListViewModel.kt + skeleton/AddressListSkeleton.kt).
 *
 * AppScaffold(title = `收货地址`): the top bar pads itself by the status bar (USER-A08).
 * bottomBar: AppBottomButton `新增地址` (hidden while loading / on error) → AddressDetail add mode (USER-A12).
 * BaseNetWorkListView: loading → 3 AddressCardSkeleton (with action buttons); error → EmptyNetwork + retry;
 * empty → EmptyData `暂无数据` (USER-A09); success → RefreshLayout list (pull-to-refresh / load-more,
 * `没有更多了`) of AddressCard with edit / delete AddressActionButtons (USER-A10 / A11).
 * Card tap: select mode → return SelectAddressResult and close (USER-A15), otherwise edit mode; edit button →
 * edit mode; delete button → confirm dialog (USER-A13 / A14). RefreshResult from AddressDetail refreshes
 * the list (USER-A16).
 */
import { Address } from '../core/model/Market';
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { Dimens } from '../core/designsystem/Dimens';
import { AddressListParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { RefreshList } from '../core/ui/base/RefreshList';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { AddressActionButton, AddressCard, AddressCardSkeleton } from '../core/ui/commerce/AddressCard';
import { AppBottomButton } from '../core/ui/widget/Buttons';
import { AddressDeleteDialog } from '../feature/user/address/AddressDeleteDialog';
import { AddressListViewModel } from '../feature/user/address/AddressListViewModel';

/** Skeleton cards (source repeat(3)) */
const SKELETON_INDEXES: number[] = [0, 1, 2];

@Builder
export function UserRoutesAddressListPageBuilder() {
  UserRoutesAddressListPage()
}

@ComponentV2
struct UserRoutesAddressListPage {
  @Local vm: AddressListViewModel = new AddressListViewModel();

  private deleteDialog: AddressDeleteDialog | null = null;

  aboutToDisappear(): void {
    if (this.deleteDialog !== null) {
      this.deleteDialog.close();
      this.deleteDialog = null;
    }
    this.vm.dispose();
  }

  /** Source: isSelectMode from UserRoutes.AddressList (default false) */
  private onParam(p: Object | undefined): void {
    let isSelectMode: boolean = false;
    if (p !== undefined && p !== null && p instanceof AddressListParam) {
      isSelectMode = (p as AddressListParam).isSelectMode === true;
    }
    this.vm.start(isSelectMode);
  }

  /** Close the dialog when the view model hides it (cancel / delete success) */
  @Monitor('vm.showDeleteDialog')
  onDeleteDialogVisibleChange(monitor: IMonitor): void {
    if (!this.vm.showDeleteDialog && this.deleteDialog !== null) {
      this.deleteDialog.close();
    }
  }

  private onDeleteClick(id: number): void {
    this.vm.openDeleteDialog(id);
    if (this.deleteDialog === null) {
      this.deleteDialog = new AddressDeleteDialog(this.getUIContext(), (): void => {
        // Mask tap / back: source onDismiss = hideDeleteDialog()
        this.vm.hideDeleteDialog();
      });
    }
    this.deleteDialog.open((): void => {
      this.vm.deleteAddress();
    }, (): void => {
      this.vm.hideDeleteDialog();
    });
  }

  @Builder
  loadingSkeleton() {
    // AddressListLoadingSkeleton: Column(fillMaxSize, padding 12, spacedBy 12) { repeat(3) AddressCardSkeleton }
    Column({ space: Dimens.spacePaddingMedium }) {
      ForEach(SKELETON_INDEXES, (i: number) => {
        AddressCardSkeleton({ showActionButtons: true })
      }, (i: number): string => 'address_skeleton_' + i)
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  actionButtons(addr: Address) {
    // Row(horizontalArrangement = spacedBy(8.dp)) { edit, delete }
    Row({ space: 8 }) {
      AddressActionButton({
        iconRes: $r('app.media.ic_edit_fill'),
        onActionClick: () => {
          AddressListViewModel.toAddressDetail(true, addr.id);
        }
      })
      AddressActionButton({
        iconRes: $r('app.media.ic_delete_fill'),
        onActionClick: () => {
          this.onDeleteClick(addr.id);
        }
      })
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  addressItem(addr: Address) {
    AddressCard({
      address: addr,
      hasActionSlot: true,
      actionSlot: (): void => {
        this.actionButtons(addr)
      },
      onCardClick: () => {
        this.vm.onAddressClick(addr);
      }
    })
  }

  @Builder
  addressList() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      itemKey: (item: Object, index: number): string => {
        const a: Address = item as Address;
        return 'address_' + a.id + '_' + a.contact + '_' + a.phone + '_' + a.province + '_' + a.city + '_' +
          a.district + '_' + a.address + '_' + a.isDefault;
      },
      itemBuilder: (item: Object, index: number): void => {
        this.addressItem(item as Address)
      }
    })
  }

  @Builder
  pageContent() {
    NetWorkStateView({
      uiState: this.vm.uiState,
      useCustomLoading: true,
      customLoading: (): void => {
        this.loadingSkeleton()
      },
      onRetry: () => {
        this.vm.retryRequest();
      },
      content: (): void => {
        this.addressList()
      }
    })
  }

  @Builder
  bottomBar() {
    AppBottomButton({
      btnText: $r('app.string.address_add_new'),
      onBtnClick: () => {
        AddressListViewModel.toAddressDetail(false, 0);
      }
    })
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.address_list_title'),
        hasBottomBar: this.vm.uiState !== 'loading' && this.vm.uiState !== 'error',
        bottomBar: (): void => {
          this.bottomBar()
        },
        content: (): void => {
          this.pageContent()
        }
      })
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
