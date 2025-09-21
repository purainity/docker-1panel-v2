# 使用 Debian 13 作为基础镜像
FROM debian:13

# 默认环境变量
# 时区：TZ
# 语言：LANGUAGE
# 安装模式: INSTALL_MODE
# 版本：VERSION
# 安装目录: PANEL_BASE_DIR
# 面板端口: PANEL_PORT
# 安全入口: PANEL_ENTRANCE
# 面板用户: PANEL_USERNAME
# 面板密码: PANEL_PASSWORD
ENV TZ=Asia/Shanghai \
    LANGUAGE=zh \
    PANEL_BASE_DIR=/opt \
    PANEL_PORT=9999 \
    PANEL_ENTRANCE=entrance \
    PANEL_USERNAME=1panel \
    PANEL_PASSWORD=1panel_password

# 设置工作目录为/app
WORKDIR /app

# 复制必要的文件
COPY entrypoint.sh install.sh systemctl3.py journalctl3.py docker.service ./

# 设置文件权限
RUN chmod +x ./entrypoint.sh && \
    chmod +x ./install.sh

# 启动
ENTRYPOINT ["/app/entrypoint.sh"]
