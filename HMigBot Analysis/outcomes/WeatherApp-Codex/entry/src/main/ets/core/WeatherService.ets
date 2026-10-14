import { Coordinates, Forecast, Place, PreferencesSettings, Settings, Snapshot, Temperature,
  TemperatureUnit, SpeedUnit, PressureUnit } from './Models';
import { SnapshotDTO, ForecastDTO, DayForecastDTO, TemperatureDTO, PrecipitationChanceDTO,
  SunriseSunsetDTO } from './Models';
import { updateTemperature, updateWindSpeed, updatePressure, temperatureUnitFromPreference,
  speedUnitFromPreference, pressureUnitFromPreference } from './Units';
import { Runtime, BinaryStore } from './Runtime';
import { encodeSnapshot, decodeSnapshot } from './BinarySnapshot';
import { LocationPlatform, hasInternetConnection } from './LocationPlatform';
import { WeatherClient, OpenMeteoClient } from '../data/OpenMeteoClient';
import { GeoLocationClient, GeoNamesClient } from '../data/GeoNamesClient';

export type ResourceStatus = 'idle' | 'loading' | 'success' | 'error';
export type UnitPreference = 'temperaturePrefs' | 'windSpeedPrefs' | 'airPressurePrefs';
export interface ServiceStore {
  read(key: string, defaultValue: string): string;
  write(key: string, value: string): void;
  flush(): Promise<void>;
}

// Independent saved-data streams, not aliases of the changing current UI state.
export class SavedState<T> {
  private value: T | null = null;
  private observers: Map<number, (value: T | null) => void> = new Map<number, (value: T | null) => void>();
  private nextId: number = 0;
  private closed: boolean = false;
  getValue(): T | null { return this.value; }
  subscribe(observer: (value: T | null) => void): () => void {
    if (this.closed) { return (): void => { }; }
    const id = this.nextId++; this.observers.set(id, observer); observer(this.value);
    return (): void => { this.observers.delete(id); };
  }
  publish(value: T | null): void {
    if (this.closed) { return; }
    this.value = value;
    this.observers.forEach((observer: (value: T | null) => void): void => { observer(value); });
  }
  dispose(): void { this.closed = true; this.observers.clear(); }
}

