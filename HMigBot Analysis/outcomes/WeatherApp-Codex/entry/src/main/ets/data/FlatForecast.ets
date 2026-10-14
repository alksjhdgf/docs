import { util } from '@kit.ArkTS';

// Protocol source: https://raw.githubusercontent.com/open-meteo/sdk/v1.14.1/flatbuffers/weather_api.fbs
// com.open-meteo:sdk:1.14.1 (libs.versions.toml:19). Field numbers are schema ordinals.
export enum FlatVariable {
  APPARENT_TEMPERATURE = 1, IS_DAY = 19, PRECIPITATION_PROBABILITY = 26,
  PRESSURE_MSL = 27, SUNRISE = 40, SUNSET = 41, TEMPERATURE = 47,
  UV_INDEX = 52, WEATHER_CODE = 56, WIND_SPEED = 59
}

// This is a table adapter over the platform DataView, not a replacement byte primitive.
export class FlatTable {
  readonly view: DataView;
  readonly position: number;
  constructor(view: DataView, position: number) { this.view = view; this.position = position; }
  field(ordinal: number): number {
    const vtable = this.position - this.view.getInt32(this.position, true);
    const entry = 4 + ordinal * 2;
    if (entry >= this.view.getUint16(vtable, true)) { return 0; }
    const offset = this.view.getUint16(vtable + entry, true);
    return offset === 0 ? 0 : this.position + offset;
  }
  indirect(ordinal: number): number {
    const field = this.field(ordinal);
    return field === 0 ? 0 : field + this.view.getUint32(field, true);
  }
  int64(position: number): number {
    // Epoch seconds fit exactly in number. int64 is little-endian signed high/unsigned low.
    return this.view.getInt32(position + 4, true) * 4294967296 + this.view.getUint32(position, true);
  }
  string(ordinal: number): string {
    const position = this.indirect(ordinal);
    if (position === 0) { throw new Error('Missing FlatBuffers string'); }
    const length = this.view.getUint32(position, true);
    const bytes = new Uint8Array(this.view.buffer, this.view.byteOffset + position + 4, length);
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }
}

export class FlatValues extends FlatTable {
  variable(): number {
    const field = this.field(0);
    return field === 0 ? 0 : this.view.getUint8(field);
  }
  length(int64: boolean = false): number {
    const position = this.indirect(int64 ? 4 : 3);
    return position === 0 ? 0 : this.view.getUint32(position, true);
  }
  value(index: number, int64: boolean = false): number {
    const position = this.indirect(int64 ? 4 : 3);
    // SDK accessor performs offset arithmetic without a vector-length guard. Preserve it;
    // DataView may still throw at the actual buffer boundary, as the platform primitive requires.
    return int64 ? this.int64(position + 4 + index * 8) : this.view.getFloat32(position + 4 + index * 4, true);
  }
}

export class FlatSeries extends FlatTable {
  time(): number { const field = this.field(0); return field === 0 ? 0 : this.int64(field); }
  timeEnd(): number { const field = this.field(1); return field === 0 ? 0 : this.int64(field); }
  interval(): number { const field = this.field(2); return field === 0 ? 0 : this.view.getInt32(field, true); }
  variable(id: FlatVariable): FlatValues {
    const vector = this.indirect(3);
    const length = vector === 0 ? 0 : this.view.getUint32(vector, true);
    for (let i = 0; i < length; i++) {
      const entry = vector + 4 + i * 4;
      const values = new FlatValues(this.view, entry + this.view.getUint32(entry, true));
      if (values.variable() === id) { return values; }
    }
    throw new Error('Missing weather variable: ' + id);
  }
  value(id: FlatVariable, index: number, int64: boolean = false): number {
    return this.variable(id).value(index, int64);
  }
}

export class FlatForecast extends FlatTable {
  readonly messageLength: number;
  private decodeTimezone: (bytes: Uint8Array) => string;
  constructor(buffer: ArrayBuffer, decodeTimezone: (bytes: Uint8Array) => string =
    (bytes: Uint8Array): string => util.TextDecoder.create('utf-8').decodeToString(bytes)) {
    const whole = new DataView(buffer);
    const length = whole.getUint32(0, true);
    // Source position(4) skips, rather than validates, the prefix. Do not introduce a
    // declared-length read window: SDK offsets are relative to the whole received buffer.
    const view = whole;
    super(view, 4 + view.getUint32(4, true));
    this.messageLength = length;
    this.decodeTimezone = decodeTimezone;
  }
  timezone(): string {
    const position = this.indirect(7);
    if (position === 0) { throw new Error('Missing FlatBuffers string'); }
    const length = this.view.getUint32(position, true);
    return this.decodeTimezone(new Uint8Array(this.view.buffer, this.view.byteOffset + position + 4, length));
  }
  series(ordinal: number): FlatSeries {
    const position = this.indirect(ordinal);
    if (position === 0) { throw new Error('Missing weather time series'); }
    return new FlatSeries(this.view, position);
  }
  minutely15(): FlatSeries { return this.series(12); }
  hourly(): FlatSeries { return this.series(11); }
  daily(): FlatSeries { return this.series(10); }
}
