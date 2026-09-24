import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';

/// 桌面快捷方式服务（架构 §3.2 `ShortcutService`，P1-2「一键记车位」）。
///
/// ## 为什么自建 MethodChannel 而不用 `quick_actions`
/// 本工程解析到的 `quick_actions`（Dart 侧走旧式方法通道
/// `plugins.flutter.io/quick_actions`）与 `quick_actions_android`（Kotlin 侧已迁移为
/// pigeon 通道 `dev.flutter.pigeon.quick_actions_android.*`）**通道名不一致**，
/// Dart ↔ 原生无法通信。因此这里改用自建通道 [AppConstants.shortcutChannelName]，
/// 由 `MainActivity.kt` 直接暴露启动动作，行为可预期、可审计。
///
/// ## 原生契约
/// - Android 静态快捷方式由 `res/xml/shortcuts.xml` 声明，点击后以
///   [AppConstants.shortcutIntentAction] 启动 `MainActivity`。
/// - 冷启动：Dart 调 `getLaunchAction` 拉取一次；
/// - 热启动：原生 `onNewIntent` 以 `launchAction` 反向推送。
///
/// 所有原生交互失败（如单测环境无平台实现）一律静默降级，不影响 App 运行。
class ShortcutService {
  /// 创建快捷方式服务。[channelOverride] 仅供单测注入假通道。
  ShortcutService({MethodChannel? channelOverride})
      : _channel = channelOverride ??
            const MethodChannel(AppConstants.shortcutChannelName);

  final MethodChannel _channel;
  final StreamController<String> _controller = StreamController<String>.broadcast();
  final List<String> _pending = <String>[];
  bool _registered = false;

  /// 快捷方式动作流（已归一化为 [AppConstants.shortcutActionRecordParking] 等业务类型）。
  Stream<String> get actions => _controller.stream;

  /// 是否仍有尚未被消费的冷启动动作。
  bool get hasPending => _pending.isNotEmpty;

  /// 注册原生桥接并拉取一次冷启动动作（幂等；应用启动时调用一次）。
  Future<void> register() async {
    if (_registered) {
      return;
    }
    _registered = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'launchAction') {
        final Object? raw = call.arguments;
        if (raw is String && raw.isNotEmpty) {
          _record(raw);
        }
      }
      return null;
    });
    try {
      final String? raw = await _channel.invokeMethod<String>('getLaunchAction');
      if (raw != null && raw.isNotEmpty) {
        _record(raw);
      }
    } on MissingPluginException {
      // 无原生实现（如单测环境）：静默降级。
    } on PlatformException {
      // 原生调用异常：静默降级。
    }
  }

  /// 取出一条暂存的冷启动动作（无则返回 null）。
  ///
  /// 供应用在首帧消费，避免「动作早于监听」而丢失信号。
  String? consumePendingAction() =>
      _pending.isEmpty ? null : _pending.removeAt(0);

  /// 直接把一个原生动作交给服务（供原生回调与单测使用）。
  @visibleForTesting
  void handleAction(String rawAction) => _record(rawAction);

  void _record(String raw) {
    final String action = _normalize(raw);
    if (_controller.hasListener) {
      _controller.add(action);
    } else {
      _pending.add(action);
    }
  }

  /// 把原生 action 字符串归一化为业务动作类型。
  static String _normalize(String raw) {
    if (raw == AppConstants.shortcutIntentAction) {
      return AppConstants.shortcutActionRecordParking;
    }
    return raw;
  }

  /// 释放资源（应用退出时）。
  Future<void> dispose() => _controller.close();
}