// JSON assertions provide static DTO access only. Validate every nested persisted field
// before constructing models or publishing *any* part of a snapshot.
function snapshotNumber(value: number): void {
  if (typeof value !== 'number' || !Number.isFinite(value)) { throw new Error('Invalid snapshot number'); }
}
function snapshotString(value: string | null): void {
  if (value !== null && typeof value !== 'string') { throw new Error('Invalid snapshot string'); }
}
function snapshotNullableNumber(value: number | null): void {
  if (value !== null) { snapshotNumber(value); }
}
function validateTemperature(dto: TemperatureDTO | null): void {
  if (dto === null) { return; }
  if (typeof dto !== 'object' || Array.isArray(dto)) { throw new Error('Invalid temperature DTO'); }
  snapshotString(dto.time); snapshotNumber(dto.temperature); snapshotString(dto.imgIdWeatherCode);
  if (dto.temperatureUnit !== 0 && dto.temperatureUnit !== 1) { throw new Error('Invalid temperature unit'); }
}
function validateRain(dto: PrecipitationChanceDTO | null): void {
  if (dto === null) { return; }
  if (typeof dto !== 'object' || Array.isArray(dto)) { throw new Error('Invalid precipitation DTO'); }
  snapshotString(dto.time); snapshotNumber(dto.percent); snapshotNullableNumber(dto.percentDiff);
  snapshotString(dto.imgIdPrecipitationChance);
}
function validateSun(dto: SunriseSunsetDTO | null): void {
  if (dto === null) { return; }
  if (typeof dto !== 'object' || Array.isArray(dto) || typeof dto.time !== 'string') {
    throw new Error('Invalid sun DTO');
  }
  snapshotNullableNumber(dto.hoursDiff); snapshotNullableNumber(dto.minutesDiff);
  if (dto.isFuture !== null && typeof dto.isFuture !== 'boolean') { throw new Error('Invalid sun flag'); }
}
function validateDay(dto: DayForecastDTO | null): void {
  if (dto === null) { return; }
  if (typeof dto !== 'object' || Array.isArray(dto) || typeof dto.date !== 'string' ||
    !Array.isArray(dto.hourlyTempForecast) || !Array.isArray(dto.precipitationChanceForecast)) {
    throw new Error('Invalid day DTO');
  }
  validateTemperature(dto.temperature); validateTemperature(dto.apparentTemp);
  validateTemperature(dto.dayTemp); validateTemperature(dto.nightTemp);
  snapshotString(dto.imgIdWeatherCode); snapshotString(dto.weatherCode);
  validateSun(dto.sunrise); validateSun(dto.sunset); validateRain(dto.precipitationChance);
  if (dto.windSpeed !== null) {
    const wind = dto.windSpeed;
    if (typeof wind !== 'object' || Array.isArray(wind)) { throw new Error('Invalid wind DTO'); }
    snapshotNumber(wind.speed); snapshotNullableNumber(wind.speedDiff); snapshotString(wind.imgIdChangeWindSpeed);
    if (wind.speedUnit !== 0 && wind.speedUnit !== 1 && wind.speedUnit !== 2) { throw new Error('Invalid speed unit'); }
  }
  if (dto.pressure !== null) {
    const pressure = dto.pressure;
    if (typeof pressure !== 'object' || Array.isArray(pressure)) { throw new Error('Invalid pressure DTO'); }
    snapshotNumber(pressure.pressure); snapshotNullableNumber(pressure.pressureDiff);
    snapshotString(pressure.imgIdChangePressure);
    if (pressure.pressureUnit !== 0 && pressure.pressureUnit !== 1 && pressure.pressureUnit !== 2) {
      throw new Error('Invalid pressure unit');
    }
  }
  if (dto.uvIndex !== null) {
    const uv = dto.uvIndex;
    if (typeof uv !== 'object' || Array.isArray(uv)) { throw new Error('Invalid UV DTO'); }
    snapshotNumber(uv.uvIndex); snapshotNullableNumber(uv.uvIndexDiff); snapshotString(uv.imgIdChangeUvIndex);
  }
  dto.hourlyTempForecast.forEach((item: TemperatureDTO): void => {
    if (item == null) { throw new Error('Null hourly temperature'); } validateTemperature(item);
  });
  dto.precipitationChanceForecast.forEach((item: PrecipitationChanceDTO): void => {
    if (item == null) { throw new Error('Null hourly precipitation'); } validateRain(item);
  });
}
export function parseSavedSnapshot(json: string, part: 'all' | 'settings' | 'forecast' = 'all'): Snapshot {
  const dto = JSON.parse(json) as SnapshotDTO;
  if (dto == null || typeof dto !== 'object' || Array.isArray(dto) ||
    (part !== 'forecast' && dto.settings === undefined) ||
    (part !== 'settings' && dto.forecast === undefined)) { throw new Error('Invalid snapshot DTO'); }
  // A malformed sibling must not suppress an independent repository read.
  if (part === 'settings') { dto.forecast = null; }
  if (part === 'forecast') { dto.settings = null; }
  if (dto.settings !== null) {
    const settings = dto.settings;
    if (typeof settings !== 'object' || Array.isArray(settings) || typeof settings.locationName !== 'string' ||
      settings.locationCoord === undefined) { throw new Error('Invalid settings DTO'); }
    if (settings.locationCoord !== null) {
      const coord = settings.locationCoord;
      if (typeof coord !== 'object' || Array.isArray(coord)) { throw new Error('Invalid coordinates DTO'); }
      snapshotNumber(coord.latitude); snapshotNumber(coord.longitude);
    }
  }
  if (dto.forecast !== null) {
    const forecast: ForecastDTO = dto.forecast;
    if (typeof forecast !== 'object' || Array.isArray(forecast) || !Array.isArray(forecast.weekTempForecast)) {
      throw new Error('Invalid forecast DTO');
    }
    validateDay(forecast.dayForecast);
    forecast.weekTempForecast.forEach((item: TemperatureDTO): void => {
      if (item == null) { throw new Error('Null weekly temperature'); } validateTemperature(item);
    });
  }
  return Snapshot.fromDto(dto);
}
export class NativeServiceStore extends BinaryStore {
  readBytes(): ArrayBuffer {
    const store = Runtime.getDataStore();
    if (store === null) { throw new Error('Runtime.init must precede service init'); }
    return store.readBytes();
  }
  writeBytes(value: ArrayBuffer): void {
    const store = Runtime.getDataStore();
    if (store === null) { throw new Error('Runtime.init must precede saving'); }
    store.writeBytes(value);
  }
  async flush(): Promise<void> { await Runtime.flush(); }
}

