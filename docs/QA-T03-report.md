# QA 验证报告 —— T03 核心记录流程（首页双状态 + 拍照页 + 叠加式新手引导 + 隐私同意门）

| 项目信息 | 内容 |
|---|---|
| 任务 | T03 独立验证（QA 工程师：严过关 Edward） |
| 被测版本 | `wo_che_ne` T03 交付（工程师自测 43 用例全过） |
| 验证环境 | Windows / Flutter（`C:\flutter`）/ 工程经 `subst W:` 套壳（`W:\wo_che_ne`） |
| 验证手段 | 独立编译 + 静态分析 + 新增 widget/单元测试（不修改 `lib/`） |
| 报告版本 | v1.0 |

> **说明**：本报告由 QA 独立编写，所有结论均基于本人亲自执行的命令与自编测试，不引用工程师的自测数字。
> **环境备注**：团队说明中的文档路径 `W:\wo_che_ne\docs` 实际不存在；文档位于 `W:\docs`（= `F:\WorkBuddy_data\wo-che-ne\docs`）。本报告因此落盘在 `W:\docs\QA-T03-report.md`。

---

## 0. 执行摘要

| 项 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!**（0 issue） |
| `flutter test`（全量，含 QA 新增 48 例） | 见 §5 汇总（**唯一红灯 = 本人刻意保留的 BUG-1 回归用例**） |
| 验收点通过 | 8 / 10（验收点 5 因 BUG-1 不通过；验收点 2、3 附条件通过，见 §4） |
| 源码缺陷 | **1 个 P1（BUG-1，功能性）**、**1 个 P2（BUG-2，合规/清单一致性）**、**1 个 P2（F-3，UX）** |
| **路由判定** | **发送给工程师（Engineer）** —— BUG-1 需改 `lib/widgets/coach_mark_overlay.dart`；测试代码无缺陷 |

---

## 1. 验证方法与独立取证手段

1. **不采信自测结论**：重新跑 `analyze` 与全量 `test`，并从零编写 48 条新用例（含边界值、错误路径、权限被拒、空数据、溢出上限）。
2. **坐标系实证**：对引导遮罩的命中行为，用 `RenderBox.localToGlobal` 打印「按钮矩形 vs 引导层矩形」并用「分点点击」定位偏移量（§3.1）。
3. **产物级核对**：读取构建产物中**合并后的** `AndroidManifest.xml`（`build/app/intermediates/merged_manifests/...`）与插件清单，而非仅看源码清单（§3.2）。
4. **真实文件系统**：淘汰策略的照片级联删除用真实临时目录 + 真实文件断言，而非 mock（`t03_eviction_cascade_test.dart`）。

---

## 2. 新增测试资产（仅新增 `test/` 下文件，未改动 `lib/`）

| 文件 | 用例数 | 覆盖点 |
|---|---|---|
| `test/support/fakes.dart` | — | 内存假仓储 / 静默震动 / 高德初始化探针 |
| `test/support/rig.dart` | — | 权限通道 mock、帧泵、App 装配脚手架 |
| `test/t03_privacy_gate_test.dart` | 7 | 隐私同意门（TC-04-x） |
| `test/t03_home_dual_state_test.dart` | 6 | 首页双状态（TC-01-x） |
| `test/t03_camera_flow_test.dart` | 8 | 记录流程 / 拍照页 / 引导 / 权限（TC-02-x、TC-05-x、TC-08-1） |
| `test/t03_coach_mark_overlay_test.dart` | 4 | 引导遮罩不穿透（TC-05-4/5/6）与 **BUG-1 回归（TC-05-7）** |
| `test/t03_parking_controller_test.dart` | 17 | 控制器保存/归档/删除/派生状态（TC-03-x） |
| `test/t03_eviction_cascade_test.dart` | 6 | 历史上限与淘汰（真实文件级联，TC-06-x） |
| **合计** | **48** | |

> 自测基线：`amap_sdk_gate_test` / `coach_mark_controller_test` / `geo_utils_test` / `parking_repository_test` / `time_utils_test` / `widget_test` 共 42 条，全部通过（未改动）。

---

## 3. 缺陷清单

### 3.1 BUG-1【P1 · 功能性 · 必须修】引导遮罩坐标系错位——高亮目标点不动

