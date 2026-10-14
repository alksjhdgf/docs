import { describe, it, expect } from '@ohos/hypium';
import { Snapshot, Forecast, DayForecast, Temperature, WindSpeed, Pressure, UvIndex,
  PrecipitationChance, SunriseSunset, Coordinates, Settings, Place, PreferencesSettings,
  TemperatureUnit, SpeedUnit, PressureUnit, Resource, Success, Error as ResourceError,
  Loading } from '../main/ets/core/Models';
import { convertTemperature, convertSpeed, convertPressure, updateTemperature, updateWindSpeed,
  updatePressure, javaRoundFloat, getTimeIndex, temperatureUnitFromPreference, speedUnitFromPreference,
  pressureUnitFromPreference } from '../main/ets/core/Units';
import { WEATHER_CODES, searchWeatherCode, requireWeatherCode, getResIdByCode, getIconIdByCode,
  getIndicatorValue } from '../main/ets/core/WeatherCodes';

// Source-derived behavior probes, NOT original business fixtures (the source has none).
// expectation quotes are atomic ledger notes verbatim; tests exercise only this unit's
// portion. Client/timezone/UI/network portions remain gates of their owning units.
// DP-A14 expectation: 当前15分/小时 index 为 `Math.round((nowMs-startTimeSeconds*1000)/intervalMs)`（不是 floor）；daily index 固定6。时区设 response.timezone；最后更新 `yyyy-MM-dd HH:mm` 用设备默认时区/locale 的当前时间，不是服务观测时间
// anchor: OpenMeteoClient.java:166、179、216、334。
// DP-A19 expectation: 天气码完整集合 `0,1,2,3,45,48,51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99` 对应资源 `clear_sky,mainly_clear,partly_cloudy,overcast,fog,ice_fog,light_drizzle,drizzle,heavy_drizzle,light_freezing_drizzle,freezing_drizzle,light_rain,rain,heavy_rain,light_freezing_rain,freezing_rain,light_snow,snow,heavy_snow,snow_grains,light_showers,showers,heavy_showers,light_snow_showers,snow_showers,thunderstorm,light_thunderstorm_hail,thunderstorm_hail`；二分查找未知返回 Optional.empty，调用端 `.get()` 无兜底
// anchor: WeatherCode.java:15、51；OpenMeteoClient.java:290。
// DP-A20 expectation: 图标昼夜成对的码 `0,1,2,51,53,55,56,57,61,63,66,71,73`；其余昼夜同图；`1/2` 共用 cloudy_2 图；`weatherCode` 存字符串资源ID而非原始 WMO码，`imgId*` 全为 Android整数资源ID，迁移缓存必须转稳定资源名，不能复用原数值
// anchor: WeatherCode.java:15；OpenMeteoClient.java:290。
// DP-A23 expectation: 转换完整公式：F→C `(t-32)*5/9`，C→F `t*9/5+32`；kmh→ms `/3.6`，mph→ms `*0.446944`，反向 `*3.6`、`/0.446944`；mmHg→hPa `*1.33322`，inHg→hPa `*33.8638`，反向除同常数；更新模型 round 到int并改unit，保留其它字段（差值不转换）。Java float精度及 round 负半值不得无意变更
// anchor: UnitConverter.java:24、43、67、91。
// DP-A26 expectation: `PlaceInfo` 七个只读String字段及构造/getter：`toponymName,countryName,countryCode,lang,adminName1,latitude,longitude`；`LocationCoordProto` 两double；`SettingsProto` 仅 `locationCoord,locationName`；`DataStoreProto` 仅 `settings,forecast`，单位/语言属于另一份SharedPreferences
// anchor: PlaceInfo.java:6；location_coord.proto:7；settings_app.proto:8；ProtoDataStoreRepository.java:38；MainViewModel.java:103。
// DP-A27 expectation: `DaysForecastProto{dayForecast,weekTempForecast[]}`；`DayForecastProto{temperature,apparentTemp,dayTemp,nightTemp,imgIdWeatherCode,weatherCode,date,sunrise,sunset,windSpeed,precipitationChance,pressure,uvIndex,hourlyTempForecast[],precipitationChanceForecast[]}`；`TemperatureProto{time?:string,temperature:int,imgIdWeatherCode?:int,temperatureUnit}`
// anchor: days_forecast.proto:9；day_forecast.proto:14；temperature.proto:8。
// DP-A28 expectation: 数值模型完整字段：`WindSpeedProto{speed,speedDiff?,imgIdChangeWindSpeed?,speedUnit}`；`PressureProto{pressure,pressureDiff?,imgIdChangePressure?,pressureUnit}`；`UvIndexProto{uvIndex,uvIndexDiff?,imgIdChangeUvIndex?}`；`PrecipitationChanceProto{time?,percent,percentDiff?,imgIdPrecipitationChance?}`；`SunriseSunsetProto{time,hoursDiff?,minutesDiff?,isFuture?}`，数值均int、time为string、future为bool；保留optional/null与0的区分
// anchor: wind_speed.proto:8；pressure.proto:8；uv_index.proto:7；precipitation_chance.proto:7；sunrise_sunset.proto:7。
// DP-A35 expectation: 工具完整API：`dpToPx(Context,int)→int`；`convertTemperature/convertSpeed/convertPressure(float,from,to)→float`；`updateTemperature/updateWindSpeed/updatePressure(model,from,to)→model`；WeatherCode `searchWeatherCode(int)→Optional<WeatherCode>,getResIdByCode(int)→Optional<Integer>,getIconIdByCode(int,boolean)→Optional<Integer>`；ChangeIndicator `getIndicatorValue(int)→int`；Resource `getData/getMessage,isSuccess/isError/isLoading,getSuccessData/getErrorMes`，Success/Error/Loading构造；NetworkChecker `hasInternetConnection()→boolean`
// anchor: UnitConverter.java:20；WeatherCode.java:51；Resource.java:9；NetworkChecker.java:3。
// SS-A16 expectation: 搜索结果数据 `PlaceInfo` 全部字段均字符串：`toponymName,countryName,countryCode,lang,adminName1,latitude,longitude`；全参构造及各 getter；坐标 `LocationCoordProto` 为 `double latitude,longitude`；缓存设置 `SettingsProto` 只有 `locationCoord,locationName`，不含语言/单位
// anchor: PlaceInfo.java:6；location_coord.proto:7；settings_app.proto:8。
// SS-A20 expectation: 转换完整边界：`float convertTemperature(float,TemperatureUnitProto from,TemperatureUnitProto to)`、`float convertSpeed(float,SpeedUnitProto from,SpeedUnitProto to)`、`float convertPressure(float,PressureUnitProto from,PressureUnitProto to)`；`TemperatureProto updateTemperature(TemperatureProto,TemperatureUnitProto,TemperatureUnitProto)`、`WindSpeedProto updateWindSpeed(WindSpeedProto,SpeedUnitProto,SpeedUnitProto)`、`PressureProto updatePressure(PressureProto,PressureUnitProto,PressureUnitProto)`；采用 Celsius/m/s/hPa 中间量，km/h 系数 `3.6`、mph `0.446944`、mmHg `1.33322`、inHg `33.8638`，更新值全部 `Math.round` 并替换单位
// anchor: UnitConverter.java:24。

