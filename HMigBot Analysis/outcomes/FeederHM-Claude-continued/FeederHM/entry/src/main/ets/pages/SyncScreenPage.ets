/**
 * SyncScreenPage —— 源 ui/compose/sync/SyncScreen.kt（SyncScreen / DualSyncScreen / SyncSetupScreen /
 * SyncJoinScreen / SyncDeviceListScreen / SyncAddNewDeviceScreen）+ NavigationDestinations SyncScreenDestination。
 * 参数 SyncParam{ syncCode, secretKey }（深链 /sync/join?sync_code=&key= 预填，SY-A12）。
 *
 * 结构（源 SyncScaffold → Scaffold(topBar = SensibleTopAppBar)）：
 *   NavDestination
 *    └ Column [padding top = 状态栏避让（SY-A01）, bottom = 导航条避让]
 *       ├ SyncTopBar（返回 + 标题 + 仅入链时的溢出菜单 Leave sync chain，SY-A17）
 *       └ Scroll（layoutWeight 1）
 *           ├ 单栏：Setup | Join | DeviceList | AddNewDevice（淡入淡出）
 *           └ 双栏（宽度类非 Compact，SY-A23）：Row[ 左 Setup|DeviceList(无添加按钮) ‖ 右 Join|AddNewDevice ]
 * 进入即拉取设备列表（SY-A14）；扫码用 ScanKit 默认扫码界面（SY-A05/A06）。
 */
import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { SyncParam } from '../core/app/RouteParams';
import { LayoutAdapt, ScreenType, WindowMetrics } from '../core/platform/LayoutAdapt';
import { FeederTheme } from '../ui/common/Theme';
import { openConfirmDialog } from '../ui/common/Dialogs';
import { installSyncChain } from '../features/sync/SyncChain';
import {
  LeftScreenToShow, RightScreenToShow, SyncScreenToShow, SyncScreenViewModel, secretKeyQueryParam, syncCodeQueryParam
} from '../features/sync/SyncScreenViewModel';
import {
  SyncAddNewDeviceContent, SyncDeviceListContent, SyncJoinContent, SyncSetupContent, SyncTopBar
} from '../features/sync/SyncScreenContent';

const LOG_TAG: string = 'FEEDER_SYNCSCREEN';
/** ScanKit：用户取消扫码 */
const SCAN_USER_CANCELED: number = 1000500002;

@Builder
export function SyncScreenPageBuilder() {
  SyncScreenPage()
}

@ComponentV2
struct SyncScreenPage {
  @Local vm: SyncScreenViewModel = new SyncScreenViewModel();
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  private scroller: Scroller = new Scroller();
  private started: boolean = false;
  private disposed: boolean = false;

  aboutToDisappear(): void {
    this.disposed = true;
    this.vm.dispose();
  }

  /** 双栏左侧内容变化 → 滚回顶部（源 LaunchedEffect(leftScreenToShow) scrollTo(0)）；单栏换屏同理 */
  @Monitor('vm.screenToShow', 'vm.remoteSyncChainId')
  onScreenChanged(): void {
    try {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
      console.debug(LOG_TAG, 'scroll reset skipped');
    }
  }

  private onRouteParam(p: SyncParam | null): void {
    if (this.started) {
      return;
    }
    this.started = true;
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    AppBootstrap.ready().then(async (): Promise<void> => {
      await installSyncChain(ctx !== undefined ? ctx : null);
      if (this.disposed) {
        return;
      }
      this.vm.start(p !== null ? p.syncCode : '', p !== null ? p.secretKey : '', p !== null);
      // SY-A14：进入即拉取设备列表
      this.vm.updateDeviceList();
    }).catch((e: Error) => {
      console.error(LOG_TAG, `start failed: ${e?.message}`);
    });
  }

  private isDual(): boolean {
    return this.metrics.screenType === ScreenType.DUAL;
  }

  /** 源 onNavigateUp：pop，无上一页时到 Settings */
  private leaveSyncSettings(): void {
    DeepLinkRouter.backOr(() => {
      DeepLinkRouter.navigateToSettings();
    });
  }

  /** SY-A22 */
  private handleBack(): boolean {
    if (!this.isDual()) {
      const s: SyncScreenToShow = this.vm.singleScreenToShow;
      if (s === SyncScreenToShow.JOIN) {
        this.vm.setScreen(SyncScreenToShow.SETUP);
        return true;
      }
      if (s === SyncScreenToShow.ADD_DEVICE) {
        this.vm.setScreen(SyncScreenToShow.DEVICELIST);
        return true;
      }
    }
    this.leaveSyncSettings();
    return true;
  }

  /** SY-A16：本机 → 离开同步链；否则服务器移除 */
  private onDeleteDevice(deviceId: number): void {
    if (deviceId === this.vm.deviceId) {
      this.vm.leaveSyncChain();
    } else {
      this.vm.removeDevice(deviceId);
    }
  }

  /** SY-A17 */
  private onLeaveSyncChain(): void {
    openConfirmDialog(this.getUIContext(), $r('app.string.leave_sync_chain'),
      $r('app.string.are_you_sure_leave_sync_chain'), () => {
        this.vm.leaveSyncChain();
      }, () => {
        console.debug(LOG_TAG, 'leave dialog dismissed');
      });
  }

