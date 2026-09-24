import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// 高德 AMAP_KEY 读取逻辑（开源红线：Key 只从 local.properties/环境变量读取，绝不入库）
// - 高德按「包名 + 签名 SHA1」鉴权，同一应用可绑多个 Key：
//     AMAP_KEY         → debug 包用（绑定 debug keystore 的 SHA1）
//     AMAP_KEY_RELEASE → release 包用（绑定 release keystore 的 SHA1）
// - 真实 Key 写在 android/local.properties（该文件已被 .gitignore 排除），
//   模板见 android/local.properties.example；申请步骤见 README.md「高德 Key 自助申请」
// - 两 Key 全未配置：Debug 放行（占位值），Release 报错中止
// - 只配 AMAP_KEY：Release 嵌 debug Key 并警告（真机地图无法鉴权）
// ============================================================
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}
val amapDebugKeyRaw = (localProps.getProperty("AMAP_KEY") ?: System.getenv("AMAP_KEY") ?: "").trim()
val amapReleaseKeyRaw =
    (localProps.getProperty("AMAP_KEY_RELEASE") ?: System.getenv("AMAP_KEY_RELEASE") ?: "").trim()
val amapDebugKeyConfigured = amapDebugKeyRaw.isNotEmpty() &&
    !amapDebugKeyRaw.startsWith("请在此填入")
val amapReleaseKeyConfigured = amapReleaseKeyRaw.isNotEmpty() &&
    !amapReleaseKeyRaw.startsWith("请在此填入")
// debug 构建嵌 AMAP_KEY（绑定 debug keystore SHA1）；
// release 构建优先嵌 AMAP_KEY_RELEASE（绑定 release keystore SHA1），
// 缺失时回退 AMAP_KEY（会在下方给警告：该 Key 绑定的是 debug 签名，真机地图无法鉴权）。
val amapDebugKeyForManifest = if (amapDebugKeyConfigured) amapDebugKeyRaw else "AMAP_KEY_NOT_CONFIGURED"
val amapReleaseKeyForManifest = when {
    amapReleaseKeyConfigured -> amapReleaseKeyRaw
    amapDebugKeyConfigured -> amapDebugKeyRaw
    else -> "AMAP_KEY_NOT_CONFIGURED"
}

if (!amapDebugKeyConfigured && !amapReleaseKeyConfigured) {
    logger.warn(
        """
        |
        |╔══════════════════════════════════════════════════════════════════╗
        |║ 【我车呢】未配置任何高德 Key，本次构建使用占位值。                     ║
        |║ 地图/定位功能在真机上将不可用；编译、分析、单测不受影响。                  ║
        |║ 配置方法：复制 android/local.properties.example 内容为                ║
        |║   android/local.properties 并填入你的高德 Key，然后重新构建。           ║
        |║ 申请指引见 README.md「高德 Key 自助申请」。                            ║
        |╚══════════════════════════════════════════════════════════════════╝
        |
        """.trimMargin()
    )
} else if (!amapReleaseKeyConfigured) {
    logger.warn(
        """
        |
        |╔══════════════════════════════════════════════════════════════════╗
        |║ 【我车呢】只配置了 AMAP_KEY，未配置 AMAP_KEY_RELEASE。                 ║
        |║ Release 包将嵌入 debug Key——它绑定的是 debug 签名 SHA1，             ║
        |║ release 真机地图将无法鉴权。请为 release keystore 单独申请一个           ║
        |║ 高德 Key 并填入 AMAP_KEY_RELEASE。                                ║
        |╚══════════════════════════════════════════════════════════════════╝
        |
        """.trimMargin()
    )
}

// ============================================================
// 正式发布签名读取逻辑（T05；开源红线：keystore 与口令绝不入库）
// - 真实签名配置写在 android/keystore.properties（该文件与 *.jks 均已被 .gitignore 排除）
// - 文件存在且四项齐全 → 使用 release 签名
// - 文件缺失 → 回退 debug 签名（保证无 keystore 的协作者仍能 flutter run --release）
//   assembleRelease 打包时会额外给出清晰警告（见文件末尾）
// ============================================================
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropsFile.exists() &&
    !keystoreProps.getProperty("storeFile").isNullOrBlank() &&
    !keystoreProps.getProperty("storePassword").isNullOrBlank() &&
    !keystoreProps.getProperty("keyAlias").isNullOrBlank() &&
    !keystoreProps.getProperty("keyPassword").isNullOrBlank()

