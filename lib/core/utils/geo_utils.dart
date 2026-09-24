import 'dart:math' as math;

/// 地理坐标点（纬度/经度，WGS-84 或 GCJ-02 均可——本工具只做相对计算）。
///
/// 纯值对象，不依赖任何插件/平台，便于单测。
/// `ParkingRecord`（车位）与 `PositionFix`（我的位置）都通过 `point` 暴露本类型。
class GeoPoint {
  /// 构造一个地理坐标点。
  const GeoPoint(this.latitude, this.longitude);

  /// 纬度（度）。
  final double latitude;

  /// 经度（度）。
  final double longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// 地理计算工具（架构 §3.2 `GeoUtils`，纯函数、零依赖）。
///
/// 覆盖 P1-1 方向箭头所需的两项计算：两坐标方位角、直线距离；
/// 以及配套的人类可读文案（方向名、距离）。
abstract final class GeoUtils {
  GeoUtils._();

  /// 地球平均半径（米），用于 Haversine 距离计算。
  static const double earthRadiusMeters = 6371000.0;

  /// 8 方位中文名，索引 = 方位角 / 45° 四舍五入（0=北，顺时针）。
  static const List<String> _compassLabels = <String>[
    '北',
    '东北',
    '东',
    '东南',
    '南',
    '西南',
    '西',
    '西北',
  ];

  /// 计算 [from] 指向 [to] 的初始方位角（度，0–360，0=正北，顺时针为正）。
  ///
  /// 用于方向箭头：`箭头旋转角 = bearingDeg(我, 车) - headingDeg(手机朝向)`。
  static double bearingDeg(GeoPoint from, GeoPoint to) {
    final double fromLat = _radians(from.latitude);
    final double toLat = _radians(to.latitude);
    final double deltaLng = _radians(to.longitude - from.longitude);

    final double y = math.sin(deltaLng) * math.cos(toLat);
    final double x = math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);

    final double deg = _degrees(math.atan2(y, x));
    return (deg + 360.0) % 360.0;
  }

  /// 计算 [from] 与 [to] 之间的球面直线距离（米），Haversine 公式。
  static double distanceMeters(GeoPoint from, GeoPoint to) {
    final double fromLat = _radians(from.latitude);
    final double toLat = _radians(to.latitude);
    final double deltaLat = _radians(to.latitude - from.latitude);
    final double deltaLng = _radians(to.longitude - from.longitude);

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(fromLat) *
            math.cos(toLat) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// 将方位角（度）转成 8 方位中文文案，如 `东北`。
  ///
  /// 任意实数角度均可（会先归一化到 0–360）。
  static String compassText(double bearingDegrees) {
    final double normalized = _normalizeDegrees(bearingDegrees);
    final int index = (normalized / 45.0).round() % _compassLabels.length;
    return _compassLabels[index];
  }

  /// 将距离（米）格式化为人类可读文案，如 `230 米`、`1.2 公里`。
  ///
  /// 规则：< 1000 米 → 取整显示米；≥ 1000 米 → 保留 1 位小数显示公里；
  /// ≥ 10 公里 → 公里取整（避免「12.3 公里」的虚假精度）。
  static String formatDistance(double meters) {
    if (meters.isNaN || meters <= 0) {
      return '0 米';
    }
    if (meters < 1000) {
      return '${meters.round()} 米';
    }
    final double km = meters / 1000.0;
    if (km < 10) {
      return '${km.toStringAsFixed(1)} 公里';
    }
    return '${km.round()} 公里';
  }

  // ---------- 私有辅助 ----------

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static double _degrees(double radians) => radians * 180.0 / math.pi;

  static double _normalizeDegrees(double degrees) {
    final double mod = degrees % 360.0;
    return mod < 0 ? mod + 360.0 : mod;
  }
}
