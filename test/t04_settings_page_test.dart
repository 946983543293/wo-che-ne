// T04 —— 设置页（PRD §4.7）：记录上限 / 深色模式(P1-3) / 震动反馈 / 关于。

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
    root = Directory.systemTemp.createTempSync('t04_settings_');
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
          // 关于页版本号：注入固定包信息，避开平台通道。
          packageInfoProvider.overrideWith(
            (Ref ref) async => PackageInfo(
              appName: '我车呢',
              packageName: 'com.wochene.app',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 滚动设置列表直到 [finder] 可见（设置项较多，底部「关于」在首屏之外）。
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-SET-1 记录上限步进器：加/减写回设置仓储', (WidgetTester tester) async {
    await pumpSettings(tester);
    expect(find.text('历史记录保存条数'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.byTooltip('增加'));
    await tester.pumpAndSettle();
    expect(settings.current.maxRecords, 11);
    expect(find.text('11'), findsOneWidget);

    await tester.tap(find.byTooltip('减少'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('减少'));
    await tester.pumpAndSettle();
    expect(settings.current.maxRecords, 9);
  });

  testWidgets('TC-SET-2 深色模式（P1-3）：选「深色」写回 themeMode', (WidgetTester tester) async {
    await pumpSettings(tester);
    expect(settings.current.themeMode, ThemeModePref.system);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(settings.current.themeMode, ThemeModePref.dark);
  });

  testWidgets('TC-SET-3 震动反馈开关：切换写回 hapticEnabled', (WidgetTester tester) async {
    await pumpSettings(tester);
    expect(settings.current.hapticEnabled, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(settings.current.hapticEnabled, isFalse);
  });

  testWidgets('TC-SET-4 关于：展示版本号与开源协议', (WidgetTester tester) async {
    await pumpSettings(tester);
    await scrollTo(tester, find.text('1.0.0 (1)'));

    expect(find.text('1.0.0 (1)'), findsOneWidget);
    expect(find.text('MIT'), findsOneWidget);
  });

  testWidgets('TC-SET-5 隐私政策：从设置页可进入全文', (WidgetTester tester) async {
    await pumpSettings(tester);
    await scrollTo(tester, find.text('隐私政策'));

    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.textContaining('不收集、不上传、不分享'), findsOneWidget);
  });
}