  /** SY-A05/A06：切到加入页；同步码为空则拉起扫码器 */
  private onScanSyncCode(): void {
    const syncCodeEmpty: boolean = this.vm.syncCode.length === 0;
    this.vm.setScreen(SyncScreenToShow.JOIN);
    if (!syncCodeEmpty) {
      return;
    }
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.vm.onMissingBarCodeScanner(this.getUIContext());
      return;
    }
    const opts: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.ALL],
      enableMultiMode: false,
      enableAlbum: true
    };
    try {
      scanBarcode.startScanForResult(ctx, opts).then((result: scanBarcode.ScanResult) => {
        this.onScanResult(result.originalValue);
      }).catch((e: BusinessError) => {
        if (e.code === SCAN_USER_CANCELED) {
          return;
        }
        console.error(LOG_TAG, `scan failed: ${e.code} ${e.message}`);
        this.vm.onMissingBarCodeScanner(this.getUIContext());
      });
    } catch (e) {
      console.error(LOG_TAG, `scanner unavailable: ${JSON.stringify(e)}`);
      this.vm.onMissingBarCodeScanner(this.getUIContext());
    }
  }

  private onScanResult(value: string): void {
    const code: string = syncCodeQueryParam(value);
    if (code.trim().length > 0) {
      this.vm.setSyncCode(code);
    }
    const secretKey: string = secretKeyQueryParam(value);
    if (secretKey.trim().length > 0) {
      this.vm.setSecretKey(secretKey);
    }
  }

  private barTitle(): Resource {
    if (this.isDual()) {
      return $r('app.string.device_sync');
    }
    const s: SyncScreenToShow = this.vm.singleScreenToShow;
    if (s === SyncScreenToShow.JOIN) {
      return $r('app.string.join_sync_chain');
    }
    if (s === SyncScreenToShow.ADD_DEVICE) {
      return $r('app.string.add_new_device');
    }
    return $r('app.string.device_sync');
  }

  private leaveSyncVisible(): boolean {
    if (this.isDual()) {
      return this.vm.leftScreenToShow === LeftScreenToShow.DEVICELIST;
    }
    return this.vm.singleScreenToShow === SyncScreenToShow.DEVICELIST;
  }

  @Builder
  setupBuilder() {
    SyncSetupContent({
      onScanSyncCode: () => {
        this.onScanSyncCode();
      },
      onStartNewSyncChain: () => {
        this.vm.startNewSyncChain();
      }
    })
  }

  @Builder
  joinBuilder() {
    SyncJoinContent({
      syncCode: this.vm.syncCode,
      secretKey: this.vm.secretKey,
      onSetSyncCode: (value: string) => {
        this.vm.setSyncCode(value);
      },
      onSetSecretKey: (value: string) => {
        this.vm.setSecretKey(value);
      },
      onJoinSyncChain: (syncCode: string, secretKey: string) => {
        this.vm.joinSyncChain(syncCode, secretKey);
      }
    })
  }

  @Builder
  deviceListBuilder(showAddDeviceButton: boolean) {
    SyncDeviceListContent({
      currentDeviceId: this.vm.deviceId,
      devices: this.vm.deviceList,
      showAddDeviceButton: showAddDeviceButton,
      onAddNewDevice: () => {
        this.vm.setScreen(SyncScreenToShow.ADD_DEVICE);
      },
      onDeleteDevice: (deviceId: number) => {
        this.onDeleteDevice(deviceId);
      }
    })
  }

  @Builder
  addDeviceBuilder() {
    SyncAddNewDeviceContent({ syncUrl: this.vm.addNewDeviceUrl })
  }

  @Builder
  singleBuilder() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.vm.singleScreenToShow === SyncScreenToShow.SETUP) {
        Column() {
          this.setupBuilder()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      } else if (this.vm.singleScreenToShow === SyncScreenToShow.JOIN) {
        Column() {
          this.joinBuilder()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      } else if (this.vm.singleScreenToShow === SyncScreenToShow.DEVICELIST) {
        Column() {
          this.deviceListBuilder(true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      } else {
        Column() {
          this.addDeviceBuilder()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      }
    }
    .width('100%')
  }

  @Builder
  dualBuilder() {
    Row() {
      Column() {
        if (this.vm.leftScreenToShow === LeftScreenToShow.SETUP) {
          this.setupBuilder()
        } else {
          this.deviceListBuilder(false)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Column() {
        if (this.vm.rightScreenToShow === RightScreenToShow.ADD_DEVICE) {
          this.addDeviceBuilder()
        } else {
          this.joinBuilder()
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        SyncTopBar({
          barTitle: this.barTitle(),
          leaveSyncVisible: this.leaveSyncVisible(),
          onNavigateUp: () => {
            this.handleBack();
          },
          onLeaveSyncChain: () => {
            this.onLeaveSyncChain();
          }
        })
        Scroll(this.scroller) {
          Column() {
            if (this.isDual()) {
              this.dualBuilder()
            } else {
              this.singleBuilder()
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .padding({ top: this.avoid.top, bottom: this.avoid.bottom })
      .backgroundColor(FeederTheme.colors.surface)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.surface)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      this.onRouteParam(p !== undefined && p instanceof SyncParam ? p as SyncParam : null);
    })
    .onBackPressed((): boolean => this.handleBack())
  }
}
