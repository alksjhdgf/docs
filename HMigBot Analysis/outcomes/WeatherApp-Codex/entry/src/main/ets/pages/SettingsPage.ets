import { promptAction } from '@kit.ArkUI';
import { AppRouter, Routes } from '../common/Router';
import { weatherService, WeatherService } from '../core/WeatherService';

type PreferenceKey = 'languagePrefs' | 'temperaturePrefs' | 'windSpeedPrefs' | 'airPressurePrefs';

class PreferenceOption {
  value: string;
  label: string;
  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

@Builder
export function SettingsPageBuilder() {
  SettingsPage()
}

@ComponentV2
struct SettingsPage {
  @Local service: WeatherService = weatherService;
  @Local topInset: number = 0;
  @Local entryOffset: string = '100%';
  private alive: boolean = false;
  private choosing: boolean = false;
  private insetTimer: number = -1;
  private returning: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    this.readWindowInset();
    // The frozen ability publishes primitive AppStorage values after loadContent
    // and on avoidAreaChange. V2 must not use V1 @StorageProp: keep observing
    // that read-only bridge, including a late initial publication and rotation.
    this.insetTimer = setInterval((): void => {
      if (this.alive) { this.readWindowInset(); }
    }, 150);
    this.initialize();
  }

  aboutToDisappear(): void {
    this.alive = false;
    clearInterval(this.insetTimer);
    this.insetTimer = -1;
  }

  private readWindowInset(): void {
    this.topInset = AppStorage.get<number>('statusBarHeight') ?? 0;
  }

  private async initialize(): Promise<void> {
    try {
      // Also supports the frozen smoke route entering Settings before Main.
      await this.service.init(false);
    } catch (error) {
      console.error('Settings initialization: ' + String(error));
    }
  }

  private localized(en: string, ru: string): string {
    return this.service.locale === 'ru' ? ru : en;
  }

  private preferenceTitle(key: PreferenceKey): string {
    if (key === 'languagePrefs') { return this.localized('Select language', 'Выбрать язык'); }
    if (key === 'temperaturePrefs') { return this.localized('Temperature', 'Температура'); }
    if (key === 'windSpeedPrefs') { return this.localized('Wind', 'Ветер'); }
    return this.localized('Air pressure', 'Давление воздуха');
  }

  private options(key: PreferenceKey): PreferenceOption[] {
    if (key === 'languagePrefs') {
      return [new PreferenceOption('en', 'English'), new PreferenceOption('ru', 'Русский')];
    }
    if (key === 'temperaturePrefs') {
      return [
        new PreferenceOption('celsius', this.localized('Degrees Celsius (°C)', 'Градусы Цельсия (°C)')),
        new PreferenceOption('fahrenheit', this.localized('Degrees Fahrenheit (°F)', 'Градусы Фаренгейта (°F)'))
      ];
    }
    if (key === 'windSpeedPrefs') {
      return [
        new PreferenceOption('kmh', this.localized('Kilometers per hour (km/h)', 'Километры в час (км/ч)')),
        new PreferenceOption('ms', this.localized('Meters per second (m/s)', 'Метры в секунду (м/с)')),
        new PreferenceOption('mph', this.localized('Miles per hour (mph)', 'Миль в час (миль/ч)'))
      ];
    }
    return [
      new PreferenceOption('hpa', this.localized('Hectopascals (hPa)', 'Гектопаскали (гПа)')),
      new PreferenceOption('mmhg', this.localized('Millimeters of mercury column (mmHg)',
        'Миллиметры ртутного столба (мм. рт. ст.)')),
      new PreferenceOption('inhg', this.localized('Inch of mercury column (inHg)',
        'Дюйм ртутного столба (дюйм рт. ст.)'))
    ];
  }

  private currentValue(key: PreferenceKey): string {
    if (key === 'languagePrefs') { return this.service.units.languagePrefs; }
    if (key === 'temperaturePrefs') { return this.service.units.temperaturePrefs; }
    if (key === 'windSpeedPrefs') { return this.service.units.windSpeedPrefs; }
    return this.service.units.airPressurePrefs;
  }

  private summary(key: PreferenceKey): string {
    const options = this.options(key);
    const value = this.currentValue(key);
    for (let index = 0; index < options.length; index++) {
      if (options[index].value === value) { return options[index].label; }
    }
    return '';
  }

