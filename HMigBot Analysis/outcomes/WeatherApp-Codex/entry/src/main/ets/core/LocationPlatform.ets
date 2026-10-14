import { abilityAccessCtrl, Permissions, Want } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { connection } from '@kit.NetworkKit';
import { Coordinates } from './Models';
import { Runtime } from './Runtime';

export const LOCATION_SERVICE_MESSAGE: string =
  'Enables the location service to retrieve weather data for the current location.';
export const LOCATION_SETTINGS_ACTION: string = 'Settings';

export interface LocationFeed {
  permissionGranted(): boolean;
  preciseGranted(): boolean;
  enabled(): boolean;
  current(precise: boolean): Promise<Coordinates | null>;
  last(): Promise<Coordinates | null>;
  requestPermissions(): Promise<boolean>;
  openSettings(): Promise<void>;
}

export class NativeLocationFeed implements LocationFeed {
  protected granted(permission: Permissions): boolean {
    const context = Runtime.context;
    if (context === null) { return false; }
    return abilityAccessCtrl.createAtManager().checkAccessTokenSync(
      context.applicationInfo.accessTokenId, permission) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }
  permissionGranted(): boolean {
    return this.granted('ohos.permission.APPROXIMATELY_LOCATION');
  }
  preciseGranted(): boolean {
    return this.permissionGranted() && this.granted('ohos.permission.LOCATION');
  }
  enabled(): boolean { return geoLocationManager.isLocationEnabled(); }
  async current(precise: boolean): Promise<Coordinates | null> {
    // GMS balanced accuracy has no exact native equivalent; LOW_POWER is the native coarse mapping.
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: precise ? geoLocationManager.LocationRequestPriority.ACCURACY :
        geoLocationManager.LocationRequestPriority.LOW_POWER,
      scenario: geoLocationManager.LocationRequestScenario.UNSET
    };
    const value = await geoLocationManager.getCurrentLocation(request);
    return value == null ? null : new Coordinates(value.latitude, value.longitude);
  }
  async last(): Promise<Coordinates | null> {
    const value = geoLocationManager.getLastLocation();
    return value == null ? null : new Coordinates(value.latitude, value.longitude);
  }
  async requestPermissions(): Promise<boolean> {
    const context = Runtime.context;
    if (context === null) { throw new Error('Runtime.init must precede permission requests'); }
    const permissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions);
    return this.permissionGranted();
  }
  async openSettings(): Promise<void> {
    const context = Runtime.context;
    if (context === null) { throw new Error('Runtime.init must precede system settings'); }
    // HarmonyOS official FAQ faqs-location-22: explicit Settings target and bare URI.
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'location_manager_settings'
    };
    await context.startAbility(want);
  }
}

export class LocationPlatform {
  private location: Coordinates = new Coordinates(40.72, -74.00);
  private feed: LocationFeed;
  private disposed: boolean = false;
  constructor(feed: LocationFeed = new NativeLocationFeed()) { this.feed = feed; }
  getLocation(): Coordinates { return this.location; }
  setLocation(location: Coordinates): void { if (!this.disposed) { this.location = location; } }
  dispose(): void { this.disposed = true; }
  isPermissionGranted(): boolean { return this.feed.permissionGranted(); }
  isProviderEnabled(): boolean { return this.feed.enabled(); }
  async requestLocation(): Promise<Coordinates> {
    if (this.disposed || !this.feed.permissionGranted()) { return this.location; }
    const value = this.feed.enabled() ? await this.feed.current(this.feed.preciseGranted()) : await this.feed.last();
    if (this.disposed) { return this.location; }
    if (value !== null) { this.location = value; } else { console.info('LocationService: location is null'); }
    return this.location;
  }
  async handlePermission(): Promise<boolean> {
    const granted = this.feed.permissionGranted() || await this.feed.requestPermissions();
    if (!granted) { console.info('LocationService: permission not enabled'); return false; }
    // Caller displays the source message and sole Settings action; never refresh in this callback.
    return !this.feed.enabled();
  }
  async openSettings(): Promise<void> { await this.feed.openSettings(); }
}

export function hasInternetConnection(): boolean {
  try {
    const net = connection.getDefaultNetSync();
    if (net.netId === 0) { return false; }
    const capabilities = connection.getNetCapabilitiesSync(net);
    return capabilities.bearerTypes.includes(connection.NetBearType.BEARER_WIFI) ||
      capabilities.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR) ||
      capabilities.bearerTypes.includes(connection.NetBearType.BEARER_ETHERNET) ||
      (capabilities.networkCap !== undefined &&
        capabilities.networkCap.includes(connection.NetCap.NET_CAPABILITY_INTERNET));
  } catch (error) { console.error('ConnectionNetworkProvider: ' + String(error)); return false; }
}
