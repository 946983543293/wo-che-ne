# QA 验证报告 —— T05 发布基础设施 + 密钥安全 + 素材/图标 + 文档

| 项目信息 | 内容 |
|---|---|
| 任务 | T05 独立验证 Round 1（QA 工程师：严过关 Edward） |
| 被测版本 | `wo_che_ne` T05 交付（发布基础设施 + 仓库卫生 + 文档 + 设计素材/图标） |
| 验证环境 | Windows / Flutter 3.47.5（`C:\flutter`）/ 工程 `W:\wo_che_ne` |
| 验证手段 | `apksigner`/`aapt2` 直查 APK 本体 + 全仓库密钥泄漏扫描 + 临时副本 `git check-ignore` 实证 + 静态走查 |
| 报告版本 | v1.0 |

> **说明**：本报告由 QA 独立编写，所有结论基于本人亲自执行的命令，不采信工程师/主理人自述。
> **敏感值脱敏**：本报告内高德 Key 一律只写前缀 `8cc0…`（长度 32），keystore 口令一律不出现。

---

## 0. 执行摘要

| 项 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!**（exit 0） |
| `flutter test`（全量） | **141 / 141 全绿**（exit 0，无回归） |
| 验证清单 | **15 / 15 通过** |
| **密钥/口令泄漏扫描** | ✅ **无泄漏（P0 项安全）** —— 详见 §2.B |
| 缺陷 | **0 个 P0/P1/P2**；**1 个 P3（文档措辞，非阻塞）** —— 见 §3 |
| **路由判定** | **NoOne（全通过）** —— 无需回工程师、无需自修测试 |

**一句话结论**：release 签名确为**非 debug 正式证书**（DN/SHA-1 与主理人给值一致，且与 debug 证书实测不同）；权限不回归（release 本体恰 8 条，无存储/媒体/录音）；**高德 Key 与 keystore 口令全仓库仅各出现在 1 个被 `.gitignore` 覆盖的文件中，无任何残留泄漏**；`.gitignore` 覆盖完整且无 `!` 反悔；文档、素材、图标均核验通过；analyze/test 无回归。

---

## 1. 验证方法与独立取证手段

1. **产物级直查**：用 `apksigner verify --print-certs` 对 release **与** debug 两个 APK 分别取证书，交叉比对证明「release 真的换了签名」；用 `aapt2 dump permissions` / `dump badging` / `dump xmltree` 直查 release APK 本体。
2. **密钥泄漏全仓库扫描**：先读 `android/local.properties` 与 `android/keystore.properties` 拿到真实值，再以「完整 Key 值」「完整口令值」「Key 前缀 `8cc0[0-9a-f]{4,}`」三种模式全仓库 `Grep`（含隐藏文件），逐一分类命中项。
3. **`.gitignore` 真实手段验证**：把工程复制到 `%TEMP%` 临时副本（排除 `build/`、`.dart_tool/`、`.gradle/`、`third_party/` 等），在**副本**里 `git init` + `git add -A` + `git status --porcelain` + `git check-ignore -v`，列出**实际会被提交的文件清单**。**未在 `W:\wo_che_ne` 本体执行任何 git 命令**（不污染交付物）。
4. **残留诊断物复查**：递归扫描 `wochene_*` / `verify*` / `_t05_*` / `*.log` / `*.txt` / `*.bak`（排除 build/.dart_tool/third_party），确认主理人清理彻底。
5. **静态走查**：读 `android/app/build.gradle.kts` 签名逻辑、`README.md`、`.gitignore`（UTF-8 读回中文）、`assets/prompts.md`、图标 XML。
6. **图标人工核验**：直接读图 `assets/images/app_icon.png` 与 `res/mipmap-xxxhdpi/ic_launcher.png` 目视确认非 Flutter 默认图标。

---

## 2. 验证清单逐条结论

### A. 发布产物

