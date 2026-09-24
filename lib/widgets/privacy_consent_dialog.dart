import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'privacy_policy_page.dart';

/// 首启隐私政策同意框（架构 §4① 、PRD §6.2 合规红线）。
///
/// 合规要点：**用户同意前，高德 SDK 不做任何初始化**。本组件只负责收集意愿，
/// 真正「落库同意状态 + 初始化 SDK」由调用方（`_ConsentGate`）在 `onAgree` 后执行。
/// 对话框内可查看隐私政策全文，保证「用户可随时查阅」。
class PrivacyConsentDialog extends StatelessWidget {
  /// 创建同意框。
  const PrivacyConsentDialog({
    super.key,
    required this.onAgree,
    required this.onDecline,
  });

  /// 用户点「同意并继续」。
  final VoidCallback onAgree;

  /// 用户点「暂不同意」（进入降级模式）。
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('欢迎使用我车呢', style: text.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '在开始之前，请了解我们如何处理你的数据：',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            const _Bullet(text: '位置、照片只存在你自己的手机里，不上传、不分享。'),
            const _Bullet(text: '不收集设备信息，无账号、无埋点、无广告。'),
            const _Bullet(text: '照片只进应用私有目录，不会写入系统相册。'),
            const _Bullet(text: '高德地图/定位 SDK 仅在你同意后才会初始化。'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openPolicy(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('查看《隐私政策》全文'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: onDecline,
                    child: const Text('暂不同意'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAgree,
                    child: const Text('同意并继续'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPolicy(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
