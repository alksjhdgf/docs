import { Temperature, WindSpeed, Pressure, TemperatureUnit, SpeedUnit, PressureUnit } from './Models';
export { TemperatureUnit, SpeedUnit, PressureUnit } from './Models';

// Java Math.round(float): nearest integer, ties toward +infinity, no negative zero;
// NaN => 0; overflow saturates to int32. Source time indexes also use this float overload.
export function javaRoundFloat(value: number): number {
  const numberValue = Math.fround(value);
  if (Number.isNaN(numberValue)) { return 0; }
  if (numberValue >= 2147483647) { return 2147483647; }
  if (numberValue <= -2147483648) { return -2147483648; }
  const rounded = Math.round(numberValue);
  return rounded === 0 ? 0 : rounded;
}
// OpenMeteoClient.java:217 casts interval to float, so division is float,
// despite the ledger's shorthand omitting that cast.
export function getTimeIndex(startTimeSeconds: number, nowMs: number, intervalMs: number): number {
  return javaRoundFloat(Math.fround(Math.fround(nowMs - startTimeSeconds * 1000) / Math.fround(intervalMs)));
}
export function convertTemperature(temperature: number, from: TemperatureUnit, to: TemperatureUnit): number {
  let celsius = Math.fround(temperature);
  if (from === TemperatureUnit.FAHRENHEIT) {
    celsius = Math.fround(Math.fround(Math.fround(celsius - 32) * 5) / 9);
  }
  if (to === TemperatureUnit.FAHRENHEIT) {
    return Math.fround(Math.fround(Math.fround(celsius * 9) / 5) + 32);
  }
  return celsius;
}
export function convertSpeed(speed: number, from: SpeedUnit, to: SpeedUnit): number {
  let metersPerSecond = Math.fround(speed);
  if (from === SpeedUnit.KMH) { metersPerSecond = Math.fround(metersPerSecond / 3.6); }
  if (from === SpeedUnit.MPH) { metersPerSecond = Math.fround(metersPerSecond * 0.446944); }
  if (to === SpeedUnit.KMH) { return Math.fround(metersPerSecond * 3.6); }
  if (to === SpeedUnit.MPH) { return Math.fround(metersPerSecond / 0.446944); }
  return metersPerSecond;
}
export function convertPressure(pressure: number, from: PressureUnit, to: PressureUnit): number {
  let hpa = Math.fround(pressure);
  if (from === PressureUnit.MMHG) { hpa = Math.fround(hpa * 1.33322); }
  if (from === PressureUnit.INHG) { hpa = Math.fround(hpa * 33.8638); }
  if (to === PressureUnit.MMHG) { return Math.fround(hpa / 1.33322); }
  if (to === PressureUnit.INHG) { return Math.fround(hpa / 33.8638); }
  return hpa;
}
export function updateTemperature(model: Temperature, from: TemperatureUnit, to: TemperatureUnit): Temperature {
  const result = Temperature.fromDto(model.toDto());
  result.temperature = javaRoundFloat(convertTemperature(model.temperature, from, to));
  result.temperatureUnit = to;
  return result;
}
export function updateWindSpeed(model: WindSpeed, from: SpeedUnit, to: SpeedUnit): WindSpeed {
  const result = WindSpeed.fromDto(model.toDto());
  result.speed = javaRoundFloat(convertSpeed(model.speed, from, to));
  result.speedUnit = to;
  return result;
}
export function updatePressure(model: Pressure, from: PressureUnit, to: PressureUnit): Pressure {
  const result = Pressure.fromDto(model.toDto());
  result.pressure = javaRoundFloat(convertPressure(model.pressure, from, to));
  result.pressureUnit = to;
  return result;
}
// UIContext supplies the platform dimension conversion; callers must not use a guessed density.
export function dpToPx(context: UIContext, dp: number): number { return Math.trunc(context.vp2px(dp)); }
export function temperatureUnitFromPreference(value: string): TemperatureUnit {
  switch (value.toUpperCase()) {
    case 'CELSIUS': return TemperatureUnit.CELSIUS;
    case 'FAHRENHEIT': return TemperatureUnit.FAHRENHEIT;
    default: throw new Error('Invalid temperature unit: ' + value);
  }
}
export function speedUnitFromPreference(value: string): SpeedUnit {
  switch (value.toUpperCase()) {
    case 'MS': return SpeedUnit.MS;
    case 'KMH': return SpeedUnit.KMH;
    case 'MPH': return SpeedUnit.MPH;
    default: throw new Error('Invalid speed unit: ' + value);
  }
}
export function pressureUnitFromPreference(value: string): PressureUnit {
  switch (value.toUpperCase()) {
    case 'MMHG': return PressureUnit.MMHG;
    case 'HPA': return PressureUnit.HPA;
    case 'INHG': return PressureUnit.INHG;
    default: throw new Error('Invalid pressure unit: ' + value);
  }
}