| 项 | 内容 |
|---|---|
| 文件:行号 | `lib/widgets/coach_mark_overlay.dart:58-75`（`_updateHole`），关键行 **:70** 与 **:71**；消费于 **:138-142**（`_ScrimPainter` 挖空）与 **:181-201**（`_blockers`，`:147` 调用） |
| 复现步骤 | 1) 新建页面 = `Scaffold(appBar: AppBar(...), body: Stack([目标按钮, Positioned.fill(CoachMarkOverlay(targetKey: 目标按钮))]))`；2) 直接点按被高亮的目标按钮中心 |
| 期望 | 目标按钮被命中（PRD §4.6 明确：「高亮目标本身也可正常点按…不强制先点『知道了』」） |
| 实际 | 点击被遮罩拦截，回调不触发 |
| 根因 | `_updateHole()` 用 `renderObject.localToGlobal(Offset.zero)` 得到的是**全局（屏幕）坐标**，但该 `hole` 随后被当作引导层自身 `Stack` 的**本地坐标**使用（`Positioned` 与 `CustomPaint` 都在本地坐标系）。只要所在页面存在 AppBar（首页），引导层 Stack 的原点就不在屏幕原点，两者相差一个 AppBar 高度 → 挖空区与命中区**整体下移**。 |
| 实测证据 | 引导层矩形 `Rect(0, 56, 800, 600)`（顶部 56 = AppBar 高度）；按钮矩形 `Rect(24, 395.6, 776, 459.6)`。点按钮**中心** → 无任何反应（定位权限说明框未弹出，`DIALOG_AFTER_CENTER=0`）；点按钮**底部 14px**（落在下移后的挖空区）→ 正常弹出权限说明框（`DIALOG_AFTER_BOTTOM=1`）。偏移量精确等于 AppBar 高度 56px。 |
| 影响面 | 首页的**第 1 步**（目标=「记下车位」）与**第 3 步**（目标=「最近一次记录」卡）均受影响：高亮圈画在错误位置，且真实目标被遮罩挡住。首次进入 App 的新用户按气泡提示「点这里」会**没有反应**，须先点「知道了」才能继续 —— 直接违背 PRD §4.6，并冲击「引导 3 步触达率 ≥80%」的指标。拍照页（无 AppBar）不受影响。降级模式下还会挡住「同意隐私政策并开始使用」入口（见 F-3）。 |
| 建议修复 | `_updateHole()` 改为把目标矩形换算到**引导层自身**的坐标系，例如：<br>`final RenderBox self = context.findRenderObject()! as RenderBox;`<br>`final Offset topLeft = self.globalToLocal(targetBox.localToGlobal(Offset.zero));`<br>同时把 `_blockers`/气泡的边界由 `MediaQuery.sizeOf` 改为引导层自身 `self.size`，以免 SafeArea 顶部内边距（状态栏）造成同类偏移。 |
| 验证用例 | `test/t03_coach_mark_overlay_test.dart` → **TC-05-7【BUG-1】**（当前红灯，修好后应转绿；同文件 TC-05-4/5/6 为无 AppBar 基线，已绿，可证明缺陷确由 AppBar 引入） |

### 3.2 BUG-2【P2 · 合规/一致性 · 建议修】合并后清单声明了与隐私承诺不符的权限

