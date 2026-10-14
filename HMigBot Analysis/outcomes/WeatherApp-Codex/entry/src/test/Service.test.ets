import { describe, it, expect } from '@ohos/hypium';
import { Permissions } from '@kit.AbilityKit';
import { Coordinates, Forecast, DayForecast, Temperature, WindSpeed, Pressure, Place, Snapshot, Settings } from '../main/ets/core/Models';
import { WeatherService, ServiceStore, parseSavedSnapshot, ProtoDataStoreRepository,
  DataStoreSerializer } from '../main/ets/core/WeatherService';
import { LocationFeed, LocationPlatform, NativeLocationFeed } from '../main/ets/core/LocationPlatform';
import { OpenMeteoClient } from '../main/ets/data/OpenMeteoClient';
import { GeoNamesClient } from '../main/ets/data/GeoNamesClient';
import { DataStoreProto } from '../main/ets/protobuf/datastore';
import { TemperatureProto } from '../main/ets/protobuf/temperature';
import { encodeSnapshot, decodeSnapshot } from '../main/ets/core/BinarySnapshot';
import { BinaryStore } from '../main/ets/core/Runtime';

// Source-derived behavior probes with injected inputs, NOT source golden fixtures.
// DP-A02 expectation: 初始化逐调用：Activity `super.onCreate→EdgeToEdge→inflate→setContentView→ViewModelProvider.get→首次装 MainFragment`；VM 构造 `initData→订阅缓存 forecast→订阅 settings→同步设置温度/速度/压力偏好`；settings 成功发布地名并 setLocation，空/错保留 provider 坐标，终止后 `fetchCurrentWeatherAndPlace→requestLocation→fetchWeatherAndPlace→天气请求、地名请求`；两请求互不等待，无原子合并
// anchor: MainActivity.java:28；MainViewModel.java:59、75、182。
// DP-A03 expectation: provider 初值 `(40.72,-74.00)`；未授权直接返回内存坐标；有授权且 GPS/网络任一启用用 current，否则 last；非空定位更新内存，null 保留原值；定位失败仅日志，不自动继续天气/地名请求
// anchor: FusedLocationProvider.java:30、44、95；MainViewModel.java:182。
// DP-A04 expectation: 天气/地名/搜索各有 `Loading→Success|Error`；Loading/Error 不携带旧数据，但 UI 天气错误不清空已有控件；天气错误 toast，地名错误只日志，搜索错误 toast。离线文案 `Turn on mobile data or connect to a Wi-Fi network`；请求错误 `Couldn't get the weather forecast` / `Couldn't get the name of the area`（硬编码英语）
// anchor: MainViewModel.java:205、272、313；Resource.java:49；MainFragment.java:169；SearchMenuFragment.java:73；values/strings.xml:65。
// DP-A06 expectation: `swipeRefresh` 下拉先处理授权再立即定位刷新（不等待授权回调）；`searchBtn` 打开搜索，`settingsBtn` 进入设置；搜索仅提交 `searchView` 发请求，输入变化不请求；点 `rvSearchList` 条目字符串坐标转 double→setLocation→天气/地名请求→关闭弹层
// anchor: MainFragment.java:110；SearchMenuFragment.java:55。
// DP-A07 expectation: 首次首页或下拉未有 fine/coarse 任一权限时请求两项；任一授予检查 provider，无授予仅日志；授权回调不会立即刷新（调用被注释）。真机需验证拒绝后仍能按已存/默认坐标取天气
// anchor: MainFragment.java:223、238；FusedLocationProvider.java:46。
// DP-A21 expectation: `languagePrefs` 默认 `en`，仅 `English/en`、`Русский/ru`；切换先按新Locale请求当前坐标地名，再 updateLocale；`temperaturePrefs` 默认 `celsius`，选项 `Degrees Celsius (°C)/celsius`、`Degrees Fahrenheit (°F)/fahrenheit`
// anchor: root_preferences.xml:3；values/arrays.xml:2；values/strings.xml:90；SettingsFragment.java:80。
// DP-A22 expectation: `windSpeedPrefs` 默认 `kmh`，完整选项 `Kilometers per hour (km/h)/kmh`、`Meters per second (m/s)/ms`、`Miles per hour (mph)/mph`；`airPressurePrefs` 默认 `hpa`，完整选项 `Hectopascals (hPa)/hpa`、`Millimeters of mercury column (mmHg)/mmhg`、`Inch of mercury column (inHg)/inhg`；偏好变更本地转换已加载天气，不主动重取天气
// anchor: root_preferences.xml:22；values/arrays.xml:22；values/strings.xml:6、81；SettingsFragment.java:89。
// DP-A24 expectation: 温度切换更新当前/体感/夜间/24小时/周168项，却遗漏 dayTemp；风速/压力仅改主值及unit，diff原样保留；未有完整data时仅更新客户端单位，不发布转换结果。这些是源缺陷，不得伪称源支持一致转换
// anchor: MainViewModel.java:227、252、262、331。
// DP-A30 expectation: 只有首页 onStop 且place有data、forecast Resource非空才保存整个坐标/名称/forecast快照；不要求forecast data非空，刷新/错误可写null forecast；请求成功本身不保存；没有TTL、按城市多缓存、自动离线重取或后台刷新
// anchor: MainFragment.java:80；MainViewModel.java:120、280。
// DP-A31 expectation: 冷重启要验证已保存坐标/地名/天气读取，语言/单位偏好另存；源是异步onStop保存，不保证强杀前完成，缓存天气也未按当前偏好重转换，后续在线请求覆盖缓存；验收不能把静态存在写调用当持久化已通过
// anchor: MainFragment.java:95；MainViewModel.java:75、120。
// Native permission, settings dispatch and real cold process persistence are device gates, not asserted by this suite.

