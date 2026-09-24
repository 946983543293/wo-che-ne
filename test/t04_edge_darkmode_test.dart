// T04 QA 独立验证 —— 边界补测（四）：P1-3 深色模式三态落地 + 对比度可读。
//
// 打击点（现有 TC-SET-2 只验证「选深色写回设置」）：
//   · 设置写入后 **app.dart 的 MaterialApp 真的切到对应 ThemeMode**（否则「点了没反应」）
//   · 深色下 Theme.brightness == dark 且 scaffold 背景为深色令牌
//   · 三态（system/light/dark）逐一映射正确

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/core/theme/app_colors.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
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
    root = Directory.systemTemp.createTempSync('t04_dark_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
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
        ],
        child: const WoCheNeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeMode appThemeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testWidgets('TC-EDGE-10 themeMode=dark：MaterialApp 切到 ThemeMode.dark 且实际亮度为暗',
      (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, themeMode: ThemeModePref.dark);
    await pumpApp(tester);

    expect(appThemeMode(tester), ThemeMode.dark);
    final BuildContext ctx = tester.element(find.text('车停好了？'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    // 深色 scaffold 背景取自令牌 backgroundDark。
    expect(Theme.of(ctx).scaffoldBackgroundColor, AppColors.backgroundDark);
  });

  testWidgets('TC-EDGE-11 themeMode=light：MaterialApp 切到 ThemeMode.light 且亮度为亮',
      (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, themeMode: ThemeModePref.light);
    await pumpApp(tester);

    expect(appThemeMode(tester), ThemeMode.light);
    final BuildContext ctx = tester.element(find.text('车停好了？'));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(Theme.of(ctx).scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('TC-EDGE-12 themeMode=system：MaterialApp 切到 ThemeMode.system',
      (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, themeMode: ThemeModePref.system);
    await pumpApp(tester);
    expect(appThemeMode(tester), ThemeMode.system);
  });

  testWidgets('TC-EDGE-13 深色主题下主文字/背景对比可读（非同一色、非透明）',
      (WidgetTester tester) async {
    settings.current =
        AppSettings(privacyAgreed: true, guideDisabled: true, themeMode: ThemeModePref.dark);
    await pumpApp(tester);

    final BuildContext ctx = tester.element(find.text('车停好了？'));
    final Color bg = Theme.of(ctx).scaffoldBackgroundColor;
    final Color fg = Theme.of(ctx).textTheme.headlineMedium!.color!;

    expect(fg.a, greaterThan(0), reason: '文字不得透明');
    expect(fg, isNot(bg), reason: '文字色不得等于背景色');

    // 相对亮度差应显著（WCAG 相对亮度差 > 0.5 为高对比）。
    double lum(Color c) => c.computeLuminance();
    expect((lum(fg) - lum(bg)).abs(), greaterThan(0.5),
        reason: '深色主题下文字/背景对比度不足，可读性差');
  });
}
