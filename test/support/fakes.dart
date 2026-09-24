// T03 QA 独立验证 —— 共享测试替身（自包含、零平台插件依赖）。
//
// 这些假实现刻意不触碰 shared_preferences / path_provider / permission_handler /
// 高德 / camera 等平台通道，使 widget test 可在无设备环境稳定运行。

import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/repositories/parking_repository.dart';
import 'package:wo_che_ne/data/repositories/settings_repository.dart';
import 'package:wo_che_ne/services/haptic_service.dart';

/// 内存假设置仓储：模拟一份可持久化的 [AppSettings]。
class FakeSettingsRepository implements SettingsRepository {
  /// 可选初始设置，缺省为全默认值。
  FakeSettingsRepository([AppSettings? initial])
      : current = initial ?? AppSettings();

  /// 当前“落库”的设置（测试可直接读断言）。
  AppSettings current;

  /// save 被调用的次数（用于断言「同意」确实写库）。
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => current;

  @override
  Future<void> save(AppSettings settings) async {
    current = settings;
    saveCount++;
  }
}

/// 内存假停车记录仓储：保存写入顺序，记录删除轨迹（零平台依赖）。
class FakeParkingRepository implements ParkingRepository {
  /// 可选初始记录。
  FakeParkingRepository([List<ParkingRecord>? initial])
      : records = <ParkingRecord>[...?initial];

  /// 当前全部记录（保存顺序）。
  final List<ParkingRecord> records;

  /// 被 [delete] 删除过的记录 id（顺序）。
  final List<String> deletedIds = <String>[];

  /// 被 [save] 写入过的记录（顺序）。
  final List<ParkingRecord> savedRecords = <ParkingRecord>[];

  @override
  Future<List<ParkingRecord>> loadAll() async =>
      List<ParkingRecord>.of(records);

  @override
  Future<ParkingRecord?> latestActive() async {
    ParkingRecord? latest;
    for (final ParkingRecord r in records) {
      if (r.archived) {
        continue;
      }
      if (latest == null || r.createdAt.isAfter(latest.createdAt)) {
        latest = r;
      }
    }
    return latest;
  }

  @override
  Future<ParkingRecord> save(ParkingRecord record) async {
    records.add(record);
    savedRecords.add(record);
    return record;
  }

  @override
  Future<void> update(ParkingRecord record) async {
    final int index = records.indexWhere((ParkingRecord r) => r.id == record.id);
    if (index >= 0) {
      records[index] = record;
    }
  }

  @override
  Future<void> delete(String id) async {
    records.removeWhere((ParkingRecord r) => r.id == id);
    deletedIds.add(id);
  }
}

/// 高德 SDK 初始化动作探针：统计被调用的次数，验证「同意前不初始化」。
class AmapInitializerSpy {
  /// 初始化动作被调用次数。
  int calls = 0;

  /// 可作为 [AmapSdkGate.initializer] 注入的回调。
  Future<void> call() async => calls++;
}

/// 静默震动服务替身：绕开 vibration 平台通道，断言调用发生与否。
class SilentHapticService implements HapticService {
  /// [HapticService.recordSaved] / [HapticService.preview] 被调用次数。
  ///
  /// 两个方法共用同一计数器：`t03_parking_controller_test.dart` 断言
  /// `expect(haptic.calls, 1)`，另开计数器会牵动既有用例。
  int calls = 0;

  @override
  Future<void> recordSaved() async => calls++;

  @override
  Future<void> preview() async => calls++;
}

/// 构造一条测试用停车记录。
ParkingRecord buildRecord({
  required String id,
  DateTime? createdAt,
  bool archived = false,
  List<String>? photos,
  String? poiName,
  double? accuracy,
  double latitude = 39.999,
  double longitude = 116.326,
}) =>
    ParkingRecord(
      id: id,
      latitude: latitude,
      longitude: longitude,
      poiName: poiName,
      accuracy: accuracy,
      photoPaths: photos,
      createdAt: createdAt ?? DateTime(2026, 9, 23, 12, 24),
      archived: archived,
    );
