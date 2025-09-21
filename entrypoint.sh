#!/bin/bash

# 判断 1Panel-core 和 1Panel-agent 命令是否存在，如果任一不存在则执行安装脚本
if ! command -v 1panel-core &> /dev/null || ! command -v 1panel-agent &> /dev/null; then
    echo "未检测到 1panel-core 或 1panel-agent，准备安装..."
    bash /app/install.sh
else
    echo "1Panel 已安装，正在启动。"
fi

# 1Panel数据初始化
systemctl start 1panel-core
sleep 3
systemctl stop 1panel-core

# 启动 docker
echo "Start Docker"
systemctl start docker

# 启动 1Panel
echo "Start 1Panel Core"
systemctl start 1panel-core

# 等待 1Panel Core 启动
sleep 3
echo "Start 1Panel Agent"
systemctl start 1panel-agent

# 监听日志
systemctl log 1panel-core -f