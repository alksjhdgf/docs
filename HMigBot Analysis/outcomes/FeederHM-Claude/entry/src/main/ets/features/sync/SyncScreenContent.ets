/**
 * SyncScreenContent —— 源 ui/compose/sync/SyncScreen.kt 的子组合项：SyncScaffold 顶栏、SyncSetupContent、
 * SyncJoinContent、SyncDeviceListContent（含 DeviceEntry / DeleteDeviceDialog）、SyncAddNewDeviceContent。
 * 布局以源 Compose 层级为规格（Column/Row 1:1，dp→vp），颜色走 FeederTheme token。
 */
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SyncDevice } from '../../core/db/SyncDaos';
import { KOFI_URL } from '../../core/util/Constants';
import { ActivityLauncher, browserWant } from '../../core/platform/LinkOpener';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { openConfirmDialog } from '../../ui/common/Dialogs';
import { AesCbcWithIntegrity } from './SyncCrypto';
import { syncCodeQueryParam } from './SyncScreenViewModel';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';

const LOG_TAG: string = 'FEEDER_SYNCSCREEN';
const MIN_TOUCH: number = 48;

/** 源 openKoFiIntent()：ACTION_VIEW KOFI_URL（openAdjacentIfSuitable = true） */
export function openKoFi(): void {
  const launcher: ActivityLauncher | null = ActivityLauncher.instance();
  if (launcher === null) {
    console.warn(LOG_TAG, 'ActivityLauncher not bound');
    return;
  }
  launcher.startAbility(true, browserWant(KOFI_URL)).catch((e: Error) => {
    console.error(LOG_TAG, `open ko-fi failed: ${e?.message}`);
  });
}

/** SY-A21：系统分享面板，纯文本链接，标题 feeder_device_sync_code */
export async function shareSyncLink(ui: UIContext, link: string): Promise<void> {
  try {
    const ctx: common.Context | undefined = ui.getHostContext();
    if (ctx === undefined) {
      return;
    }
    const intentTitle: string = ctx.resourceManager.getStringByNameSync('feeder_device_sync_code');
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      content: link,
      title: intentTitle
    };
    const controller: systemShare.ShareController = new systemShare.ShareController(new systemShare.SharedData(record));
    const options: systemShare.ShareControllerOptions = {};
    await controller.show(ctx as common.UIAbilityContext, options);
  } catch (e) {
    console.error(LOG_TAG, `share failed: ${JSON.stringify(e)}`);
  }
}

// ================================================================== SyncScaffold 顶栏

@ComponentV2
export struct SyncTopBar {
  @Param barTitle: ResourceStr = '';
  @Param leaveSyncVisible: boolean = false;
  @Event onNavigateUp: () => void = () => {
    console.info('TODO:onNavigateUp:SyncTopBar');
  };
  @Event onLeaveSyncChain: () => void = () => {
    console.info('TODO:onLeaveSyncChain:SyncTopBar');
  };
  @Local showMenu: boolean = false;

  @Builder
  iconGlyph(icon: Resource) {
    SymbolGlyph(icon)
      .fontSize(24)
      .fontColor([FeederTheme.colors.onSurfaceVariant])
  }

  @Builder
  menuBuilder() {
    Column() {
      Row() {
        Text($r('app.string.leave_sync_chain'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
      }
      .width('100%')
      .constraintSize({ minWidth: 112, minHeight: MIN_TOUCH })
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.showMenu = false;
        this.onLeaveSyncChain();
      })
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, bottom: 8 })
    // UT-A44：源 SyncScreen.kt:157 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.showMenu = false;
    }))
  }

  build() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.iconGlyph($r('sys.symbol.arrow_left'))
      }
      .width(MIN_TOUCH)
      .height(MIN_TOUCH)
      .margin({ left: 4 })
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.go_back'))
      .onClick(() => {
        this.onNavigateUp();
      })

      Text(this.barTitle)
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
        .margin({ left: 4, right: 4 })

      if (this.leaveSyncVisible) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          this.iconGlyph($r('sys.symbol.dot_grid_1x2'))
        }
        .width(MIN_TOUCH)
        .height(MIN_TOUCH)
        .margin({ right: 4 })
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.open_menu'))
        .onClick(() => {
          this.showMenu = true;
        })
        .bindMenu(this.showMenu, (): void => {
          this.menuBuilder()
        }, {
          onDisappear: () => {
            this.showMenu = false;
          }
        })
      }
    }
    .width('100%')
    .height(64)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FeederTheme.colors.surface)
  }
}

// ================================================================== 共用小件

@ComponentV2
export struct SyncBodyText {
  @Param text: ResourceStr = '';
  @Param topPadding: number = 0;

