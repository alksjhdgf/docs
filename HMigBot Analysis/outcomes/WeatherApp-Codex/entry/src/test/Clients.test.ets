import { describe, it, expect } from '@ohos/hypium';
import { FlatForecast, FlatVariable } from '../main/ets/data/FlatForecast';
import { OpenMeteoClient, buildWeatherForecastUrl, cityTime, WeatherCalendarFields } from '../main/ets/data/OpenMeteoClient';
import { GeoNamesClient, buildNearestPlaceUrl, buildSearchLocationUrl, parseNearestPlace,
  parseSearch, parsePlaceInfoJson, GeoPlaceJson, consumeGeoHttpResponse } from '../main/ets/data/GeoNamesClient';
import { TemperatureUnit, SpeedUnit, PressureUnit } from '../main/ets/core/Models';
import { Forecast } from '../main/ets/core/Models';
import { updatePressure } from '../main/ets/core/Units';

// These are schema/source-derived behavior probes, NOT source golden fixtures or service observations.
// SDK fixture layout: https://raw.githubusercontent.com/open-meteo/sdk/v1.14.1/flatbuffers/weather_api.fbs
// DP-A09 expectation: 天气真实 GET `https://api.open-meteo.com/v1/forecast`：`latitude=<double>&longitude=<double>&temperature_unit=<celsius|fahrenheit>&wind_speed_unit=<kmh|ms|mph>&pressure_msl=hpa&timeformat=unixtime&timezone=auto&past_days=6&forecast_days=10&format=flatbuffers`；`minutely_15=weather_code,temperature_2m,apparent_temperature,wind_speed_10m`；`hourly=weather_code,temperature_2m,precipitation_probability,uv_index,pressure_msl,is_day`；`daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset`；URL 编码交给 HttpUrl。连接10s/读取30s，源码未配置应用层重试或调用取消（不排除OkHttp默认内部行为）
// anchor: OpenMeteoClient.java:54、68。
// DP-A10 expectation: 天气响应是二进制，不是 JSON：ByteBuffer little-endian，position(4) 跳过长度前缀，`WeatherApiResponse.getRootAsWeatherApiResponse`；使用 `minutely15/hourly/daily/timezone`，变量按 SDK Variable ID 搜索 first，float values 与日出日落 int64 秒；HTTP不成功 onError 后仍继续读取（无 return），空body/IO失败报错；没有 malformed/缺变量/越界/未知码防护
// anchor: OpenMeteoClient.java:95、161、208、338。
// DP-A11 expectation: 近邻地名 GET `http://api.geonames.org/findNearbyPlaceNameJSON?lat=<double>&lng=<double>&style=FULL&cities=cities1000&lang=<client locale language>&username=my_weather_app`；取根 `geonames[0]`，空数组为错误。连接10s/读取30s；明文在 Android manifest 显式允许，不得静默替换成本地假城市或另家搜索
// anchor: GeoNamesClient.java:34、43；AndroidManifest.xml:12。
// DP-A12 expectation: 搜索 GET `http://api.geonames.org/searchJSON?q=<query>&style=LONG&maxRows=15&fuzzy=0.8&lang=<Locale.getDefault language>&username=my_weather_app`；依原顺序映射 `geonames[]`，空列表成功，无分页/筛选/去重；搜索 lang 不使用 setLocale 字段
// anchor: GeoNamesClient.java:125、180。
// DP-A13 expectation: 地点映射必须读 `name,countryName,countryCode,adminName1,lat,lng` 字符串；有 `alternateNames` 时直接取 `[0].lang`，没有则 `en`，有但空会失败；首页只发布 `toponymName`，没有自动拼国家名
// anchor: GeoNamesClient.java:111；MainViewModel.java:325。
// DP-A14 expectation: 当前15分/小时 index 为 `Math.round((nowMs-startTimeSeconds*1000)/intervalMs)`（不是 floor）；daily index 固定6。时区设 response.timezone；最后更新 `yyyy-MM-dd HH:mm` 用设备默认时区/locale 的当前时间，不是服务观测时间
// anchor: OpenMeteoClient.java:166、179、216、334。
// DP-A15 expectation: 当前温度/体感/风速/降水概率/气压/UV取当前相应序列四舍五入整数；昼高夜低扫描 `hourlyIndex-hourOfDay-1` 开始24项，按 is_day 分组，温度先 Java `(int)` 截断再 max/min；不是请求的 daily min/max；无昼/无夜保留 int 极值的风险
// anchor: OpenMeteoClient.java:220、238、298。
// DP-A16 expectation: 风速、降水、压力、UV差值都为当前整数减 `index-24` 的整数，显示 abs(diff)，正/负/零分别 `ic_arrow_upgrade/ic_arrow_downgrade/ic_arrow_unchanged`；风速来自15分钟序列，实际比较6小时前而非24小时前
// anchor: OpenMeteoClient.java:298；ChangeIndicator.java:10。
// DP-A17 expectation: 逐小时温度/降水各从当前hourlyIndex含首项取24条，时间 `HH:mm` 按 response时区；温度 round，降水 `(int)` 截断；24个天气图标都使用当前 isDay，而非各小时 is_day。周温度取168项，从 `index-((DAY_OF_WEEK-1)*24+HOUR_OF_DAY)` 开始，Java周日为0，模型无时间/图标；不是未来连续7天
// anchor: OpenMeteoClient.java:368、390、411。
// DP-A18 expectation: 日落当天index6；超过当天日落则日出取index7，否则index6；time 用城市时区格式，hoursDiff/minutesDiff 却分别取两个 Calendar 的时/分绝对差（sun Calendar设备时区，now Calendar城市时区），isFuture 按epoch比较；不能描述为准确时长倒计时
// anchor: OpenMeteoClient.java:338。
// DP-A25 expectation: OpenMeteo实际 pressure_msl始终 hPa，却 parse 时标客户端 pressureUnit；VM formatDaysForecast 再以已标unit转向相同客户端unit且不改标签；非hPa设置下新请求存在数值/标签错配。迁移需显式决定修复，禁止按错误标签二次换算
// anchor: OpenMeteoClient.java:76、314；MainViewModel.java:290。
// DP-A32 expectation: 天气服务接口：`fetchWeatherForecast(latitude:double,longitude:double)→Single<DaysForecastProto>`；温度/速度/压力各 `get*Unit()→enum`、`set*Unit(enum)→void`；地名接口 `fetchNearestPlaceInfo(double,double)→Single<PlaceInfo>,searchLocation(String)→Single<List<PlaceInfo>>,getLocale()→Locale,setLocale(Locale)→void`；定位接口 `requestLocation()→Single<LocationCoordProto>,getLocation()→LocationCoordProto,setLocation(LocationCoordProto)→void`，实现另有 `isPermissionGranted()→boolean`
// anchor: OpenMeteoClient.java:68、131；GeoNamesClient.java:43、101、125；FusedLocationProvider.java:44、72、90。
// DP-A36 expectation: 解析顺序为 response三序列→设时区→当前index/day-night→构造当前温度/体感/昼/夜/图标/描述/更新时间/日出/日落/风/降水/压/UV/24小时温度/24小时降水→168项周温度；保留此数据依赖，`getDayTemp/getNightTemp` 两私有方法存在但当前parse不调用，不能另造双路径
// anchor: OpenMeteoClient.java:161、259、274。
// DP-A38 expectation: OkHttp Call/Callback/Request/Response/HttpUrl→`http` from `@kit.NetworkKit`：官方确认 `createHttp().request(url,options)→Promise<HttpResponse>`、GET、responseCode、STRING/ArrayBuffer返回选项、connectTimeout/readTimeout毫秒、destroy释放；须声明 `ohos.permission.INTERNET`；GeoNames HTTP有cleartext阻断错误2300997。不要采用最新master API26 queryParams，目标SDK未确定，按源自行编码查询参数
// anchor: GeoNamesClient.java:24；OpenMeteoClient.java:43。
// DP-A41 expectation: 平台权限ConnectivityManager/NetworkCapabilities需要另做网络状态适配；本轮仅静态确认源算法，未查证NetworkKit connection接口签名；OpenMeteo Java SDK FlatBuffers与Wire Java生成代码均非内置ArkTS库，需真实协议适配，不可用JSON响应假冒已有FlatBuffers实现；ABI、目标API、签名/权限UI本机能力未验证
// anchor: ConnectionNetworkProvider.java:3；OpenMeteoClient.java:11；app/build.gradle.kts:58。
// DP-A43 expectation: 高风险短清单：服务账号 `my_weather_app` 配额/有效性未实测；cleartext迁移策略；FlatBuffers长度前缀及变量缺失；未知码`.get()`、数组bounds、NaN；静态共享timeFormat并发与默认/城市时区混用；周日起点与UI周一标签错配；单位dayTemp遗漏、diff不换算、气压错标签；cache/settings与单位初始化并发及刷新的null覆盖；多个请求无取消/去重/版本号，旧请求可能覆盖新城市。均需明确保持/修复决策，不增加用户功能
// anchor: OpenMeteoClient.java:57、95、216、290、390；GeoNamesClient.java:35；MainViewModel.java:75、227、290；MainFragment.java:95；values/strings.xml:15。
// SS-A22 expectation: GeoNames 搜索 GET `http://api.geonames.org/searchJSON`：`q=query,style=LONG,maxRows=15,fuzzy=0.8,lang=Locale.getDefault().getLanguage(),username=my_weather_app`；最近地点 GET `findNearbyPlaceNameJSON`：`lat,lng,style=FULL,cities=cities1000,lang=client.locale.language,username`；连接超时 10s、读取 30s
// anchor: GeoNamesClient.java:34、43、125。
// SS-A23 expectation: JSON `geonames` 数组每项读取 `name,countryName,countryCode,adminName1,lat,lng`，`lang` 取存在的 `alternateNames[0].lang`，否则 `en`；最近地点取第一项，空数组报错；搜索空数组正常成功
// anchor: GeoNamesClient.java:81、111、180。
// SS-A25 expectation: 搜索无 trim/长度校验（空查询是否提交由框架决定），选中坐标 `Double.parseDouble` 无捕获；JSON 必填字段及存在但空 `alternateNames` 会使解析失败；HTTP 非成功分支发 error 后未 return
// anchor: SearchMenuFragment.java:57；GeoNamesClient.java:111、154。
// SS-A26 expectation: 搜索使用系统默认 locale，最近地名使用客户端 locale，语言切换后的语言一致性依赖外部 LocaleHelper；不能擅自把搜索参数写成必然使用 `languagePrefs`
// anchor: GeoNamesClient.java:51、133；SettingsFragment.java:80。
// SS-A30 expectation: 网络服务为明文 HTTP 与固定用户名，需迁移网络策略/服务配额核验；此卡只提取静态行为，不声称线上 GeoNames 可达、框架对话框按钮文案已在源中定义或真机视觉已验证
// anchor: GeoNamesClient.java:34；root_preferences.xml:4。
// Transport/cleartext/account/ABI clauses are not claimed as runtime-tested by this offline suite.

