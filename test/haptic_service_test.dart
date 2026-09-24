// 震动无反应修复 —— HapticService 行为验证。
//
// `vibration` 与 `HapticFeedback` 都走平台通道；`flutter test` 里平台通道无宿主，
// 未打桩的通道调用会**挂起**而不是报错，所以这里的每个用例都显式打桩。

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/services/haptic_service.dart';

import 'support/fakes.dart';

void main() {
  // 本文件用的是纯 `test()`（非 widget 测试），`TestDefaultBinaryMessengerBinding
  // .instance` 在绑定初始化前不可用，必须先 ensureInitialized。
  TestWidgetsFlutterBinding.ensureInitialized();

  /// `vibration` 插件的通道名（vibration_platform_interface 中写死）。
  const MethodChannel vibrationChannel = MethodChannel('vibration');

  /// `HapticFeedback` 走的通道。
  ///
  /// 注意：`SystemChannels.platform` 实际是
  /// `OptionalMethodChannel('flutter/platform', JSONMethodCodec())`，
  /// 打桩必须用**同名的 JSONMethodCodec** 通道，否则解码会失败（StandardMethodCodec
  /// 解不出 JSON 消息），回退调用会被吞掉。
  final MethodChannel platformChannel =
      MethodChannel('flutter/platform', JSONMethodCodec());

  void installVibrationMock(
    void Function(MethodCall call) onCall, {
    Object? error,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(vibrationChannel, (MethodCall call) async {
      if (error != null) {
        throw error;
      }
      onCall(call);
      return null;
    });
  }

  void installPlatformMock(void Function(MethodCall call) onCall) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (MethodCall call) async {
      onCall(call);
      return null;
    });
  }

  setUp(() {
    // 默认给两条通道都打桩，避免用例不小心挂起。
    installVibrationMock((MethodCall _) {});
    installPlatformMock((MethodCall _) {});
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(vibrationChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformChannel, null);
    });
  });

  HapticService buildService({required bool enabled}) => HapticService(
        settings: FakeSettingsRepository(
          AppSettings(hapticEnabled: enabled),
        ),
      );

  test('HAPTIC-1 开关关闭：recordSaved 不触发任何震动通道', () async {
    final List<MethodCall> calls = <MethodCall>[];
    installVibrationMock(calls.add);

    await buildService(enabled: false).recordSaved();

    expect(calls, isEmpty);
  });

  test('HAPTIC-2 开关开启：recordSaved 调 vibration 通道，参数 duration=60 / amplitude=160',
      () async {
    final List<MethodCall> calls = <MethodCall>[];
    installVibrationMock(calls.add);

    await buildService(enabled: true).recordSaved();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'vibrate');
    final Map<Object?, Object?> args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['duration'], HapticService.durationMs);
    expect(args['duration'], 60, reason: '30ms 太短，感知不到');
    expect(args['amplitude'], HapticService.amplitude);
    expect(args['amplitude'], 160, reason: '默认 -1 在多数机型是最轻档');
  });

  test('HAPTIC-3 vibration 通道抛异常：不抛出，回退 HapticFeedback.mediumImpact',
      () async {
    final List<MethodCall> platformCalls = <MethodCall>[];
    installVibrationMock((MethodCall _) {}, error: PlatformException(code: 'boom'));
    installPlatformMock(platformCalls.add);

    await expectLater(buildService(enabled: true).recordSaved(), completes);

    // 只断言方法名：不同 Flutter 版本传给 `HapticFeedback.vibrate` 的实参字符串
    // 可能是 'mediumImpact' 或 'HapticFeedback.mediumImpact'，不应锁死。
    expect(
      platformCalls.any((MethodCall c) => c.method == 'HapticFeedback.vibrate'),
      isTrue,
      reason: 'vibration 插件失败应回退到 Flutter 内置 HapticFeedback',
    );
  });

  test('HAPTIC-4 两条通道都抛异常：仍然 completes（绝不打断记录流程）', () async {
    installVibrationMock((MethodCall _) {}, error: PlatformException(code: 'boom'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel,
            (MethodCall call) async => throw PlatformException(code: 'fallback'));

    await expectLater(buildService(enabled: true).recordSaved(), completes);
  });

  test('HAPTIC-5 preview 忽略开关：开关关闭时也震一次（设置页「试一下」用）',
      () async {
    final List<MethodCall> calls = <MethodCall>[];
    installVibrationMock(calls.add);

    await buildService(enabled: false).preview();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'vibrate');
  });

  test('HAPTIC-6 开关开启时不再预检 hasVibrator（vibration 通道只收到一次 vibrate）',
      () async {
    final List<MethodCall> calls = <MethodCall>[];
    installVibrationMock(calls.add);

    await buildService(enabled: true).recordSaved();

    expect(calls.map((MethodCall c) => c.method), <String>['vibrate']);
  });
}
