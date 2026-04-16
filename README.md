# docker-1panel-v2

通过 DooD (Docker-outside-of-Docker) 方式在 Docker 容器中运行 [1Panel V2](https://github.com/1Panel-dev/1Panel) 开源服务器管理面板。

**提示**：本项目已重构。如需查看以前的版本，请前往提交历史。查看详细重构内容、本项目原理、开发背后的故事及升级说明，请查看这篇文章：[追求极致：docker-1panel-v2 容器化方案的重构](https://jibukeshi.dpdns.org/posts/project/refactoring-docker-1panel-v2.html)。

## 功能特性

- **完整体验**：在容器内运行几乎原生的 1Panel 面板。
- **DooD 架构**：支持直接管理宿主机上的 Docker 容器、镜像及网络。
- **全功能支持**：支持创建网站、配置运行环境（PHP/Python/Node.js 等）。
- **广泛兼容**：支持 OpenWRT、iStoreOS、Alpine 等非 systemd 系统环境。

## 使用方法

### 使用预构建镜像

使用以下命令通过 GitHub Container Registry 上的最新版预构建 Docker 镜像启动容器（请根据需要修改环境变量）：

```bash
docker run \
--name 1panel \
--network host \
--restart unless-stopped \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /path/to/your/data:/path/to/your/data \
-e PANEL_BASE_DIR=/path/to/your/data \
-e PANEL_PORT=9999 \
-e PANEL_ENTRANCE=entrance \
-e PANEL_USERNAME=1panel \
-e PANEL_PASSWORD=1panel_password \
ghcr.io/purainity/docker-1panel-v2:latest
```

### 本地构建镜像

将本仓库中的所有文件复制到同一目录下，进入该目录后构建镜像：

```bash
docker build -t docker-1panel-v2 .
```

构建完成后，可参照上方的 `docker run` 命令，将镜像名称替换为 `docker-1panel-v2` 来启动容器。

### Docker Compose

在项目根目录下创建一个名为 `docker-compose.yml` 的文件，内容如下：

```yaml
version: '3.8'

services:
  1panel:
    # 如果使用 ghcr 上的最新版预构建镜像
    image: ghcr.io/purainity/docker-1panel-v2:latest
    # 如果使用当前目录的 Dockerfile 本地构建镜像，请取消注释下一行，并注释上一行
    # build: . 
    container_name: 1panel # 容器名称
    network_mode: host # 使用宿主机网络
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # 挂载 Docker 套接字
      - /path/to/your/data:/path/to/your/data # 挂载 1Panel 数据目录，请确保宿主机路径和容器内路径一致
    environment:
      TZ: Asia/Shanghai # 时区
      LANGUAGE: zh # 面板语言
      PANEL_BASE_DIR: /path/to/your/data # 安装目录
      PANEL_PORT: 9999 # 面板端口
      PANEL_ENTRANCE: entrance # 安全入口
      PANEL_USERNAME: 1panel # 面板用户
      PANEL_PASSWORD: 1panel_password # 面板密码
    restart: unless-stopped # 容器退出时自动重启，除非手动停止
```

然后启动服务：

```bash
docker compose up -d --build
```

## 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
| --- | --- | --- |
| `PANEL_EDITION` | `cn` | 发行版本，可选 `cn` (国内源) 或 `intl` (国际源) |
| `INSTALL_MODE` | `stable` | 安装模式，可选 `stable` (稳定版) 或 `dev` (开发版) |
| `LANGUAGE` | `zh` | 面板语言，支持列表参考 [官方仓库](https://github.com/1Panel-dev/installer/tree/v2/lang) |
| `PANEL_BASE_DIR` | `/app` | 容器内 1Panel 数据存储根目录 |
| `PANEL_PORT` | `9999` | 面板端口 |
| `PANEL_ENTRANCE` | `entrance` | 安全入口 |
| `PANEL_USERNAME` | `1panel` | 面板用户 |
| `PANEL_PASSWORD` | `1panel_password` | 面板密码 |
| `TZ` | `Asia/Shanghai` | 时区设置 |

### 挂载目录

为了保证 1Panel 的数据、配置及安装的应用不丢失，必须挂载以下目录：

- **/var/run/docker.sock:/var/run/docker.sock**：允许容器内的 1Panel 直接与宿主机的 Docker 守护进程通信。
- **/app:/path/to/your/data**（请务必映射为 `PANEL_BASE_DIR` 指定的路径）：用于持久化存储 1Panel 的配置、数据以及通过它安装的所有应用。
    - **路径一致性重要提示**：**宿主机路径和容器内路径必须保持一致**。原因在于 1Panel 安装应用时会基于容器内路径创建数据卷，若内外路径不匹配，应用将因找不到正确的数据目录而启动失败。
    - **挂载建议**：可以直接挂载 `PANEL_BASE_DIR` 目录或其任何一级父目录，只要保证 `-v` 参数冒号前后的路径完全相同即可。例如，`-v /opt/1panel:/opt/1panel`。
- **自定义数据目录**：如需使用 1Panel 管理宿主机上的其他文件，可以根据需要挂载更多自定义数据目录。

### 端口设置

`PANEL_PORT` 环境变量设置的是 1Panel 在容器内的监听端口。
- **Host 模式**：使用 `--network host` 可使 1Panel 直接监听宿主机端口，无需额外映射。
- **非 Host 模式**：若未开启 host 模式，必须手动通过 `-p` 参数配置端口映射，将容器内端口映射到宿主机。

### 自动重启

使用 `--restart unless-stopped` 可以使 1Panel 容器在异常退出或系统重启时自动尝试恢复运行。

## 注意事项

### 1. 无法使用的功能

由于容器环境限制，以下涉及修改宿主机系统设置的功能无法使用：

- AI - GPU 监控
- 容器 - 配置 - 镜像加速（请手动修改宿主机的 docker `daemon.json`）
- 系统 - 防火墙
- 系统 - SSH 管理
- 系统 - 磁盘管理
- 工具箱 - 重启面板/重启服务器（如需重启请直接重启该容器）
- 工具箱 - 进程守护
- 工具箱 - 病毒扫描
- 工具箱 - FTP
- 工具箱 - Fail2ban

### 2. 配置生效时机

环境变量中的设置仅在**首次安装** 1Panel 时有效。安装完成后，若需修改配置，请通过 1Panel 网页面板进行操作。

### 3. 版本更新与切换

- **常规升级**：可直接在 1Panel 网页面板中进行在线更新。
- **版本切换**：若需降级或在 `stable` 与 `dev` 通道间切换，需重建容器。请确保数据目录已正确持久化，停止并删除旧容器后，修改环境变量重新创建。

### 4. 命令行工具操作

不推荐在容器环境使用 `1pctl` 脚本。如需管理面板，请先执行 `docker exec -it 1panel bash` 进入容器，再通过下述 `1panel` 原生命令进行操作。命令中的 `-l` 参数代表语言（如 `-l zh` 表示中文）。

| 完整命令 | 功能说明 |
| --- | --- |
| `1panel -l zh version` | 查看版本信息 |
| `1panel -l zh user-info` | 获取用户信息 |
| `1panel -l zh update password` | 修改面板密码 |
| `1panel -l zh update port` | 修改面板端口 |
| `1panel -l zh update username` | 修改面板用户 |
| `1panel -l zh reset domain` | 取消访问域名绑定 |
| `1panel -l zh reset entrance` | 取消安全入口 |
| `1panel -l zh reset https` | 取消 https 方式登录 |
| `1panel -l zh reset ips` | 取消授权 IP 限制 |
| `1panel -l zh reset mfa` | 取消两步验证 |
| `1panel -l zh reset passkey` | 清空通行密钥 |
| `1panel -l zh restore` | 恢复至上一个稳定版 |

### 5. 安全入口设置

首次安装时必须设置安全入口。若想关闭，请在安装完成后通过网页面板操作，或在容器内执行 `1panel -l zh reset entrance`。请勿在创建容器时将 `PANEL_ENTRANCE` 环境变量设为空字符串，否则会导致面板启动失败。

## 项目结构

```text
.
├── Dockerfile       # 容器镜像构建文件
├── entrypoint.sh   # 容器启动入口
└── install.sh      # 适配容器环境的安装脚本
```

## 免责声明

- 本项目仅用于学习与技术研究，请勿用于非法用途。
- 使用本项目造成的任何数据丢失或系统不稳定风险由使用者自行承担。
- 1Panel 程序版权归飞致云（FIT2CLOUD）所有。

## 其他项目

目前社区中已有多个优秀项目实现了在 Docker 容器内运行 1Panel。这些项目分别采用了 DooD (Docker-outside-of-Docker) 或 DinD (Docker-in-Docker) 架构，其实现细节与技术路线与本项目各有侧重：

- [Xeath/1panel-in-docker](https://github.com/Xeath/1panel-in-docker)
- [okxlin/docker-1panel](https://github.com/okxlin/docker-1panel)
- [dph5199278/docker-1panel](https://github.com/dph5199278/docker-1panel)
- [geekwho-eth/docker-1Panel](https://github.com/geekwho-eth/docker-1Panel)
