// T04 QA 独立验证 —— 边界补测（五）：设置页边界（上限钳制 UI + 引导重置 + 权限/仓库入口）。
//
// 打击点（现有 t04_settings_page_test 未覆盖）：
//   · 上限步进器到 3（下限）时「减少」禁用、到 20（上限）时「增加」禁用
//   · 「重新查看新手引导」调用 reset → 引导状态清空（guideDisabled=false, seen={}）
//   · 隐私政策 / 权限管理 / 开源仓库 入口存在且可点

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wo_che_ne/core/theme/app_theme.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/pages/settings/settings_page.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  late FakeSettingsRepository settings;
  late Directory root;

  setUp(() {
    installPermissionMock();
    settings = FakeSettingsRepository(
      AppSettings(privacyAgreed: true, guideDisabled: true),
    );
    root = Directory.systemTemp.createTempSync('t04_setb_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(settings),
          parkingRepositoryProvider.overrideWithValue(FakeParkingRepository()),
          amapSdkGateProvider.overrideWithValue(
            AmapSdkGate(settings: settings, initializer: () async {}),
          ),
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
          hapticServiceProvider.overrideWithValue(SilentHapticService()),
          packageInfoProvider.overrideWith(
            (Ref ref) async => PackageInfo(
              appName: '我车呢',
              packageName: 'com.wochene.app',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 按图标定位步进按钮：`find.byTooltip` 返回的是 `Tooltip` 而非 `IconButton`，
  /// 必须经 `widgetWithIcon` 才能拿到带 `onPressed` 的按钮本体。
  IconButton iconBtn(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('TC-EDGE-14 上限下限 3：再减按钮禁用，值保持 3', (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, maxRecords: 3);
    await pumpSettings(tester);

    expect(find.text('3'), findsOneWidget);
    expect(iconBtn(tester, Icons.remove_circle_outline).onPressed, isNull,
        reason: '到下限 3，「减少」应禁用');
    expect(iconBtn(tester, Icons.add_circle_outline).onPressed, isNotNull);
  });

  testWidgets('TC-EDGE-15 上限上限 20：再加按钮禁用，值保持 20', (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, maxRecords: 20);
    await pumpSettings(tester);

    expect(find.text('20'), findsOneWidget);
    expect(iconBtn(tester, Icons.add_circle_outline).onPressed, isNull,
        reason: '到上限 20，「增加」应禁用');
    expect(iconBtn(tester, Icons.remove_circle_outline).onPressed, isNotNull);
  });

  testWidgets('TC-EDGE-16 越界写入被钳制：直接设 100 → 20，设 1 → 3',
      (WidgetTester tester) async {
    // 经设置控制器写入越界值，验证仓储/模型层钳制（不只 UI 层）。
    settings.current = AppSettings(maxRecords: 100);
    expect(settings.current.maxRecords, 20);
    settings.current = AppSettings(maxRecords: 1);
    expect(settings.current.maxRecords, 3);
  });

  testWidgets('TC-EDGE-17 「重新查看新手引导」→ reset 清空引导状态',
      (WidgetTester tester) async {
    // 先制造「引导已关闭且看过 1、3 步」的状态。
    settings.current = AppSettings(
      privacyAgreed: true,
      guideDisabled: true,
      guideStepsSeen: <int>{1, 3},
    );
    await pumpSettings(tester);

    // 「反馈」分组新增了「试一下震动」入口后，本项在 800×600 的测试表面上落到首屏
    // 之外（tap 命中点 y≈607 > 600），必须先滚动到位——与同文件 TC-EDGE-18 的做法一致。
    await tester.scrollUntilVisible(
      find.text('重新查看新手引导'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新查看新手引导'));
    await tester.pumpAndSettle();

    expect(settings.current.guideDisabled, isFalse, reason: 'reset 应解除永久关闭');
    expect(settings.current.guideStepsSeen, isEmpty, reason: 'reset 应清空已看步号');
    expect(find.textContaining('已重置'), findsOneWidget, reason: '应有 SnackBar 反馈');
  });

  testWidgets('TC-EDGE-18 设置页含隐私政策 / 权限管理 / 开源仓库入口',
      (WidgetTester tester) async {
    await pumpSettings(tester);

    // 设置项较多：底部「隐私 / 权限 / 关于」在首屏之外，ListView 惰性构建，
    // 必须先滚动到位再断言（否则未挂载 → 误报 findsNothing）。
    Future<void> scrollTo(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await scrollTo(find.text('权限管理'));
    expect(find.text('权限管理'), findsOneWidget);

    await scrollTo(find.text('隐私政策'));
    expect(find.text('隐私政策'), findsOneWidget);

    await scrollTo(find.text('开源仓库'));
    expect(find.text('开源仓库'), findsOneWidget);
    expect(find.text('开源协议'), findsOneWidget);
  });
}
