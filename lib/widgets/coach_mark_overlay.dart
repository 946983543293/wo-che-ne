import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// 叠加式新手引导层（架构 §4.6 / PRD §4.6）。
///
/// 放在目标页面 `Stack` 的最上层，实现「界面压暗 + 主色描边圆角挖空高亮 + 箭头气泡」：
/// - 压暗层与命中阻拦用「挖空 + 四周矩形」实现——**挖空区不拦截点击**，
///   因此高亮目标（如「记下车位」）仍可直接点按（边做边学）；遮罩区点击不穿透。
/// - 气泡含「知道了」按钮与「以后不再提示」复选框；勾选后回调 `onDismiss(true)`。
///
/// 用法：页面用 `GlobalKey` 标记目标，当 `shouldShow(step)` 为真时把它作为
/// `Positioned.fill` 塞进页面 `Stack`；在 `onDismiss` 里调
/// `CoachMarkController.completeStep(step, neverAgain: ...)`。
class CoachMarkOverlay extends StatefulWidget {
  /// 创建引导层。
  const CoachMarkOverlay({
    super.key,
    required this.targetKey,
    required this.message,
    required this.onDismiss,
    this.screenPadding = 20,
  });

  /// 被高亮目标的 `GlobalKey`（用于计算挖空区域）。
  final GlobalKey targetKey;

  /// 气泡文案。
  final String message;

  /// 用户点「知道了」时回调；参数为「以后不再提示」复选框是否勾选。
  final ValueChanged<bool> onDismiss;

  /// 气泡距屏幕边缘的最小留白。
  final double screenPadding;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  static const double _arrowW = 16;
  static const double _arrowH = 8;
  static const double _bubbleEstimate = 150;

  Rect? _hole;
  Size _selfSize = Size.zero;
  bool _neverAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHole());
  }

  void _updateHole() {
    if (!mounted) {
      return;
    }
    final BuildContext? targetContext = widget.targetKey.currentContext;
    if (targetContext == null) {
      return;
    }
    final RenderObject? targetObject = targetContext.findRenderObject();
    if (targetObject is! RenderBox || !targetObject.hasSize) {
      return;
    }
    // 引导层自身的 RenderBox：挖空区/命中区/气泡都使用它的本地坐标系。
    final RenderObject? selfObject = context.findRenderObject();
    if (selfObject is! RenderBox || !selfObject.hasSize) {
      return;
    }
    // BUG-1 修复：localToGlobal 得到的是**全局**坐标，必须用引导层自身的
    // globalToLocal 再换算回**本地**坐标，否则页面含 AppBar 时会整体下移一个
    // AppBar 高度，导致挖空区与命中区错位、高亮目标点不动。
    final Offset topLeft =
        selfObject.globalToLocal(targetObject.localToGlobal(Offset.zero));
    final Rect rect = (topLeft & targetObject.size).inflate(6);
    final Size selfSize = selfObject.size;
    if (_hole != rect || _selfSize != selfSize) {
      setState(() {
        _hole = rect;
        _selfSize = selfSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 每次布局后校正挖空区域（目标尺寸/位置可能变化）；相等则不 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHole());

    // 用 LayoutBuilder 取得**引导层自身**的尺寸（= 所在 Stack 的尺寸）：
    // 气泡留白与 `_blockers` 命中区边界都必须基于本地尺寸，绝不可用
    // MediaQuery.sizeOf（那是整屏含 AppBar 的尺寸，会引入同一处坐标错位）。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screen = constraints.biggest;
        final Rect? hole = _hole;

        if (hole == null) {
          // 目标尚未就绪：仅压暗 + 居中气泡，避免卡死。
          return SizedBox.expand(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: const ColoredBox(color: AppColors.scrim),
                  ),
                ),
                _bubble(
                  left: widget.screenPadding,
                  top: screen.height * 0.36,
                  width: screen.width - widget.screenPadding * 2,
                ),
              ],
            ),
          );
        }

        final double bubbleWidth = math.min(
          screen.width - widget.screenPadding * 2,
          300,
        );
        final double centered = (screen.width - bubbleWidth) / 2;
        final double bubbleLeft = math.max(
          widget.screenPadding,
          math.min(centered, screen.width - bubbleWidth - widget.screenPadding),
        );
        final bool hasRoomBelow = hole.bottom + _arrowH + _bubbleEstimate <
            screen.height - widget.screenPadding;
        final double bubbleTop = hasRoomBelow
            ? hole.bottom + _arrowH + 6
            : math.max(
                widget.screenPadding,
                hole.top - _arrowH - 6 - _bubbleEstimate,
              );
        final double arrowLeft = math.max(
          widget.screenPadding,
          math.min(
            hole.center.dx - _arrowW / 2,
            screen.width - _arrowW - widget.screenPadding,
          ),
        );
        final double arrowTop =
            hasRoomBelow ? hole.bottom + 4 : hole.top - _arrowH - 4;

        return SizedBox.expand(
          child: Stack(
            children: <Widget>[
              // ① 视觉压暗 + 圆角挖空
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ScrimPainter(
                      hole: RRect.fromRectAndRadius(
                        hole,
                        const Radius.circular(AppTokens.radiusL),
                      ),
                    ),
                  ),
                ),
              ),
              // ② 命中阻拦（四周），挖空区放行 → 目标可点
              ..._blockers(hole, screen),
              // ③ 高亮描边
              Positioned.fromRect(
                rect: hole,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(AppTokens.radiusL),
                    ),
                  ),
                ),
              ),
              // ④ 指向箭头
              Positioned(
                left: arrowLeft,
                top: arrowTop,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(_arrowW, _arrowH),
                    painter: _ArrowPainter(
                      pointsUp: hasRoomBelow,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
              // ⑤ 气泡
              _bubble(left: bubbleLeft, top: bubbleTop, width: bubbleWidth),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _blockers(Rect hole, Size screen) {
    Widget block(double left, double top, double width, double height) {
      return Positioned(
        left: left,
        top: top,
        width: math.max(0, width),
        height: math.max(0, height),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
        ),
      );
    }

    return <Widget>[
      block(0, 0, screen.width, hole.top),
      block(0, hole.bottom, screen.width, screen.height - hole.bottom),
      block(0, hole.top, hole.left, hole.height),
      block(hole.right, hole.top, screen.width - hole.right, hole.height),
    ];
  }

  Widget _bubble({required double left, required double top, required double width}) {
    final TextTheme text = Theme.of(context).textTheme;
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.message, style: text.bodyMedium),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => widget.onDismiss(_neverAgain),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('知道了'),
                  ),
                  const Spacer(),
                  Flexible(
                    child: InkWell(
                      onTap: () => setState(() => _neverAgain = !_neverAgain),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _neverAgain,
                              onChanged: (bool? value) =>
                                  setState(() => _neverAgain = value ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '以后不再提示',
                              style: text.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 压暗层画笔：整屏黑遮罩减去一个圆角矩形（挖空）。
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole});

  final RRect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final Path full = Path()..addRect(Offset.zero & size);
    final Path cut = Path()..addRRect(hole);
    final Path scrim = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(scrim, Paint()..color = AppColors.scrim);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.hole != hole;
}

/// 气泡指向目标的小三角形。
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointsUp, required this.color});

  final bool pointsUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp || oldDelegate.color != color;
}
