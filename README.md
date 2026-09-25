# 我车呢（wo-che-ne）

> 在偌大的校园里停好车，回头就忘了停哪？——「我车呢」帮你 10 秒记下车位，10 秒找回车。

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform: Android](https://img.shields.io/badge/Platform-Android-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.47.5-blue.svg)

---

## 📱 下载体验

**纯本地的找车小工具**：停车时花几秒记下「位置 + 照片」，找车时地图告诉你车在哪个方向、多远，再对着当时拍的照片认。

- 📍 **秒记车位**——拍 0–3 张照片即可存好一笔记录，目标 ≤ 3 次点击、≤ 10 秒
- 🧭 **找车给方向和距离**——顶部胶囊显示「车在东方向 · 25 米」，带方向箭头
- 📷 **拍照认车**——不拍照也能记，定位不准时主要靠照片认
- 🌙 **深色模式**——可选跟随系统 / 浅色 / 深色
- 🔒 **数据全在本机**——无账号、无后端、无云同步，照片只存应用私有目录
- 🫥 **不申请相册/录音权限**——除了高德 SDK 提供地图/定位所必需的网络请求，应用自身没有任何网络请求

**[⬇️ 前往 Releases 下载最新版 APK](https://github.com/LingFengyuTHU/wo-che-ne/releases/latest)**

> ⚠️ 安装提示：手机上装过 debug 包的话，请**先卸载**再装 release 包（两者签名不同，直接覆盖会失败）。
>
> 🔒 隐私：全部数据只存在你手机本机，无账号、无后端。详见 [PRIVACY.md](PRIVACY.md)。

| 首页 · 停车态 | 拍照页 | 地图找车页 | 首页 · 找车态 |
|:---:|:---:|:---:|:---:|
| ![首页 · 停车态](docs/screenshots/01-home-parking.jpg) | ![拍照页](docs/screenshots/02-camera.jpg) | ![地图找车页](docs/screenshots/03-map-find.jpg) | ![首页 · 找车态](docs/screenshots/04-home-find.jpg) |

更多截图见 [docs/screenshots/](docs/screenshots/)（共 10 张真机原图，含历史、设置、深色模式、新手引导、隐私同意弹窗）。

---

## 🛠 开发者指南

### 平台状态

| 平台 | 状态 |
|---|---|
| **Android** | ✅ 实际开发并在真机跑通的唯一平台，构建脚本、权限、图标均只针对 Android 配置 |
| iOS | ⚠️ `ios/` 是 `flutter create` 生成的脚手架，未做任何适配（未配置高德 iOS Key，未添加定位用途描述），**不能直接构建运行** |

### 环境要求

| 项 | 要求 | 取值来自 |
|---|---|---|
| Flutter / Dart | Dart SDK `^3.13.4`；实测环境 Flutter 3.47.5 / Dart 3.13.4 | `pubspec.yaml` / 本机 `flutter --version` |
| JDK | 17 | `android/app/build.gradle.kts`（`VERSION_17` / `JVM_17`） |
| Android Gradle Plugin | 9.1.0 | `android/settings.gradle.kts` |
| Kotlin | 2.4.0 | `android/settings.gradle.kts` |
| Android SDK | 不硬编码，`compileSdk` / `minSdk` / `targetSdk` 均取 Flutter 工具链默认值 | `android/app/build.gradle.kts`（`flutter.*SdkVersion`） |
| Gradle | 无需预装，仓库自带 Gradle Wrapper | `android/gradlew` / `gradle-wrapper.jar` |

### 拉取代码

```bash
git clone https://github.com/LingFengyuTHU/wo-che-ne
cd wo-che-ne
flutter pub get
```

中国大陆网络可按需设置镜像：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`（Maven 仓库已配置阿里云镜像优先，见 `android/settings.gradle.kts`）。

### 配置高德 Key（必需，最大的坑）

地图与定位用的是高德 Android SDK，而高德按 **「包名 + 签名 SHA1」** 鉴权。本项目的 debug 包和 release 包**签名不同**（debug 用本机 debug keystore，release 用你自己的发布 keystore），两者 SHA1 不一样，所以**必须各申请一个 Key**：

| 字段 | 给谁用 | 绑定的签名 |
|---|---|---|
| `AMAP_KEY` | debug 包 | 本机 debug keystore 的 SHA1 |
| `AMAP_KEY_RELEASE` | release 包 | 你自己的 release keystore 的 SHA1 |

**步骤**：

1. 注册[高德开放平台](https://lbs.amap.com/)个人开发者并完成实名认证。
2. 控制台 → 应用管理 → 创建应用 → 添加 Key（服务平台选 **Android**）：
   - 包名填 **`com.wochene.app`**（必须与 `applicationId` 一致）；
   - 签名 SHA1 用你自己的（本仓库**不含任何 keystore**，已被 `.gitignore` 排除）：
     ```bash
     # debug（本机默认 debug keystore）
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     # release（用你自己生成的 keystore）
     keytool -list -v -keystore <你的.jks> -alias <别名>
     ```
3. 复制 [`android/local.properties.example`](android/local.properties.example) 为 `android/local.properties`，填入两个 Key（以 `请在此填入` 开头的值视为未配置）。该文件已被 `.gitignore` 排除，**Key 绝不提交进 Git**。

**三种配置情况的后果**（逻辑见 `android/app/build.gradle.kts`）：

| 配置情况 | 后果 |
|---|---|
| 两个都配了 | ✅ 正常 |
| 只配 `AMAP_KEY` | ⚠️ Release 回退嵌这个 Key 并警告——它绑定 debug 签名，真机地图无法鉴权 |
| 都没配 | Debug 放行（嵌占位值，真机地图不可用，编译/单测不受影响）；**Release 构建直接中止** |

### 构建与安装

```bash
flutter build apk --debug      # 调试包（未配高德 Key 也能构建）
flutter build apk --release    # 发布包（必须已配置高德 Key，否则构建中止）
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release 正式分发需自行生成 keystore 并创建 `android/keystore.properties`（四项：`storeFile` / `storePassword` / `keyAlias` / `keyPassword`，同样不入库）；文件缺失时回退 debug 签名并警告，该包不可用于正式分发。

### 技术栈

具体版本以 [`pubspec.yaml`](pubspec.yaml) 为准：

| 类别 | 选型 |
|---|---|
| 框架 | Flutter / Dart |
| 状态管理 | `flutter_riverpod` |
| 本地存储 | `shared_preferences` + `path_provider` |
| 拍照 | `camera` |
| 地图 / 定位 | 高德 `amap_flutter_map` / `amap_flutter_location` / `amap_flutter_base`（vendored，见下） |
| 运行时权限 | `permission_handler` |
| 指南针朝向 | `flutter_compass_v2` |
| 其他 | `vibration`、`intl`、`uuid`、`package_info_plus` |
| 静态检查 / 测试 | `flutter_lints`（见 [`analysis_options.yaml`](analysis_options.yaml)）、`mocktail` |

### 数据存储

```
应用私有目录/
├── records.json     # 全部停车记录（单个 JSON 文件）
└── photos/          # 停车照片
SharedPreferences    # 设置项，键名形如 settings.maxRecords
```

无 SQLite、无后端、无账号。记录上限默认 **10** 条（可调 3–20，超限淘汰最早），每条记录最多 **3** 张照片。卸载应用即删除全部数据。

### 关于 `third_party/`

高德官方 Flutter 插件最新版仍是 3.0.0（2022 年，已停止维护），与新工具链不兼容，本仓库将其 vendoring 到 `third_party/` 并经 `dependency_overrides` 指向本地路径，做了最小现代化改造（只改构建脚本与 pubspec，不改 Dart/Java 源码逻辑）。

> ⚠️ **许可证不同**：`third_party/amap_flutter_*` 各包为 **BSD 3-Clause（Copyright 2020 lbs.amap.com）**，与主项目的 MIT 不同，二次分发时请一并保留这些 LICENSE。详见 [`third_party/README.md`](third_party/README.md)。
>
> 另外：release 构建的 R8 会打断高德 SDK 的反射调用，[`android/app/proguard-rules.pro`](android/app/proguard-rules.pro) 中已保留 `com.amap.api.**` / `com.autonavi.**` / `com.amap.flutter.**`。

### 测试

Flutter 3.47.5 / Dart 3.13.4（stable）环境下实测：

```bash
flutter analyze    # → No issues found!
flutter test       # → 180 个用例全通过
```

> Windows 用户：若 `flutter test` 报 `WebSocketException: Invalid WebSocket upgrade request`（宿主环境注入了本地代理），改用 [`tool/flutter.ps1`](tool/flutter.ps1)：
> ```powershell
> .\tool\flutter.ps1 test
> .\tool\flutter.ps1 analyze
> ```

### 文档索引

| 文档 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 产品需求文档（v1.2）：产品目标与核心指标、功能范围、权限与隐私红线 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 系统架构设计（v1.3）：分层结构、插件选型、关键难点对策 |
| [PRIVACY.md](PRIVACY.md) | 隐私政策（应用内与仓库同步维护） |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 如何提 Issue / PR、代码风格与测试要求 |
| [third_party/README.md](third_party/README.md) | vendored 高德插件的改造清单与维护指引 |
| [assets/prompts.md](assets/prompts.md) | 设计素材的 AI 生图提示词记录（素材自产、可复现） |
| [docs/QA-T03-report.md](docs/QA-T03-report.md) · [QA-T04](docs/QA-T04-report.md) · [QA-T05](docs/QA-T05-report.md) | 各阶段 QA 独立验证报告 |

### 贡献

欢迎提 Issue / PR，要求见 [CONTRIBUTING.md](CONTRIBUTING.md)。欢迎补充其他机型或主题的真机截图。

## 许可与署名

- **主项目**：MIT，见 [LICENSE](LICENSE)（Copyright (c) 2026 我车呢贡献者）；`third_party/` 为 BSD 3-Clause。
- **高德地图 SDK**：其使用受《高德地图开放平台服务条款》约束，需自行申请 Key。
- **开发者署名**：**聆风语**（<https://github.com/LingFengyuTHU>）——应用内「设置 → 关于」展示。
- 全部设计素材由 AI 生图自产，提示词记录于 [assets/prompts.md](assets/prompts.md)。
