/**
 * DependencyDataSource (source: feature/common/data/DependencyDataSource.kt) — the 21 third-party
 * dependencies listed in the About `引用致谢` sheet (data copied verbatim from the source).
 */
import { Dependency } from './Dependency';

export class DependencyDataSource {
  /** All dependencies (source getAllDependencies) */
  static getAllDependencies(): Dependency[] {
    return [
      // Android 核心库
      new Dependency('AndroidX Core KTX', '1.17.0', 'Android KTX 核心库，提供 Kotlin 扩展函数',
        'https://developer.android.com/jetpack/androidx/releases/core', 'Android 核心'),
      new Dependency('AndroidX Lifecycle Runtime KTX', '2.9.4', '生命周期感知组件的 Kotlin 扩展',
        'https://developer.android.com/jetpack/androidx/releases/lifecycle', 'Android 核心'),
      new Dependency('AndroidX Activity Compose', '1.11.0', 'Activity 与 Compose 的集成库',
        'https://developer.android.com/jetpack/androidx/releases/activity', 'Android 核心'),
      // Jetpack Compose
      new Dependency('Jetpack Compose BOM', '2025.09.00', 'Compose 库版本管理，确保所有 Compose 库版本兼容',
        'https://developer.android.com/jetpack/compose/bom', 'UI 框架'),
      new Dependency('Material3', 'BOM 管理', 'Material Design 3 组件库',
        'https://developer.android.com/jetpack/compose/designsystems/material3', 'UI 框架'),
      // 导航
      new Dependency('Navigation Compose', '2.9.4', 'Compose 导航组件',
        'https://developer.android.com/jetpack/androidx/releases/navigation', '导航'),
      // 网络请求
      new Dependency('OkHttp', '5.1.0', '高效的 HTTP 客户端库', 'https://square.github.io/okhttp/', '网络请求'),
      new Dependency('Retrofit', '3.0.0', '类型安全的 HTTP 客户端', 'https://square.github.io/retrofit/', '网络请求'),
      new Dependency('Chucker', '4.2.0', '网络请求调试工具', 'https://github.com/ChuckerTeam/chucker', '调试工具'),
      // 序列化
      new Dependency('Kotlinx Serialization JSON', '1.9.0', 'Kotlin 多平台序列化库',
        'https://github.com/Kotlin/kotlinx.serialization', '序列化'),
      // 依赖注入
      new Dependency('Hilt', '2.57.1', '基于 Dagger 的 Android 依赖注入库',
        'https://developer.android.com/training/dependency-injection/hilt-android', '依赖注入'),
      // 图片加载
      new Dependency('Coil Compose', '2.7.0', 'Kotlin 协程图片加载库', 'https://coil-kt.github.io/coil/compose/',
        '图片加载'),
      // 日志
      new Dependency('Timber', '5.0.1', 'Android 日志工具库', 'https://github.com/JakeWharton/timber', '日志'),
      // 数据存储
      new Dependency('MMKV', '2.2.3', '腾讯高性能键值存储框架', 'https://github.com/Tencent/MMKV', '数据存储'),
      new Dependency('Room', '2.8.0', 'SQLite 抽象层，提供流畅的数据库访问',
        'https://developer.android.com/training/data-storage/room', '数据存储'),
      // 动画
      new Dependency('Lottie Compose', '6.6.7', 'After Effects 动画库', 'https://airbnb.io/lottie/#/android-compose',
        '动画'),
      // 调试工具
      new Dependency('LeakCanary', '2.14', '内存泄漏检测工具', 'https://github.com/square/leakcanary', '调试工具'),
      // Toast
      new Dependency('Toaster', '13.2', 'Android 吐司框架', 'https://github.com/getActivity/Toaster', 'UI 组件'),
      // 权限
      new Dependency('XXPermissions', '26.5', 'Android 权限请求框架', 'https://github.com/getActivity/XXPermissions',
        '权限管理'),
      // 支付
      new Dependency('支付宝 SDK', '15.8.38', '支付宝移动支付 SDK', 'https://opendocs.alipay.com/open/54/104509', '支付'),
      // 启动页
      new Dependency('AndroidX Core Splashscreen', '1.0.1', '启动画面 API，兼容 Android 12+',
        'https://developer.android.com/jetpack/androidx/releases/core', '启动页')
    ];
  }

  /** Dependencies of one category (source getDependenciesByCategory) */
  static getDependenciesByCategory(category: string): Dependency[] {
    return DependencyDataSource.getAllDependencies().filter((d: Dependency): boolean => d.category === category);
  }

  /** Distinct sorted categories (source getAllCategories) */
  static getAllCategories(): string[] {
    const result: string[] = [];
    for (const d of DependencyDataSource.getAllDependencies()) {
      if (result.indexOf(d.category) < 0) {
        result.push(d.category);
      }
    }
    result.sort();
    return result;
  }
}
