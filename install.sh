#!/bin/bash

# 失败退出
set -e

# 设置时区
echo -n "$TZ" > /etc/timezone

# 检查系统架构
echo "检查系统架构..."
os_check=$(uname -a)
arch=""
if [[ $os_check =~ 'x86_64' ]]; then
    arch="amd64"
elif [[ $os_check =~ 'arm64' ]] || [[ $os_check =~ 'aarch64' ]]; then
    arch="arm64"
elif [[ $os_check =~ 'armv7l' ]]; then
    arch="armv7"
elif [[ $os_check =~ 'ppc64le' ]]; then
    arch="ppc64le"
elif [[ $os_check =~ 's390x' ]]; then
    arch="s390x"
elif [[ $os_check =~ 'riscv64' ]]; then
    arch="riscv64"
else
    echo "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"
    exit 1
fi
echo "系统架构检测完成: ${arch}"


# 安装必要的软件包
echo "安装必要的软件包..."
apt-get update
DEBIAN_FRONTEND=noninteractive TZ="$TZ" apt-get install -y ca-certificates curl wget iproute2 tzdata python3 procps docker-cli docker-buildx docker-compose

# 创建 systemctl 模拟脚本
echo "正在创建 systemctl 模拟脚本..."
cp systemctl3.py /usr/bin/systemctl
chmod +x /usr/bin/systemctl

# 创建 journalctl 模拟脚本
echo "正在创建 journalctl 模拟脚本..."
cp journalctl3.py /usr/bin/journalctl
chmod +x /usr/bin/journalctl

# 创建 docker 伪装 systemctl 服务文件
echo "正在创建 docker 伪装 systemctl 服务文件..."
cp docker.service /usr/lib/systemd/system/


