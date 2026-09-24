import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/models/app_settings.dart';
import '../data/models/parking_record.dart';
import '../data/repositories/parking_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/storage/local_store.dart';
import '../services/amap_sdk_gate.dart';
import '../services/compass_service.dart';
import '../services/haptic_service.dart';
import '../services/location_service.dart';
import '../services/shortcut_service.dart';
import 'coach_mark_controller.dart';
import 'parking_controller.dart';
import 'settings_controller.dart';

/// 全局 Provider 装配（架构 §2/§3.2）。
///
/// 依赖方向：UI → 状态 → 服务/数据 → 平台。上层只 `watch/read` 这里的 Provider，
/// 不直接 new 具体实现，便于单测用 `overrideWithValue` 注入假实现。

// ---------- 基础设施（低层，可注入） ----------

/// 设置仓储。**必须在 `main()` 的真实 `SharedPreferences` 实现上覆盖注入**。
///
/// 之所以默认抛异常而不内置实现：`SharedPreferences.getInstance()` 是异步的，
/// 放在 Provider 里会让所有依赖它的地方都被迫异步化；在 `main()` 里先 `await`
/// 拿到实例再 `overrideWithValue` 是更干净的做法。
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
  throw UnimplementedError('settingsRepositoryProvider 必须在 ProviderScope 中覆盖注入');
});

/// 高德 SDK 合规门。**必须在 `main()` 中注入**（承载冷启动的 `initIfAgreed()`）。
final Provider<AmapSdkGate> amapSdkGateProvider = Provider<AmapSdkGate>((Ref ref) {
  throw UnimplementedError('amapSdkGateProvider 必须在 ProviderScope 中覆盖注入');
});

/// 本地文件存取器（记录 JSON + 照片目录）。
final Provider<LocalStore> localStoreProvider =
    Provider<LocalStore>((Ref ref) => LocalStore());

// ---------- 仓储 / 服务（高层，依赖低层） ----------

/// 停车记录仓储（JSON 文件实现）。
final Provider<ParkingRepository> parkingRepositoryProvider =
    Provider<ParkingRepository>((Ref ref) {
  return JsonParkingRepository(
    store: ref.watch(localStoreProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
});

/// 定位服务（高德融合定位封装；每次调用前经合规门把关）。
final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) {
  return LocationService(gate: ref.watch(amapSdkGateProvider));
});

/// 震动反馈服务（读设置开关）。
final Provider<HapticService> hapticServiceProvider =
    Provider<HapticService>((Ref ref) {
  return HapticService(settings: ref.watch(settingsRepositoryProvider));
});

/// 指南针朝向服务（P1-1 方向箭头）。
final Provider<CompassService> compassServiceProvider =
    Provider<CompassService>((Ref ref) => CompassService());

/// 桌面快捷方式服务（P1-2「一键记车位」）。
final Provider<ShortcutService> shortcutServiceProvider =
    Provider<ShortcutService>((Ref ref) => ShortcutService());

/// 应用包信息（关于页版本号）。
final FutureProvider<PackageInfo> packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

/// 「距当前位置」用的尽力定位（无权限/SDK 未就绪/失败 → null）。
///
/// 抽成 Provider 便于页面复用与单测覆盖注入。
final FutureProvider<PositionFix?> currentFixProvider =
    FutureProvider<PositionFix?>((Ref ref) {
  return ref.watch(locationServiceProvider).tryGetCurrentFix();
});

/// 快捷方式「一键记车位」请求信号：true 时首页自动进入记录流程。
final StateProvider<bool> quickRecordRequestProvider =
    StateProvider<bool>((Ref ref) => false);

// ---------- 控制器（状态层） ----------

/// 设置控制器（异步读取/写回 [AppSettings]）。
final AsyncNotifierProvider<SettingsController, AppSettings>
    settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// 停车记录控制器（列表状态 + 记录 CRUD/归档/淘汰编排）。
final AsyncNotifierProvider<ParkingController, List<ParkingRecord>>
    parkingControllerProvider =
    AsyncNotifierProvider<ParkingController, List<ParkingRecord>>(
  ParkingController.new,
);

/// 新手引导控制器（3 步状态机）。
final AsyncNotifierProvider<CoachMarkController, CoachMarkState>
    coachMarkControllerProvider =
    AsyncNotifierProvider<CoachMarkController, CoachMarkState>(
  CoachMarkController.new,
);

// ---------- 派生状态 ----------

/// 最近一条未归档记录（首页双状态判据：null=停车态，非 null=找车态）。
///
/// 直接由 [parkingControllerProvider] 派生，避免重复持有数据源。
final Provider<AsyncValue<ParkingRecord?>> latestActiveRecordProvider =
    Provider<AsyncValue<ParkingRecord?>>((Ref ref) {
  final AsyncValue<List<ParkingRecord>> records =
      ref.watch(parkingControllerProvider);
  return records.whenData((List<ParkingRecord> list) {
    ParkingRecord? latest;
    for (final ParkingRecord record in list) {
      if (record.archived) {
        continue;
      }
      if (latest == null || record.createdAt.isAfter(latest.createdAt)) {
        latest = record;
      }
    }
    return latest;
  });
});

/// 全部记录按创建时间**倒序**（历史列表用）。
final Provider<AsyncValue<List<ParkingRecord>>> historyRecordsProvider =
    Provider<AsyncValue<List<ParkingRecord>>>((Ref ref) {
  return ref.watch(parkingControllerProvider).whenData(
        (List<ParkingRecord> list) => List<ParkingRecord>.unmodifiable(
          List<ParkingRecord>.of(list)
            ..sort((ParkingRecord a, ParkingRecord b) =>
                b.createdAt.compareTo(a.createdAt)),
        ),
      );
});