| 项 | 内容 |
|---|---|
| 证据:行号 | 合并清单 `build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml:43-47`；来源插件清单 `build/camera_android_camerax/intermediates/merged_manifest/debug/processDebugManifest/AndroidManifest.xml:9-13` |
| 实际 | 合并清单含 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`、`READ_EXTERNAL_STORAGE`（无 maxSdk 限制）、`WRITE_EXTERNAL_STORAGE`（maxSdkVersion=28）。三者均由 `camera_android_camerax` 注入。 |
| 期望 | `android/app/src/main/AndroidManifest.xml:14` 明确注释「刻意不声明 READ_MEDIA_IMAGES —— 照片只进应用私有目录」；PRD §6.2/§7 与 `PRIVACY.md` 声明「不申请相册读取、通知等无关权限」「照片 0 张进入系统相册」。 |
| 说明 | 好消息：`READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`/`MANAGE_EXTERNAL_STORAGE` **确实不存在**（Android 13+ 无相册权限）；`lib/` 内**无任何 MediaStore/相册写入路径**（照片只经 `LocalStore` 写 `getApplicationDocumentsDirectory()`）。坏消息：在 Android ≤12（minSdk=24）上，`READ_EXTERNAL_STORAGE` 即「读取相册」等价权限；`RECORD_AUDIO` 亦与「不申请无关权限」不一致（代码已 `enableAudio: false`）。工信部/应用商店 SDK 隐私检测会读到这三条。 |
| 建议修复 | 在 `android/app/src/main/AndroidManifest.xml` 增加（需 `xmlns:tools`）：<br>`<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove" />`<br>`<uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove" />`<br>（拍照走相机插件自身缓存目录，均不需要这两个权限；移除后需回归一次真机拍照。） |
| 严重级别 | P2（无功能影响、运行时不会为二者弹权限框；但对外承诺与清单不一致，属合规风险） |

### 3.3 F-3【P2 · UX · 建议修】降级模式仍展示「第 1 步引导」，指向被禁用的按钮

| 项 | 内容 |
|---|---|
| 位置 | `lib/pages/home/home_page.dart:74-83`（第 1 步触发未判断 `widget.degraded`）＋ `:138`（降级时按钮 `onPressed: null`） |
| 实际 | 用户点「暂不同意」进入降级首页后，仍会看到气泡「点这里，位置自动记」，且高亮框对准的是**已禁用**的「记下车位」；叠加 BUG-1 后，该遮罩还会挡住「同意隐私政策并开始使用」入口（实测：直接点该入口命中测试失败，需先点「知道了」）。 |
| 期望 | 降级模式下不展示引导（或改为指向「同意隐私政策并开始使用」）。 |
| 建议 | 第 1 步触发条件加 `!widget.degraded`。 |
| 验证用例 | `t03_privacy_gate_test.dart` → TC-04-3（记录该行为）；BUG-1 的连带影响见 §3.1 实测证据。 |

### 3.4 其他观察（非缺陷，记录备查）

- **F-4【P3 · 设计走查】字号字面量**：`lib/core/theme/app_theme.dart:140`（AppBar 标题 18sp）与 `:160`（按钮文字 18sp）直接写死字号，未走 `AppTokens`（令牌集里也没有 18sp 档）。色值红线无违反（见 §4-9）。
- **F-5【P3 · 防御性】**：`ParkingController.saveNewRecord` 不校验 3 张照片上限（护栏只在拍照页 `_capture()`），4 张也会照写。当前行为已用测试固定（`TC-03-4`），如希望双保险可在状态层再加一次 clamp。
- **F-6【测试基建】**：`flutter test` 环境中**未注册 mock 的平台通道不会抛异常，而是永不完成（流程静默挂起）**。团队后续写 widget test 务必用 `test/support/rig.dart` 的 `installPermissionMock()` 并覆盖 `hapticServiceProvider`，否则记录流程会在权限/震动调用处卡住。
- **F-7【P2 · 工具链】**：`tool/flutter.ps1` 在 Windows PowerShell 5.1 下不可用 —— 脚本自身 `$ErrorActionPreference = 'Stop'`（`:37`）会把 flutter 向 stderr 输出的镜像提示（`Flutter assets will be downloaded from …`）当成**终止性错误**，在 `& $flutter @args`（`:62`）处抛出 `NativeCommandError` 并中止（实测：`analyze` 未跑完即退出）。规避：本次全部验证改为直接调用 flutter 并自设 `NO_PROXY`（等价于包装器的唯一职责）。建议把 `$ErrorActionPreference` 改为 `Continue`（或包装原生命令调用）以便 PS 5.1 可用。

---

## 4. 十条验收点逐条结论

| # | 验收点 | 结论 | 依据 |
|---|---|---|---|
| 1 | 操作步数：不拍照 ≤2、含 1 张 ≤3 | **通过（附提示）** | TC-02-1 实测「打开→记下车位→不拍了，直接记」共 **2 次点击**即落库并切找车态。3 次点击路径（含快门 1 次）因无真机相机不可执行，但 UI 恰为该两个控件（快门 + 「拍够了就这样」），已在代码核验（`camera_page.dart:520-554`）。⚠️ 首次启动叠加引导时，因 BUG-1 需先点一次「知道了」，实际点击变为 4 次。 |
| 2 | 拍照 0/1/2/3 张均可保存；0 张文案「不拍了，直接记」；满 3 张自动保存；缩略图可删可重拍 | **部分通过** | 保存侧**完全覆盖**：TC-03-1~4 证明 0/1/2/3 张记录均可落库且数量顺序正确；0 张 UI 路径全链路可跑（TC-02-1/2/3）；0 张按钮文案断言通过。**满 3 张自动保存**（`camera_page.dart:201-203`）与**缩略图删除/重拍**（`:212-219`、`:492-506`）仅代码核验、**未测试覆盖**（见 §5）。 |
| 3 | 照片仅入应用私有目录；无 MediaStore/相册路径；`AndroidManifest.xml` 无 READ_MEDIA_IMAGES | **通过（附 BUG-2）** | `lib/` 中仅 `local_store.dart:32` 使用 `getApplicationDocumentsDirectory()`；全仓无 `MediaStore/insertImage/MediaScanner`；`READ_MEDIA_IMAGES` 确认不存在。但合并清单被插件注入 `READ_EXTERNAL_STORAGE`/`RECORD_AUDIO`/`WRITE_EXTERNAL_STORAGE` → BUG-2。 |
| 4 | 首次启动弹门；「暂不同意」→ 降级；「同意」→ `agreeAndInit()` + 写同意状态；**同意前不得初始化 SDK** | **通过** | TC-04-1（弹门 + `spy.calls==0` + `gate.ready==false`）、TC-04-2（同意 → 落库 + `agreeAndInit` 调用 1 次 + `ready==true` + 进停车态）、TC-04-3（拒绝 → 主按钮禁用 + 不落库 + 不初始化）、TC-04-4（降级后可重新唤起同意框）、TC-04-5（已同意冷启动不弹门）、TC-04-7（可查政策全文）。冷启动 `initIfAgreed()` 位于 `main()`，由 T02 的 `amap_sdk_gate_test` 覆盖其语义。 |
| 5 | 3 步依次触发；任一步可永久关闭；设置 reset 后可重现；**遮罩不穿透** | **不通过** | 依次触发 ✓（TC-05-1 全链路三步）；永久关闭 ✓（TC-05-2/3 + 控制器单测）；reset 可重现 ✓（`coach_mark_controller_test`）；遮罩区拦截 ✓（TC-05-4/6）；**但「高亮目标可点」✗（BUG-1，TC-05-7 红灯）** → 该条整体判定不通过。 |
| 6 | 3–20 条约束、默认 10；超限先淘汰「已归档中最早」；照片级联删除 | **通过** | TC-06-6（钳制 3/20）、TC-06-3（默认 10 不误淘汰）、TC-06-1（优先淘汰已归档最早 + **真实文件**被删）、TC-06-2（无归档则淘汰最早）、TC-06-4（上限动态调小立即收敛）、TC-06-5（delete 级联删照片）。 |
| 7 | 定位失败可纯照片记录 + 手动输入地点（默认收起）；精度>20m 提示 | **通过（提示项未覆盖）** | 纯照片记录 ✓（TC-02-1 坐标落哨兵 `(0,0)`）；手动地点默认收起/一键展开 ✓（TC-02-2）；手动优先于 POI、空白串回退 ✓（TC-03-5~7）；地点为 null 显示「未知地点」✓（TC-01-4）。⚠️「精度>20m 提示」代码存在（`home_page.dart:203-210`）但**未覆盖**（widget test 无法驱动高德定位成功）。 |
| 8 | 点「记下车位」才申请定位、进拍照页才申请相机；被拒可降级 | **通过** | TC-08-1：启动阶段无任何权限框 → 点「记下车位」弹出「需要定位权限」→ 进拍照页弹出「需要相机权限」。被拒后全程降级可用（TC-02-1/2/3/4 均在拒绝路径完成记录或安全返回）。 |
| 9 | 设计质量红线：无硬编码色值；一屏一个主行动点；动效 150–250ms | **通过（附小注）** | 全 `lib/` 中唯一出现 `Color(0x…)` 字面量的是令牌文件 `app_colors.dart`；页面/组件一律走 `AppColors.*`。动效令牌仅 150/200/250ms，全部落在 PRD 区间。停车态整屏恰 1 个 `ElevatedButton`（TC-01-5）。小注：`app_theme.dart:140/160` 写死 18sp 字号（F-4）。 |
| 10 | `flutter test` 全过 + `flutter analyze` 无 issue | **通过**（见 §5） | `analyze` → No issues found；`flutter test` → 全部通过，除本人刻意保留的 BUG-1 回归红灯。 |

---

## 5. 测试执行结果

| 项 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!**（`ANALYZE_EXIT=0`） |
| `flutter test` 总用例 | 90（既有 42 + 新增 48） |
| 通过 | 89 |
| 失败 | **1（唯一：`TC-05-7【BUG-1】`，刻意保留的红灯）** |
| 结论 | 除 BUG-1 外无其他失败 —— 工程师自测未覆盖的边界（空串地点、归档淘汰、真实文件级联、权限被拒、降级模式、遮罩命中）均已被本次独立用例覆盖并通过。 |

### 用例清单

> 说明：为节省篇幅，同一断言组的参数化用例合并为一行。全部用例均在 `test/` 下可复跑。

| 编号 | 前置条件 | 步骤 | 期望 | 实际 | 结论 |
|---|---|---|---|---|---|
| TC-04-1 | 未同意隐私 | 冷启动 | 弹同意框；`spy.calls==0`；`gate.ready==false` | 一致 | 通过 |
| TC-04-2 | 未同意隐私 | 点「同意并继续」 | 落库同意+时间；`agreeAndInit` 调用 1 次；进停车态 | 一致 | 通过 |
| TC-04-3 | 未同意隐私 | 点「暂不同意」 | 降级提示；主按钮禁用；不落库/不初始化 | 一致 | 通过 |
| TC-04-4 | 已降级 | 点「同意隐私政策并开始使用」 | 重新弹出同意框 | 一致（需先关引导遮罩，见 F-3） | 通过 |
| TC-04-5 | 已同意 | 冷启动 | 不弹门，直接停车态 | 一致 | 通过 |
| TC-04-6 | 已降级 | 检查入口 | 设置/历史可用；记录入口禁用 | 一致 | 通过 |
| TC-04-7 | 未同意隐私 | 点「查看《隐私政策》全文」 | 展示政策全文 | 一致 | 通过 |
| TC-01-1 | 无未归档记录 | 打开首页 | 停车态：标题+主按钮+「2 次点击」提示 | 一致 | 通过 |
| TC-01-2 | 仅已归档记录 | 打开首页 | 仍为停车态；主按钮可用 | 一致 | 通过 |
| TC-01-3 | 1 条未归档 | 打开首页 | 找车态：卡片+地点+时间+「再记一笔」 | 一致 | 通过 |
| TC-01-4 | 未归档但无地点名 | 打开首页 | 显示「未知地点」 | 一致 | 通过 |
| TC-01-5 | 停车态 | 统计按钮 | 整屏恰 1 个主行动按钮 | 一致 | 通过 |
| TC-01-6 | 找车态 | 点「最近一次记录」 | 可导航（至 T04 占位页） | 一致 | 通过 |
| TC-02-1 | 权限拒绝 | 记下车位→不拍了直接记 | 2 次点击落库；0 张；坐标哨兵；切找车态 | 一致 | 通过 |
| TC-02-2 | 权限拒绝 | 展开补充地点→输入→完成 | 地点入库；默认收起 | 一致 | 通过 |
| TC-02-3 | 权限拒绝 | 输入空白串→完成 | `poiName` 落 null | 一致 | 通过 |
| TC-02-4 | 权限拒绝 | 进拍照页→返回 | 不落库；回停车态 | 一致 | 通过 |
| TC-05-1 | 引导开启 | 走完「首页→拍照→找车」 | 第 1/2/3 步依次出现，`seen={1,2,3}` | 一致 | 通过 |
| TC-05-2 | 引导开启 | 第 1 步勾「以后不再提示」 | `guideDisabled=true`；后续步骤均不出现 | 一致 | 通过 |
| TC-05-3 | 引导已关闭 | 重启 | 引导不再出现 | 一致 | 通过 |
| TC-05-4 | 无 AppBar | 点遮罩区 / 点挖空目标 / 知道了 | 遮罩拦截；目标可点；`onDismiss(false)` | 一致 | 通过 |
| TC-05-5 | 无 AppBar | 勾选后知道了 | `onDismiss(true)` | 一致 | 通过 |
| TC-05-6 | **有 AppBar** | 点遮罩区 | 拦截误触 | 一致 | 通过 |
| **TC-05-7** | **有 AppBar** | **点挖空区中的高亮目标** | **目标可点（PRD §4.6）** | **被拦截，回调未触发** | **失败（BUG-1）** |
| TC-08-1 | 权限拒绝 | 启动→记下车位→进拍照页 | 启动不弹；按需弹定位/相机说明框 | 一致 | 通过 |
| TC-03-1~4 | 控制器 | 保存 0/1/2/3 张照片 | 数量与顺序原样落库 | 一致 | 通过 |
| TC-03-5 | 控制器 | `fix=null` + 手动地点 | 哨兵坐标 + 手动地点 | 一致 | 通过 |
| TC-03-6 | 控制器 | `fix` 有 POI，无手动 | 取 POI，保留精度 | 一致 | 通过 |
| TC-03-7 | 控制器 | 手动 > POI | 手动优先 | 一致 | 通过 |
| TC-03-8 | 控制器 | 手动为空白串 | 回退 POI | 一致 | 通过 |
| TC-03-9 | 控制器 | 无 POI 无手动 | `poiName=null` | 一致 | 通过 |
| TC-03-10 | 控制器 | 保存 | 触发 1 次震动 | 一致 | 通过 |
| TC-03-11 | 控制器 | 保存 / 归档 | 派生状态停车态↔找车态切换正确 | 一致 | 通过 |
| TC-03-12 | 控制器 | 归档未知 id | 静默无副作用 | 一致 | 通过 |
| TC-03-13 | 控制器 | `remove(id)` | 调用仓储删除 | 一致 | 通过 |
| TC-03-14 | 控制器 | 多条未归档 | 取 `createdAt` 最新 | 一致 | 通过 |
| TC-03-15 | 控制器 | 传 4 张照片 | 原样写库（记录当前行为，见 F-5） | 一致 | 通过 |
| TC-06-1 | 上限 3，含已归档 | 保存第 4 条 | 淘汰已归档最早；**真实照片文件被删** | 一致 | 通过 |
| TC-06-2 | 上限 3，无归档 | 保存第 4 条 | 淘汰最早记录 | 一致 | 通过 |
| TC-06-3 | 默认上限 10 | 保存 3 条 | 不淘汰 | 一致 | 通过 |
| TC-06-4 | 上限 20→3 | 再保存 1 条 | 立即收敛到 3 | 一致 | 通过 |
| TC-06-5 | 有照片记录 | `delete(id)` | 记录与照片文件同删 | 一致 | 通过 |
| TC-06-6 | — | 上限钳制 | 1→3，100→20 | 一致 | 通过 |

---

## 6. 未覆盖与残余风险

以下内容**未获测试覆盖**，不得据此判定「通过」；建议由 T04 集成测试或真机验证补齐：

1. **真机相机行为**（widget test 无法驱动 camera 平台通道）：取景框渲染、快门连拍、**满 3 张自动收工**、缩略图「×」删除与重拍、`dispose` 时孤儿照片清理（`camera_page.dart:74-77`）。
2. **1–3 张照片的 UI 侧路径**：拍照后按钮文案切换为「拍够了就这样」（`camera_page.dart:550`）**未经 UI 断言**（仅在控制器层验证了 0–3 张的保存能力）。
3. **高德定位成功路径**：`getCurrentFix()` 字段解析、`已定位：地点，精度 N m` 文案、**精度 >20m 的「定位不准，主要靠照片认车」提示**（`home_page.dart:203-210`）均未覆盖（需真机或注入 `locationServiceProvider`）。
4. **冷启动合规接线**：`main()` 的 `initIfAgreed()`（widget test 不执行 `main()`）—— 其分支语义已由 T02 的门单测覆盖，但「启动即读同意状态」的接线本身未覆盖。
5. **权限永久拒绝（Don't ask again）后的「去系统设置」引导**：当前代码未实现该入口（PRD 未强制要求），若产品需要需另立需求。
6. **iOS 侧**：本任务仅面向 Android，未验证。
7. **真实 `SharedPreferences`/真实 `records.json` 并发写**：T02 已覆盖 JSON 往返与原子写语义，T03 未重复。
8. **真机引导首启体验**：BUG-1 在真机上的表现（AppBar + 状态栏双重内边距可能使偏移更大）需修复后真机回归。

---

## 7. 路由判定

| 目标 | 内容 |
|---|---|
| **发送给：工程师（Engineer）** | **BUG-1（P1，功能性）**：`lib/widgets/coach_mark_overlay.dart` 坐标系错位，导致高亮目标不可点（TC-05-7 红灯即验收条件）。附带：BUG-2（P2，清单权限）、F-3（P2，降级模式引导）、F-4（P3，字号令牌）、F-7（P2，`tool/flutter.ps1` PS5.1 兼容）。 |
| 发送给：QA（本人） | **无**。本轮未发现任何「测试代码自身错误」——首轮 8 条红灯经逐条定位，全部归因于「测试环境未 mock 平台通道」（已在 `test/support/rig.dart` 修正）与 BUG-1（真实缺陷），测试断言本身正确。 |
| 发送给：NoOne | 不适用（存在 P1 缺陷）。 |

**修复后回归方式**：`Set-Location W:\wo_che_ne; .\tool\flutter.ps1 test`（或直接 `flutter test` 并自设 `NO_PROXY`），`test/t03_coach_mark_overlay_test.dart` 的 TC-05-7 转绿即视为 BUG-1 已修复。

---
---

# Round 2 回归复验（修复轮后 · 第 2 轮 / 终轮）

| 项目信息 | 内容 |
|---|---|
| 复验对象 | 工程师修复轮产出（BUG-1 / BUG-2 / F-3 / F-4 / F-7，F-5 按裁决不改） |
| 复验手段 | 独立读源码对比 + 独立跑 `.\tool\flutter.ps1 analyze/test`（读退出码）+ 独立 `aapt2` 直查 **APK 本体** + 新增 4 条边界/回归用例 |
| 报告版本 | v1.1 |
| **总结论** | **全部修复点独立复验通过；无新缺陷；路由判定 = NoOne（全绿）** |

> 原则：不采信团队/工程师结论，以下每条均为本人亲自复跑或亲自取证。

## R2-1. 修复点逐条独立复验

| 修复点 | 独立复验方法 | 结论 | 证据（文件:行号 / 命令） |
|---|---|---|---|
| **BUG-1**（P1 · 引导坐标） | 读新版 `lib/widgets/coach_mark_overlay.dart`；跑本人 Round 1 刻意保留的红灯 TC-05-7 | **通过** | `_updateHole()`（:79-80）改为 `selfObject.globalToLocal(targetObject.localToGlobal(Offset.zero))`；外层改 `LayoutBuilder` + `constraints.biggest`（:99-101），`_blockers`/气泡边界不再用 `MediaQuery.sizeOf`。TC-05-7 由红转绿。 |
| **BUG-2**（P2 · 合规权限） | **`aapt2 dump xmltree --file AndroidManifest.xml` 直查 APK 本体**（非 build 中间产物）：`build/app/outputs/flutter-apk/app-debug.apk`（mtime `2026-09-23 21:38:56`） | **通过** | APK 本体内 `uses-permission` 仅剩：INTERNET、ACCESS_FINE_LOCATION、ACCESS_COARSE_LOCATION、CAMERA、ACCESS_NETWORK_STATE、ACCESS_WIFI_STATE、CHANGE_WIFI_STATE、VIBRATE（+ 自定义 DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION）。**READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE / RECORD_AUDIO 四条权限均已在 APK 中消失。** |
| **BUG-2 附带**（高德 Key 未被误删） | 同一次 aapt2 输出核对 | **通过** | `<meta-data android:name="com.amap.api.v2.apikey" android:value="8cc0…"/>` 仍位于 `application` 下（值前缀 `8cc0`，完整值不在此记录）。 |
| **F-3**（P2 · 降级模式弹引导） | 读新版 `lib/pages/home/home_page.dart`；新增 TC-04-8 | **通过** | 第 1 步触发条件（:70 与 :74-78）均加 `!widget.degraded`。TC-04-8：降级首页无「点这里，位置自动记」、无「知道了」遮罩，`guideStepsSeen` 为空。 |
| **F-4**（P3 · 字号令牌） | 全 `lib/` 正则扫描 `Color(0x` / `fontSize:` / `Colors.` | **通过** | `Color(0x…)` 字面量**仅**存在于令牌文件 `app_colors.dart`；所有 `fontSize:` 均走 `AppTokens.*`，含新增 `AppTokens.fontSubtitle = 18`（`app_theme.dart`），已用于 AppBar 标题（:143）与主按钮（:164）。仅余 `Colors.transparent`（Material 常量，非品牌色）。 |
| **F-7**（P2 · 工具链） | 直接用 `.\tool\flutter.ps1` 跑 analyze / test 并读 `$LASTEXITCODE` | **通过** | `tool/flutter.ps1:42` 改 `$ErrorActionPreference = 'Continue'`。本轮 analyze、test 均由该脚本跑通：`analyze_exit=0`、`test_exit=0`（Round 1 需绕过脚本，本轮不再需要）。 |
| **F-5**（P3 · 裁决：不加截断） | 读控制器 + 本人契约用例 | **按裁决保留** | 控制器 `saveNewRecord` 仍不静默截断；`test/t03_parking_controller_test.dart`「4 张原样入库」契约用例保留、未被弱化改写。 |

## R2-2. 测试断言是否被削弱（独立核查）

- **测试文件未被改动**：Round 1 全量 90 例 → 本轮 90 例（原样）+ 4 例（本人新增）= **94 例**；无任何既有用例被删除或放宽。
- **重点核查红灯用例 TC-05-7 原样保留**：断言仍是「点目标**中心** → `targetTaps == 1`」，触发方式（`tapAt(getCenter(...))`）与 reason 文案与 Round 1 一字不差 —— **不是靠放松断言转绿，而是源码修复后真实转绿**。
- TC-05-4/5/6 及 F-5 契约用例（4 张）逐行比对，均未改动。

## R2-3. 新增边界用例（Round 1 未覆盖）

| 编号 | 场景 | 期望 | 结果 |
|---|---|---|---|
| **TC-05-8** | 带 AppBar **且**底部安全区（34px）**且**内容可滚动（滚动偏移） | 挖空区仍对齐目标，点目标中心可命中 | 通过 |
| **TC-05-9** | 目标贴近底部 → 气泡只能朝上放置 | 气泡矩形与目标**不重叠**（`bubble.bottom <= target.top`）；点目标不误触气泡「知道了」 | 通过 |
| **TC-05-10** | **RTL** 文本方向 + **320 窄屏** | 挖空区仍与目标对齐，目标可点 | 通过 |
| **TC-04-8** | **F-3**：降级模式（引导开关保持开启） | 不弹第 1 步引导、无遮罩、不写 `guideStepsSeen` | 通过 |

> 说明：TC-05-8 用 `tester.view` 注入底部安全区（`FakeViewPadding(bottom: 34)`）+ `SafeArea` + `ListView` 滚动，专门复现「AppBar 之外还有第二处垂直内边距」的组合场景；TC-05-10 用 `Directionality(rtl)` + 320 宽验证坐标换算与书写方向/窄屏无关（几何基于 `RenderBox`，与方向无关）。

## R2-4. 测试执行结果（Round 2）

| 项 | 结果 |
|---|---|
| `flutter analyze`（`.\tool\flutter.ps1 analyze`） | **No issues found!**（`analyze_exit=0`，ran in 6.8s） |
| `flutter test`（`.\tool\flutter.ps1 test`） | **All tests passed!**（`test_exit=0`） |
| 总用例 | **94**（既有 42 + Round 1 新增 48 + Round 2 新增 4） |
| 通过 / 失败 | **94 / 0** |

## R2-5. 新缺陷清单

**无。** Round 2 未发现任何新缺陷；Round 1 提出的 BUG-1 / BUG-2 / F-3 / F-4 / F-7 均已闭环，F-5 按裁决保持现行为。

## R2-6. 路由判定（Round 2）

| 目标 | 内容 |
|---|---|
| **发送给：NoOne** | 全部修复点独立复验通过；全量 **94/94 全绿**、`analyze` 无 issue；无新缺陷。**T03 判定为通过。** |
| 发送给：工程师 | 无。 |
| 发送给：QA（本人） | 无。 |

> 残余风险（不影响本轮判定，供 T04 / 真机回归）：真机相机路径、高德定位成功路径、iOS 侧等仍按上文「§6 未覆盖与残余风险」清单处理。
