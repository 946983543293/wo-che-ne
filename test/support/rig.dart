// T03 QA 独立验证 —— widget test 装配脚手架。
//
// `flutter test` 环境中平台通道无宿主：未注册 mock 的 MethodChannel 调用不会完成
// （表现为流程挂起，而非抛异常）。因此这里统一为 permission_handler 注册 mock，
// 并用内存替身覆盖 haptic（避免 Vibration 通道阻塞保存流程）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/state/providers.dart';

import 'fakes.dart';

/// permission_handler 的方法通道名（见 permission_handler_platform_interface）。
const MethodChannel kPermissionChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

/// PermissionStatus 数值：0=denied，1=granted。
const int kDenied = 0;
const int kGranted = 1;

/// `Permission.value`：camera=1，location=3。
const int _kCameraValue = 1;
const int _kLocationValue = 3;

/// 注册权限通道 mock（默认全部「拒绝」，即降级路径）。
void installPermissionMock({int location = kDenied, int camera = kDenied}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(kPermissionChannel, (MethodCall call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        if (call.arguments == _kLocationValue) return location;
        if (call.arguments == _kCameraValue) return camera;
        return kDenied;
      case 'requestPermissions':
        final List<dynamic> ids = call.arguments as List<dynamic>;
        return ids
            .map((dynamic id) =>
                id == _kLocationValue ? location : (id == _kCameraValue ? camera : kDenied))
            .toList();
      case 'shouldShowRequestPermissionRationale':
        return false;
      case 'checkServiceStatus':
        return 1;
      case 'openAppSettings':
        return true;
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kPermissionChannel, null);
  });
}

/// 泵若干固定帧：用于屏幕上存在「加载指示器 / 未定动画」时替代 `pumpAndSettle`。
Future<void> pumpFrames(WidgetTester tester, [int times = 10]) async {
  for (int i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 组装被测 App：注入内存假仓储 + 临时目录 LocalStore + 静默震动服务。
Widget buildApp({
  required FakeSettingsRepository settings,
  required FakeParkingRepository parking,
  required Directory root,
}) =>
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(settings),
        parkingRepositoryProvider.overrideWithValue(parking),
        amapSdkGateProvider.overrideWithValue(
          AmapSdkGate(settings: settings, initializer: () async {}),
        ),
        localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
        hapticServiceProvider.overrideWithValue(SilentHapticService()),
      ],
      child: const WoCheNeApp(),
    );
