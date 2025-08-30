#!/bin/bash

# 定义一个模拟 systemctl 命令的函数
function Fake_Systemctl()
{
    local action="$1" # systemctl 命令的动作 (e.g., start, stop, status)
    local target_service="$2" # 目标服务名称 (e.g., 1panel-core, docker)
    local service_name="" # 实际的服务进程名称
    local log_file="" # 服务日志文件路径
    local binary_path="" # 服务可执行文件路径

    # 根据目标服务名称确定实际的服务信息
    case "$target_service" in
        "1panel-core" | "1panel-core.service")
            service_name="1panel-core"
            log_file="/tmp/1panel-core.log"
            binary_path="/usr/bin/1panel-core"
            ;;
        "1panel-agent" | "1panel-agent.service")
            service_name="1panel-agent"
            log_file="/tmp/1panel-agent.log"
            binary_path="/usr/bin/1panel-agent"
            ;;
        "1panel" | "1panel.service") # 兼容旧版，将 "1panel" 视为 "1panel-core"
            service_name="1panel-core"
            log_file="/tmp/1panel-core.log"
            binary_path="/usr/bin/1panel-core"
            ;;
        "docker" | "docker.service") # 对于 docker 服务，始终模拟为运行中
            if [[ "$action" = "status" || "$action" = "is-active" ]]; then echo "Active: active (running)"; fi
            return 0 # docker 服务不执行其他操作
            ;;
        *) # 对于其他未知服务，如果请求状态，则模拟为运行中，否则不执行任何操作
            if [[ "$action" = "status" || "$action" = "is-active" ]]; then echo "Active: active (running)"; fi
            return 0
            ;;
    esac

    # 根据动作执行相应的操作
    case "$action" in
        "stop")
            pkill -9 "$service_name" >/dev/null 2>&1
            ;;
        "start")
            # 检查服务是否已运行
            pkill -0 "$service_name" >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                echo "尝试启动 $service_name..."
                # 启动服务并将其放入后台
                nohup "$binary_path" > "$log_file" 2>&1 &
                # 等待服务启动，最多等待 10 秒
                for i in $(seq 1 10); do
                    pkill -0 "$service_name" >/dev/null 2>&1
                    if [[ $? -eq 0 ]]; then
                        echo "$service_name 启动成功。"
                        return 0
                    fi
                    sleep 1
                done
                echo "警告: $service_name 未能成功启动。"
                return 1 # 启动失败
            else
                echo "$service_name 已经在运行。"
                return 0
            fi
            ;;
        "status")
            pkill -0 "$service_name" >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                echo "Active: inactive (dead)"
                return 3 # 模拟 systemctl status 返回 3 表示不活动，但不退出脚本
            else
                echo "Active: active (running)"
            fi
            ;;
        "disable")
            # 模拟禁用服务，实际操作是停止服务
            pkill -9 "$service_name" >/dev/null 2>&1
            ;;
        "daemon-reload")
            # 模拟 daemon-reload，不执行任何操作
            ;;
        "reset-failed")
            # 模拟 reset-failed，不执行任何操作
            ;;
        *)
            # 对于未知动作，不执行任何操作
            ;;
    esac
}

# 处理传入的参数，如果存在则调用 Fake_Systemctl
if [[ ! -z "$1" ]]; then
    if [[ "$1" = "restart" ]] || [[ "$1" = "reload" ]];then
        Fake_Systemctl stop "$2"
        Fake_Systemctl start "$2"
    else
        Fake_Systemctl "$1" "$2"
    fi
    exit 0
fi

# 判断 1Panel-core 和 1Panel-agent 命令是否存在，如果任一不存在则执行安装脚本
if ! command -v 1panel-core &> /dev/null || ! command -v 1panel-agent &> /dev/null; then
    echo "未检测到 1panel-core 或 1panel-agent，准备安装..."
    bash /app/install.sh
else
    echo "1Panel 已安装，正在启动。"
fi

# 检查并启动 cron 服务
if [[ -e "/var/run/crond.pid" ]]; then
    kill -0 $(cat /var/run/crond.pid) > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        rm -rf /var/run/crond.pid
    fi
fi
if [[ ! -e "/var/run/crond.pid" ]]; then
    echo "启动 cron 服务..."
    /usr/sbin/cron
fi

# 启动 1Panel-core 和 1Panel-agent 服务
echo "启动 1Panel-core 服务..."
Fake_Systemctl start 1panel-core
echo "启动 1Panel-agent 服务..."
Fake_Systemctl start 1panel-agent

# 监控 1Panel-core 的日志，保持容器运行
echo "开始监控 1Panel-core 日志..."
# 尝试获取 1panel-core 的 PID，最多等待 30 秒
for i in $(seq 1 30); do
    PANEL_PID=$(pgrep 1panel-core)
    if [[ -n "$PANEL_PID" ]]; then
        echo "1Panel-core 进程已找到 (PID: $PANEL_PID)。开始监控日志。"
        tail --pid "$PANEL_PID" -f /tmp/1panel-core.log
        exit 0 # 如果 tail 退出，说明 1panel-core 停止了，容器也退出
    fi
    echo "等待 1Panel-core 启动... ($i/30)"
    sleep 1
done

echo "警告: 1Panel-core 进程在 30 秒内未找到。容器将保持运行以便调试。"
# 如果 1panel-core 未启动，则保持容器运行，方便用户进入调试
tail -f /dev/null