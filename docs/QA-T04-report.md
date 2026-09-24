# QA 验证报告 —— T04 地图找车 / 历史 / 设置页 + P1 三项（方向箭头 / 桌面快捷方式 / 深色模式）

| 项目信息 | 内容 |
|---|---|
| 任务 | T04 独立验证 Round 1（QA 工程师：严过关 Edward） |
| 被测版本 | `wo_che_ne` T04 交付（工程师自测 5 个 `t04_*` 文件） |
| 验证环境 | Windows / Flutter（`C:\flutter`）/ 工程 `W:\wo_che_ne` |
| 验证手段 | 静态源码走查 + `aapt2` 直查 APK 本体 + 独立新增 27 条边界用例（只改 `test/`，未改 `lib/`） |
| 报告版本 | v1.0 |

> **说明**：本报告由 QA 独立编写，所有结论基于本人亲自执行的命令与自编测试，不引用工程师自测数字。
> **APK 取证说明**：`app-release.apk` 不存在，故对**最新构建的 `app-debug.apk`**（mtime `2026-09-23 22:59:55`，晚于全部源码最新改动 `22:03:59`，确为 T04 代码后的产物）做 `aapt2` 直查。

---

## 0. 执行摘要

| 项 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!**（exit 0） |
| `flutter test`（全量，含 QA 新增 27 例） | **141 / 141 全绿**（exit 0） |
| 10 条验收点 | **10 / 10 通过** |
| 源码缺陷 | **0 个**（未发现需工程师修改的源码 Bug） |
| 测试问题（本人自修） | **6 处**（均为我新增用例的脚手架/选择器写法问题，已自修并复跑转绿，见 §4） |
| **路由判定** | **NoOne（全通过）** —— 无需回工程师、无需再修测试 |

**一句话结论**：T04 全部落地正确；合规权限纪律不回归（APK 本体恰 8 条权限，无存储/录音）；P1 三项（方向箭头跨 0°、桌面快捷方式冷启动合规、深色模式三态）实测通过。唯一红灯来自我首轮新写用例的 6 个测试写法问题（选择器/动画 settle/需连续关两个权限框），**属 QA 类，已自修**。

---

## 1. 验证方法与独立取证手段

1. **纯静态先走查**：逐文件读 `lib/pages/{map_find,history,settings}`、`lib/widgets/photo_strip.dart`、`lib/services/{compass_service,shortcut_service}.dart`、`lib/app.dart`、`lib/pages/home/home_page.dart`、`lib/data/repositories/parking_repository.dart` 等，比对 PRD §4.4/4.5/4.7/§5 与架构 §7.7/§9-9。
2. **等构建落地再跑**：首轮遵守团队纪律「先静态、后跑 flutter」，等工程师 APK 重建（`app-debug.apk` mtime 22:59:55 > 源码 22:03:59）后再执行 `analyze` + `test`，避免争 `build/` 锁。
3. **产物级权限核对**：用 `aapt2 dump permissions` 与 `aapt2 dump xmltree --file AndroidManifest.xml` **直查 APK 本体**（非中间产物），核对权限条数与高德 Key。
4. **边界自补**：针对现有用例未覆盖的跨 0° 方位角、空照片记录、`maxRecords` 3/20 边界淘汰+级联删除、深色对比度，从零新写 27 条用例。
5. **真实文件系统**：淘汰/删除的照片级联用真实临时目录 + 真实文件存在性断言，而非 mock。
6. **断言削弱核查**：逐条核对既有用例是否被「为转绿而放松」，结论见 §5。

---

## 2. 新增测试资产（仅新增 `test/` 下文件，未改动 `lib/`）

| 文件 | 用例数 | 覆盖点（现有用例未覆盖处） |
|---|---|---|
| `test/t04_edge_geo_photo_test.dart` | 12 | **TC-EDGE-1** 跨 0° 方位角（正北≈0 / 车正北·机朝 350°→箭头 10° / 机朝 10°→箭头 350° / 359°↔1° 不反向跳变）；**TC-EDGE-2** PhotoStrip 空列表不占位、3 张一致、点开全屏页码 1/3→2/3 并可关、单张不显页码、`openPhotoViewer` 空列表守卫；**TC-EDGE-3** 0 张照片记录在详情页/地图页不崩、无空条、显示「0 张」 |
| `test/t04_edge_eviction_boundary_test.dart` | 4 | **TC-EDGE-4** 下限 3 触发淘汰且照片文件真删、磁盘无孤儿；**TC-EDGE-5** 上限 20 满 21 淘汰最早恰剩 20；**TC-EDGE-6** 含已归档优先淘汰「已归档中最早」；**TC-EDGE-7** `delete` 不误删他人照片 |
| `test/t04_edge_shortcut_coldstart_test.dart` | 2 | **TC-EDGE-8** 未同意隐私→快捷方式冷启动仍先弹同意门、不直达记录页（合规不绕过）；**TC-EDGE-9** 已同意→冷启动直达记录流程且不残留第 1 步引导 |
| `test/t04_edge_darkmode_test.dart` | 4 | **TC-EDGE-10/11/12** 三态 system/light/dark 真实切到 `MaterialApp.themeMode` 且 `Theme.brightness`、`scaffoldBackgroundColor` 正确；**TC-EDGE-13** 深色下文字/背景相对亮度差 > 0.5（可读） |
| `test/t04_edge_settings_boundary_test.dart` | 5 | **TC-EDGE-14/15** 到下限 3「减少」禁用、到上限 20「增加」禁用；**TC-EDGE-16** 越界写入被模型层钳制（100→20、1→3）；**TC-EDGE-17** 重置引导 `reset()` 清空状态 + SnackBar；**TC-EDGE-18** 隐私/权限/开源入口存在 |
| **合计** | **27** | |

