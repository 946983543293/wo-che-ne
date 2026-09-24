// T03 QA 独立验证 —— 核心记录流程（首页 → 拍照页 → 保存 → 找车态）。
//
// 覆盖：验收点 1（点击步数）、验收点 2 的 0 张与文案、验收点 5（引导 3 步）、
// 验收点 7（定位失败降级 + 手动地点默认收起）、验收点 8（权限按需申请）。
//
// 说明：真机相机取景/快门依赖 camera 平台通道，widget test 无法覆盖。本文件在
// 「相机权限被拒」的降级分支上验证拍照页结构、文案与保存流水线（见 QA 报告「未覆盖」）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/models/parking_record.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeParkingRepository parking;
  late Directory root;

  setUp(() {
    installPermissionMock(); // 定位/相机均「拒绝」→ 走降级分支
    settings = FakeSettingsRepository(
      AppSettings(privacyAgreed: true, guideDisabled: true),
    );
    parking = FakeParkingRepository();
    root = Directory.systemTemp.createTempSync('t03_camera_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(settings: settings, parking: parking, root: root),
    );
    await tester.pumpAndSettle();
  }

  /// 处理「权限说明」对话框（若出现），点「暂不」进入降级。
  Future<void> declineIfShown(WidgetTester tester, String title) async {
    if (find.text(title).evaluate().isNotEmpty) {
      await tester.tap(find.text('暂不'));
      await pumpFrames(tester);
    }
  }

  /// 从停车态进入拍照页（依次处理定位、相机权限说明框）。
  Future<void> enterCamera(WidgetTester tester) async {
    await tester.tap(find.text('记下车位'));
    await pumpFrames(tester);
    await declineIfShown(tester, '需要定位权限');
    await pumpFrames(tester);
    await declineIfShown(tester, '需要相机权限');
    await pumpFrames(tester);
  }

  /// 点「不拍了，直接记」完成记录并回到首页。
  Future<void> finishRecord(WidgetTester tester) async {
    await tester.tap(find.text('不拍了，直接记'));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-02-1 不拍照极速路径：2 次点击完成记录，返回找车态',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // 第 1 次点击：记下车位 → 进入拍照页。
    await enterCamera(tester);
    expect(find.text('未获得相机权限'), findsOneWidget);
    expect(find.text('不拍了，直接记'), findsOneWidget);
    // 定位失败（fix=null）→ 地点输入默认收起，显示一键展开。
    expect(find.text('定位失败，补充地点'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: '地点输入默认应收起');

    // 第 2 次点击：不拍了，直接记 → 保存并返回。
    await finishRecord(tester);

    expect(find.text('找到你的车了吗？'), findsOneWidget);
    expect(find.text('最近一次记录'), findsOneWidget);

    expect(parking.savedRecords, hasLength(1));
    final ParkingRecord saved = parking.savedRecords.single;
    expect(saved.photoPaths, isEmpty, reason: '0 张照片也应成功保存');
    expect(saved.latitude, ParkingRecord.unknownCoordinate);
    expect(saved.longitude, ParkingRecord.unknownCoordinate);
    expect(saved.archived, isFalse);
    expect(saved.poiName, isNull);
  });

  testWidgets('TC-02-2 定位失败降级：手动输入地点生效、默认收起一键展开',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await enterCamera(tester);

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('定位失败，补充地点'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('例如：紫荆园东侧'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '紫荆园东侧');
    await finishRecord(tester);

    final ParkingRecord saved = parking.savedRecords.single;
    expect(saved.poiName, '紫荆园东侧', reason: '手动地点优先落库');
    expect(saved.photoPaths, isEmpty);
  });

  testWidgets('TC-02-3 手动地点为空串 → poiName 落 null（不写空字符串）',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await enterCamera(tester);

    await tester.tap(find.text('定位失败，补充地点'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await finishRecord(tester);

    expect(parking.savedRecords.single.poiName, isNull);
  });

  testWidgets('TC-05-1 引导 3 步在首次真实流程中依次触发', (WidgetTester tester) async {
    settings.current = AppSettings(privacyAgreed: true); // 打开引导
    await pumpApp(tester);

    // 第 1 步：首页停车态。
    expect(find.text('点这里，位置自动记'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('点这里，位置自动记'), findsNothing);
    expect(settings.current.guideStepsSeen, contains(1));

    // 第 2 步：拍照页（亮点 = 快门 + 完成按钮所在控制条）。
    await enterCamera(tester);
    expect(find.text('顺手拍张照，找车不迷路；点这里随时完成'), findsOneWidget);

    // 控制条整体在挖空区 → 「不拍了，直接记」可点，同时完成第 2 步。
    await finishRecord(tester);

    // 第 3 步：找车态最近一次记录卡。
    expect(find.text('找到你的车了吗？'), findsOneWidget);
    expect(find.text('下次找车，点这里'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(settings.current.guideStepsSeen, containsAll(<int>[1, 2, 3]));
  });

  testWidgets('TC-05-2 任一步勾「以后不再提示」→ 后续引导永久不再出现',
      (WidgetTester tester) async {
    settings.current = AppSettings(privacyAgreed: true);
    await pumpApp(tester);

    expect(find.text('点这里，位置自动记'), findsOneWidget);
    await tester.tap(find.text('以后不再提示'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(settings.current.guideDisabled, isTrue, reason: '勾选后应永久关闭引导');

    await enterCamera(tester);
    expect(find.text('顺手拍张照，找车不迷路；点这里随时完成'), findsNothing);

    await finishRecord(tester);
    expect(find.text('下次找车，点这里'), findsNothing);
    expect(find.text('找到你的车了吗？'), findsOneWidget);
  });

  testWidgets('TC-05-3 勾「以后不再提示」后引导总开关落库，重启不再出现',
      (WidgetTester tester) async {
    settings.current = AppSettings(privacyAgreed: true);
    await pumpApp(tester);
    await tester.tap(find.text('以后不再提示'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    // 模拟重启：用同一份持久化设置重新挂载。
    await pumpApp(tester);
    expect(find.text('点这里，位置自动记'), findsNothing);
  });

  testWidgets('TC-02-4 拍照页返回（放弃记录）：不落库、不残留记录',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await enterCamera(tester);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(parking.savedRecords, isEmpty, reason: '放弃记录不应写入');
    expect(find.text('车停好了？'), findsOneWidget, reason: '回到停车态');
  });

  testWidgets('TC-08-1 权限按需申请：启动不弹权限，点「记下车位」才要定位、进拍照页才要相机',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // 启动阶段不弹任何权限说明框。
    expect(find.text('需要定位权限'), findsNothing);
    expect(find.text('需要相机权限'), findsNothing);

    await tester.tap(find.text('记下车位'));
    await pumpFrames(tester);
    expect(find.text('需要定位权限'), findsOneWidget,
        reason: '点「记下车位」才申请定位，并先给理由');
    expect(find.text('需要相机权限'), findsNothing);

    await tester.tap(find.text('暂不'));
    await pumpFrames(tester);
    expect(find.text('需要相机权限'), findsOneWidget,
        reason: '进入拍照页才申请相机权限');
  });
}
