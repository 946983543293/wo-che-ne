import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 空状态（PRD §5：Seedream 插图 + 一句话文案）。
///
/// 图形层为 Seedream 生成的「一排校园自行车」插图
/// （assets/images/empty_state_bikes.png，提示词见 assets/prompts.md）；
/// 插图缺失（如资源未打包）时回退到「主色浅底圆 + 图标」的令牌化占位。
class EmptyState extends StatelessWidget {
  /// 创建空状态。
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.directions_bike_outlined,
  });

  /// 一句话文案。
  final String message;

  /// 插图缺失时的占位图标。
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            'assets/images/empty_state_bikes.png',
            width: 200,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                _iconFallback(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 插图缺失时的令牌化占位（T03 时期的实现，保留为降级路径）。
  Widget _iconFallback() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: AppColors.primary),
    );
  }
}
