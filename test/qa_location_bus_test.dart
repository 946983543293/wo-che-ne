// QA 独立验证（修复轮）—— Bug「无法定位」：定位回调总线复用回归。
//
// 背景（vendored 高德插件的两个坑）：
// 1. 插件 `AMapFlutterLocation.onLocationChanged()` 返回的是**单订阅**流
//    （内部 `StreamController()`），第二次 listen 会抛
//    `Bad state: Stream has already been listened to`；
// 2. native 侧 `AMapLocationClientImpl` 在**第一次**方法调用时才被创建，而
//    EventChannel 的 EventSink 要等 Dart 侧先 listen 才就绪 —— 顺序反了首个
//    定位结果会被永久丢弃（表现为 15 秒超时「定位失败」）。
//
// 修复：Dart 侧只订阅一次，把事件转进 `LocationService._events`（broadcast）
// 供 `getCurrentFix` / `watchFix` 复用；且订阅必须早于任何方法调用。
//
// 本文件用 mock 的 MethodChannel / EventChannel 直接驱动 `LocationService`，
// 重点证伪**修复引入的回归点**：`getCurrentFix()` 的 finally 里有
// `client.stopLocation()` + `subscription.cancel()`，会不会把总线掐断，
// 导致同一实例第二次调用定位永远拿不到结果。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/services/location_service.dart';

import 'support/fakes.dart';

const String _methodChannelName = 'amap_flutter_location';
const String _streamChannelName = 'amap_flutter_location_stream';
const StandardMethodCodec _codec = StandardMethodCodec();

/// 平台通道调用顺序日志：`m:<方法名>` / `s:<listen|cancel>`。
final List<String> _callLog = <String>[];

/// 从 `setLocationOption` 入参里截获的 pluginKey（插件按它过滤回调）。
String? _pluginKey;

/// EventChannel `listen` 被触发的次数。
int _streamListenCount = 0;

void _installChannelMocks() {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel(_methodChannelName),
    (MethodCall call) async {
      _callLog.add('m:${call.method}');
      final Object? args = call.arguments;
      if (call.method == 'setLocationOption' && args is Map<Object?, Object?>) {
        final Object? key = args['pluginKey'];
        if (key != null) {
          _pluginKey = key.toString();
        }
      }
      return null;
    },
  );

  messenger.setMockMessageHandler(
    _streamChannelName,
    (ByteData? message) async {
      final MethodCall call = _codec.decodeMethodCall(message);
      _callLog.add('s:${call.method}');
      if (call.method == 'listen') {
        _streamListenCount++;
        return _codec.encodeSuccessEnvelope(null);
      }
      if (call.method == 'cancel') {
        return _codec.encodeSuccessEnvelope(null);
      }
      return null;
    },
  );

  addTearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(_methodChannelName), null);
    messenger.setMockMessageHandler(_streamChannelName, null);
  });
}

/// 模拟 native 侧回传一条定位结果（含 pluginKey，否则被插件过滤掉）。
Future<void> _pushFix({
  double lat = 39.9,
  double lng = 116.3,
  int errorCode = 0,
}) {
  final Map<String, Object> event = <String, Object>{
    'pluginKey': _pluginKey ?? '',
    'latitude': lat,
    'longitude': lng,
    'accuracy': 12.0,
    'poiName': '图书馆北',
    'errorCode': errorCode,
  };
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    _streamChannelName,
    _codec.encodeSuccessEnvelope(event),
    null,
  );
}

