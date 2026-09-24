# 贡献指南

感谢你想让「我车呢」变得更好。这是一个个人课程 / 自用性质的小项目，
目前**只有 Android 平台**在维护，所以能收到的贡献主要集中在这几类：

- 🐛 Bug 报告与修复（尤其是真机上的定位、地图、相机问题）
- 📸 **真机截图**（`docs/screenshots/` 已有 10 张，欢迎补充其他机型或主题的）
- 📝 文档错漏、构建脚本在新环境上的兼容性问题

---

## 提 Issue

**提交前请先搜索现有 Issue**，避免重复。

### Bug 报告请附上这些

缺了这些信息，问题基本没法定位，只能回复「请补充」：

| 项 | 说明 |
|---|---|
| 机型 | 例如「小米 14」 |
| Android 版本 | 例如「Android 14」 |
| 复现步骤 | 一步一步写清楚，从哪个页面点了哪里 |
| **应用内诊断日志** | **设置 → 诊断 → 诊断日志** 里的全部内容（这是最关键的一项） |
| 构建类型 | 是 debug 包还是 release 包（两者行为可能不同） |

> 应用会把未处理的异常落盘到诊断日志，很多真机闪退只能靠它取证。
> 请在**复现一次之后**再去取日志。

### 关于高德 Key 相关的问题

地图 / 定位不可用，请先确认：

1. 已按 [README 的「配置高德 Key」章节](README.md#3-配置高德-key必需)填好了 `android/local.properties`；
2. 包名填的是 `com.wochene.app`；
3. **debug 和 release 各申请了一个 Key**（两者签名 SHA1 不同，高德按「包名 + SHA1」鉴权）；
4. 已在应用内同意隐私政策（同意前高德 SDK 不会初始化）。

---

## 提 PR

### 合并前提

- `flutter analyze` **零 issue**；
- `flutter test` **全绿**（当前基线：**180 个用例全通过**，见 [README](README.md#测试)）；
- **不要为了让自己新加的代码通过而放宽既有的用例断言**——如果发现既有断言有问题，
  请在 PR 描述里说明理由并单独讨论；
- 遵循 [`analysis_options.yaml`](analysis_options.yaml) 的 lint 规则
  （`flutter_lints`，额外开启了 `public_member_api_docs`）。

```bash
flutter analyze
flutter test
```

> **Windows 用户**：若 `flutter test` 报
> `Unable to connect to flutter_tester process` / `WebSocketException: Invalid WebSocket upgrade request`，
> 是宿主环境注入了本地代理。请改用仓库内的包装脚本：
> ```powershell
> .\tool\flutter.ps1 test
> .\tool\flutter.ps1 analyze
> ```

### 代码风格

- **文档注释用中文**，且 public API 需要写文档注释（`public_member_api_docs` 会检查）。
- **显式类型标注**：不要写 `var` / `dynamic` 了事，变量、字段、返回值都写清楚类型。
- **颜色一律取 [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart) 里的令牌**（如 `AppColors.primary`）。
  **架构红线：页面里不允许写死色值**（`Color(0xFF...)` 这种只允许出现在令牌文件里）。
- 常量统一放在 [`lib/core/constants.dart`](lib/core/constants.dart)，不要各写各的键名。

### 提交前自检：不要提交私密文件

以下文件**已在 `.gitignore` 中**，正常情况下不会被提交，但请务必确认没有 `git add -f` 强加：

- `android/local.properties`（高德 Key）
- `android/keystore.properties`（签名口令）
- `*.jks` / `*.keystore` / `*.key`

**任何高德 Key、签名口令、证书文件都不允许进入版本库。** 如果你不小心提交了，请立即撤销并更换 Key。

---

## 补充真机截图

`docs/screenshots/` 目前已有 10 张真机截图（覆盖停车态、拍照、地图找车、历史、设置、
深色模式、新手引导与隐私同意弹窗），欢迎继续补充其他机型或主题的截图。建议：

- 命名沿用现有风格：`01-home-parking.jpg`、`02-camera.jpg`、`03-map-find.jpg` …，
  新增的按 `11-xxx.jpg` 依次往后编号（格式统一为 `.jpg`）；
- 浅色 / 深色两套主题都补上更好；
- 如果截图中含你不愿公开的地理位置或时间信息，**建议先抹掉再提交**
  （本仓库现有的 10 张截图由开发者本人授权公开，其中含真实地点名与时间戳）；
- 如果你不是截图里的出镜人，请确保画面中没有可识别的他人肖像。

---

## 许可证

- 你贡献给**主项目**的代码，将以 **MIT** 许可随项目分发（见 [LICENSE](LICENSE)）。
- 请勿改动 `third_party/` 下 vendored 高德插件的 Dart / Java 源码逻辑——
  那里是 **BSD 3-Clause（Copyright 2020 lbs.amap.com）**，且我们的改造原则是
  「只动构建脚本与 pubspec」，详见 [`third_party/README.md`](third_party/README.md)。
