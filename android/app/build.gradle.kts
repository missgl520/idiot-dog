import java.util.Properties

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

    signingConfigs {
        create("release") {
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                val props = Properties()
                keyPropsFile.inputStream().use { stream -> props.load(stream) }
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 使用正式的 release 签名（key.properties + upload-keystore.jks）
            // 若 keystore 文件实际不存在，回退到 debug 签名，保证本地 `flutter build apk` 可用
            val releaseKeystore = signingConfigs.findByName("release")?.storeFile
            signingConfig = if (releaseKeystore != null && releaseKeystore.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
