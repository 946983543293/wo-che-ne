import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../models/app_settings.dart';

/// 设置仓储接口（架构 §3.2 `SettingsRepository`）。
///
/// 数据层对外只暴露接口，便于状态层/服务层注入与单测替换实现。
abstract interface class SettingsRepository {
  /// 读取当前设置（缺失项取默认值）。
  Future<AppSettings> load();

  /// 全量写入设置。
  Future<void> save(AppSettings settings);
}

/// 基于 `shared_preferences` 的设置仓储实现（架构 §1.4）。
///
/// 逐字段落在 `AppConstants` 定义的键上，避免单键 JSON blob 的版本迁移麻烦。
class PrefsSettingsRepository implements SettingsRepository {
  /// 使用已初始化的 [SharedPreferences] 实例构造。
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  /// 便捷工厂：异步获取 `SharedPreferences` 实例后构造。
  static Future<PrefsSettingsRepository> create() async =>
      PrefsSettingsRepository(await SharedPreferences.getInstance());

  @override
  Future<AppSettings> load() async {
    final List<String> seen =
        _prefs.getStringList(AppConstants.keyGuideStepsSeen) ?? const <String>[];
    final String? agreedAtRaw =
        _prefs.getString(AppConstants.keyPrivacyAgreedAt);

    return AppSettings(
      maxRecords: _prefs.getInt(AppConstants.keyMaxRecords) ??
          AppConstants.defaultMaxRecords,
      themeMode: ThemeModePref.fromStorage(
        _prefs.getString(AppConstants.keyThemeMode),
      ),
      hapticEnabled:
          _prefs.getBool(AppConstants.keyHapticEnabled) ?? true,
      guideDisabled:
          _prefs.getBool(AppConstants.keyGuideDisabled) ?? false,
      guideStepsSeen: seen
          .map((String e) => int.tryParse(e))
          .whereType<int>()
          .toSet(),
      privacyAgreed:
          _prefs.getBool(AppConstants.keyPrivacyAgreed) ?? false,
      privacyAgreedAt:
          agreedAtRaw == null ? null : DateTime.tryParse(agreedAtRaw),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setInt(AppConstants.keyMaxRecords, settings.maxRecords);
    await _prefs.setString(AppConstants.keyThemeMode, settings.themeMode.name);
    await _prefs.setBool(
      AppConstants.keyHapticEnabled,
      settings.hapticEnabled,
    );
    await _prefs.setBool(
      AppConstants.keyGuideDisabled,
      settings.guideDisabled,
    );
    final List<String> steps = settings.guideStepsSeen
        .map((int e) => e.toString())
        .toList()
      ..sort();
    await _prefs.setStringList(AppConstants.keyGuideStepsSeen, steps);
    await _prefs.setBool(
      AppConstants.keyPrivacyAgreed,
      settings.privacyAgreed,
    );
    final DateTime? agreedAt = settings.privacyAgreedAt;
    if (agreedAt == null) {
      await _prefs.remove(AppConstants.keyPrivacyAgreedAt);
    } else {
      await _prefs.setString(
        AppConstants.keyPrivacyAgreedAt,
        agreedAt.toIso8601String(),
      );
    }
  }
}
