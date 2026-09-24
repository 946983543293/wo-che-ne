import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/parking_record.dart';
import '../../state/providers.dart';
import '../../widgets/photo_strip.dart';

/// 记录详情页（PRD §4.5：同 4.4 的布局，只读 + 可删除）。
///
/// 展示地图预览（仅车位图钉）+ 时间/地点/精度 + 照片条；右上角可删除该记录
/// （连照片文件一起删，由仓储级联，架构 §7.7）。
class RecordDetailPage extends ConsumerWidget {
  /// 创建详情页。[record] 为待展示记录。
  const RecordDetailPage({super.key, required this.record});

  /// 待展示记录。
  final ParkingRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除记录',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: <Widget>[
            _buildMapPreview(context, ref),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.pagePadding,
              ),
              child: _buildInfoCard(context),
            ),
            if (record.photoPaths.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.pagePadding,
                ),
                child: PhotoStrip(photoPaths: record.photoPaths, thumbSize: 76),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(BuildContext context, WidgetRef ref) {
    final bool ready = ref.watch(amapSdkGateProvider).ready;
    if (!ready || !record.hasLocation) {
      return Container(
        height: 200,
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.map_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              record.hasLocation ? '地图需在同意隐私政策后显示' : '这条记录没有位置（纯照片记录）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    final LatLng target = LatLng(record.latitude, record.longitude);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 200,
      child: AMapWidget(
        privacyStatement: const AMapPrivacyStatement(
          hasContains: true,
          hasShow: true,
          hasAgree: true,
        ),
        mapType: dark ? MapType.night : MapType.normal,
        initialCameraPosition: CameraPosition(target: target, zoom: 17),
        markers: <Marker>{
          Marker(
            position: target,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindowEnable: false,
            zIndex: 2,
          ),
        },
        scaleEnabled: false,
        compassEnabled: false,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row(context, '时间', TimeUtils.formatFriendly(record.createdAt)),
          const SizedBox(height: 12),
          _row(context, '地点', record.poiName ?? '未知地点'),
          const SizedBox(height: 12),
          _row(
            context,
            '状态',
            record.archived ? '已归档' : '未归档（找车中）',
          ),
          if (record.accuracy != null) ...<Widget>[
            const SizedBox(height: 12),
            _row(context, '定位精度', '${record.accuracy!.round()} 米'),
          ],
          if (record.hasLocation) ...<Widget>[
            const SizedBox(height: 12),
            _row(
              context,
              '坐标',
              '${record.latitude.toStringAsFixed(5)}, '
                  '${record.longitude.toStringAsFixed(5)}',
            ),
          ],
          const SizedBox(height: 12),
          _row(context, '照片', '${record.photoPaths.length} 张'),
          const SizedBox(height: 4),
          Text(
            '照片只存在手机私有目录，不进系统相册。',
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(label, style: text.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('记录与照片将被一起删除，无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(parkingControllerProvider.notifier).remove(record.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