  private async choose(key: PreferenceKey): Promise<void> {
    if (this.choosing || !this.alive) { return; }
    this.choosing = true;
    const options = this.options(key);
    const buttons: [promptAction.Button, promptAction.Button?, promptAction.Button?] = [
      { text: options[0].label, color: '#FFFFFF' }
    ];
    for (let index = 0; index < options.length; index++) {
      const button: promptAction.Button = {
        text: options[index].label,
        color: options[index].value === this.currentValue(key) ? '#90CAF9' : '#FFFFFF'
      };
      buttons[index] = button;
    }
    // A native single-choice action menu dismisses immediately after an item tap.
    // Current value remains visible in the title and is distinguished by color.
    const menu: promptAction.ActionMenuOptions = {
      title: this.preferenceTitle(key) + '\n' + this.summary(key),
      buttons: buttons
    };
    let selection: number = -1;
    try {
      const result = await this.getUIContext().getPromptAction().showActionMenu(menu);
      selection = result.index;
    } catch (error) {
      // Native cancel/back rejects; it must not change the stored value.
      selection = -1;
    }
    this.choosing = false;
    if (!this.alive || selection < 0 || selection >= options.length) { return; }
    try {
      if (key === 'languagePrefs') {
        // Service starts the new-locale nearest-place request BEFORE applying UI locale.
        await this.service.changeLanguage(options[selection].value);
      } else {
        // Conversion is immediate on the shared forecast; no weather fetch or Save button.
        await this.service.changeUnit(key, options[selection].value);
      }
    } catch (error) {
      console.error('Settings persistence: ' + String(error));
    }
  }

  private returnToMain(): void {
    if (!this.alive || this.returning) { return; }
    this.returning = true;
    if (AppRouter.stack.getAllPathName().indexOf(Routes.MAIN) >= 0) {
      // Pop invokes MainPage.openSettings's onPop callback: the actual homepage
      // swipeRefresh moves from -300 to 0 over 350ms, not a substitute native slide.
      // Both toolbar and system back take this same callback-preserving path.
      AppRouter.back();
    } else {
      AppRouter.goHome();
    }
  }

  @Builder
  private preferenceRow(key: PreferenceKey) {
    Column() {
      Text(this.preferenceTitle(key)).fontSize(16).fontColor('#FFFFFF')
      Text(this.summary(key)).fontSize(14).fontColor('#BDBDBD').margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .id(key)
    .accessibilityGroup(true)
    .accessibilityText(this.preferenceTitle(key) + ', ' + this.summary(key))
    .onClick(() => { this.choose(key); })
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button('←', { type: ButtonType.Circle })
            .width(48).height(48).fontSize(28).fontColor('#FFFFFF').backgroundColor('#000000')
            .id('backBtn')
            .accessibilityText(this.localized('Go back', 'Вернуться назад'))
            .accessibilityDescription(this.localized('Go back', 'Вернуться назад'))
            .onClick(() => { this.returnToMain(); })
          Text(this.localized('Settings', 'Настройки'))
            .fontSize(22).fontColor('#FFFFFF').margin({ left: 4 })
        }
        // Title constrained to backBtn top/bottom in source XML: vertically centered.
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .padding({ left: 4, right: 4 })
        Scroll() {
          Column() {
            Text(this.localized('Language', 'Язык'))
              .fontSize(14).fontColor('#90CAF9').padding({ left: 16, right: 16, top: 16, bottom: 8 })
            this.preferenceRow('languagePrefs')
            Text(this.localized('Units', 'Единицы'))
              .fontSize(14).fontColor('#90CAF9').padding({ left: 16, right: 16, top: 16, bottom: 8 })
            this.preferenceRow('temperaturePrefs')
            this.preferenceRow('windSpeedPrefs')
            this.preferenceRow('airPressurePrefs')
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .width('100%')
        }
        .align(Alignment.TopStart)
        .layoutWeight(1)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .padding({ top: this.topInset })
      // Source slide_in_right/slide_out_right: content enters/exits by its full width.
      .translate({ x: this.entryOffset })
      .onAppear((): void => {
        this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, (): void => {
          this.entryOffset = '0%';
        });
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.IDENTITY,
        TransitionEffect.translate({ x: '100%' }).animation({ duration: 300, curve: Curve.EaseIn })
      ))
    }
    .hideTitleBar(true)
    // Android removes Settings while animating the underlying homepage only.
    .systemTransition(NavigationSystemTransitionType.NONE)
    .onShown(() => { this.returning = false; this.readWindowInset(); })
    .onBackPressed((): boolean => { this.returnToMain(); return true; })
  }
}
