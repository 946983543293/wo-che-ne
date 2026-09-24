// T04 QA 独立验证 —— 边界补测（二）：maxRecords 3/20 边界 + 真实文件级联删除。
//
// 打击点（现有用例未覆盖）：
//   · maxRecords 取最小 3 / 最大 20 两个边界时的淘汰数量与级联删除（真实磁盘文件）
//   · 淘汰后「剩余记录集合」正确（不是只看数量）
//   · 20 条规模下淘汰的恰好是最早那条

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
    root = Directory.systemTemp.createTempSync('t04_edge_evict_');
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

  /// 写入一条记录 + 一张真实照片文件。
  Future<void> seed(String id, DateTime createdAt, {bool archived = false}) async {
    await store.savePhoto(id, 0, <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
    await repo.save(buildRecord(
      id: id,
      createdAt: createdAt,
      archived: archived,
      photos: <String>['photos/${id}_0.jpg'],
    ));
  }

  test('TC-EDGE-4 下限 maxRecords=3：第 4 条触发淘汰，且被淘汰记录照片文件真的消失', () async {
    await seed('a', DateTime(2026, 9, 1));
    await seed('b', DateTime(2026, 9, 2));
    await seed('c', DateTime(2026, 9, 3));
    expect(photo('a_0.jpg').existsSync(), isTrue);

    await seed('d', DateTime(2026, 9, 4));

    final Set<String> ids =
        (await repo.loadAll()).map((ParkingRecord r) => r.id).toSet();
    expect(ids, <String>{'b', 'c', 'd'}, reason: '保留最新 3 条，淘汰最早 a');
    expect(photo('a_0.jpg').existsSync(), isFalse, reason: 'a 的照片文件必须被删');
    expect(photo('b_0.jpg').existsSync(), isTrue);
    expect(photo('c_0.jpg').existsSync(), isTrue);
    expect(photo('d_0.jpg').existsSync(), isTrue);
    // 目录内照片数 == 剩余记录数（无孤儿）。
    final int files = Directory('${root.path}/photos')
        .listSync()
        .whereType<File>()
        .length;
    expect(files, 3, reason: '磁盘照片数应等于剩余记录数，无孤儿文件');
  });

  test('TC-EDGE-5 上限 maxRecords=20：满 20 后第 21 条淘汰最早，恰好剩 20', () async {
    settings.current = AppSettings(maxRecords: 20);
    for (int i = 0; i < 20; i++) {
      await seed('r$i', DateTime(2026, 9, 1).add(Duration(days: i)));
    }
    expect((await repo.loadAll()).length, 20);
    expect(photo('r0_0.jpg').existsSync(), isTrue);

    await seed('r20', DateTime(2026, 10, 1));

    final List<ParkingRecord> all = await repo.loadAll();
    expect(all.length, 20, reason: '上限 20，绝不越界');
    final Set<String> ids = all.map((ParkingRecord r) => r.id).toSet();
    expect(ids.contains('r0'), isFalse, reason: '最早 r0 被淘汰');
    expect(ids.contains('r20'), isTrue);
    expect(photo('r0_0.jpg').existsSync(), isFalse);
  });

  test('TC-EDGE-6 下限 3 且含已归档：优先淘汰「已归档中最早」，未归档最新保留', () async {
    await seed('archOld', DateTime(2026, 9, 1), archived: true);
    await seed('active1', DateTime(2026, 9, 2));
    await seed('active2', DateTime(2026, 9, 3));

    await seed('active3', DateTime(2026, 9, 4));

    final Set<String> ids =
        (await repo.loadAll()).map((ParkingRecord r) => r.id).toSet();
    expect(ids, <String>{'active1', 'active2', 'active3'});
    expect(photo('archOld_0.jpg').existsSync(), isFalse);
  });

  test('TC-EDGE-7 delete 记录后照片文件消失，且不误删其他记录照片', () async {
    await seed('keep', DateTime(2026, 9, 1));
    await seed('gone', DateTime(2026, 9, 2));

    await repo.delete('gone');

    expect(photo('gone_0.jpg').existsSync(), isFalse);
    expect(photo('keep_0.jpg').existsSync(), isTrue, reason: '不得误删他人照片');
    expect((await repo.loadAll()).single.id, 'keep');
  });
}
