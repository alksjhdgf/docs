import { http } from '@kit.NetworkKit';
import { i18n } from '@kit.LocalizationKit';
import { Forecast, DayForecast, Temperature, WindSpeed, Pressure, UvIndex, PrecipitationChance,
  SunriseSunset, TemperatureUnit, SpeedUnit, PressureUnit } from '../core/Models';
import { javaRoundFloat, getTimeIndex } from '../core/Units';
import { requireWeatherCode, getIndicatorValue } from '../core/WeatherCodes';
import { FlatForecast, FlatSeries, FlatVariable } from './FlatForecast';

export function buildWeatherForecastUrl(latitude: number, longitude: number,
  temperatureUnit: TemperatureUnit = TemperatureUnit.CELSIUS, speedUnit: SpeedUnit = SpeedUnit.KMH): string {
  const temperature = temperatureUnit === TemperatureUnit.CELSIUS ? 'celsius' : 'fahrenheit';
  const speed = speedUnit === SpeedUnit.KMH ? 'kmh' : speedUnit === SpeedUnit.MS ? 'ms' : 'mph';
  return 'https://api.open-meteo.com/v1/forecast?latitude=' + encodeURIComponent(latitude.toString()) +
    '&longitude=' + encodeURIComponent(longitude.toString()) + '&temperature_unit=' + temperature +
    '&wind_speed_unit=' + speed + '&pressure_msl=hpa&timeformat=unixtime&timezone=auto&past_days=6&forecast_days=10&format=flatbuffers' +
    '&minutely_15=' + encodeURIComponent('weather_code,temperature_2m,apparent_temperature,wind_speed_10m') +
    '&hourly=' + encodeURIComponent('weather_code,temperature_2m,precipitation_probability,uv_index,pressure_msl,is_day') +
    '&daily=' + encodeURIComponent('weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset');
}
export class WeatherCalendarFields {
  year: number = 0;
  month: number = 0;
  date: number = 0;
  dayOfWeek: number = 0;
  hour: number = 0;
  minute: number = 0;
}
export function calendarAt(epochMs: number, timezone: string | null): WeatherCalendarFields {
  const calendar = i18n.getCalendar(i18n.System.getSystemLanguage(), 'gregory');
  if (timezone !== null) { calendar.setTimeZone(timezone); }
  calendar.setTime(epochMs);
  const fields = new WeatherCalendarFields();
  fields.year = calendar.get('year'); fields.month = calendar.get('month'); fields.date = calendar.get('date');
  fields.dayOfWeek = calendar.get('day_of_week'); fields.hour = calendar.get('hour_of_day');
  fields.minute = calendar.get('minute');
  return fields;
}
function pad(value: number): string { return value.toString().padStart(2, '0'); }
export function cityTime(epochMs: number, timezone: string,
  readCalendar: (epochMs: number, timezone: string | null) => WeatherCalendarFields = calendarAt): string {
  const calendar = readCalendar(epochMs, timezone);
  return pad(calendar.hour) + ':' + pad(calendar.minute);
}
function updatedAt(nowMs: number,
  readCalendar: (epochMs: number, timezone: string | null) => WeatherCalendarFields): string {
  const calendar = readCalendar(nowMs, null);
  return calendar.year.toString().padStart(4, '0') + '-' + pad(calendar.month + 1) + '-' +
    pad(calendar.date) + ' ' + pad(calendar.hour) + ':' + pad(calendar.minute);
}
function sunValue(epochMs: number, nowMs: number, timezone: string,
  readCalendar: (epochMs: number, timezone: string | null) => WeatherCalendarFields): SunriseSunset {
  const sun = readCalendar(epochMs, null);
  const now = readCalendar(nowMs, timezone);
  const result = new SunriseSunset();
  result.time = cityTime(epochMs, timezone, readCalendar);
  result.hoursDiff = Math.abs(sun.hour - now.hour);
  result.minutesDiff = Math.abs(sun.minute - now.minute);
  result.isFuture = nowMs < epochMs;
  return result;
}
function difference(series: FlatSeries, id: FlatVariable, index: number): number {
  return javaRoundFloat(series.value(id, index)) - javaRoundFloat(series.value(id, index - 24));
}
// Java float-to-int narrowing also defines NaN and overflow, unlike Math.trunc alone.
function javaInt(value: number): number {
  if (Number.isNaN(value)) { return 0; }
  if (value >= 2147483647) { return 2147483647; }
  if (value <= -2147483648) { return -2147483648; }
  const integer = Math.trunc(value);
  return integer === 0 ? 0 : integer;
}
export interface WeatherClient {
  fetchWeatherForecast(latitude: number, longitude: number): Promise<Forecast>;
  getTemperatureUnit(): TemperatureUnit; setTemperatureUnit(unit: TemperatureUnit): void;
  getSpeedUnit(): SpeedUnit; setSpeedUnit(unit: SpeedUnit): void;
  getPressureUnit(): PressureUnit; setPressureUnit(unit: PressureUnit): void;
}
export class OpenMeteoClient implements WeatherClient {
  // DP-A43 decisions: preserve Sunday week start, current-isDay hourly icons, mixed
  // device/city sun fields, NaN Java narrowing and raw-unit diffs. Missing variables and
  // unknown codes fail, never synthesize observations. Request retries/cancellation,
  // deduplication and versioning remain absent (old-request overwrite remains possible).
  // Use per-call native calendars instead of Java's shared formatter: deliberate race
  // isolation, not a change to timezone arithmetic. dayTemp conversion omission and
  // settings/cache initialization/null-refresh races belong to WeatherService, unchanged.
  private readCalendar: (epochMs: number, timezone: string | null) => WeatherCalendarFields;
  private decodeTimezone: ((bytes: Uint8Array) => string) | undefined;
  constructor(readCalendar: (epochMs: number, timezone: string | null) => WeatherCalendarFields = calendarAt,
    decodeTimezone?: (bytes: Uint8Array) => string) {
    this.readCalendar = readCalendar; this.decodeTimezone = decodeTimezone;
  }
  private temperatureUnit: TemperatureUnit = TemperatureUnit.CELSIUS;
  private speedUnit: SpeedUnit = SpeedUnit.KMH;
  private pressureUnit: PressureUnit = PressureUnit.HPA;
  getTemperatureUnit(): TemperatureUnit { return this.temperatureUnit; }
  setTemperatureUnit(unit: TemperatureUnit): void { this.temperatureUnit = unit; }
  getSpeedUnit(): SpeedUnit { return this.speedUnit; }
  setSpeedUnit(unit: SpeedUnit): void { this.speedUnit = unit; }
  getPressureUnit(): PressureUnit { return this.pressureUnit; }
  setPressureUnit(unit: PressureUnit): void { this.pressureUnit = unit; }
  buildWeatherForecastUrl(latitude: number, longitude: number): string {
    return buildWeatherForecastUrl(latitude, longitude, this.temperatureUnit, this.speedUnit);
  }
  async fetchWeatherForecast(latitude: number, longitude: number): Promise<Forecast> {
    const connection = http.createHttp();
    try {
      const options: http.HttpRequestOptions = { method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, connectTimeout: 10000, readTimeout: 30000 };
      const response = await connection.request(this.buildWeatherForecastUrl(latitude, longitude), options);
      if (!(response.result instanceof ArrayBuffer)) {
        throw new Error(response.responseCode < 200 || response.responseCode >= 300 ?
          'ERROR REQUEST SERVER: api.open-meteo ' + response.responseCode : 'Empty body');
      }
      return this.parseHttpResponse(response.responseCode, response.result);
    } finally { connection.destroy(); }
  }
  parseHttpResponse(status: number, body: ArrayBuffer): Forecast {
    // Rx Single's first onError is terminal, but the source callback keeps reading and
    // parsing. Preserve both: consume the response, then reject with the first error.
    try {
      if (body.byteLength === 0) { throw new Error('Empty body'); }
      return this.parseWeatherData(body);
    }
    finally {
      if (status < 200 || status >= 300) {
        throw new Error('ERROR REQUEST SERVER: api.open-meteo ' + status);
      }
    }
  }
  private temperature(value: number): Temperature {
    const result = new Temperature();
    result.temperature = value; result.temperatureUnit = this.temperatureUnit;
    return result;
  }
  parseWeatherData(buffer: ArrayBuffer, nowMs: number = Date.now()): Forecast {
    const response = new FlatForecast(buffer, this.decodeTimezone);
    const minute = response.minutely15();
    const hourly = response.hourly();
    const daily = response.daily();
    const timezone = response.timezone();
    const now = this.readCalendar(nowMs, timezone);
    const minuteIndex = getTimeIndex(minute.time(), nowMs, 900000);
    const hourIndex = getTimeIndex(hourly.time(), nowMs, 3600000);
    const isDay = javaInt(hourly.value(FlatVariable.IS_DAY, hourIndex));
    let dayMax = -2147483648;
    let nightMin = 2147483647;
    const dayStart = hourIndex - now.hour - 1;
    for (let i = dayStart; i < dayStart + 24; i++) {
      const temp = javaInt(hourly.value(FlatVariable.TEMPERATURE, i));
      if (hourly.value(FlatVariable.IS_DAY, i) === 1) { dayMax = Math.max(dayMax, temp); }
      else { nightMin = Math.min(nightMin, temp); }
    }
    const day = new DayForecast();
    day.temperature = this.temperature(javaRoundFloat(minute.value(FlatVariable.TEMPERATURE, minuteIndex)));
    day.apparentTemp = this.temperature(javaRoundFloat(minute.value(FlatVariable.APPARENT_TEMPERATURE, minuteIndex)));
    day.dayTemp = this.temperature(dayMax); day.nightTemp = this.temperature(nightMin);
    const code = requireWeatherCode(javaInt(minute.value(FlatVariable.WEATHER_CODE, minuteIndex)));
    day.imgIdWeatherCode = isDay === 1 ? code.iconDayId : code.iconNightId;
    day.weatherCode = code.resId; day.date = updatedAt(nowMs, this.readCalendar);
    const sunsetMs = daily.value(FlatVariable.SUNSET, 6, true) * 1000;
    day.sunrise = sunValue(daily.value(FlatVariable.SUNRISE, nowMs > sunsetMs ? 7 : 6, true) * 1000, nowMs, timezone, this.readCalendar);
    day.sunset = sunValue(sunsetMs, nowMs, timezone, this.readCalendar);
    const wind = new WindSpeed();
    const windDiff = difference(minute, FlatVariable.WIND_SPEED, minuteIndex);
    wind.speed = javaRoundFloat(minute.value(FlatVariable.WIND_SPEED, minuteIndex));
    wind.speedDiff = Math.abs(windDiff); wind.imgIdChangeWindSpeed = getIndicatorValue(windDiff);
    wind.speedUnit = this.speedUnit; day.windSpeed = wind;
    const rain = new PrecipitationChance();
    const rainDiff = difference(hourly, FlatVariable.PRECIPITATION_PROBABILITY, hourIndex);
    rain.time = ''; rain.percent = javaRoundFloat(hourly.value(FlatVariable.PRECIPITATION_PROBABILITY, hourIndex));
    rain.percentDiff = Math.abs(rainDiff); rain.imgIdPrecipitationChance = getIndicatorValue(rainDiff);
    day.precipitationChance = rain;
    const pressure = new Pressure();
    const pressureDiff = difference(hourly, FlatVariable.PRESSURE_MSL, hourIndex);
    // Source labels raw hPa with the selected unit, including its visible mismatch.
    // Fixing that bug conflicts with frozen DP-A25; see client-accept-fix-evidence.md.
    pressure.pressure = javaRoundFloat(hourly.value(FlatVariable.PRESSURE_MSL, hourIndex));
    pressure.pressureDiff = Math.abs(pressureDiff); pressure.imgIdChangePressure = getIndicatorValue(pressureDiff);
    pressure.pressureUnit = this.pressureUnit; day.pressure = pressure;
    const uv = new UvIndex();
    const uvDiff = difference(hourly, FlatVariable.UV_INDEX, hourIndex);
    uv.uvIndex = javaRoundFloat(hourly.value(FlatVariable.UV_INDEX, hourIndex));
    uv.uvIndexDiff = Math.abs(uvDiff); uv.imgIdChangeUvIndex = getIndicatorValue(uvDiff); day.uvIndex = uv;
    for (let i = hourIndex; i < hourIndex + 24; i++) {
      const temperature = this.temperature(javaRoundFloat(hourly.value(FlatVariable.TEMPERATURE, i)));
      temperature.time = cityTime((hourly.time() + hourly.interval() * i) * 1000, timezone, this.readCalendar);
      const hourCode = requireWeatherCode(javaInt(hourly.value(FlatVariable.WEATHER_CODE, i)));
      temperature.imgIdWeatherCode = isDay === 1 ? hourCode.iconDayId : hourCode.iconNightId;
      day.hourlyTempForecast.push(temperature);
      const chance = new PrecipitationChance();
      chance.time = temperature.time; chance.percent = javaInt(hourly.value(FlatVariable.PRECIPITATION_PROBABILITY, i));
      day.precipitationChanceForecast.push(chance);
    }
    const forecast = new Forecast(); forecast.dayForecast = day;
    const weekStart = hourIndex - ((now.dayOfWeek - 1) * 24 + now.hour);
    for (let i = weekStart; i < weekStart + 168; i++) {
      forecast.weekTempForecast.push(this.temperature(javaRoundFloat(hourly.value(FlatVariable.TEMPERATURE, i))));
    }
    return forecast;
  }
}
