import { describe, it, expect, beforeAll, afterAll } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo } from '@kit.CoreFileKit';
import { FileSnapshotStore } from '../../../main/ets/core/Runtime';
import { DataStoreSerializer } from '../../../main/ets/core/WeatherService';

export default function nativeIOGuard(): void {
  describe('NativeIOGuard', () => {
    let directory: string = '';
    beforeAll((): void => {
      const appContext = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
        .getApplicationContext();
      directory = appContext.cacheDir + '/native-io-guard-' + Date.now().toString();
      fileIo.mkdirSync(directory);
    });
    afterAll((): void => {
      if (directory !== '' && fileIo.accessSync(directory)) {
        fileIo.rmdirSync(directory);
        expect(fileIo.accessSync(directory)).assertFalse();
      }
    });
    it('emptyAndBinaryNativeWriteReadFlush', 0, async (): Promise<void> => {
      const path = directory + '/roundtrip.pb';
      try {
        const store = new FileSnapshotStore(path);
        expect(store.readBytes().byteLength).assertEqual(0);
        store.writeBytes(new ArrayBuffer(0));
        await store.flush();
        expect(fileIo.statSync(path).size).assertEqual(0);
        const bytes = new Uint8Array([0, 255, 128, 1, 0, 13, 10, 254]);
        store.writeBytes(bytes.buffer as ArrayBuffer);
        bytes[0] = 77;
        await store.flush();
        const actual = new Uint8Array(new FileSnapshotStore(path).readBytes());
        const expected = new Uint8Array([0, 255, 128, 1, 0, 13, 10, 254]);
        expect(actual.length).assertEqual(expected.length);
        for (let index = 0; index < expected.length; index++) {
          expect(actual[index]).assertEqual(expected[index]);
        }
        expect(fileIo.accessSync(path + '.tmp')).assertFalse();
        store.writeBytes(new ArrayBuffer(0));
        await store.flush();
        expect(new FileSnapshotStore(path).readBytes().byteLength).assertEqual(0);
      } finally {
        if (fileIo.accessSync(path + '.tmp')) { fileIo.unlinkSync(path + '.tmp'); }
        if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
      }
    });
    it('missingParentConstructorSurvivesGuardedReadErrors', 0, async (): Promise<void> => {
      const path = directory + '/missing-read/settings.pb';
      const store = new FileSnapshotStore(path);
      expect(fileIo.accessSync(path)).assertFalse();
      let resolved: boolean = false;
      let errorSeen: boolean = false;
      try {
        await new DataStoreSerializer().readFrom(async (): Promise<ArrayBuffer> => store.readBytes());
        resolved = true;
      } catch (error) {
        errorSeen = error instanceof Error && String(error).includes('DataStore read:') &&
          String(error).includes('settings.pb read failed:');
      }
      expect(resolved).assertFalse();
      expect(errorSeen).assertTrue();
      expect(fileIo.accessSync(directory + '/missing-read')).assertFalse();
    });
    it('failedNativeFlushRejectsGuardedWriteNeverSucceeds', 0, async (): Promise<void> => {
      const path = directory + '/missing-write/settings.pb';
      const store = new FileSnapshotStore(path);
      const serializer = new DataStoreSerializer();
      let resolved: boolean = false;
      let errorSeen: boolean = false;
      try {
        await serializer.writeTo(serializer.getDefaultValue(), async (bytes: ArrayBuffer): Promise<void> => {
          store.writeBytes(bytes);
          await store.flush();
        });
        resolved = true;
      } catch (error) {
        errorSeen = error instanceof Error && String(error).includes('DataStore write:') &&
          String(error).includes('settings.pb write failed:');
      }
      expect(resolved).assertFalse();
      expect(errorSeen).assertTrue();
      let rejectedAgain: boolean = false;
      try { await store.flush(); } catch (error) {
        rejectedAgain = error instanceof Error && String(error).includes('settings.pb write failed:');
      }
      expect(rejectedAgain).assertTrue();
      expect(fileIo.accessSync(path)).assertFalse();
      expect(fileIo.accessSync(path + '.tmp')).assertFalse();
      expect(fileIo.accessSync(directory + '/missing-write')).assertFalse();
    });
  });
}