void main() {
  late FakeSettingsRepository settings;
  late AmapSdkGate gate;

  setUp(() {
    _callLog.clear();
    _pluginKey = null;
    _streamListenCount = 0;
    settings = FakeSettingsRepository(AppSettings(privacyAgreed: true));
    gate = AmapSdkGate(settings: settings, initializer: () async {});
    _installChannelMocks();
  });

  Future<LocationService> readyService() async {
    await gate.initIfAgreed();
    expect(gate.ready, isTrue);
    return LocationService(gate: gate);
  }

  testWidgets(
    'LOC-ORDER-1 先订阅回调流，再发 setLocationOption / startLocation（Bug1 根因）',
    (WidgetTester tester) async {
      final LocationService service = await readyService();
      await tester.runAsync<PositionFix?>(() async {
        final Future<PositionFix> pending = service.getCurrentFix();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _pushFix();
        return pending.timeout(const Duration(seconds: 3));
      });
      service.dispose();

      final int listen = _callLog.indexOf('s:listen');
      final int setOption = _callLog.indexOf('m:setLocationOption');
      final int start = _callLog.indexOf('m:startLocation');
      expect(listen, greaterThanOrEqualTo(0),
          reason: '未观察到 EventChannel listen —— 订阅根本没有发生');
      expect(_streamListenCount, 1, reason: '插件回调流只应订阅一次');
      expect(setOption, greaterThan(listen),
          reason: '订阅必须早于 setLocationOption，否则首个定位结果会被 native 丢弃');
      expect(start, greaterThan(listen),
          reason: '订阅必须早于 startLocation');
    },
  );

  testWidgets(
    'LOC-SEQ-1 同一实例连续两次 getCurrentFix() 都能拿到结果（修复引入的回归点）',
    (WidgetTester tester) async {
      final LocationService service = await readyService();
      final List<PositionFix>? fixes =
          await tester.runAsync<List<PositionFix>>(() async {
        final List<PositionFix> out = <PositionFix>[];
        for (int i = 1; i <= 2; i++) {
          final Future<PositionFix> pending = service.getCurrentFix();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await _pushFix(lat: 39.9 + i * 0.001, lng: 116.3 + i * 0.001);
          out.add(await pending.timeout(const Duration(seconds: 3)));
          // 让上一次调用的 finally（stopLocation + cancel）跑完。
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return out;
      });
      service.dispose();

      expect(fixes, hasLength(2),
          reason: '第二次定位必须仍能拿到结果 —— finally 不能掐断总线');
      expect(fixes![0].latitude, closeTo(39.901, 1e-6));
      expect(fixes[1].latitude, closeTo(39.902, 1e-6));
      expect(fixes[1].poiName, '图书馆北');
    },
  );

  testWidgets(
    'LOC-BUS-1 单次定位与持续定位可同时消费同一份回调（broadcast 总线）',
    (WidgetTester tester) async {
      final LocationService service = await readyService();
      final List<PositionFix> streamed = <PositionFix>[];
      PositionFix? once;
      await tester.runAsync<void>(() async {
        final StreamSubscription<PositionFix> sub =
            service.watchFix().listen(streamed.add);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final Future<PositionFix> pending = service.getCurrentFix();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _pushFix(lat: 40.0, lng: 116.4);
        once = await pending.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
      });
      service.dispose();

      expect(once, isNotNull);
      expect(once!.latitude, closeTo(40.0, 1e-6));
      expect(streamed, hasLength(1), reason: 'watchFix 也应收到同一次回调');
      expect(streamed.single.latitude, closeTo(40.0, 1e-6));
    },
  );

  testWidgets('LOC-ERR-1 高德返回非 0 errorCode → LocationFailedException',
      (WidgetTester tester) async {
    final LocationService service = await readyService();
    Object? caught;
    await tester.runAsync<void>(() async {
      final Future<PositionFix> pending = service.getCurrentFix();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _pushFix(errorCode: 12);
      try {
        await pending.timeout(const Duration(seconds: 3));
      } catch (error) {
        caught = error;
      }
    });
    service.dispose();

    expect(caught, isA<LocationFailedException>());
    expect((caught! as LocationFailedException).errorCode, 12);
  });

  testWidgets('LOC-ERR-2 超时未拿到坐标 → 抛定位超时异常（不挂死）',
      (WidgetTester tester) async {
    final LocationService service = await readyService();
    Object? caught;
    await tester.runAsync<void>(() async {
      final Future<PositionFix> pending = service.getCurrentFix(
        timeout: const Duration(milliseconds: 200),
      );
      try {
        await pending;
      } catch (error) {
        caught = error;
      }
    });
    service.dispose();

    expect(caught, isA<LocationFailedException>());
    expect(caught.toString(), contains('定位超时'));
  });
}
