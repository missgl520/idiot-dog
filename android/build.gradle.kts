// 项目级 Gradle 构建脚本（Kotlin DSL）

allprojects {
    repositories {
        // Google 官方仓库
        google()
        // Maven 中央仓库
        mavenCentral()
        // 阿里云镜像：加速国内 Gradle 依赖下载
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
}

// 将所有子项目的构建输出目录统一放到项目根目录的 build 文件夹下
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // 每个子项目（如 :app）的构建目录设置为根 build 下以项目名命名的子目录
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 强制所有子项目使用 compileSdk 36，解决依赖库版本冲突
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
                if (compileSdkVersion < 36) {
                    compileSdkVersion(36)
                }
            }
        }
    }
}

subprojects {
    // 确保所有子项目都在 :app 模块评估后再进行评估
    project.evaluationDependsOn(":app")
}

// 注册 clean 任务：删除根构建目录
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