const START_SECONDS: number = 1704067200; // Monday 2024-01-01 00:00 UTC
const NOW_MS: number = (START_SECONDS + 6 * 86400 + 12 * 3600 + 31 * 60) * 1000;

// Local Test does not execute native TextEncoder/TextDecoder or i18n.Calendar.
// Only the platform boundaries are supplied here; parser and forecast algorithms stay real.
function fixtureTimezone(bytes: Uint8Array): string {
  let text = '';
  for (let i = 0; i < bytes.length; i++) {
    if (bytes[i] > 127) { throw new Error('Fixture timezone must be ASCII'); }
    text += String.fromCharCode(bytes[i]);
  }
  return text;
}
function fixtureCalendar(epochMs: number, timezone: string | null): WeatherCalendarFields {
  if (timezone !== null && timezone !== 'UTC' && timezone !== 'Asia/Tokyo') {
    throw new Error('Unsupported fixture timezone: ' + timezone);
  }
  const date = new Date(epochMs + (timezone === 'Asia/Tokyo' ? 9 * 3600000 : 0));
  const fields = new WeatherCalendarFields();
  fields.year = timezone === null ? date.getFullYear() : date.getUTCFullYear();
  fields.month = timezone === null ? date.getMonth() : date.getUTCMonth();
  fields.date = timezone === null ? date.getDate() : date.getUTCDate();
  fields.dayOfWeek = (timezone === null ? date.getDay() : date.getUTCDay()) + 1;
  fields.hour = timezone === null ? date.getHours() : date.getUTCHours();
  fields.minute = timezone === null ? date.getMinutes() : date.getUTCMinutes();
  return fields;
}

