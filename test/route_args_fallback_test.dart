// Bug 修复补测 —— 命名路由参数兜底（闪退止血）。
//
// 进程被系统回收后重建 / 调用方漏传 arguments 时，`settings.arguments! as X`
// 会抛 cast 异常并冒泡成白屏闪退。这里验证三条带参路由在 arguments 为 null
// 或类型不符时都降级为「记录已失效」占位页，且仍可返回。

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
    root = Directory.systemTemp.createTempSync('wcn_route_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<Finder> mountAndPush(
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
    return find.text('记录已失效');
  }

  testWidgets('ROUTE-1 /camera 缺参数 → 兜底占位页，不抛 cast 异常',
      (WidgetTester tester) async {
    final Finder stub = await mountAndPush(tester, AppConstants.routeCamera);

    expect(stub, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('返回'));
    await pumpFrames(tester, 10);
    expect(find.text('记录已失效'), findsNothing);
  });

  testWidgets('ROUTE-2 /map-find 缺参数 → 兜底占位页，不抛 cast 异常',
      (WidgetTester tester) async {
    final Finder stub = await mountAndPush(tester, AppConstants.routeMapFind);

    expect(stub, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ROUTE-3 /record-detail 参数类型不符 → 兜底占位页',
      (WidgetTester tester) async {
    final Finder stub = await mountAndPush(
      tester,
      AppConstants.routeRecordDetail,
      arguments: 'not-a-record',
    );

    expect(stub, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
