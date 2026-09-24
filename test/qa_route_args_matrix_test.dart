// QA 独立验证（修复轮）—— 命名路由参数兜底**矩阵**补测。
//
// 工程师已覆盖三条组合：/camera(null)、/map-find(null)、/record-detail(错类型)。
// 这里补齐另外三条组合，并补一条**正向对照**：传对参数时必须真的进目标页，
// 否则「一律兜底」本身就是掩盖功能不可用的假绿。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/core/constants.dart';
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
    root = Directory.systemTemp.createTempSync('wcn_route_qa_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pushRoute(
    WidgetTester tester,
    String route, {
    Object? arguments,
  }) async {
    await tester.pumpWidget(
      buildApp(settings: settings, parking: parking, root: root),
    );
    await pumpFrames(tester, 5);
    final NavigatorState navigator =
        tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed<void>(route, arguments: arguments);
    await pumpFrames(tester, 10);
  }

  testWidgets('QA-ROUTE-1 /camera 参数类型不符（String）→ 兜底页，不抛 cast 异常',
      (WidgetTester tester) async {
    await pushRoute(
      tester,
      AppConstants.routeCamera,
      arguments: 'not-camera-args',
    );

    expect(find.text('记录已失效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-ROUTE-2 /camera 参数类型不符（int）→ 兜底页，不抛 cast 异常',
      (WidgetTester tester) async {
    await pushRoute(tester, AppConstants.routeCamera, arguments: 42);

    expect(find.text('记录已失效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-ROUTE-3 /map-find 参数类型不符（String）→ 兜底页',
      (WidgetTester tester) async {
    await pushRoute(
      tester,
      AppConstants.routeMapFind,
      arguments: 'not-a-record',
    );

    expect(find.text('记录已失效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-ROUTE-4 /record-detail 缺参数（null）→ 兜底页',
      (WidgetTester tester) async {
    await pushRoute(tester, AppConstants.routeRecordDetail);

    expect(find.text('记录已失效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-ROUTE-5 正向对照：/record-detail 传合法 ParkingRecord → 不落兜底页',
      (WidgetTester tester) async {
    await pushRoute(
      tester,
      AppConstants.routeRecordDetail,
      arguments: buildRecord(id: 'r1', poiName: '图书馆北'),
    );

    expect(find.text('记录已失效'), findsNothing,
        reason: '参数合法时必须进真实详情页，不能一律兜底');
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-ROUTE-6 正向对照：/map-find 传合法 ParkingRecord → 不落兜底页',
      (WidgetTester tester) async {
    await pushRoute(
      tester,
      AppConstants.routeMapFind,
      arguments: buildRecord(id: 'r2', poiName: '图书馆北'),
    );

    expect(find.text('记录已失效'), findsNothing,
        reason: '参数合法时必须进真实找车页，不能一律兜底');
    expect(tester.takeException(), isNull);
  });
}
