# 使用 Debian 13 slim 作为基础镜像
FROM debian:13-slim

# 构建时确保安装过程无需人工交互
ARG DEBIAN_FRONTEND=noninteractive

# TZ 设置系统默认时区
# LANG 和 LC_ALL 确保系统支持 UTF-8 编码，避免中文乱码
# 以下为 1Panel 应用级环境变量默认值（docker run 时可通过 -e 覆盖）
# 发行版本：PANEL_EDITION
# 安装模式：INSTALL_MODE
# 语言：LANGUAGE
# 安装目录：PANEL_BASE_DIR
# 面板端口：PANEL_PORT
# 安全入口：PANEL_ENTRANCE
# 面板用户：PANEL_USERNAME
# 面板密码：PANEL_PASSWORD
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PANEL_EDITION=cn \
    INSTALL_MODE=stable \
    LANGUAGE=zh \
    PANEL_BASE_DIR=/app \
    PANEL_PORT=9999 \
    PANEL_ENTRANCE=entrance \
    PANEL_USERNAME=1panel \
    PANEL_PASSWORD=1panel_password

# 更新软件源、安装依赖并设置时区、清理缓存以减小镜像体积
RUN apt-get update && apt-get install -y \
    tzdata \
    docker-cli \
    docker-compose \
    zip \
    unzip \
    7zip \
    unrar-free \
    curl \
    openssl \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 设置容器内部的工作目录
WORKDIR /app

# 复制启动脚本和安装脚本到容器的工作目录中
COPY entrypoint.sh install.sh /app/

# 指定容器启动时执行的入口脚本
ENTRYPOINT ["bash", "/app/entrypoint.sh"]
