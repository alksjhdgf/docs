import { i18n } from '@kit.LocalizationKit';
import { Temperature } from '../core/Models';

export class ForecastPoint {
  x: number = 0;
  y: number = 0;
  constructor(x: number = 0, y: number = 0) { this.x = x; this.y = y; }
}

// TodayWeatherFragment:148-160. The inclusive endpoint exists only when length is divisible by six.
export function createWeekDayForecast(values: Temperature[]): ForecastPoint[] {
  const points: ForecastPoint[] = [];
  if (values.length === 0) { return points; } // safety: never fabricate successful weather
  for (let i = 0; i <= values.length; i += 6) {
    points.push(new ForecastPoint(Math.floor(i / 24) + 1 + (i % 24) / 24 - 0.5,
      values[i === values.length ? i - 1 : i].temperature));
  }
  return points;
}

export function forecastWeekLabels(locale: string, sundayFirst: boolean): string[] {
  const days = locale === 'ru' ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'] :
    ['Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat', 'Sun']; // preserve source string-array typo
  if (sundayFirst) { const sunday = days.pop(); if (sunday !== undefined) { days.unshift(sunday); } }
  days.unshift('');
  return days;
}

// Source LineChartView's data/axis boundary, independent of Canvas for behavior probes.
// changeAxisY is intentionally the X-axis label formatter, despite its source name.
export class ForecastChartState {
  private dataSet: ForecastPoint[] = [];
  labels: string[] = [];
  position: string = 'bottom';
  axisMaximum: number = 1;
  axisMinimum: number = 0;
  setData(points: ForecastPoint[]): void { this.dataSet = points; }
  getDataSet(): ForecastPoint[] { return this.dataSet; }
  changeAxisY(labels: string[]): void { this.labels = labels; }
  setPosition(position: string): void { this.position = position; }
  setAxisYMax(value: number): void { this.axisMaximum = value; }
  setAxisYMin(value: number): void { this.axisMinimum = value; }
  getAxisYMax(): number {
    if (this.dataSet.length === 0) { throw new Error('Empty forecast extrema'); }
    return Math.ceil(Math.max(...this.dataSet.map((p: ForecastPoint): number => p.y)));
  }
  getAxisYMin(): number {
    if (this.dataSet.length === 0) { throw new Error('Empty forecast extrema'); }
    return Math.ceil(Math.min(...this.dataSet.map((p: ForecastPoint): number => p.y)));
  }
}

@ComponentV2
export struct ForecastChart {
  @Param values: Temperature[] = [];
  @Param locale: string = 'en';
  @Local canvasWidth: number = 1;
  @Local canvasHeight: number = 120;
  @Local animationY: number = 1;
  @Local markerVisible: boolean = false;
  @Local markerLeft: number = 0;
  @Local markerTop: number = 0;
  @Local markerText: string = '';
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private points: ForecastPoint[] = [];
  private chartState: ForecastChartState = new ForecastChartState();
  private selected: number = -1;
  private ready: boolean = false;
  private live: boolean = false;
  private animationTimer: number = -1;
  private minimum: number = 0;
  private maximum: number = 1;

  aboutToAppear(): void { this.live = true; }
  aboutToDisappear(): void { this.live = false; this.ready = false; clearInterval(this.animationTimer); }
  @Monitor('values', 'locale')
  onDataChange(): void { if (this.ready) { this.setData(); } }