# 1Panel 安装主函数
main_install() {
    # 获取当前脚本的目录
    local current_dir=$(pwd)

    # 语言文件配置
    echo "$LANGUAGE" > "$current_dir/.selected_language" # 将选择的语言写入文件
    local lang_file="$current_dir/lang/$LANGUAGE.sh"
    if [ -f "$lang_file" ]; then
        source "$lang_file" # 导入选定语言的文本变量
        echo "已加载语言文件: $lang_file"
    else
        echo "错误: 语言文件 $lang_file 不存在。"
        exit 1
    fi

    # 设置安装目录
    local use_existing=false # 标记是否使用现有数据
    # 验证 PANEL_BASE_DIR 是否为绝对路径
    if [[ "$PANEL_BASE_DIR" != /* ]]; then
        echo "错误: 安装目录 $PANEL_BASE_DIR 无效，请提供目录的完整路径。"
        exit 1
    fi
    # 创建安装目录
    mkdir -p "$PANEL_BASE_DIR"
    # 检查安装目录下是否存在 1Panel 数据库文件
    if [[ -f "$PANEL_BASE_DIR/1panel/db/core.db" ]]; then
        use_existing=true
        echo "检测到现有 1Panel 数据，将使用现有配置。"
    fi

    # 设置面板端口
    # 验证端口号是否为数字且在合法范围内 (1-65535)
    if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
        echo "错误: 面板端口 $PANEL_PORT 无效，输入的端口号必须在 1 到 65535 之间。"
        exit 1
    fi
    # 检查端口是否被占用
    if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
        echo "错误: 面板端口 $PANEL_PORT 已被占用。"
        exit 1
    fi

    # 检测宿主机的 Docker Daemon 版本
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
    local major_version=${docker_version%%.*}
    if [[ $major_version -lt 20 ]]; then
        echo "检测到宿主机 Docker Daemon 版本低于 20.x，建议手动升级以避免功能受限。"
    fi

    echo "正在配置 1Panel 服务..."

    local run_base_dir="$PANEL_BASE_DIR/1panel" # 1Panel 实际运行目录
    mkdir -p "$run_base_dir"
    # 清理旧的 1Panel 运行目录内容，安全删除
    rm -rf "$run_base_dir:?/*" 

    cd "${current_dir}" || exit # 切换到当前脚本目录

    # 复制并设置 1panel-core 可执行文件
    cp ./1panel-core /usr/local/bin && chmod +x /usr/local/bin/1panel-core
    # 移除旧的软链接
    if [[ -e /usr/bin/1panel ]]; then
        rm -f /usr/bin/1panel
    fi
    # 兼容旧版，将 1panel-core 软链接到 1panel
    ln -s /usr/local/bin/1panel-core /usr/bin/1panel >/dev/null 2>&1
    # 确保 /usr/bin/1panel-core 存在软链接 (如果需要)
    if [[ ! -f /usr/bin/1panel-core ]]; then
        ln -s /usr/local/bin/1panel-core /usr/bin/1panel-core >/dev/null 2>&1
    fi

    # 复制并设置 1panel-agent 可执行文件
    cp ./1panel-agent /usr/local/bin && chmod +x /usr/local/bin/1panel-agent
    # 确保 /usr/bin/1panel-agent 存在软链接 (如果需要)
    if [[ ! -f /usr/bin/1panel-agent ]]; then
        ln -s /usr/local/bin/1panel-agent /usr/bin/1panel-agent >/dev/null 2>&1
    fi

    # 复制并配置 1pctl 控制工具
    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    # 使用 sed 命令替换 1pctl 脚本中的配置变量
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USERNAME}#g" /usr/local/bin/1pctl
    # 密码中可能包含特殊字符，需要进行转义
    local escaped_panel_password=$(echo "$PANEL_PASSWORD" | sed 's/[!@#$%*_,.?]/\\&/g')
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${escaped_panel_password}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    sed -i -e "s#LANGUAGE=.*#LANGUAGE=${LANGUAGE}#g" /usr/local/bin/1pctl
    # 如果是使用现有数据，则在 1pctl 中添加或修改 CHANGE_USER_INFO 标记
    if [[ "$use_existing" == true ]]; then
        if grep -q "^CHANGE_USER_INFO=" "/usr/local/bin/1pctl"; then
            sed -i 's/^CHANGE_USER_INFO=.*/CHANGE_USER_INFO=use_existing/' "/usr/local/bin/1pctl"
        else
            sed -i '/^LANGUAGE=.*/a CHANGE_USER_INFO=use_existing' "/usr/local/bin/1pctl"
        fi
    fi
    # 确保 /usr/bin/1pctl 存在软链接 (如果需要)
    if [[ ! -f /usr/bin/1pctl ]]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    fi

    # 复制 GeoIP 数据
    if [ -d "$run_base_dir/geo" ]; then
        rm -rf "$run_base_dir/geo" # 清理旧的 GeoIP 目录
    fi
    mkdir -p "$run_base_dir/geo"
    cp -r ./GeoIP.mmdb "$run_base_dir/geo/"

    # 复制语言文件
    cp -r ./lang /usr/local/bin

    # 复制 systemd 服务文件
    cp ./1panel-core.service /etc/systemd/system
    cp ./1panel-agent.service /etc/systemd/system

    systemctl enable 1panel-agent.service
    systemctl enable 1panel-core.service
    systemctl daemon-reload

    # 清理安装包和解压后的文件
    echo "清理安装文件..."
    cd ..
    rm -f "${package_file_name}"
    rm -rf "1panel-${VERSION}-linux-${arch}"

    echo 
    echo "感谢您的耐心等待，安装已完成。"
    echo "面板端口: $PANEL_PORT"
    echo "安全入口: $PANEL_ENTRANCE"
    echo "面板用户: $PANEL_USERNAME"
    echo "面板密码: $PANEL_PASSWORD"
    echo "请确保 Docker 以 host 网络模式运行或已经配置端口映射 $PANEL_PORT。"
    echo
}



# 设置安装模式
if [[ -z "${INSTALL_MODE}" ]]; then
    echo "未手动指定安装模式，默认采用 stable。"
    INSTALL_MODE="stable"
else
    echo "已手动指定安装模式: ${INSTALL_MODE}。"
fi

# 获取最新版本号
if [[ -z "${VERSION}" ]]; then
    echo "未手动指定版本号，在线获取最新版本..."
    VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/v2/${INSTALL_MODE}/latest)
    if [[ -z "${VERSION}" ]]; then
        echo "错误: 获取最新版本失败，请稍候重试。"
        exit 1
    else
        echo "最新版本: ${VERSION}。"
    fi
else
    echo "已手动指定版本号: ${VERSION}。"
fi

hash_file_url="https://resource.fit2cloud.com/1panel/package/v2/${INSTALL_MODE}/${VERSION}/release/checksums.txt"
package_file_name="1panel-${VERSION}-linux-${arch}.tar.gz"
package_download_url="https://resource.fit2cloud.com/1panel/package/v2/${INSTALL_MODE}/${VERSION}/release/${package_file_name}"
expected_hash=$(curl -s "$hash_file_url" | grep "$package_file_name" | awk '{print $1}')

# 检查安装包是否已存在且哈希值匹配
if [[ -f "${package_file_name}" ]]; then
    if [[ -n "${expected_hash}" ]]; then
        actual_hash=$(sha256sum "${package_file_name}" | awk '{print $1}')
        if [[ "${expected_hash}" == "${actual_hash}" ]]; then
            echo "安装包已存在且哈希值匹配，跳过下载。"
            tar zxvf "${package_file_name}"
            cd "1panel-${VERSION}-linux-${arch}" || { echo "错误: 无法进入安装目录。"; exit 1; }
            main_install
            exit 0 # 安装完成，退出脚本
        else
            echo "已存在安装包，但哈希值不一致，开始重新下载。"
            rm -f "${package_file_name}"
        fi
    else
        echo "无法获取安装包的哈希值，将重新下载安装包以确保完整性。"
        rm -f "${package_file_name}"
    fi
fi

# 下载安装包
echo "开始下载 1Panel ${VERSION} 版本在线安装包..."
echo "安装包下载地址: ${package_download_url}"
curl -Lk -o "${package_file_name}" "${package_download_url}"
if [[ ! -f "${package_file_name}" ]]; then
    echo "错误: 下载安装包失败，请稍候重试。"
    exit 1
fi
echo "安装包下载完成。"

# 解压安装包
echo "开始解压安装包..."
tar zxvf "${package_file_name}"
if [[ $? -ne 0 ]]; then
    echo "错误: 解压安装包失败，请稍候重试。"
    rm -f "${package_file_name}"
    exit 1
fi
echo "安装包解压完成。"

# 进入解压后的目录并执行安装脚本
echo "开始安装 1Panel..."
cd "1panel-${VERSION}-linux-${arch}" || { echo "错误: 无法进入安装目录。"; exit 1; }
main_install
