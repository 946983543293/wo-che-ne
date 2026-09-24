import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repositories/settings_repository.dart';
import 'services/amap_sdk_gate.dart';
import 'services/diagnostics_service.dart';
import 'state/providers.dart';

/// 「我车呢」应用入口。
///
/// 启动顺序（架构 §4①）：
/// 1. 初始化 Flutter 绑定；
/// 2. 注册全局错误捕获（写诊断日志，避免未处理异常直接白屏/闪退）；
/// 3. 构造设置仓储（`shared_preferences` 已在此 `await` 就绪，供全 App 同步注入）；
/// 4. 构造合规门并按需初始化高德 SDK —— **仅当此前已同意隐私政策**（合规红线）；
/// 5. `ProviderScope` 注入上述实例并启动 UI（首启同意框在 `_ConsentGate` 处理）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误捕获：任何未处理异常先落盘诊断日志（「设置 → 诊断 → 诊断日志」可取证），
  // 再交给 Flutter 默认呈现逻辑，避免真机上直接白屏/闪退且无从排查。
  FlutterError.onError = (FlutterErrorDetails details) {
    unawaited(
      diagnosticsService.logError(
        details.exception,
        stack: details.stack,
        tag: 'FlutterError',
      ),
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(
      diagnosticsService.logError(
        error,
        stack: stack,
        tag: 'PlatformDispatcher',
      ),
    );
    // 返回 true：已处理，不再冒泡给引擎默认处理（避免二次上报）。
    return true;
  };

  final SettingsRepository settings = await PrefsSettingsRepository.create();
  final AmapSdkGate gate = AmapSdkGate(settings: settings);
  try {
    await gate.initIfAgreed();
  } catch (_) {
    // 冷启动初始化失败不阻断应用（后续定位调用会再次经 gate.ensureReady 校验）。
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(settings),
        amapSdkGateProvider.overrideWithValue(gate),
      ],
      child: const WoCheNeApp(),
    ),
  );
}
