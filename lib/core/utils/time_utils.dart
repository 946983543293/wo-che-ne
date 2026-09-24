import 'package:intl/intl.dart';

/// 时间格式化工具（架构 §2 `time_utils.dart`、§7.8 时间约定）。
///
/// 存储一律用 `DateTime.toIso8601String()`（本地时区）；展示统一走本工具，
/// 输出「今天 12:24」「昨天 12:24」这类人性化文案。
abstract final class TimeUtils {
  TimeUtils._();

  /// 24 小时制时钟格式化器（`HH:mm`，不依赖 locale 数据，纯 Dart 可测）。
  static final DateFormat _clock = DateFormat('HH:mm');

  /// 将 [dateTime] 格式化为人性化文案。
  ///
  /// - 今天 → `今天 12:24`
  /// - 昨天 → `昨天 12:24`
  /// - 同年更早 → `9月18日 12:24`
  /// - 跨年 → `2025年9月18日 12:24`
  ///
  /// [now] 仅用于测试注入「当前时间」，缺省取 [DateTime.now]。
  static String formatFriendly(DateTime dateTime, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final int dayGap = _dayIndex(reference) - _dayIndex(dateTime);
    final String clock = _clock.format(dateTime);

    if (dayGap == 0) {
      return '今天 $clock';
    }
    if (dayGap == 1) {
      return '昨天 $clock';
    }
    if (dateTime.year == reference.year) {
      return '${dateTime.month}月${dateTime.day}日 $clock';
    }
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 $clock';
  }

  /// 计算「自纪元起的第几天」（按本地年月日），规避夏令时导致的 1 小时偏移。
  static int _dayIndex(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}
