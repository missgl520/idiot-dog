# ============================================================
# zhuyu Flutter Android CI/CD 构建镜像
# 基于 Ubuntu 22.04 + Flutter（Git 克隆）+ Android SDK
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Flutter SDK ──────────────────────────────────────────────
# 注意：与本地 Flutter 3.44.6 保持一致（Dart 3.12.2）
ENV FLUTTER_VERSION=3.44.6
ENV FLUTTER_SDK=/opt/flutter
ENV PATH=${FLUTTER_SDK}/bin:${PATH}
# ── 国内镜像（全链路加速）───────────────────────────────
# Flutter 工具链下载（engine、dart-sdk、gradle-wrapper）
ENV FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn/flutter_infra_release
# pub 包下载（riverpod、hive 等所有 pub.dev 包）
ENV PUB_HOSTED_URL=https://pub.flutter-io.cn

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

# ── Gradle-wrapper 预下载（镜像 + --no-same-owner 解压）─────
# 镜像: https://storage.flutter-io.cn/flutter_infra_release/
# 3.44.6 的 gradle-wrapper hash:
ENV GRADLE_WRAPPER_HASH=fd5c1f2c013565a3bea56ada6df9d2b8e96d56aa
RUN mkdir -p ${FLUTTER_SDK}/bin/cache/downloads/storage.googleapis.com/flutter_infra_release/gradle-wrapper && \
    wget -q --timeout=60 \
        "${FLUTTER_STORAGE_BASE_URL}/gradle-wrapper/${GRADLE_WRAPPER_HASH}/gradle-wrapper.tgz" \
        -O /tmp/gradle-wrapper.tgz && \
    mkdir -p ${FLUTTER_SDK}/bin/cache/artifacts/gradle_wrapper && \
    tar xzf /tmp/gradle-wrapper.tgz \
        -C ${FLUTTER_SDK}/bin/cache/artifacts/gradle_wrapper/ \
        --no-same-owner && \
    rm /tmp/gradle-wrapper.tgz || true

# ── Flutter precache（可选：预热 engine 缓存，失败不影响构建）───────
# 注意：gradle-wrapper 已预下载；precache 失败不影响后续 flutter build
RUN FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL} flutter precache \
    --no-android --no-ios --no-fuchsia --no-linux --no-macos --no-windows --no-web \
    ; true

# ── 国内 pub 镜像（避免 pub.dev 访问不稳定）──────────────────
# pub.flutter-io.cn 是 Flutter 中国社区维护的 pub.dev 镜像
RUN flutter config set pub-preloader https://pub.flutter-io.cn/ \
    || true

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
