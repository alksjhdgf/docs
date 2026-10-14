import { DayForecast, Forecast, PrecipitationChance, PressureUnit, SpeedUnit, SunriseSunset, Temperature } from '../core/Models';
import { ForecastChart } from './ForecastChart';

export function formatSpeedUnit(speed: number, unit: SpeedUnit, locale: string): string {
  const suffix = unit === SpeedUnit.MS ? (locale === 'ru' ? 'м/с' : 'm/s') :
    unit === SpeedUnit.MPH ? (locale === 'ru' ? 'миль/ч' : 'mph') : (locale === 'ru' ? 'км/ч' : 'km/h');
  return Math.trunc(speed) + ' ' + suffix;
}
export function formatPressureUnit(pressure: number, unit: PressureUnit, locale: string): string {
  const suffix = unit === PressureUnit.INHG ? (locale === 'ru' ? 'дюйм рт. ст.' : 'inHg') :
    unit === PressureUnit.MMHG ? (locale === 'ru' ? 'мм. рт. ст.' : 'mmHg') : (locale === 'ru' ? 'гПа' : 'hpa');
  return Math.trunc(pressure) + ' ' + suffix;
}
export function formatSunriseSunset(sun: SunriseSunset, locale: string): string {
  const minutes = sun.hoursDiff === 0;
  const value = minutes ? sun.minutesDiff : sun.hoursDiff;
  if (value === null) { return ''; }
  const duration = Math.trunc(value) + (locale === 'ru' ? (minutes ? 'мин' : 'ч') : (minutes ? 'min' : 'h'));
  return sun.isFuture ? (locale === 'ru' ? 'через ' : 'in ') + duration :
    duration + (locale === 'ru' ? ' назад' : ' ago');
}

