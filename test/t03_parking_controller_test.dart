// T03 QA 独立验证 —— 停车记录控制器（saveNewRecord / archive / remove / 派生状态）。
//
// 覆盖验收点 2（0–3 张照片保存自由度）、验收点 6（归档后回停车态）、
// 验收点 7（定位失败降级：坐标哨兵 + 手动地点优先）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/services/location_service.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'support/fakes.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeParkingRepository repo;
  late SilentHapticService haptic;

  setUp(() {
    settings = FakeSettingsRepository(AppSettings(maxRecords: 10));
    repo = FakeParkingRepository();
    haptic = SilentHapticService();
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(settings),
        parkingRepositoryProvider.overrideWithValue(repo),
        hapticServiceProvider.overrideWithValue(haptic),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> boot() async {
    final ProviderContainer container = makeContainer();
    await container.read(parkingControllerProvider.future);
    return container;
  }

  group('saveNewRecord：照片数量自由度（0–3 张）', () {
    for (final int n in <int>[0, 1, 2, 3]) {
      test('$n 张照片均可保存，顺序与数量原样落库', () async {
        final ProviderContainer c = await boot();
        final List<String> photos =
            List<String>.generate(n, (int i) => 'photos/rec_$i.jpg');

        final ParkingRecord saved = await c
            .read(parkingControllerProvider.notifier)
            .saveNewRecord(
              id: 'rec',
              fix: const PositionFix(
                latitude: 39.999,
                longitude: 116.326,
                accuracy: 6,
                poiName: '清华·紫荆园',
              ),
              photoPaths: photos,
            );

        expect(saved.photoPaths.length, n);
        expect(saved.photoPaths, photos);
        expect(repo.savedRecords.single.photoPaths.length, n);
      });
    }

    test('4 张超上限仍被写库（上限由 UI/采集侧把关，仓储不静默截断）', () async {
      // 记录当前行为：saveNewRecord 不做 3 张截断，护栏在拍照页 _capture()。
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'rec4',
            photoPaths: <String>['a', 'b', 'c', 'd'],
          );
      expect(saved.photoPaths.length, 4);
    });
  });

  group('saveNewRecord：定位失败降级与地点解析', () {
    test('fix 为 null：坐标落哨兵 (0,0)，地点取手动输入', () async {
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'degraded',
            fix: null,
            photoPaths: const <String>[],
            manualPlaceName: '紫荆园东侧',
          );

      expect(saved.latitude, ParkingRecord.unknownCoordinate);
      expect(saved.longitude, ParkingRecord.unknownCoordinate);
      expect(saved.hasLocation, isFalse);
      expect(saved.poiName, '紫荆园东侧');
      expect(saved.accuracy, isNull);
    });

    test('fix 非空且有 POI、无手动输入：地点取 fix.poiName，精度保留', () async {
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'located',
            fix: const PositionFix(
              latitude: 39.99,
              longitude: 116.32,
              accuracy: 25.7,
              poiName: '图书馆北',
            ),
            photoPaths: const <String>[],
          );

      expect(saved.poiName, '图书馆北');
      expect(saved.accuracy, 25.7);
      expect(saved.hasLocation, isTrue);
    });

    test('手动输入优先于 POI（PRD Q6：用户手输 > 逆地理）', () async {
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'manualWin',
            fix: const PositionFix(
              latitude: 39.99,
              longitude: 116.32,
              poiName: '系统地名',
            ),
            photoPaths: const <String>[],
            manualPlaceName: '我停的角落',
          );

      expect(saved.poiName, '我停的角落');
    });

    test('手动输入为空白串：回退到 POI（不写空串）', () async {
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'blankManual',
            fix: const PositionFix(
              latitude: 39.99,
              longitude: 116.32,
              poiName: '系统地名',
            ),
            photoPaths: const <String>[],
            manualPlaceName: '   ',
          );

      expect(saved.poiName, '系统地名');
    });

    test('无 POI 且无手动输入：poiName 为 null', () async {
      final ProviderContainer c = await boot();
      final ParkingRecord saved = await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(
            id: 'noName',
            fix: const PositionFix(latitude: 39.99, longitude: 116.32),
            photoPaths: const <String>[],
          );

      expect(saved.poiName, isNull);
    });
  });

  group('saveNewRecord 副作用 / 派生状态', () {
    test('保存触发一次震动反馈', () async {
      final ProviderContainer c = await boot();
      await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(id: 'h1', photoPaths: const <String>[]);
      expect(haptic.calls, 1);
    });

    test('保存后 latestActiveRecordProvider 变为非 null（切找车态）', () async {
      final ProviderContainer c = await boot();
      expect(c.read(latestActiveRecordProvider).valueOrNull, isNull);

      await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(id: 'x', photoPaths: const <String>[]);

      expect(c.read(latestActiveRecordProvider).valueOrNull?.id, 'x');
    });

    test('archive 后 latestActiveRecordProvider 回到 null（回停车态）', () async {
      final ProviderContainer c = await boot();
      await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(id: 'y', photoPaths: const <String>[]);
      await c.read(parkingControllerProvider.notifier).archive('y');

      expect(c.read(latestActiveRecordProvider).valueOrNull, isNull);
      expect(repo.records.single.archived, isTrue);
    });

    test('archive 未知 id 静默无副作用', () async {
      final ProviderContainer c = await boot();
      await c.read(parkingControllerProvider.notifier).archive('ghost');
      expect(repo.records, isEmpty);
    });

    test('remove 调用仓储删除（含照片级联由仓储负责）', () async {
      final ProviderContainer c = await boot();
      await c
          .read(parkingControllerProvider.notifier)
          .saveNewRecord(id: 'z', photoPaths: const <String>[]);
      await c.read(parkingControllerProvider.notifier).remove('z');

      expect(repo.deletedIds, <String>['z']);
      expect(repo.records, isEmpty);
    });

    test('多条未归档：latestActiveRecordProvider 取 createdAt 最新', () async {
      final ProviderContainer c = await boot();
      repo.records.addAll(<ParkingRecord>[
        buildRecord(id: 'old', createdAt: DateTime(2026, 9, 1, 8)),
        buildRecord(id: 'new', createdAt: DateTime(2026, 9, 3, 8)),
        buildRecord(id: 'mid', createdAt: DateTime(2026, 9, 2, 8)),
      ]);
      await c.read(parkingControllerProvider.notifier).refresh();

      expect(c.read(latestActiveRecordProvider).valueOrNull?.id, 'new');
    });
  });
}
