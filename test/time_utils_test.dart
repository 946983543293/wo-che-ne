import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/core/utils/time_utils.dart';

void main() {
  group('TimeUtils.formatFriendly', () {
    // 固定「当前时间」参考点，保证用例确定、不受运行时刻影响。
    final DateTime now = DateTime(2026, 9, 23, 18, 0);

    test('同一天 → 今天 HH:mm', () {
      expect(
        TimeUtils.formatFriendly(DateTime(2026, 9, 23, 12, 24), now: now),
        '今天 12:24',
      );
    });

    test('前一天 → 昨天 HH:mm（分钟补零）', () {
      expect(
        TimeUtils.formatFriendly(DateTime(2026, 9, 22, 9, 5), now: now),
        '昨天 09:05',
      );
    });

    test('同年更早 → M月D日 HH:mm', () {
      expect(
        TimeUtils.formatFriendly(DateTime(2026, 3, 1, 8, 0), now: now),
        '3月1日 08:00',
      );
    });

    test('跨年 → YYYY年M月D日 HH:mm', () {
      expect(
        TimeUtils.formatFriendly(DateTime(2025, 9, 18, 12, 0), now: now),
        '2025年9月18日 12:00',
      );
    });

    test('跨年但相邻两天仍按「昨天」', () {
      expect(
        TimeUtils.formatFriendly(
          DateTime(2025, 12, 31, 23, 59),
          now: DateTime(2026, 1, 1, 0, 31),
        ),
        '昨天 23:59',
      );
    });
  });
}