class InputStore implements ServiceStore {
  values: Map<string, string> = new Map<string, string>();
  flushes: number = 0;
  failFlush: boolean = false;
  read(key: string, fallback: string): string { return this.values.get(key) ?? fallback; }
  write(key: string, value: string): void { this.values.set(key, value); }
  async flush(): Promise<void> {
    this.flushes++; if (this.failFlush) { throw new Error('Injected storage IO failure'); }
  }
}
class InputBinaryStore extends BinaryStore {
  bytes: ArrayBuffer = new ArrayBuffer(0);
  failRead: boolean = false;
  failFlush: boolean = false;
  readBytes(): ArrayBuffer {
    if (this.failRead) { throw new Error('Injected binary read failure'); }
    return this.bytes.slice(0);
  }
  writeBytes(value: ArrayBuffer): void { this.bytes = value.slice(0); }
  async flush(): Promise<void> {
    if (this.failFlush) { throw new Error('Injected binary flush failure'); }
  }
}
class PermissionFeed extends NativeLocationFeed {
  approximate: boolean = false;
  fine: boolean = false;
  currentCalls: number = 0;
  protected granted(permission: Permissions): boolean {
    return permission === 'ohos.permission.LOCATION' ? this.fine : this.approximate;
  }
  enabled(): boolean { return true; }
  async current(precise: boolean): Promise<Coordinates | null> {
    this.currentCalls++; return new Coordinates(10, 20);
  }
}
class Deferred<T> {
  promise: Promise<T>;
  private resolveValue: ((value: T) => void) | null = null;
  private rejectValue: ((error: Error) => void) | null = null;
  constructor() {
    this.promise = new Promise<T>((resolve, reject): void => { this.resolveValue = resolve; this.rejectValue = reject; });
  }
  resolve(value: T): void { if (this.resolveValue !== null) { this.resolveValue(value); } }
  reject(): void { if (this.rejectValue !== null) { this.rejectValue(new Error('Deferred failure')); } }
}
class InputLocation implements LocationFeed {
  granted: boolean = false;
  precise: boolean = false;
  active: boolean = true;
  value: Coordinates | null = null;
  failure: boolean = false;
  currentCalls: number = 0;
  lastCalls: number = 0;
  permissionCalls: number = 0;
  permissionGranted(): boolean { return this.granted; }
  preciseGranted(): boolean { return this.precise; }
  enabled(): boolean { return this.active; }
  async current(precise: boolean): Promise<Coordinates | null> {
    this.currentCalls++; this.precise = precise;
    if (this.failure) { throw new Error('Injected location failure'); } return this.value;
  }
  async last(): Promise<Coordinates | null> { this.lastCalls++; return this.value; }
  async requestPermissions(): Promise<boolean> { this.permissionCalls++; return this.granted; }
  async openSettings(): Promise<void> { }
}
class InputWeather extends OpenMeteoClient {
  calls: number = 0;
  failure: boolean = false;
  value: Forecast = new Forecast();
  async fetchWeatherForecast(latitude: number, longitude: number): Promise<Forecast> {
    this.calls++; if (this.failure) { throw new Error('Injected weather failure'); } return this.value;
  }
}
class InputGeo extends GeoNamesClient {
  calls: number = 0;
  requestedLocale: string = '';
  queries: string[] = [];
  constructor() { super((): string => 'en'); }
  async fetchNearestPlaceInfo(latitude: number, longitude: number): Promise<Place> {
    this.calls++; this.requestedLocale = this.getLocale();
    return new Place('Injected place', '', '', 'en', '', latitude.toString(), longitude.toString());
  }
  async searchLocation(query: string): Promise<Place[]> { this.queries.push(query); return []; }
}
class PendingWeather extends InputWeather {
  pending: Deferred<Forecast> = new Deferred<Forecast>();
  async fetchWeatherForecast(latitude: number, longitude: number): Promise<Forecast> { return this.pending.promise; }
}
class PendingGeo extends InputGeo {
  place: Deferred<Place> = new Deferred<Place>();
  search: Deferred<Place[]> = new Deferred<Place[]>();
  async fetchNearestPlaceInfo(latitude: number, longitude: number): Promise<Place> { return this.place.promise; }
  async searchLocation(query: string): Promise<Place[]> { return this.search.promise; }
}
class PendingLocation extends InputLocation {
  pending: Deferred<Coordinates | null> = new Deferred<Coordinates | null>();
  async current(precise: boolean): Promise<Coordinates | null> { return this.pending.promise; }
}
class Inputs {
  store: InputStore = new InputStore();
  preferences: InputStore = new InputStore();
  feed: InputLocation = new InputLocation();
  weather: InputWeather = new InputWeather();
  geo: InputGeo = new InputGeo();
  online: boolean = true;
  localeOrder: string = '';
  service: WeatherService;
  constructor() {
    this.service = new WeatherService(this.weather, this.geo, new LocationPlatform(this.feed), this.store,
      (): boolean => this.online, (locale: string): void => { this.localeOrder = this.geo.requestedLocale + ':' + locale; },
      this.preferences);
  }
}
function temperature(value: number): Temperature { const result = new Temperature(); result.temperature = value; return result; }
function fixtureBytes(hex: string): ArrayBuffer {
  const bytes = new Uint8Array(hex.length / 2);
  for (let index = 0; index < bytes.length; index++) { bytes[index] = Number.parseInt(hex.substring(index * 2, index * 2 + 2), 16); }
  return bytes.buffer as ArrayBuffer;
}
function byteString(bytes: ArrayBuffer): string { return Array.from(new Uint8Array(bytes)).join(','); }

