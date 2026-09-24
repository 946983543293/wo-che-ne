// T04 —— 历史记录页 + 记录详情页（PRD §4.5）。
//
// 本文件刻意通过**真实 App**（`WoCheNeApp` + 真实路由表）进入历史页，
// 以便同时覆盖 `/history` 与 `/record-detail` 两条命名路由的接线。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeParkingRepository parking;
  late Directory root;

  setUp(() {
    installPermissionMock();
    settings = FakeSettingsRepository(
      AppSettings(privacyAgreed: true, guideDisabled: true),
    );
    parking = FakeParkingRepository();
    root = Directory.systemTemp.createTempSync('t04_history_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// 启动真实 App，从首页 AppBar 进入历史记录页。
  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(settings: settings, parking: parking, root: root),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-HIS-1 空态：无记录时显示引导文案', (WidgetTester tester) async {
    await pumpHistory(tester);
    expect(find.textContaining('还没有停车记录'), findsOneWidget);
  });

  testWidgets('TC-HIS-2 倒序：新记录在上、旧记录在下', (WidgetTester tester) async {
    parking.records
      ..add(buildRecord(
        id: 'old',
        poiName: '旧车棚',
        createdAt: DateTime(2026, 9, 1, 8),
      ))
      ..add(buildRecord(
        id: 'new',
        poiName: '新车棚',
        createdAt: DateTime(2026, 9, 20, 9),
      ));
    await pumpHistory(tester);

    expect(find.text('新车棚'), findsOneWidget);
    expect(find.text('旧车棚'), findsOneWidget);
    expect(
      tester.getCenter(find.text('新车棚')).dy <
          tester.getCenter(find.text('旧车棚')).dy,
      isTrue,
      reason: '历史列表应按创建时间倒序（新的在上）',
    );
  });

  testWidgets('TC-HIS-3 点行进入详情页（只读信息卡）', (WidgetTester tester) async {
    parking.records.add(buildRecord(
      id: 'r1',
      poiName: '紫荆园东侧',
      accuracy: 8,
      createdAt: DateTime(2026, 9, 23, 12, 24),
    ));
    await pumpHistory(tester);

    await tester.tap(find.text('紫荆园东侧'));
    await tester.pumpAndSettle();

    expect(find.text('记录详情'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('未归档（找车中）'), findsOneWidget);
    expect(find.textContaining('照片只存在手机私有目录'), findsOneWidget);
  });

  testWidgets('TC-HIS-4 详情页删除：二次确认后级联删除记录并返回空态',
      (WidgetTester tester) async {
    parking.records.add(buildRecord(
      id: 'r2',
      poiName: '图书馆北',
      createdAt: DateTime(2026, 9, 23, 13),
    ));
    await pumpHistory(tester);

    await tester.tap(find.text('图书馆北'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除记录'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条记录？'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(parking.deletedIds, contains('r2'));
    expect(find.textContaining('还没有停车记录'), findsOneWidget);
  });
}