@ComponentV2
export struct WeatherDetails {
  @Param forecast: Forecast | null = null;
  @Param locale: string = 'en';
  @Event onInnerGesture: (active: boolean) => void = (_active: boolean): void => {};
  @Event onHorizontalGesture: (active: boolean) => void = (_active: boolean): void => {};
  @Event onHorizontalMove: () => void = (): void => {};
  private hourlyTouched: boolean = false;
  private hourlyScrolling: boolean = false;
  private rainTouched: boolean = false;
  private rainScrolling: boolean = false;
  private rainBoundary: boolean = false;
  private rainTouchY: number = 0;
  private rainScroll: ListScroller = new ListScroller();
  private day(): DayForecast | null { return this.forecast?.dayForecast ?? null; }
  private hours(): Temperature[] { return this.day()?.hourlyTempForecast ?? []; }
  private rain(): PrecipitationChance[] { return this.day()?.precipitationChanceForecast ?? []; }
  private label(kind: number): Resource {
    return kind === 0 ? $r('app.string.title_wind_speed') : kind === 1 ? $r('app.string.title_rain_chance') :
      kind === 2 ? $r('app.string.title_pressure') : $r('app.string.title_uv_index');
  }
  private icon(kind: number): Resource {
    return kind === 0 ? $r('app.media.ic_wind_icon') : kind === 1 ? $r('app.media.ic_rain_icon') :
      kind === 2 ? $r('app.media.ic_waves_icon') : $r('app.media.ic_sun_icon');
  }
  private reading(kind: number): string {
    const df = this.day();
    if (df === null) { return ''; }
    if (kind === 0 && df.windSpeed !== null) { return formatSpeedUnit(df.windSpeed.speed, df.windSpeed.speedUnit, this.locale); }
    if (kind === 1 && df.precipitationChance !== null) { return Math.trunc(df.precipitationChance.percent) + '%'; }
    if (kind === 2 && df.pressure !== null) { return formatPressureUnit(df.pressure.pressure, df.pressure.pressureUnit, this.locale); }
    // Deliberate source compatibility: UV main reading is uvIndexDiff, NOT uvIndex.
    if (kind === 3 && df.uvIndex !== null) { return this.integer(df.uvIndex.uvIndexDiff); }
    return '';
  }
  private integer(value: number | null): string { return value === null ? '' : String(Math.trunc(value)); }
  private diff(kind: number): string {
    const df = this.day();
    if (df === null) { return ''; }
    return this.integer(kind === 0 ? df.windSpeed?.speedDiff ?? null : kind === 1 ? df.precipitationChance?.percentDiff ?? null :
      kind === 2 ? df.pressure?.pressureDiff ?? null : df.uvIndex?.uvIndexDiff ?? null);
  }
  private arrow(kind: number): string | null {
    const df = this.day();
    if (df === null) { return null; }
    return kind === 0 ? df.windSpeed?.imgIdChangeWindSpeed ?? null : kind === 1 ? df.precipitationChance?.imgIdPrecipitationChance ?? null :
      kind === 2 ? df.pressure?.imgIdChangePressure ?? null : df.uvIndex?.imgIdChangeUvIndex ?? null;
  }
  private sun(rise: boolean): SunriseSunset | null { return rise ? this.day()?.sunrise ?? null : this.day()?.sunset ?? null; }
  private relative(rise: boolean): string {
    const sun = this.sun(rise); return sun === null ? '' : formatSunriseSunset(sun, this.locale);
  }
  private publishGesture(): void {
    // A finger release is not a scroll end: keep ownership through inertial MOVE.
    const horizontal = this.hourlyTouched || this.hourlyScrolling;
    this.onHorizontalGesture(horizontal);
    this.onInnerGesture(horizontal || ((this.rainTouched || this.rainScrolling) && !this.rainBoundary));
  }
  private innerTouch(event: TouchEvent, hourly: boolean): void {
    const active = event.type !== TouchType.Up && event.type !== TouchType.Cancel;
    if (hourly) {
      this.hourlyTouched = active;
      if (event.type === TouchType.Cancel) { this.hourlyScrolling = false; }
    } else {
      this.rainTouched = active;
      if (event.touches.length > 0) {
        const fingerY = event.touches[0].screenY;
        if (event.type === TouchType.Down) { this.rainBoundary = false; }
        if (event.type === TouchType.Move) {
          const delta = fingerY - this.rainTouchY;
          // At either edge SELF_FIRST passes the unconsumed delta to the
          // weather Scroll. Ownership must follow that handoff as well, so a
          // continued down gesture can restore the header once the parent tops.
          if (delta !== 0) {
            this.rainBoundary = delta > 0 ? this.rainScroll.currentOffset().yOffset <= 0.5 : this.rainScroll.isAtEnd();
          }
        }
        this.rainTouchY = fingerY;
      }
      if (event.type === TouchType.Cancel) { this.rainScrolling = false; }
    }
    this.publishGesture();
    if (hourly && event.type === TouchType.Move) { this.onHorizontalMove(); }
  }
  private innerScroll(scrolling: boolean, hourly: boolean): void {
    if (hourly) { this.hourlyScrolling = scrolling; } else { this.rainScrolling = scrolling; }
    this.publishGesture();
  }
  aboutToDisappear(): void {
    this.hourlyTouched = false; this.hourlyScrolling = false;
    this.rainTouched = false; this.rainScrolling = false;
    this.rainBoundary = false;
    this.onHorizontalGesture(false); this.onInnerGesture(false);
  }
  @Builder
  private metric(kind: number) {
    Column() {
      Row() {
        Image(this.icon(kind)).width(24).height(24).objectFit(ImageFit.Contain)
        Column() {
          Text(this.label(kind)).fontSize(14)
          Text(this.reading(kind)).fontSize(14)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding({ left: 8 })
      }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%')
      Row() {
        if (this.arrow(kind) !== null) {
          Image($r('app.media.' + this.arrow(kind))).width(14).height(14).objectFit(ImageFit.Contain)
        }
        Text(this.diff(kind)).fontSize(12)
      }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.End).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').constraintSize({ minHeight: 76 })
      .padding({ top: 10, bottom: 10, left: 10, right: 10 }).borderRadius(16)
      .backgroundColor($r('app.color.backgroundPinkPrimary'))
  }
  @Builder
  private sectionLabel(label: Resource, icon: Resource) {
    Row() {
      Image(icon).width(24).height(24).objectFit(ImageFit.Contain)
      Text(label).fontSize(14).layoutWeight(1).padding({ left: 8 })
    }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%')
  }
  @Builder
  private sunCard(rise: boolean) {
    Column() {
      this.sectionLabel(rise ? $r('app.string.title_sunrise') : $r('app.string.title_sunset'),
        rise ? $r('app.media.ic_sunrise_icon') : $r('app.media.ic_sunset_icon'))
      Text(this.sun(rise)?.time ?? '').fontSize(16)
      Row() { Text(this.relative(rise)).fontSize(12) }
        .alignItems(VerticalAlign.Top).justifyContent(FlexAlign.End).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 10, bottom: 10, left: 10, right: 10 })
      .borderRadius(16).backgroundColor($r('app.color.backgroundPinkPrimary'))
  }
  build() {
    Column() {
      Row({ space: 16 }) {
        Column() { this.metric(0) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column() { this.metric(1) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.alignItems(VerticalAlign.Top).justifyContent(FlexAlign.Start).width('100%')
      Row({ space: 16 }) {
        Column() { this.metric(2) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column() { this.metric(3) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.alignItems(VerticalAlign.Top).justifyContent(FlexAlign.Start).width('100%').margin({ top: 12, bottom: 16 })
      Column() {
        this.sectionLabel($r('app.string.title_hourly_forecast'), $r('app.media.ic_clock_icon'))
        List({ space: 25 }) {
          ForEach(this.hours(), (item: Temperature, index: number) => {
            ListItem() {
              Column() {
                Text(index === 0 ? (this.locale === 'ru' ? 'Сейчас' : 'Now') : item.time ?? '').fontSize(14)
                if (item.imgIdWeatherCode !== null) {
                  Image($r('app.media.' + item.imgIdWeatherCode)).width(30).height(30).objectFit(ImageFit.Contain).margin({ top: 2 })
                }
                Text(Math.trunc(item.temperature) + '°').fontSize(18).margin({ top: 4 })
              }.alignItems(HorizontalAlign.Center) // source hour cell's centred labels/icon
            }
          }, (item: Temperature, index: number): string => index + ':' + item.time + ':' + item.temperature + ':' + item.imgIdWeatherCode)
        }.id('rvHourlyForecast').listDirection(Axis.Horizontal).width('100%').height(80).scrollBar(BarState.Off)
          .nestedScroll({ scrollForward: NestedScrollMode.SELF_ONLY, scrollBackward: NestedScrollMode.SELF_ONLY })
           .margin({ top: 16 }).onTouch((event: TouchEvent): void => this.innerTouch(event, true))
           .onScrollStart((): void => this.innerScroll(true, true))
           .onScrollStop((): void => this.innerScroll(false, true))
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12, bottom: 12, left: 12, right: 12 })
        .backgroundColor($r('app.color.backgroundPinkPrimary')).borderRadius(16).margin({ bottom: 16 })
      Column() {
        this.sectionLabel($r('app.string.title_day_forecast'), $r('app.media.ic_calendar_icon'))
        ForecastChart({ values: this.forecast?.weekTempForecast ?? [], locale: this.locale })
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12, bottom: 12, left: 12, right: 12 })
        .backgroundColor($r('app.color.backgroundPinkPrimary')).borderRadius(16).margin({ bottom: 16 })
      Column() {
        this.sectionLabel($r('app.string.title_chance_precipitation'), $r('app.media.ic_rain_icon'))
        List({ space: 10, scroller: this.rainScroll }) {
          ForEach(this.rain(), (item: PrecipitationChance, index: number) => {
            ListItem() {
              Row() {
                Text(index === 0 ? (this.locale === 'ru' ? 'Сейчас' : 'Now') : item.time ?? '').width(55).textAlign(TextAlign.End)
                Progress({ value: item.percent, total: 100, type: ProgressType.Linear }).layoutWeight(1)
                  .color($r('app.color.darkPurple')).margin({ left: 33, right: 22 })
                Text(Math.trunc(item.percent) + '%').width(45).textAlign(TextAlign.End)
              }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%')
            }
          }, (item: PrecipitationChance, index: number): string => index + ':' + item.time + ':' + item.percent)
        }.id('tlChanceOfRain').width('100%').layoutWeight(1).scrollBar(BarState.Off).margin({ top: 16 })
          .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
           // Same-axis boundary handoff stays SELF_FIRST; unlike the hourly list,
           // it must not disable the parent Scroll and trap the user at either edge.
           .onTouch((event: TouchEvent): void => this.innerTouch(event, false))
           .onScrollStart((): void => this.innerScroll(true, false))
           .onScrollStop((): void => this.innerScroll(false, false))
      }.alignItems(HorizontalAlign.Start).width('100%').height(210).padding({ top: 12, bottom: 12, left: 12, right: 12 })
        .backgroundColor($r('app.color.backgroundPinkPrimary')).borderRadius(16).margin({ bottom: 16 })
      Row({ space: 16 }) {
        Column() { this.sunCard(true) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column() { this.sunCard(false) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.alignItems(VerticalAlign.Top).justifyContent(FlexAlign.Start).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
  }
}
