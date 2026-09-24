import '../models/parking_record.dart';
import '../storage/local_store.dart';
import 'settings_repository.dart';

/// 停车记录仓储接口（架构 §3.2 `ParkingRepository`）。
///
/// 接口隔离：状态层只依赖本接口，将来若换 sqflite 实现，UI/状态层零改动。
abstract interface class ParkingRepository {
  /// 读取全部记录（存储顺序）。
  Future<List<ParkingRecord>> loadAll();

  /// 取最近一条未归档记录（首页找车态卡片用）；没有则返回 null。
  Future<ParkingRecord?> latestActive();

  /// 新增一条记录（自动执行淘汰），返回写入后的记录。
  Future<ParkingRecord> save(ParkingRecord record);

  /// 更新一条已存在的记录（按 id 匹配；未找到则忽略）。
  Future<void> update(ParkingRecord record);

  /// 删除一条记录（连照片文件一起删）。
  Future<void> delete(String id);
}

/// JSON 文件实现的停车记录仓储（架构 §1.4、§3.1 `_evictIfNeeded` 淘汰规则）。
class JsonParkingRepository implements ParkingRepository {
  /// 注入本地存储与设置仓储（设置用于读取淘汰阈值 [AppSettings.maxRecords]）。
  JsonParkingRepository({required this._store, required this._settings});

  final LocalStore _store;
  final SettingsRepository _settings;

  @override
  Future<List<ParkingRecord>> loadAll() async {
    final List<Map<String, dynamic>> raw = await _store.readRecords();
    return raw.map(ParkingRecord.fromJson).toList();
  }

  @override
  Future<ParkingRecord?> latestActive() async {
    final List<ParkingRecord> all = await loadAll();
    ParkingRecord? latest;
    for (final ParkingRecord record in all) {
      if (record.archived) {
        continue;
      }
      if (latest == null || record.createdAt.isAfter(latest.createdAt)) {
        latest = record;
      }
    }
    return latest;
  }

  @override
  Future<ParkingRecord> save(ParkingRecord record) async {
    final List<ParkingRecord> all = await loadAll();
    all.add(record);
    await _evictIfNeeded(all);
    await _persist(all);
    return record;
  }

  @override
  Future<void> update(ParkingRecord record) async {
    final List<ParkingRecord> all = await loadAll();
    final int index = all.indexWhere((ParkingRecord r) => r.id == record.id);
    if (index < 0) {
      return;
    }
    all[index] = record;
    await _persist(all);
  }

  @override
  Future<void> delete(String id) async {
    final List<ParkingRecord> all = await loadAll();
    all.removeWhere((ParkingRecord r) => r.id == id);
    await _persist(all);
    await _store.deletePhotos(id);
  }

  /// 淘汰规则（架构 §3.1）：保存后若总数超过上限，**先删「已归档中最早」**，
  /// 若仍超限（极端情况）则删「最早」记录（含未归档）；被淘汰记录的照片一并删除。
  /// 淘汰静默进行，不打断用户。
  Future<void> _evictIfNeeded(List<ParkingRecord> records) async {
    final int max = (await _settings.load()).maxRecords;
    while (records.length > max) {
      final ParkingRecord victim = _pickVictim(records);
      records.removeWhere((ParkingRecord r) => r.id == victim.id);
      await _store.deletePhotos(victim.id);
    }
  }

  /// 选出本轮应淘汰的记录。
  static ParkingRecord _pickVictim(List<ParkingRecord> records) {
    final List<ParkingRecord> archived = records
        .where((ParkingRecord r) => r.archived)
        .toList()
      ..sort((ParkingRecord a, ParkingRecord b) =>
          a.createdAt.compareTo(b.createdAt));
    if (archived.isNotEmpty) {
      return archived.first;
    }
    final List<ParkingRecord> sorted = List<ParkingRecord>.of(records)
      ..sort((ParkingRecord a, ParkingRecord b) =>
          a.createdAt.compareTo(b.createdAt));
    return sorted.first;
  }

  Future<void> _persist(List<ParkingRecord> records) async {
    await _store.writeRecords(
      records.map((ParkingRecord r) => r.toJson()).toList(),
    );
  }
}
