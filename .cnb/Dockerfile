# ============================================================
# 竹芽 Flutter Android CI/CD 构建镜像
# 基于 Ubuntu 22.04，自带 Flutter SDK + Android SDK
# 由 .cnb.yml 的 docker.build 引用，每次构建自动构建此镜像
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Flutter SDK ──────────────────────────────────────────────
ENV FLUTTER_VERSION=3.24.6
ENV FLUTTER_SDK=/opt/flutter
ENV PATH=${FLUTTER_SDK}/bin:${PATH}

# ── Android SDK ──────────────────────────────────────────────
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_SDK_CMDLINE_TOOLS=${ANDROID_SDK_ROOT}/cmdline-tools
ENV PATH=${ANDROID_SDK_CMDLINE_TOOLS}/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}

# ── 基础依赖 ─────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    git \
    curl \
    zip \
    openjdk-17-jdk \
    libc6-dev \
    libstdc++6 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── Flutter SDK ──────────────────────────────────────────────
RUN mkdir -p ${FLUTTER_SDK} \
    && cd ${FLUTTER_SDK} \
    && wget -q --timeout=120 \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        -O flutter.tar.xz \
    && tar xf flutter.tar.xz --strip-components=1 \
    && rm flutter.tar.xz

RUN flutter precache --no-android --no-ios --no-fuchsia --no-linux --no-macos --no-windows --no-web 2>/dev/null || true \
    && flutter config --no-analytics

# ── Android SDK 命令行工具 ──────────────────────────────────
ENV ANDROID_SDK_VERSION=11076708
ENV BUILD_TOOLS_VERSION=34.0.0

RUN mkdir -p ${ANDROID_SDK_CMDLINE_TOOLS} \
    && cd /tmp \
    && wget -q --timeout=180 \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip" \
        -O cmdline-tools.zip \
    && unzip -q cmdline-tools.zip \
    && mv cmdline-tools ${ANDROID_SDK_CMDLINE_TOOLS}/latest \
    && rm cmdline-tools.zip

# ── 安装 Android SDK 组件 ───────────────────────────────────
# platforms;android-34   → Android 14
# platforms;android-21   → 最低支持 Android 5.0
# build-tools;34.0.0     → 编译工具链
# ndk;26.1.10909125      → NDK（Live2D/Cube Engine 原生库需要）
# cmake;3.22.1           → CMake（部分 Flutter 插件需要）
RUN yes | ${ANDROID_SDK_CMDLINE_TOOLS}/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true \
    && ${ANDROID_SDK_CMDLINE_TOOLS}/latest/bin/sdkmanager --install \
        "platform-tools" \
        "platforms;android-34" \
        "platforms;android-21" \
        "build-tools;${BUILD_TOOLS_VERSION}" \
        "ndk;26.1.10909125" \
        "cmake;3.22.1"

# 全局 local.properties（Flutter build engine 读取此文件定位 SDK）
RUN echo "sdk.dir=${ANDROID_SDK_ROOT}" > ${ANDROID_SDK_ROOT}/local.properties

# ── Flutter 配置 ─────────────────────────────────────────────
RUN flutter config --android-sdk=${ANDROID_SDK_ROOT} \
    && yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

# ── 验证 ─────────────────────────────────────────────────────
RUN flutter --version
RUN flutter doctor -v | grep -E "(Flutter|Android|Java|Dart)" | head -10

WORKDIR /workspace
