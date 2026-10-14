export class WeatherCode {
  readonly code: number;
  readonly resId: string;
  readonly iconDayId: string;
  readonly iconNightId: string;
  constructor(code: number, resId: string, iconDayId: string, iconNightId: string) {
    this.code = code; this.resId = resId; this.iconDayId = iconDayId; this.iconNightId = iconNightId;
  }
  static searchWeatherCode(code: number): WeatherCode | null { return searchWeatherCode(code); }
  static getResIdByCode(code: number): string | null { return getResIdByCode(code); }
  static getIconIdByCode(code: number, isDay: boolean): string | null { return getIconIdByCode(code, isDay); }
}
// WeatherCode.java:15-42, sorted for the source binary search.
export const WEATHER_CODES: WeatherCode[] = [
  new WeatherCode(0, 'clear_sky', 'ic_clear_day', 'ic_clear_night'),
  new WeatherCode(1, 'mainly_clear', 'ic_cloudy_2_day', 'ic_cloudy_2_night'),
  new WeatherCode(2, 'partly_cloudy', 'ic_cloudy_2_day', 'ic_cloudy_2_night'),
  new WeatherCode(3, 'overcast', 'ic_cloudy', 'ic_cloudy'),
  new WeatherCode(45, 'fog', 'ic_fog', 'ic_fog'),
  new WeatherCode(48, 'ice_fog', 'ic_ice_fog', 'ic_ice_fog'),
  new WeatherCode(51, 'light_drizzle', 'ic_drizzle_1_day', 'ic_drizzle_1_night'),
  new WeatherCode(53, 'drizzle', 'ic_drizzle_2_day', 'ic_drizzle_2_night'),
  new WeatherCode(55, 'heavy_drizzle', 'ic_drizzle_3_day', 'ic_drizzle_3_night'),
  new WeatherCode(56, 'light_freezing_drizzle', 'ic_drizzle_and_snow_1_day', 'ic_drizzle_and_snow_1_night'),
  new WeatherCode(57, 'freezing_drizzle', 'ic_drizzle_and_snow_3_day', 'ic_drizzle_and_snow_3_night'),
  new WeatherCode(61, 'light_rain', 'ic_rainy_1_day', 'ic_rainy_1_night'),
  new WeatherCode(63, 'rain', 'ic_rainy_2_day', 'ic_rainy_2_night'),
  new WeatherCode(65, 'heavy_rain', 'ic_rainy_3', 'ic_rainy_3'),
  new WeatherCode(66, 'light_freezing_rain', 'ic_rainy_and_snow_1_day', 'ic_rainy_and_snow_1_night'),
  new WeatherCode(67, 'freezing_rain', 'ic_rainy_and_snow_3', 'ic_rainy_and_snow_3'),
  new WeatherCode(71, 'light_snow', 'ic_snowy_1_day', 'ic_snowy_1_night'),
  new WeatherCode(73, 'snow', 'ic_snowy_2_day', 'ic_snowy_2_night'),
  new WeatherCode(75, 'heavy_snow', 'ic_snowy_3', 'ic_snowy_3'),
  new WeatherCode(77, 'snow_grains', 'ic_hail', 'ic_hail'),
  new WeatherCode(80, 'light_showers', 'ic_showers_1', 'ic_showers_1'),
  new WeatherCode(81, 'showers', 'ic_showers_2', 'ic_showers_2'),
  new WeatherCode(82, 'heavy_showers', 'ic_showers_3', 'ic_showers_3'),
  new WeatherCode(85, 'light_snow_showers', 'ic_showers_and_snow_1', 'ic_showers_and_snow_1'),
  new WeatherCode(86, 'snow_showers', 'ic_showers_and_snow_3', 'ic_showers_and_snow_3'),
  new WeatherCode(95, 'thunderstorm', 'ic_thunderstorms', 'ic_thunderstorms'),
  new WeatherCode(96, 'light_thunderstorm_hail', 'ic_thunderstorms_and_hail', 'ic_thunderstorms_and_hail'),
  new WeatherCode(99, 'thunderstorm_hail', 'ic_thunderstorms_and_hail_heavy', 'ic_thunderstorms_and_hail_heavy')
];
export function searchWeatherCode(code: number): WeatherCode | null {
  if (!Number.isInteger(code)) { return null; }
  let left = 0;
  let right = WEATHER_CODES.length - 1;
  while (left <= right) {
    const mid = left + Math.trunc((right - left) / 2);
    const value = WEATHER_CODES[mid];
    if (code > value.code) { left = mid + 1; }
    else if (code < value.code) { right = mid - 1; }
    else { return value; }
  }
  return null;
}
export function getResIdByCode(code: number): string | null {
  const value = searchWeatherCode(code);
  return value === null ? null : value.resId;
}
export function getIconIdByCode(code: number, isDay: boolean): string | null {
  const value = searchWeatherCode(code);
  return value === null ? null : isDay ? value.iconDayId : value.iconNightId;
}
// Explicit equivalent of the source caller's Optional.get(), not a clear-sky fallback.
export function requireWeatherCode(code: number): WeatherCode {
  const value = searchWeatherCode(code);
  if (value === null) { throw new Error('Unknown weather code: ' + code); }
  return value;
}
export function getIndicatorValue(value: number): string {
  return value > 0 ? 'ic_arrow_upgrade' : value < 0 ? 'ic_arrow_downgrade' : 'ic_arrow_unchanged';
}
export class ChangeIndicator {
  static getIndicatorValue(value: number): string { return getIndicatorValue(value); }
}
