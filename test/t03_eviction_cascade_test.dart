// T03 QA 独立验证 —— 历史记录上限与淘汰（真实文件系统级联校验）。
//
// 验收点 6：3–20 条约束、默认 10；超限先淘汰「已归档中最早」，照片文件级联删除。
// 与 T02 的 mock 版单测互补：这里用真实 LocalStore + 临时目录，验证照片「文件」确实被删。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/repositories/parking_repository.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';

import 'support/fakes.dart';

void main() {
  late Directory root;
  late LocalStore store;
  late FakeSettingsRepository settings;
  late JsonParkingRepository repo;

  setUp(() {
    root = Directory.systemTemp.createTempSync('t03_evict_');
    store = LocalStore(rootOverride: root);
    settings = FakeSettingsRepository(AppSettings(maxRecords: 3));
    repo = JsonParkingRepository(store: store, settings: settings);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  File photo(String name) => File('${root.path}/photos/$name');

  /// 写入 [id] 的一张真实照片文件（photos/{id}_0.jpg）。
  Future<void> seedPhoto(String id) async {
    await store.savePhoto(id, 0, <int>[0xFF, 0xD8, 0xFF, 0xE0]);
  }

  test('TC-06-1 超上限优先淘汰「已归档中最早」，并级联删除其照片文件', () async {
    for (final String id in <String>['a', 'b', 'c']) {
      await seedPhoto(id);
    }

    await repo.save(buildRecord(
      id: 'a',
      createdAt: DateTime(2026, 9, 1),
      archived: true,
      photos: <String>['photos/a_0.jpg'],
    ));
    await repo.save(buildRecord(
      id: 'b',
      createdAt: DateTime(2026, 9, 2),
      photos: <String>['photos/b_0.jpg'],
    ));
    await repo.save(buildRecord(
      id: 'c',
      createdAt: DateTime(2026, 9, 3),
      photos: <String>['photos/c_0.jpg'],
    ));
    expect(photo('a_0.jpg').existsSync(), isTrue);

    // 第 4 条触发淘汰。
    await repo.save(buildRecord(
      id: 'd',
      createdAt: DateTime(2026, 9, 4),
      photos: <String>['photos/d_0.jpg'],
    ));

    final Set<String> ids =
        (await repo.loadAll()).map((ParkingRecord r) => r.id).toSet();
    expect(ids, <String>{'b', 'c', 'd'});
    expect(photo('a_0.jpg').existsSync(), isFalse,
        reason: '被淘汰记录的照片文件必须被删除');
    expect(photo('b_0.jpg').existsSync(), isTrue);
    expect(photo('c_0.jpg').existsSync(), isTrue);
  });

  test('TC-06-2 无已归档记录时：淘汰最早的记录（含未归档）', () async {
    for (final String id in <String>['a', 'b', 'c']) {
      await seedPhoto(id);
    }
    await repo.save(buildRecord(
        id: 'a', createdAt: DateTime(2026, 9, 1), photos: <String>['photos/a_0.jpg']));
    await repo.save(buildRecord(
        id: 'b', createdAt: DateTime(2026, 9, 2), photos: <String>['photos/b_0.jpg']));
    await repo.save(buildRecord(
        id: 'c', createdAt: DateTime(2026, 9, 3), photos: <String>['photos/c_0.jpg']));

    await repo.save(buildRecord(
        id: 'd', createdAt: DateTime(2026, 9, 4), photos: <String>['photos/d_0.jpg']));

    final Set<String> ids =
        (await repo.loadAll()).map((ParkingRecord r) => r.id).toSet();
    expect(ids, <String>{'b', 'c', 'd'});
    expect(photo('a_0.jpg').existsSync(), isFalse);
  });

  test('TC-06-3 未超上限不淘汰（默认上限 10 下 3 条保留）', () async {
    settings.current = AppSettings(); // 默认 10
    for (final String id in <String>['a', 'b', 'c']) {
      await repo.save(buildRecord(id: id, createdAt: DateTime(2026, 9, 1)));
    }
    expect((await repo.loadAll()).length, 3);
  });

  test('TC-06-4 上限动态调小后，下一次保存立即收敛到新上限', () async {
    settings.current = AppSettings(maxRecords: 20);
    for (int i = 0; i < 5; i++) {
      await repo.save(buildRecord(id: 'r$i', createdAt: DateTime(2026, 9, 1 + i)));
    }
    expect((await repo.loadAll()).length, 5);

    settings.current = AppSettings(maxRecords: 3);
    await repo.save(buildRecord(id: 'r5', createdAt: DateTime(2026, 9, 10)));

    final List<ParkingRecord> all = await repo.loadAll();
    expect(all.length, 3);
    final Set<String> ids = all.map((ParkingRecord r) => r.id).toSet();
    expect(ids, <String>{'r3', 'r4', 'r5'});
  });

  test('TC-06-5 delete 连带删除该记录的照片文件', () async {
    await seedPhoto('x');
    await repo.save(buildRecord(
        id: 'x', createdAt: DateTime(2026, 9, 1), photos: <String>['photos/x_0.jpg']));
    expect(photo('x_0.jpg').existsSync(), isTrue);

    await repo.delete('x');

    expect(photo('x_0.jpg').existsSync(), isFalse);
    expect(await repo.loadAll(), isEmpty);
  });

  test('TC-06-6 上限钳制：设置 1 → 3，设置 100 → 20', () async {
    settings.current = AppSettings(maxRecords: 1);
    expect(settings.current.maxRecords, 3);
    settings.current = AppSettings(maxRecords: 100);
    expect(settings.current.maxRecords, 20);
  });
}
