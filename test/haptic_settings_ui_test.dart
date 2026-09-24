// 震动开关的**界面表达**：副标题必须随开关状态切换。
//
// 背景：设置页「试一下震动」是**故意忽略开关**的（便于验证硬件与链路），
// 因此若文案不区分开关状态，就会出现「按钮震了、记录却不震」的错觉。
// 本文件锁定两条分支的文案，防止回归。

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
  late FakeSettingsRepository settingsRepo;
  late Directory root;

  setUp(() {
    installPermissionMock();
    root = Directory.systemTemp.createTempSync('wcn_haptic_ui_');
    settingsRepo = FakeSettingsRepository(
      AppSettings(privacyAgreed: true, guideDisabled: true),
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    SilentHapticService? haptic,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          parkingRepositoryProvider.overrideWithValue(FakeParkingRepository()),
          amapSdkGateProvider.overrideWithValue(
            AmapSdkGate(settings: settingsRepo, initializer: () async {}),
          ),
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
          hapticServiceProvider.overrideWithValue(haptic ?? SilentHapticService()),
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

  /// 滚动到 [finder] 可见（设置项较多，「反馈」分组在首屏之外）。
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HAPTIC-UI-1 开关开启：两个副标题走「开启」分支文案',
      (WidgetTester tester) async {
    settingsRepo.current = AppSettings(
      privacyAgreed: true,
      guideDisabled: true,
      hapticEnabled: true,
    );
    await pumpSettings(tester);

    await scrollTo(tester, find.text('记录保存成功时轻震一下，无需看屏'));
    expect(find.text('记录保存成功时轻震一下，无需看屏'), findsOneWidget);

    await scrollTo(tester, find.text('立刻震一次，验证硬件与链路'));
    expect(find.text('立刻震一次，验证硬件与链路'), findsOneWidget);
    expect(
      find.text('上方开关已关闭 —— 记录时不会震动，此按钮仍可测试硬件'),
      findsNothing,
    );
  });

  testWidgets('HAPTIC-UI-2 开关关闭：两个副标题都切到「关闭」分支文案',
      (WidgetTester tester) async {
    settingsRepo.current = AppSettings(
      privacyAgreed: true,
      guideDisabled: true,
      hapticEnabled: false,
    );
    await pumpSettings(tester);

    await scrollTo(tester, find.text('已关闭：记录完成后不会震动'));
    expect(find.text('已关闭：记录完成后不会震动'), findsOneWidget);

    await scrollTo(
      tester,
      find.text('上方开关已关闭 —— 记录时不会震动，此按钮仍可测试硬件'),
    );
    expect(
      find.text('上方开关已关闭 —— 记录时不会震动，此按钮仍可测试硬件'),
      findsOneWidget,
    );
    expect(find.text('记录保存成功时轻震一下，无需看屏'), findsNothing);
  });

  testWidgets('HAPTIC-UI-3 开关关闭时点「试一下震动」仍调用 preview（忽略开关）',
      (WidgetTester tester) async {
    final SilentHapticService haptic = SilentHapticService();
    settingsRepo.current = AppSettings(
      privacyAgreed: true,
      guideDisabled: true,
      hapticEnabled: false,
    );
    await pumpSettings(tester, haptic: haptic);

    await scrollTo(tester, find.text('试一下震动'));
    await tester.tap(find.text('试一下震动'));
    await tester.pumpAndSettle();

    expect(haptic.calls, 1, reason: 'preview 应忽略开关，照震不误');
  });
}