export default function serviceTests(): void {
  describe('SourceDerivedWeatherService', (): void => {
    it('resume-binary-serializer full independent protoc fixture maps every forecast field', 0, async (): Promise<void> => {
      // protobuf-research/forecast-fixture.textproto -> official protoc --encode=DataStoreProto.
      // Independent of TurboTrans and the application adapter under test.
      const bytes = fixtureBytes('126a0a640a080a001007187b2001120210081a0210092202100a287c307d' +
        '3a014442090a01531000180220004a090a01541003180020015208080b10' +
        '00187e20015a090a0152100c1800207f6209080d100018800120016a0708' +
        '0e10001881017202100f7a02101012021011');
      const serializer = new DataStoreSerializer();
      const snapshot = await serializer.readFrom(async (): Promise<ArrayBuffer> => bytes);
      expect(snapshot.settings === null).assertTrue();
      const day = snapshot.forecast?.dayForecast;
      if (day == null) { throw new Error('Missing full fixture forecast'); }
      expect(day.temperature?.time).assertEqual(''); expect(day.temperature?.temperature).assertEqual(7);
      expect(day.temperature?.imgIdWeatherCode).assertEqual('wire-id:123');
      expect(day.temperature?.temperatureUnit).assertEqual(1);
      expect(day.apparentTemp?.temperature).assertEqual(8); expect(day.apparentTemp?.time === null).assertTrue();
      expect(day.apparentTemp?.imgIdWeatherCode === null).assertTrue();
      expect(day.dayTemp?.temperature).assertEqual(9); expect(day.nightTemp?.temperature).assertEqual(10);
      expect(day.imgIdWeatherCode).assertEqual('wire-id:124'); expect(day.weatherCode).assertEqual('wire-id:125');
      expect(day.date).assertEqual('D'); expect(day.sunrise?.time).assertEqual('S');
      expect(day.sunrise?.hoursDiff).assertEqual(0); expect(day.sunrise?.minutesDiff).assertEqual(2);
      expect(day.sunrise?.isFuture).assertFalse(); expect(day.sunset?.time).assertEqual('T');
      expect(day.sunset?.hoursDiff).assertEqual(3); expect(day.sunset?.minutesDiff).assertEqual(0);
      expect(day.sunset?.isFuture).assertTrue(); expect(day.windSpeed?.speed).assertEqual(11);
      expect(day.windSpeed?.speedDiff).assertEqual(0); expect(day.windSpeed?.imgIdChangeWindSpeed).assertEqual('wire-id:126');
      expect(day.windSpeed?.speedUnit).assertEqual(1); expect(day.precipitationChance?.time).assertEqual('R');
      expect(day.precipitationChance?.percent).assertEqual(12); expect(day.precipitationChance?.percentDiff).assertEqual(0);
      expect(day.precipitationChance?.imgIdPrecipitationChance).assertEqual('wire-id:127');
      expect(day.pressure?.pressure).assertEqual(13); expect(day.pressure?.pressureDiff).assertEqual(0);
      expect(day.pressure?.imgIdChangePressure).assertEqual('wire-id:128'); expect(day.pressure?.pressureUnit).assertEqual(1);
      expect(day.uvIndex?.uvIndex).assertEqual(14); expect(day.uvIndex?.uvIndexDiff).assertEqual(0);
      expect(day.uvIndex?.imgIdChangeUvIndex).assertEqual('wire-id:129');
      expect(day.hourlyTempForecast.length).assertEqual(1); expect(day.hourlyTempForecast[0].temperature).assertEqual(15);
      expect(day.precipitationChanceForecast.length).assertEqual(1);
      expect(day.precipitationChanceForecast[0].percent).assertEqual(16);
      expect(snapshot.forecast?.weekTempForecast[0].temperature).assertEqual(17);
      let output = new ArrayBuffer(0);
      expect(await serializer.writeTo(snapshot, async (value: ArrayBuffer): Promise<void> => { output = value; }) === snapshot).assertTrue();
      expect(byteString(output)).assertEqual(byteString(bytes));
      const negative = TemperatureProto.decode(fixtureBytes('10ffffffffffffffffff01'));
      expect(negative?.temperature).assertEqual(-1);
      // Target resource names resolve to real target IDs, not invented Android IDs.
      if (day.temperature === null) { throw new Error('Missing fixture temperature'); }
      day.temperature.imgIdWeatherCode = 'ic_clear_day';
      const restored = decodeSnapshot(encodeSnapshot(snapshot));
      expect(restored.forecast?.dayForecast?.temperature?.imgIdWeatherCode).assertEqual('ic_clear_day');
    });
    it('resume-binary-serializer actual binary repository full APIs independent reads and distinct coordinates', 0, async (): Promise<void> => {
      const store = new InputBinaryStore(); const repository = new ProtoDataStoreRepository(store);
      expect((await repository.getDataStoreProto())?.settings === null).assertTrue();
      expect(await repository.getSettings() === null).assertTrue();
      expect(await repository.getDaysForecastResponse() === null).assertTrue();
      let calls = 0;
      const stop = repository.getFlowLocationCoord().subscribe((coord: Coordinates | null): void => { calls++; });
      expect(calls).assertEqual(0);
      let rejected = false;
      try { await repository.saveLocationCoord(new Coordinates()); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      // Independent exact byte settings fixture, latitude 1 and longitude -2.
      store.bytes = fixtureBytes('0a170a1209000000000000f03f1100000000000000c0120141');
      expect((await repository.getSettings())?.locationName).assertEqual('A');
      expect(await repository.getDaysForecastResponse() === null).assertTrue();
      repository.getFlowLocationCoord(); expect(calls).assertEqual(1);
      await repository.saveLocationCoord(new Coordinates(1, -2)); expect(calls).assertEqual(1);
      await repository.saveLocationCoord(new Coordinates(1, -3)); expect(calls).assertEqual(2);
      const forecast = new Forecast(); forecast.weekTempForecast = [temperature(17)];
      await repository.saveDaysForecastResponse(forecast); expect(calls).assertEqual(2);
      expect((await repository.getSettings())?.locationCoord?.longitude).assertEqual(-3);
      await repository.saveSettings(null);
      expect((await repository.getDaysForecastResponse())?.weekTempForecast[0].temperature).assertEqual(17);
      await repository.saveDaysForecastResponse(null);
      expect(byteString(store.bytes)).assertEqual('');
      const snapshot = new Snapshot(); snapshot.settings = new Settings(); snapshot.settings.locationName = 'Saved';
      await repository.saveDataStore(snapshot);
      expect((await repository.getDataStoreProto())?.settings?.locationName).assertEqual('Saved');
      const replacement = new InputBinaryStore(); repository.setDataStore(replacement);
      expect(repository.getDataStore() === replacement).assertTrue();
      expect(await repository.getSettings() === null).assertTrue();
      replacement.failRead = true;
      expect(await repository.getDataStoreProto() === null).assertTrue();
      expect(await repository.getSettings() === null).assertTrue();
      expect(await repository.getDaysForecastResponse() === null).assertTrue();
      rejected = false;
      try { await new DataStoreSerializer().readFrom(async (): Promise<ArrayBuffer> => { throw new Error('IO read'); }); }
      catch (error) { rejected = true; }
      expect(rejected).assertTrue(); replacement.failRead = false; replacement.failFlush = true; rejected = false;
      try { await repository.saveDataStore(snapshot); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); replacement.failFlush = false;
      await repository.saveDataStore(snapshot); expect((await repository.getSettings())?.locationName).assertEqual('Saved');
      replacement.bytes = fixtureBytes('0a020a');
      expect(await repository.getDataStoreProto() === null).assertTrue();
      stop(); repository.dispose();
    });
    it('resume-binary-serializer native empty and independent exact settings fixture', 0, (): void => {
      // Schema-derived, not generated by the codec under test:
      // settings(1): locationCoord(1): latitude double(1)=1, longitude double(2)=-2;
      // locationName string(2)="A". forecast is absent.
      const bytes = new Uint8Array([10, 23, 10, 18, 9, 0, 0, 0, 0, 0, 0, 240, 63,
        17, 0, 0, 0, 0, 0, 0, 0, 192, 18, 1, 65]);
      const decoded = DataStoreProto.decode(bytes.buffer as ArrayBuffer);
      expect(decoded !== undefined).assertTrue();
      if (decoded === undefined) { throw new Error('Native decode returned undefined'); }
      expect(decoded.settings?.locationName).assertEqual('A');
      expect(decoded.settings?.locationCoord?.latitude).assertEqual(1);
      expect(decoded.settings?.locationCoord?.longitude).assertEqual(-2);
      expect(decoded.hasForecast()).assertFalse();
      const encoded = DataStoreProto.encode(decoded);
      if (encoded === undefined) { throw new Error('Native encode returned undefined'); }
      expect(Array.from(new Uint8Array(encoded)).join(',')).assertEqual(Array.from(bytes).join(','));
      const empty = DataStoreProto.decode(new ArrayBuffer(0));
      expect(empty?.hasSettings()).assertFalse(); expect(empty?.hasForecast()).assertFalse();
      const emptyBytes = DataStoreProto.encode(new DataStoreProto());
      expect(emptyBytes?.byteLength).assertEqual(0);
    });
    it('resume-binary-serializer native optional presence and int32 wire fixture', 0, (): void => {
      // Explicit optional empty time, explicit optional zero resource ID, Fahrenheit.
      const bytes = new Uint8Array([10, 0, 16, 7, 24, 0, 32, 1]);
      const decoded = TemperatureProto.decode(bytes.buffer as ArrayBuffer);
      if (decoded === undefined) { throw new Error('Native decode returned undefined'); }
      expect(decoded.hasTime()).assertTrue(); expect(decoded.time).assertEqual('');
      expect(decoded.hasImgIdWeatherCode()).assertTrue(); expect(decoded.imgIdWeatherCode).assertEqual(0);
      expect(decoded.temperature).assertEqual(7); expect(decoded.temperatureUnit).assertEqual(1);
      const encoded = TemperatureProto.encode(decoded);
      if (encoded === undefined) { throw new Error('Native encode returned undefined'); }
      expect(Array.from(new Uint8Array(encoded)).join(',')).assertEqual(Array.from(bytes).join(','));
      const absent = TemperatureProto.decode(new ArrayBuffer(0));
      expect(absent?.hasTime()).assertFalse(); expect(absent?.hasImgIdWeatherCode()).assertFalse();
      expect(absent?.temperature).assertEqual(0); expect(absent?.temperatureUnit).assertEqual(0);
    });
    it('resume-binary-serializer native malformed bytes must not produce a successful snapshot', 0, (): void => {
      let rejected = false;
      try {
        // Truncated length-delimited settings message, length 2 but only one byte.
        const decoded = DataStoreProto.decode(new Uint8Array([10, 2, 10]).buffer as ArrayBuffer);
        rejected = decoded === undefined;
      } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
    });
    it('DP-A39 native permission truth table requires approximate; precise requires both', 0, async (): Promise<void> => {
      const feed = new PermissionFeed(); const location = new LocationPlatform(feed);
      expect(feed.permissionGranted()).assertFalse(); expect(feed.preciseGranted()).assertFalse();
      feed.fine = true;
      expect(feed.permissionGranted()).assertFalse(); expect(feed.preciseGranted()).assertFalse();
      expect((await location.requestLocation()).latitude).assertEqual(40.72); expect(feed.currentCalls).assertEqual(0);
      feed.fine = false; feed.approximate = true;
      expect(feed.permissionGranted()).assertTrue(); expect(feed.preciseGranted()).assertFalse();
      feed.fine = true; expect(feed.preciseGranted()).assertTrue();
    });
    it('DP-A34 saved streams retain independent values and support unsubscribe', 0, async (): Promise<void> => {
      const inputs = new Inputs(); const snapshot = new Snapshot(); const settings = new Settings();
      settings.locationCoord = new Coordinates(3, 4); settings.locationName = 'Cached'; snapshot.settings = settings;
      const forecast = new Forecast(); const day = new DayForecast(); day.temperature = temperature(10);
      forecast.dayForecast = day; snapshot.forecast = forecast; inputs.store.write('snapshot', snapshot.toJson());
      const stream = inputs.service.getSavedSettings(); let calls = 0;
      const unsubscribe = stream.subscribe((value: Settings | null): void => { calls++; });
      await inputs.service.init(false);
      expect(calls).assertEqual(2); expect(stream.getValue()?.locationName).assertEqual('Cached');
      inputs.service.setLocation(new Coordinates(8, 9));
      await inputs.service.changeUnit('temperaturePrefs', 'fahrenheit');
      expect(inputs.service.getSavedLocationCoord().getValue()?.latitude).assertEqual(3);
      expect(inputs.service.getSavedDaysForecast().getValue()?.dayForecast?.temperature?.temperature).assertEqual(10);
      await inputs.service.fetchWeatherAndPlace(new Coordinates(8, 9));
      expect(stream.getValue()?.locationName).assertEqual('Cached');
      unsubscribe(); await inputs.service.saveSnapshot(); expect(calls).assertEqual(2);
      expect(stream.getValue()?.locationName).assertEqual('Injected place');
      expect(inputs.service.getSavedLocationCoord().getValue()?.longitude).assertEqual(9);
      const repository = inputs.service.storage;
      let coordCalls = 0;
      const stop = repository.getFlowLocationCoord().subscribe((value: Coordinates | null): void => { coordCalls++; });
      expect(coordCalls).assertEqual(1);
      await repository.saveLocationCoord(new Coordinates(8, 9)); expect(coordCalls).assertEqual(1);
      await repository.saveLocationCoord(new Coordinates(8, 10)); expect(coordCalls).assertEqual(2);
      await repository.saveDaysForecastResponse(forecast); expect(coordCalls).assertEqual(2);
      settings.locationCoord = null; await repository.saveSettings(settings); expect(coordCalls).assertEqual(2);
      settings.locationCoord = new Coordinates(8, 10); await repository.saveSettings(settings);
      expect(coordCalls).assertEqual(2); stop();
      expect((await repository.getSettings())?.locationCoord?.longitude).assertEqual(10);
      expect((await repository.getDaysForecastResponse())?.dayForecast?.temperature?.temperature).assertEqual(10);
      expect((await repository.getDataStoreProto())?.settings?.locationCoord?.latitude).assertEqual(8);
      const empty = new ProtoDataStoreRepository(new InputStore()); let emptyCalls = 0;
      const replacement = new InputStore(); empty.setDataStore(replacement);
      expect(empty.getDataStore() === replacement).assertTrue();
      empty.getFlowLocationCoord().subscribe((value: Coordinates | null): void => { emptyCalls++; });
      expect(emptyCalls).assertEqual(0); expect(await empty.getSettings() === null).assertTrue();
      let rejected = false;
      try { await empty.saveLocationCoord(new Coordinates()); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      await empty.saveSettings(settings); expect(emptyCalls).assertEqual(1);
      await empty.saveDaysForecastResponse(forecast);
      expect((await empty.getSettings())?.locationName).assertEqual('Cached');
      await empty.saveSettings(null);
      expect((await empty.getDaysForecastResponse())?.dayForecast?.temperature?.temperature).assertEqual(10);
      await empty.saveDaysForecastResponse(null);
      expect(await empty.getDaysForecastResponse() === null).assertTrue();
      const serializer = new DataStoreSerializer(); expect(serializer.getDefaultValue().settings === null).assertTrue();
      expect((await serializer.readFrom(async (): Promise<ArrayBuffer> => encodeSnapshot(snapshot))).settings?.locationName)
        .assertEqual('Cached');
      rejected = false;
      try { await serializer.readFrom(async (): Promise<ArrayBuffer> => new Uint8Array([10, 2, 10]).buffer as ArrayBuffer); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); rejected = false;
      try {
        await serializer.writeTo(snapshot, async (bytes: ArrayBuffer): Promise<void> => { throw new Error('IO failure'); });
      } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      const proxy = inputs.service.repository;
      expect((await proxy.getSettings())?.locationCoord?.longitude).assertEqual(10);
      expect((await proxy.getDaysForecastResponse())?.dayForecast?.temperature?.temperature).assertEqual(10);
      proxy.setTemperatureUnit(0); expect(proxy.getTemperatureUnit()).assertEqual(0);
      proxy.setSpeedUnit(1); expect(proxy.getSpeedUnit()).assertEqual(1);
      proxy.setPressureUnit(2); expect(proxy.getPressureUnit()).assertEqual(2);
      proxy.setLocale('ru'); expect((await proxy.fetchNearestPlaceInfo(1, 2)).toponymName).assertEqual('Injected place');
      expect(inputs.geo.requestedLocale).assertEqual('ru');
      expect((await proxy.fetchWeatherForecast(1, 2)) === inputs.weather.value).assertTrue();
      expect((await proxy.searchLocation('proxy')).length).assertEqual(0);
      expect((await proxy.requestLocation()).latitude).assertEqual(8);
      const failingStore = new InputStore(); failingStore.failFlush = true;
      const failingRepository = new ProtoDataStoreRepository(failingStore); rejected = false;
      try { await failingRepository.saveDataStore(snapshot); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
    });
    it('DP-A40 rejects malformed DTO; DP-A29 independent reads isolate malformed siblings', 0, async (): Promise<void> => {
      const invalid: string[] = [
        '{"settings":{"locationName":"Cached","locationCoord":{"latitude":"3","longitude":4}},"forecast":null}',
        '{"settings":{"locationName":"Cached","locationCoord":{"latitude":3,"longitude":false}},"forecast":null}',
        '{"settings":{"locationName":false,"locationCoord":null},"forecast":null}',
        '{"settings":{"locationName":"Cached","locationCoord":{"latitude":1e400,"longitude":4}},"forecast":null}',
        '{"settings":null,"forecast":{"dayForecast":null,"weekTempForecast":[{"time":null,"temperature":"10","imgIdWeatherCode":null,"temperatureUnit":0}]}}',
        '{"settings":null,"forecast":{"dayForecast":null,"weekTempForecast":[{"time":null,"temperature":10,"imgIdWeatherCode":null,"temperatureUnit":7}]}}',
        '{"settings":null,"forecast":{"dayForecast":null,"weekTempForecast":[null]}}'
      ];
      invalid.forEach((json: string): void => {
        let rejected = false;
        try { parseSavedSnapshot(json); } catch (error) { rejected = true; }
        expect(rejected).assertTrue();
        const inputs = new Inputs(); inputs.store.write('snapshot', json); inputs.service.restore();
        expect(inputs.service.getLocation().latitude).assertEqual(40.72);
        expect(inputs.service.placeName === null).assertTrue();
        expect(inputs.service.getSavedSettings().getValue() === null).assertTrue();
      });
      const inputs = new Inputs();
      inputs.store.write('snapshot', '{"settings":{"locationName":"Cached","locationCoord":{"latitude":3,"longitude":4}},"forecast":{"dayForecast":null,"weekTempForecast":[null]}}');
      await inputs.service.init(false);
      expect(inputs.service.placeName).assertEqual('Cached'); expect(inputs.service.getLocation().latitude).assertEqual(3);
      expect(inputs.service.forecast === null).assertTrue();
      expect(await inputs.service.storage.getDaysForecastResponse() === null).assertTrue();
      expect((await inputs.service.storage.getSettings())?.locationName).assertEqual('Cached');
      inputs.store.write('snapshot', '{"settings":{"locationName":false,"locationCoord":null},"forecast":{"dayForecast":null,"weekTempForecast":[]}}');
      const other = new Inputs(); other.store.write('snapshot', inputs.store.read('snapshot', ''));
      await other.service.init(false); expect(other.service.forecastStatus).assertEqual('success');
      expect(other.service.placeName === null).assertTrue();
    });
    it('DP-A34 dispose detaches subscribers and suppresses late weather place search successes', 0, async (): Promise<void> => {
      const weather = new PendingWeather(); const geo = new PendingGeo();
      const service = new WeatherService(weather, geo, new LocationPlatform(new InputLocation()), new InputStore(),
        (): boolean => true, (locale: string): void => { }, new InputStore());
      let calls = 0; service.getSavedSettings().subscribe((value: Settings | null): void => { calls++; });
      const fetching = service.fetchWeatherAndPlace(new Coordinates()); const searching = service.search('query');
      service.onCleared();
      weather.pending.resolve(new Forecast()); geo.place.resolve(new Place('Late')); geo.search.resolve([new Place('Late')]);
      await fetching; expect(await searching === null).assertTrue();
      expect(service.forecast === null).assertTrue(); expect(service.placeName === null).assertTrue();
      expect(service.searchResults === null).assertTrue(); expect(service.loading).assertFalse();
      service.restore(); expect(calls).assertEqual(1);
      await service.fetchWeatherAndPlace(new Coordinates()); expect(await service.saveSnapshot()).assertFalse();
    });
    it('DP-A34 dispose suppresses late errors and location cannot trigger followup requests', 0, async (): Promise<void> => {
      const weather = new PendingWeather(); const geo = new PendingGeo();
      const service = new WeatherService(weather, geo, new LocationPlatform(new InputLocation()), new InputStore(),
        (): boolean => true, (locale: string): void => { }, new InputStore());
      const fetching = service.fetchWeatherAndPlace(new Coordinates()); const searching = service.search('query');
      service.dispose(); weather.pending.reject(); geo.place.reject(); geo.search.reject(); await fetching; await searching;
      expect(service.weatherError === null).assertTrue(); expect(service.placeError === null).assertTrue();
      expect(service.searchError === null).assertTrue();
      const feed = new PendingLocation(); feed.granted = true; const location = new LocationPlatform(feed);
      const nextWeather = new InputWeather(); const nextGeo = new InputGeo();
      const nextService = new WeatherService(nextWeather, nextGeo, location, new InputStore(),
        (): boolean => true, (locale: string): void => { }, new InputStore());
      const request = nextService.fetchCurrentWeatherAndPlace(); nextService.dispose();
      feed.pending.resolve(new Coordinates(1, 2)); await request;
      expect(nextWeather.calls).assertEqual(0); expect(nextGeo.calls).assertEqual(0);
      expect(location.getLocation().latitude).assertEqual(40.72);
    });
    it('DP-A03 denied uses memory; current null preserves; disabled uses last', 0, async (): Promise<void> => {
      const feed = new InputLocation(); const location = new LocationPlatform(feed);
      expect((await location.requestLocation()).latitude).assertEqual(40.72);
      expect(location.getLocation().longitude).assertEqual(-74);
      expect(feed.currentCalls).assertEqual(0);
      feed.granted = true; await location.requestLocation();
      expect(location.getLocation().latitude).assertEqual(40.72);
      feed.active = false; feed.value = new Coordinates(1, 2); await location.requestLocation();
      expect(feed.lastCalls).assertEqual(1); expect(location.getLocation().longitude).assertEqual(2);
    });
    it('DP-A03 failed current only logs and does not request weather or place', 0, async (): Promise<void> => {
      const inputs = new Inputs(); inputs.feed.granted = true; inputs.feed.failure = true;
      await inputs.service.fetchCurrentWeatherAndPlace();
      expect(inputs.weather.calls).assertEqual(0); expect(inputs.geo.calls).assertEqual(0);
      expect(inputs.service.forecastStatus).assertEqual('idle');
    });
    it('DP-A02 ordinary init requests both; DP-A07 callback does not refresh', 0, async (): Promise<void> => {
      const inputs = new Inputs(); await inputs.service.init();
      expect(inputs.weather.calls).assertEqual(1); expect(inputs.geo.calls).assertEqual(1);
      expect(inputs.feed.permissionCalls).assertEqual(1);
      await inputs.service.handlePermission(); expect(inputs.weather.calls).assertEqual(1);
      expect(inputs.service.placeName).assertEqual('Injected place');
      expect(inputs.store.flushes).assertEqual(0);
      const staged = new Inputs(); staged.preferences.write('languagePrefs', 'ru');
      staged.preferences.write('temperaturePrefs', 'fahrenheit'); await staged.service.init(false);
      expect(staged.service.locale).assertEqual('ru'); expect(staged.service.units.temperaturePrefs).assertEqual('fahrenheit');
      expect(staged.weather.calls).assertEqual(0); expect(staged.feed.permissionCalls).assertEqual(0);
      await staged.service.init(true); await staged.service.init(true);
      expect(staged.weather.calls).assertEqual(1); expect(staged.feed.permissionCalls).assertEqual(1);
    });
    it('DP-A04 offline clears Resource data and reports exact source errors', 0, async (): Promise<void> => {
      const inputs = new Inputs(); await inputs.service.fetchWeatherAndPlace(new Coordinates());
      inputs.online = false; await inputs.service.fetchWeatherAndPlace(new Coordinates());
      expect(inputs.service.forecast === null).assertTrue(); expect(inputs.service.placeName === null).assertTrue();
      expect(inputs.service.weatherError).assertEqual('Turn on mobile data or connect to a Wi-Fi network');
      expect(inputs.service.loading).assertFalse(); expect(inputs.weather.calls).assertEqual(1);
      await inputs.service.search(''); expect(inputs.service.searchStatus).assertEqual('error');
    });
    it('DP-A04 independent weather error still publishes nearest place', 0, async (): Promise<void> => {
      const inputs = new Inputs(); inputs.weather.failure = true;
      await inputs.service.fetchWeatherAndPlace(new Coordinates());
      expect(inputs.service.weatherError).assertEqual("Couldn't get the weather forecast");
      expect(inputs.service.placeName).assertEqual('Injected place');
      expect(inputs.service.forecastStatus).assertEqual('error');
    });
    it('DP-A06 selection sets coordinates and fetches nearest rather than row text', 0, async (): Promise<void> => {
      const inputs = new Inputs(); await inputs.service.selectPlace(new Place('Row text', '', '', '', '', '12.5', '-3'));
      expect(inputs.service.getLocation().latitude).assertEqual(12.5);
      expect(inputs.service.placeName).assertEqual('Injected place');
      await inputs.service.search('  query  '); expect(inputs.geo.queries[0]).assertEqual('  query  ');
      expect(inputs.service.searchResults?.length).assertEqual(0);
    });
    it('DP-A21 locale request starts before UI language change and persists separately', 0, async (): Promise<void> => {
      const inputs = new Inputs(); await inputs.service.changeLanguage('ru');
      expect(inputs.localeOrder).assertEqual('ru:ru'); expect(inputs.service.locale).assertEqual('ru');
      expect(inputs.preferences.read('languagePrefs', '')).assertEqual('ru');
      expect(inputs.store.read('languagePrefs', '')).assertEqual('');
      expect(inputs.store.read('snapshot', '')).assertEqual('');
    });
    it('DP-A22 DP-A24 instantaneous conversions preserve dayTemp and diff', 0, async (): Promise<void> => {
      const inputs = new Inputs(); const day = new DayForecast();
      day.temperature = temperature(10); day.apparentTemp = temperature(10); day.nightTemp = temperature(10);
      day.dayTemp = temperature(20); day.hourlyTempForecast = [temperature(10)];
      day.windSpeed = new WindSpeed(); day.windSpeed.speed = 10; day.windSpeed.speedDiff = 3;
      day.pressure = new Pressure(); day.pressure.pressure = 760; day.pressure.pressureDiff = 7;
      inputs.weather.value.dayForecast = day; inputs.weather.value.weekTempForecast = [temperature(10)];
      await inputs.service.fetchWeatherAndPlace(new Coordinates());
      await inputs.service.changeUnit('temperaturePrefs', 'fahrenheit');
      expect(inputs.service.forecast?.dayForecast?.temperature?.temperature).assertEqual(50);
      expect(inputs.service.forecast?.dayForecast?.dayTemp?.temperature).assertEqual(20);
      expect(inputs.service.forecast?.weekTempForecast[0].temperature).assertEqual(50);
      await inputs.service.changeUnit('windSpeedPrefs', 'kmh');
      await inputs.service.changeUnit('airPressurePrefs', 'hpa');
      expect(inputs.service.forecast?.dayForecast?.windSpeed?.speed).assertEqual(36);
      expect(inputs.service.forecast?.dayForecast?.windSpeed?.speedDiff).assertEqual(3);
      expect(inputs.service.forecast?.dayForecast?.pressure?.pressureDiff).assertEqual(7);
      expect(inputs.weather.calls).assertEqual(1);
    });
    it('DP-A30 save guard permits null forecast Resource and flushes DTO', 0, async (): Promise<void> => {
      const inputs = new Inputs(); expect(await inputs.service.saveSnapshot()).assertFalse();
      inputs.weather.failure = true; await inputs.service.fetchWeatherAndPlace(new Coordinates(3, 4));
      inputs.service.setLocation(new Coordinates(3, 4)); expect(await inputs.service.saveSnapshot()).assertTrue();
      const dto = Snapshot.fromJson(inputs.store.read('snapshot', ''));
      expect(dto.forecast === null).assertTrue(); expect(dto.settings?.locationName).assertEqual('Injected place');
      expect(dto.settings?.locationCoord?.longitude).assertEqual(4); expect(inputs.store.flushes).assertEqual(1);
    });
    it('DP-A31 cached units remain unchanged; direct Settings cold entry does not fetch', 0, async (): Promise<void> => {
      const inputs = new Inputs(); const day = new DayForecast(); day.temperature = temperature(10);
      inputs.weather.value.dayForecast = day; await inputs.service.fetchWeatherAndPlace(new Coordinates());
      await inputs.service.saveSnapshot(); inputs.preferences.write('temperaturePrefs', 'fahrenheit');
      const restored = new WeatherService(inputs.weather, inputs.geo, new LocationPlatform(inputs.feed), inputs.store,
        (): boolean => false, (locale: string): void => { }, inputs.preferences);
      await restored.init(false);
      expect(restored.forecast?.dayForecast?.temperature?.temperature).assertEqual(10);
      expect(restored.units.temperaturePrefs).assertEqual('fahrenheit'); expect(inputs.weather.calls).assertEqual(1);
      const empty = new Inputs(); await empty.service.init(false);
      expect(empty.service.forecast === null).assertTrue(); expect(empty.weather.calls).assertEqual(0);
    });
  });
}
