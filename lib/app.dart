import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'data/models/parking_record.dart';
import 'pages/camera/camera_page.dart';
import 'pages/history/history_page.dart';
import 'pages/history/record_detail_page.dart';
import 'pages/home/home_page.dart';
import 'pages/map_find/map_find_page.dart';
import 'pages/settings/settings_page.dart';
import 'services/shortcut_service.dart';
import 'state/providers.dart';
import 'widgets/privacy_consent_dialog.dart';

/// 「我车呢」应用根组件（MaterialApp 装配：主题 / 路由 / 深色模式 / 隐私同意门）。
class WoCheNeApp extends ConsumerWidget {
  /// 创建应用根组件。
  const WoCheNeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P1-3：深色模式偏好来自设置（默认跟随系统）。
    //
    // 注意：必须 `watch` 设置**状态**本身（而非 notifier），否则主题切换不会
    // 触发 MaterialApp 重建，用户在设置页改「深色」时会「点了没反应」。
    final AppSettings settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? AppSettings();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _toThemeMode(settings.themeMode),
      home: const _AppRoot(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// 主题偏好枚举 → Flutter [ThemeMode]。
  static ThemeMode _toThemeMode(ThemeModePref pref) {
    switch (pref) {
      case ThemeModePref.light:
        return ThemeMode.light;
      case ThemeModePref.dark:
        return ThemeMode.dark;
      case ThemeModePref.system:
        return ThemeMode.system;
    }
  }

  /// 生成命名路由。
  ///
  /// 所有带参路由都**先做类型判定再使用**：进程被系统回收后重建、或调用方漏传
  /// arguments 时，`settings.arguments! as X` 会抛 cast 异常并冒泡成白屏/闪退。
  /// 这里统一降级为「记录已失效」占位页，绝不因参数问题崩溃。
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;
    switch (settings.name) {
      case AppConstants.routeHome:
        return MaterialPageRoute<void>(builder: (_) => const _ConsentGate());
      case AppConstants.routeCamera:
        if (args is CameraPageArgs) {
          return MaterialPageRoute<bool>(
            builder: (_) => CameraPage(args: args),
          );
        }
        return _staleArgsRoute();
      case AppConstants.routeMapFind:
        if (args is ParkingRecord) {
          return MaterialPageRoute<bool>(
            builder: (_) => MapFindPage(record: args),
          );
        }
        return _staleArgsRoute();
      case AppConstants.routeHistory:
        return MaterialPageRoute<void>(builder: (_) => const HistoryPage());
      case AppConstants.routeRecordDetail:
        if (args is ParkingRecord) {
          return MaterialPageRoute<void>(
            builder: (_) => RecordDetailPage(record: args),
          );
        }
        return _staleArgsRoute();
      case AppConstants.routeSettings:
        return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
      default:
        return null;
    }
  }
}

/// 路由参数缺失 / 类型不符时的兜底页路由（绝不因 cast 异常导致白屏/闪退）。
MaterialPageRoute<void> _staleArgsRoute() => MaterialPageRoute<void>(
      builder: (BuildContext context) => const _StaleArgsPage(),
    );

/// 「记录已失效」占位页：给出明确文案 + 一个返回按钮，不让用户卡在空白页。
class _StaleArgsPage extends StatelessWidget {
  const _StaleArgsPage();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.history_toggle_off_outlined,
                    size: 44, color: AppColors.primary),
                const SizedBox(height: 14),
                Text('记录已失效', style: text.bodyMedium),
                const SizedBox(height: 6),
                Text('这条记录已不可查看，请返回重试。', style: text.bodySmall),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 应用外壳：挂载「桌面快捷方式」桥接，并承载首启合规门。
///
/// 职责边界：本组件只把原生「一键记车位」动作转换为 [quickRecordRequestProvider]
/// 信号（真正的记录流程仍由首页在**合规就绪**后消费）；不触碰任何业务状态。
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  StreamSubscription<String>? _shortcutSub;

  @override
  void initState() {
    super.initState();
    final ShortcutService service = ref.read(shortcutServiceProvider);
    // 先订阅，再 register：即使原生动作在启动早期到达也不会丢失。
    _shortcutSub = service.actions.listen(_handleShortcut);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await service.register();
      final String? coldStart = service.consumePendingAction();
      if (coldStart != null) {
        _handleShortcut(coldStart);
      }
    });
  }

  @override
  void dispose() {
    _shortcutSub?.cancel();
    super.dispose();
  }

  /// 把原生动作翻译为「请求进入记录流程」信号。
  ///
  /// 不在此处判断隐私同意：未同意时 [_ConsentGate] 会先呈现同意框（合规红线），
  /// 首页在同意后消费该信号，实现「不重复弹引导/隐私门」的直达体验。
  void _handleShortcut(String action) {
    if (action != AppConstants.shortcutActionRecordParking) {
      return;
    }
    ref.read(quickRecordRequestProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) => const _ConsentGate();
}

/// 首启合规门（架构 §4①）：未同意隐私政策 → 先弹同意框；不同意 → 降级首页。
///
/// **合规红线**：同意前不初始化高德 SDK。同意后落库状态并调 `gate.agreeAndInit()`。
class _ConsentGate extends ConsumerStatefulWidget {
  const _ConsentGate();

  @override
  ConsumerState<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<_ConsentGate> {
  bool _dialogScheduled = false;
  bool _declined = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSettings> settingsAsync =
        ref.watch(settingsControllerProvider);
    return settingsAsync.when(
      loading: () => const _SplashScreen(),
      error: (Object error, StackTrace stack) => const _SplashScreen(),
      data: (AppSettings settings) {
        if (!settings.privacyAgreed && !_declined) {
          _scheduleConsentDialog();
          return const _SplashScreen();
        }
        return HomePage(
          degraded: _declined && !settings.privacyAgreed,
          onRequestConsent: () {
            if (mounted) {
              setState(() => _declined = false);
            }
          },
        );
      },
    );
  }

  void _scheduleConsentDialog() {
    if (_dialogScheduled) {
      return;
    }
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final bool? agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => PrivacyConsentDialog(
          onAgree: () => Navigator.of(dialogContext).pop(true),
          onDecline: () => Navigator.of(dialogContext).pop(false),
        ),
      );
      if (!mounted) {
        return;
      }
      _dialogScheduled = false;
      if (agreed == true) {
        await ref.read(settingsControllerProvider.notifier).agreePrivacy();
        try {
          await ref.read(amapSdkGateProvider).agreeAndInit();
        } catch (_) {
          // SDK 初始化失败不阻断进入（定位调用会再次经合规门校验）。
        }
      } else if (agreed == false) {
        setState(() => _declined = true);
      }
    });
  }
}

/// 启动占位（读取设置/等待同意框期间显示），保持清新校园风的大留白。
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              'assets/images/brand_mark.png',
              width: 88,
              height: 88,
              errorBuilder: (_, Object _, StackTrace? _) => const Icon(
                Icons.directions_bike,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
