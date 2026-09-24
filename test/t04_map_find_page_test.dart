// T04 —— 找车地图页（PRD §4.4）：合规占位 + 信息胶囊 + 归档流程。

import 'dart:io';

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
    root = Directory.systemTemp.createTempSync('t04_map_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('TC-MAP-1 首页→找车页：合规占位 + 胶囊 + 归档后回停车态',
      (WidgetTester tester) async {
    parking.records.add(buildRecord(
      id: 'active',
      poiName: '图书馆北',
      createdAt: DateTime(2026, 9, 23, 12, 24),
    ));
    await tester.pumpWidget(
      buildApp(settings: settings, parking: parking, root: root),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('最近一次记录'));
    await tester.pumpAndSettle();

    // 合规：gate 未就绪 → 令牌化占位（不白屏、不初始化高德 SDK）。
    expect(find.text('地图需在同意隐私政策后显示'), findsOneWidget);
    // 顶部信息胶囊（定位流未到 → 骨架文案）。
    expect(find.text('正在确定你的位置…'), findsOneWidget);
    // 底部主行动按钮。
    expect(find.text('找到了，归档'), findsOneWidget);

    await tester.tap(find.text('找到了，归档'));
    await tester.pumpAndSettle();

    // 归档落库 + 自动返回首页停车态。
    expect(parking.records.single.archived, isTrue);
    expect(find.text('车停好了？'), findsOneWidget);
  });

  testWidgets('TC-MAP-2 纯照片记录（无坐标）：胶囊退化为「先看照片认车」仍可归档',
      (WidgetTester tester) async {
    parking.records.add(buildRecord(
      id: 'active2',
      poiName: null,
      latitude: 0,
      longitude: 0,
      createdAt: DateTime(2026, 9, 23, 9),
    ));
    await tester.pumpWidget(
      buildApp(settings: settings, parking: parking, root: root),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('最近一次记录'));
    await tester.pumpAndSettle();

    expect(find.text('找到了，归档'), findsOneWidget);
  });
}