| # | 验收点 | 结论 | 证据（本人实测） |
|---|---|---|---|
| A1 | release APK 签名**非 debug**；与 debug 证书**确实不同** | ✅ 通过 | `apksigner verify --print-certs app-release.apk` → DN `CN=WoCheNe, OU=Mobile, O=WoCheNe, L=Beijing, ST=Beijing, C=CN`；SHA-1 `adb49ab282475dbf9507b48c6799f7dff8d8a7fb`（= 主理人给值，大小写不敏感一致）。`app-debug.apk` → DN `CN=Android Debug, O=Android, C=US`；SHA-1 `4b68a53326ed41aaa2620a239710bbc55b4a209e`。**两者 DN 与 SHA-1 均不同**，证明 release 确换了签名而非沿用 debug |
| A2 | 权限不回归（release 本体） | ✅ 通过 | `aapt2 dump permissions app-release.apk` = **恰 8 条系统权限**：`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`CAMERA`、`INTERNET`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`CHANGE_WIFI_STATE`、`VIBRATE`。**`READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` / `RECORD_AUDIO` 均不在**（另 1 条 `com.wochene.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` 为 androidx 自定义权限，非系统权限） |
| A3 | 包名 / 元数据 | ✅ 通过 | `dump badging`：`package: name='com.wochene.app' versionCode='1' versionName='1.0.0' compileSdkVersion='36' targetSdkVersion='36' minSdkVersion:'24'`。`dump xmltree`：`com.amap.api.v2.apikey` 元数据在包内（值前缀 `8cc0…`，长度 32）；`android.app.shortcuts` 元数据在包内（`@0x7f100000` → `res/xml/shortcuts.xml`） |
| A4 | APK 时间戳晚于全部源码（含图标资源） | ✅ 通过 | `app-release.apk` mtime **2026-09-23 23:43:50**（78,867,770 B，与主理人给值一致）；全部源码/资源最新 mtime = `res/mipmap-anydpi-v26/ic_launcher.xml` **23:14:16**。23:43:50 > 23:14:16 ✓ |

### B. 密钥与口令安全（**本轮最高优先级**）

| # | 验收点 | 结论 | 证据（本人实测） |
|---|---|---|---|
| B5 | **真实高德 Key 是否泄漏** | ✅ **无泄漏** | 全仓库搜完整 Key 值 `8cc0…2660`：命中项仅 `android/local.properties` + `build/**` 中间产物；搜前缀 `8cc0[0-9a-f]{4,}`：同上。**排除 `build/` 后，唯一命中 = `android/local.properties`**，该文件被 `android/.gitignore:6:/local.properties` 与根 `.gitignore:52:local.properties` 双重忽略。主理人提及的残留诊断日志 `wochene_apikey_verify.log` / `wochene_verify3.log` **已不存在**；递归扫 `wochene_*`/`verify*`/`_t05_*`/`*.log`/`*.txt`/`*.bak`（排除 build/.dart_tool/third_party）→ **NONE（clean）** |
| B6 | **keystore 口令是否泄漏** | ✅ **无泄漏** | 搜完整口令值 `-GomJRY0…PyPb`：命中项**仅** `android/keystore.properties` 一个文件。搜 `storePassword`/`keyPassword`（排除 build）：命中 `README.md`（占位符「你的口令」）、`android/keystore.properties`（真实值，已忽略）、`android/app/build.gradle.kts`（仅属性名读取）。**口令未出现在任何 `.md`/`.log`/`.txt`/源码中** |
| B7 | `.gitignore` 覆盖完整且无 `!` 反悔 | ✅ 通过 | 根 `.gitignore` 含：`local.properties`、`android/local.properties`、`*.jks`、`*.key`、`*.keystore`、`keystore.properties`、`.env`、`.env.*`；`android/.gitignore` 另含 `/local.properties`、`keystore.properties`、`**/*.keystore`、`**/*.jks`。**全仓库 `.gitignore` 无任何 `!` 否定规则**（实测 count=0）。**临时副本 `git init`+`add -A` 实证**：`git check-ignore -v` → `android/local.properties`、`android/keystore.properties`、`android/app/wochene-release.jks` **全部被忽略**；`git status --porcelain` 的**实际提交清单中不含**任何 `.jks`/`.keystore`/`keystore.properties`/真实 `local.properties`（`android/local.properties.example` 模板入库属预期，内容为占位符「请在此填入你的高德Key」） |
| B8 | `.gitignore` 中文无乱码 | ✅ 通过 | 以 UTF-8 读回根 `.gitignore` 尾部「开源红线（PRD §6.2）」段，中文注释与条目**全部正常无乱码**（见 §6 复现） |

### C. 签名配置健壮性

| # | 验收点 | 结论 | 证据 |
|---|---|---|---|
| C9 | 签名逻辑健壮，无「静默用错签名」风险；AMAP_KEY 逻辑未被破坏 | ✅ 通过 | `build.gradle.kts:55-59`：`hasReleaseKeystore = keystorePropsFile.exists() && 四项均 !isNullOrBlank()` —— **四项逐项非空校验**，任一项缺失即回退，**不存在「某一项为空却仍判定可用」的静默误用路径**。`:61-72` 缺失时打印中文警告；`:109-117` 仅齐全才 `create("release")`；`:123-127` 有则 `release`、无则 `debug`；`:156-173` `assembleRelease`/`packageRelease*` 缺正式签名时给清晰中文警告（不中止，便于协作者 `flutter run --release`）。AMAP_KEY 逻辑（`:15-40` 读取 + `:102-104` 占位符注入 + `:133-153` release 强制校验）**完整未被改动**，与 T03/T04 一致 |

### D. 文档正确性

| # | 验收点 | 结论 | 证据 |
|---|---|---|---|
| D10 | README 事实核对 + 引用路径存在 + 无完整 Key | ✅ 通过 | ① 构建环境写 `platforms;android-36`、`build-tools;36.0.0`（README:27）——与 APK `compileSdkVersion='36'` 一致，且本机 `Sdk\platforms\android-36`、`build-tools\36.0.0` **均存在**；② 「高德 Key 自助申请」（README:50-54）已明确「**本仓库不包含任何 keystore**」「**用你自己的签名指纹**」，未再声称含 keystore 或给「可直接使用」的 SHA1；③ 「发布签名」段（README:71）已改为「**本仓库不附带 keystore，请自行生成并离线备份**」；④ 「真机安装」段（README:113-115）含 debug→release 换签名需先 `adb uninstall com.wochene.app` 的提示；⑤ 引用相对路径**全部存在**：`LICENSE`(1075B)、`PRIVACY.md`(2358B)、`docs/screenshots/01-home-parking.png`(22295B)、`02-camera.png`(20478B)、`03-map-find.png`(23163B)、`assets/prompts.md`(4074B)、`android/local.properties.example`(569B)；⑥ README 内 `Grep '8cc0'` **零命中**（仅占位符「你的高德Key」）；`Grep 'AMAP_KEY'` 仅占位符行。另：「3 次点击、≤10 秒」（README:16）与 PRD §3（`≤10 秒`/`≤3 次`）一致；`flutter --version` = 3.47.5 / Dart 3.13.4，满足 README「≥3.47 / ≥3.13」 |

### E. 素材与图标

| # | 验收点 | 结论 | 证据 |
|---|---|---|---|
| E11 | `assets/images/` 三图存在且体积合理；`prompts.md` 记录提示词 | ✅ 通过 | `empty_state_bikes.png` 217,820 B、`about_bike_pin.png` 227,635 B、`app_icon.png` 714,369 B（另 `.gitkeep`）。`assets/prompts.md`(4074B) 含「统一风格约定 + 素材清单（含完整提示词）+ 生成记录（模型 `doubao-seedream-5.0-lite`、中文提示词、后处理）+ 图标派生资源说明」，满足开源红线第 4 条（素材自产 + 提示词可复现） |
| E12 | 图标资源完整 + XML 合法 | ✅ 通过 | `mipmap-{m,h,xh,xxh,xxxh}dpi/` 各有 `ic_launcher.png` 与 `ic_launcher_foreground.png`（mdpi 3243/5000 B → xxxhdpi 32756/45632 B，随密度递增合理）；`values/ic_launcher_background.xml`（`#FAFAF7`）、`mipmap-anydpi-v26/ic_launcher.xml`、`ic_launcher_round.xml` 均存在且为合法 `<adaptive-icon>` XML（background + foreground 引用齐全） |
| E13 | `docs/screenshots/` 3 张占位图存在，README 不断链 | ✅ 通过 | 三张 PNG 均存在（~20–23 KB）；人工读图 `01-home-parking.png` 为带「首页·停车态 / 真机截图待补」字样的占位图，非断链 |
| E14 | 图标不再是 Flutter 默认图标 | ✅ 通过 | 人工读图：`assets/images/app_icon.png` 与 `res/mipmap-xxxhdpi/ic_launcher.png` 均为**薄荷青绿「自行车剪影 + 定位针」**自定义图标（米白底），**非 Flutter 默认蓝色 logo**；与 `prompts.md` 记录一致 |

### F. 无回归

| # | 验收点 | 结论 | 证据 |
|---|---|---|---|
| F15 | analyze 无 issue；test 141/141 | ✅ 通过 | `.\tool\flutter.ps1 analyze` → `No issues found! (ran in 8.8s)`（exit 0）；`.\tool\flutter.ps1 test` → **`All tests passed!` +141**（exit 0，与 T04 基线一致，无回归） |

**验证清单通过：15 / 15。**

---

## 3. 缺陷清单

### 3.1 唯一发现【P3 · 文档措辞 · 非阻塞】

| 项 | 内容 |
|---|---|
| 级别 | P3（建议改进，不影响安全/功能/构建） |
| 文件:行号 | `README.md:125` |
| 现状 | `## 项目结构（架构文档见团队 docs/ARCHITECTURE.md）` |
| 问题 | 该括号引用的 `docs/ARCHITECTURE.md` **在本开源仓库内不存在**（仓库 `docs/` 下仅有 `QA-T03-report.md`、`QA-T04-report.md`、`screenshots/`）。架构文档实际位于团队工作区（`F:\WorkBuddy_data\我车呢\docs\ARCHITECTURE.md`），并未随开源仓库分发。措辞虽冠以「团队」，但外部读者按相对路径 `docs/ARCHITECTURE.md` 查找会落空 |
| 建议修法 | 二选一：① 将架构文档一并纳入仓库 `docs/`；② 把该括号改为「（架构文档为团队内部文档，未随本仓库分发）」，避免读者按 `docs/ARCHITECTURE.md` 查找 |
| 复现 | `Test-Path W:\wo_che_ne\docs\ARCHITECTURE.md` → False |

> **说明**：此为**文档措辞**层面的 P3，不构成安全、功能或构建缺陷，故**不路由 Engineer**；建议后续文档轮顺手修正即可。

**P0/P1/P2 缺陷：0 个。**

---

## 4. 未覆盖项（如实声明，未据此放宽任何其它判定）

| 项 | 状态 | 理由 |
|---|---|---|
| 真机安装冒烟（`adb install -r app-release.apk` 并启动） | **未覆盖** | 验证环境无连接的真机/模拟器，`adb devices` 无可用设备；无法执行安装与首启冒烟 |
| 真机运行截图（替换 `docs/screenshots/*.png` 占位） | **未覆盖** | 同上，无真机；当前为带「真机截图待补」字样的占位图，README 已如实标注「T05 真机截图待补」 |
| 真机验证高德地图/定位/指南针实际可用 | **未覆盖** | 依赖真机传感器与高德 Key 联网，超出本环境能力 |

> 上述三项因**环境能力限制**未覆盖，已在报告明确标注；**未**因未覆盖而放宽 A–F 任何其它判定。

---

## 5. 结论与路由

| 项 | 结论 |
|---|---|
| 验证清单 | **15 / 15 通过** |
| 全量测试 | **141 / 141 通过**（analyze exit 0，无回归） |
| 密钥/口令泄漏 | **无（P0 项安全）** |
| 缺陷 | 0 个 P0/P1/P2；1 个 P3（README 文档措辞） |
| **路由判定** | **NoOne（全通过）** |

T05 交付通过 QA Round 1 独立验证：**发布产物、密钥安全、签名健壮性、文档、素材图标全部达标，无回归**。唯一 P3 为文档措辞建议，不阻塞交付，无需回退工程师。

---

## 6. 复现命令（供复核）

```powershell
Set-Location W:\wo_che_ne
# F15 无回归
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test

# A1 release 签名（应见 CN=WoCheNe…；debug 应见 CN=Android Debug…，两者不同）
$as="C:\Users\lenovo\AppData\Local\Android\Sdk\build-tools\36.0.0\apksigner.bat"
& $as verify --print-certs build\app\outputs\flutter-apk\app-release.apk
& $as verify --print-certs build\app\outputs\flutter-apk\app-debug.apk

# A2/A3 release 权限/包名/元数据（应恰 8 条系统权限，无存储/媒体/录音）
$a2="C:\Users\lenovo\AppData\Local\Android\Sdk\build-tools\36.0.0\aapt2.exe"
& $a2 dump permissions build\app\outputs\flutter-apk\app-release.apk
& $a2 dump badging      build\app\outputs\flutter-apk\app-release.apk

# B5/B6 泄漏扫描（排除 build 后应各仅命中 local.properties / keystore.properties 一处）
#   完整 Key 与完整口令值见 android/local.properties、android/keystore.properties（本报告不抄录）

# B7 .gitignore 真实手段（在临时副本执行，勿在 W:\wo_che_ne 本体 git init）
#   见 §1.3 步骤：复制工程到 %TEMP% → git init → git add -A → git check-ignore -v

# B8 .gitignore 中文读回
Get-Content .gitignore -Encoding UTF8 | Select-Object -Last 12
```

实测输出：analyze `No issues found!`；test `All tests passed! +141`；release 权限恰 8 条；release/debug 证书 DN 与 SHA-1 均不同。
