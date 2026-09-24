import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/repositories/parking_repository.dart';
import 'package:wo_che_ne/data/repositories/settings_repository.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';

/// LocalStore 的 mocktail mock，用状态化 stub 模拟一份内存文件。
class _MockLocalStore extends Mock implements LocalStore {}

/// 轻量假设置仓储（避免对设置层做过度 mock）。
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this._maxRecords);

  int _maxRecords;

  set maxRecords(int value) => _maxRecords = value;

  @override
  Future<AppSettings> load() async => AppSettings(maxRecords: _maxRecords);

  @override
  Future<void> save(AppSettings settings) async {
    _maxRecords = settings.maxRecords;
  }
}

/// 构造测试用停车记录。
ParkingRecord _record(
  String id,
  DateTime createdAt, {
  bool archived = false,
  List<String>? photos,
  String? poiName,
  double? accuracy,
}) =>
    ParkingRecord(
      id: id,
      latitude: 31.2304,
      longitude: 121.4737,
      poiName: poiName,
      accuracy: accuracy,
      photoPaths: photos,
      createdAt: createdAt,
      archived: archived,
    );

void main() {
  late _MockLocalStore store;
  late _FakeSettingsRepository settings;
  late JsonParkingRepository repository;

  /// 内存中的“文件”内容（原始 JSON 列表）。
  late List<Map<String, dynamic>> disk;

  /// 被删除照片的记录 id 轨迹。
  late List<String> deletedPhotoIds;

  setUpAll(() {
    // mocktail：为 any() 用到的非原始类型注册兜底值。
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  setUp(() {
    disk = <Map<String, dynamic>>[];
    deletedPhotoIds = <String>[];
    store = _MockLocalStore();
    settings = _FakeSettingsRepository(10);

    when(() => store.readRecords()).thenAnswer(
      (_) async => disk
          .map((Map<String, dynamic> e) => Map<String, dynamic>.from(e))
          .toList(),
    );
    when(() => store.writeRecords(any())).thenAnswer((Invocation invocation) async {
      final List<Map<String, dynamic>> written =
          (invocation.positionalArguments.first as List)
              .map((dynamic e) =>
                  Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
      disk = written;
    });
    when(() => store.deletePhotos(any())).thenAnswer((Invocation invocation) async {
      deletedPhotoIds.add(invocation.positionalArguments.first as String);
    });

    repository = JsonParkingRepository(store: store, settings: settings);
  });

  group('JSON 序列化往返', () {
    test('ParkingRecord 全字段往返一致', () {
      final ParkingRecord original = ParkingRecord(
        id: 'r1',
        latitude: 31.2304,
        longitude: 121.4737,
        poiName: '人民广场',
        note: null,
        accuracy: 12.5,
        photoPaths: <String>['photos/r1_0.jpg', 'photos/r1_1.jpg'],
        createdAt: DateTime(2026, 9, 23, 12, 24, 30),
        archived: true,
      );

      final ParkingRecord restored =
          ParkingRecord.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.photoPaths, original.photoPaths);
      expect(restored.createdAt, DateTime(2026, 9, 23, 12, 24, 30));
    });

    test('ParkingRecord 缺省字段可平滑读取', () {
      final ParkingRecord restored = ParkingRecord.fromJson(<String, dynamic>{
        'id': 'r2',
        'latitude': 1,
        'longitude': 2,
        'createdAt': '2026-09-23T00:00:00.000',
      });
      expect(restored.archived, isFalse);
      expect(restored.photoPaths, isEmpty);
      expect(restored.poiName, isNull);
      expect(restored.accuracy, isNull);
    });

    test('AppSettings 全字段往返一致', () {
      final AppSettings original = AppSettings(
        maxRecords: 15,
        themeMode: ThemeModePref.dark,
        hapticEnabled: false,
        guideDisabled: true,
        guideStepsSeen: <int>{1, 3},
        privacyAgreed: true,
        privacyAgreedAt: DateTime(2026, 9, 23, 8, 0, 0),
      );

      final AppSettings restored = AppSettings.fromJson(original.toJson());

      expect(restored, original);
    });

    test('AppSettings maxRecords 被钳制在 3–20', () {
      expect(AppSettings(maxRecords: 100).maxRecords, 20);
      expect(AppSettings(maxRecords: 1).maxRecords, 3);
      expect(AppSettings(maxRecords: 10).maxRecords, 10);
    });
  });

  group('save / loadAll / latestActive', () {
    test('save 持久化且可完整读回', () async {
      final ParkingRecord record =
          _record('r1', DateTime(2026, 9, 23, 12, 0), photos: <String>['photos/r1_0.jpg']);

      final ParkingRecord saved = await repository.save(record);

      expect(saved, record);
      final List<ParkingRecord> all = await repository.loadAll();
      expect(all, <ParkingRecord>[record]);
      verify(() => store.writeRecords(any())).called(1);
    });

    test('latestActive 取最近未归档记录', () async {
      disk = <Map<String, dynamic>>[
        _record('old', DateTime(2026, 9, 1, 8, 0)).toJson(),
        _record('newArchived', DateTime(2026, 9, 2, 8, 0), archived: true).toJson(),
        _record('active', DateTime(2026, 9, 3, 8, 0)).toJson(),
      ];

      final ParkingRecord? latest = await repository.latestActive();
      expect(latest?.id, 'active');
    });

    test('latestActive 无未归档记录时返回 null', () async {
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1), archived: true).toJson(),
      ];
      expect(await repository.latestActive(), isNull);
    });
  });

  group('update / delete', () {
    test('update 按 id 覆盖', () async {
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1)).toJson(),
      ];

      await repository.update(_record('a', DateTime(2026, 9, 1), archived: true));

      final List<ParkingRecord> all = await repository.loadAll();
      expect(all.single.archived, isTrue);
    });

    test('update 未知 id 静默忽略', () async {
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1)).toJson(),
      ];

      await repository.update(_record('ghost', DateTime(2026, 9, 1)));

      expect((await repository.loadAll()).single.id, 'a');
    });

    test('delete 删除记录并连照片一起删', () async {
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1), photos: <String>['photos/a_0.jpg']).toJson(),
        _record('b', DateTime(2026, 9, 2)).toJson(),
      ];

      await repository.delete('a');

      final List<ParkingRecord> all = await repository.loadAll();
      expect(all.map((ParkingRecord r) => r.id), <String>['b']);
      verify(() => store.deletePhotos('a')).called(1);
    });
  });

  group('淘汰策略（_evictIfNeeded）', () {
    test('超上限：优先删「已归档中最早」，保留更早的未归档', () async {
      settings.maxRecords = 3;
      disk = <Map<String, dynamic>>[
        _record('activeOld', DateTime(2026, 9, 1)).toJson(),
        _record('archivedMid', DateTime(2026, 9, 2), archived: true).toJson(),
        _record('activeNew', DateTime(2026, 9, 3)).toJson(),
      ];

      await repository.save(_record('justParked', DateTime(2026, 9, 4)));

      final List<ParkingRecord> all = await repository.loadAll();
      expect(
        all.map((ParkingRecord r) => r.id).toSet(),
        <String>{'activeOld', 'activeNew', 'justParked'},
      );
      // 被淘汰的是已归档的 archivedMid，而非更早的 activeOld。
      expect(deletedPhotoIds, <String>['archivedMid']);
    });

    test('超上限且无已归档：删最早的记录', () async {
      settings.maxRecords = 3;
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1)).toJson(),
        _record('b', DateTime(2026, 9, 2)).toJson(),
        _record('c', DateTime(2026, 9, 3)).toJson(),
      ];

      await repository.save(_record('d', DateTime(2026, 9, 4)));

      final List<ParkingRecord> all = await repository.loadAll();
      expect(
        all.map((ParkingRecord r) => r.id).toSet(),
        <String>{'b', 'c', 'd'},
      );
      expect(deletedPhotoIds, <String>['a']);
    });

    test('极端：删完已归档仍超限，继续删最早的（含未归档）', () async {
      // 注意：AppSettings 会把 maxRecords 钳制到 3–20，故此处用允许的最小值 3；
      // 要触发「删到未归档」，需让保存后总数 - 已归档数 > 上限。
      settings.maxRecords = 3;
      disk = <Map<String, dynamic>>[
        _record('archivedA', DateTime(2026, 9, 1), archived: true).toJson(),
        _record('activeB', DateTime(2026, 9, 2)).toJson(),
        _record('activeC', DateTime(2026, 9, 3)).toJson(),
        _record('activeD', DateTime(2026, 9, 4)).toJson(),
      ];

      await repository.save(_record('activeE', DateTime(2026, 9, 5)));

      final List<ParkingRecord> all = await repository.loadAll();
      expect(
        all.map((ParkingRecord r) => r.id).toSet(),
        <String>{'activeC', 'activeD', 'activeE'},
      );
      expect(deletedPhotoIds, <String>['archivedA', 'activeB']);
    });

    test('未超上限时不淘汰', () async {
      settings.maxRecords = 10;
      disk = <Map<String, dynamic>>[
        _record('a', DateTime(2026, 9, 1)).toJson(),
      ];

      await repository.save(_record('b', DateTime(2026, 9, 2)));

      expect((await repository.loadAll()).length, 2);
      expect(deletedPhotoIds, isEmpty);
    });
  });
}
