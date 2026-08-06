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

# ── Flutter SDK（Git 克隆 shallow + 按需下载）
# 用 --filter=blob:none：只拉元数据，文件按需下载
# 避免下载 693MB tarball 超时（10min Docker 构建限制）
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
        --filter=blob:none \
        https://github.com/flutter/flutter.git \
        ${FLUTTER_SDK}

# ── 预缓存 Flutter 平台文件 ─────────────────────────────────
# flutter precache 会按需下载必要二进制（比全量 tarball 小很多）
RUN flutter precache --no-ios --no-fuchsia --no-linux --no-macos --no-windows --no-web \
    && flutter config --no-analytics

# ── Android SDK 命令行工具（dl.google.com）──────────────────
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

# ── 安装 Android SDK 组件 ───────────────────────────────────
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
