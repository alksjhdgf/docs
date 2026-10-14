import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';

export abstract class BinaryStore {
  abstract readBytes(): ArrayBuffer;
  abstract writeBytes(value: ArrayBuffer): void;
  abstract flush(): Promise<void>;
}

export class FileSnapshotStore extends BinaryStore {
  private path: string;
  private pending: ArrayBuffer | null = null;
  constructor(path: string) {
    super(); this.path = path;
    // A zero-byte protobuf is the source empty (null, null) installation value.
    // Never truncate or replace an existing/corrupt file on initialization.
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.closeSync(file);
    } catch (error) {
      // Defer storage failure to the guarded repository reads/saves. Do not
      // kill Ability.onCreate or substitute fabricated successful cache bytes.
      console.error('settings.pb initialization failed: ' + String(error));
    }
  }
  readBytes(): ArrayBuffer {
    try {
      const file = fileIo.openSync(this.path, fileIo.OpenMode.READ_ONLY);
      try {
        const bytes = new ArrayBuffer(fileIo.statSync(file.fd).size);
        let offset = 0;
        while (offset < bytes.byteLength) {
          const chunk = new ArrayBuffer(bytes.byteLength - offset);
          const count = fileIo.readSync(file.fd, chunk);
          if (count === 0) { throw new Error('Unexpected end of settings.pb'); }
          new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), offset); offset += count;
        }
        return bytes;
      } finally { fileIo.closeSync(file); }
    } catch (error) { throw new Error('settings.pb read failed: ' + String(error)); }
  }
  writeBytes(value: ArrayBuffer): void { this.pending = value.slice(0); }
  async flush(): Promise<void> {
    const bytes = this.pending;
    if (bytes === null) { return; }
    const temporary = this.path + '.tmp';
    try {
      const file = fileIo.openSync(temporary, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        let offset = 0;
        while (offset < bytes.byteLength) {
          const count = fileIo.writeSync(file.fd, bytes.slice(offset));
          if (count === 0) { throw new Error('Unable to write settings.pb'); }
          offset += count;
        }
        fileIo.fsyncSync(file.fd);
      } finally { fileIo.closeSync(file); }
      fileIo.renameSync(temporary, this.path);
      this.pending = null;
    } catch (error) { throw new Error('settings.pb write failed: ' + String(error)); }
  }
}

// DataStoreSerializer.getDefaultValue(): new DataStoreProto(null, null).
// This DTO describes only the empty installation value, not populated models.
class EmptySnapshotDTO {
  settings: null = null;
  forecast: null = null;
}

export class Runtime {
  static context: common.UIAbilityContext | null = null;
  private static dataStore: BinaryStore | null = null;
  static unitPreferences: preferences.Preferences | null = null;
  static readonly snapshotKey: string = 'snapshot';
  static readonly defaultSnapshot: string = JSON.stringify(new EmptySnapshotDTO());

  static init(context: common.UIAbilityContext): void {
    Runtime.context = context;
    if (Runtime.unitPreferences === null) {
      const options: preferences.Options = { name: 'weather_preferences' };
      Runtime.unitPreferences = preferences.getPreferencesSync(context, options);
    }
    if (Runtime.dataStore !== null) {
      Runtime.initializeApplicationLocale();
      return;
    }
    Runtime.dataStore = new FileSnapshotStore(context.filesDir + '/settings.pb');
    Runtime.initializeApplicationLocale();
  }

  // LocaleAwareApplication.onCreate equivalent: restore the application language
  // before any page or view model is created. The service may reapply it later,
  // but is no longer the owner of the initial application resource language.
  private static initializeApplicationLocale(): void {
    const context = Runtime.context;
    const store = Runtime.unitPreferences;
    if (context === null || store === null) {
      throw new Error('Runtime.init must precede application locale initialization');
    }
    const locale = store.getSync('languagePrefs', 'en') as string;
    context.getApplicationContext().setLanguage(locale);
  }

  static async flush(): Promise<void> {
    const store = Runtime.dataStore;
    if (store === null) {
      throw new Error('Runtime.init must precede saving settings.pb');
    }
    await store.flush();
  }

  static getDataStore(): BinaryStore | null { return Runtime.dataStore; }
  static setDataStore(store: BinaryStore | null): void { Runtime.dataStore = store; }
  static async flushUnitPreferences(): Promise<void> {
    const store = Runtime.unitPreferences;
    if (store === null) { throw new Error('Runtime.init must precede saving unit preferences'); }
    await store.flush();
  }
}
