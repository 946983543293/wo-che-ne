import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart';
import '../../state/providers.dart';
import '../../widgets/privacy_policy_page.dart';
import 'diagnostics_log_page.dart';

/// 设置页（PRD §4.7 全项）。
///
/// 所有写操作都经 [settingsControllerProvider]（读改写 + 落库），
/// 页面本身不持有状态，保证与首页/引导共享同一份事实来源。
class SettingsPage extends ConsumerWidget {
  /// 创建设置页。
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSettings> settingsAsync =
        ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object _, StackTrace _) => const Center(child: Text('设置读取失败')),
          data: (AppSettings settings) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              12,
              AppTokens.pagePadding,
              40,
            ),
            children: <Widget>[
              _buildRecordsSection(context, ref, settings),
              const SizedBox(height: 20),
              _buildAppearanceSection(context, ref, settings),
              const SizedBox(height: 20),
              _buildFeedbackSection(context, ref, settings),
              const SizedBox(height: 20),
              _buildGuideSection(context, ref),
              const SizedBox(height: 20),
              _buildPermissionSection(context),
              const SizedBox(height: 20),
              _buildPrivacySection(context),
              const SizedBox(height: 20),
              _buildAboutSection(context, ref),
              const SizedBox(height: 20),
              _buildDiagnosticsSection(context),
              const SizedBox(height: 32),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 记录 ----------

  Widget _buildRecordsSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final bool canDecrease = settings.maxRecords > AppConstants.minMaxRecords;
    final bool canIncrease = settings.maxRecords < AppConstants.maxMaxRecords;
    return _Section(
      title: '记录',
      children: <Widget>[
        ListTile(
          title: const Text('历史记录保存条数'),
          subtitle: const Text('超出上限后自动删除最早的记录（含照片）'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '减少',
                onPressed: canDecrease
                    ? () => ref
                        .read(settingsControllerProvider.notifier)
                        .setMaxRecords(settings.maxRecords - 1)
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${settings.maxRecords}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '增加',
                onPressed: canIncrease
                    ? () => ref
                        .read(settingsControllerProvider.notifier)
                        .setMaxRecords(settings.maxRecords + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- 外观（P1-3） ----------

  Widget _buildAppearanceSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return _Section(
      title: '外观',
      children: <Widget>[
        const ListTile(
          title: Text('深色模式'),
          subtitle: Text('夜间找车不刺眼；地图同步切换暗色底图'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SegmentedButton<ThemeModePref>(
            segments: const <ButtonSegment<ThemeModePref>>[
              ButtonSegment<ThemeModePref>(
                value: ThemeModePref.system,
                label: Text('跟随系统'),
              ),
              ButtonSegment<ThemeModePref>(
                value: ThemeModePref.light,
                label: Text('浅色'),
              ),
              ButtonSegment<ThemeModePref>(
                value: ThemeModePref.dark,
                label: Text('深色'),
              ),
            ],
            selected: <ThemeModePref>{settings.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (Set<ThemeModePref> selection) {
              if (selection.isNotEmpty) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setThemeMode(selection.first);
              }
            },
          ),
        ),
      ],
    );
  }

  // ---------- 震动反馈（Q2 已决：默认开） ----------

  Widget _buildFeedbackSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final bool enabled = settings.hapticEnabled;
    return _Section(
      title: '反馈',
      children: <Widget>[
        SwitchListTile(
          title: const Text('记录完成后震动'),
          // 让开关状态自己说话：关着时明确写出「记录完成后不会震动」。
          subtitle: Text(
            enabled
                ? '记录保存成功时轻震一下，无需看屏'
                : '已关闭：记录完成后不会震动',
          ),
          value: enabled,
          onChanged: (bool value) => ref
              .read(settingsControllerProvider.notifier)
              .setHapticEnabled(value),
        ),
        ListTile(
          title: const Text('试一下震动'),
          // 本按钮**故意忽略开关**（便于验证硬件与链路），所以副标题必须说明
          // 「开关关着时记录不会震」，否则会出现「按钮震了、记录却不震」的错觉。
          subtitle: Text(
            enabled
                ? '立刻震一次，验证硬件与链路'
                : '上方开关已关闭 —— 记录时不会震动，此按钮仍可测试硬件',
          ),
          trailing: const Icon(Icons.vibration, color: AppColors.textSecondary),
          onTap: () => ref.read(hapticServiceProvider).preview(),
        ),
      ],
    );
  }

  // ---------- 新手引导 ----------

  Widget _buildGuideSection(BuildContext context, WidgetRef ref) {
    return _Section(
      title: '新手引导',
      children: <Widget>[
        ListTile(
          title: const Text('重新查看新手引导'),
          subtitle: const Text('重置后，按真实操作流程再走一遍 3 步引导'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () async {
            await ref.read(coachMarkControllerProvider.notifier).reset();
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('已重置，下次进入记录流程时会重新引导')),
                );
            }
          },
        ),
      ],
    );
  }

  // ---------- 权限管理 ----------

  Widget _buildPermissionSection(BuildContext context) {
    return _Section(
      title: '权限',
      children: <Widget>[
        ListTile(
          title: const Text('权限管理'),
          subtitle: const Text('定位 / 相机权限可在系统设置中随时调整'),
          trailing: const Icon(Icons.open_in_new, color: AppColors.textSecondary),
          onTap: openAppSettings,
        ),
      ],
    );
  }

  // ---------- 隐私政策 ----------

  Widget _buildPrivacySection(BuildContext context) {
    return _Section(
      title: '隐私',
      children: <Widget>[
        ListTile(
          title: const Text('隐私政策'),
          subtitle: const Text('本应用不收集、不上传任何数据'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
          ),
        ),
      ],
    );
  }

  // ---------- 关于 ----------

  Widget _buildAboutSection(BuildContext context, WidgetRef ref) {
    final AsyncValue<PackageInfo> pkgAsync = ref.watch(packageInfoProvider);
    final PackageInfo? pkg = pkgAsync.valueOrNull;
    final String version =
        pkg == null ? '—' : '${pkg.version} (${pkg.buildNumber})';
    return _Section(
      title: '关于',
      children: <Widget>[
        // Seedream 生成插图（assets/images/about_bike_pin.png，提示词见 assets/prompts.md）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Image.asset(
            'assets/images/about_bike_pin.png',
            width: 160,
            errorBuilder: (_, Object _, StackTrace? _) =>
                const SizedBox.shrink(),
          ),
        ),
        ListTile(
          title: const Text('版本'),
          trailing: Text(
            version,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ListTile(
          title: const Text('开发者'),
          trailing: Text(
            AppConstants.developerName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ListTile(
          title: const Text('开源协议'),
          trailing: Text(
            AppConstants.licenseName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ListTile(
          title: const Text('开源仓库'),
          subtitle: const Text(AppConstants.githubRepoUrl),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '地图与定位服务由高德地图提供，用户名下高德 Key 方可用；不再首次弹窗之外收集任何信息。',
            style: TextStyle(
              fontSize: AppTokens.fontCaptionS,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- 诊断（真机闪退取证） ----------

  Widget _buildDiagnosticsSection(BuildContext context) {
    return _Section(
      title: '诊断',
      children: <Widget>[
        ListTile(
          title: const Text('诊断日志'),
          subtitle: const Text('闪退排查用：查看 / 复制 / 清空本机错误日志'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const DiagnosticsLogPage(),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- 页脚署名（行业通行做法：拉到底可见） ----------

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Text(
        '我车呢 · 由 ${AppConstants.developerName} 开发',
        style: const TextStyle(
          fontSize: AppTokens.fontCaptionS,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

/// 设置分组卡片：小标题 + 内容。
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          shadowColor: AppColors.shadow,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