if (!hasReleaseKeystore) {
    logger.warn(
        """
        |
        |╔══════════════════════════════════════════════════════════════════╗
        |║ 【我车呢】未找到 android/keystore.properties，Release 将回退 debug 签名。     ║
        |║ 仅用于本地调试；正式分发前请按 README.md 生成并配置 release keystore。       ║
        |╚══════════════════════════════════════════════════════════════════╝
        |
        """.trimMargin()
    )
}

// 本工程无 C/C++ 原生代码：NDK 仅在本地已安装时才启用，
// 避免 AGP 因显式 ndkVersion 而强制拉取 ~1GB 的 NDK（sdkmanager 下载在本机不稳定）。
val androidSdkDir: String? =
    localProps.getProperty("sdk.dir") ?: System.getenv("ANDROID_HOME")
val flutterNdkVersion: String = flutter.ndkVersion
val flutterNdkInstalled: Boolean =
    androidSdkDir != null && File(androidSdkDir, "ndk/$flutterNdkVersion").isDirectory

android {
    namespace = "com.wochene.wo_che_ne"
    compileSdk = flutter.compileSdkVersion
    if (flutterNdkInstalled) {
        ndkVersion = flutterNdkVersion
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 定稿 applicationId（架构 §8-2）：高德 Key 绑定与此 ID 一致，定后不宜改
        applicationId = "com.wochene.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 高德 Key 占位符 → AndroidManifest.xml 中的 ${AMAP_KEY}
        // default 兜底用 debug Key；下面按构建类型分别覆盖。
        manifestPlaceholders["AMAP_KEY"] = amapDebugKeyForManifest
    }

    signingConfigs {
        // 正式发布签名（T05）：口令与 keystore 绝不入库，从 android/keystore.properties 读取。
        // 仅在配置文件齐全时创建，避免无 keystore 的环境（如 CI 只跑 analyze/test）构建失败。
        if (hasReleaseKeystore) {
            create("release") {
                // storeFile 相对 app 模块目录（android/app/）解析，与官方 Flutter 签名模板一致。
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // debug 包嵌 debug Key（绑定 debug keystore SHA1）
            manifestPlaceholders["AMAP_KEY"] = amapDebugKeyForManifest
        }
        release {
            // release 包优先嵌 release Key（绑定 release keystore SHA1）
            manifestPlaceholders["AMAP_KEY"] = amapReleaseKeyForManifest
            // 有正式签名则用之；否则回退 debug 签名以便 flutter run --release 可用。
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Release 构建强制要求真实高德 Key（Debug 放行，保证无 Key 也能编译/跑单测）
tasks.matching {
    it.name.equals("assembleRelease", ignoreCase = true) ||
        it.name.startsWith("packageRelease")
}.configureEach {
    doFirst {
        if (!amapDebugKeyConfigured && !amapReleaseKeyConfigured) {
            throw GradleException(
                """
                |
                |【我车呢】Release 构建中止：未配置任何高德 Key。
                |请按以下步骤配置后重新构建：
                |  1. 复制 android/local.properties.example 为 android/local.properties
                |  2. 在高德开放平台申请 Android Key（包名绑定 com.wochene.app，步骤见 README.md）
                |  3. 在 local.properties 中填入：AMAP_KEY_RELEASE=你的Key（release 用）
                |  4. 重新执行 flutter build apk --release
                |
                """.trimMargin()
            )
        }
    }
}

// Release 打包时若缺正式签名：给出清晰警告（不中止——便于 CI/协作者用 debug 签名验证流程）。
tasks.matching {
    it.name.equals("assembleRelease", ignoreCase = true) ||
        it.name.startsWith("packageRelease")
}.configureEach {
    doFirst {
        if (!hasReleaseKeystore) {
            logger.warn(
                """
                |
                |【我车呢】警告：未找到 android/keystore.properties，本次 Release 使用 debug 签名。
                |此包不可用于正式分发（无法覆盖更新）。请生成 release keystore 后重新构建，
                |步骤见 README.md「发布签名」章节。
                |
                """.trimMargin()
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 高德 SDK 实际运行库（vendored 插件仅 compileOnly 引用，需 app 侧 implementation 打包进 APK）
    implementation("com.amap.api:3dmap:8.1.0")
    implementation("com.amap.api:location:5.6.0")
}

flutter {
    source = "../.."
}
