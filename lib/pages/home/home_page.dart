import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/parking_record.dart';
import '../../services/location_service.dart';
import '../../state/coach_mark_controller.dart';
import '../../state/providers.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../camera/camera_page.dart';

/// 首页（单页双状态，架构 §1.1/§4.1/§4.3）。
///
/// - 无未归档记录 → **停车态**：大字「车停好了？」+ 实时定位状态 + 超大「记下车位」；
/// - 有未归档记录 → **找车态**：「最近一次记录」大卡（时间/地点/首图）+「再记一笔」。
///
/// 用 [latestActiveRecordProvider] 是否为 null 切换两棵子树，不建两个页面。
/// 首启合规流见 `app.dart` 的 `_ConsentGate`；[degraded] 表示用户「暂不同意」隐私政策
/// （定位/地图置灰，仅可查看历史——历史页属 T04）。
class HomePage extends ConsumerStatefulWidget {
  /// 创建首页。[degraded] 为降级模式（未同意隐私政策）；[onRequestConsent] 用于再次唤起同意框。
  const HomePage({
    super.key,
    this.degraded = false,
    this.onRequestConsent,
  });

  /// 是否处于降级模式（未同意隐私政策）。
  final bool degraded;

  /// 用户希望「去同意隐私政策」时的回调。
  final VoidCallback? onRequestConsent;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

/// 定位状态（首页实时定位文案）。
enum _LocStatus { idle, locating, located, failed }

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _recordButtonKey = GlobalKey();
  final GlobalKey _recentCardKey = GlobalKey();

  _LocStatus _locStatus = _LocStatus.idle;
  PositionFix? _fix;

  /// 定位失败时展示的真实原因（含高德错误码），便于用户/开发者定位问题。
  String? _locError;
  bool _locStarted = false;
  bool _step1Checked = false;

  /// 是否已在处理「一键记车位」快捷方式请求（防止重复触发）。
  bool _quickRecordHandled = false;

  /// 当前显示的引导步号（1 或 3），null 表示不显示。
  int? _coachStep;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ParkingRecord?> latestAsync = ref.watch(latestActiveRecordProvider);
    final CoachMarkState? coachState =
        ref.watch(coachMarkControllerProvider).valueOrNull;
    final ParkingRecord? latest = latestAsync.valueOrNull;
    final bool quickRequest = ref.watch(quickRecordRequestProvider);

