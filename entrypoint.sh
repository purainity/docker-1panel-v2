#!/bin/bash

# 判断 1panel-core 和 1panel-agent 命令是否存在，如果任一不存在则执行安装脚本
if ! command -v "1panel-core" &> /dev/null || ! command -v "1panel-agent" &> /dev/null; then
    echo "1Panel 未安装，开始执行安装脚本..."
    if ! bash "/app/install.sh"; then
        echo "错误：1Panel 安装脚本执行失败，容器退出"
        exit 1
    fi
else
    echo "1Panel 已安装，准备启动"
fi

# 定义清理函数，捕获容器停止信号，确保后台进程能接收到终止指令并安全退出，防止数据库损坏
cleanup() {
    echo "接收到停止信号，正在关闭服务..."
    kill -TERM "$CORE_PID" "$AGENT_PID" 2>/dev/null
    wait "$CORE_PID" "$AGENT_PID"
    echo "服务已正常关闭"
    exit 0
}

# 绑定信号处理
trap cleanup SIGTERM SIGINT

# 启动 1Panel Core
echo "正在后台启动 1Panel Core..."
"1panel-core" 2>&1 &
CORE_PID=$!

# 等待 Core 初始化完成，防止 Agent 因 /etc/1panel/.1panel 未生成而 Panic，最多等待 30 秒
for i in {1..30}; do
    [ -f "/etc/1panel/.1panel" ] && break
    if [ "$i" -eq 30 ]; then
        echo "错误：核心配置文件生成超时，1Panel Core 可能启动失败"
        exit 1
    fi
    sleep 1
done

# 启动 1Panel Agent
echo "正在后台启动 1Panel Agent..."
"1panel-agent" 2>&1 &
AGENT_PID=$!

# 保持容器运行并实时监控进程状态，因为核心进程都在后台运行，容器如果没有前台进程会立即退出
echo "服务启动成功，正在监控进程状态"
wait -n "$CORE_PID" "$AGENT_PID"

echo "错误：1Panel 进程已退出，容器退出"
exit 1
