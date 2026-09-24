import 'dart:async';

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/utils/geo_utils.dart';
import 'amap_sdk_gate.dart';

/// 定位结果（架构 §3.2 `PositionFix`）。
///
/// 与高德坐标系（GCJ-02）一致；[poiName] 来自逆地理，可为 null。
class PositionFix {
  /// 构造定位结果。
  const PositionFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.poiName,
  });

  /// 纬度（GCJ-02）。
  final double latitude;

  /// 经度（GCJ-02）。
  final double longitude;

  /// 定位精度（米）；不可用时为 null。
  final double? accuracy;

  /// 逆地理地点名；未取到时为 null。
  final String? poiName;

  /// 坐标点，供 [GeoUtils] 计算方位角/距离。
  GeoPoint get point => GeoPoint(latitude, longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionFix &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracy == other.accuracy &&
          poiName == other.poiName;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy, poiName);

  @override
  String toString() =>
      'PositionFix($latitude, $longitude, accuracy: $accuracy, poi: $poiName)';
}

/// 定位失败时抛出的类型化异常（架构 §7.6 错误处理约定）。
class LocationFailedException implements Exception {
  /// 构造异常。[errorCode] / [errorInfo] 取自高德定位 SDK 的错误码与描述。
  const LocationFailedException(
    this.message, {
    this.errorCode,
    this.errorInfo,
  });

  /// 人类可读的失败原因。
  final String message;

  /// 高德定位错误码（见高德错误码表）。
  final int? errorCode;

  /// 高德返回的错误描述。
  final String? errorInfo;

  @override
  String toString() => 'LocationFailedException: $message'
      '${errorCode == null ? '' : ' (code=$errorCode)'}'
      '${errorInfo == null ? '' : ' $errorInfo'}';
}

/// 高德融合定位封装（架构 §3.2 `LocationService`）。
///
/// 所有方法调用前先过 [AmapSdkGate.ensureReady]（合规红线）。
/// 单次定位用于「记下车位」，流式定位用于找车页「我的位置」。
class LocationService {
  /// 注入合规门。
  LocationService({required this._gate});

  final AmapSdkGate _gate;
  AMapFlutterLocation? _client;

  /// 插件 EventChannel 结果的**转发总线**（broadcast，可多播给单次/流式两处）。
  ///
  /// 为什么需要它：vendored 高德插件的 `AMapFlutterLocation.onLocationChanged()`
  /// 返回的是**单订阅**流，反复调用并 listen 会抛
  /// `Bad state: Stream has already been listened to`。这里只订阅一次，
  /// 再把事件转进 broadcast 控制器，供 [getCurrentFix] 与 [watchFix] 复用。
  final StreamController<Map<String, Object>> _events =
      StreamController<Map<String, Object>>.broadcast();

  /// 插件流 → [_events] 的桥接订阅（[dispose] 时取消）。
  StreamSubscription<Map<String, Object>>? _bridgeSub;

  /// 单次定位，取当前坐标（含逆地理地点名与精度）。
  ///
  /// [timeout] 到期未拿到有效坐标则抛 [LocationFailedException]。
  Future<PositionFix> getCurrentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _gate.ensureReady();
    final AMapFlutterLocation client = _ensureClient();
    client.setLocationOption(
      AMapLocationOption(
        needAddress: true,
        onceLocation: true,
        locationMode: AMapLocationMode.Hight_Accuracy,
        locationInterval: 1000,
      ),
    );

    final Completer<PositionFix> completer = Completer<PositionFix>();
    final StreamSubscription<Map<String, Object>> subscription =
        _events.stream.listen(
      (Map<String, Object> event) {
        if (completer.isCompleted) {
          return;
        }
        final int? code = _errorCode(event);
        if (code != null) {
          completer.completeError(
            LocationFailedException(
              '定位失败',
              errorCode: code,
              errorInfo: event['errorInfo']?.toString(),
            ),
          );
        } else {
          completer.complete(_toFix(event));
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(
            LocationFailedException('定位流异常：$error'),
          );
        }
      },
    );

