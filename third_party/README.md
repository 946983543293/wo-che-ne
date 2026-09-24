# third_party —— vendored 高德插件（附现代化改造说明）

本目录是**高德官方 Flutter 插件 3.0.0 的本地副本**，仅在必要时做最小现代化改造，
通过 `pubspec.yaml` 的 `dependency_overrides` 指向本地路径使用。

## 为什么需要 vendoring

高德官方 `amap_flutter_base` / `amap_flutter_map` / `amap_flutter_location` 的**最新版本仍是
3.0.0（2022 年发布，已停止维护）**，在本项目的工具链（Flutter 3.47 / Dart 3.13 / Gradle 9.3.1 /
AGP 9.1.0 / JDK 17）下**无法直接构建**：

| 问题 | 现象 | 改造 |
|---|---|---|
| `sdk: ">=2.12.0 <3.0.0"` | 与 Dart 3 不兼容 | 放宽为 `>=2.12.0 <4.0.0` |
| `jcenter()` | Gradle 9 已移除该方法，构建直接报错 | 删除；仓库统一由宿主 `android/build.gradle.kts` 提供（含阿里云镜像） |
| 插件内自带 `buildscript { classpath 'AGP 3.5.x' }` | 与宿主 AGP 9 冲突 | 删除，Android 插件由宿主统一提供 |
| `compileSdkVersion` / `minSdkVersion` / `lintOptions` | AGP 9 已删除的遗留 DSL | 改为 `compileSdk` / `minSdk` / `lint` |
| AndroidManifest 的 `package` 属性 | AGP 8+ 不再支持，要求 `namespace` | 移除属性，在 build.gradle 补 `namespace` |
| `dependencies` 嵌在 `android {}` 内（location 插件） | Gradle 9 严格校验失败 | 移到顶层 |

改造原则：**只动构建脚本与 pubspec，不改任何 Dart / Java 源码逻辑**，保证与官方插件行为一致。

## 使用方式

`pubspec.yaml`：

```yaml
dependencies:
  amap_flutter_map: ^3.0.0
  amap_flutter_location: ^3.0.0

dependency_overrides:
  amap_flutter_base:
    path: third_party/amap_flutter_base
  amap_flutter_map:
    path: third_party/amap_flutter_map
  amap_flutter_location:
    path: third_party/amap_flutter_location
```

高德 SDK 的 aar 依赖（`com.amap.api:3dmap` / `com.amap.api:location`）由**宿主 app**
在 `android/app/build.gradle.kts` 以 `implementation` 引入（插件侧仅 `compileOnly`）。

## 维护指引

- 上游若发布兼容新工具链的版本：优先升级官方版本并删除本目录与 `dependency_overrides`。
- 本目录内容升级（如换用社区维护的 fork）时，请同步更新上表与根 `README.md`。
- 各包原始 LICENSE 已随之保留（`amap_flutter_map/LICENSE` 等）。
