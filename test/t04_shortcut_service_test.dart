// T04 —— P1-2 桌面快捷方式：自建 MethodChannel 服务测试（冷启动拉取 + 热启动推送 + 降级）。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/core/constants.dart';
import 'package:wo_che_ne/services/shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(AppConstants.shortcutChannelName);

  /// 安装该通道的 mock；[launchAction] 为 getLaunchAction 的返回值。
  void installChannel({String? launchAction}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getLaunchAction') {
        return launchAction;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  /// 取一次服务「已发出或已暂存」的动作（覆盖监听时序差异）。
  Future<List<String>> drain(
    ShortcutService service,
    List<String> received,
  ) async {
    await Future<void>.delayed(Duration.zero);
    final String? pending = service.consumePendingAction();
    if (pending != null) {
      received.add(pending);
    }
    return received;
  }

  test('冷启动：register() 拉取原生 action 并归一化为业务类型', () async {
    installChannel(launchAction: AppConstants.shortcutIntentAction);
    final ShortcutService service = ShortcutService();
    final List<String> received = <String>[];
    final StreamSubscription<String> sub = service.actions.listen(received.add);

    await service.register();
    await drain(service, received);

    expect(received, contains(AppConstants.shortcutActionRecordParking));
    await sub.cancel();
    await service.dispose();
  });

  test('归一化：未知 action 原样透传（不误判为记车位）', () async {
    installChannel(launchAction: 'some.other.action');
    final ShortcutService service = ShortcutService();
    final List<String> received = <String>[];
    service.actions.listen(received.add);

    await service.register();
    await drain(service, received);

    expect(received, contains('some.other.action'));
    expect(
      received,
      isNot(contains(AppConstants.shortcutActionRecordParking)),
    );
    await service.dispose();
  });

  test('热启动：原生 launchAction 反向推送 → 流发出归一化动作', () async {
    installChannel(launchAction: null);
    final ShortcutService service = ShortcutService();
    final List<String> received = <String>[];
    final StreamSubscription<String> sub = service.actions.listen(received.add);
    await service.register();
    await Future<void>.delayed(Duration.zero);

    // 模拟原生 onNewIntent 经通道推送到 Dart 的 launchAction 回调。
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      AppConstants.shortcutChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('launchAction', AppConstants.shortcutIntentAction),
      ),
      (ByteData? _) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(received, contains(AppConstants.shortcutActionRecordParking));
    await sub.cancel();
    await service.dispose();
  });

  test('无原生实现（如单测环境）：register() 静默降级，不抛异常', () async {
    final ShortcutService service = ShortcutService();
    await expectLater(service.register(), completes);
    await service.dispose();
  });
}