  build() {
    Text(this.text)
      .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
      .width('100%')
      .padding({ top: this.topPadding })
      .textAlign(TextAlign.Start)
  }
}

/** 源 LinkTextStyle（primary + 下划线）的 Ko-fi 链接；非 play 构建可见 */
@ComponentV2
export struct KoFiLink {
  build() {
    Text(KOFI_URL)
      .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.primary))
      .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
      .width('100%')
      .textAlign(TextAlign.Start)
      .onClick(() => {
        openKoFi();
      })
  }
}

// ================================================================== SyncSetupContent（SY-A02）

@ComponentV2
export struct SyncSetupContent {
  @Event onScanSyncCode: () => void = () => {
    console.info('TODO:onScanSyncCode:SyncSetupContent');
  };
  @Event onStartNewSyncChain: () => void = () => {
    console.info('TODO:onStartNewSyncChain:SyncSetupContent');
  };

  build() {
    Column({ space: 8 }) {
      SyncBodyText({ text: $r('app.string.device_sync_description_1') })
      SyncBodyText({ text: $r('app.string.device_sync_description_2') })
      SyncBodyText({ text: $r('app.string.device_sync_financed_by_community') })
      // Google Play does not allow direct donation links（鸿蒙为非 play 构建）
      KoFiLink()
      Text($r('app.string.device_sync_beta_warning'))
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .width('100%')
        .textAlign(TextAlign.Start)

      Row().height(24).width(24)

      Button() {
        Text($r('app.string.scan_or_enter_code'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onPrimary))
      }
      .type(ButtonType.Capsule)
      .height(40)
      .padding({ left: 24, right: 24 })
      .backgroundColor(FeederTheme.colors.primary)
      .onClick(() => {
        this.onScanSyncCode();
      })
      Button() {
        Text($r('app.string.start_new_sync_chain'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.primary))
      }
      .type(ButtonType.Capsule)
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onStartNewSyncChain();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
  }
}

// ================================================================== SyncJoinContent（SY-A07..A09）

@ComponentV2
export struct SyncJoinContent {
  @Param syncCode: string = '';
  @Param secretKey: string = '';
  @Event onSetSyncCode: (value: string) => void = (value: string) => {
    console.info(`TODO:onSetSyncCode:SyncJoinContent ${value.length}`);
  };
  @Event onSetSecretKey: (value: string) => void = (value: string) => {
    console.info(`TODO:onSetSecretKey:SyncJoinContent ${value.length}`);
  };
  @Event onJoinSyncChain: (syncCode: string, secretKey: string) => void = (syncCode: string, secretKey: string) => {
    console.info(`TODO:onJoinSyncChain:SyncJoinContent ${syncCode.length} ${secretKey.length}`);
  };

  private syncCodeError(): boolean {
    return syncCodeQueryParam(this.syncCode).length !== 64;
  }

  private secretKeyError(): boolean {
    return !AesCbcWithIntegrity.isKeyDecodable(this.secretKey);
  }

