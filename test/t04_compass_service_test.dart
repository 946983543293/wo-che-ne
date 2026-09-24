// T04 —— P1-1 方向箭头：指南针朝向服务（纯函数，无需传感器）。

import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/services/compass_service.dart';

void main() {
  group('CompassService.normalizeDegrees', () {
    test('归一化到 [0, 360)：负角回卷、越界取模', () {
      expect(CompassService.normalizeDegrees(0), 0);
      expect(CompassService.normalizeDegrees(359), 359);
      expect(CompassService.normalizeDegrees(360), 0);
      expect(CompassService.normalizeDegrees(-90), 270);
      expect(CompassService.normalizeDegrees(450), 90);
    });
  });

  group('CompassService.arrowRotationDeg（箭头角 = 目标方位角 − 设备朝向）', () {
    test('手机正北（朝向 0）、目标正东（方位 90）→ 箭头右转 90°', () {
      expect(
        CompassService.arrowRotationDeg(bearingDeg: 90, headingDeg: 0),
        90,
      );
    });

    test('手机朝东（90）、目标正东（90）→ 箭头朝上 0°（目标在正前方）', () {
      expect(
        CompassService.arrowRotationDeg(bearingDeg: 90, headingDeg: 90),
        0,
      );
    });

    test('跨 0° 回卷：目标正北（0）、手机朝西（270）→ 90°', () {
      expect(
        CompassService.arrowRotationDeg(bearingDeg: 0, headingDeg: 270),
        90,
      );
    });

    test('朝向参数缺省 → 按真北（0）处理', () {
      expect(CompassService.arrowRotationDeg(bearingDeg: 200), 200);
    });
  });
}
