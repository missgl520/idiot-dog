plugins {
    // Android 应用插件
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 和 Kotlin 插件之后应用
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 应用的命名空间，需与 AndroidManifest.xml 中的 package 保持一致
    namespace = "com.zhuyapp.zhuyapp"
    // 编译 SDK 版本由 Flutter 工具自动提供
    compileSdk = 36
    // NDK 版本由 Flutter 工具自动提供
    ndkVersion = flutter.ndkVersion

    // Java 编译兼容性设置为 JDK 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 应用唯一包名
        applicationId = "com.zhuyapp.zhuyapp"
        // 最低支持 Android 7.0（API 24）
        // 原因：flutter_live2d 插件依赖 OpenGL ES 2.0，最低需要 Android 7.0
        minSdk = 24
        // 目标 SDK 版本由 Flutter 工具自动提供
        targetSdk = 36
        // 版本号和版本名称由 Flutter 工具自动提供（来自 pubspec.yaml）
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 发布构建目前使用 debug 签名配置，方便 `flutter run --release` 直接运行
            // 正式上线前请替换为正式的 release 签名配置
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        // Kotlin 编译目标 JVM 17，与 Java compileOptions 保持一致
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    // Flutter 项目根目录相对位置
    source = "../.."
}
