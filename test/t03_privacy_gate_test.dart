// T03 QA 独立验证 —— 隐私同意门（合规红线）。
//
// 验收点 4：首次启动弹门；「暂不同意」→ 降级模式；「同意」→ agreeAndInit() 且写同意状态；
// 同意前不得初始化高德 SDK。验收点 8：打开 APP 不弹权限（仅按需申请）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeParkingRepository parking;
  late AmapInitializerSpy spy;
  late AmapSdkGate gate;
  late Directory root;

  setUp(() {
    installPermissionMock();
    settings = FakeSettingsRepository(AppSettings());
    parking = FakeParkingRepository();
    spy = AmapInitializerSpy();
    gate = AmapSdkGate(settings: settings, initializer: spy.call);
    root = Directory.systemTemp.createTempSync('t03_privacy_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Widget rig() => ProviderScope(
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(settings),
          parkingRepositoryProvider.overrideWithValue(parking),
          amapSdkGateProvider.overrideWithValue(gate),
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
          hapticServiceProvider.overrideWithValue(SilentHapticService()),
        ],
        child: const WoCheNeApp(),
      );

  testWidgets('TC-04-1 首启未同意：弹出隐私同意框，且同意前高德 SDK 未初始化',
      (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('暂不同意'), findsOneWidget);
    expect(find.text('查看《隐私政策》全文'), findsOneWidget);
    // 合规红线：此时不得有任何高德 SDK 初始化动作。
    expect(spy.calls, 0, reason: '同意前不得初始化高德 SDK（合规红线）');
    expect(gate.ready, isFalse);
    expect(settings.current.privacyAgreed, isFalse);
  });

  testWidgets('TC-04-2 点「同意并继续」：写同意状态 + agreeAndInit + 进入停车态',
      (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    expect(settings.current.privacyAgreed, isTrue, reason: '同意状态必须落库');
    expect(settings.current.privacyAgreedAt, isNotNull, reason: '应记录同意时间');
    expect(spy.calls, 1, reason: '同意后应调用 agreeAndInit() 初始化 SDK');
    expect(gate.ready, isTrue);
    expect(find.text('车停好了？'), findsOneWidget);
    expect(find.text('记下车位'), findsOneWidget);
  });

  testWidgets('TC-04-3 点「暂不同意」：进入降级模式（主按钮禁用 + 降级提示）',
      (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();

    expect(find.text('定位与地图暂不可用'), findsOneWidget);
    expect(find.text('同意隐私政策并开始使用'), findsOneWidget);

    final ElevatedButton recordButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '记下车位'),
    );
    expect(recordButton.onPressed, isNull, reason: '降级模式下主按钮应禁用');

    // 降级不等于同意：不得落库同意、不得初始化 SDK。
    expect(settings.current.privacyAgreed, isFalse);
    expect(spy.calls, 0);
    expect(gate.ready, isFalse);
  });

  testWidgets('TC-04-4 降级后点「同意隐私政策并开始使用」：重新唤起同意框',
      (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();
    expect(find.text('同意并继续'), findsNothing);

    // 先关掉第 1 步引导遮罩（它覆盖在降级首页之上），再点降级提示里的入口。
    if (find.text('知道了').evaluate().isNotEmpty) {
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('同意隐私政策并开始使用'));
    await tester.pumpAndSettle();

    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('暂不同意'), findsOneWidget);
  });

  testWidgets('TC-04-5 已同意冷启动：不再弹门，直接进入停车态',
      (WidgetTester tester) async {
    settings.current = AppSettings(
      privacyAgreed: true,
      privacyAgreedAt: DateTime(2026, 9, 1, 8),
      guideDisabled: true,
    );
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    expect(find.text('同意并继续'), findsNothing);
    expect(find.text('车停好了？'), findsOneWidget);
    expect(settings.current.privacyAgreed, isTrue);
  });

  testWidgets('TC-04-6 降级模式：仅历史/设置入口可用，记录入口被禁用',
      (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.byTooltip('历史记录'), findsOneWidget);

    final ElevatedButton recordButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '记下车位'),
    );
    expect(recordButton.onPressed, isNull);
  });

  testWidgets('TC-04-7 同意框内可查看隐私政策全文', (WidgetTester tester) async {
    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看《隐私政策》全文'));
    await tester.pumpAndSettle();

    expect(find.text('隐私政策'), findsWidgets);
    expect(find.textContaining('不收集、不上传、不分享'), findsOneWidget);
  });

  // Round 2 回归：F-3 —— 降级模式不得触发新手引导遮罩。
  testWidgets('TC-04-8【F-3】降级模式不显示新手引导（引导开关开启也不弹）',
      (WidgetTester tester) async {
    // 引导开关保持默认开启（guideDisabled=false），唯一让它不出现的理由就是
    // HomePage 处于降级模式（degraded=true）。若 F-3 修复缺失，第 1 步引导会弹出。
    expect(settings.current.guideDisabled, isFalse);

    await tester.pumpWidget(rig());
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();

    expect(find.text('定位与地图暂不可用'), findsOneWidget);
    expect(find.text('点这里，位置自动记'), findsNothing,
        reason: 'F-3：降级首页不应显示第 1 步引导气泡');
    expect(find.text('知道了'), findsNothing, reason: 'F-3：降级首页不应出现引导遮罩');
    expect(settings.current.guideStepsSeen, isEmpty,
        reason: 'F-3：降级模式不应把引导步号写进已看集合');
  });
}
