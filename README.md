# 我车呢（wo-che-ne）

> 在偌大的校园里停好车，回头就忘了停哪？——「我车呢」帮你几秒记下车位，几秒找回车。

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform: Android](https://img.shields.io/badge/Platform-Android-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.47.5-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)
![minSdk](https://img.shields.io/badge/minSdk-24-blue.svg)

---

## 目录

- [📖 这是什么](#-这是什么)
  - [它做什么](#它做什么) · [它明确不做什么](#它明确不做什么) · [适合谁用](#适合谁用)
- [✨ 功能特性](#-功能特性)
- [📱 快速上手](#-快速上手)
  - [系统要求](#系统要求) · [下载安装](#下载安装) · [怎么用](#怎么用) · [常见问题 FAQ](#常见问题-faq)
- [🖼 界面预览](#-界面预览)
- [🔒 隐私与权限](#-隐私与权限)
- [🧱 项目结构](#-项目结构)
- [🛠 开发者指南](#-开发者指南)
  - [平台状态](#平台状态) · [环境要求](#环境要求) · [拉取代码](#拉取代码) · [配置高德 Key](#配置高德-key必需最大的坑) · [构建与安装](#构建与安装) · [技术栈](#技术栈) · [数据存储](#数据存储) · [关于 third_party](#关于-third_party) · [测试](#测试) · [文档索引](#文档索引) · [贡献](#贡献)
- [📄 许可与署名](#-许可与署名)

---

## 📖 这是什么

「我车呢」是一款**纯本地、无账号**的 Android 找车小工具，专门解决一个很小、但每天都会遇到的小麻烦：**停好车，回头就忘了停哪。**

**它要解决的小麻烦**：校园（尤其是车多、停车点密集的校区）里，一排排外观相似的自行车停在一起，下课后、饭后一出来，常常分不清自己的车停在**哪一排、哪一侧**，靠记忆找车既费时又容易绕路。常见的地图 App 只管"路怎么走"，不管"我的这辆车停在哪"。

**它怎么解决**——把「停车 → 找车」做成一个最短闭环：

- **停车时**：打开 App 自动定位，点一下「记下车位」，顺手可拍 0–3 张照片（车位、周围标志物），几秒完成一笔记录；
- **找车时**：打开 App 直接看到「最近一次记录」，点进去在地图上**同时看到「我的位置」和「车的位置」**，顶部还有「车在东北方向 · 230 米」这样的方向与直线距离提示，底部可翻看当时拍的照片来认车；
- **找到后**：点「找到了，归档」，该记录转入历史。

全部记录与照片只存在手机本地，不上传、不需要账号。

### 它做什么

- 一键记车位：打开首页自动定位，点「记下车位」即完成（拍照可选）。
- 地图找车：地图上同时显示「我的位置」与「车的位置」。
- 方向箭头 + 直线距离：不看地图也能凭方向感走过去。
- 拍照认车：定位不准时，主要靠当时拍的照片确认。
- 历史记录：按时间倒序查看、详情回看。
- 桌面快捷方式：长按图标「一键记车位」。

### 它明确不做什么

「极简」是本项目的**产品灵魂**，不是功能缺失。以下都是**刻意不做**：

- 账号 / 登录 / 云同步；
- 后端服务器（应用自身**没有任何网络请求**）；
- 埋点 / 统计 / 广告 SDK；
- 多辆车档案管理；
- 电子围栏、到点提醒、社交分享。

原因很简单：找车是一次「打开 → 看到 → 走过去」的短操作。任何账号、社交、多车管理的复杂度，都会拖慢它、也稀释它的用途；把这些全部砍掉，App 才能做到"打开就能用、几秒就记完"。

### 适合谁用

- 校园里骑自行车 / 电动车通勤的学生、教职工；
- 大型停车场、商圈、景区等"车多且相似"的场景同样适用。

**典型场景**：下课或饭后出来，打开 App → 看到「最近一次记录」→ 跟着方向与距离走过去 → 对照照片确认 → 归档。

---

## ✨ 功能特性

每条都交代「是什么 + 什么场景下有用」，不做无信息量的罗列。

- **秒记车位**：首页即停车页，打开自动开始定位，主按钮「记下车位」一点即可存下一笔记录（位置 + 可选照片 + 时间）。省掉"先选地点、再手动打字"的步骤，目标 ≤ 3 次点击 / ≤ 10 秒——赶时间也愿意用。
- **0–3 张照片，「拍够了就这样」**：拍照是**可选**的，0 / 1 / 2 / 3 张都是合法记录。快门右侧有描边按钮「拍够了就这样」（未拍照时显示「不拍了，直接记」），随时可结束，拍满 3 张则自动保存。它同时覆盖两种极端场景：车就停在楼下（不必拍照）与一排车一模一样（必须拍照）。
- **方向箭头 + 直线距离**：找车页顶部胶囊显示「车在东北方向 · 230 米」，由指南针朝向 + 两点坐标方位角在**本地**算出。不看地图、凭方向感就能走过去，对"路痴"尤其友好。
- **拍照认车**：定位在教学楼背阴面、树荫、半地下车棚可能漂移几十米，此时照片比地图更能确认"就是这一排、这一侧"。它是定位不确定时的主要兜底手段。
- **历史记录与自动淘汰**：历史页按时间倒序列出全部记录，点开可看详情（地图 / 照片 / 时间 / 地点）。保存条数默认 **10** 条（可在 **3–20** 间调整），达到上限时**自动淘汰最早一条及其照片文件**，记录不会无限堆积。
- **桌面快捷方式「一键记车位」**：长按 App 图标即可直接开始记录，连"打开 App"那一步都省掉。
- **深色模式**：可跟随系统，或手动固定为浅色 / 深色；夜间找车不刺眼，地图底图同步切换暗色。
- **震动反馈**：记录完成时轻震一下作为"无屏确认"，默认开启、可在设置中关闭（设置里还提供「试一下震动」）。
- **叠加式新手引导**：首次使用时在**真实界面**上叠加 3 步 Coach Marks（首页 → 拍照页 → 找车卡），边走流程边学，任一步可勾选「以后不再提示」永久关闭；设置页可随时「重新查看新手引导」。
- **诊断日志**：设置内提供「诊断日志」，用于查看 / 复制 / 清空本机错误记录，方便反馈闪退等问题时取证。
- **纯本地存储**：记录与照片只存在应用私有目录，不写入系统相册、不上传、不需要账号。

---

## 📱 快速上手

面向**使用者**，从安装到上手。

### 系统要求

| 项 | 要求 |
|---|---|
| 系统 | **Android 7.0（API 24）及以上**（`minSdk = 24`，`targetSdk = 36`） |
| 权限 | 定位（记录车位、找车；点「记下车位」时才申请）、相机（拍照；进拍照页时才申请）；振动与网络为普通权限 |
| 网络 | 地图与定位由高德 SDK 提供，需要联网 |

### 下载安装

1. 打开 [Releases 页面](https://github.com/LingFengyuTHU/wo-che-ne/releases/latest)，下载最新的 `.apk`。
2. 手机上允许「安装未知来源应用」，点击 APK 安装。

**安装注意**：

- 若手机上装过 **debug 包**（或其它签名的同名 APK），请**先卸载**再装 release 包——两者签名不同，直接覆盖安装会失败。
- 公开分发的 APK 内嵌了**本项目的 release 高德 Key**，因此安装者的地图 / 定位请求会**消耗本项目的配额**（这也是本项目开源、并鼓励自建的原因之一）。若你的用量较大，建议按 [开发者指南](#-开发者指南)自行构建一个使用**你自己高德 Key** 的包。

### 怎么用

**① 第一次使用**

1. 打开 App，首启会弹出**隐私政策同意框**；**同意后**高德 SDK 才会初始化（这是合规要求的"延迟初始化"）。
2. 首页会依次出现 3 步叠加式新手引导，跟着操作即可；任一步可勾选「以后不再提示」。

**② 记车位**

1. 打开 App（首页会自动开始定位）。
2. 点主按钮「**记下车位**」。
3. （可选）进入拍照页，拍 1–3 张车的位置或周围标志物；拍不够就点「**拍够了就这样**」，拍满 3 张会自动保存。
4. 记录保存完成，首页切换到"找车态"。

**③ 找车**

1. 打开 App，点首页的「**最近一次记录**」卡片。
2. 在找车页看地图上的「我的位置」（蓝点）与「车的位置」（图钉），以及顶部的方向与直线距离。
3. 到车附近后，可翻看照片确认是哪一辆。
4. 找到后点「**找到了，归档**」，该记录转入历史。

**④ 查看历史**

1. 首页右上角进入「历史记录」。
2. 列表按时间倒序，点任意一条查看详情（地图 / 照片 / 时间 / 地点）。

### 常见问题 FAQ

**Q1：定位不准怎么办？**
高德融合定位在开阔区域较准；在建筑边缘、树荫、半地下车棚等处可能漂移几十米。建议记车位时**拍 1–3 张照片**（车位、周围标志物），找车时以照片为主要确认依据。定位精度较差时，界面也会提示"定位不准，主要靠照片认车"。

**Q2：为什么不需要注册账号？**
本应用在设计上就没有账号、也没有后端：记录与照片只存在你本机的应用私有目录，**应用自身不发出任何网络请求**（只有高德 SDK 为了地图 / 定位联网），所以不存在"登录"这一步，也不会收集你的账号信息。

**Q3：换手机，数据怎么办？**
数据只保存在本机，**没有云同步**，因此换机不会自动迁移——目前需要在新手机上重新记录。这是"纯本地、零数据出设备"取舍的结果。

**Q4：装不上 / 提示"签名冲突 / 无法安装"？**
多半是手机上已存在同包名、但签名不同的 APK（例如之前的 debug 包）。**先卸载旧包**，再安装新的 release 包即可。

**Q5：地图区域空白 / 一直加载？**
先确认手机已联网，并**已在 App 内同意隐私政策**——同意前高德 SDK 不会初始化，地图与定位都不可用。若使用的是公开分发的 APK，其内嵌的是本项目的 release Key，若该 Key 的日调用配额用尽，地图 / 定位也可能失效；此时可改用**自行构建**（用你自己的高德 Key）的包。

**Q6：记录会不会丢？**
记录与照片存于应用私有目录，正常使用不会丢；但**卸载应用会连同全部数据一起删除**，且没有云备份。另外历史上限默认 10 条，超出上限时会自动淘汰最早的记录（含其照片），可在设置中调整到最多 20 条。

---

## 🖼 界面预览

| 首页 · 停车态 | 拍照页 | 地图找车页 | 首页 · 找车态 |
|:---:|:---:|:---:|:---:|
| ![首页 · 停车态](docs/screenshots/01-home-parking.jpg) | ![拍照页](docs/screenshots/02-camera.jpg) | ![地图找车页](docs/screenshots/03-map-find.jpg) | ![首页 · 找车态](docs/screenshots/04-home-find.jpg) |

更多截图见 [docs/screenshots/](docs/screenshots/)（共 10 张真机原图，含历史、设置、深色模式、新手引导、隐私同意弹窗）。

---

## 🔒 隐私与权限

一句话：**本应用不收集、不上传、不分享任何用户数据，你的全部数据只存在你自己的手机里。**

**数据存在哪**

| 数据 | 用途 | 存储位置 |
|---|---|---|
| 停车位置（经纬度、地点名、时间） | 帮你找到车 | 应用私有目录（`records.json`） |
| 停车照片（0–3 张/条） | 凭照片认车 | 应用私有目录（`photos/`），**不写入系统相册** |
| 应用设置（记录上限、主题、引导状态等） | 记住你的偏好 | 系统键值存储（SharedPreferences） |

**申请的权限及用途**

| 权限 | 何时申请 | 用途 |
|---|---|---|
| 精确定位 / 粗略定位 | 你点「记下车位」时 | 记录车位坐标、找车时显示「我的位置」 |
| 相机 | 你进入拍照页时 | 拍摄停车照片（仅存入应用私有目录） |
| 振动（普通权限） | — | 记录完成的轻震反馈 |
| 网络 / 网络状态 / Wi-Fi 状态（普通权限） | — | 高德地图 SDK 提供地图与定位所必需 |

**明确不申请的权限**：相册读取（`READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`）、外部存储写入（`WRITE_EXTERNAL_STORAGE`）、录音（`RECORD_AUDIO`）——这些即使被第三方插件带入，也已在 `AndroidManifest.xml` 中**显式移除**。照片只进应用私有目录，不碰系统相册。

**网络请求**：**仅**高德 SDK 为提供地图与定位服务而联网；应用自身**没有任何网络请求**，无埋点、无统计、无广告 SDK。

**拒绝授权也能用**：定位被拒可用纯照片记录，相机被拒可用纯定位记录。

**卸载即删除**：卸载应用会删除全部数据（含照片），不留残余。

完整说明见 [PRIVACY.md](PRIVACY.md)（应用内「设置 → 隐私 → 隐私政策」与仓库同步维护）。

---

## 🧱 项目结构

```
wo-che-ne/
├── lib/                    # Dart 源码（分层：UI → 状态 → 服务/数据 → 平台）
│   ├── main.dart           # 应用入口（启动装配、隐私同意门）
│   ├── app.dart            # 根组件 MaterialApp（主题 / 路由 / 深色模式）
│   ├── core/               # 全局常量、主题令牌、工具
│   │   ├── constants.dart  #   应用信息 / 存储键名 / 默认上限 / 路由名
│   │   ├── theme/          #   颜色与主题令牌（app_colors / app_theme）
│   │   └── utils/          #   地理计算（geo_utils）、时间格式化（time_utils）
│   ├── data/               # 数据层（与插件解耦，可单测）
│   │   ├── models/         #   ParkingRecord / AppSettings
│   │   ├── repositories/   #   ParkingRepository / SettingsRepository（接口 + 实现）
│   │   └── storage/        #   local_store.dart（JSON 文件 + 照片读写）
│   ├── services/           # 平台服务
│   │   ├── amap_sdk_gate.dart      #   高德 SDK 延迟初始化门
│   │   ├── location_service.dart   #   融合定位
│   │   ├── compass_service.dart    #   指南针朝向（方向箭头）
│   │   ├── shortcut_service.dart   #   桌面快捷方式「一键记车位」
│   │   ├── haptic_service.dart     #   震动反馈
│   │   └── diagnostics_service.dart#   诊断日志
│   ├── state/              # 状态层（Riverpod）
│   │   ├── providers.dart          #   Provider 定义
│   │   ├── parking_controller.dart #   记录读写 / 淘汰
│   │   ├── settings_controller.dart#   设置
│   │   └── coach_mark_controller.dart # 叠加式新手引导
│   ├── pages/              # 页面
│   │   ├── home/           #   首页（停车态 / 找车态双状态）
│   │   ├── camera/         #   拍照页
│   │   ├── map_find/       #   地图找车页
│   │   ├── history/        #   历史列表 / 记录详情
│   │   └── settings/       #   设置 / 诊断日志
│   └── widgets/            # 可复用组件（主按钮、照片条、引导遮罩、隐私弹窗等）
├── android/                # Android 平台工程
│   ├── app/build.gradle.kts    # applicationId / SDK 版本 / Key 注入 / 签名
│   ├── app/src/main/           # AndroidManifest、图标、strings、shortcuts.xml
│   ├── gradlew · gradle/       # 自带 Gradle Wrapper（无需预装 Gradle）
│   ├── local.properties.example# 本地私密配置模板（真实 local.properties 不入库）
│   └── settings.gradle.kts     # 插件版本、阿里云 Maven 镜像
├── assets/                 # 设计素材（AI 生成插图与 app_icon）
│   └── prompts.md          #   生图提示词记录（可复现、可二次创作）
├── docs/                   # 文档
│   ├── PRD.md              #   产品需求文档
│   ├── ARCHITECTURE.md     #   系统架构设计
│   ├── QA-T03/T04/T05-report.md  # 各阶段 QA 独立验证报告
│   └── screenshots/        #   10 张真机截图
├── test/                   # 单元 / Widget 测试（含 support/ 测试脚手架）
├── third_party/            # vendored 高德 Flutter 插件（BSD 3-Clause，见下）
├── tool/
│   └── flutter.ps1         # Windows 命令包装脚本（自动设 NO_PROXY）
├── pubspec.yaml            # 依赖与版本
├── analysis_options.yaml   # 静态检查规则（flutter_lints）
├── PRIVACY.md · CONTRIBUTING.md · LICENSE
└── README.md
```

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

---

## 📄 许可与署名

- **主项目**：MIT，见 [LICENSE](LICENSE)（Copyright (c) 2026 我车呢贡献者）；`third_party/` 为 BSD 3-Clause。
- **高德地图 SDK**：其使用受《高德地图开放平台服务条款》约束，需自行申请 Key。
- **开发者署名**：**聆风语**（<https://github.com/LingFengyuTHU>）——应用内「设置 → 关于」展示。
- 全部设计素材由 AI 生图自产，提示词记录于 [assets/prompts.md](assets/prompts.md)。