// Test-only forward serialization of official table/vector ordinals; not a second weather parser.
class SchemaFixture {
  buffer: ArrayBuffer = new ArrayBuffer(131072);
  view: DataView = new DataView(this.buffer);
  cursor: number = 8;
  allocate(length: number): number {
    this.cursor = Math.ceil(this.cursor / 8) * 8;
    const result = this.cursor; this.cursor += length; return result;
  }
  table(fields: number): number {
    const vtable = this.allocate(4 + fields * 2);
    const position = this.allocate(8 + fields * 8);
    this.view.setUint16(vtable, 4 + fields * 2, true);
    this.view.setUint16(vtable + 2, 8 + fields * 8, true);
    this.view.setInt32(position, position - vtable, true);
    return position;
  }
  field(table: number, ordinal: number): number {
    const vtable = table - this.view.getInt32(table, true);
    this.view.setUint16(vtable + 4 + ordinal * 2, 8 + ordinal * 8, true);
    return table + 8 + ordinal * 8;
  }
  link(position: number, target: number): void { this.view.setUint32(position, target - position, true); }
  int64(position: number, value: number): void {
    this.view.setUint32(position, value % 4294967296, true);
    this.view.setInt32(position + 4, Math.floor(value / 4294967296), true);
  }
  text(text: string): number {
    const bytes = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      if (code > 127) { throw new Error('Fixture timezone must be ASCII'); }
      bytes[i] = code;
    }
    const position = this.allocate(4 + bytes.length + 1);
    this.view.setUint32(position, bytes.length, true);
    new Uint8Array(this.buffer, position + 4, bytes.length).set(bytes);
    return position;
  }
  dataValue(id: FlatVariable, index: number): number {
    if (id === FlatVariable.WEATHER_CODE) { return 0; }
    if (id === FlatVariable.IS_DAY) { return index % 24 >= 6 && index % 24 < 18 ? 1 : 0; }
    if (id === FlatVariable.TEMPERATURE) { return index / 10 - 5.25; }
    if (id === FlatVariable.APPARENT_TEMPERATURE) { return index / 10 - 7.25; }
    if (id === FlatVariable.PRESSURE_MSL) { return 1000 + index / 10; }
    if (id === FlatVariable.PRECIPITATION_PROBABILITY) { return index / 10 + 0.8; }
    if (id === FlatVariable.SUNRISE) { return START_SECONDS + index * 86400 + 21600; }
    if (id === FlatVariable.SUNSET) { return START_SECONDS + index * 86400 + 64800; }
    return index / 10;
  }
  series(count: number, interval: number, ids: FlatVariable[]): number {
    const table = this.table(4);
    this.int64(this.field(table, 0), START_SECONDS);
    this.int64(this.field(table, 1), START_SECONDS + count * interval);
    this.view.setInt32(this.field(table, 2), interval, true);
    const vector = this.allocate(4 + ids.length * 4);
    this.view.setUint32(vector, ids.length, true); this.link(this.field(table, 3), vector);
    for (let i = 0; i < ids.length; i++) {
      const variable = this.table(5);
      this.link(vector + 4 + i * 4, variable);
      this.view.setUint8(this.field(variable, 0), ids[i]);
      const int64 = ids[i] === FlatVariable.SUNRISE || ids[i] === FlatVariable.SUNSET;
      const values = this.allocate(8 + count * (int64 ? 8 : 4)) + 4;
      this.view.setUint32(values, count, true);
      this.link(this.field(variable, int64 ? 4 : 3), values);
      for (let j = 0; j < count; j++) {
        if (int64) { this.int64(values + 4 + j * 8, this.dataValue(ids[i], j)); }
        else { this.view.setFloat32(values + 4 + j * 4, this.dataValue(ids[i], j), true); }
      }
    }
    return table;
  }
  build(timezone: string = 'UTC'): ArrayBuffer {
    const root = this.table(13); this.link(4, root);
    this.link(this.field(root, 7), this.text(timezone));
    this.link(this.field(root, 12), this.series(1600, 900, [FlatVariable.WIND_SPEED,
      FlatVariable.APPARENT_TEMPERATURE, FlatVariable.WEATHER_CODE, FlatVariable.TEMPERATURE]));
    this.link(this.field(root, 11), this.series(400, 3600, [FlatVariable.UV_INDEX, FlatVariable.IS_DAY,
      FlatVariable.PRESSURE_MSL, FlatVariable.TEMPERATURE, FlatVariable.PRECIPITATION_PROBABILITY,
      FlatVariable.WEATHER_CODE]));
    this.link(this.field(root, 10), this.series(16, 86400, [FlatVariable.SUNSET, FlatVariable.SUNRISE]));
    this.view.setUint32(0, this.cursor - 4, true);
    return this.buffer.slice(0, this.cursor);
  }
}
function throwsNear(body: string): boolean {
  try { parseNearestPlace(body); return false; } catch { return true; }
}
function throwsSearch(body: string): boolean {
  try { parseSearch(body); return false; } catch { return true; }
}
class ResponseProbe extends OpenMeteoClient {
  parsed: boolean = false;
  consumedBytes: number = 0;
  parseWeatherData(buffer: ArrayBuffer, nowMs: number = NOW_MS): Forecast {
    this.parsed = true;
    this.consumedBytes = buffer.byteLength;
    return super.parseWeatherData(buffer, nowMs);
  }
}