    client.startLocation();
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw const LocationFailedException('定位超时，请到空旷处重试'),
      );
    } finally {
      client.stopLocation();
      await subscription.cancel();
    }
  }

  /// 持续定位流，用于找车页实时刷新「我的位置」。
  ///
  /// 返回**多订阅**流（同一份插件回调经 [_events] 广播）；
  /// 定位出错时以 [LocationFailedException] 作为流错误发出。
  Stream<PositionFix> watchFix({
    Duration interval = const Duration(seconds: 2),
  }) {
    _gate.ensureReady();
    final AMapFlutterLocation client = _ensureClient();
    client.setLocationOption(
      AMapLocationOption(
        needAddress: false,
        onceLocation: false,
        locationMode: AMapLocationMode.Hight_Accuracy,
        locationInterval: interval.inMilliseconds,
      ),
    );
    client.startLocation();
    return _events.stream.map<PositionFix>(
      (Map<String, Object> event) {
        final int? code = _errorCode(event);
        if (code != null) {
          throw LocationFailedException(
            '定位失败',
            errorCode: code,
            errorInfo: event['errorInfo']?.toString(),
          );
        }
        return _toFix(event);
      },
    );
  }

  /// 停止持续定位（找车页销毁时调用；不销毁客户端，便于复用）。
  void stopWatch() {
    _client?.stopLocation();
  }

  /// 是否已取得定位权限（**只查询、不申请**，遵循「按需申请」约定）。
  Future<bool> hasPermission() async {
    try {
      return (await Permission.location.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 尽力取一次定位：无权限、SDK 未就绪或定位失败一律返回 null。
  ///
  /// 用于历史列表「距当前位置」这类**非关键**信息——失败即隐藏，绝不打扰用户。
  Future<PositionFix?> tryGetCurrentFix() async {
    if (!await hasPermission()) {
      return null;
    }
    try {
      return await getCurrentFix();
    } catch (_) {
      return null;
    }
  }

  /// 释放定位客户端（页面销毁时调用）。
  void dispose() {
    _bridgeSub?.cancel();
    _bridgeSub = null;
    _client?.destroy();
    _client = null;
  }

  /// 惰性创建高德客户端，并**立即订阅一次**定位回调流。
  ///
  /// 顺序至关重要（Bug「无法定位」根因之一）：vendored 插件在**第一次**
  /// `setLocationOption`/`startLocation` 等方法调用时才会创建 native 的
  /// `AMapLocationClientImpl`，因此必须先让 Dart 侧 `listen`（触发 native
  /// `onListen` 填好 EventSink），再发任何方法调用，否则首个定位请求的结果
  /// 会被 native 全部丢弃 → 15 秒超时 → 「定位失败」。
  AMapFlutterLocation _ensureClient() {
    final AMapFlutterLocation? existing = _client;
    if (existing != null) {
      return existing;
    }
    final AMapFlutterLocation client = AMapFlutterLocation();
    _client = client;
    _bridgeSub = client.onLocationChanged().listen(
      (Map<String, Object> event) {
        if (!_events.isClosed) {
          _events.add(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_events.isClosed) {
          _events.addError(error, stack);
        }
      },
      cancelOnError: false,
    );
    return client;
  }

  /// 解析高德回调：错误码非 0 视为失败，返回错误码；否则返回 null。
  static int? _errorCode(Map<String, Object> event) {
    final Object? raw = event['errorCode'];
    final int? code = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (code == null || code == 0) {
      return null;
    }
    return code;
  }

  static PositionFix _toFix(Map<String, Object> event) {
    final double? latitude = _toDouble(event['latitude']);
    final double? longitude = _toDouble(event['longitude']);
    if (latitude == null || longitude == null) {
      throw const LocationFailedException('定位结果缺少经纬度');
    }
    final String? poi = _firstNonEmpty(<Object?>[
      event['poiName'],
      event['description'],
      event['address'],
    ]);
    return PositionFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: _toDouble(event['accuracy']),
      poiName: poi,
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String? _firstNonEmpty(List<Object?> candidates) {
    for (final Object? candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }
}