    // 停车态首次出现：自动定位 + 触发引导第 1 步。
    if (!widget.degraded && latestAsync.hasValue && latest == null && !_locStarted) {
      _locStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
    }
    if (!_step1Checked &&
        !widget.degraded &&
        latestAsync.hasValue &&
        latest == null &&
        coachState != null) {
      _step1Checked = true;
      if (coachState.shouldShow(1)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _coachStep = 1);
          }
        });
      }
    }

    // P1-2：桌面快捷方式「一键记车位」→ 合规就绪后直达记录流程（跳过引导）。
    if (quickRequest && latestAsync.hasValue && !_quickRecordHandled) {
      if (widget.degraded) {
        // 降级模式（未同意隐私）：忽略快捷方式，避免绕过合规门。
        _quickRecordHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(quickRecordRequestProvider.notifier).state = false;
            _quickRecordHandled = false;
          }
        });
      } else {
        _quickRecordHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          ref.read(quickRecordRequestProvider.notifier).state = false;
          _quickRecordHandled = false;
          if (_coachStep != null) {
            setState(() => _coachStep = null);
          }
          await _onRecordPressed(skipCoach: true);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: () => Navigator.of(context).pushNamed(AppConstants.routeSettings),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: '历史记录',
            onPressed: () => Navigator.of(context).pushNamed(AppConstants.routeHistory),
          ),
        ],
      ),
      body: SafeArea(
        child: latestAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              const EmptyState(message: '记录读取失败，请稍后重试', icon: Icons.error_outline),
          data: (ParkingRecord? record) => record == null
              ? _buildParkingState()
              : _buildFindState(record),
        ),
      ),
    );
  }

  // ---------- 停车态 ----------

  Widget _buildParkingState() {
    final TextTheme text = Theme.of(context).textTheme;
    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 主视觉横幅：小屏（如 568dp 高的 SE）下用 flex:1 的 Spacer 让位，
              // 资源缺失时降级为同高占位，整列布局不塌。
              const Spacer(flex: 1),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusL),
                child: Image.asset(
                  'assets/images/home_parking_hero.png',
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, Object _, StackTrace? _) =>
                      const SizedBox(height: 150),
                ),
              ),
              const SizedBox(height: 6),
              Text('车停好了？', style: text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _buildLocationStatus(),
              const Spacer(flex: 3),
              if (widget.degraded) ...<Widget>[
                _buildDegradedNotice(),
                const SizedBox(height: 16),
              ],
              PrimaryButton(
                key: _recordButtonKey,
                label: '记下车位',
                icon: Icons.location_on_outlined,
                onPressed: widget.degraded ? null : _onRecordPressed,
              ),
              const SizedBox(height: 14),
              Text(
                '不拍照也行，2 次点击搞定',
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
        if (_coachStep == 1)
          Positioned.fill(
            child: CoachMarkOverlay(
              targetKey: _recordButtonKey,
              message: '点这里，位置自动记',
              onDismiss: (bool neverAgain) => _dismissCoach(1, neverAgain),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationStatus() {
    final TextTheme text = Theme.of(context).textTheme;
    final ({IconData icon, String label, Color color}) view = switch (_locStatus) {
      _LocStatus.idle => (
          icon: Icons.location_searching_outlined,
          label: '点「记下车位」开始定位',
          color: AppColors.textSecondary,
        ),
      _LocStatus.locating => (
          icon: Icons.my_location_outlined,
          label: '定位中…',
          color: AppColors.primary,
        ),
      _LocStatus.located => (
          icon: Icons.check_circle_outline,
          label: _locatedText(),
          color: AppColors.primary,
        ),
      _LocStatus.failed => (
          icon: Icons.location_off_outlined,
          label: _locError ?? '定位失败，可仅拍照记录',
          color: AppColors.accent,
        ),
    };

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(view.icon, size: 18, color: view.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                view.label,
                style: text.bodySmall?.copyWith(color: view.color),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if (_locStatus == _LocStatus.located && (_fix?.accuracy ?? 0) > AppConstants.poorAccuracyMeters)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '当前定位不准，主要靠照片认车',
              style: text.labelSmall?.copyWith(color: AppColors.accent),
            ),
          ),
      ],
    );
  }

  String _locatedText() {
    final PositionFix? fix = _fix;
    if (fix == null) {
      return '已定位';
    }
    final String place = fix.poiName ?? '当前位置';
    final double? accuracy = fix.accuracy;
    return accuracy == null
        ? '已定位：$place'
        : '已定位：$place，精度 ${accuracy.round()} m';
  }

  Widget _buildDegradedNotice() {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('定位与地图暂不可用', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('同意隐私政策后即可记录车位；你随时可以查看历史记录。', style: text.bodySmall),
          if (widget.onRequestConsent != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onRequestConsent,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              child: const Text('同意隐私政策并开始使用'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- 找车态 ----------

  Widget _buildFindState(ParkingRecord record) {
    final TextTheme text = Theme.of(context).textTheme;
    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 1),
              Text('找到你的车了吗？', style: text.headlineMedium),
              const SizedBox(height: 20),
              _buildRecentCard(record),
              const SizedBox(height: AppTokens.cardGap),
              Center(
                child: TextButton.icon(
                  onPressed: widget.degraded ? null : _onRecordPressed,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('再记一笔'),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
        if (_coachStep == 3)
          Positioned.fill(
            child: CoachMarkOverlay(
              targetKey: _recentCardKey,
              message: '下次找车，点这里',
              onDismiss: (bool neverAgain) => _dismissCoach(3, neverAgain),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentCard(ParkingRecord record) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      key: _recentCardKey,
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppTokens.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        onTap: () => Navigator.of(context).pushNamed(
          AppConstants.routeMapFind,
          arguments: record,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _buildThumb(record),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('最近一次记录', style: text.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      TimeUtils.formatFriendly(record.createdAt),
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (record.accuracy != null &&
                            record.accuracy! > AppConstants.poorAccuracyMeters) ...<Widget>[
                          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
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
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(ParkingRecord record) {
    const double size = 64;
    final String? relative =
        record.photoPaths.isNotEmpty ? record.photoPaths.first : null;
    if (relative == null) {
      return _thumbPlaceholder(size);
    }
    return FutureBuilder<String>(
      future: ref.read(localStoreProvider).absolutePhotoPath(relative),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (!snapshot.hasData) {
          return _thumbPlaceholder(size);
        }
        // 限分辨率解码：只按 64dp × DPR 解码，避免原图全分辨率解码吃掉几十 MB。
        final int cacheWidth =
            (size * MediaQuery.devicePixelRatioOf(context)).round();
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusS),
          child: Image.file(
            File(snapshot.data!),
            width: size,
            height: size,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _thumbPlaceholder(size),
          ),
        );
      },
    );
  }

  Widget _thumbPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
      ),
      child: const Icon(Icons.photo_outlined, color: AppColors.primary),
    );
  }

  // ---------- 记录流程 ----------

  Future<void> _initLocation() async {
    bool granted = false;
    try {
      granted = (await Permission.location.status).isGranted;
    } catch (_) {
      granted = false;
    }
    if (!mounted) {
      return;
    }
    if (!granted) {
      // 未授权 → 停在 idle（保留「点『记下车位』开始定位」的引导文案）。
      //
      // 注意：这里**不能**直接申请权限——PRD §4「按需申请」约定「启动不弹权限，
      // 点『记下车位』才要定位」，`t03_camera_flow_test.dart` 的 TC-08-1 正是
      // 这条红线的回归用例。用户点「记下车位」时 `_onRecordPressed` 会走
      // `_ensureLocationPermission()`（先给理由再申请）。
      setState(() => _locStatus = _LocStatus.idle);
      return;
    }
    await _fetchFix();
  }

  Future<void> _fetchFix() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _locStatus = _LocStatus.locating;
      _locError = null;
    });
    try {
      final PositionFix fix = await ref.read(locationServiceProvider).getCurrentFix();
      if (!mounted) {
        return;
      }
      setState(() {
        _fix = fix;
        _locStatus = _LocStatus.located;
      });
    } on LocationFailedException catch (error) {
      // 把高德真实错误码/描述透出到 UI：否则用户永远只看到「定位失败」，
      // 无法区分「KEY 鉴权失败」与「无定位信号」。
      if (!mounted) {
        return;
      }
      setState(() {
        _fix = null;
        _locError = _formatLocationError(error);
        _locStatus = _LocStatus.failed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fix = null;
        _locStatus = _LocStatus.failed;
      });
    }
  }

  /// 把 [LocationFailedException] 格式化为用户可见的真实原因。
  static String _formatLocationError(LocationFailedException error) {
    final int? code = error.errorCode;
    if (code != null) {
      return '定位失败（code=$code：${error.errorInfo ?? error.message}）';
    }
    return '定位失败：${error.message}';
  }

  Future<void> _onRecordPressed({bool skipCoach = false}) async {
    if (skipCoach) {
      // 快捷方式直达：不展示/不推进引导，直接进入记录流程。
      if (_coachStep != null && mounted) {
        setState(() => _coachStep = null);
      }
    } else {
      if (_coachStep == 1) {
        await _completeCoach(1);
      }
      if (_coachStep != null && mounted) {
        setState(() => _coachStep = null);
      }
    }

    PositionFix? fix = _fix;
    if (fix == null) {
      final bool granted = await _ensureLocationPermission();
      if (granted) {
        await _fetchFix();
        fix = _fix;
      }
    }
    if (!mounted) {
      return;
    }

    final String recordId = const Uuid().v4();
    final bool? saved = await Navigator.of(context).pushNamed<bool>(
      AppConstants.routeCamera,
      arguments: CameraPageArgs(recordId: recordId, fix: fix),
    );
    if (saved == true && mounted) {
      await _maybeShowStep3();
    }
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      if ((await Permission.location.status).isGranted) {
        return true;
      }
      if (!mounted) {
        return false;
      }
      final bool ok = await _showRationale(
            title: '需要定位权限',
            reason: '用于记录车位坐标、找车时显示你的位置。位置只存本机、不上传。',
          ) ??
          false;
      if (!ok) {
        return false;
      }
      return (await Permission.location.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _showRationale({required String title, required String reason}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(reason),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('暂不'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  // ---------- 新手引导 ----------

  Future<void> _maybeShowStep3() async {
    final CoachMarkState? coach =
        ref.read(coachMarkControllerProvider).valueOrNull;
    if (coach != null && coach.shouldShow(3) && mounted) {
      setState(() => _coachStep = 3);
    }
  }

  void _dismissCoach(int step, bool neverAgain) {
    setState(() => _coachStep = null);
    _completeCoach(step, neverAgain: neverAgain);
  }

  Future<void> _completeCoach(int step, {bool neverAgain = false}) {
    return ref
        .read(coachMarkControllerProvider.notifier)
        .completeStep(step, neverAgain: neverAgain);
  }
}
