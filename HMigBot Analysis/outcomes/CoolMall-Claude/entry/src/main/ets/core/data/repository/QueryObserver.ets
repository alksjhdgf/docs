/**
 * QueryObserver — replaces Room `Flow<List<T>>` observation (DATA-A25 "list queries are observable").
 * Runs the query once immediately (Flow initial emission) and again after every DAO write notification.
 * Out-of-order results are dropped (only the latest query result is delivered).
 * Unsubscribe with the owning repository's `unsubscribe(id)`; a query already in flight may still
 * deliver once afterwards, so callbacks must ignore results after the page is gone (conventions A2.4).
 */
import { LogUtils } from '../../util/LogUtils';

const TAG: string = 'QueryObserver';

export class QueryObserver {
  static observe<T>(subscribeFn: (cb: () => void) => number, query: () => Promise<T>,
    onData: (data: T) => void): number {
    let seq: number = 0;
    const run = (): void => {
      seq++;
      const mySeq: number = seq;
      query().then((data: T): void => {
        if (mySeq === seq) {
          onData(data);
        }
      }).catch((err: Error): void => {
        LogUtils.eTag(TAG, 'observed query failed: ' + (err?.message ?? ''));
      });
    };
    const id: number = subscribeFn(run);
    run();
    return id;
  }
}
