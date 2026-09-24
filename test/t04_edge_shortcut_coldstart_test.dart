// T04 QA 独立验证 —— 边界补测（三）：P1-2 桌面快捷方式冷启动集成路径。
//
// 打击点（现有 t04_shortcut_service_test 只测了服务层，未测「接进 App」）：
//   · 未同意隐私政策时冷启动「一键记车位」→ 仍先弹同意门，不绕过合规、不直达记录页
//   · 已同意时冷启动「一键记车位」→ 直达记录流程，且**跳过/不残留**第 1 步引导
//   · 隐私同意门只弹一次（不重复）

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/core/constants.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/services/shortcut_service.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeParkingRepository parking;
  late Directory root;

  setUp(() {
    installPermissionMock();
    settings = FakeSettingsRepository(
      AppSettings(privacyAgreed: true, guideDisabled: false),
    );
    parking = FakeParkingRepository();
    root = Directory.systemTemp.createTempSync('t04_shortcut_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// 安装快捷方式通道 mock：冷启动 getLaunchAction 返回「一键记车位」intent action。
  void installShortcutColdStart() {
    const MethodChannel channel =
        MethodChannel(AppConstants.shortcutChannelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getLaunchAction') {
        return AppConstants.shortcutIntentAction;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  Widget buildAppWithShortcut() => ProviderScope(
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(settings),
          parkingRepositoryProvider.overrideWithValue(parking),
          amapSdkGateProvider.overrideWithValue(
            AmapSdkGate(settings: settings, initializer: () async {}),
          ),
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
          hapticServiceProvider.overrideWithValue(SilentHapticService()),
          shortcutServiceProvider.overrideWithValue(
            ShortcutService(
              channelOverride: const MethodChannel(
                AppConstants.shortcutChannelName,
              ),
            ),
          ),
        ],
        child: const WoCheNeApp(),
      );

  /// 反复点击权限说明框里的「暂不」，直到不再出现。
  ///
  /// 直达记录流程会**连续**弹出两个说明框：先「需要定位权限」（首页），
  /// 再「需要相机权限」（拍照页）。只关第一个会卡在相机说明框上，
  /// 永远到不了「未获得相机权限」的降级态。
  Future<void> declineRationales(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      if (find.text('暂不').evaluate().isEmpty) {
        return;
      }
      await tester.tap(find.text('暂不'));
      await pumpFrames(tester, 15);
    }
  }

  testWidgets('TC-EDGE-8 未同意隐私：快捷方式冷启动仍先弹同意门，不直达记录页',
      (WidgetTester tester) async {
    settings.current = AppSettings(privacyAgreed: false);
    installShortcutColdStart();

    await tester.pumpWidget(buildAppWithShortcut());
    await pumpFrames(tester, 15);

    // 合规红线：未同意 → 同意框出现，且**只有一次**（不重复弹）。
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('暂不同意'), findsOneWidget);
    // 未被快捷方式绕过到拍照页。
    expect(find.text('未获得相机权限'), findsNothing);
    expect(find.text('不拍了，直接记'), findsNothing);
  });

  testWidgets('TC-EDGE-9 已同意：快捷方式冷启动直达记录流程且不残留第 1 步引导',
      (WidgetTester tester) async {
    // 引导开启（guideDisabled=false）：正常进入首页本会弹第 1 步引导，
    // 快捷方式应「直达记录流程」并跳过引导。
    settings.current = AppSettings(privacyAgreed: true, guideDisabled: false);
    installShortcutColdStart();

    await tester.pumpWidget(buildAppWithShortcut());
    await pumpFrames(tester, 15);
    await declineRationales(tester);
    await pumpFrames(tester, 15);

    // 直达拍照页（权限被拒 → 降级文案）。
    expect(find.text('未获得相机权限'), findsOneWidget,
        reason: '快捷方式应直达记录流程（拍照页）');
    // 不残留引导遮罩。
    expect(find.text('点这里，位置自动记'), findsNothing,
        reason: '快捷方式直达应跳过第 1 步引导，不残留气泡');
    // 合规门不再出现（已同意）。
    expect(find.text('同意并继续'), findsNothing);
  });
}
