import { http } from '@kit.NetworkKit';
import { i18n } from '@kit.LocalizationKit';
import { Place } from '../core/Models';

export interface AlternateNameJson { lang: string; }
export interface GeoPlaceJson {
  name: string; countryName: string; countryCode: string; adminName1: string;
  lat: string; lng: string; alternateNames?: AlternateNameJson[];
}
export interface GeoResponseJson { geonames: GeoPlaceJson[]; }
export function localeLanguage(locale: string): string {
  return locale.replace('_', '-').split('-')[0];
}
export function buildNearestPlaceUrl(latitude: number, longitude: number, locale: string): string {
  return 'http://api.geonames.org/findNearbyPlaceNameJSON?lat=' + encodeURIComponent(latitude.toString()) +
    '&lng=' + encodeURIComponent(longitude.toString()) + '&style=FULL&cities=cities1000&lang=' +
    encodeURIComponent(localeLanguage(locale)) + '&username=my_weather_app';
}
export function buildSearchLocationUrl(query: string, defaultLocale: string): string {
  return 'http://api.geonames.org/searchJSON?q=' + encodeURIComponent(query) +
    '&style=LONG&maxRows=15&fuzzy=0.8&lang=' + encodeURIComponent(localeLanguage(defaultLocale)) +
    '&username=my_weather_app';
}
function requireString(value: string): string {
  if (typeof value !== 'string') { throw new Error('Missing GeoNames string'); }
  return value;
}
export function parsePlaceInfoJson(json: GeoPlaceJson): Place {
  let language = 'en';
  if (json.alternateNames !== undefined) {
    if (!Array.isArray(json.alternateNames) || json.alternateNames.length === 0) {
      throw new Error('Array alternateNames is empty or invalid');
    }
    language = requireString(json.alternateNames[0].lang);
  }
  return new Place(requireString(json.name), requireString(json.countryName), requireString(json.countryCode),
    language, requireString(json.adminName1), requireString(json.lat), requireString(json.lng));
}
function parseRoot(body: string): GeoResponseJson {
  const root = JSON.parse(body) as GeoResponseJson;
  if (root == null || !Array.isArray(root.geonames)) { throw new Error('Missing geonames array'); }
  return root;
}
export function parseNearestPlace(body: string): Place {
  const root = parseRoot(body);
  if (root.geonames.length === 0) { throw new Error("Array 'geonames' is empty"); }
  return parsePlaceInfoJson(root.geonames[0]);
}
export function parseSearch(body: string): Place[] {
  return parseRoot(body).geonames.map((item: GeoPlaceJson): Place => parsePlaceInfoJson(item));
}
export function consumeGeoHttpResponse(status: number, body: string, consume: (body: string) => void): string {
  try {
    if (body.length === 0) { throw new Error('Empty body'); }
    consume(body);
    return body;
  } finally {
    // Source calls onError but does not return: parsing still runs, while Single keeps
    // the first terminal server error even if subsequent parsing fails.
    if (status < 200 || status >= 300) { throw new Error('ERROR REQUEST SERVER: api.geonames ' + status); }
  }
}
export interface GeoLocationClient {
  fetchNearestPlaceInfo(latitude: number, longitude: number): Promise<Place>;
  searchLocation(query: string): Promise<Place[]>;
  getLocale(): string;
  setLocale(locale: string): void;
}
export class GeoNamesClient implements GeoLocationClient {
  private locale: string = i18n.System.getSystemLanguage();
  private defaultLocale: () => string;
  // Provider injection models Java Locale.getDefault, independently of client setLocale.
  constructor(defaultLocale: () => string = (): string => i18n.System.getSystemLanguage()) {
    this.defaultLocale = defaultLocale;
  }
  getLocale(): string { return this.locale; }
  setLocale(locale: string): void { this.locale = locale; }
  buildNearestPlaceUrl(latitude: number, longitude: number): string {
    return buildNearestPlaceUrl(latitude, longitude, this.locale);
  }
  buildSearchLocationUrl(query: string): string { return buildSearchLocationUrl(query, this.defaultLocale()); }
  // Cleartext decision: keep original host/account/HTTP, no HTTPS substitution,
  // fallback city or secondary provider. NetworkKit 2300997 is propagated unchanged
  // through the existing error path. Official policy lives in profile/network_config.json,
  // not a module.networkSecurityConfig field. Profile ownership is blocked for this repair;
  // see client-accept-fix-evidence.md. INTERNET alone does not establish cleartext policy.
  // my_weather_app quota/validity remains unverified; no retries or account replacement.
  async request(url: string, consume: (body: string) => void = (body: string): void => {}): Promise<string> {
    const connection = http.createHttp();
    try {
      const options: http.HttpRequestOptions = { method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING, connectTimeout: 10000, readTimeout: 30000 };
      const response = await connection.request(url, options);
      if (typeof response.result !== 'string') {
        throw new Error(response.responseCode < 200 || response.responseCode >= 300 ?
          'ERROR REQUEST SERVER: api.geonames ' + response.responseCode : 'Empty body');
      }
      return consumeGeoHttpResponse(response.responseCode, response.result, consume);
    } finally { connection.destroy(); }
  }
  async fetchNearestPlaceInfo(latitude: number, longitude: number): Promise<Place> {
    let place: Place | null = null;
    await this.request(this.buildNearestPlaceUrl(latitude, longitude), (body: string): void => { place = parseNearestPlace(body); });
    if (place === null) { throw new Error('Empty body'); }
    return place;
  }
  async searchLocation(query: string): Promise<Place[]> {
    let places: Place[] = [];
    await this.request(this.buildSearchLocationUrl(query), (body: string): void => { places = parseSearch(body); });
    return places;
  }
}
