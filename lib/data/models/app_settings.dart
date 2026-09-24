import '../../core/constants.dart';

/// 主题模式偏好（架构 §3.1 `AppSettings.themeMode`）。
///
/// 数据层不依赖 Flutter：这里只存偏好枚举，映射到 `ThemeMode` 由状态层
/// `SettingsController` 负责（架构 §3.2），保证本文件纯 Dart 可测。
enum ThemeModePref {
  /// 跟随系统（默认）。
  system,

  /// 强制浅色。
  light,

  /// 强制深色。
  dark;

  /// 从持久化字符串解析；非法或空值回退到 [ThemeModePref.system]。
  static ThemeModePref fromStorage(String? value) {
    for (final ThemeModePref mode in ThemeModePref.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ThemeModePref.system;
  }
}

/// 应用设置模型（架构 §3.1 字段表）。
///
/// 持久化载体为 `shared_preferences`（键名见 `AppConstants`），
/// 同时提供 `fromJson` / `toJson` 以便整体导入导出与单测往返。
class AppSettings {
  /// 构造设置对象（构造时对 [maxRecords] 做 3–20 的钳制，并归一化引导步集合）。
  AppSettings({
    int maxRecords = AppConstants.defaultMaxRecords,
    this.themeMode = ThemeModePref.system,
    this.hapticEnabled = true,
    this.guideDisabled = false,
    Set<int>? guideStepsSeen,
    this.privacyAgreed = false,
    this.privacyAgreedAt,
  })  : maxRecords = maxRecords.clamp(
          AppConstants.minMaxRecords,
          AppConstants.maxMaxRecords,
        ),
        guideStepsSeen =
            Set<int>.unmodifiable(guideStepsSeen ?? const <int>{});

  /// 历史记录保存条数上限（淘汰阈值，钳制在 3–20）。
  final int maxRecords;

  /// 主题模式偏好。
  final ThemeModePref themeMode;

  /// 是否开启「记录完成」震动反馈。
  final bool hapticEnabled;

  /// 引导「以后不再提示」总开关。
  final bool guideDisabled;

  /// 已完成的引导步号（1/2/3）。
  final Set<int> guideStepsSeen;

  /// 隐私政策是否已同意（高德 SDK 合规门依据）。
  final bool privacyAgreed;

  /// 隐私政策同意时间；未同意时为 null。
  final DateTime? privacyAgreedAt;

  /// 从 JSON 反序列化（字段缺失时取默认值）。
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['guideStepsSeen'];
    final Object? agreedAt = json['privacyAgreedAt'];
    return AppSettings(
      maxRecords:
          (json['maxRecords'] as num?)?.toInt() ?? AppConstants.defaultMaxRecords,
      themeMode: ThemeModePref.fromStorage(json['themeMode'] as String?),
      hapticEnabled: json['hapticEnabled'] as bool? ?? true,
      guideDisabled: json['guideDisabled'] as bool? ?? false,
      guideStepsSeen: rawSteps is List
          ? rawSteps
              .map((dynamic e) => e is num ? e.toInt() : int.tryParse('$e'))
              .whereType<int>()
              .toSet()
          : const <int>{},
      privacyAgreed: json['privacyAgreed'] as bool? ?? false,
      privacyAgreedAt:
          agreedAt is String ? DateTime.tryParse(agreedAt) : null,
    );
  }

  /// 序列化为 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'maxRecords': maxRecords,
        'themeMode': themeMode.name,
        'hapticEnabled': hapticEnabled,
        'guideDisabled': guideDisabled,
        'guideStepsSeen': guideStepsSeen.toList()..sort(),
        'privacyAgreed': privacyAgreed,
        'privacyAgreedAt': privacyAgreedAt?.toIso8601String(),
      };

  /// 返回一份修改了指定字段的副本。
  ///
  /// 可空字段 [privacyAgreedAt] 使用哨兵默认值：不传表示「保持原值」，
  /// 显式传 `null` 表示「置空」。
  AppSettings copyWith({
    int? maxRecords,
    ThemeModePref? themeMode,
    bool? hapticEnabled,
    bool? guideDisabled,
    Set<int>? guideStepsSeen,
    bool? privacyAgreed,
    Object? privacyAgreedAt = _unset,
  }) {
    return AppSettings(
      maxRecords: maxRecords ?? this.maxRecords,
      themeMode: themeMode ?? this.themeMode,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      guideDisabled: guideDisabled ?? this.guideDisabled,
      guideStepsSeen: guideStepsSeen ?? this.guideStepsSeen,
      privacyAgreed: privacyAgreed ?? this.privacyAgreed,
      privacyAgreedAt: identical(privacyAgreedAt, _unset)
          ? this.privacyAgreedAt
          : privacyAgreedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          maxRecords == other.maxRecords &&
          themeMode == other.themeMode &&
          hapticEnabled == other.hapticEnabled &&
          guideDisabled == other.guideDisabled &&
          _setEquals(guideStepsSeen, other.guideStepsSeen) &&
          privacyAgreed == other.privacyAgreed &&
          privacyAgreedAt == other.privacyAgreedAt;

  @override
  int get hashCode => Object.hash(
        maxRecords,
        themeMode,
        hapticEnabled,
        guideDisabled,
        Object.hashAllUnordered(guideStepsSeen),
        privacyAgreed,
        privacyAgreedAt,
      );

  @override
  String toString() =>
      'AppSettings(maxRecords: $maxRecords, themeMode: ${themeMode.name}, '
      'haptic: $hapticEnabled, guideDisabled: $guideDisabled, '
      'steps: $guideStepsSeen, agreed: $privacyAgreed)';

  /// `copyWith` 的可空字段哨兵。
  static const Object _unset = Object();

  static bool _setEquals(Set<int> a, Set<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    return a.containsAll(b);
  }
}
