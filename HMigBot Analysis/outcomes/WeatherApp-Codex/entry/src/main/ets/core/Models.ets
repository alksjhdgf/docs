// Source: app/src/main/proto/*.proto. Resource IDs become stable resource names.
// Plain models intentionally have no observation decorators; persistence uses DTOs.
export enum TemperatureUnit { CELSIUS = 0, FAHRENHEIT = 1 }
export enum SpeedUnit { MS = 0, KMH = 1, MPH = 2 }
export enum PressureUnit { MMHG = 0, HPA = 1, INHG = 2 }

// Source: util/Resource.java. Java Optional is represented by an explicit nullable
// value, as with weather-code lookup. State depends on the variant, not payload
// truthiness: null success data and an empty error message remain valid states.
export class Resource<T> {
  private readonly data: T | null;
  private readonly message: string | null;
  constructor(data: T | null, message: string | null) {
    this.data = data;
    this.message = message;
  }
  getData(): T | null { return this.data; }
  getMessage(): string | null { return this.message; }
  isSuccess(): boolean { return this instanceof Success; }
  isError(): boolean { return this instanceof ResourceError; }
  isLoading(): boolean { return this instanceof Loading; }
  getSuccessData(): T | null { return this.isSuccess() ? this.getData() : null; }
  getErrorMes(): string | null { return this.isError() ? this.getMessage() : null; }
}
export class Success<T> extends Resource<T> {
  constructor(data: T | null) { super(data, null); }
}
// Keep the internal name distinct from the platform Error used for exceptions.
export class ResourceError<T> extends Resource<T> {
  constructor(message: string | null) { super(null, message); }
}
export { ResourceError as Error };
export class Loading<T> extends Resource<T> {
  constructor() { super(null, null); }
}

