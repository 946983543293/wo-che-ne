import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';
import 'providers.dart';

/// 新手引导状态（架构 §4.6：3 步叠加引导 + 永久关闭总开关）。
///
/// 不可变值对象：只暴露「是否永久关闭」与「已看过的步号集合」两个事实。
class CoachMarkState {
  /// 构造引导状态。
  const CoachMarkState({required this.disabled, required this.seenSteps});

  /// 用户是否勾选过「以后不再提示」（永久关闭全部引导）。
  final bool disabled;

  /// 已完成的引导步号（1/2/3）。
  final Set<int> seenSteps;

  /// 初始状态：未关闭、未看过任何一步。
  static const CoachMarkState initial = CoachMarkState(
    disabled: false,
    seenSteps: <int>{},
  );

  /// 第 [step] 步是否应显示：未永久关闭且该步未看过。
  bool shouldShow(int step) => !disabled && !seenSteps.contains(step);

  /// 返回一份修改了指定字段的副本。
  CoachMarkState copyWith({bool? disabled, Set<int>? seenSteps}) =>
      CoachMarkState(
        disabled: disabled ?? this.disabled,
        seenSteps: seenSteps ?? this.seenSteps,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachMarkState &&
          runtimeType == other.runtimeType &&
          disabled == other.disabled &&
          _setEquals(seenSteps, other.seenSteps);

  @override
  int get hashCode => Object.hash(disabled, Object.hashAllUnordered(seenSteps));

  @override
  String toString() =>
      'CoachMarkState(disabled: $disabled, seenSteps: $seenSteps)';

  static bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// 新手引导控制器（架构 §3.2/§4.6）。
///
/// 状态机很克制：每步有「看过（[completeStep]）」与「以后不再提示（neverAgain）」
/// 两种收尾；[reset] 用于设置页「重新查看新手引导」。
/// 引导字段与其余设置共用同一份 [AppSettings]（`guideDisabled` + `guideStepsSeen`），
/// 读写都走 [SettingsRepository]，避免第二个事实来源。
class CoachMarkController extends AsyncNotifier<CoachMarkState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<CoachMarkState> build() async {
    final AppSettings s = await _repo.load();
    return CoachMarkState(
      disabled: s.guideDisabled,
      seenSteps: s.guideStepsSeen,
    );
  }

  /// 同步查询第 [step] 步是否应显示（加载中按「不显示」处理，避免闪现）。
  bool shouldShow(int step) => (state.valueOrNull ?? CoachMarkState.initial).shouldShow(step);

  /// 标记第 [step] 步已完成；[neverAgain] 为 true 时同时永久关闭全部引导。
  ///
  /// 幂等：重复调用只会在已看集合里重复加入同一步，不产生副作用。
  Future<void> completeStep(int step, {bool neverAgain = false}) async {
    final AppSettings current = await _repo.load();
    final Set<int> seen = <int>{...current.guideStepsSeen, step};
    final AppSettings next = current.copyWith(
      guideStepsSeen: seen,
      guideDisabled: neverAgain ? true : current.guideDisabled,
    );
    await _repo.save(next);
    state = AsyncData<CoachMarkState>(
      CoachMarkState(disabled: next.guideDisabled, seenSteps: next.guideStepsSeen),
    );
  }

  /// 重置引导：清空已看步号并解除「以后不再提示」（设置页「重新查看新手引导」）。
  Future<void> reset() async {
    final AppSettings current = await _repo.load();
    final AppSettings next = current.copyWith(
      guideDisabled: false,
      guideStepsSeen: const <int>{},
    );
    await _repo.save(next);
    state = const AsyncData<CoachMarkState>(CoachMarkState.initial);
  }
}