export class NativePreferenceStore implements ServiceStore {
  read(key: string, defaultValue: string): string {
    const store = Runtime.unitPreferences;
    if (store === null) { throw new Error('Runtime.init must precede preference reads'); }
    return store.getSync(key, defaultValue) as string;
  }
  write(key: string, value: string): void {
    const store = Runtime.unitPreferences;
    if (store === null) { throw new Error('Runtime.init must precede preference writes'); }
    store.putSync(key, value);
  }
  async flush(): Promise<void> { await Runtime.flushUnitPreferences(); }
}

// Official generated schema codec owns protobuf primitives; IO/decode failures
// propagate as Error with no corruption handler or JSON-as-protobuf fallback.
export class DataStoreSerializer {
  getDefaultValue(): Snapshot { return new Snapshot(); }
  async readFrom(input: () => Promise<ArrayBuffer>): Promise<Snapshot> {
    try { return decodeSnapshot(await input()); }
    catch (error) { throw new Error('DataStore read: ' + String(error)); }
  }
  async writeTo(value: Snapshot, output: (bytes: ArrayBuffer) => Promise<void>): Promise<Snapshot> {
    try {
      await output(encodeSnapshot(value)); return value;
    } catch (error) { throw new Error('DataStore write: ' + String(error)); }
  }
}

export class CoordinateState extends SavedState<Coordinates> {
  subscribe(observer: (value: Coordinates | null) => void): () => void {
    return super.subscribe((value: Coordinates | null): void => { if (value !== null) { observer(value); } });
  }
  publish(value: Coordinates | null): void {
    if (value === null) { return; }
    const previous = this.getValue();
    if (previous !== null && previous.latitude === value.latitude && previous.longitude === value.longitude) { return; }
    super.publish(Coordinates.fromDto(value.toDto()));
  }
}

export class ProtoDataStoreRepository {
  private store: ServiceStore | BinaryStore;
  private updates: Promise<void> = Promise.resolve();
  private coordinates: CoordinateState = new CoordinateState();
  constructor(store: ServiceStore | BinaryStore = new NativeServiceStore()) { this.store = store; }
  getDataStore(): ServiceStore | BinaryStore { return this.store; }
  setDataStore(store: ServiceStore | BinaryStore): void { this.store = store; }
  private read(part: 'all' | 'settings' | 'forecast'): Snapshot {
    const store = this.store;
    if (store instanceof BinaryStore) { return decodeSnapshot(store.readBytes(), part); }
    // Explicit target-cache transition/test adapter, not native protobuf storage.
    return parseSavedSnapshot(store.read(Runtime.snapshotKey, Runtime.defaultSnapshot), part);
  }
  readSettings(): Settings | null {
    try { return this.read('settings').settings; } catch (error) { return null; }
  }
  readDaysForecastResponse(): Forecast | null {
    try { return this.read('forecast').forecast; } catch (error) { return null; }
  }
  async getDataStoreProto(): Promise<Snapshot | null> {
    try { return this.read('all'); } catch (error) { return null; }
  }
  async getSettings(): Promise<Settings | null> { return this.readSettings(); }
  async getDaysForecastResponse(): Promise<Forecast | null> { return this.readDaysForecastResponse(); }
  getFlowLocationCoord(): CoordinateState {
    this.coordinates.publish(this.readSettings()?.locationCoord ?? null);
    return this.coordinates;
  }
  private update(transform: (value: Snapshot) => Snapshot): Promise<void> {
    const operation = this.updates.then(async (): Promise<void> => {
      const value = transform(this.read('all'));
      const store = this.store;
      if (store instanceof BinaryStore) {
        await new DataStoreSerializer().writeTo(value, async (bytes: ArrayBuffer): Promise<void> => {
          store.writeBytes(bytes); await store.flush();
        });
      } else {
        const json = value.toJson(); parseSavedSnapshot(json);
        store.write(Runtime.snapshotKey, json); await store.flush();
      }
      this.coordinates.publish(value.settings?.locationCoord ?? null);
    });
    this.updates = operation.catch((): void => { });
    return operation;
  }
  saveDataStore(value: Snapshot): Promise<void> { return this.update((previous: Snapshot): Snapshot => value); }
  saveSettings(value: Settings | null): Promise<void> {
    return this.update((previous: Snapshot): Snapshot => { previous.settings = value; return previous; });
  }
  saveDaysForecastResponse(value: Forecast | null): Promise<void> {
    return this.update((previous: Snapshot): Snapshot => { previous.forecast = value; return previous; });
  }
  saveLocationCoord(value: Coordinates): Promise<void> {
    return this.update((previous: Snapshot): Snapshot => {
      if (previous.settings === null) { throw new Error('saveLocationCoord requires existing settings'); }
      previous.settings.locationCoord = value; return previous;
    });
  }
  dispose(): void { this.coordinates.dispose(); }
}

