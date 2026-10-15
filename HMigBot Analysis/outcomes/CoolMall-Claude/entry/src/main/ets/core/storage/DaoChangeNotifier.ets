/**
 * DaoChangeNotifier — replaces Room's Flow invalidation tracking (DATA-A25 "list queries are observable").
 * Each DAO owns one notifier; subscribers are called back (no payload) after every write and
 * should re-query. Call unsubscribe(id) symmetrically (e.g. in aboutToDisappear).
 */
import { LogUtils } from '../util/LogUtils';

export class DaoChangeNotifier {
  private nextId: number = 1;
  private listeners: Map<number, () => void> = new Map<number, () => void>();
  private tag: string;

  constructor(tag: string) {
    this.tag = tag;
  }

  subscribe(cb: () => void): number {
    const id = this.nextId;
    this.nextId++;
    this.listeners.set(id, cb);
    return id;
  }

  unsubscribe(id: number): void {
    this.listeners.delete(id);
  }

  notifyChanged(): void {
    const cbs: Array<() => void> = Array.from(this.listeners.values());
    for (const cb of cbs) {
      try {
        cb();
      } catch (e) {
        LogUtils.eTag(this.tag, 'change listener threw: ' + JSON.stringify(e));
      }
    }
  }
}
