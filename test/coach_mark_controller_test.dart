import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/repositories/settings_repository.dart';
import 'package:wo_che_ne/state/coach_mark_controller.dart';
import 'package:wo_che_ne/state/providers.dart';

/// 内存假设置仓储：模拟一份可持久化的偏好，供引导状态机单测使用（零插件依赖）。
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this._current);

  AppSettings _current;

  AppSettings get current => _current;

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<void> save(AppSettings settings) async => _current = settings;
}

/// 建一个只覆盖设置仓储的 ProviderContainer，并在用例结束时销毁。
ProviderContainer _container(SettingsRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      settingsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// 取控制器并等待其 `build()` 完成。
Future<CoachMarkController> _boot(ProviderContainer container) async {
  final CoachMarkController controller =
      container.read(coachMarkControllerProvider.notifier);
  await container.read(coachMarkControllerProvider.future);
  return controller;
}

void main() {
  group('CoachMarkController 3 步状态机（架构 §4.6）', () {
    test('初始未看过：3 步都应显示', () async {
      final ProviderContainer container =
          _container(_FakeSettingsRepository(AppSettings()));
      final CoachMarkController controller = await _boot(container);

      expect(controller.shouldShow(1), isTrue);
      expect(controller.shouldShow(2), isTrue);
      expect(controller.shouldShow(3), isTrue);
    });

    test('完成第 1 步：仅第 1 步不再显示，且落库 seen', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository(AppSettings());
      final ProviderContainer container = _container(repo);
      final CoachMarkController controller = await _boot(container);

      await controller.completeStep(1);

      expect(controller.shouldShow(1), isFalse);
      expect(controller.shouldShow(2), isTrue);
      expect(controller.shouldShow(3), isTrue);
      expect(repo.current.guideStepsSeen, contains(1));
      expect(repo.current.guideDisabled, isFalse);
    });

    test('勾选「以后不再提示」：3 步全部永久关闭', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository(AppSettings());
      final ProviderContainer container = _container(repo);
      final CoachMarkController controller = await _boot(container);

      await controller.completeStep(2, neverAgain: true);

      expect(controller.shouldShow(1), isFalse);
      expect(controller.shouldShow(2), isFalse);
      expect(controller.shouldShow(3), isFalse);
      expect(repo.current.guideDisabled, isTrue);
      expect(repo.current.guideStepsSeen, contains(2));
    });

    test('reset：清空已看步号并解除永久关闭', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository(
        AppSettings(guideDisabled: true, guideStepsSeen: <int>{1, 2, 3}),
      );
      final ProviderContainer container = _container(repo);
      final CoachMarkController controller = await _boot(container);

      expect(controller.shouldShow(1), isFalse);

      await controller.reset();

      expect(controller.shouldShow(1), isTrue);
      expect(controller.shouldShow(2), isTrue);
      expect(controller.shouldShow(3), isTrue);
      expect(repo.current.guideDisabled, isFalse);
      expect(repo.current.guideStepsSeen, isEmpty);
    });

    test('从已有进度恢复：已看 1、2 → 仅第 3 步显示', () async {
      final ProviderContainer container = _container(
        _FakeSettingsRepository(AppSettings(guideStepsSeen: <int>{1, 2})),
      );
      final CoachMarkController controller = await _boot(container);

      expect(controller.shouldShow(1), isFalse);
      expect(controller.shouldShow(2), isFalse);
      expect(controller.shouldShow(3), isTrue);
    });

    test('进度持久化：completeStep 后新建容器仍记得', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository(AppSettings());

      final ProviderContainer first = _container(repo);
      await _boot(first);
      await first.read(coachMarkControllerProvider.notifier).completeStep(1);

      // 复用同一份「持久化」数据的第二个容器，模拟重启后恢复。
      final ProviderContainer second = _container(repo);
      final CoachMarkController controller = await _boot(second);

      expect(controller.shouldShow(1), isFalse);
      expect(controller.shouldShow(2), isTrue);
      expect(controller.shouldShow(3), isTrue);
    });
  });
}