export interface TemperatureDTO {
  time: string | null;
  temperature: number;
  imgIdWeatherCode: string | null;
  temperatureUnit: TemperatureUnit;
}
export class Temperature {
  time: string | null = null;
  temperature: number = 0;
  imgIdWeatherCode: string | null = null;
  temperatureUnit: TemperatureUnit = TemperatureUnit.CELSIUS;
  toDto(): TemperatureDTO {
    return { time: this.time, temperature: this.temperature,
      imgIdWeatherCode: this.imgIdWeatherCode, temperatureUnit: this.temperatureUnit };
  }
  static fromDto(dto: TemperatureDTO): Temperature {
    const value = new Temperature();
    value.time = dto.time ?? null;
    value.temperature = dto.temperature;
    value.imgIdWeatherCode = dto.imgIdWeatherCode ?? null;
    value.temperatureUnit = dto.temperatureUnit;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Temperature { return Temperature.fromDto(JSON.parse(json) as TemperatureDTO); }
}
export interface WindSpeedDTO {
  speed: number;
  speedDiff: number | null;
  imgIdChangeWindSpeed: string | null;
  speedUnit: SpeedUnit;
}
export class WindSpeed {
  speed: number = 0;
  speedDiff: number | null = null;
  imgIdChangeWindSpeed: string | null = null;
  speedUnit: SpeedUnit = SpeedUnit.MS;
  toDto(): WindSpeedDTO {
    return { speed: this.speed, speedDiff: this.speedDiff,
      imgIdChangeWindSpeed: this.imgIdChangeWindSpeed, speedUnit: this.speedUnit };
  }
  static fromDto(dto: WindSpeedDTO): WindSpeed {
    const value = new WindSpeed();
    value.speed = dto.speed;
    value.speedDiff = dto.speedDiff ?? null;
    value.imgIdChangeWindSpeed = dto.imgIdChangeWindSpeed ?? null;
    value.speedUnit = dto.speedUnit;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): WindSpeed { return WindSpeed.fromDto(JSON.parse(json) as WindSpeedDTO); }
}
export interface PressureDTO {
  pressure: number;
  pressureDiff: number | null;
  imgIdChangePressure: string | null;
  pressureUnit: PressureUnit;
}
export class Pressure {
  pressure: number = 0;
  pressureDiff: number | null = null;
  imgIdChangePressure: string | null = null;
  pressureUnit: PressureUnit = PressureUnit.MMHG;
  toDto(): PressureDTO {
    return { pressure: this.pressure, pressureDiff: this.pressureDiff,
      imgIdChangePressure: this.imgIdChangePressure, pressureUnit: this.pressureUnit };
  }
  static fromDto(dto: PressureDTO): Pressure {
    const value = new Pressure();
    value.pressure = dto.pressure;
    value.pressureDiff = dto.pressureDiff ?? null;
    value.imgIdChangePressure = dto.imgIdChangePressure ?? null;
    value.pressureUnit = dto.pressureUnit;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Pressure { return Pressure.fromDto(JSON.parse(json) as PressureDTO); }
}
export interface UvIndexDTO {
  uvIndex: number;
  uvIndexDiff: number | null;
  imgIdChangeUvIndex: string | null;
}
export class UvIndex {
  uvIndex: number = 0;
  uvIndexDiff: number | null = null;
  imgIdChangeUvIndex: string | null = null;
  toDto(): UvIndexDTO {
    return { uvIndex: this.uvIndex, uvIndexDiff: this.uvIndexDiff, imgIdChangeUvIndex: this.imgIdChangeUvIndex };
  }
  static fromDto(dto: UvIndexDTO): UvIndex {
    const value = new UvIndex();
    value.uvIndex = dto.uvIndex;
    value.uvIndexDiff = dto.uvIndexDiff ?? null;
    value.imgIdChangeUvIndex = dto.imgIdChangeUvIndex ?? null;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): UvIndex { return UvIndex.fromDto(JSON.parse(json) as UvIndexDTO); }
}
export interface PrecipitationChanceDTO {
  time: string | null;
  percent: number;
  percentDiff: number | null;
  imgIdPrecipitationChance: string | null;
}
export class PrecipitationChance {
  time: string | null = null;
  percent: number = 0;
  percentDiff: number | null = null;
  imgIdPrecipitationChance: string | null = null;
  toDto(): PrecipitationChanceDTO {
    return { time: this.time, percent: this.percent, percentDiff: this.percentDiff,
      imgIdPrecipitationChance: this.imgIdPrecipitationChance };
  }
  static fromDto(dto: PrecipitationChanceDTO): PrecipitationChance {
    const value = new PrecipitationChance();
    value.time = dto.time ?? null;
    value.percent = dto.percent;
    value.percentDiff = dto.percentDiff ?? null;
    value.imgIdPrecipitationChance = dto.imgIdPrecipitationChance ?? null;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): PrecipitationChance {
    return PrecipitationChance.fromDto(JSON.parse(json) as PrecipitationChanceDTO);
  }
}
export interface SunriseSunsetDTO {
  time: string;
  hoursDiff: number | null;
  minutesDiff: number | null;
  isFuture: boolean | null;
}
export class SunriseSunset {
  time: string = '';
  hoursDiff: number | null = null;
  minutesDiff: number | null = null;
  isFuture: boolean | null = null;
  toDto(): SunriseSunsetDTO {
    return { time: this.time, hoursDiff: this.hoursDiff, minutesDiff: this.minutesDiff, isFuture: this.isFuture };
  }
  static fromDto(dto: SunriseSunsetDTO): SunriseSunset {
    const value = new SunriseSunset();
    value.time = dto.time;
    value.hoursDiff = dto.hoursDiff ?? null;
    value.minutesDiff = dto.minutesDiff ?? null;
    value.isFuture = dto.isFuture ?? null;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): SunriseSunset { return SunriseSunset.fromDto(JSON.parse(json) as SunriseSunsetDTO); }
}
export interface DayForecastDTO {
  temperature: TemperatureDTO | null;
  apparentTemp: TemperatureDTO | null;
  dayTemp: TemperatureDTO | null;
  nightTemp: TemperatureDTO | null;
  imgIdWeatherCode: string | null;
  weatherCode: string | null;
  date: string;
  sunrise: SunriseSunsetDTO | null;
  sunset: SunriseSunsetDTO | null;
  windSpeed: WindSpeedDTO | null;
  precipitationChance: PrecipitationChanceDTO | null;
  pressure: PressureDTO | null;
  uvIndex: UvIndexDTO | null;
  hourlyTempForecast: TemperatureDTO[];
  precipitationChanceForecast: PrecipitationChanceDTO[];
}
export class DayForecast {
  temperature: Temperature | null = null;
  apparentTemp: Temperature | null = null;
  dayTemp: Temperature | null = null;
  nightTemp: Temperature | null = null;
  imgIdWeatherCode: string | null = null;
  weatherCode: string | null = null;
  date: string = '';
  sunrise: SunriseSunset | null = null;
  sunset: SunriseSunset | null = null;
  windSpeed: WindSpeed | null = null;
  precipitationChance: PrecipitationChance | null = null;
  pressure: Pressure | null = null;
  uvIndex: UvIndex | null = null;
  hourlyTempForecast: Temperature[] = [];
  precipitationChanceForecast: PrecipitationChance[] = [];
  toDto(): DayForecastDTO {
    return { temperature: this.temperature === null ? null : this.temperature.toDto(),
      apparentTemp: this.apparentTemp === null ? null : this.apparentTemp.toDto(),
      dayTemp: this.dayTemp === null ? null : this.dayTemp.toDto(),
      nightTemp: this.nightTemp === null ? null : this.nightTemp.toDto(),
      imgIdWeatherCode: this.imgIdWeatherCode, weatherCode: this.weatherCode, date: this.date,
      sunrise: this.sunrise === null ? null : this.sunrise.toDto(),
      sunset: this.sunset === null ? null : this.sunset.toDto(),
      windSpeed: this.windSpeed === null ? null : this.windSpeed.toDto(),
      precipitationChance: this.precipitationChance === null ? null : this.precipitationChance.toDto(),
      pressure: this.pressure === null ? null : this.pressure.toDto(),
      uvIndex: this.uvIndex === null ? null : this.uvIndex.toDto(),
      hourlyTempForecast: this.hourlyTempForecast.map((item: Temperature): TemperatureDTO => item.toDto()),
      precipitationChanceForecast: this.precipitationChanceForecast.map(
        (item: PrecipitationChance): PrecipitationChanceDTO => item.toDto()) };
  }
  static fromDto(dto: DayForecastDTO): DayForecast {
    const value = new DayForecast();
    value.temperature = dto.temperature == null ? null : Temperature.fromDto(dto.temperature);
    value.apparentTemp = dto.apparentTemp == null ? null : Temperature.fromDto(dto.apparentTemp);
    value.dayTemp = dto.dayTemp == null ? null : Temperature.fromDto(dto.dayTemp);
    value.nightTemp = dto.nightTemp == null ? null : Temperature.fromDto(dto.nightTemp);
    value.imgIdWeatherCode = dto.imgIdWeatherCode ?? null;
    value.weatherCode = dto.weatherCode ?? null;
    value.date = dto.date;
    value.sunrise = dto.sunrise == null ? null : SunriseSunset.fromDto(dto.sunrise);
    value.sunset = dto.sunset == null ? null : SunriseSunset.fromDto(dto.sunset);
    value.windSpeed = dto.windSpeed == null ? null : WindSpeed.fromDto(dto.windSpeed);
    value.precipitationChance = dto.precipitationChance == null ? null : PrecipitationChance.fromDto(dto.precipitationChance);
    value.pressure = dto.pressure == null ? null : Pressure.fromDto(dto.pressure);
    value.uvIndex = dto.uvIndex == null ? null : UvIndex.fromDto(dto.uvIndex);
    value.hourlyTempForecast = dto.hourlyTempForecast.map((item: TemperatureDTO): Temperature => Temperature.fromDto(item));
    value.precipitationChanceForecast = dto.precipitationChanceForecast.map(
      (item: PrecipitationChanceDTO): PrecipitationChance => PrecipitationChance.fromDto(item));
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): DayForecast { return DayForecast.fromDto(JSON.parse(json) as DayForecastDTO); }
}
export interface ForecastDTO { dayForecast: DayForecastDTO | null; weekTempForecast: TemperatureDTO[]; }
export class Forecast {
  dayForecast: DayForecast | null = null;
  weekTempForecast: Temperature[] = [];
  toDto(): ForecastDTO {
    return { dayForecast: this.dayForecast === null ? null : this.dayForecast.toDto(),
      weekTempForecast: this.weekTempForecast.map((item: Temperature): TemperatureDTO => item.toDto()) };
  }
  static fromDto(dto: ForecastDTO): Forecast {
    const value = new Forecast();
    value.dayForecast = dto.dayForecast == null ? null : DayForecast.fromDto(dto.dayForecast);
    value.weekTempForecast = dto.weekTempForecast.map((item: TemperatureDTO): Temperature => Temperature.fromDto(item));
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Forecast { return Forecast.fromDto(JSON.parse(json) as ForecastDTO); }
}
export interface CoordinatesDTO { latitude: number; longitude: number; }
export class Coordinates {
  latitude: number = 0;
  longitude: number = 0;
  constructor(latitude: number = 0, longitude: number = 0) { this.latitude = latitude; this.longitude = longitude; }
  toDto(): CoordinatesDTO { return { latitude: this.latitude, longitude: this.longitude }; }
  static fromDto(dto: CoordinatesDTO): Coordinates { return new Coordinates(dto.latitude, dto.longitude); }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Coordinates { return Coordinates.fromDto(JSON.parse(json) as CoordinatesDTO); }
}
export interface SettingsDTO { locationCoord: CoordinatesDTO | null; locationName: string; }
// SettingsProto: only cached location, never language/units.
export class Settings {
  locationCoord: Coordinates | null = null;
  locationName: string = '';
  toDto(): SettingsDTO {
    return { locationCoord: this.locationCoord === null ? null : this.locationCoord.toDto(), locationName: this.locationName };
  }
  static fromDto(dto: SettingsDTO): Settings {
    const value = new Settings();
    value.locationCoord = dto.locationCoord == null ? null : Coordinates.fromDto(dto.locationCoord);
    value.locationName = dto.locationName;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Settings { return Settings.fromDto(JSON.parse(json) as SettingsDTO); }
}
export interface SnapshotDTO { settings: SettingsDTO | null; forecast: ForecastDTO | null; }
export class Snapshot {
  settings: Settings | null = null;
  forecast: Forecast | null = null;
  toDto(): SnapshotDTO {
    return { settings: this.settings === null ? null : this.settings.toDto(),
      forecast: this.forecast === null ? null : this.forecast.toDto() };
  }
  static fromDto(dto: SnapshotDTO): Snapshot {
    if (dto == null || dto.settings === undefined || dto.forecast === undefined) {
      throw new Error('Invalid snapshot DTO');
    }
    const value = new Snapshot();
    value.settings = dto.settings === null ? null : Settings.fromDto(dto.settings);
    value.forecast = dto.forecast === null ? null : Forecast.fromDto(dto.forecast);
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Snapshot { return Snapshot.fromDto(JSON.parse(json) as SnapshotDTO); }
}
export interface PlaceDTO {
  toponymName: string; countryName: string; countryCode: string; lang: string;
  adminName1: string; latitude: string; longitude: string;
}
export class Place {
  readonly toponymName: string;
  readonly countryName: string;
  readonly countryCode: string;
  readonly lang: string;
  readonly adminName1: string;
  readonly latitude: string;
  readonly longitude: string;
  constructor(toponymName: string = '', countryName: string = '', countryCode: string = '', lang: string = '',
    adminName1: string = '', latitude: string = '', longitude: string = '') {
    this.toponymName = toponymName; this.countryName = countryName; this.countryCode = countryCode;
    this.lang = lang; this.adminName1 = adminName1; this.latitude = latitude; this.longitude = longitude;
  }
  getToponymName(): string { return this.toponymName; }
  getCountryName(): string { return this.countryName; }
  getCountryCode(): string { return this.countryCode; }
  getLang(): string { return this.lang; }
  getAdminName1(): string { return this.adminName1; }
  getLatitude(): string { return this.latitude; }
  getLongitude(): string { return this.longitude; }
  toDto(): PlaceDTO {
    return { toponymName: this.toponymName, countryName: this.countryName, countryCode: this.countryCode,
      lang: this.lang, adminName1: this.adminName1, latitude: this.latitude, longitude: this.longitude };
  }
  static fromDto(dto: PlaceDTO): Place {
    return new Place(dto.toponymName, dto.countryName, dto.countryCode, dto.lang, dto.adminName1, dto.latitude, dto.longitude);
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): Place { return Place.fromDto(JSON.parse(json) as PlaceDTO); }
}
export interface PreferencesSettingsDTO {
  languagePrefs: string; temperaturePrefs: string; windSpeedPrefs: string; airPressurePrefs: string;
}
// Separate SharedPreferences defaults, NOT fields in Snapshot.settings.
export class PreferencesSettings {
  languagePrefs: string = 'en';
  temperaturePrefs: string = 'celsius';
  windSpeedPrefs: string = 'kmh';
  airPressurePrefs: string = 'hpa';
  toDto(): PreferencesSettingsDTO {
    return { languagePrefs: this.languagePrefs, temperaturePrefs: this.temperaturePrefs,
      windSpeedPrefs: this.windSpeedPrefs, airPressurePrefs: this.airPressurePrefs };
  }
  static fromDto(dto: PreferencesSettingsDTO): PreferencesSettings {
    const value = new PreferencesSettings();
    value.languagePrefs = dto.languagePrefs; value.temperaturePrefs = dto.temperaturePrefs;
    value.windSpeedPrefs = dto.windSpeedPrefs; value.airPressurePrefs = dto.airPressurePrefs;
    return value;
  }
  toJson(): string { return JSON.stringify(this.toDto()); }
  static fromJson(json: string): PreferencesSettings {
    return PreferencesSettings.fromDto(JSON.parse(json) as PreferencesSettingsDTO);
  }
}
