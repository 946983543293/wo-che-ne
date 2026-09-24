import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../data/repositories/settings_repository.dart';
import 'diagnostics_service.dart';

/// 震动反馈服务（架构 §3.2 `HapticService`，Q2 已决：默认开启）。
///
/// 读取 `AppSettings.hapticEnabled` 决定是否震动；震动失败**绝不打断记录流程**。
///
/// ## 为什么不再调用 `Vibration.hasVibrator()`
/// - native 侧 `vibration` 插件的 `Vibration.vibrate(long duration, int amplitude)`
///   内部**已经** `if (vibrator.hasVibrator()) { ... }` 判过（见
///   `vibration-3.2.1/android/.../Vibration.java:19`），Dart 侧再判一次纯属重复；
/// - 更糟的是 Dart 侧的 `hasVibrator()` 在 Android 上要先 `await deviceInfo.androidInfo`
///   （走的是 `device_info_plus` 通道，与 `vibration` 通道无关），多一次跨平台调用
///   就多一个失败点；且它只 catch `PlatformException` / `UnsupportedError`，
///   其它异常会一路抛上来被这里静默吞掉 → 表现为「永远不震，且不留任何痕迹」。
///   去掉这层判断既少一个失败点，也把真实原因暴露给诊断日志。
///
/// ## 失败兜底
/// `vibration` 插件调用失败 → 回退 Flutter 内置的 `HapticFeedback.mediumImpact()`
/// （`package:flutter/services.dart`，无新增依赖）；再失败才静默，但**每一步都写
/// 诊断日志**，避免下次「不震了却无从查起」。
class HapticService {
  /// 注入设置仓储（读取震动开关）。
  HapticService({required this._settings});

  final SettingsRepository _settings;

  /// 单次震动时长（毫秒）。30ms 太短，多数机型上感知不到。
  static const int durationMs = 60;

  /// 单次震动强度（1–255）。不支持调幅的机型由 native 自动回退默认强度，传此值安全。
  static const int amplitude = 160;

  /// 记录保存成功后的轻震反馈（开关关闭时直接返回，不做任何事）。
  Future<void> recordSaved() async {
    final bool enabled;
    try {
      enabled = (await _settings.load()).hapticEnabled;
    } catch (error, stack) {
      // 设置读取失败不该阻断记录流程，但要留痕。
      unawaited(
        diagnosticsService.logError(
          error,
          stack: stack,
          tag: 'haptic.settings',
        ),
      );
      return;
    }
    if (!enabled) {
      // 开关关闭导致的「跳过」也留痕：否则用户反馈「记录时不震」时，
      // 诊断日志里一片空白，只能靠猜（开关是唯一的静默 return 路径）。
      unawaited(
        diagnosticsService.logError(
          '跳过震动：设置项 hapticEnabled 为 false',
          tag: 'haptic.disabled',
        ),
      );
      return;
    }
    await _vibrate('recordSaved');
  }

  /// 设置页「试一下震动」用：**忽略开关**直接震一次，便于用户验证硬件与链路。
  Future<void> preview() => _vibrate('preview');

  /// 实际震动：`vibration` 插件优先，失败回退 `HapticFeedback`，再失败才静默。
  Future<void> _vibrate(String tag) async {
    try {
      await Vibration.vibrate(duration: durationMs, amplitude: amplitude);
    } catch (error, stack) {
      unawaited(
        diagnosticsService.logError(error, stack: stack, tag: 'haptic.$tag'),
      );
      try {
        await HapticFeedback.mediumImpact();
      } catch (fallbackError, fallbackStack) {
        unawaited(
          diagnosticsService.logError(
            fallbackError,
            stack: fallbackStack,
            tag: 'haptic.$tag.fallback',
          ),
        );
      }
    }
  }
}