// Unaggregated source repository contract: failures/results pass through unchanged.
export class WeatherForecastRepository {
  private weather: WeatherClient;
  private geo: GeoLocationClient;
  private location: LocationPlatform;
  private storage: ProtoDataStoreRepository;
  constructor(weather: WeatherClient, geo: GeoLocationClient, location: LocationPlatform,
    storage: ProtoDataStoreRepository) {
    this.weather = weather; this.geo = geo; this.location = location; this.storage = storage;
  }
  fetchWeatherForecast(latitude: number, longitude: number): Promise<Forecast> {
    return this.weather.fetchWeatherForecast(latitude, longitude);
  }
  getTemperatureUnit(): TemperatureUnit { return this.weather.getTemperatureUnit(); }
  getSpeedUnit(): SpeedUnit { return this.weather.getSpeedUnit(); }
  getPressureUnit(): PressureUnit { return this.weather.getPressureUnit(); }
  setTemperatureUnit(value: TemperatureUnit): void { this.weather.setTemperatureUnit(value); }
  setSpeedUnit(value: SpeedUnit): void { this.weather.setSpeedUnit(value); }
  setPressureUnit(value: PressureUnit): void { this.weather.setPressureUnit(value); }
  fetchNearestPlaceInfo(latitude: number, longitude: number): Promise<Place> {
    return this.geo.fetchNearestPlaceInfo(latitude, longitude);
  }
  searchLocation(query: string): Promise<Place[]> { return this.geo.searchLocation(query); }
  getSettings(): Promise<Settings | null> { return this.storage.getSettings(); }
  getDaysForecastResponse(): Promise<Forecast | null> { return this.storage.getDaysForecastResponse(); }
  saveDataStore(value: Snapshot): Promise<void> { return this.storage.saveDataStore(value); }
  saveLocationCoord(value: Coordinates): Promise<void> { return this.storage.saveLocationCoord(value); }
  getLocation(): Coordinates { return this.location.getLocation(); }
  setLocation(value: Coordinates): void { this.location.setLocation(value); }
  requestLocation(): Promise<Coordinates> { return this.location.requestLocation(); }
  setLocale(value: string): void { this.geo.setLocale(value); }
}

