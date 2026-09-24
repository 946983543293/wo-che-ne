import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';
import 'providers.dart';

/// 设置控制器（架构 §3.2 `SettingsController`）。
///
/// 持有 [AppSettings] 的单一可信状态：`build()` 从仓储读取，所有写操作都
/// 「读改写 + 落库 + 更新内存 state」，保证 UI 与持久化一致。
/// 本类是 UI 与数据层之间唯一的设置写入点（引导控制器除外，它只管引导字段）。
class SettingsController extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() => _repo.load();

  /// 当前主题模式（偏好枚举 → Flutter [ThemeMode]；加载中回退跟随系统）。
  ThemeMode get themeMode {
    switch (state.valueOrNull?.themeMode) {
      case ThemeModePref.light:
        return ThemeMode.light;
      case ThemeModePref.dark:
        return ThemeMode.dark;
      case ThemeModePref.system:
      case null:
        return ThemeMode.system;
    }
  }

  /// 设置历史记录保存上限（仓储层会再钳制到 3–20）。
  Future<void> setMaxRecords(int value) =>
      _update((AppSettings s) => s.copyWith(maxRecords: value));

  /// 设置主题模式（跟随系统 / 浅色 / 深色）。
  Future<void> setThemeMode(ThemeModePref mode) =>
      _update((AppSettings s) => s.copyWith(themeMode: mode));

  /// 开关记录完成后的震动反馈。
  Future<void> setHapticEnabled(bool enabled) =>
      _update((AppSettings s) => s.copyWith(hapticEnabled: enabled));

  /// 落库隐私政策同意状态（高德 SDK 合规门依据）。
  ///
  /// 幂等：已同意则不覆盖原同意时间。
  Future<void> agreePrivacy() => _update((AppSettings s) {
        if (s.privacyAgreed) {
          return s;
        }
        return s.copyWith(privacyAgreed: true, privacyAgreedAt: DateTime.now());
      });

  /// 从仓储重新拉取（设置页/其他写方改动后刷新用）。
  Future<void> reload() async {
    state = const AsyncLoading<AppSettings>();
    state = await AsyncValue.guard(_repo.load);
  }

  /// 通用「读改写」：加载当前值 → 变换 → 落库 → 更新 state。
  Future<void> _update(AppSettings Function(AppSettings current) transform) async {
    final AppSettings current = state.valueOrNull ?? await _repo.load();
    final AppSettings next = transform(current);
    await _repo.save(next);
    state = AsyncData<AppSettings>(next);
  }
}
