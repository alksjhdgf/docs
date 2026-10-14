import { DataStoreProto } from '../protobuf/datastore';
import { SettingsProto } from '../protobuf/settings_app';
import { LocationCoordProto } from '../protobuf/location_coord';
import { DaysForecastProto } from '../protobuf/days_forecast';
import { DayForecastProto } from '../protobuf/day_forecast';
import { TemperatureProto } from '../protobuf/temperature';
import { WindSpeedProto } from '../protobuf/wind_speed';
import { PressureProto } from '../protobuf/pressure';
import { UvIndexProto } from '../protobuf/uv_index';
import { PrecipitationChanceProto } from '../protobuf/precipitation_chance';
import { SunriseSunsetProto } from '../protobuf/sunrise_sunset';
import { TemperatureUnitProto } from '../protobuf/temperature_unit';
import { SpeedUnitProto } from '../protobuf/speed_unit';
import { PressureUnitProto } from '../protobuf/pressure_unit';
import { Snapshot, Settings, Coordinates, Forecast, DayForecast, Temperature, WindSpeed,
  Pressure, UvIndex, PrecipitationChance, SunriseSunset, TemperatureUnit, SpeedUnit, PressureUnit } from './Models';

// Only real IDs in THIS target build. These are not Android resource IDs.
// Unrecognized imported IDs remain opaque wire-id:<int32>, never guessed names.
function resourceIds(): Map<string, number> {
  return new Map<string, number>([
    ['clear_sky', $r('app.string.clear_sky').id], ['mainly_clear', $r('app.string.mainly_clear').id],
    ['partly_cloudy', $r('app.string.partly_cloudy').id], ['overcast', $r('app.string.overcast').id],
    ['fog', $r('app.string.fog').id], ['ice_fog', $r('app.string.ice_fog').id],
    ['light_drizzle', $r('app.string.light_drizzle').id], ['drizzle', $r('app.string.drizzle').id],
    ['heavy_drizzle', $r('app.string.heavy_drizzle').id],
    ['light_freezing_drizzle', $r('app.string.light_freezing_drizzle').id],
    ['freezing_drizzle', $r('app.string.freezing_drizzle').id],
    ['light_rain', $r('app.string.light_rain').id], ['rain', $r('app.string.rain').id],
    ['heavy_rain', $r('app.string.heavy_rain').id],
    ['light_freezing_rain', $r('app.string.light_freezing_rain').id],
    ['freezing_rain', $r('app.string.freezing_rain').id],
    ['light_snow', $r('app.string.light_snow').id], ['snow', $r('app.string.snow').id],
    ['heavy_snow', $r('app.string.heavy_snow').id], ['snow_grains', $r('app.string.snow_grains').id],
    ['light_showers', $r('app.string.light_showers').id], ['showers', $r('app.string.showers').id],
    ['heavy_showers', $r('app.string.heavy_showers').id],
    ['light_snow_showers', $r('app.string.light_snow_showers').id],
    ['snow_showers', $r('app.string.snow_showers').id], ['thunderstorm', $r('app.string.thunderstorm').id],
    ['light_thunderstorm_hail', $r('app.string.light_thunderstorm_hail').id],
    ['thunderstorm_hail', $r('app.string.thunderstorm_hail').id],
    ['ic_clear_day', $r('app.media.ic_clear_day').id], ['ic_clear_night', $r('app.media.ic_clear_night').id],
    ['ic_cloudy_2_day', $r('app.media.ic_cloudy_2_day').id], ['ic_cloudy_2_night', $r('app.media.ic_cloudy_2_night').id],
    ['ic_cloudy', $r('app.media.ic_cloudy').id], ['ic_fog', $r('app.media.ic_fog').id],
    ['ic_ice_fog', $r('app.media.ic_ice_fog').id],
    ['ic_drizzle_1_day', $r('app.media.ic_drizzle_1_day').id], ['ic_drizzle_1_night', $r('app.media.ic_drizzle_1_night').id],
    ['ic_drizzle_2_day', $r('app.media.ic_drizzle_2_day').id], ['ic_drizzle_2_night', $r('app.media.ic_drizzle_2_night').id],
    ['ic_drizzle_3_day', $r('app.media.ic_drizzle_3_day').id], ['ic_drizzle_3_night', $r('app.media.ic_drizzle_3_night').id],
    ['ic_drizzle_and_snow_1_day', $r('app.media.ic_drizzle_and_snow_1_day').id],
    ['ic_drizzle_and_snow_1_night', $r('app.media.ic_drizzle_and_snow_1_night').id],
    ['ic_drizzle_and_snow_3_day', $r('app.media.ic_drizzle_and_snow_3_day').id],
    ['ic_drizzle_and_snow_3_night', $r('app.media.ic_drizzle_and_snow_3_night').id],
    ['ic_rainy_1_day', $r('app.media.ic_rainy_1_day').id], ['ic_rainy_1_night', $r('app.media.ic_rainy_1_night').id],
    ['ic_rainy_2_day', $r('app.media.ic_rainy_2_day').id], ['ic_rainy_2_night', $r('app.media.ic_rainy_2_night').id],
    ['ic_rainy_3', $r('app.media.ic_rainy_3').id],
    ['ic_rainy_and_snow_1_day', $r('app.media.ic_rainy_and_snow_1_day').id],
    ['ic_rainy_and_snow_1_night', $r('app.media.ic_rainy_and_snow_1_night').id],
    ['ic_rainy_and_snow_3', $r('app.media.ic_rainy_and_snow_3').id],
    ['ic_snowy_1_day', $r('app.media.ic_snowy_1_day').id], ['ic_snowy_1_night', $r('app.media.ic_snowy_1_night').id],
    ['ic_snowy_2_day', $r('app.media.ic_snowy_2_day').id], ['ic_snowy_2_night', $r('app.media.ic_snowy_2_night').id],
    ['ic_snowy_3', $r('app.media.ic_snowy_3').id], ['ic_hail', $r('app.media.ic_hail').id],
    ['ic_showers_1', $r('app.media.ic_showers_1').id], ['ic_showers_2', $r('app.media.ic_showers_2').id],
    ['ic_showers_3', $r('app.media.ic_showers_3').id],
    ['ic_showers_and_snow_1', $r('app.media.ic_showers_and_snow_1').id],
    ['ic_showers_and_snow_3', $r('app.media.ic_showers_and_snow_3').id],
    ['ic_thunderstorms', $r('app.media.ic_thunderstorms').id],
    ['ic_thunderstorms_and_hail', $r('app.media.ic_thunderstorms_and_hail').id],
    ['ic_thunderstorms_and_hail_heavy', $r('app.media.ic_thunderstorms_and_hail_heavy').id],
    ['ic_arrow_upgrade', $r('app.media.ic_arrow_upgrade').id],
    ['ic_arrow_downgrade', $r('app.media.ic_arrow_downgrade').id],
    ['ic_arrow_unchanged', $r('app.media.ic_arrow_unchanged').id]
  ]);
}
function int32(value: number): number {
  if (!Number.isInteger(value) || value < -2147483648 || value > 2147483647) {
    throw new Error('Value is not a protobuf int32');
  }
  return value;
}
function resourceToWire(value: string | null): number | undefined {
  if (value === null) { return undefined; }
  if (value.startsWith('wire-id:')) { return int32(Number(value.substring(8))); }
  const id = resourceIds().get(value);
  if (id === undefined) { throw new Error('No target resource ID for ' + value); }
  return int32(id);
}
function resourceFromWire(value: number): string {
  let name = 'wire-id:' + int32(value).toString();
  resourceIds().forEach((id: number, key: string): void => { if (id === value) { name = key; } });
  return name;
}
function temperatureToWire(value: Temperature | null): TemperatureProto | undefined {
  if (value === null) { return undefined; }
  const result = new TemperatureProto();
  result.time = value.time ?? undefined; result.temperature = int32(value.temperature);
  result.imgIdWeatherCode = resourceToWire(value.imgIdWeatherCode);
  result.temperatureUnit = value.temperatureUnit as number as TemperatureUnitProto;
  return result;
}
function temperatureFromWire(value: TemperatureProto | undefined): Temperature | null {
  if (value === undefined) { return null; }
  const result = new Temperature(); result.time = value.hasTime() ? value.time : null;
  result.temperature = value.temperature ?? 0;
  result.imgIdWeatherCode = value.hasImgIdWeatherCode() ? resourceFromWire(value.imgIdWeatherCode) : null;
  result.temperatureUnit = (value.temperatureUnit ?? 0) as number as TemperatureUnit;
  return result;
}
function rainToWire(value: PrecipitationChance | null): PrecipitationChanceProto | undefined {
  if (value === null) { return undefined; }
  const result = new PrecipitationChanceProto(); result.time = value.time ?? undefined;
  result.percent = int32(value.percent); result.percentDiff = value.percentDiff === null ? undefined : int32(value.percentDiff);
  result.imgIdPrecipitationChance = resourceToWire(value.imgIdPrecipitationChance); return result;
}
function rainFromWire(value: PrecipitationChanceProto | undefined): PrecipitationChance | null {
  if (value === undefined) { return null; }
  const result = new PrecipitationChance(); result.time = value.hasTime() ? value.time : null;
  result.percent = value.percent ?? 0; result.percentDiff = value.hasPercentDiff() ? value.percentDiff : null;
  result.imgIdPrecipitationChance = value.hasImgIdPrecipitationChance() ? resourceFromWire(value.imgIdPrecipitationChance) : null;
  return result;
}
function sunToWire(value: SunriseSunset | null): SunriseSunsetProto | undefined {
  if (value === null) { return undefined; }
  const result = new SunriseSunsetProto(); result.time = value.time;
  result.hoursDiff = value.hoursDiff === null ? undefined : int32(value.hoursDiff);
  result.minutesDiff = value.minutesDiff === null ? undefined : int32(value.minutesDiff);
  result.isFuture = value.isFuture ?? undefined; return result;
}
function sunFromWire(value: SunriseSunsetProto | undefined): SunriseSunset | null {
  if (value === undefined) { return null; }
  const result = new SunriseSunset(); result.time = value.time ?? '';
  result.hoursDiff = value.hasHoursDiff() ? value.hoursDiff : null;
  result.minutesDiff = value.hasMinutesDiff() ? value.minutesDiff : null;
  result.isFuture = value.hasIsFuture() ? value.isFuture : null; return result;
}
function dayToWire(value: DayForecast): DayForecastProto {
  const result = new DayForecastProto(); result.temperature = temperatureToWire(value.temperature);
  result.apparentTemp = temperatureToWire(value.apparentTemp); result.dayTemp = temperatureToWire(value.dayTemp);
  result.nightTemp = temperatureToWire(value.nightTemp);
  result.imgIdWeatherCode = resourceToWire(value.imgIdWeatherCode) ?? 0;
  result.weatherCode = resourceToWire(value.weatherCode) ?? 0; result.date = value.date;
  result.sunrise = sunToWire(value.sunrise); result.sunset = sunToWire(value.sunset);
  result.precipitationChance = rainToWire(value.precipitationChance);
  if (value.windSpeed !== null) {
    const wind = new WindSpeedProto(); wind.speed = int32(value.windSpeed.speed);
    wind.speedDiff = value.windSpeed.speedDiff === null ? undefined : int32(value.windSpeed.speedDiff);
    wind.imgIdChangeWindSpeed = resourceToWire(value.windSpeed.imgIdChangeWindSpeed);
    wind.speedUnit = value.windSpeed.speedUnit as number as SpeedUnitProto; result.windSpeed = wind;
  }
  if (value.pressure !== null) {
    const pressure = new PressureProto(); pressure.pressure = int32(value.pressure.pressure);
    pressure.pressureDiff = value.pressure.pressureDiff === null ? undefined : int32(value.pressure.pressureDiff);
    pressure.imgIdChangePressure = resourceToWire(value.pressure.imgIdChangePressure);
    pressure.pressureUnit = value.pressure.pressureUnit as number as PressureUnitProto; result.pressure = pressure;
  }
  if (value.uvIndex !== null) {
    const uv = new UvIndexProto(); uv.uvIndex = int32(value.uvIndex.uvIndex);
    uv.uvIndexDiff = value.uvIndex.uvIndexDiff === null ? undefined : int32(value.uvIndex.uvIndexDiff);
    uv.imgIdChangeUvIndex = resourceToWire(value.uvIndex.imgIdChangeUvIndex); result.uvIndex = uv;
  }
  value.hourlyTempForecast.forEach((item: Temperature): void => {
    const wire = temperatureToWire(item); if (wire !== undefined) { result.hourlyTempForecast.push(wire); }
  });
  value.precipitationChanceForecast.forEach((item: PrecipitationChance): void => {
    const wire = rainToWire(item); if (wire !== undefined) { result.precipitationChanceForecast.push(wire); }
  });
  return result;
}
function dayFromWire(value: DayForecastProto): DayForecast {
  const result = new DayForecast(); result.temperature = temperatureFromWire(value.temperature);
  result.apparentTemp = temperatureFromWire(value.apparentTemp); result.dayTemp = temperatureFromWire(value.dayTemp);
  result.nightTemp = temperatureFromWire(value.nightTemp);
  result.imgIdWeatherCode = resourceFromWire(value.imgIdWeatherCode ?? 0);
  result.weatherCode = resourceFromWire(value.weatherCode ?? 0); result.date = value.date ?? '';
  result.sunrise = sunFromWire(value.sunrise); result.sunset = sunFromWire(value.sunset);
  result.precipitationChance = rainFromWire(value.precipitationChance);
  const wind = value.windSpeed;
  if (wind !== undefined) {
    result.windSpeed = new WindSpeed(); result.windSpeed.speed = wind.speed ?? 0;
    result.windSpeed.speedDiff = wind.hasSpeedDiff() ? wind.speedDiff : null;
    result.windSpeed.imgIdChangeWindSpeed = wind.hasImgIdChangeWindSpeed() ? resourceFromWire(wind.imgIdChangeWindSpeed) : null;
    result.windSpeed.speedUnit = (wind.speedUnit ?? 0) as number as SpeedUnit;
  }
  const pressure = value.pressure;
  if (pressure !== undefined) {
    result.pressure = new Pressure(); result.pressure.pressure = pressure.pressure ?? 0;
    result.pressure.pressureDiff = pressure.hasPressureDiff() ? pressure.pressureDiff : null;
    result.pressure.imgIdChangePressure = pressure.hasImgIdChangePressure() ? resourceFromWire(pressure.imgIdChangePressure) : null;
    result.pressure.pressureUnit = (pressure.pressureUnit ?? 0) as number as PressureUnit;
  }
  const uv = value.uvIndex;
  if (uv !== undefined) {
    result.uvIndex = new UvIndex(); result.uvIndex.uvIndex = uv.uvIndex ?? 0;
    result.uvIndex.uvIndexDiff = uv.hasUvIndexDiff() ? uv.uvIndexDiff : null;
    result.uvIndex.imgIdChangeUvIndex = uv.hasImgIdChangeUvIndex() ? resourceFromWire(uv.imgIdChangeUvIndex) : null;
  }
  value.hourlyTempForecast.forEach((item: TemperatureProto): void => {
    const model = temperatureFromWire(item); if (model !== null) { result.hourlyTempForecast.push(model); }
  });
  value.precipitationChanceForecast.forEach((item: PrecipitationChanceProto): void => {
    const model = rainFromWire(item); if (model !== null) { result.precipitationChanceForecast.push(model); }
  });
  return result;
}
export function encodeSnapshot(value: Snapshot): ArrayBuffer {
  const wire = new DataStoreProto();
  if (value.settings !== null) {
    const settings = new SettingsProto(); settings.locationName = value.settings.locationName;
    if (value.settings.locationCoord !== null) {
      const coord = new LocationCoordProto(); coord.latitude = value.settings.locationCoord.latitude;
      coord.longitude = value.settings.locationCoord.longitude; settings.locationCoord = coord;
    }
    wire.settings = settings;
  }
  if (value.forecast !== null) {
    const forecast = new DaysForecastProto();
    if (value.forecast.dayForecast !== null) { forecast.dayForecast = dayToWire(value.forecast.dayForecast); }
    value.forecast.weekTempForecast.forEach((item: Temperature): void => {
      const temperature = temperatureToWire(item); if (temperature !== undefined) { forecast.weekTempForecast.push(temperature); }
    });
    wire.forecast = forecast;
  }
  const bytes = DataStoreProto.encode(wire);
  if (bytes === undefined) { throw new Error('Native protobuf encode failed'); }
  return bytes;
}
export function decodeSnapshot(bytes: ArrayBuffer, part: 'all' | 'settings' | 'forecast' = 'all'): Snapshot {
  const wire = DataStoreProto.decode(bytes);
  if (wire === undefined) { throw new Error('Native protobuf decode failed'); }
  const result = new Snapshot(); const settings = wire.settings; const forecast = wire.forecast;
  if (part !== 'forecast' && settings !== undefined) {
    result.settings = new Settings(); result.settings.locationName = settings.locationName ?? '';
    const coord = settings.locationCoord;
    if (coord !== undefined) { result.settings.locationCoord = new Coordinates(coord.latitude ?? 0, coord.longitude ?? 0); }
  }
  if (part !== 'settings' && forecast !== undefined) {
    result.forecast = new Forecast();
    if (forecast.dayForecast !== undefined) { result.forecast.dayForecast = dayFromWire(forecast.dayForecast); }
    forecast.weekTempForecast.forEach((item: TemperatureProto): void => {
      const temperature = temperatureFromWire(item); if (temperature !== null) { result.forecast?.weekTempForecast.push(temperature); }
    });
  }
  return result;
}
