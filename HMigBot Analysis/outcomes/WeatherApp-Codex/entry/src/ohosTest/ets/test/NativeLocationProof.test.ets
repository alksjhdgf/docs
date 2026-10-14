import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';

async function proveNativeLocation(fine: boolean): Promise<void> {
  let approximateGranted: boolean = false;
  let preciseGranted: boolean = false;
  let preciseDenied: boolean = false;
  let enabled: boolean = false;
  try {
    const applicationContext = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
      .getApplicationContext();
    const tokenId: number = applicationContext.applicationInfo.accessTokenId;
    const access = abilityAccessCtrl.createAtManager();
    const approximate = access.checkAccessTokenSync(tokenId, 'ohos.permission.APPROXIMATELY_LOCATION');
    const precise = access.checkAccessTokenSync(tokenId, 'ohos.permission.LOCATION');
    approximateGranted = approximate === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    preciseGranted = precise === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    preciseDenied = precise === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
    enabled = geoLocationManager.isLocationEnabled();
  } catch (error) {
    const code: number = (error as BusinessError).code;
    console.info(`[NativeLocationProof] precondition errorCode=${code}`);
    throw new Error(`Native location precondition errorCode=${code}`);
  }
  console.info(`[NativeLocationProof] fine=${fine} approximateGranted=${approximateGranted} ` +
    `preciseGranted=${preciseGranted} preciseDenied=${preciseDenied} enabled=${enabled}`);
  expect(approximateGranted).assertTrue();
  expect(fine ? preciseGranted : preciseDenied).assertTrue();
  expect(enabled).assertTrue();

  const request: geoLocationManager.CurrentLocationRequest = {
    priority: fine ? geoLocationManager.LocationRequestPriority.ACCURACY :
      geoLocationManager.LocationRequestPriority.LOW_POWER,
    timeoutMs: 12000
  };
  let location: geoLocationManager.Location;
  try {
    location = await geoLocationManager.getCurrentLocation(request);
  } catch (error) {
    const code: number = (error as BusinessError).code;
    console.info(`[NativeLocationProof] locate errorCode=${code}`);
    throw new Error(`Native getCurrentLocation errorCode=${code}`);
  }
  // Assert booleans, never coordinate values: Hypium prints failed assertion operands.
  const latitudeValid: boolean = Number.isFinite(location.latitude) &&
    location.latitude >= -90 && location.latitude <= 90;
  const longitudeValid: boolean = Number.isFinite(location.longitude) &&
    location.longitude >= -180 && location.longitude <= 180;
  const accuracyValid: boolean = Number.isFinite(location.accuracy) &&
    location.accuracy > 0 && location.accuracy <= 40075017;
  console.info(`[NativeLocationProof] latitudeValid=${latitudeValid} longitudeValid=${longitudeValid} ` +
    `accuracyValid=${accuracyValid}`);
  if (Number.isFinite(location.accuracy)) {
    console.info(`[NativeLocationProof] accuracy=${location.accuracy}`);
  }
  expect(latitudeValid).assertTrue();
  expect(longitudeValid).assertTrue();
  expect(accuracyValid).assertTrue();
}

export default function nativeLocationProof(): void {
  describe('NativeLocationFine', () => {
    it('realFineLocationWithPrecisePermission', 0, async (): Promise<void> => {
      await proveNativeLocation(true);
    });
  });
  describe('NativeLocationCoarse', () => {
    it('realCoarseLocationWithoutPrecisePermission', 0, async (): Promise<void> => {
      await proveNativeLocation(false);
    });
  });
}
