import 'dart:async';
import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/parking_record.dart';
import '../../services/amap_sdk_gate.dart';
import '../../services/compass_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/location_service.dart';
import '../../state/providers.dart';
import '../../widgets/photo_strip.dart';
import '../../widgets/primary_button.dart';

/// 地图找车页（架构 §4③ / PRD §4.4）。
///
/// 冷启动策略（≤3 秒可见）：**先渲染地图 + 橙色「我的车」图钉**（数据来自本地
/// 记录，毫秒级），「我的位置」走骨架态，定位流到达后再刷新蓝点并自动取景。
/// 顶部胶囊浮层给出 P1-1 的「车在东北方向 · 230 米」+ 方向箭头；
/// 底部照片条可点开全屏浏览；「找到了，归档」把记录转为历史并返回首页。
///
/// **合规**：地图创建前先过 [AmapSdkGate.ensureReady]（`ready` 为 false 时展示
/// 令牌化占位并引导去同意，绝不初始化高德 SDK）。
class MapFindPage extends ConsumerStatefulWidget {
  /// 创建找车页。[record] 为目标记录（由首页「最近一次记录」卡传入）。
  const MapFindPage({super.key, required this.record});

  /// 目标停车记录。
  final ParkingRecord record;

  @override
  ConsumerState<MapFindPage> createState() => _MapFindPageState();
}

class _MapFindPageState extends ConsumerState<MapFindPage> {
  late final LocationService _locationService;

  StreamSubscription<PositionFix>? _fixSub;
  StreamSubscription<double>? _headingSub;

  AMapController? _mapController;

  /// 「我的车」自定义图钉（资源字节转换而来）；加载失败时为 null → 回退系统默认橙色图钉。
  ///
  /// 图钉尖已对齐素材画布底部中心，与 `Marker` 默认 anchor `Offset(0.5, 1.0)` 匹配，
  /// 因此**不要**改 `Marker` 的 anchor，也不要再放大素材（native 侧不按 DPR 缩放）。
  BitmapDescriptor? _bikeMarkerIcon;

  PositionFix? _myFix;
  bool _locFailed = false;
  double? _heading;
  bool _fitted = false;
  bool _archiving = false;
  Set<Marker> _markers = <Marker>{};

