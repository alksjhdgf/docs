import { intl } from '@kit.LocalizationKit';
import { ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { AppRouter, Routes } from '../common/Router';
import { Coordinates, DayForecast, Forecast, Place } from '../core/Models';
import { weatherService, WeatherService } from '../core/WeatherService';
import { WeatherDetails } from '../components/WeatherDetails';
import { Runtime } from '../core/Runtime';

export function parseDate(value: string): Date {
  const date = new Date(value.replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? new Date() : date;
}
export function searchResultLabel(place: Place): string {
  return place.toponymName + ', ' + (place.adminName1.length === 0 ? '' : place.adminName1 + ', ') + place.countryName;
}

@Builder
export function MainPageBuilder() { MainPage() }

@ComponentV2
struct MainPage {
  @Local service: WeatherService = weatherService;
  // Retain last successful controls when Resource becomes Loading/Error, as Android observers do.
  @Local displayedForecast: Forecast | null = null;
  @Local displayedPlace: string = '';
  @Local hasDisplayedPlace: boolean = false;
  @Local refreshing: boolean = false;
  @Local searchOpen: boolean = false;
  @Local query: string = '';
  @Local results: Place[] = [];
  @Local headerProgress: number = 0;
  @Local headerMoving: boolean = false;
  @Local innerGesture: boolean = false;
  @Local horizontalGesture: boolean = false;
  @Local statusInset: number = 0;
  @Local bottomInset: number = 0;
  @Local mainTranslation: number = 0;
  @Local pageWidth: number = 300;
  private scroll: Scroller = new Scroller();
  private live: boolean = false;
  private storageTimer: number = -1;
  private applicationContext: common.ApplicationContext | null = null;
  private appStateListener: ApplicationStateChangeCallback = {
    onApplicationForeground: (): void => { if (this.live) { this.readWindowState(); } },
    onApplicationBackground: (): void => { if (this.live) { this.saveOnStop(); } }
  };
  private queryGeneration: number = 0;
  private weatherToastShown: string | null = null;
  private horizontalStartOffset: number = 0;
  private horizontalStartHeader: number = 0;
  private headerPanActive: boolean = false;
  private headerPanOffset: number = 0;

  aboutToAppear(): void {
    this.live = true;
    this.readWindowState();
    if (Runtime.context !== null) {
      this.applicationContext = Runtime.context.getApplicationContext();
      this.applicationContext.on('applicationStateChange', this.appStateListener);
    }
    // V2 cannot use @StorageProp. Read only the frozen ability's primitive bridge;
    // no singleton is placed into V1 AppStorage, and the observer timer is disposed.
    this.storageTimer = setInterval((): void => {
      if (!this.live) { return; }
      this.readWindowState();
    }, 150);
    this.initialize();
  }
  aboutToDisappear(): void {
    this.saveOnStop(); this.live = false; this.queryGeneration += 1; clearInterval(this.storageTimer);
    this.applicationContext?.off('applicationStateChange', this.appStateListener);
    this.applicationContext = null;
  }
  private readWindowState(): void {
    this.statusInset = AppStorage.get<number>('statusBarHeight') ?? 0;
    this.bottomInset = AppStorage.get<number>('navigationBarHeight') ?? 0;
  }
  private async initialize(): Promise<void> {
    try {
      await this.service.init(false);
      if (!this.live) { return; }
      this.retainSuccess();
      this.weatherToastShown = null;
      await this.service.init(true); // permission request then location refresh; do not await permission first
      if (this.live) { this.observeViewModel(); this.observeWeatherError(); }
    } catch (error) { console.error('Main initialization: ' + String(error)); }
  }
  private saveOnStop(): void {
    this.service.saveSnapshot().catch((error: Error): void => console.error('Main onStop: ' + error.message));
  }
  @Monitor('service.forecastStatus', 'service.forecast', 'service.placeStatus', 'service.placeName')
  private observeViewModel(): void {
    if (!this.live) { return; }
    this.retainSuccess();
    if (this.service.forecastStatus === 'loading') { this.refreshing = true; this.weatherToastShown = null; }
    if ((this.service.forecastStatus === 'success' && this.service.forecast !== null) ||
      (this.service.forecastStatus === 'error' && this.service.weatherError !== null)) { this.refreshing = false; }
  }
  private retainSuccess(): void {
    if (this.service.forecastStatus === 'success' && this.service.forecast !== null) {
      this.displayedForecast = this.service.forecast;
    }
    if (this.service.placeStatus === 'success' && this.service.placeName !== null) {
      this.displayedPlace = this.service.placeName;
      this.hasDisplayedPlace = true;
    }
  }
  @Monitor('service.weatherError')
  private observeWeatherError(): void {
    if (this.live && this.service.weatherError !== null && this.weatherToastShown !== this.service.weatherError) {
      this.weatherToastShown = this.service.weatherError; this.showToast(this.service.weatherError);
    }
  }
  private showToast(message: string): void {
    if (this.live) { this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 }); }
  }
  private refresh(): void {
    // Also guard the callback: Refresh can already have recognized a pull before
    // the child's reactive pullToRefresh(false) reaches the native recognizer.
    if (this.innerGesture || this.headerMoving || this.headerProgress !== 0) {
      this.refreshing = this.service.forecastStatus === 'loading';
      return;
    }
    this.weatherToastShown = null;
    this.service.refresh().then((): void => {
      if (this.live) { this.observeViewModel(); this.observeWeatherError(); }
    }).catch((error: Error): void => console.error(String(error)));
  }
  private async submitSearch(): Promise<void> {
    // Lifetime guard only, NOT latest-query cancellation/versioning (source permits racing queries).
    const generation = this.queryGeneration;
    await this.service.search(this.query);
    if (!this.live || !this.searchOpen || generation !== this.queryGeneration) { return; }
    if (this.service.searchStatus === 'success' && this.service.searchResults !== null) {
      this.results = this.service.searchResults; // includes empty success; preserves GeoNames response order
    } else if (this.service.searchStatus === 'error' && this.service.searchError !== null) {
      this.showToast(this.service.searchError); // old list intentionally retained
    }
  }
  private selectPlace(place: Place): void {
    const coords = new Coordinates(Number(place.latitude), Number(place.longitude));
    if (place.latitude.trim().length === 0 || place.longitude.trim().length === 0 ||
      Number.isNaN(coords.latitude) || Number.isNaN(coords.longitude)) {
      console.error('Invalid coordinate string'); return;
    }
    this.service.setLocation(coords);
    this.weatherToastShown = null;
    this.service.fetchWeatherAndPlace(coords).then((): void => {
      if (this.live) { this.observeViewModel(); this.observeWeatherError(); }
    }).catch((error: Error): void => console.error(String(error)));
    this.searchOpen = false; this.queryGeneration += 1;
  }
  private openSearch(): void {
    // Each Android SearchMenuFragment starts with a fresh adapter, not cached suggestions.
    this.query = ''; this.results = []; this.searchOpen = true;
  }
  private openSettings(): void {
    this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseInOut }, (): void => {
      this.mainTranslation = -this.pageWidth;
    });
    AppRouter.push(Routes.SETTINGS, undefined, (_pop: PopInfo): void => {
      if (!this.live) { return; }
      this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseInOut }, (): void => {
        this.mainTranslation = 0;
      });
    });
  }
  private day(): DayForecast | null { return this.displayedForecast?.dayForecast ?? null; }
  // Source fragment_main.xml's initial controls, not a synthetic Forecast or a success state.
  private temperature(): string { const value = this.day()?.temperature; return value == null ? '20°' : Math.trunc(value.temperature) + '°'; }
  private feelsLike(): string {
    const value = this.day()?.apparentTemp;
    return value == null ? '' : (this.service.locale === 'ru' ? 'Ощущается ' : 'Feels like ') + Math.trunc(value.temperature) + '°';
  }
  private dayNight(): string {
    const day = this.day();
    if (day === null || day.dayTemp === null || day.nightTemp === null) { return ''; }
    return (this.service.locale === 'ru' ? 'Днем ' : 'Day ') + Math.trunc(day.dayTemp.temperature) + '°\n' +
      (this.service.locale === 'ru' ? 'Ночью ' : 'Night ') + Math.trunc(day.nightTemp.temperature) + '°';
  }
  private lastUpdate(): string {
    const day = this.day(); if (day === null) { return ''; }
    const date = parseDate(day.date);
    const month = new intl.DateTimeFormat(this.service.locale, { month: 'long' }).format(date);
    const time = String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0');
    return this.service.locale === 'ru' ? 'Последнее обновление\n' + date.getDate() + ' ' + month + ', ' + time :
      'Last update\n' + month + ' ' + date.getDate() + ', ' + time;
  }
  private foreground(): string {
    // MotionScene holds white through frame 50 and reaches black at frame 60.
    const colorProgress = Math.max(0, Math.min(1, (this.headerProgress - 0.5) / 0.1));
    const gray = Math.round(255 * (1 - colorProgress)); return 'rgb(' + gray + ',' + gray + ',' + gray + ')';
  }
  private settleHeader(): void {
    if (!this.headerMoving || this.innerGesture || this.headerPanActive) { return; }
    const target = this.headerProgress < 0.5 ? 0 : 1;
    this.getUIContext().animateTo({ duration: Math.max(1, Math.round(1000 * Math.abs(target - this.headerProgress))),
      curve: Curve.EaseInOut, onFinish: (): void => { if (this.live) { this.headerMoving = false; } }
    }, (): void => { this.headerProgress = target; });
  }
  private degreePositionCorrection(): number {
    // Degree and icon both pass through 85% of their vertical path at frame 80.
    const position = this.headerProgress <= 0.8 ? this.headerProgress * 0.85 / 0.8 :
      0.85 + (this.headerProgress - 0.8) * 0.15 / 0.2;
    return -229 * (position - this.headerProgress);
  }
  private keyPosition(frame: number, fraction: number): number {
    // deltaRelative positions interpolate the start/end centre displacement,
    // independently of the (still linear) size interpolation.
    const progress = this.headerProgress;
    return progress <= frame ? progress * fraction / frame :
      fraction + (progress - frame) * (1 - fraction) / (1 - frame);
  }
  private backgroundPositionCorrection(): number {
    // Top stays -30, height loses 229: the centre's end displacement is -114.5.
    return -114.5 * (this.keyPosition(0.6, 0.3) - this.headerProgress);
  }
  private datePositionCorrection(): number {
    // Bottom-anchored row: header loses 229 while its height loses 59.
    return (-229 + 59 / 2) * (this.keyPosition(0.7, 0.5) - this.headerProgress);
  }
  private consumeHeader(offset: number): number {
    if (this.horizontalGesture) { return 0; }
    if (this.innerGesture || this.refreshing) { return offset; }
    if (offset > 0 && this.headerProgress < 1) {
      this.headerMoving = true;
      const consumed = Math.min(offset, (1 - this.headerProgress) * 229);
      this.headerProgress = Math.min(1, this.headerProgress + consumed / 229);
      return offset - consumed;
    }
    if (offset < 0 && this.scroll.currentOffset().yOffset <= 0 && this.headerProgress > 0) {
      // Restoration is driven by the finger, not a scroll frame: at the top
      // Scroll can clamp its negative delta to zero. Do not also consume the
      // same delta here, or devices that emit boundary frames expand twice.
      return 0;
    }
    return offset;
  }
  private restoreHeader(event: GestureEvent): void {
    const delta = event.offsetY - this.headerPanOffset;
    this.headerPanOffset = event.offsetY;
    if (delta <= 0 || this.innerGesture || this.horizontalGesture || this.refreshing ||
      this.scroll.currentOffset().yOffset > 0.5 || this.headerProgress <= 0) { return; }
    this.headerMoving = true;
    this.headerProgress = Math.max(0, this.headerProgress - delta / 229);
  }
  private endHeaderPan(): void {
    this.headerPanActive = false;
    this.headerPanOffset = 0;
    this.settleHeader();
  }
  private horizontalOwnership(active: boolean): void {
    if (active === this.horizontalGesture) { return; }
    this.horizontalGesture = active;
    if (active) {
      this.horizontalStartOffset = this.scroll.currentOffset().yOffset;
      this.horizontalStartHeader = this.headerProgress;
    }
    this.traceHorizontalGesture(active ? 'begin' : 'end');
  }
  private traceHorizontalGesture(phase: string): void {
    // Runtime evidence hook, not an assertion of a device pass. Contains no
    // location/weather payload. The 4b runner can correlate every native MOVE
    // with outer offset/header deltas and the actual loading/refresh state.
    console.info('[WeatherGesture] hourly ' + phase + ' parentDelta=' +
      (this.scroll.currentOffset().yOffset - this.horizontalStartOffset) +
      ' headerDelta=' + (this.headerProgress - this.horizontalStartHeader) +
      ' refreshing=' + this.refreshing + ' loading=' + (this.service.forecastStatus === 'loading') +
      ' refreshEnabled=' + (this.headerProgress === 0 && !this.headerMoving && !this.innerGesture));
  }
  @Builder
  private searchSheet() {
    Column() {
      Row() {
        Image($r('app.media.ic_search')).width(24).height(24).objectFit(ImageFit.Contain)
          .hitTestBehavior(HitTestMode.None)
        TextInput({ text: this.query }).id('searchView').type(InputType.Normal).enterKeyType(EnterKeyType.Search)
          .layoutWeight(1).showUnderline(false).cancelButton({ style: CancelButtonStyle.INPUT })
          .onChange((value: string): void => { this.query = value; })
          .onSubmit((): void => { this.submitSearch(); })
      }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%').margin({ bottom: 23 })
      List() {
        ForEach(this.results, (place: Place) => {
          ListItem() {
            Text(searchResultLabel(place)).id('tvLocationName').fontSize(18).width('100%')
              .padding({ top: 18, bottom: 18, left: 10, right: 10 })
              .onClick((): void => this.selectPlace(place))
          }
        }, (place: Place, index: number): string => index + ':' + place.latitude + ':' + place.longitude + ':' + searchResultLabel(place))
      }.id('rvSearchList').width('100%').layoutWeight(1)
    }.alignItems(HorizontalAlign.Start).width('100%').height('100%')
      .padding({ top: this.statusInset + 23, bottom: this.bottomInset + 16, left: 23, right: 23 })
      .borderRadius({ topLeft: 28, topRight: 28 }).clip(true)
  }
  @Builder
  private weatherHeader() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Source toolbar's -30dp top extension; compensate image size so the bottom remains anchored.
      Image($r('app.media.img_main_background_night')).width('100%').height('calc(100% + 30vp)').margin({ top: -30 })
        .translate({ y: this.backgroundPositionCorrection() })
        .objectFit(ImageFit.Fill).opacity(Math.max(0, 1 - this.headerProgress / 0.65)).hitTestBehavior(HitTestMode.None)
      Column() {
        Row() {
           Text(this.hasDisplayedPlace ? this.displayedPlace : 'Chinatown').id('tvCityCountry').fontSize(22).fontColor(this.foreground()).layoutWeight(1)
             .minFontSize(14).maxFontSize(22).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
             .maxLines(this.headerProgress > 0.5 ? 1 : 2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_search')).width(24).height(24).objectFit(ImageFit.Contain).fillColor(this.foreground())
          }.id('searchBtn').width(40).height(40).backgroundColor(Color.Transparent)
            .accessibilityText(this.service.locale === 'ru' ? 'Кнопка для поиска' : 'button searchable')
            .onClick((): void => this.openSearch())
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_settings')).width(24).height(24).objectFit(ImageFit.Contain).fillColor(this.foreground())
          }.id('settingsBtn').width(40).height(40).backgroundColor(Color.Transparent)
            .accessibilityText(this.service.locale === 'ru' ? 'Кнопка настроек' : 'button settings')
            .onClick((): void => this.openSettings())
        }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%')
        Row() {
           Row() {
             Text(this.temperature()).id('tvMainDegree').fontSize(112 - 55 * this.headerProgress).fontColor(this.foreground())
               .layoutWeight(2).maxLines(1).minFontSize(32).maxFontSize(112 - 55 * this.headerProgress)
               .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
             Text(this.feelsLike()).id('tvFeelsLike').fontSize(18).fontColor(this.foreground())
               .layoutWeight(1).maxLines(3).minFontSize(12).maxFontSize(18)
               .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
               .margin({ left: 4, right: 8 })
           // Keep the source's beside-degree placement, but allocate real bounds:
           // absolute 145vp text overlapped the icon and three-digit Fahrenheit.
           }.alignItems(VerticalAlign.Center).layoutWeight(1).translate({ y: this.degreePositionCorrection() })
          Column() {
            if (this.day()?.imgIdWeatherCode != null) {
              Image($r('app.media.' + this.day()?.imgIdWeatherCode)).id('imgMainWeatherIcon')
                .width(107 - 48 * this.headerProgress).height(107 - 48 * this.headerProgress).objectFit(ImageFit.Contain)
            } else {
              Image($r('app.media.ic_clear_day')).width(107 - 48 * this.headerProgress)
                .height(107 - 48 * this.headerProgress).objectFit(ImageFit.Contain)
            }
            if (this.day()?.weatherCode != null) {
              Text($r('app.string.' + this.day()?.weatherCode)).id('tvWeatherMainText').fontSize(22)
                  .fontColor(this.foreground()).textAlign(TextAlign.Center).maxLines(3).width('100%')
                 .height(72 * (1 - this.headerProgress)).margin({ top: 11 * (1 - this.headerProgress) })
                 .minFontSize(14).maxFontSize(22).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
                 .clip(true)
                .translate({ x: this.pageWidth * Math.min(1, this.headerProgress / 0.1) * 0.5 +
                  this.pageWidth * Math.max(0, (this.headerProgress - 0.1) / 0.9) * 0.5 })
            } else {
              Text($r('app.string.weather_type_default')).fontSize(22).fontColor(this.foreground())
                  .textAlign(TextAlign.Center).maxLines(3).width('100%')
                 .height(72 * (1 - this.headerProgress)).margin({ top: 11 * (1 - this.headerProgress) })
                 .minFontSize(14).maxFontSize(22).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
                 .clip(true)
                .translate({ x: this.pageWidth * Math.min(1, this.headerProgress / 0.1) * 0.5 +
                  this.pageWidth * Math.max(0, (this.headerProgress - 0.1) / 0.9) * 0.5 })
            }
           }.alignItems(HorizontalAlign.Center).width(150 - 91 * this.headerProgress)
            .translate({ y: this.degreePositionCorrection() })
        }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%').layoutWeight(1)
        Row() {
           Text(this.lastUpdate()).id('tvLastUpdate').fontSize(18).fontColor(this.foreground()).layoutWeight(2)
             .maxLines(3).minFontSize(12).maxFontSize(18).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
           Text(this.dayNight()).id('tvDayDegrees').fontSize(18).fontColor(this.foreground()).textAlign(TextAlign.End)
             .layoutWeight(1).maxLines(2).margin({ left: 8 })
             .minFontSize(12).maxFontSize(18).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
        }.alignItems(VerticalAlign.Bottom).justifyContent(FlexAlign.SpaceBetween).width('100%')
          // End constraint compresses this container to 1dp; it does not remove it at frame 50.
          .constraintSize({ maxHeight: 60 * (1 - this.headerProgress) + this.headerProgress }).clip(true)
          .translate({ y: this.datePositionCorrection() })
      }.alignItems(HorizontalAlign.Start).width('100%').height('100%')
        .padding({ top: this.statusInset + 20, bottom: 16, left: 22, right: 22 })
     }.width('100%').height(400 - 229 * this.headerProgress).backgroundColor(Color.White).clip(true)
  }
  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
      Refresh({ refreshing: $$this.refreshing }) {
        Column() {
          this.weatherHeader()
          Scroll(this.scroll) {
            Column() {
              WeatherDetails({ forecast: this.displayedForecast, locale: this.service.locale,
                 onInnerGesture: (active: boolean): void => {
                   this.innerGesture = active;
                   if (!active) { this.settleHeader(); }
                 },
                 onHorizontalGesture: (active: boolean): void => this.horizontalOwnership(active),
                 onHorizontalMove: (): void => this.traceHorizontalGesture('move') })
            }.alignItems(HorizontalAlign.Start).width('100%')
          }.id('flTodayWeather').width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
            // Child MOVE must not be stolen by the parent scroll recognizer, not merely by the header.
             .enableScrollInteraction(!this.horizontalGesture)
            .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
            .onScrollFrameBegin((offset: number, _state: ScrollState): ScrollResult => {
              return { offsetRemain: this.consumeHeader(offset) };
            })
             .onScrollStop((): void => this.settleHeader())
             // Parallel observation does not replace either List's recognizer.
             // It still receives downward finger travel when Scroll is at zero.
             .parallelGesture(PanGesture({ direction: PanDirection.Vertical })
               .onActionStart((event: GestureEvent): void => {
                 this.headerPanActive = true; this.headerPanOffset = 0; this.restoreHeader(event);
               })
               .onActionUpdate((event: GestureEvent): void => this.restoreHeader(event))
               .onActionEnd((): void => this.endHeaderPan())
               .onActionCancel((): void => this.endHeaderPan()))
        }.alignItems(HorizontalAlign.Start).width('100%').height('100%')
      }.id('swipeRefresh').width('100%').height('100%')
        .translate({ x: this.mainTranslation })
        .pullToRefresh(this.headerProgress === 0 && !this.headerMoving && !this.innerGesture)
        .onRefreshing((): void => this.refresh())
        .padding({ bottom: this.bottomInset })
        // Blur the actual underlying weather surface, not just the sheet material.
        .blur(this.searchOpen ? 20 : 0)
        .bindSheet($$this.searchOpen, this.searchSheet(), {
          height: '100%', detents: ['100%'], preferType: SheetType.BOTTOM, showClose: false, dragBar: false,
          backgroundColor: '#DDFFFFFF', blurStyle: BlurStyle.Thick,
          onDisappear: (): void => { this.searchOpen = false; this.queryGeneration += 1; }
        })
        if (this.service.locationServiceDisabled && !this.searchOpen) {
          // Snackbar overlays the viewport; it must not displace the forecast layout.
          Row() {
            Text($r('app.string.provider_absence_notification')).fontColor(Color.White)
              .fontSize(14).layoutWeight(1)
            Button('Settings').fontColor('#BB86FC').backgroundColor(Color.Transparent)
              .onClick((): void => { this.service.openLocationSettings(); })
          }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).width('100%')
            .padding({ left: 16, right: 8, top: 8, bottom: 8 }).backgroundColor('#323232')
            .margin({ bottom: this.bottomInset }).accessibilityGroup(true)
        }
      }.width('100%').height('100%')
    }.hideTitleBar(true).backgroundColor(Color.White)
      .onAreaChange((_old: Area, area: Area): void => { this.pageWidth = Number(area.width); })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
       .onHidden((): void => this.saveOnStop())
       .onShown((): void => {
         // The popped destination may be a rebuilt instance after locale change;
         // restore its own visible surface, not an old onPop closure's instance.
         this.live = true;
         this.mainTranslation = 0;
         this.readWindowState();
         this.retainSuccess();
       })
      .onBackPressed((): boolean => {
        if (this.searchOpen) { this.searchOpen = false; this.queryGeneration += 1; return true; }
        this.saveOnStop(); return false;
      })
  }
}
