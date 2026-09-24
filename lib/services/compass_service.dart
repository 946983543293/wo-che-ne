import 'package:flutter_compass_v2/flutter_compass_v2.dart';

/// 指南针朝向服务（架构 §3.2 `CompassService`，P1-1 方向箭头）。
///
/// 只做两件事：
/// 1. 把设备朝向（磁北为 0°、顺时针，单位度）以流的形式给出；
/// 2. 提供**纯函数** [arrowRotationDeg]，把「车相对我的方位角」换算成方向箭头
///    UI 需要的旋转角（= 方位角 − 设备朝向），无需传感器即可单测。
class CompassService {
  /// 设备朝向流（度，0=北，顺时针，已归一化到 [0, 360)）。
  ///
  /// 设备无磁力计或平台不支持时返回空流；UI 侧退化为「按真北方位」显示箭头。
  Stream<double> headingStream() {
    final Stream<CompassEvent>? events = FlutterCompass.events;
    if (events == null) {
      return const Stream<double>.empty();
    }
    return events
        .map((CompassEvent event) => event.heading)
        .where((double? heading) => heading != null && heading.isFinite)
        .map((double? heading) => normalizeDegrees(heading!));
  }

  /// 方向箭头应旋转的角度（度，顺时针）。
  ///
  /// 含义：手机顶端正对目标方向时箭头朝上（旋转 0°）。
  /// 即 `箭头角 = 目标方位角 − 设备朝向`，再归一化到 [0, 360)。
  static double arrowRotationDeg({
    required double bearingDeg,
    double headingDeg = 0,
  }) =>
      normalizeDegrees(bearingDeg - headingDeg);

  /// 将任意角度归一化到 [0, 360)。
  static double normalizeDegrees(double degrees) {
    final double mod = degrees % 360.0;
    return mod < 0 ? mod + 360.0 : mod;
  }
}
