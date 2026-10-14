import originalTestsuite from '../../../test/List.test';
import nativeLocationProof from './NativeLocationProof.test';
import nativeIOGuard from './NativeIOGuard.test';

export default function testsuite(): void {
  originalTestsuite();
  nativeLocationProof();
  nativeIOGuard();
}
