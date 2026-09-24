# =============================================================================
# 高德地图 / 高德定位 SDK keep 规则（3dmap 8.1.0 + location 5.6.0）
#
# 真机 release 闪退根因（2026-09-24 定位）：
#   R8 把高德 SDK 的类全部改名（见 build/app/outputs/mapping/release/mapping.txt：
#     com.amap.api.maps.MapsInitializer -> u40:
#     com.amap.api.maps.TextureMapView -> an0:
#     com.amap.api.location.AMapLocationClient -> l:）
#   而本工程与 vendored 插件都依赖「按原名反射调用」：
#     - third_party/amap_flutter_map/.../ConvertUtil.setPrivacyStatement()
#       反射 MapsInitializer.updatePrivacyShow / updatePrivacyAgree（空 catch 吞异常）
#     - third_party/amap_flutter_location/.../AMapFlutterLocationPlugin
#       .updatePrivacyStatement() 反射 AMapLocationClient.updatePrivacyShow/Agree
#       （同样空 catch）
#     - 高德 SDK 内部（com.amap.api.maps.model.* / mapcore）也会反射加载自己的类
#   改名后反射全部抛 NoSuchMethodException，且被空 catch 静默吞掉：
#   → 地图 SDK 的隐私合规从未真正应用 → SDK 拒绝初始化（地图黑屏）
#   → 内部再走反射 / 初始化时直接崩溃。
#
# 这同时解释了两个现象：
#   · debug 包不闪退（debug 不跑 R8）而 release 包必闪退；
#   · 只有地图页崩，而 Dart 诊断日志是空的（崩溃发生在原生层，不走 Dart 异常）。
#
# 按高德官方文档做法：整包 keep（含 `com.autonavi.**`，因为 mapcore 等内部类
# 实际位于该包名下）。
#
# 注：Flutter Gradle 插件在 release 构建中默认 isMinifyEnabled = true，并且
# 只要本文件存在（`android/app/proguard-rules.pro`）就会自动追加进 proguardFiles，
# 因此无需改动 android/app/build.gradle.kts。
# =============================================================================

-keep class com.amap.api.** {*;}
-keep class com.autonavi.** {*;}
-keep class com.amap.flutter.** {*;}

-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
-dontwarn com.amap.flutter.**