  private setData(): void {
    this.points = createWeekDayForecast(this.values);
    this.chartState.setData(this.points);
    this.chartState.setPosition('bottom');
    this.chartState.changeAxisY(forecastWeekLabels(this.locale,
      i18n.getCalendar(this.locale).getFirstDayOfWeek() === 1));
    this.selected = -1;
    this.markerVisible = false;
    if (this.points.length > 0) {
      this.chartState.setAxisYMin(this.chartState.getAxisYMin() - 2);
      this.chartState.setAxisYMax(this.chartState.getAxisYMax() + 2);
      this.minimum = this.chartState.axisMinimum;
      this.maximum = this.chartState.axisMaximum;
    }
    clearInterval(this.animationTimer);
    const started = Date.now();
    this.animationY = 0;
    this.animationTimer = setInterval((): void => {
      if (!this.live) { return; }
      const t = Math.min(1, (Date.now() - started) / 1000);
      this.animationY = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
      this.refresh();
      if (t === 1) { clearInterval(this.animationTimer); }
    }, 16);
    this.refresh();
  }
  private px(point: ForecastPoint): number {
    if (this.points.length < 2) { return 35; }
    const first = this.points[0].x;
    const last = this.points[this.points.length - 1].x;
    return 35 + (point.x - first) / (last - first) * (this.canvasWidth - 45);
  }
  private py(point: ForecastPoint): number {
    return this.canvasHeight - 30 - (point.y - this.minimum) / (this.maximum - this.minimum) *
      (this.canvasHeight - 55) * this.animationY;
  }
  // MPAndroidChart's cubicIntensity default is .2; retain neighbouring-point control tangents.
  private curve(): void {
    if (this.points.length === 0) { return; }
    const c = this.context;
    c.moveTo(this.px(this.points[0]), this.py(this.points[0]));
    for (let i = 1; i < this.points.length; i++) {
      const prev = this.points[i - 1];
      const before = this.points[Math.max(0, i - 2)];
      const curr = this.points[i];
      const next = this.points[Math.min(this.points.length - 1, i + 1)];
      c.bezierCurveTo(this.px(prev) + (this.px(curr) - this.px(before)) * 0.2,
        this.py(prev) + (this.py(curr) - this.py(before)) * 0.2,
        this.px(curr) - (this.px(next) - this.px(prev)) * 0.2,
        this.py(curr) - (this.py(next) - this.py(prev)) * 0.2, this.px(curr), this.py(curr));
    }
  }
  private refresh(): void {
    if (!this.ready) { return; }
    const c = this.context;
    c.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    if (this.points.length === 0) { return; }
    const bottom = this.canvasHeight - 30;
    c.beginPath(); this.curve();
    c.lineTo(this.px(this.points[this.points.length - 1]), bottom);
    c.lineTo(this.px(this.points[0]), bottom); c.closePath();
    const gradient = c.createLinearGradient(0, 20, 0, bottom);
    gradient.addColorStop(0, 'rgba(43,0,165,0.2)'); gradient.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = gradient; c.fill();
    c.beginPath(); this.curve(); c.strokeStyle = '#000000'; c.lineWidth = 2; c.stroke();
    c.font = '12px sans-serif'; c.fillStyle = '#000000'; c.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
      const value = this.minimum + (this.maximum - this.minimum) * i / 4;
      c.fillText(String(Math.round(value)), 29, bottom - (bottom - 25) * i / 4);
    }
    const days = this.chartState.labels;
    c.textAlign = 'center';
    for (let day = 1; day < days.length; day++) {
      const x = this.px(new ForecastPoint(day));
      if (x >= 35 && x <= this.canvasWidth - 10) { c.fillText(days[day], x, this.canvasHeight - 9); }
    }
    if (this.selected >= 0 && this.selected < this.points.length) {
      const point = this.points[this.selected]; const x = this.px(point); const y = this.py(point);
      c.beginPath(); c.moveTo(x, 10); c.lineTo(x, bottom); c.strokeStyle = '#21005D'; c.stroke();
      // Source CustomMarkerView offsets (-width/2, -height-10); use the migrated vector,
      // including its rounded capsule and pointer, instead of an unrelated white rectangle.
      this.markerLeft = Math.max(0, Math.min(this.canvasWidth - 46, x - 23));
      this.markerTop = Math.max(0, y - 35);
      this.markerText = Math.trunc(point.y) + '°';
      this.markerVisible = true;
    }
  }
  private selectAt(x: number): void {
    let distance = Number.MAX_VALUE; this.selected = -1;
    for (let i = 0; i < this.points.length; i++) {
      const next = Math.abs(this.px(this.points[i]) - x);
      if (next < distance) { distance = next; this.selected = i; }
    }
    this.refresh();
  }
  getChart(): CanvasRenderingContext2D { return this.context; }
  getDataSet(): ForecastPoint[] { return this.chartState.getDataSet(); }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
    Canvas(this.context).id('chDayForecast').width('100%').height(120).margin({ top: 16 })
      .onReady((): void => { this.ready = true; this.setData(); })
      .onAreaChange((_old: Area, area: Area): void => {
        this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.refresh();
      })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down && event.touches.length > 0) { this.selectAt(event.touches[0].x); }
      })
      if (this.markerVisible) {
        Stack() {
          Image($r('app.media.ic_temperature_display_icon')).width(46).height(25).objectFit(ImageFit.Fill)
          Text(this.markerText).fontSize(14).fontColor(Color.Black).margin({ bottom: 3 })
        }.width(46).height(25).position({ x: this.markerLeft, y: this.markerTop + 16 })
          .hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').height(136)
  }
}