@ObservedV2
export class WeatherService {
  @Trace forecast: Forecast | null = null;
  @Trace placeName: string | null = null;
  @Trace loading: boolean = false;
  @Trace errors: string[] = [];
  @Trace locale: string = 'en';
  @Trace units: PreferencesSettings = new PreferencesSettings();
  @Trace forecastStatus: ResourceStatus = 'idle';
  @Trace placeStatus: ResourceStatus = 'idle';
  @Trace searchStatus: ResourceStatus = 'idle';
  @Trace searchResults: Place[] | null = null;
  @Trace weatherError: string | null = null;
  @Trace placeError: string | null = null;
  @Trace searchError: string | null = null;
  @Trace locationServiceDisabled: boolean = false;
  private location: LocationPlatform;
  private preferenceStore: ServiceStore;
  readonly storage: ProtoDataStoreRepository;
  readonly repository: WeatherForecastRepository;
  private network: () => boolean;
  private applyLocale: (locale: string) => void;
  private initialized: boolean = false;
  private homeInitialized: boolean = false;
  private disposed: boolean = false;
  private savedLocation: SavedState<Coordinates> = new SavedState<Coordinates>();
  private savedSettings: SavedState<Settings> = new SavedState<Settings>();
  private savedForecast: SavedState<Forecast> = new SavedState<Forecast>();
  constructor(weather: WeatherClient = new OpenMeteoClient(), geo: GeoLocationClient = new GeoNamesClient(),
    location: LocationPlatform = new LocationPlatform(), store: ServiceStore | BinaryStore = new NativeServiceStore(),
    network: () => boolean = hasInternetConnection,
    applyLocale: (locale: string) => void = (locale: string): void => {
      if (Runtime.context === null) { throw new Error('Runtime.init must precede UI locale'); }
      Runtime.context.getApplicationContext().setLanguage(locale);
    }, preferenceStore: ServiceStore = new NativePreferenceStore()) {
    this.location = location;
    this.network = network; this.applyLocale = applyLocale;
    this.preferenceStore = preferenceStore;
    this.storage = new ProtoDataStoreRepository(store);
    this.repository = new WeatherForecastRepository(weather, geo, location, this.storage);
  }
  getLocation(): Coordinates { return this.repository.getLocation(); }
  setLocation(value: Coordinates): void { if (!this.disposed) { this.repository.setLocation(value); } }
  getSavedLocationCoord(): SavedState<Coordinates> { return this.savedLocation; }
  getSavedSettings(): SavedState<Settings> { return this.savedSettings; }
  getSavedDaysForecast(): SavedState<Forecast> { return this.savedForecast; }
  dispose(): void {
    this.disposed = true; this.location.dispose();
    this.storage.dispose();
    this.savedLocation.dispose(); this.savedSettings.dispose(); this.savedForecast.dispose();
    // Promise transports have no abort contract; cancel their state subscriptions.
    // Late completion (including errors and permission callbacks) cannot publish.
    this.loading = false;
  }
  onCleared(): void { this.dispose(); }
  private publishSaved(snapshot: Snapshot): void {
    this.savedSettings.publish(snapshot.settings === null ? null : Settings.fromDto(snapshot.settings.toDto()));
    const coord = snapshot.settings === null ? null : snapshot.settings.locationCoord;
    this.savedLocation.publish(coord === null ? null : Coordinates.fromDto(coord.toDto()));
    this.savedForecast.publish(snapshot.forecast === null ? null : Forecast.fromDto(snapshot.forecast.toDto()));
  }
  private updateLoading(): void {
    this.loading = this.forecastStatus === 'loading' || this.placeStatus === 'loading';
    const errors: string[] = [];
    if (this.weatherError !== null) { errors.push(this.weatherError); }
    if (this.placeError !== null) { errors.push(this.placeError); }
    if (this.searchError !== null) { errors.push(this.searchError); }
    this.errors = errors;
  }
  private offlineMessage(): string {
    return this.locale === 'ru' ? 'Включите мобильную передачу данных или подключитесь к сети Wi-Fi' :
      'Turn on mobile data or connect to a Wi-Fi network';
  }
  async init(home: boolean = true): Promise<void> {
    if (this.disposed) { return; }
    if (!this.initialized) {
      this.initialized = true;
      this.restore();
      const prefs = new PreferencesSettings();
      prefs.languagePrefs = this.preferenceStore.read('languagePrefs', 'en');
      prefs.temperaturePrefs = this.preferenceStore.read('temperaturePrefs', 'celsius');
      prefs.windSpeedPrefs = this.preferenceStore.read('windSpeedPrefs', 'kmh');
      prefs.airPressurePrefs = this.preferenceStore.read('airPressurePrefs', 'hpa');
      this.units = prefs; this.locale = prefs.languagePrefs;
      this.repository.setTemperatureUnit(temperatureUnitFromPreference(prefs.temperaturePrefs));
      this.repository.setSpeedUnit(speedUnitFromPreference(prefs.windSpeedPrefs));
      this.repository.setPressureUnit(pressureUnitFromPreference(prefs.airPressurePrefs));
      this.applyLocale(this.locale);
    }
    if (home && !this.homeInitialized) {
      this.homeInitialized = true;
      this.handlePermission();
      await this.fetchCurrentWeatherAndPlace();
    }
  }
  async handlePermission(): Promise<void> {
    if (this.disposed) { return; }
    try {
      const disabled = await this.location.handlePermission();
      if (!this.disposed) { this.locationServiceDisabled = disabled; }
    }
    catch (error) { console.error('Location permission: ' + String(error)); }
  }
  async openLocationSettings(): Promise<void> { if (!this.disposed) { await this.location.openSettings(); } }
  async refresh(): Promise<void> {
    this.handlePermission(); // Do not await or refresh again in authorization completion.
    await this.fetchCurrentWeatherAndPlace();
  }
  async fetchCurrentWeatherAndPlace(): Promise<void> {
    if (this.disposed) { return; }
    try {
      const value = await this.repository.requestLocation();
      if (!this.disposed) { await this.fetchWeatherAndPlace(value); }
    }
    catch (error) { console.error('LocationService: ' + String(error)); }
  }
  async fetchWeatherAndPlace(value: Coordinates): Promise<void> {
    if (this.disposed) { return; }
    // Start independently; publishing one success never waits for the other request.
    const weather = this.fetchWeather(value);
    const place = this.fetchPlace(value);
    await Promise.all([weather, place]);
  }
  private async fetchWeather(value: Coordinates): Promise<void> {
    this.forecastStatus = 'loading'; this.forecast = null; this.weatherError = null; this.updateLoading();
    try {
      if (!this.network()) { throw new Error(this.offlineMessage()); }
      const forecast = await this.repository.fetchWeatherForecast(value.latitude, value.longitude);
      if (this.disposed) { return; }
      this.forecast = forecast;
      // Source parser labels pressure with the client unit; formatDaysForecast's same-unit conversion is identity.
      this.forecastStatus = 'success';
    } catch (error) {
      if (this.disposed) { return; }
      this.weatherError = String(error).includes(this.offlineMessage()) ? this.offlineMessage() :
        "Couldn't get the weather forecast";
      this.forecastStatus = 'error';
    }
    this.updateLoading();
  }
  private async fetchPlace(value: Coordinates): Promise<void> {
    this.placeStatus = 'loading'; this.placeName = null; this.placeError = null; this.updateLoading();
    try {
      if (!this.network()) { throw new Error(this.offlineMessage()); }
      const place = await this.repository.fetchNearestPlaceInfo(value.latitude, value.longitude);
      if (this.disposed) { return; }
      this.placeName = place.toponymName; this.placeStatus = 'success';
    } catch (error) {
      if (this.disposed) { return; }
      this.placeError = String(error).includes(this.offlineMessage()) ? this.offlineMessage() :
        "Couldn't get the name of the area";
      this.placeStatus = 'error'; console.error('MainViewModel: ' + this.placeError);
    }
    this.updateLoading();
  }
  async search(query: string): Promise<Place[] | null> {
    if (this.disposed) { return null; }
    this.searchStatus = 'loading'; this.searchResults = null; this.searchError = null; this.updateLoading();
    try {
      if (!this.network()) { throw new Error(this.offlineMessage()); }
      const results = await this.repository.searchLocation(query);
      if (this.disposed) { return null; }
      this.searchResults = results; this.searchStatus = 'success';
    } catch (error) {
      if (this.disposed) { return null; }
      this.searchError = String(error).includes(this.offlineMessage()) ? this.offlineMessage() :
        "Couldn't get the name of the area";
      this.searchStatus = 'error';
    }
    this.updateLoading(); return this.searchResults;
  }
  async selectPlace(place: Place): Promise<void> {
    if (this.disposed) { return; }
    const value = new Coordinates(Number(place.latitude), Number(place.longitude));
    // Double.parseDouble throws on invalid strings, unlike Number(''); no new business validation.
    if (place.latitude.trim().length === 0 || place.longitude.trim().length === 0 ||
      Number.isNaN(value.latitude) || Number.isNaN(value.longitude)) { throw new Error('Invalid coordinate string'); }
    this.setLocation(value); await this.fetchWeatherAndPlace(value);
  }
  async changeLanguage(locale: string): Promise<void> {
    if (this.disposed) { return; }
    this.repository.setLocale(locale);
    const request = this.fetchPlace(this.getLocation());
    this.applyLocale(locale); this.locale = locale;
    const prefs = PreferencesSettings.fromDto(this.units.toDto()); prefs.languagePrefs = locale; this.units = prefs;
    this.preferenceStore.write('languagePrefs', locale); await this.preferenceStore.flush(); await request;
  }
  async changeUnit(key: UnitPreference, value: string): Promise<void> {
    if (this.disposed) { return; }
    const prefs = PreferencesSettings.fromDto(this.units.toDto());
    if (key === 'temperaturePrefs') { prefs.temperaturePrefs = value;
      this.repository.setTemperatureUnit(temperatureUnitFromPreference(value)); }
    if (key === 'windSpeedPrefs') { prefs.windSpeedPrefs = value;
      this.repository.setSpeedUnit(speedUnitFromPreference(value)); }
    if (key === 'airPressurePrefs') { prefs.airPressurePrefs = value;
      this.repository.setPressureUnit(pressureUnitFromPreference(value)); }
    this.units = prefs;
    const data = this.forecast;
    if (data !== null && data.dayForecast !== null) {
      const converted = Forecast.fromDto(data.toDto()); const day = converted.dayForecast;
      if (day !== null) {
        if (key === 'temperaturePrefs') {
          const target = this.repository.getTemperatureUnit();
          if (day.temperature !== null) { day.temperature = updateTemperature(day.temperature, day.temperature.temperatureUnit, target); }
          if (day.apparentTemp !== null) { day.apparentTemp = updateTemperature(day.apparentTemp, day.apparentTemp.temperatureUnit, target); }
          if (day.nightTemp !== null) { day.nightTemp = updateTemperature(day.nightTemp, day.nightTemp.temperatureUnit, target); }
          day.hourlyTempForecast = day.hourlyTempForecast.map((item: Temperature): Temperature =>
            updateTemperature(item, item.temperatureUnit, target));
          converted.weekTempForecast = converted.weekTempForecast.map((item: Temperature): Temperature =>
            updateTemperature(item, item.temperatureUnit, target));
          // dayTemp omission is source compatibility, not a missing conversion implementation.
        }
        if (key === 'windSpeedPrefs' && day.windSpeed !== null) {
          day.windSpeed = updateWindSpeed(day.windSpeed, day.windSpeed.speedUnit, this.repository.getSpeedUnit()); }
        if (key === 'airPressurePrefs' && day.pressure !== null) {
          day.pressure = updatePressure(day.pressure, day.pressure.pressureUnit, this.repository.getPressureUnit()); }
        this.forecast = converted; this.forecastStatus = 'success'; this.weatherError = null; this.updateLoading();
      }
    }
    this.preferenceStore.write(key, value); await this.preferenceStore.flush();
  }
  async saveSnapshot(): Promise<boolean> {
    if (this.disposed || this.placeName === null || this.forecastStatus === 'idle') { return false; }
    const settings = new Settings(); settings.locationCoord = this.getLocation(); settings.locationName = this.placeName;
    const snapshot = new Snapshot(); snapshot.settings = settings; snapshot.forecast = this.forecast;
    const json = snapshot.toJson();
    const saved = parseSavedSnapshot(json);
    await this.repository.saveDataStore(saved);
    if (!this.disposed) { this.publishSaved(saved); }
    return true;
  }
  restore(): void {
    if (this.disposed) { return; }
    const forecast = this.storage.readDaysForecastResponse();
    const settings = this.storage.readSettings();
    this.savedForecast.publish(forecast); this.savedSettings.publish(settings);
    this.savedLocation.publish(settings?.locationCoord ?? this.getLocation());
    this.storage.getFlowLocationCoord();
    if (forecast !== null) { this.forecast = forecast; this.forecastStatus = 'success'; }
    if (settings !== null) {
      this.placeName = settings.locationName; this.placeStatus = 'success';
      if (settings.locationCoord !== null) { this.setLocation(settings.locationCoord); }
    }
  }
}

export const weatherService: WeatherService = new WeatherService();