export default function modelsTest(): void {
  describe('ModelsSourceDerived', (): void => {
    it('DP-A35 Resource success getters and variant state', 0, (): void => {
      const data = new Forecast();
      const result: Resource<Forecast> = new Success<Forecast>(data);
      expect(result.getData()).assertEqual(data);
      expect(result.getSuccessData()).assertEqual(data);
      expect(result.getMessage()).assertEqual(null);
      expect(result.getErrorMes()).assertEqual(null);
      expect(result.isSuccess()).assertEqual(true);
      expect(result.isError()).assertEqual(false);
      expect(result.isLoading()).assertEqual(false);
    });
    it('DP-A35 Resource error getters and variant state', 0, (): void => {
      const result: Resource<Forecast> = new ResourceError<Forecast>('network failed');
      expect(result.getData()).assertEqual(null);
      expect(result.getSuccessData()).assertEqual(null);
      expect(result.getMessage()).assertEqual('network failed');
      expect(result.getErrorMes()).assertEqual('network failed');
      expect(result.isSuccess()).assertEqual(false);
      expect(result.isError()).assertEqual(true);
      expect(result.isLoading()).assertEqual(false);
    });
    it('DP-A35 Resource loading getters and variant state', 0, (): void => {
      const result: Resource<Forecast> = new Loading<Forecast>();
      expect(result.getData()).assertEqual(null);
      expect(result.getSuccessData()).assertEqual(null);
      expect(result.getMessage()).assertEqual(null);
      expect(result.getErrorMes()).assertEqual(null);
      expect(result.isSuccess()).assertEqual(false);
      expect(result.isError()).assertEqual(false);
      expect(result.isLoading()).assertEqual(true);
    });
    it('DP-A35 Resource nullable optional and falsy payload semantics', 0, (): void => {
      expect(new Success<number>(0).getSuccessData()).assertEqual(0);
      expect(new Success<boolean>(false).getSuccessData()).assertEqual(false);
      expect(new Success<string>('').getSuccessData()).assertEqual('');
      const success = new Success<Forecast>(null);
      expect(success.isSuccess()).assertEqual(true);
      expect(success.getSuccessData()).assertEqual(null);
      expect(new ResourceError<Forecast>('').getErrorMes()).assertEqual('');
      const error = new ResourceError<Forecast>(null);
      expect(error.isError()).assertEqual(true);
      expect(error.getErrorMes()).assertEqual(null);
    });
    it('DP-A35 Resource base constructor is not a variant', 0, (): void => {
      const result = new Resource<number>(0, 'message');
      expect(result.getData()).assertEqual(0);
      expect(result.getMessage()).assertEqual('message');
      expect(result.isSuccess()).assertEqual(false);
      expect(result.isError()).assertEqual(false);
      expect(result.isLoading()).assertEqual(false);
      expect(result.getSuccessData()).assertEqual(null);
      expect(result.getErrorMes()).assertEqual(null);
    });
    it('DP-A23 SS-A20 temperature Java float operations', 0, (): void => {
      expect(convertTemperature(0, TemperatureUnit.CELSIUS, TemperatureUnit.FAHRENHEIT)).assertEqual(32);
      expect(convertTemperature(100, TemperatureUnit.CELSIUS, TemperatureUnit.FAHRENHEIT)).assertEqual(212);
      expect(convertTemperature(32, TemperatureUnit.FAHRENHEIT, TemperatureUnit.CELSIUS)).assertEqual(0);
      expect(convertTemperature(-40, TemperatureUnit.FAHRENHEIT, TemperatureUnit.CELSIUS)).assertEqual(-40);
      expect(convertTemperature(1, TemperatureUnit.FAHRENHEIT, TemperatureUnit.CELSIUS)).assertEqual(-17.22222137451172);
      expect(convertTemperature(1, TemperatureUnit.CELSIUS, TemperatureUnit.CELSIUS)).assertEqual(1);
      expect(convertTemperature(212, TemperatureUnit.FAHRENHEIT, TemperatureUnit.FAHRENHEIT)).assertEqual(212);
    });
    it('DP-A23 SS-A20 complete speed conversion pairs', 0, (): void => {
      const units: SpeedUnit[] = [SpeedUnit.MS, SpeedUnit.KMH, SpeedUnit.MPH];
      // Each source reading corresponds to 1 m/s after the source intermediate cast.
      const readings: number[] = [1, 3.6, 1 / 0.446944];
      const expected: number[] = [1, Math.fround(3.6), Math.fround(1 / 0.446944)];
      for (let from = 0; from < units.length; from++) {
        for (let to = 0; to < units.length; to++) {
          expect(convertSpeed(readings[from], units[from], units[to])).assertEqual(expected[to]);
        }
      }
      expect(convertSpeed(-36, SpeedUnit.KMH, SpeedUnit.MS)).assertEqual(-10);
      expect(convertSpeed(10, SpeedUnit.MPH, SpeedUnit.MS)).assertEqual(Math.fround(4.46944));
    });
    it('DP-A23 SS-A20 complete pressure conversion pairs', 0, (): void => {
      const units: PressureUnit[] = [PressureUnit.HPA, PressureUnit.MMHG, PressureUnit.INHG];
      const readings: number[] = [1, 1 / 1.33322, 1 / 33.8638];
      const expected: number[] = [1, Math.fround(1 / 1.33322), Math.fround(1 / 33.8638)];
      for (let from = 0; from < units.length; from++) {
        for (let to = 0; to < units.length; to++) {
          expect(convertPressure(readings[from], units[from], units[to])).assertEqual(expected[to]);
        }
      }
      expect(convertPressure(760, PressureUnit.MMHG, PressureUnit.HPA)).assertEqual(Math.fround(760 * 1.33322));
      expect(convertPressure(30, PressureUnit.INHG, PressureUnit.HPA)).assertEqual(Math.fround(30 * 33.8638));
    });
    it('DP-A14 DP-A23 Java rounding including negative ties and float index', 0, (): void => {
      expect(javaRoundFloat(-1.5)).assertEqual(-1);
      expect(javaRoundFloat(-0.5)).assertEqual(0);
      expect(1 / javaRoundFloat(-0.5)).assertEqual(Number.POSITIVE_INFINITY);
      expect(javaRoundFloat(1.5)).assertEqual(2);
      expect(javaRoundFloat(Number.NaN)).assertEqual(0);
      expect(javaRoundFloat(Number.POSITIVE_INFINITY)).assertEqual(2147483647);
      expect(javaRoundFloat(Number.NEGATIVE_INFINITY)).assertEqual(-2147483648);
      expect(getTimeIndex(1000, 1000000 + 450000, 900000)).assertEqual(1);
      expect(getTimeIndex(1000, 1000000 - 450000, 900000)).assertEqual(0);
      expect(getTimeIndex(0, 149999999, 100000000)).assertEqual(2);
    });
    it('DP-A23 DP-A28 SS-A20 model updates preserve other fields and original', 0, (): void => {
      const temperature = new Temperature();
      temperature.temperature = 10; temperature.time = '01:00'; temperature.imgIdWeatherCode = 'ic_clear_night';
      const newTemperature = updateTemperature(temperature, TemperatureUnit.CELSIUS, TemperatureUnit.FAHRENHEIT);
      expect(newTemperature.temperature).assertEqual(50);
      expect(newTemperature.temperatureUnit).assertEqual(TemperatureUnit.FAHRENHEIT);
      expect(newTemperature.time).assertEqual('01:00');
      expect(newTemperature.imgIdWeatherCode).assertEqual('ic_clear_night');
      expect(temperature.temperature).assertEqual(10);
      const wind = new WindSpeed();
      wind.speed = 10; wind.speedDiff = 3; wind.imgIdChangeWindSpeed = 'ic_arrow_upgrade';
      const newWind = updateWindSpeed(wind, SpeedUnit.MS, SpeedUnit.KMH);
      expect(newWind.speed).assertEqual(36); expect(newWind.speedUnit).assertEqual(SpeedUnit.KMH);
      expect(newWind.speedDiff).assertEqual(3); expect(newWind.imgIdChangeWindSpeed).assertEqual('ic_arrow_upgrade');
      expect(wind.speed).assertEqual(10);
      const pressure = new Pressure();
      pressure.pressure = 1000; pressure.pressureDiff = 0; pressure.imgIdChangePressure = 'ic_arrow_unchanged';
      const newPressure = updatePressure(pressure, PressureUnit.HPA, PressureUnit.MMHG);
      expect(newPressure.pressure).assertEqual(750); expect(newPressure.pressureUnit).assertEqual(PressureUnit.MMHG);
      expect(newPressure.pressureDiff).assertEqual(0); expect(newPressure.imgIdChangePressure).assertEqual('ic_arrow_unchanged');
      expect(pressure.pressure).assertEqual(1000);
    });
    it('DP-A26 SS-A16 enum values and separate preference defaults', 0, (): void => {
      expect(TemperatureUnit.CELSIUS).assertEqual(0); expect(TemperatureUnit.FAHRENHEIT).assertEqual(1);
      expect(SpeedUnit.MS).assertEqual(0); expect(SpeedUnit.KMH).assertEqual(1); expect(SpeedUnit.MPH).assertEqual(2);
      expect(PressureUnit.MMHG).assertEqual(0); expect(PressureUnit.HPA).assertEqual(1); expect(PressureUnit.INHG).assertEqual(2);
      expect(temperatureUnitFromPreference('celsius')).assertEqual(TemperatureUnit.CELSIUS);
      expect(temperatureUnitFromPreference('fahrenheit')).assertEqual(TemperatureUnit.FAHRENHEIT);
      expect(speedUnitFromPreference('ms')).assertEqual(SpeedUnit.MS);
      expect(speedUnitFromPreference('kmh')).assertEqual(SpeedUnit.KMH);
      expect(speedUnitFromPreference('mph')).assertEqual(SpeedUnit.MPH);
      expect(pressureUnitFromPreference('mmhg')).assertEqual(PressureUnit.MMHG);
      expect(pressureUnitFromPreference('hpa')).assertEqual(PressureUnit.HPA);
      expect(pressureUnitFromPreference('inhg')).assertEqual(PressureUnit.INHG);
      const prefs = new PreferencesSettings();
      expect(prefs.languagePrefs).assertEqual('en'); expect(prefs.temperaturePrefs).assertEqual('celsius');
      expect(prefs.windSpeedPrefs).assertEqual('kmh'); expect(prefs.airPressurePrefs).assertEqual('hpa');
      expect(PreferencesSettings.fromJson(prefs.toJson()).toJson()).assertEqual(prefs.toJson());
      expect(new Settings().toJson()).assertEqual('{"locationCoord":null,"locationName":""}');
      expect(new Snapshot().toJson()).assertEqual('{"settings":null,"forecast":null}');
    });
    it('DP-A19 DP-A20 full 28 weather resources and both icons', 0, (): void => {
      const codes: number[] = [0,1,2,3,45,48,51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99];
      const names: string[] = ['clear_sky','mainly_clear','partly_cloudy','overcast','fog','ice_fog',
        'light_drizzle','drizzle','heavy_drizzle','light_freezing_drizzle','freezing_drizzle','light_rain',
        'rain','heavy_rain','light_freezing_rain','freezing_rain','light_snow','snow','heavy_snow','snow_grains',
        'light_showers','showers','heavy_showers','light_snow_showers','snow_showers','thunderstorm',
        'light_thunderstorm_hail','thunderstorm_hail'];
      const day: string[] = ['ic_clear_day','ic_cloudy_2_day','ic_cloudy_2_day','ic_cloudy','ic_fog','ic_ice_fog',
        'ic_drizzle_1_day','ic_drizzle_2_day','ic_drizzle_3_day','ic_drizzle_and_snow_1_day','ic_drizzle_and_snow_3_day',
        'ic_rainy_1_day','ic_rainy_2_day','ic_rainy_3','ic_rainy_and_snow_1_day','ic_rainy_and_snow_3',
        'ic_snowy_1_day','ic_snowy_2_day','ic_snowy_3','ic_hail','ic_showers_1','ic_showers_2','ic_showers_3',
        'ic_showers_and_snow_1','ic_showers_and_snow_3','ic_thunderstorms','ic_thunderstorms_and_hail',
        'ic_thunderstorms_and_hail_heavy'];
      const night: string[] = ['ic_clear_night','ic_cloudy_2_night','ic_cloudy_2_night','ic_cloudy','ic_fog','ic_ice_fog',
        'ic_drizzle_1_night','ic_drizzle_2_night','ic_drizzle_3_night','ic_drizzle_and_snow_1_night','ic_drizzle_and_snow_3_night',
        'ic_rainy_1_night','ic_rainy_2_night','ic_rainy_3','ic_rainy_and_snow_1_night','ic_rainy_and_snow_3',
        'ic_snowy_1_night','ic_snowy_2_night','ic_snowy_3','ic_hail','ic_showers_1','ic_showers_2','ic_showers_3',
        'ic_showers_and_snow_1','ic_showers_and_snow_3','ic_thunderstorms','ic_thunderstorms_and_hail',
        'ic_thunderstorms_and_hail_heavy'];
      expect(WEATHER_CODES.length).assertEqual(28);
      for (let i = 0; i < codes.length; i++) {
        expect(requireWeatherCode(codes[i]).code).assertEqual(codes[i]);
        expect(getResIdByCode(codes[i])).assertEqual(names[i]);
        expect(getIconIdByCode(codes[i], true)).assertEqual(day[i]);
        expect(getIconIdByCode(codes[i], false)).assertEqual(night[i]);
      }
      expect(searchWeatherCode(-1)).assertEqual(null); expect(searchWeatherCode(4)).assertEqual(null);
      expect(searchWeatherCode(100)).assertEqual(null); expect(getResIdByCode(4)).assertEqual(null);
      expect(getIconIdByCode(4, true)).assertEqual(null);
      let failed = false;
      try { requireWeatherCode(4); } catch { failed = true; }
      expect(failed).assertEqual(true);
    });
    it('DP-A35 change indicators preserve sign mapping', 0, (): void => {
      expect(getIndicatorValue(1)).assertEqual('ic_arrow_upgrade');
      expect(getIndicatorValue(-1)).assertEqual('ic_arrow_downgrade');
      expect(getIndicatorValue(0)).assertEqual('ic_arrow_unchanged');
    });
    it('DP-A26 SS-A16 Place full constructor getters and DTO coordinates', 0, (): void => {
      const place = new Place('test-name', 'test-country', 'ZZ', 'ru', '', '1.25', '-2.5');
      const restored = Place.fromJson(place.toJson());
      expect(restored.getToponymName()).assertEqual('test-name'); expect(restored.getCountryName()).assertEqual('test-country');
      expect(restored.getCountryCode()).assertEqual('ZZ'); expect(restored.getLang()).assertEqual('ru');
      expect(restored.getAdminName1()).assertEqual(''); expect(restored.getLatitude()).assertEqual('1.25');
      expect(restored.getLongitude()).assertEqual('-2.5');
      expect(Coordinates.fromJson(new Coordinates(1.25, -2.5).toJson()).latitude).assertEqual(1.25);
      expect(Coordinates.fromJson(new Coordinates(1.25, -2.5).toJson()).longitude).assertEqual(-2.5);
    });
    it('DP-A27 DP-A28 complete nested DTO roundtrip null zero false', 0, (): void => {
      const day = new DayForecast();
      const temperature = new Temperature();
      temperature.time = ''; temperature.temperature = -1; temperature.imgIdWeatherCode = 'ic_clear_night';
      temperature.temperatureUnit = TemperatureUnit.FAHRENHEIT;
      day.temperature = temperature; day.apparentTemp = Temperature.fromDto(temperature.toDto());
      day.dayTemp = new Temperature(); day.nightTemp = Temperature.fromDto(temperature.toDto());
      day.imgIdWeatherCode = 'ic_clear_night'; day.weatherCode = 'clear_sky'; day.date = '2000-01-01 00:00';
      const sun = new SunriseSunset(); sun.time = '01:00'; sun.hoursDiff = 0; sun.minutesDiff = 0; sun.isFuture = false;
      day.sunrise = sun; day.sunset = new SunriseSunset();
      const wind = new WindSpeed(); wind.speed = 1; wind.speedDiff = 0;
      wind.imgIdChangeWindSpeed = 'ic_arrow_unchanged'; wind.speedUnit = SpeedUnit.KMH; day.windSpeed = wind;
      const pressure = new Pressure(); pressure.pressure = 2; pressure.pressureDiff = -1;
      pressure.imgIdChangePressure = 'ic_arrow_downgrade'; pressure.pressureUnit = PressureUnit.INHG; day.pressure = pressure;
      const uv = new UvIndex(); uv.uvIndex = 3; uv.uvIndexDiff = 0; uv.imgIdChangeUvIndex = 'ic_arrow_unchanged'; day.uvIndex = uv;
      const chance = new PrecipitationChance(); chance.time = ''; chance.percent = 4;
      chance.percentDiff = 0; chance.imgIdPrecipitationChance = 'ic_arrow_unchanged'; day.precipitationChance = chance;
      day.hourlyTempForecast = [temperature, new Temperature()];
      day.precipitationChanceForecast = [chance, new PrecipitationChance()];
      const forecast = new Forecast(); forecast.dayForecast = day; forecast.weekTempForecast = [new Temperature()];
      const settings = new Settings(); settings.locationCoord = new Coordinates(1.25, -2.5); settings.locationName = 'test-name';
      const snapshot = new Snapshot(); snapshot.settings = settings; snapshot.forecast = forecast;
      const restored = Snapshot.fromJson(snapshot.toJson());
      expect(restored.toJson()).assertEqual(snapshot.toJson());
      const restoredForecast = restored.forecast;
      if (restoredForecast === null || restoredForecast.dayForecast === null) { throw new Error('Missing forecast'); }
      expect(restoredForecast.dayForecast.temperature instanceof Temperature).assertEqual(true);
      expect(restoredForecast.dayForecast.windSpeed instanceof WindSpeed).assertEqual(true);
      expect(restoredForecast.dayForecast.sunrise instanceof SunriseSunset).assertEqual(true);
      expect(restoredForecast.weekTempForecast[0].time).assertEqual(null);
      expect(restoredForecast.weekTempForecast[0].imgIdWeatherCode).assertEqual(null);
      expect(restoredForecast.weekTempForecast[0].temperature).assertEqual(0);
      expect(SunriseSunset.fromJson(sun.toJson()).isFuture).assertEqual(false);
      expect(SunriseSunset.fromJson(new SunriseSunset().toJson()).isFuture).assertEqual(null);
      expect(WindSpeed.fromJson(wind.toJson()).speedDiff).assertEqual(0);
      expect(WindSpeed.fromJson(new WindSpeed().toJson()).speedDiff).assertEqual(null);
      expect(Pressure.fromJson(pressure.toJson()).pressureDiff).assertEqual(-1);
      expect(UvIndex.fromJson(uv.toJson()).uvIndexDiff).assertEqual(0);
      expect(PrecipitationChance.fromJson(chance.toJson()).percentDiff).assertEqual(0);
      expect(Forecast.fromJson(forecast.toJson()).toJson()).assertEqual(forecast.toJson());
      expect(DayForecast.fromJson(day.toJson()).toJson()).assertEqual(day.toJson());
      expect(Settings.fromJson(settings.toJson()).toJson()).assertEqual(settings.toJson());
      expect(Temperature.fromJson(temperature.toJson()).time).assertEqual('');
      day.temperature = null; forecast.dayForecast = null; snapshot.forecast = null;
      expect(DayForecast.fromJson(day.toJson()).temperature).assertEqual(null);
      expect(Forecast.fromJson(forecast.toJson()).dayForecast).assertEqual(null);
      expect(Snapshot.fromJson(snapshot.toJson()).forecast).assertEqual(null);
    });
  });
}