export default function clientsTest(): void {
  describe('ClientsSourceAndSchemaDerived', (): void => {
    it('DP-A10 SS-A25 HTTP errors consume valid and malformed bodies but remain terminal', 0, async (): Promise<void> => {
      const weather = new ResponseProbe(fixtureCalendar, fixtureTimezone);
      const responseBody = new SchemaFixture().build();
      let error = '';
      let published = false;
      // Inject the status/body at the exact production boundary called after native request.
      // Promise rejection must win even when the real parser constructs a valid Forecast.
      try { await Promise.resolve().then((): Forecast => weather.parseHttpResponse(503, responseBody)); published = true; }
      catch (e) { error = (e as Error).message; }
      expect(published).assertFalse(); expect(weather.consumedBytes).assertEqual(responseBody.byteLength);
      expect(weather.parsed).assertTrue(); expect(error).assertEqual('ERROR REQUEST SERVER: api.open-meteo 503');
      weather.parsed = false;
      try { await Promise.resolve().then((): Forecast => weather.parseHttpResponse(502, new ArrayBuffer(5))); published = true; }
      catch (e) { error = (e as Error).message; }
      expect(published).assertFalse(); expect(weather.consumedBytes).assertEqual(5);
      expect(weather.parsed).assertTrue(); expect(error).assertEqual('ERROR REQUEST SERVER: api.open-meteo 502');
      let consumed = false;
      try { await Promise.resolve().then((): string => consumeGeoHttpResponse(403, '{"geonames":[]}', (body: string): void => {
        consumed = true; expect(parseSearch(body).length).assertEqual(0);
      })); published = true; } catch (e) { error = (e as Error).message; }
      expect(published).assertFalse();
      expect(consumed).assertTrue(); expect(error).assertEqual('ERROR REQUEST SERVER: api.geonames 403');
      consumed = false;
      try { await Promise.resolve().then((): string => consumeGeoHttpResponse(500, 'malformed', (body: string): void => {
        consumed = true; parseSearch(body);
      })); published = true; } catch (e) { error = (e as Error).message; }
      expect(published).assertFalse();
      expect(consumed).assertTrue(); expect(error).assertEqual('ERROR REQUEST SERVER: api.geonames 500');
      consumed = false;
      try { consumeGeoHttpResponse(404, '{"geonames":[]}', (body: string): void => {
        consumed = true; parseNearestPlace(body);
      }); } catch (e) { error = (e as Error).message; }
      expect(consumed).assertTrue(); expect(error).assertEqual('ERROR REQUEST SERVER: api.geonames 404');
      // Positive control: a success status must not be rejected by the HTTP terminal rule.
      expect(weather.parseHttpResponse(200, responseBody).dayForecast !== null).assertTrue();
      expect(consumeGeoHttpResponse(200, '{"geonames":[]}', (body: string): void => {
        expect(parseSearch(body).length).assertEqual(0);
      })).assertEqual('{"geonames":[]}');
    });
    it('DP-A10 skips inconsistent prefix and preserves unguarded SDK vector arithmetic', 0, (): void => {
      const buffer = new SchemaFixture().build(); new DataView(buffer).setUint32(0, 1, true);
      const response = new FlatForecast(buffer, fixtureTimezone);
      expect(response.timezone()).assertEqual('UTC');
      const variable = response.hourly().variable(FlatVariable.TEMPERATURE);
      // Out-of-vector but in-buffer reads must not acquire new business validation.
      variable.value(variable.length());
      let failed = false;
      try { variable.value(buffer.byteLength); } catch (e) { failed = e instanceof Error; }
      expect(failed).assertTrue();
      failed = false;
      try { response.hourly().variable(FlatVariable.SUNRISE); } catch (e) { failed = e instanceof Error; }
      expect(failed).assertTrue();
      failed = false;
      const client = new OpenMeteoClient(fixtureCalendar, fixtureTimezone);
      try { client.parseHttpResponse(200, new ArrayBuffer(5)); } catch (e) { failed = e instanceof Error; }
      expect(failed).assertTrue();
      const invalidCode = new SchemaFixture().build();
      const values = new FlatForecast(invalidCode, fixtureTimezone).minutely15().variable(FlatVariable.WEATHER_CODE);
      new DataView(invalidCode).setFloat32(values.indirect(3) + 4 + 626 * 4, 999, true);
      failed = false;
      try { client.parseWeatherData(invalidCode, NOW_MS); } catch (e) { failed = e instanceof Error; }
      expect(failed).assertTrue();
    });
    it('DP-A09 exact request query and all unit options', 0, (): void => {
      const url = buildWeatherForecastUrl(40.72, -74);
      expect(url).assertEqual('https://api.open-meteo.com/v1/forecast?latitude=40.72&longitude=-74&temperature_unit=celsius&wind_speed_unit=kmh&pressure_msl=hpa&timeformat=unixtime&timezone=auto&past_days=6&forecast_days=10&format=flatbuffers&minutely_15=weather_code%2Ctemperature_2m%2Capparent_temperature%2Cwind_speed_10m&hourly=weather_code%2Ctemperature_2m%2Cprecipitation_probability%2Cuv_index%2Cpressure_msl%2Cis_day&daily=weather_code%2Ctemperature_2m_max%2Ctemperature_2m_min%2Csunrise%2Csunset');
      expect(buildWeatherForecastUrl(1, 2, TemperatureUnit.FAHRENHEIT, SpeedUnit.MS).includes('temperature_unit=fahrenheit&wind_speed_unit=ms')).assertTrue();
      expect(buildWeatherForecastUrl(1, 2, TemperatureUnit.CELSIUS, SpeedUnit.MPH).includes('wind_speed_unit=mph')).assertTrue();
    });
    it('DP-A11 DP-A12 SS-A22 SS-A25 SS-A26 distinct locale and encoded query', 0, (): void => {
      expect(buildNearestPlaceUrl(1, 2, 'ru-RU')).assertEqual('http://api.geonames.org/findNearbyPlaceNameJSON?lat=1&lng=2&style=FULL&cities=cities1000&lang=ru&username=my_weather_app');
      expect(buildSearchLocationUrl('New York &', 'en-US')).assertEqual('http://api.geonames.org/searchJSON?q=New%20York%20%26&style=LONG&maxRows=15&fuzzy=0.8&lang=en&username=my_weather_app');
      const geo = new GeoNamesClient((): string => 'en-US'); geo.setLocale('ru-RU');
      expect(geo.getLocale()).assertEqual('ru-RU');
      expect(geo.buildNearestPlaceUrl(1, 2).includes('lang=ru')).assertTrue();
      expect(geo.buildSearchLocationUrl('x').includes('lang=en')).assertTrue();
      expect(geo.buildSearchLocationUrl('  ').includes('q=%20%20&')).assertTrue();
      expect(geo.buildSearchLocationUrl('').includes('q=&')).assertTrue();
    });
    it('DP-A11 DP-A12 DP-A13 SS-A23 SS-A25 JSON mapping order null and empty behavior', 0, (): void => {
      const first: GeoPlaceJson = { name: 'source-derived fixture A', countryName: 'country', countryCode: 'CC',
        adminName1: '', lat: '1.25', lng: '-2.5', alternateNames: [{ lang: 'ru' }, { lang: 'en' }] };
      const second: GeoPlaceJson = { name: 'source-derived fixture B', countryName: 'country', countryCode: 'CC',
        adminName1: 'region', lat: '3', lng: '4' };
      const body = '{"geonames":[' + JSON.stringify(first) + ',' + JSON.stringify(second) + ']}';
      const list = parseSearch(body); expect(list.length).assertEqual(2);
      expect(list[0].toponymName).assertEqual(first.name); expect(list[1].toponymName).assertEqual(second.name);
      expect(list[0].countryName).assertEqual('country'); expect(list[0].countryCode).assertEqual('CC');
      expect(list[0].adminName1).assertEqual(''); expect(list[0].latitude).assertEqual('1.25');
      expect(list[0].longitude).assertEqual('-2.5'); expect(list[0].lang).assertEqual('ru');
      expect(parsePlaceInfoJson(second).lang).assertEqual('en');
      expect(parseNearestPlace(body).toponymName).assertEqual(first.name);
      expect(parseSearch('{"geonames":[]}').length).assertEqual(0);
      expect(throwsNear('{"geonames":[]}')).assertTrue();
      first.alternateNames = [];
      expect(throwsSearch('{"geonames":[' + JSON.stringify(first) + ']}')).assertTrue();
      expect(throwsSearch('{"status":{"message":"error"}}')).assertTrue();
      expect(throwsSearch('{"geonames":[{"name":"missing other fields"}]}')).assertTrue();
      expect(throwsSearch('malformed')).assertTrue();
      expect(throwsSearch('null')).assertTrue();
    });
    it('DP-A10 native DataView size prefix table variable IDs int64 and float vectors', 0, (): void => {
      const buffer = new SchemaFixture().build(); const response = new FlatForecast(buffer, fixtureTimezone);
      expect(response.messageLength).assertEqual(buffer.byteLength - 4); expect(response.timezone()).assertEqual('UTC');
      expect(response.hourly().time()).assertEqual(START_SECONDS);
      expect(response.hourly().timeEnd()).assertEqual(START_SECONDS + 400 * 3600);
      expect(response.minutely15().interval()).assertEqual(900); expect(response.daily().interval()).assertEqual(86400);
      expect(response.hourly().variable(FlatVariable.TEMPERATURE).length()).assertEqual(400);
      expect(response.minutely15().variable(FlatVariable.TEMPERATURE).length()).assertEqual(1600);
      expect(response.hourly().value(FlatVariable.TEMPERATURE, 157)).assertEqual(Math.fround(10.45));
      expect(response.daily().value(FlatVariable.SUNSET, 6, true)).assertEqual(START_SECONDS + 6 * 86400 + 64800);
    });
    it('DP-A14 DP-A15 DP-A16 DP-A17 DP-A25 DP-A32 DP-A36 forecast derivation', 0, (): void => {
      const client = new OpenMeteoClient(fixtureCalendar, fixtureTimezone); client.setPressureUnit(PressureUnit.MMHG);
      expect(client.getTemperatureUnit()).assertEqual(TemperatureUnit.CELSIUS);
      expect(client.getSpeedUnit()).assertEqual(SpeedUnit.KMH); expect(client.getPressureUnit()).assertEqual(PressureUnit.MMHG);
      const forecast = client.parseWeatherData(new SchemaFixture().build(), NOW_MS);
      const day = forecast.dayForecast; expect(day !== null).assertTrue();
      if (day === null) { throw new Error('Missing day'); }
      expect(day.temperature?.temperature).assertEqual(57); expect(day.apparentTemp?.temperature).assertEqual(55);
      expect(day.dayTemp?.temperature).assertEqual(10); expect(day.nightTemp?.temperature).assertEqual(9);
      expect(day.weatherCode).assertEqual('clear_sky'); expect(day.imgIdWeatherCode).assertEqual('ic_clear_day');
      expect(day.windSpeed?.speed).assertEqual(63); expect(day.windSpeed?.speedDiff).assertEqual(3);
      expect(day.windSpeed?.imgIdChangeWindSpeed).assertEqual('ic_arrow_upgrade');
      expect(day.precipitationChance?.percent).assertEqual(17); expect(day.precipitationChance?.percentDiff).assertEqual(3);
      expect(day.pressure?.pressure).assertEqual(1016); expect(day.pressure?.pressureDiff).assertEqual(3);
      expect(day.pressure?.pressureUnit).assertEqual(PressureUnit.MMHG); // source-visible wrong label, not a safety repair
      if (day.pressure === null) { throw new Error('Missing pressure'); }
      // Source changePressureUnit converts using the wrong label. Frozen DP-A25's safety
      // clause conflicts with this behavior; document the debt rather than fake a pass.
      expect(updatePressure(day.pressure, day.pressure.pressureUnit, PressureUnit.HPA).pressure).assertEqual(1355);
      expect(day.uvIndex?.uvIndex).assertEqual(16); expect(day.uvIndex?.uvIndexDiff).assertEqual(3);
      expect(day.hourlyTempForecast.length).assertEqual(24); expect(day.precipitationChanceForecast.length).assertEqual(24);
      expect(day.hourlyTempForecast[0].time).assertEqual('13:00'); expect(day.hourlyTempForecast[23].time).assertEqual('12:00');
      expect(day.hourlyTempForecast[0].temperature).assertEqual(10); expect(day.precipitationChanceForecast[0].percent).assertEqual(16);
      expect(day.hourlyTempForecast[7].imgIdWeatherCode).assertEqual('ic_clear_day');
      expect(forecast.weekTempForecast.length).assertEqual(168); expect(forecast.weekTempForecast[0].temperature).assertEqual(9);
      expect(forecast.weekTempForecast[167].temperature).assertEqual(26);
      expect(forecast.weekTempForecast[0].time).assertNull(); expect(forecast.weekTempForecast[0].imgIdWeatherCode).assertNull();
    });
    it('DP-A18 daily6 next sunrise7 and city timezone time', 0, (): void => {
      const client = new OpenMeteoClient(fixtureCalendar, fixtureTimezone); const buffer = new SchemaFixture().build();
      const before = client.parseWeatherData(buffer, NOW_MS).dayForecast;
      const after = client.parseWeatherData(buffer, (START_SECONDS + 6 * 86400 + 19 * 3600) * 1000).dayForecast;
      expect(before?.sunrise?.time).assertEqual('06:00'); expect(before?.sunrise?.isFuture).assertFalse();
      expect(before?.sunset?.time).assertEqual('18:00'); expect(before?.sunset?.isFuture).assertTrue();
      expect(after?.sunrise?.isFuture).assertTrue(); expect(after?.sunset?.isFuture).assertFalse();
      expect(cityTime(START_SECONDS * 1000, 'Asia/Tokyo', fixtureCalendar)).assertEqual('09:00');
      const tokyo = client.parseWeatherData(new SchemaFixture().build('Asia/Tokyo'), NOW_MS).dayForecast;
      expect(tokyo?.hourlyTempForecast[0].time).assertEqual('22:00');
      // Source sun Calendar retains DEVICE timezone; current Calendar has CITY timezone.
      const sunCalendar = fixtureCalendar((START_SECONDS + 6 * 86400 + 21600) * 1000, null);
      expect(tokyo?.sunrise?.hoursDiff).assertEqual(Math.abs(sunCalendar.hour - 21));
      expect(tokyo?.sunrise?.minutesDiff).assertEqual(Math.abs(sunCalendar.minute - 31));
    });
  });
}
