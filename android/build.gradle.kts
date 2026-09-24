allprojects {
    repositories {
        // 中国大陆网络优化：阿里云镜像优先，官方源兜底
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // 高德地图/定位 SDK（com.amap.api:*）——原为 jcenter 托管，现由阿里云 public 镜像提供
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // 统一抬高所有 Android 子工程（含三方 Flutter 插件）的 compileSdk 到 36。
    // 背景：部分旧插件（如 flutter_compass_v2）硬编码 compileSdk 33，而新版 androidx
    // 依赖（fragment/window 等）要求 compileSdk >= 34，否则 checkDebugAarMetadata 失败。
    // 通过反射调用 setCompileSdkVersion，避免改动插件源码。
    // 注意：:app 会被别的子工程的 evaluationDependsOn 提前评估，故需判断 state.executed，
    // 已评估的工程直接设置，未评估的注册 afterEvaluate。
    val forceCompileSdk36 = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            setter?.invoke(androidExt, 36)
        }
        Unit
    }
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
