import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 「我车呢」主行动按钮（PRD §5：高 64dp、主色填充、白色粗体字、按压小动效）。
///
/// 视觉完全交给 `ElevatedButtonTheme`（主色填充 + 大圆角），本组件只补：
/// ① 可选前置图标；② 按下时 0.97 缩放的克制反馈（150ms 缓动）。
/// 用 [Listener] 监听指针事件而不消费手势，保证按钮本身的点击不受影响。
class PrimaryButton extends StatefulWidget {
  /// 创建主按钮。
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调；为 null 时按钮呈禁用态。
  final VoidCallback? onPressed;

  /// 可选前置图标。
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppTokens.motionFast,
        curve: Curves.easeOut,
        child: SizedBox(
          height: AppTokens.primaryButtonHeight,
          width: double.infinity,
          child: widget.icon == null
              ? ElevatedButton(
                  onPressed: widget.onPressed,
                  child: Text(widget.label),
                )
              : ElevatedButton.icon(
                  onPressed: widget.onPressed,
                  icon: Icon(widget.icon),
                  label: Text(widget.label),
                ),
        ),
      ),
    );
  }
}
