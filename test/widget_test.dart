// 「我车呢」首页/合规门冒烟测试（T03）。
//
// 全部外部依赖（设置仓储 / 合规门 / 记录仓储）都用内存假实现注入，
// 不触发 shared_preferences / path_provider / permission_handler / 高德 等平台插件，
// 因此可在无设备环境下稳定运行。相机页与相机插件不在 widget 测试范围内。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/app.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';
import 'package:wo_che_ne/data/repositories/parking_repository.dart';
import 'package:wo_che_ne/data/repositories/settings_repository.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';
import 'package:wo_che_ne/state/providers.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this._current);

  AppSettings _current;

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<void> save(AppSettings settings) async => _current = settings;
}

class _EmptyParkingRepository implements ParkingRepository {
  @override
  Future<List<ParkingRecord>> loadAll() async => <ParkingRecord>[];

  @override
  Future<ParkingRecord?> latestActive() async => null;

  @override
  Future<ParkingRecord> save(ParkingRecord record) async => record;

  @override
  Future<void> update(ParkingRecord record) async {}

  @override
  Future<void> delete(String id) async {}
}

ProviderScope _appWith({
  required SettingsRepository settings,
}) {
  final AmapSdkGate gate =
      AmapSdkGate(settings: settings, initializer: () async {});
  return ProviderScope(
    overrides: <Override>[
      settingsRepositoryProvider.overrideWithValue(settings),
      amapSdkGateProvider.overrideWithValue(gate),
      parkingRepositoryProvider.overrideWithValue(_EmptyParkingRepository()),
    ],
    child: const WoCheNeApp(),
  );
}

void main() {
  testWidgets('首启未同意隐私政策：先弹合规同意框', (WidgetTester tester) async {
    await tester.pumpWidget(
      _appWith(settings: _FakeSettingsRepository(AppSettings())),
    );
    await tester.pumpAndSettle();

    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('暂不同意'), findsOneWidget);
    expect(find.text('查看《隐私政策》全文'), findsOneWidget);
  });

  testWidgets('已同意且无记录：显示停车态首页（标题 + 主按钮）', (WidgetTester tester) async {
    await tester.pumpWidget(
      _appWith(
        settings: _FakeSettingsRepository(
          // guideDisabled=true：跳过引导叠加层，稳定断言停车态主界面。
          AppSettings(privacyAgreed: true, guideDisabled: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我车呢'), findsOneWidget);
    expect(find.text('车停好了？'), findsOneWidget);
    expect(find.text('记下车位'), findsOneWidget);
  });
}
