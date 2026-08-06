# ============================================================
# zhuyu Flutter Android CI/CD 构建镜像
# 基于 Ubuntu 22.04 + Flutter（Git 克隆）+ Android SDK
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Flutter SDK ──────────────────────────────────────────────
ENV FLUTTER_VERSION=3.24.5
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

# ── Flutter SDK（Git 克隆 shallow）───────────────────────────
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
        --filter=blob:none \
        https://github.com/flutter/flutter.git \
        ${FLUTTER_SDK}

# ── Gradle-wrapper 预下载（镜像 + --no-same-owner 解压）
# Flutter precache 需要 gradle-wrapper.tgz，但 Docker rootless 环境
# tar 解压会报 "Cannot change ownership" 导致 precache 失败
# 解决：提前用镜像下载，用 --no-same-owner 解压到目标路径
ENV GRADLE_WRAPPER_HASH=fd5c1f2c013565a3bea56ada6df9d2b8e96d56aa
RUN mkdir -p ${FLUTTER_SDK}/bin/cache/downloads/storage.googleapis.com/flutter_infra_release/gradle-wrapper && \
    wget -q --timeout=60 \
        "https://storage.flutter-io.cn/flutter_infra_release/gradle-wrapper/${GRADLE_WRAPPER_HASH}/gradle-wrapper.tgz" \
        -O /tmp/gradle-wrapper.tgz && \
    mkdir -p ${FLUTTER_SDK}/bin/cache/artifacts/gradle_wrapper && \
    tar xzf /tmp/gradle-wrapper.tgz \
        -C ${FLUTTER_SDK}/bin/cache/artifacts/gradle_wrapper/ \
        --no-same-owner && \
    rm /tmp/gradle-wrapper.tgz || true

# ── Flutter precache（核心缓存预热）─────────────────────────
# 只下载 engine + dart-sdk（不需要 Android/iOS/Web/Fuchsia）
RUN flutter precache --no-android --no-ios --no-fuchsia --no-linux --no-macos --no-windows --no-web || true \
    && flutter config --no-analytics

# ── Android SDK 命令行工具（dl.google.com）───────────────────
ENV ANDROID_SDK_VERSION=11076708
ENV BUILD_TOOLS_VERSION=34.0.0

RUN mkdir -p ${ANDROID_SDK_CMDLINE_TOOLS} \
    && cd /tmp \
    && wget -q --timeout=300 \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip" \
        -O cmdline-tools.zip \
    && unzip -q cmdline-tools.zip \
    && mv cmdline-tools ${ANDROID_SDK_CMDLINE_TOOLS}/latest \
    && rm cmdline-tools.zip

# ── 安装 Android SDK 组件 ────────────────────────────────────
RUN yes | ${ANDROID_SDK_CMDLINE_TOOLS}/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true \
    && ${ANDROID_SDK_CMDLINE_TOOLS}/latest/bin/sdkmanager --install \
        "platform-tools" \
        "platforms;android-34" \
        "platforms;android-21" \
        "build-tools;${BUILD_TOOLS_VERSION}" \
        "ndk;26.1.10909125" \
        "cmake;3.22.1"

# 全局 local.properties
RUN echo "sdk.dir=${ANDROID_SDK_ROOT}" > ${ANDROID_SDK_ROOT}/local.properties

# ── Flutter 配置 ─────────────────────────────────────────────
RUN flutter config --android-sdk=${ANDROID_SDK_ROOT} \
    && yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

# ── 验证 ─────────────────────────────────────────────────────
RUN flutter --version
RUN flutter doctor -v | grep -E "(Flutter|Android|Java|Dart)" | head -10

WORKDIR /workspace
