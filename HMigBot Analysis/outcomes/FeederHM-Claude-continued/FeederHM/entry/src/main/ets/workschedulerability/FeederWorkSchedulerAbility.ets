/**
 * FeederWorkSchedulerAbility.ets —— WorkScheduler 扩展进程入口壳（≙ 源 FeederJobService 所在进程的 DI 装配）。
 *
 * 扩展进程不经 EntryAbility / AppBootstrap，core/* 又不得反向 import features/*，故由本壳（与 entryability 同级的
 * 进程入口）在模块加载时注册 features 级安装项，再复用通知包装的作业分派：
 *  - registerSyncChainStartupHook()：SyncScheduler.bootstrapHeadless 在 SyncScheduler.init 之后执行 installSyncChain，
 *    使后台 RSS 同步前的同步链拉取/上报（SY-A49..A51）在扩展进程同样生效；
 *  - NotifyingWorkSchedulerAbility（features/notify/RssNotifications）：注册新条目通知钩子与小组件上下文后交
 *    SyncScheduler.runWork（后台同步结束发布通知，NW-A01）。
 */
import NotifyingWorkSchedulerAbility from '../features/notify/RssNotifications';
import { registerSyncChainStartupHook } from '../features/sync/SyncChain';

registerSyncChainStartupHook();

export default class FeederWorkSchedulerAbility extends NotifyingWorkSchedulerAbility {
}
