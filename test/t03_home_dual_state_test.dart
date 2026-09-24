// T03 QA 独立验证 —— 首页双状态（停车态 / 找车态）。
//
// 验收点 1（点击步数相关的静止态）、验收点 9（一屏一个主行动点）。
// PRD §4.1 停车态 / §4.3 找车态。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/core/utils/time_utils.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'support/fakes.dart';

void main() {
  late FakeParkingRepository parking;
  late Directory root;

  setUp(() {
    parking = FakeParkingRepository();
    root = Directory.systemTemp.createTempSync('t03_home_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// 启动 App 并停在首页；[guideDisabled] 默认 true 以跳过叠加引导、稳定断言主界面。
  Future<void> pumpHome(
    WidgetTester tester, {
    bool guideDisabled = true,
    AppSettings? settings,
  }) async {
    final FakeSettingsRepository settingsRepo = FakeSettingsRepository(
      settings ??
          AppSettings(privacyAgreed: true, guideDisabled: guideDisabled),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          parkingRepositoryProvider.overrideWithValue(parking),
          amapSdkGateProvider.overrideWithValue(
            AmapSdkGate(settings: settingsRepo, initializer: () async {}),
          ),
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
        ],
        child: const WoCheNeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-01-1 无未归档记录 → 停车态（标题 + 主按钮 + 2 次点击提示）',
      (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.text('车停好了？'), findsOneWidget);
    expect(find.text('记下车位'), findsOneWidget);
    expect(find.text('不拍照也行，2 次点击搞定'), findsOneWidget);
    expect(find.text('找到你的车了吗？'), findsNothing);
  });

  testWidgets('TC-01-2 仅存在已归档记录 → 仍为停车态（归档记录不进找车态）',
      (WidgetTester tester) async {
    parking.records.add(buildRecord(id: 'archived1', archived: true));
    await pumpHome(tester);

    expect(find.text('车停好了？'), findsOneWidget);
    expect(find.text('找到你的车了吗？'), findsNothing);
    // 主按钮可用
    final ElevatedButton btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '记下车位'),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('TC-01-3 存在未归档记录 → 找车态（最近一次记录卡 + 再记一笔）',
      (WidgetTester tester) async {
    final ParkingRecord record = buildRecord(
      id: 'active1',
      createdAt: DateTime(2026, 9, 23, 12, 24),
      poiName: '紫荆园东侧',
      accuracy: 8,
    );
    parking.records.add(record);
    await pumpHome(tester);

    expect(find.text('找到你的车了吗？'), findsOneWidget);
    expect(find.text('最近一次记录'), findsOneWidget);
    expect(find.text('再记一笔'), findsOneWidget);
    expect(find.text('紫荆园东侧'), findsOneWidget);
    // 时间文案与 TimeUtils 契约一致。
    expect(
      find.text(TimeUtils.formatFriendly(record.createdAt)),
      findsOneWidget,
    );
    expect(find.text('车停好了？'), findsNothing);
  });

  testWidgets('TC-01-4 找车态：地点名为空 → 显示「未知地点」占位',
      (WidgetTester tester) async {
    parking.records.add(buildRecord(id: 'nopoi', poiName: null, accuracy: null));
    await pumpHome(tester);

    expect(find.text('未知地点'), findsOneWidget);
  });

  testWidgets('TC-01-5 停车态下整屏仅一个主行动按钮（一屏一个主行动点）',
      (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('记下车位'), findsOneWidget);
  });

  testWidgets('TC-01-6 找车态：主卡可点，点击进入地图找车页', (WidgetTester tester) async {
    parking.records.add(buildRecord(id: 'active2', poiName: '图书馆北'));
    await pumpHome(tester);

    await tester.tap(find.text('最近一次记录'));
    await tester.pumpAndSettle();

    // T04 已交付：路由落地为真实的地图找车页。
    // 本用例的 gate 未初始化（ready=false），页面按合规约定展示令牌化占位，
    // 但顶部信息胶囊与底部主行动按钮始终可见，据此断言「卡片确实可导航」。
    expect(find.text('找到了，归档'), findsOneWidget);
    expect(find.text('地图需在同意隐私政策后显示'), findsOneWidget);
  });
}
