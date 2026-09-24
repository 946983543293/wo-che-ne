// T03 QA 独立验证 —— 叠加式新手引导层是否「不穿透」。
//
// 验收点 5：高亮目标可点、遮罩区拦截误触；气泡复选框「以后不再提示」回调正确。
//
// TC-05-4/5 用「无 AppBar」页面验证基础能力（通过）。
// TC-05-7 用「有 AppBar」页面复现「挖空区坐标错位」缺陷 —— 当前为红灯（BUG-1），
// 修复 `coach_mark_overlay.dart` 后应转绿。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/widgets/coach_mark_overlay.dart';

/// 组装「干扰按钮在左上角 + 高亮目标在底部」的页面。
Widget overlayScene({
  required GlobalKey targetKey,
  required VoidCallback onTarget,
  required VoidCallback onOther,
  required ValueChanged<bool> onDismiss,
  bool withAppBar = false,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: withAppBar ? AppBar(title: const Text('带 AppBar 的页面')) : null,
      body: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: ElevatedButton(
              onPressed: onOther,
              child: const Text('其他'),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                key: targetKey,
                onPressed: onTarget,
                child: const Text('目标'),
              ),
            ),
          ),
          Positioned.fill(
            child: CoachMarkOverlay(
              targetKey: targetKey,
              message: '点这里',
              onDismiss: onDismiss,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('TC-05-4 遮罩不穿透：高亮目标可点、遮罩区拦截误触（无 AppBar 基线）',
      (WidgetTester tester) async {
    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;
    int otherTaps = 0;
    bool? dismissedWith;

    await tester.pumpWidget(overlayScene(
      targetKey: targetKey,
      onTarget: () => targetTaps++,
      onOther: () => otherTaps++,
      onDismiss: (bool neverAgain) => dismissedWith = neverAgain,
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('其他')));
    await tester.pumpAndSettle();
    expect(otherTaps, 0, reason: '遮罩区点击不得穿透到下层控件');

    await tester.tapAt(tester.getCenter(find.text('目标')));
    await tester.pumpAndSettle();
    expect(targetTaps, 1, reason: '挖空区应放行，目标可点');

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(dismissedWith, isFalse);
  });

  testWidgets('TC-05-5 勾选「以后不再提示」→ onDismiss(true)',
      (WidgetTester tester) async {
    final GlobalKey targetKey = GlobalKey();
    bool? dismissedWith;

    await tester.pumpWidget(overlayScene(
      targetKey: targetKey,
      onTarget: () {},
      onOther: () {},
      onDismiss: (bool neverAgain) => dismissedWith = neverAgain,
    ));
    await tester.pumpAndSettle();

    expect(find.text('以后不再提示'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(dismissedWith, isTrue);
  });

  testWidgets('TC-05-6 遮罩区拦截误触（带 AppBar 时同样成立）',
      (WidgetTester tester) async {
    final GlobalKey targetKey = GlobalKey();
    int otherTaps = 0;

    await tester.pumpWidget(overlayScene(
      targetKey: targetKey,
      onTarget: () {},
      onOther: () => otherTaps++,
      onDismiss: (_) {},
      withAppBar: true,
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('其他')));
    await tester.pumpAndSettle();
    expect(otherTaps, 0);
  });

  // ---------------------------------------------------------------------------
  // BUG-1 回归测试（当前红灯，待工程师修复 coach_mark_overlay.dart）
  // ---------------------------------------------------------------------------
  testWidgets('TC-05-7【BUG-1】带 AppBar 的页面：高亮目标必须仍可点（挖空区不得整体下移）',
      (WidgetTester tester) async {
    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;

    await tester.pumpWidget(overlayScene(
      targetKey: targetKey,
      onTarget: () => targetTaps++,
      onOther: () {},
      onDismiss: (_) {},
      withAppBar: true,
    ));
    await tester.pumpAndSettle();

    // PRD §4.6：高亮目标本身也可正常点按，不强制先点「知道了」。
    await tester.tapAt(tester.getCenter(find.text('目标')));
    await tester.pumpAndSettle();

    expect(targetTaps, 1,
        reason: 'BUG-1：hole 用 localToGlobal（全局坐标）计算，却被当作引导层 Stack 的'
            '本地坐标使用；页面含 AppBar 时坐标系原点差一个 AppBar 高度，'
            '导致挖空区与命中区整体下移，高亮目标被遮罩挡住无法点击。');
  });

  // ---------------------------------------------------------------------------
  // Round 2 边界补测（BUG-1 修复后的稳健性）
  // ---------------------------------------------------------------------------
  testWidgets('TC-05-8 AppBar + 底部安全区 + 滚动偏移：挖空区仍对齐目标、目标可点',
      (WidgetTester tester) async {
    // 制造真实机型形态：带状态栏/AppBar、底部手势条（安全区 34）、内容可滚动。
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('AppBar + 安全区')),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              // 顶部塞入大块留白制造「内容高于视口」的滚动场景。
              ListView(
                padding: const EdgeInsets.only(top: 420, bottom: 24),
                children: <Widget>[
                  Center(
                    child: ElevatedButton(
                      key: targetKey,
                      onPressed: () => targetTaps++,
                      child: const Text('目标'),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: CoachMarkOverlay(
                  targetKey: targetKey,
                  message: '点这里',
                  onDismiss: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pumpAndSettle();
    expect(targetTaps, 1,
        reason: 'AppBar + 底部安全区 + 滚动偏移下，挖空区仍须对齐目标并可点');
  });

  testWidgets('TC-05-9 气泡不遮挡高亮目标：目标贴底时气泡整体位于其上方',
      (WidgetTester tester) async {
    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;
    int dismissCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('带 AppBar')),
        body: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  key: targetKey,
                  onPressed: () => targetTaps++,
                  child: const Text('目标'),
                ),
              ),
            ),
            Positioned.fill(
              child: CoachMarkOverlay(
                targetKey: targetKey,
                message: '点这里',
                onDismiss: (_) => dismissCalls++,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 目标贴底 → 下方无空间 → 气泡只能朝上放，且必须与目标不重叠。
    final Rect targetRect = tester.getRect(find.byKey(targetKey));
    final Rect bubbleRect = tester.getRect(
      find.ancestor(of: find.text('知道了'), matching: find.byType(Material)).first,
    );
    expect(bubbleRect.bottom <= targetRect.top + 0.5, isTrue,
        reason: '气泡不得压在目标上（bubble.bottom=${bubbleRect.bottom} '
            'target.top=${targetRect.top}）');

    // 命中目标中心：应触发目标自身，而非误触气泡里的「知道了」。
    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pumpAndSettle();
    expect(targetTaps, 1);
    expect(dismissCalls, 0, reason: '点目标不应误触气泡按钮');
  });

  testWidgets('TC-05-10 窄屏(320) + RTL：挖空区仍与目标对齐、目标可点',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('RTL 窄屏')),
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ElevatedButton(
                    key: targetKey,
                    onPressed: () => targetTaps++,
                    child: const Text('目标'),
                  ),
                ),
              ),
              Positioned.fill(
                child: CoachMarkOverlay(
                  targetKey: targetKey,
                  message: '点这里',
                  onDismiss: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pumpAndSettle();
    expect(targetTaps, 1, reason: 'RTL + 320 窄屏下挖空区仍须对齐目标并可点');
  });
}
