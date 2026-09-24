import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/parking_record.dart';
import '../../services/location_service.dart';
import '../../state/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/photo_strip.dart';

/// 历史记录页（PRD §4.5）。
///
/// 按创建时间**倒序**列出全部记录：首图缩略图 + 时间 + 地点名 + 距当前位置直线距离；
/// 点行进记录详情（只读 + 可删除）。数量受设置上限约束（淘汰由仓储负责）。
class HistoryPage extends ConsumerWidget {
  /// 创建历史记录页。
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ParkingRecord>> recordsAsync =
        ref.watch(historyRecordsProvider);
    final PositionFix? me = ref.watch(currentFixProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: SafeArea(
        child: recordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object _, StackTrace _) => const EmptyState(
            message: '记录读取失败，请稍后重试',
            icon: Icons.error_outline,
          ),
          data: (List<ParkingRecord> records) => records.isEmpty
              ? const EmptyState(
                  message: '还没有停车记录\n记一次，找车不再翻遍整个车棚',
                  icon: Icons.history,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    32,
                  ),
                  itemCount: records.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: AppTokens.cardGap),
                  itemBuilder: (BuildContext context, int index) => _HistoryTile(
                    record: records[index],
                    me: me,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 单条历史卡：左图右文，整卡可点进详情。
class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.record, required this.me});

  final ParkingRecord record;
  final PositionFix? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? distance = (me != null && record.hasLocation)
        ? GeoUtils.formatDistance(
            GeoUtils.distanceMeters(me!.point, record.point),
          )
        : null;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        onTap: () => Navigator.of(context).pushNamed(
          AppConstants.routeRecordDetail,
          arguments: record,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              PhotoThumb(
                relativePath: record.photoPaths.isEmpty
                    ? null
                    : record.photoPaths.first,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      TimeUtils.formatFriendly(record.createdAt),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        if (record.archived) ...<Widget>[
                          _Tag(text: '已归档', color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            record.poiName ?? '未知地点',
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (distance != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '距你 $distance',
                            style: text.labelSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小标签（如「已归档」）。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
    );
  }
}
