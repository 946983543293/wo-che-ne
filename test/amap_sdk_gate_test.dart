import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/repositories/settings_repository.dart';
import 'package:wo_che_ne/services/amap_sdk_gate.dart';

/// 轻量假设置仓储：内存持有一份 [AppSettings]，可断言「同意状态是否落库」。
///
/// 刻意不用 mocktail：本组用例关注的是「同意状态 → 是否初始化 SDK」的行为，
/// 用一个可读的假实现比逐条 `when(...)` 更清晰，也避免 `registerFallbackValue`。
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this._current);

  AppSettings _current;

  /// 当前（内存）设置快照。
  AppSettings get current => _current;

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<void> save(AppSettings settings) async => _current = settings;
}

void main() {
  /// 记录「真实初始化动作」是否被触发的探头。
  late bool initialized;

  Future<void> fakeInitializer() async {
    initialized = true;
  }

  setUp(() => initialized = false);

  group('AmapSdkGate 合规门（未同意不得初始化）', () {
    test('未同意时 ensureReady() 抛 SdkNotReadyException', () {
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(AppSettings(privacyAgreed: false));
      final AmapSdkGate gate =
          AmapSdkGate(settings: settings, initializer: fakeInitializer);

      expect(gate.ready, isFalse);
      expect(
        gate.ensureReady,
        throwsA(isA<SdkNotReadyException>()),
      );
      // 未就绪不应触发任何真实初始化动作。
      expect(initialized, isFalse);
    });

    test('initIfAgreed() 未同意：保持未就绪且不初始化 SDK', () async {
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(AppSettings(privacyAgreed: false));
      final AmapSdkGate gate =
          AmapSdkGate(settings: settings, initializer: fakeInitializer);

      await gate.initIfAgreed();

      expect(gate.ready, isFalse);
      expect(initialized, isFalse);
      expect(
        gate.ensureReady,
        throwsA(isA<SdkNotReadyException>()),
      );
    });

    test('initIfAgreed() 已同意：初始化 SDK 并转为就绪', () async {
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(AppSettings(privacyAgreed: true));
      final AmapSdkGate gate =
          AmapSdkGate(settings: settings, initializer: fakeInitializer);

      await gate.initIfAgreed();

      expect(gate.ready, isTrue);
      expect(initialized, isTrue);
      expect(gate.ensureReady, returnsNormally);
    });
  });

  group('AmapSdkGate 同意流程', () {
    test('agreeAndInit() 落库同意状态、初始化 SDK 并转为就绪', () async {
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(AppSettings(privacyAgreed: false));
      final AmapSdkGate gate =
          AmapSdkGate(settings: settings, initializer: fakeInitializer);

      await gate.agreeAndInit();

      expect(gate.ready, isTrue);
      expect(initialized, isTrue);
      expect(settings.current.privacyAgreed, isTrue);
      expect(settings.current.privacyAgreedAt, isNotNull);
      expect(gate.ensureReady, returnsNormally);
    });

    test('agreeAndInit() 幂等：重复调用不报错且保持就绪', () async {
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(AppSettings(privacyAgreed: false));
      final AmapSdkGate gate =
          AmapSdkGate(settings: settings, initializer: fakeInitializer);

      await gate.agreeAndInit();
      final DateTime? firstAgreedAt = settings.current.privacyAgreedAt;

      await gate.agreeAndInit();

      expect(gate.ready, isTrue);
      expect(settings.current.privacyAgreed, isTrue);
      // 同意时间在首次同意时已写入；幂等调用不应清空它。
      expect(settings.current.privacyAgreedAt, isNotNull);
      expect(settings.current.privacyAgreedAt, isNotNull);
      expect(firstAgreedAt, isNotNull);
    });
  });
}