  @override
  void initState() {
    super.initState();
    _locationService = ref.read(locationServiceProvider);
    _rebuildMarkers();
    _loadBikeMarkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStreams());
  }

  /// 异步加载「我的车」自定义图钉；失败静默（保留系统默认橙色图钉）。
  Future<void> _loadBikeMarkerIcon() async {
    try {
      final ByteData data =
          await rootBundle.load('assets/images/marker_bike.png');
      final BitmapDescriptor icon =
          BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      if (!mounted) {
        return;
      }
      setState(() {
        _bikeMarkerIcon = icon;
        _rebuildMarkers();
      });
    } catch (error, stack) {
      // 资源加载失败：保留系统默认橙色图钉，不让找车页挂掉。
      unawaited(
        diagnosticsService.logError(
          error,
          stack: stack,
          tag: 'bikeMarkerIcon',
        ),
      );
    }
  }

  @override
  void dispose() {
    _fixSub?.cancel();
    _headingSub?.cancel();
    try {
      _locationService.stopWatch();
    } catch (error, stack) {
      // 停止定位是平台调用；失败只落诊断日志，绝不能在 dispose 里冒泡成闪退。
      unawaited(
        diagnosticsService.logError(error, stack: stack, tag: 'stopWatch'),
      );
    }
    super.dispose();
  }

  void _startStreams() {
    if (!mounted) {
      return;
    }
    if (!ref.read(amapSdkGateProvider).ready) {
      return;
    }
    try {
      _fixSub = _locationService.watchFix().listen(
        (PositionFix fix) {
          if (!mounted) {
            return;
          }
          setState(() {
            _myFix = fix;
            _locFailed = false;
          });
          _rebuildMarkers();
          _maybeFitToBoth();
        },
        onError: (Object error, StackTrace stack) {
          unawaited(
            diagnosticsService.logError(
              error,
              stack: stack,
              tag: 'watchFix',
            ),
          );
          if (mounted) {
            setState(() => _locFailed = true);
          }
        },
        cancelOnError: true,
      );
    } catch (error, stack) {
      unawaited(
        diagnosticsService.logError(error, stack: stack, tag: 'watchFix'),
      );
      if (mounted) {
        setState(() => _locFailed = true);
      }
    }
    try {
      _headingSub = ref.read(compassServiceProvider).headingStream().listen(
        (double heading) {
          if (mounted) {
            setState(() => _heading = heading);
          }
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // 无指南针（如平板）：箭头退化为按真北方位显示。
    }
  }

  /// 重建地图标记（缓存实例，避免每次 build 生成新 id 触发无谓刷新）。
  void _rebuildMarkers() {
    final ParkingRecord record = widget.record;
    final Set<Marker> markers = <Marker>{};
    if (record.hasLocation) {
      markers.add(
        Marker(
          position: LatLng(record.latitude, record.longitude),
          icon: _bikeMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindowEnable: false,
          zIndex: 2,
        ),
      );
    }
    final PositionFix? me = _myFix;
    if (me != null) {
      markers.add(
        Marker(
          position: LatLng(me.latitude, me.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindowEnable: false,
          zIndex: 1,
        ),
      );
    }
    _markers = markers;
  }

  LatLng _initialTarget() {
    final ParkingRecord record = widget.record;
    return record.hasLocation
        ? LatLng(record.latitude, record.longitude)
        : const LatLng(39.909187, 116.397451);
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = ref.watch(amapSdkGateProvider).ready;
    final ParkingRecord record = widget.record;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ready ? _buildMap() : _buildMapUnavailable(),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(record),
                const Spacer(),
                _buildBottom(record),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // P1-3：夜间（深色模式）切换地图暗色样式，避免浅色底图与深色 UI 割裂。
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AMapWidget(
      privacyStatement: const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      mapType: dark ? MapType.night : MapType.normal,
      initialCameraPosition: CameraPosition(target: _initialTarget(), zoom: 16),
      markers: _markers,
      scaleEnabled: false,
      compassEnabled: false,
      onMapCreated: (AMapController controller) {
        _mapController = controller;
        try {
          _maybeFitToBoth();
        } catch (error, stack) {
          unawaited(
            diagnosticsService.logError(
              error,
              stack: stack,
              tag: 'onMapCreated',
            ),
          );
        }
      },
    );
  }

  Widget _buildMapUnavailable() {
    final TextTheme text = Theme.of(context).textTheme;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.map_outlined, size: 44, color: AppColors.primary),
              const SizedBox(height: 14),
              Text('地图需在同意隐私政策后显示', style: text.bodyMedium),
              const SizedBox(height: 6),
              Text('返回首页同意后即可使用找车地图', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ParkingRecord record) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: '返回',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoCapsule(record),
        ],
      ),
    );
  }

  Widget _buildInfoCapsule(ParkingRecord record) {
    final TextTheme text = Theme.of(context).textTheme;
    final PositionFix? me = _myFix;
    final bool hasBoth = me != null && record.hasLocation;

    late final String directionLine;
    double? arrowDeg;
    if (hasBoth) {
      final double bearing = GeoUtils.bearingDeg(me.point, record.point);
      final double meters = GeoUtils.distanceMeters(me.point, record.point);
      directionLine =
          '车在${GeoUtils.compassText(bearing)}方向 · ${GeoUtils.formatDistance(meters)}';
      arrowDeg = CompassService.arrowRotationDeg(
        bearingDeg: bearing,
        headingDeg: _heading ?? 0,
      );
    } else if (_locFailed) {
      directionLine = '定位暂不可用，先看照片认车';
    } else {
      directionLine = '正在确定你的位置…';
    }

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            if (arrowDeg != null) ...<Widget>[
              Transform.rotate(
                angle: arrowDeg * math.pi / 180.0,
                child: const Icon(
                  Icons.navigation,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
            ] else ...<Widget>[
              const Icon(Icons.my_location, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    directionLine,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${TimeUtils.formatFriendly(record.createdAt)} · '
                    '${record.poiName ?? '未知地点'}',
                    style: text.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottom(ParkingRecord record) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (record.photoPaths.isNotEmpty) ...<Widget>[
            Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              elevation: 2,
              shadowColor: AppColors.shadow,
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PhotoStrip(photoPaths: record.photoPaths),
              ),
            ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: '找到了，归档',
            icon: Icons.check_circle_outline,
            onPressed: _archiving ? null : _archive,
          ),
        ],
      ),
    );
  }

  // ---------- 取景 / 归档 ----------

  void _maybeFitToBoth() {
    final AMapController? controller = _mapController;
    final PositionFix? me = _myFix;
    final ParkingRecord record = widget.record;
    if (_fitted || controller == null || me == null || !record.hasLocation) {
      return;
    }
    _fitted = true;
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        math.min(me.latitude, record.latitude),
        math.min(me.longitude, record.longitude),
      ),
      northeast: LatLng(
        math.max(me.latitude, record.latitude),
        math.max(me.longitude, record.longitude),
      ),
    );
    // 双点取景：一次把「我」与「车」纳入视野。
    // `moveCamera` 是异步平台调用，成功/失败都必须静默（绝不能冒泡成闪退）。
    try {
      controller
          .moveCamera(CameraUpdate.newLatLngBounds(bounds, 80))
          .catchError((Object error, StackTrace stack) {
        unawaited(
          diagnosticsService.logError(error, stack: stack, tag: 'moveCamera'),
        );
        return false;
      });
    } catch (error, stack) {
      unawaited(
        diagnosticsService.logError(error, stack: stack, tag: 'moveCamera'),
      );
    }
  }

  Future<void> _archive() async {
    setState(() => _archiving = true);
    await ref.read(parkingControllerProvider.notifier).archive(widget.record.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// 圆形图标按钮（浮于地图之上的令牌化小控件）。
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: AppColors.textPrimary,
        onPressed: onPressed,
      ),
    );
  }
}
