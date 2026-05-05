# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# 自动安装 Android SDK 和 Flutter 所需的工具
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 设置环境变量，使其在容器启动时生效
ENV ANDROID_HOME=/usr/local/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools