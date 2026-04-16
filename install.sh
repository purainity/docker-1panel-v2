#!/bin/bash

# 失败退出
set -e


lang_file=".selected_language" # 语言配置路径
edition_file=".selected_edition" # 发行版本配置路径


# 检查系统架构
os_check=$(uname -a)
if [[ $os_check =~ 'x86_64' ]]; then
    architecture="amd64"
elif [[ $os_check =~ 'arm64' ]] || [[ $os_check =~ 'aarch64' ]]; then
    architecture="arm64"
elif [[ $os_check =~ 'armv7l' ]]; then
    architecture="armv7"
elif [[ $os_check =~ 'ppc64le' ]]; then
    architecture="ppc64le"
elif [[ $os_check =~ 's390x' ]]; then
    architecture="s390x"
elif [[ $os_check =~ 'riscv64' ]]; then
    architecture="riscv64"
else
    echo "当前系统架构暂不支持，请参考官方文档选择受支持的系统与架构。"
    exit 1
fi


# 1Panel 安装主函数
main_install() {

    echo "开始安装 1Panel。"

    # 获取当前工作目录
    local current_dir=$(pwd)

    # 写入发行版本配置文件
    echo "$PANEL_EDITION" > "$edition_file"

    # 语言文件配置
    echo "$LANGUAGE" > "$current_dir/$lang_file" # 写入语言配置文件
    # 检查选择的语言是否存在
    local langfile="$current_dir/lang/$LANGUAGE.sh"
    if [ -f "$langfile" ]; then
        source "$langfile" # 导入选定语言的文本变量
    else
        echo "错误：未找到语言文件 $langfile"
        exit 1
    fi

    # 设置安装目录
    local use_existing=false # 标记是否使用现有数据
    # 验证安装目录是否为绝对路径
    if [[ "$PANEL_BASE_DIR" != /* ]]; then
        echo "错误：安装目录 $PANEL_BASE_DIR 无效，请提供目录的完整路径。"
        exit 1
    fi
    # 创建安装目录
    if [[ ! -d "$PANEL_BASE_DIR" ]]; then
        mkdir -p "$PANEL_BASE_DIR"
    fi
    # 检查安装目录下是否存在 1Panel 数据库文件
    if [[ -f "$PANEL_BASE_DIR/1panel/db/core.db" ]]; then
        use_existing=true
        echo "检测到现有 1Panel 数据，将使用现有配置。"
    fi

    # 设置面板端口
    # 验证端口号是否为数字且在合法范围内 (1-65535)
    if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
        echo "错误：面板端口 $PANEL_PORT 无效，输入的端口号必须在 1 到 65535 之间。"
        exit 1
    fi

    # 检查宿主机的 docker.sock 是否已挂载到容器内
    if [ ! -S /var/run/docker.sock ]; then
        echo "警告：未检测到 /var/run/docker.sock，请确保已将宿主机的 docker.sock 挂载到容器内。"
    fi

    # 检测宿主机的 Docker Daemon 版本
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
    local major_version=${docker_version%%.*}
    if [[ $major_version -lt 20 ]]; then
        echo "检测到宿主机 Docker Daemon 版本低于 20.x，建议手动升级以避免功能受限。"
    fi

    echo "正在配置 1Panel 服务。"

    local run_base_dir=$PANEL_BASE_DIR/1panel # 1Panel 实际运行目录
    # 创建实际运行目录
    mkdir -p "$run_base_dir"
    # 如果不使用现有配置就清理旧的运行目录
    if [[ "$use_existing" == false ]]; then
        rm -rf "$run_base_dir"/* 2>/dev/null 
    fi

    cd "${current_dir}" || exit # 切换到当前脚本目录

    # 复制并设置 1panel-core 可执行文件
    cp ./1panel-core /usr/local/bin && chmod +x /usr/local/bin/1panel-core
    # 移除旧的软链接
    if [[ -e /usr/bin/1panel ]]; then
        rm -f /usr/bin/1panel
    fi
    # 兼容旧版，将 1panel-core 软链接到 1panel
    ln -s /usr/local/bin/1panel-core /usr/bin/1panel >/dev/null 2>&1
    # 确保 /usr/bin/1panel-core 存在软链接
    if [[ ! -f /usr/bin/1panel-core ]]; then
        ln -s /usr/local/bin/1panel-core /usr/bin/1panel-core >/dev/null 2>&1
    fi

    # 复制并设置 1panel-agent 可执行文件
    cp ./1panel-agent /usr/local/bin && chmod +x /usr/local/bin/1panel-agent
    # 确保 /usr/bin/1panel-agent 存在软链接
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
    sed -i -e "s#^PANEL_EDITION=.*#PANEL_EDITION=${PANEL_EDITION}#g" /usr/local/bin/1pctl
    # 如果是使用现有数据，则在 1pctl 中添加或修改 CHANGE_USER_INFO 标记
    if [[ "$use_existing" == true ]]; then
        if grep -q "^CHANGE_USER_INFO=" "/usr/local/bin/1pctl"; then
            sed -i 's/^CHANGE_USER_INFO=.*/CHANGE_USER_INFO=use_existing/' "/usr/local/bin/1pctl"
        else
            sed -i '/^LANGUAGE=.*/a CHANGE_USER_INFO=use_existing' "/usr/local/bin/1pctl"
        fi
    fi
    # 确保 /usr/bin/1pctl 存在软链接
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

    # 复制传统 sysvinit 的服务脚本到 init.d 满足 1Panel 后端和 1pctl 脚本的自检
    mkdir -p /etc/init.d # docker 容器中这个目录不存在，需要手动创建
    cp ./initscript/1panel-core.init /etc/init.d/1panel-core
    cp ./initscript/1panel-agent.init /etc/init.d/1panel-agent
    chmod +x /etc/init.d/1panel-core
    chmod +x /etc/init.d/1panel-agent

    # 复制资源文件
    if [[ ! -d "$run_base_dir/resource" ]]; then
        mkdir -p "$run_base_dir/resource"
    fi
    cp -r ./initscript "$run_base_dir/resource/"

    # 清理安装包和解压后的文件
    echo "安装已完成，清理安装文件。"
    cd ..
    rm -f "${package_file_name}"
    rm -rf "1panel-${VERSION}-linux-${architecture}"

    echo 
    echo "感谢您的耐心等待，安装已完成。"
    echo "面板端口：$PANEL_PORT"
    echo "安全入口：$PANEL_ENTRANCE"
    echo "面板用户：$PANEL_USERNAME"
    echo "面板密码：$PANEL_PASSWORD"
    echo "请确保 Docker 以 host 网络模式运行或已经配置端口映射 $PANEL_PORT。"
    echo "请确保安装目录 $PANEL_BASE_DIR 已映射到宿主机上的目录以免数据丢失。"
    echo
}


# 检查发行版本
if [[ "${PANEL_EDITION}" == "cn" ]]; then
    URL_PREFIX="https://resource.fit2cloud.com/1panel/package/"
elif [[ "${PANEL_EDITION}" == "intl" ]]; then
    URL_PREFIX="https://resource.1panel.pro/"
else
    echo "PANEL_EDITION 参数无效：${PANEL_EDITION}。仅支持：cn、intl。"
    exit 1
fi

# 检查安装模式
if [[ "${INSTALL_MODE}" != "dev" && "${INSTALL_MODE}" != "stable" ]]; then
    echo "INSTALL_MODE 参数无效：${INSTALL_MODE}。仅支持：dev、stable。"
    exit 1
fi

# 获取最新版本号
if [[ -z "${VERSION}" ]]; then
    echo "未手动指定版本号，在线获取最新版本。"
    VERSION=$(curl -s "${URL_PREFIX}v2/${INSTALL_MODE}/latest")
    if [[ "x${VERSION}" == "x" ]]; then
        echo "获取最新版本失败（模式：${INSTALL_MODE}），请稍后重试。"
        exit 1
    else
        echo "最新版本：${VERSION}。"
    fi
else
    echo "已手动指定版本号：${VERSION}。"
fi

# 获取安装包期望哈希值和下载链接
hash_file_url="${URL_PREFIX}v2/${INSTALL_MODE}/${VERSION}/release/checksums.txt" # 安装包期望哈希值下载链接
package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz" # 安装包文件名
package_download_url="${URL_PREFIX}v2/${INSTALL_MODE}/${VERSION}/release/${package_file_name}" # 安装包下载链接
expected_hash=$(curl -s "$hash_file_url" | grep "$package_file_name" | awk '{print $1}') # 安装包期望哈希值

# 检查本地是否已存在校验通过的安装包，若有则直接解压安装
if [[ -f "${package_file_name}" ]]; then
    actual_hash=$(sha256sum "${package_file_name}" | awk '{print $1}') # 本地安装包哈希值
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo "检测到本地安装包且校验通过，跳过下载。"
        rm -rf "1panel-${VERSION}-linux-${architecture}" # 清理安装包解压目录
        tar zxf "${package_file_name}" # 解压安装包
        cd "1panel-${VERSION}-linux-${architecture}" # 进入安装包解压目录
        main_install # 执行安装主函数
        exit 0 # 安装完成，退出脚本
    else
        echo "本地安装包校验不通过，开始重新下载。"
        rm -f "${package_file_name}" # 删除本地已经存在的压缩包准备重新下载
    fi
fi

# 下载安装包
echo "准备下载 1Panel ${VERSION}（架构：${architecture}，模式：${INSTALL_MODE}）。"
echo "下载地址：${package_download_url}"
curl -LOk "${package_download_url}"
if [[ ! -f "${package_file_name}" ]]; then
    echo "下载安装包失败，请检查网络连接后重试。"
    exit 1
fi

# 解压安装包
tar zxf "${package_file_name}"
if [[ $? != 0 ]]; then
    echo "解压安装包失败，下载文件可能不完整或已损坏。"
    rm -f "${package_file_name}" # 删除解压失败的安装包
    exit 1
fi

# 进入解压后的安装目录并调用主安装函数
cd "1panel-${VERSION}-linux-${architecture}" # 进入安装包解压目录
main_install # 执行安装主函数
