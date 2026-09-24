import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceMeters', () {
    test('1 度纬度差约等于 111.19 公里', () {
      final double d = GeoUtils.distanceMeters(
        const GeoPoint(0, 0),
        const GeoPoint(1, 0),
      );
      expect(d, closeTo(111194.93, 1.0));
    });

    test('同一点距离为 0', () {
      expect(
        GeoUtils.distanceMeters(const GeoPoint(31.23, 121.47),
            const GeoPoint(31.23, 121.47)),
        0.0,
      );
    });

    test('两点互换距离对称', () {
      const GeoPoint a = GeoPoint(31.2304, 121.4737);
      const GeoPoint b = GeoPoint(31.2404, 121.4837);
      expect(
        GeoUtils.distanceMeters(a, b),
        closeTo(GeoUtils.distanceMeters(b, a), 1e-6),
      );
    });
  });

  group('GeoUtils.bearingDeg', () {
    test('正北 / 正东 / 正南 / 正西', () {
      expect(
        GeoUtils.bearingDeg(const GeoPoint(0, 0), const GeoPoint(1, 0)),
        closeTo(0, 0.01),
      );
      expect(
        GeoUtils.bearingDeg(const GeoPoint(0, 0), const GeoPoint(0, 1)),
        closeTo(90, 0.01),
      );
      expect(
        GeoUtils.bearingDeg(const GeoPoint(0, 0), const GeoPoint(-1, 0)),
        closeTo(180, 0.01),
      );
      expect(
        GeoUtils.bearingDeg(const GeoPoint(0, 0), const GeoPoint(0, -1)),
        closeTo(270, 0.01),
      );
    });

    test('东北方向约 45 度', () {
      expect(
        GeoUtils.bearingDeg(const GeoPoint(0, 0), const GeoPoint(1, 1)),
        closeTo(45, 0.1),
      );
    });

    test('结果始终落在 0–360', () {
      final double b = GeoUtils.bearingDeg(
        const GeoPoint(31.2, 121.4),
        const GeoPoint(30.9, 121.1),
      );
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    });
  });

  group('GeoUtils.compassText', () {
    test('8 方位映射正确', () {
      expect(GeoUtils.compassText(0), '北');
      expect(GeoUtils.compassText(45), '东北');
      expect(GeoUtils.compassText(90), '东');
      expect(GeoUtils.compassText(135), '东南');
      expect(GeoUtils.compassText(180), '南');
      expect(GeoUtils.compassText(225), '西南');
      expect(GeoUtils.compassText(270), '西');
      expect(GeoUtils.compassText(315), '西北');
    });

    test('越界角度归一化', () {
      expect(GeoUtils.compassText(360), '北');
      expect(GeoUtils.compassText(-90), '西');
      expect(GeoUtils.compassText(450), '东');
      expect(GeoUtils.compassText(350), '北');
    });
  });

  group('GeoUtils.formatDistance', () {
    test('米/公里文案', () {
      expect(GeoUtils.formatDistance(0), '0 米');
      expect(GeoUtils.formatDistance(230), '230 米');
      expect(GeoUtils.formatDistance(999), '999 米');
      expect(GeoUtils.formatDistance(1000), '1.0 公里');
      expect(GeoUtils.formatDistance(1234), '1.2 公里');
      expect(GeoUtils.formatDistance(11200), '11 公里');
    });

    test('非法输入回退为 0 米', () {
      expect(GeoUtils.formatDistance(-5), '0 米');
      expect(GeoUtils.formatDistance(double.nan), '0 米');
    });
  });

  group('GeoPoint', () {
    test('值相等语义', () {
      expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
      expect(const GeoPoint(1, 2).hashCode, const GeoPoint(1, 2).hashCode);
      expect(const GeoPoint(1, 2) == const GeoPoint(2, 1), isFalse);
    });
  });
}