  @Builder
  fieldLabel(label: Resource, isError: boolean) {
    Text(label)
      .attributeModifier(textStyle(M3Type.bodySmall, false,
        isError ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant))
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })
      .textAlign(TextAlign.Start)
  }

  build() {
    Column({ space: 8 }) {
      Column() {
        this.fieldLabel($r('app.string.sync_code'), this.syncCodeError())
        TextInput({ text: this.syncCode })
          .editMenuOptions(new FeederEditMenuOptions((): string => this.syncCode))
          .width('100%')
          .constraintSize({ minHeight: 40 })
          .backgroundColor(Color.Transparent)
          .fontColor(FeederTheme.colors.onSurface)
          .caretColor(this.syncCodeError() ? FeederTheme.colors.error : FeederTheme.colors.primary)
          .accessibilityText($r('app.string.sync_code'))
          .onChange((value: string) => {
            this.onSetSyncCode(value);
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
      .borderRadius({ topLeft: 4, topRight: 4 })
      .border({
        width: { bottom: this.syncCodeError() ? 2 : 1 },
        color: { bottom: this.syncCodeError() ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant }
      })

      Column() {
        this.fieldLabel($r('app.string.secret_key'), this.secretKeyError())
        TextArea({ text: this.secretKey })
          .editMenuOptions(new FeederEditMenuOptions((): string => this.secretKey))
          .width('100%')
          .constraintSize({ minHeight: 40 })
          .backgroundColor(Color.Transparent)
          .fontColor(FeederTheme.colors.onSurface)
          .caretColor(this.secretKeyError() ? FeederTheme.colors.error : FeederTheme.colors.primary)
          .accessibilityText($r('app.string.secret_key'))
          .onChange((value: string) => {
            this.onSetSecretKey(value);
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
      .borderRadius({ topLeft: 4, topRight: 4 })
      .border({
        width: { bottom: this.secretKeyError() ? 2 : 1 },
        color: { bottom: this.secretKeyError() ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant }
      })

      Button() {
        Text($r('app.string.join_sync_chain'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onPrimary))
      }
      .type(ButtonType.Capsule)
      .height(40)
      .padding({ left: 24, right: 24 })
      .backgroundColor(FeederTheme.colors.primary)
      .enabled(!this.syncCodeError())
      .opacity(this.syncCodeError() ? 0.38 : 1)
      .onClick(() => {
        this.onJoinSyncChain(this.syncCode, this.secretKey);
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
  }
}

// ================================================================== SyncDeviceListContent（SY-A13/A15）

@ComponentV2
export struct DeviceEntry {
  @Param currentDeviceId: number = 0;
  @Param device: SyncDevice = new SyncDevice();
  @Event onDelete: () => void = () => {
    console.info('TODO:onDelete:DeviceEntry');
  };

  build() {
    Row() {
      Text(this.device.deviceId === this.currentDeviceId ?
        $r('app.string.this_device', this.device.deviceName) : this.device.deviceName)
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurfaceVariant])
      }
      .width(MIN_TOUCH)
      .height(MIN_TOUCH)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.disconnect_device_from_sync'))
      .onClick(() => {
        this.onDelete();
      })
    }
    .width('100%')
    .constraintSize({ minHeight: MIN_TOUCH })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct SyncDeviceListContent {
  @Param currentDeviceId: number = 0;
  @Param devices: SyncDevice[] = [];
  @Param showAddDeviceButton: boolean = true;
  @Event onAddNewDevice: () => void = () => {
    console.info('TODO:onAddNewDevice:SyncDeviceListContent');
  };
  @Event onDeleteDevice: (deviceId: number) => void = (deviceId: number) => {
    console.info(`TODO:onDeleteDevice:SyncDeviceListContent ${deviceId}`);
  };

  /** 源 DeleteDeviceDialog：OK → onDeleteDevice；Cancel/外部 → 不做任何事 */
  private confirmDelete(device: SyncDevice): void {
    const deviceId: number = device.deviceId;
    openConfirmDialog(this.getUIContext(), $r('app.string.remove_device'),
      $r('app.string.remove_device_question', device.deviceName), () => {
        this.onDeleteDevice(deviceId);
      }, () => {
        console.debug(LOG_TAG, 'remove device dismissed');
      });
  }

  build() {
    Column() {
      Text($r('app.string.devices_on_sync_chain'))
        .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .textAlign(TextAlign.Start)
      ForEach(this.devices, (device: SyncDevice) => {
        DeviceEntry({
          currentDeviceId: this.currentDeviceId,
          device: device,
          onDelete: () => {
            this.confirmDelete(device);
          }
        })
      }, (device: SyncDevice): string => `${device.id}|${device.deviceId}|${device.deviceName}|${this.currentDeviceId}`)
      SyncBodyText({ text: $r('app.string.device_sync_financed_by_community'), topPadding: 8 })
      // Google Play does not allow direct donation links（鸿蒙为非 play 构建）
      KoFiLink()
      if (this.showAddDeviceButton) {
        Button() {
          Text($r('app.string.add_new_device'))
            .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onPrimary))
            .textAlign(TextAlign.Center)
        }
        .type(ButtonType.Capsule)
        .height(40)
        .margin({ top: 8 })
        .padding({ left: 24, right: 24 })
        .backgroundColor(FeederTheme.colors.primary)
        .onClick(() => {
          this.onAddNewDevice();
        })
      }
      Row().height(8).width(8)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
  }
}

// ================================================================== SyncAddNewDeviceContent（SY-A19..A21）

@ComponentV2
export struct SyncAddNewDeviceContent {
  @Param syncUrl: string = '';

  build() {
    Column({ space: 8 }) {
      SyncBodyText({ text: $r('app.string.press_scan_sync') })
      SyncBodyText({ text: $r('app.string.or_open_device_sync_link') })
      Text($r('app.string.treat_like_password'))
        .attributeModifier(textStyle(M3Type.bodyLarge, false, Color.Red))
        .width('100%')
        .textAlign(TextAlign.Start)
      QRCode(this.syncUrl)
        .width(250)
        .height(250)
        .color(Color.Black)
        .backgroundColor(Color.White)
        .accessibilityText($r('app.string.qr_code'))
      Text(this.syncUrl)
        .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.primary))
        .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
        .width('100%')
        .textAlign(TextAlign.Start)
        .onClick(() => {
          shareSyncLink(this.getUIContext(), this.syncUrl).catch((e: Error) => {
            console.error(LOG_TAG, `share failed: ${e?.message}`);
          });
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
  }
}
