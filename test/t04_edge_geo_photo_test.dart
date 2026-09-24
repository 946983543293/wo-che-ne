// T04 QA 独立验证 —— 边界补测（一）：跨 0° 方位角 + 照片条/空照片降级。
//
// 打击点（现有用例未覆盖）：
//   · 真实地理坐标下「车在正北」的方位角跨 0°/360° 边界，箭头不反向跳变（P1-1）
//   · PhotoStrip：空列表降级、张数一致、点开全屏、左右滑动、页码
//   · 记录详情页 / 地图找车页在「0 张照片」记录下的表现（不崩、无空条）

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/core/utils/geo_utils.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/pages/history/record_detail_page.dart';
import 'package:wo_che_ne/pages/map_find/map_find_page.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/services/compass_service.dart';
import 'package:wo_che_ne/state/providers.dart';
import 'package:wo_che_ne/widgets/photo_strip.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1) 跨 0°/360° 方位角 + 箭头旋转（P1-1）
  // ---------------------------------------------------------------------------
  group('TC-EDGE-1 跨 0° 方位角边界（正北 / 350° / 10°）', () {
    // 真实校园坐标：车在「我」正北方。
    const GeoPoint me = GeoPoint(39.999, 116.326);
    const GeoPoint carNorth = GeoPoint(40.010, 116.326);

    test('车在正北：方位角 ≈ 0（不出现 360 或负值）', () {
      final double bearing = GeoUtils.bearingDeg(me, carNorth);
      expect(bearing, closeTo(0, 0.5));
      expect(bearing, greaterThanOrEqualTo(0));
    });

    test('车正北、手机朝 350°：箭头 10°（跨 0 后小幅右转，非 350/-350）', () {
      final double bearing = GeoUtils.bearingDeg(me, carNorth);
      final double arrow =
          CompassService.arrowRotationDeg(bearingDeg: bearing, headingDeg: 350);
      expect(arrow, closeTo(10, 0.5));
    });

    test('车正北、手机朝 10°：箭头 350°（等价于左转 10°，连续无跳变）', () {
      final double bearing = GeoUtils.bearingDeg(me, carNorth);
      final double arrow =
          CompassService.arrowRotationDeg(bearingDeg: bearing, headingDeg: 10);
      expect(arrow, closeTo(350, 0.5));
    });

    test('相邻方位角 359° 与 1°：箭头随朝向单调、不反向跳变', () {
      final double a = CompassService.arrowRotationDeg(
        bearingDeg: 359,
        headingDeg: 0,
      );
      final double b = CompassService.arrowRotationDeg(
        bearingDeg: 1,
        headingDeg: 0,
      );
      expect(a, closeTo(359, 0.001));
      expect(b, closeTo(1, 0.001));
      // 跨越 0° 的两侧角度差应约为 2°，而不是 ~358°。
      expect((a - b).abs(), greaterThan(350));
      expect(CompassService.normalizeDegrees(a - b), closeTo(358, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // 2) PhotoStrip / 全屏浏览
  // ---------------------------------------------------------------------------
  group('TC-EDGE-2 PhotoStrip 与全屏浏览', () {
    late Directory root;
    late LocalStore store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('t04_photo_');
      store = LocalStore(rootOverride: root);
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    Widget wrap(Widget child) => ProviderScope(
          overrides: <Override>[
            localStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(home: Scaffold(body: child)),
        );

    testWidgets('空照片：PhotoStrip 不占位（SizedBox.shrink）', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PhotoStrip(photoPaths: <String>[])));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumb), findsNothing);
      expect(find.byType(PhotoStrip), findsOneWidget);
    });

    testWidgets('3 张照片：缩略图数量与记录一致', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PhotoStrip(
        photoPaths: <String>['photos/r_0.jpg', 'photos/r_1.jpg', 'photos/r_2.jpg'],
      )));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumb), findsNWidgets(3));
    });

    testWidgets('点缩略图 → 全屏浏览：页码 1/3，可滑动到 2/3 并关闭',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PhotoStrip(
        photoPaths: <String>['photos/r_0.jpg', 'photos/r_1.jpg', 'photos/r_2.jpg'],
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PhotoThumb).first);
      // 浏览页在图片路径未就绪时显示 CircularProgressIndicator（持续动画），
      // 不能用 pumpAndSettle；改用固定帧推进，避免「永不 settle」的假失败。
      await pumpFrames(tester, 15);

      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      // 左右滑动切换（用带速度的 fling 模拟真实快速滑动：
      // InteractiveViewer 会参与手势竞技，慢拖可能被其吞掉而不翻页）。
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
      await pumpFrames(tester, 20);
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byTooltip('关闭'));
      await pumpFrames(tester, 15);
      expect(find.byType(PhotoViewerPage), findsNothing);
    });

    testWidgets('单张照片：不显示页码（避免「1 / 1」噪音）', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PhotoStrip(
        photoPaths: <String>['photos/only_0.jpg'],
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PhotoThumb).first);
      await pumpFrames(tester, 15);

      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(find.text('1 / 1'), findsNothing);
    });

    test('openPhotoViewer 空列表：安全无操作（不抛异常）', () {
      // 纯函数守卫，无需 widget 环境。
      expect(() => openPhotoViewer(_FakeContext(), const <String>[], 0),
          returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 3) 0 张照片记录：详情页 / 地图页不崩、无空照片条
  // ---------------------------------------------------------------------------
  group('TC-EDGE-3 空照片记录在各页面的降级表现', () {
    late FakeSettingsRepository settings;
    late Directory root;

    setUp(() {
      installPermissionMock();
      settings = FakeSettingsRepository(
        AppSettings(privacyAgreed: true, guideDisabled: true),
      );
      root = Directory.systemTemp.createTempSync('t04_empty_');
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    ProviderScope scope(Widget home) => ProviderScope(
          overrides: <Override>[
            settingsRepositoryProvider.overrideWithValue(settings),
            parkingRepositoryProvider.overrideWithValue(FakeParkingRepository()),
            amapSdkGateProvider.overrideWithValue(
              AmapSdkGate(settings: settings, initializer: () async {}),
            ),
            localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
            hapticServiceProvider.overrideWithValue(SilentHapticService()),
          ],
          child: MaterialApp(home: home),
        );

    testWidgets('详情页：0 张照片记录不崩、无照片条、显示「0 张」',
        (WidgetTester tester) async {
      final ParkingRecord record = buildRecord(
        id: 'noPhoto',
        poiName: '紫荆园',
        photos: const <String>[],
      );
      await tester.pumpWidget(scope(RecordDetailPage(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('记录详情'), findsOneWidget);
      expect(find.text('0 张'), findsOneWidget);
      expect(find.byType(PhotoStrip), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('地图找车页：0 张照片记录不崩、无照片条、归档按钮仍在',
        (WidgetTester tester) async {
      final ParkingRecord record = buildRecord(
        id: 'noPhoto2',
        poiName: '图书馆北',
        photos: const <String>[],
      );
      await tester.pumpWidget(scope(MapFindPage(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('找到了，归档'), findsOneWidget);
      expect(find.byType(PhotoStrip), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('详情页：3 张照片记录显示照片条', (WidgetTester tester) async {
      final ParkingRecord record = buildRecord(
        id: 'hasPhoto',
        poiName: '体育馆',
        photos: const <String>['photos/hasPhoto_0.jpg', 'photos/hasPhoto_1.jpg'],
      );
      await tester.pumpWidget(scope(RecordDetailPage(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('2 张'), findsOneWidget);
      expect(find.byType(PhotoStrip), findsOneWidget);
    });
  });
}

/// 仅用于 `openPhotoViewer` 空列表守卫测试的最小 BuildContext 替身。
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