> 基线：工程师 5 个 `t04_*` 文件 + T03 既有用例 = 114 条；114 + 27 = **141**，与全量实测吻合。

---

## 3. 十条验收点逐条结论

| # | 验收点 | 结论 | 关键证据 |
|---|---|---|---|
| 1 | **地图找车页**（PRD §4.4） | ✅ 通过 | `map_find_page.dart`：合规 `!ready` → `_buildMapUnavailable()` 令牌化占位；`_startStreams()` 在 gate 未就绪时直接 return（同意前不初始化定位）。`TC-MAP-1/2` + 我的 `TC-EDGE-3`（0 张照片不崩、归档按钮在） |
| 2 | **照片条**（§4.4 底部 1–3 张，点开全屏滑动+放大） | ✅ 通过 | `photo_strip.dart`：空→`SizedBox.shrink`；`PhotoThumb` 空→占位；`PhotoViewerPage` = `PageView.builder`+`InteractiveViewer(maxScale:4)`，单张不显页码。我的 `TC-EDGE-2`（5 例）全绿 |
| 3 | **历史列表**（§4.5 倒序 + 缩略图/时间/地点/距离） | ✅ 通过 | `history_page.dart` 用 `historyRecordsProvider`（按 `createdAt` 降序）；`_HistoryTile` 显示首图/时间/`poiName`/`GeoUtils.formatDistance`。`TC-HIS-1..` 全绿 |
| 4 | **详情页**（§4.5 同 4.4 布局，只读+可删除） | ✅ 通过 | `record_detail_page.dart`：地图预览（仅车位图钉）+ 时间/地点/状态/精度/坐标/张数；右上删除二次确认。`TC-HIS-4` + 我的 `TC-EDGE-3`（0 张/2 张两态）全绿 |
| 5 | **级联删除**（淘汰与删除都连照片文件一起删） | ✅ 通过 | `parking_repository.dart`：`delete()`→`_store.deletePhotos(id)`；`_evictIfNeeded()` 淘汰时 `deletePhotos(victim.id)`。我的 `TC-EDGE-4/5/6/7`（真实文件断言，含「磁盘无孤儿」）全绿 |
| 6 | **设置页全项**（§4.7：上限步进器 / 深色 / 震动 / 重置引导 / 权限 / 隐私 / 关于） | ✅ 通过 | `settings_page.dart` 七分组齐备；步进器 `canDecrease/canIncrease` 钳 3–20；`SegmentedButton<ThemeModePref>` 三态；`SwitchListTile` 震动；重置引导→`reset()`+SnackBar；权限→`openAppSettings`；隐私→本地静态页；关于→`packageInfoProvider`。`TC-SET-1..5` + 我的 `TC-EDGE-14..18` 全绿 |
| 7 | **P1-1 方向箭头**（方位角 + 指南针，跨 0°） | ✅ 通过 | `GeoUtils.bearingDeg`（atan2 + `(deg+360)%360`）；`CompassService.arrowRotationDeg = normalize(bearing − heading)`。我的 `TC-EDGE-1`（4 例）实测：车正北·机朝 350°→**10°**（非 350/-350）；机朝 10°→**350°**；359°↔1° 单调不反向 |
| 8 | **P1-2 桌面快捷方式**（「一键记车位」冷/热启动） | ✅ 通过 | `shortcut_service.dart` 自建通道 + `MainActivity.kt` 冷启动 `getLaunchAction`/热启动 `onNewIntent`；`app.dart` `_AppRoot` 订阅→`quickRecordRequestProvider`；`home_page.dart` 降级时**忽略**快捷方式（不绕过合规）。`TC-EDGE-8/9` 全绿：未同意仍弹同意门；已同意直达且不残留第 1 步引导 |
| 9 | **权限纪律**（架构 §9-9：恰 8 条权限） | ✅ 通过 | `aapt2 dump permissions app-debug.apk` = **恰 8 条**：`INTERNET`、`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`CAMERA`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`CHANGE_WIFI_STATE`、`VIBRATE`。**`READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` / `RECORD_AUDIO` 均不在**。另：`aapt2` 见 `com.amap.api.v2.apikey` meta-data 存在（前缀 `8cc0…`，长度 32，已脱敏） |
| 10 | **设计红线**（架构 §7.2：页面不写死色值） | ✅ 通过 | `lib/` 全目录 `Grep 'Color\(0x'` 仅命中 `core/theme/app_colors.dart`（16 处，唯一事实来源）；其余页面/组件零硬编码色值 |

**验收点通过：10 / 10。**

---

## 4. 测试问题（QA 自修，非源码缺陷）

首轮我新写的 27 例中有 6 例红灯，经逐条定位，**全部是我用例自身的脚手架/选择器写法问题**，源码行为正确。已自修并复跑转绿（第二次 `.\tool\flutter.ps1 test test\t04_edge_*.dart` 后 `t04_edge_geo_photo_test.dart` 12/12、全套 141/141）。

| 用例 | 现象 | 根因（我的测试写法） | 修法 |
|---|---|---|---|
| TC-EDGE-2（全屏浏览 / 单张页码） | `pumpAndSettle timed out` | `PhotoViewerPage` 在图片路径未就绪时显示 `CircularProgressIndicator`（持续动画），**永不 settle** | 改用固定帧 `pumpFrames(tester, 15)` |
| TC-EDGE-2（左右滑动翻页） | 拖拽后仍在 `1 / 3` | `InteractiveViewer` 参与手势竞技，慢 `drag` 被其吞掉，`PageView` 未翻页 | 改用带速度的 `tester.fling(..., 1200)` 模拟真实快滑 |
| TC-EDGE-9（快捷方式直达） | 找不到「未获得相机权限」 | 直达记录流程会**连续弹两个**权限说明框（首页「需要定位权限」→ 拍照页「需要相机权限」），我只关了第一个 | 改为循环点「暂不」直到无框（`declineRationales`） |
| TC-EDGE-14 / 15（步进器边界） | `type 'RawTooltip' is not a subtype of type 'IconButton'` | `find.byTooltip` 返回 `Tooltip` 而非 `IconButton` | 改 `find.widgetWithIcon(IconButton, Icons.remove_circle_outline)` 取按钮本体 |
| TC-EDGE-18（设置入口存在） | 找不到「隐私政策」 | 设置项多，底部「隐私/权限/关于」在首屏外，`ListView` **惰性构建**未挂载 | 先 `scrollUntilVisible` 再断言 |

> **重要**：以上 6 处**不涉及 `lib/` 任何改动**，也未削弱任何对源码行为的断言——期望值始终对齐 PRD/架构（如「箭头 10°」「未同意仍弹同意门」「恰 8 条权限」），仅修正了「如何驱动/定位 UI」的写法。

---

## 5. 既有断言削弱核查

对工程师在 T04 改动过的既有用例逐条核对，**未发现为转绿而放松断言**：

| 被改用例 | 改动内容 | 判定 |
|---|---|---|
| `test/t03_home_dual_state_test.dart` → `TC-01-6` | 由断言「地图占位文案」改为断言**真实地图页**的「找到了，归档」「地图需在同意隐私政策后显示」 | **合法更新（非削弱）**。T04 落地了真实 `MapFindPage`，旧断言针对的是 T03 的临时占位；新断言要求更具体（同时校验真实页面元素与合规占位），强度不降反升 |

其余 T03/T04 用例未见断言放松。

---

## 6. 缺陷清单

**源码缺陷：0 个。**

未发现需要工程师修改的源码 Bug。§4 的 6 处红灯均为本人测试写法问题，已自修；§5 未发现断言削弱。故**无需路由给工程师**。

---

## 7. 复现命令（供复核）

```powershell
Set-Location W:\wo_che_ne
# 1) 全量静态分析 + 全量测试
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
# 2) 仅 QA 新增边界用例
.\tool\flutter.ps1 test test\t04_edge_geo_photo_test.dart test\t04_edge_eviction_boundary_test.dart test\t04_edge_shortcut_coldstart_test.dart test\t04_edge_darkmode_test.dart test\t04_edge_settings_boundary_test.dart
# 3) APK 本体权限直查（恰 8 条，无存储/录音）
& "C:\Users\lenovo\AppData\Local\Android\Sdk\build-tools\36.0.0\aapt2.exe" dump permissions build\app\outputs\flutter-apk\app-debug.apk
```

实测输出：`analyze` exit 0；`test` **141/141 All tests passed**；`aapt2` 恰 8 条权限且无 `READ/WRITE_EXTERNAL_STORAGE`、无 `RECORD_AUDIO`。

---

## 8. 结论与路由

| 项 | 结论 |
|---|---|
| 10 条验收点 | **10 / 10 通过** |
| 全量测试 | **141 / 141 通过**（含 QA 新增 27 例） |
| 源码缺陷 | 0 |
| **路由判定** | **NoOne（全通过）** |

T04 交付通过 QA Round 1 独立验证，无需回退工程师，无需再修测试。
