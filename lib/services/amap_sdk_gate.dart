import 'package:amap_flutter_location/amap_flutter_location.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';

/// 高德 SDK 尚未就绪时抛出的类型化异常（架构 §7.5 合规约定）。
///
/// UI 层捕获后应引导用户前往隐私政策同意流程，而不是直接崩溃。
class SdkNotReadyException implements Exception {
  /// 构造异常，[message] 缺省给出面向开发者的中文说明。
  const SdkNotReadyException([
    this.message = '高德 SDK 尚未就绪：需先取得用户对隐私政策的同意',
  ]);

  /// 人类可读的原因说明。
  final String message;

  @override
  String toString() => 'SdkNotReadyException: $message';
}

/// 高德 SDK 初始化的具体动作（可注入，便于单测绕开真实插件）。
typedef AmapSdkInitializer = Future<void> Function();

/// 高德 SDK 合规门（架构 §1.1、§3.2、§7.5）。
///
/// **合规红线**：用户同意隐私政策前，绝不对高德 SDK 做任何初始化。
/// 所有高德相关调用（地图创建、定位、指南针页）前必须先 `ensureReady()`；
/// 未就绪时抛 [SdkNotReadyException]。同意状态持久化在 [SettingsRepository]。
class AmapSdkGate {
  /// 注入设置仓储（读写同意状态）与可选的初始化动作（单测注入假实现）。
  AmapSdkGate({
    required this._settings,
    AmapSdkInitializer? initializer,
  }) : _initializer = initializer ?? _initAmapSdk;

  final SettingsRepository _settings;
  final AmapSdkInitializer _initializer;

  bool _ready = false;

  /// SDK 是否已就绪（可安全调用高德 API）。
  bool get ready => _ready;

  /// 用户点击「同意并继续」时调用：落库同意状态 + 初始化高德 SDK。
  ///
  /// 幂等：重复调用只会再写一次同意时间并重跑初始化，不会出错。
  Future<void> agreeAndInit() async {
    final AppSettings current = await _settings.load();
    if (!current.privacyAgreed) {
      await _settings.save(
        current.copyWith(
          privacyAgreed: true,
          privacyAgreedAt: DateTime.now(),
        ),
      );
    }
    await _initializer();
    _ready = true;
  }

  /// 冷启动时调用：仅当已同意过才初始化 SDK，否则保持未就绪。
  Future<void> initIfAgreed() async {
    final AppSettings current = await _settings.load();
    if (!current.privacyAgreed) {
      return;
    }
    await _initializer();
    _ready = true;
  }

  /// 断言 SDK 已就绪；未就绪抛 [SdkNotReadyException]。
  void ensureReady() {
    if (!_ready) {
      throw const SdkNotReadyException();
    }
  }

  /// 默认初始化动作：设置高德定位 SDK 的隐私合规开关。
  ///
  /// - 定位 SDK：`updatePrivacyShow` / `updatePrivacyAgree` 必须在任何定位调用之前调用。
  /// - 地图 SDK：Android 端 Key 由 AndroidManifest 的 `com.amap.api.v2.apikey`
  ///   （构建期由 local.properties 注入）自动读取；隐私声明随 `AMapWidget`
  ///   的 `privacyStatement` 参数传入（T04 接线）。
  static Future<void> _initAmapSdk() async {
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
  }
}
