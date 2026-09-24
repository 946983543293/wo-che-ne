import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/parking_record.dart';
import '../data/repositories/parking_repository.dart';
import '../services/haptic_service.dart';
import '../services/location_service.dart';
import 'providers.dart';

/// 停车记录控制器（架构 §3.2 `ParkingController`）。
///
/// 状态 = 全部记录的当前快照（[loadAll] 顺序）；写操作后统一 `refresh()`，
/// 保证首页双状态、历史页共享同一份数据。淘汰由仓储层
/// `JsonParkingRepository._evictIfNeeded` 负责（架构 §3.1）。
class ParkingController extends AsyncNotifier<List<ParkingRecord>> {
  ParkingRepository get _repo => ref.read(parkingRepositoryProvider);
  HapticService get _haptic => ref.read(hapticServiceProvider);

  @override
  Future<List<ParkingRecord>> build() => _repo.loadAll();

  /// 从仓储重新拉取全部记录。
  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.loadAll);
  }

  /// 保存一条新记录，并触发「记录完成」震动反馈（读设置开关，失败静默）。
  ///
  /// [id] 由调用方生成（拍照页需在写照片文件前就确定记录 id，以便命名
  /// `photos/{id}_{n}.jpg`）。[fix] 为 null 表示定位失败降级：坐标落哨兵
  /// [ParkingRecord.unknownCoordinate]，地点名优先取 [manualPlaceName]。
  ///
  /// 说明：本方法**不**对照片数量做静默截断——3 张上限由采集侧（拍照页
  /// `_capture()`）把关，控制器只负责原子持久化，保持「所见即所存」。
  /// 这与 QA 的 `t03_parking_controller_test.dart` 约定一致。
  Future<ParkingRecord> saveNewRecord({
    required String id,
    PositionFix? fix,
    required List<String> photoPaths,
    String? manualPlaceName,
  }) async {
    final ParkingRecord record = ParkingRecord(
      id: id,
      latitude: fix?.latitude ?? ParkingRecord.unknownCoordinate,
      longitude: fix?.longitude ?? ParkingRecord.unknownCoordinate,
      poiName: _resolvePlaceName(fix, manualPlaceName),
      accuracy: fix?.accuracy,
      photoPaths: photoPaths,
      createdAt: DateTime.now(),
      archived: false,
    );
    final ParkingRecord saved = await _repo.save(record);
    await _haptic.recordSaved();
    await refresh();
    return saved;
  }

  /// 归档一条记录（找车完成）：首页随之切回停车态。
  Future<void> archive(String id) async {
    final List<ParkingRecord> list = state.valueOrNull ?? await _repo.loadAll();
    final int index = list.indexWhere((ParkingRecord r) => r.id == id);
    if (index < 0) {
      return;
    }
    await _repo.update(list[index].copyWith(archived: true));
    await refresh();
  }

  /// 删除一条记录（连照片文件一起删，由仓储层级联）。
  Future<void> remove(String id) async {
    await _repo.delete(id);
    await refresh();
  }

  /// 地点名解析：手动输入 > 高德 POI；都没有则返回 null（UI 显示「未知地点」）。
  static String? _resolvePlaceName(PositionFix? fix, String? manualPlaceName) {
    final String? manual = manualPlaceName?.trim();
    if (manual != null && manual.isNotEmpty) {
      return manual;
    }
    final String? poi = fix?.poiName?.trim();
    if (poi != null && poi.isNotEmpty) {
      return poi;
    }
    return null;
  }
}
