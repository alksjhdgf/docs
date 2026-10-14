/**
 * RateLimiter.ets —— 源 model/RateLimiter.kt：按 key（主机）限速，每秒最多 3 次（间隔 1000/3=333ms）。
 * 不足间隔时随机等待 [剩余, 2×剩余) 毫秒后重新检查（FS-A15）；block 完成后才记录时间。
 * ArkTS 单线程：源 blockingRateLimited（Thread.sleep）与 suspendingRateLimited（delay）统一为异步等待。
 */

const LOG_TAG: string = 'FEEDER_RATELIMIT';

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

export class RateLimiter {
  static readonly MAX_PER_SECOND: number = 3;
  /** 1000L / 3 = 333（Kotlin Long 整除） */
  static readonly DELAY_MS: number = Math.floor(1000 / RateLimiter.MAX_PER_SECOND);

  private static lastTime: Map<string, number> = new Map<string, number>();

  /** Random.nextLong(remaining, remaining*2)：[remaining, 2*remaining) 内均匀整数 */
  static randomSleepTime(remainingTime: number): number {
    return remainingTime + Math.floor(Math.random() * remainingTime);
  }

  /** 距离上次请求不足 DELAY_MS 时需要的剩余毫秒；无需等待返回 0 */
  static remainingTime(key: string, now: number): number {
    const last = RateLimiter.lastTime.get(key);
    const diff = now - (last !== undefined ? last : 0);
    return diff < RateLimiter.DELAY_MS ? RateLimiter.DELAY_MS - diff : 0;
  }

  /** 源 suspendingRateLimited / blockingRateLimited */
  static async rateLimited<T>(key: string, block: () => Promise<T>): Promise<T> {
    while (true) {
      const remaining = RateLimiter.remainingTime(key, Date.now());
      if (remaining > 0) {
        const sleepTime = RateLimiter.randomSleepTime(remaining);
        console.debug(`${LOG_TAG}: Rate limit hit [${key}]. Sleeping for ${sleepTime} ms`);
        await sleepMs(sleepTime);
      } else {
        // 源 block().also { lastTime[key] = now; cleanOldEntries() }：block 抛异常时不记录（照源）
        const result: T = await block();
        RateLimiter.lastTime.set(key, Date.now());
        RateLimiter.cleanOldEntries();
        return result;
      }
    }
  }

  /** 源 cleanOldEntries：移除 value < now - 60（源写的是 60 毫秒，照搬） */
  static cleanOldEntries(): void {
    const now = Date.now();
    const stale: string[] = [];
    RateLimiter.lastTime.forEach((v: number, k: string) => {
      if (v < now - 60) {
        stale.push(k);
      }
    });
    for (const k of stale) {
      RateLimiter.lastTime.delete(k);
    }
  }

  /** 测试用：清空状态 */
  static resetForTest(): void {
    RateLimiter.lastTime.clear();
  }
}
