# docker-1panel-v2

在 Docker 容器中运行 1Panel V2（通过 DooD 方式），支持 OpenWRT/iStoreOS 环境。

## ⚙️ 工作原理

1. **模拟 systemctl**：在容器内部增加一个模拟的 systemctl 脚本，以模拟系统服务管理，满足 1Panel 对 systemctl 的依赖。
2. **魔改官方安装脚本**：对 1Panel 官方安装脚本进行修改，使其适应容器环境。
3. **DooD 模式 (Docker-out-of-Docker)**：通过将宿主机的 `/var/run/docker.sock` 挂载到容器内部，使容器内的 1Panel 能够直接访问和管理宿主机上的 Docker 守护进程及容器。

## ❤️ 特别感谢

- [dph5199278/docker-1panel](https://github.com/dph5199278/docker-1panel)：提供了在 Docker 容器中运行 1Panel 的初步思路与安装方式。
- [Xeath/1panel-in-docker](https://github.com/Xeath/1panel-in-docker)：提供了运行 1Panel V2 所需的 Docker 服务伪装脚本，解决了 1Panel 在容器中对 Docker 环境的依赖。
- [gdraheim/docker-systemctl-replacement](https://github.com/gdraheim/docker-systemctl-replacement)：提供了在 Docker 容器内部使用 systemctl 模拟脚本的实现。

## 📝 环境变量

- `TZ`：时区（默认：`Asia/Shanghai`）
- `LANGUAGE`：面板语言（可选：`en`、`fa`、`pt-BR`、`ru`、`zh`，默认：`zh`）
- `INSTALL_MODE`：安装模式（可选：`stable`、`beta`、`dev`，默认：`stable`）
- `VERSION`：版本号（可手动指定特定版本号，默认：在线获取最新稳定版本）
- `PANEL_BASE_DIR`：安装目录（默认：`/opt`）
- `PANEL_PORT`：面板端口（默认：`9999`）
- `PANEL_ENTRANCE`：安全入口（默认：`entrance`）
- `PANEL_USERNAME`：面板用户（默认：`1panel`）
- `PANEL_PASSWORD`：面板密码（默认：`1panel_password`）

## 📂 挂载目录

- **Docker 进程套接字（不可修改）**

    `/var/run/docker.sock:/var/run/docker.sock`

    允许容器内的 1Panel 直接与宿主机的 Docker 守护进程通信，管理宿主机上的 Docker 容器。

- **1Panel 数据及应用安装目录（重要）**

    `/path/to/your/data:/path/to/your/data`（示例，**请务必替换为您的实际路径**）

    此目录用于持久化存储 1Panel 的配置、数据以及通过它安装的所有应用。
    
    **为保证所有应用正常工作，宿主机路径和容器内路径必须保持一致**。原因是 1Panel 安装应用时，会基于容器内的路径（由 `PANEL_BASE_DIR` 定义）来为应用创建数据卷。如果内外路径不匹配，1Panel 本身可能正常运行，但其创建的应用将因找不到正确的数据目录而启动失败。
    
    您可以选择直接挂载 `PANEL_BASE_DIR` 指定的目录，或其任何一级父目录，前提是 -v 参数冒号前后的路径必须完全相同**。例如，如果 `PANEL_BASE_DIR` 是 `/path/to/your/data`，那么 `-v /path/to/your/data:/path/to/your/data` 和 `-v /path:/path` 都是有效的配置。

## 🐳 部署方式

### Docker CLI 部署示例

1. **准备 Docker 镜像**

    您可以使用 GitHub Container Registry 上的最新版预构建 Docker 镜像：`ghcr.io/purainity/docker-1panel-v2:latest`，也可以在本地构建镜像。

    如需在本地构建 Docker 镜像，请将本仓库中的所有文件复制到同一目录下，`cd` 进入该目录后执行以下命令。您可以根据需要修改镜像名 `docker-1panel-v2`。

    ```bash
    docker build -t docker-1panel-v2 .
    ```

2. **运行 Docker 容器**

    使用以下命令运行 1Panel 容器。**请务必根据您的实际需求修改配置参数**。以下示例使用 ghcr 上的最新预构建镜像，容器名称为 `1panel`，1Panel 数据目录为 `/path/to/your/data`，面板端口 `9999`，安全入口 `entrance`，面板用户 `1panel`，面板密码 `1panel_password`，并自动下载最新稳定版。

    使用 `--network host` 可以避免额外的端口映射配置，使 1Panel 直接监听宿主机的端口。

    使用 `--restart unless-stopped` 可以使 1Panel 容器在异常退出时自动重启。

    ```bash
    docker run -d \
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

3. **访问 1Panel**

    1Panel 安装完成后，您可以通过 `http://您的宿主机IP:面板端口/安全入口` 访问 1Panel 面板，并使用您在环境变量中设置的用户和密码登录。

### Docker Compose 部署示例

1. **创建 `docker-compose.yml` 文件**

    在项目根目录下创建一个名为 `docker-compose.yml` 的文件，内容如下。**请务必根据您的实际需求修改配置参数**。

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

2. **部署服务**

    在 `docker-compose.yml` 文件所在的目录下，执行以下命令构建镜像并启动服务。

    ```bash
    docker compose up -d --build
    ```

    （如果您的系统使用的是旧版 docker-compose，请使用 `docker-compose up -d --build`）

3. **访问 1Panel**

    1Panel 安装完成后，您可以通过 `http://您的宿主机IP:面板端口/安全入口` 访问 1Panel 面板，并使用您在环境变量中设置的用户和密码登录。

## ❓ 常见问题

1. **运行容器后无法进入网页面板？**

    请使用以下命令查看容器日志，注意将容器名 `1panel` 修改为您的实际容器名称。

    ```bash
    docker logs -f 1panel
    ```

    如果日志中未出现 `[INFO] listen at http://0.0.0.0:面板端口 [tcp4]`，则说明 1Panel 还未启动，请耐心等待。如果重启容器后仍无法访问，请检查是否使用了 `host` 网络模式，若否，请检查是否正确配置了端口映射。

2. **网页面板出现 `请求错误，请检查该节点状态: stat /etc/1panel/agent.sock: no such file or directory` ？**

    这是 `1panel-agent` 服务还未完全启动。请耐心等待几秒钟后刷新网页即可。若长时间这样，请尝试重启容器。

3. **1Panel 安装完成后，如何修改安全入口、面板用户、面板密码等设置？**

    环境变量中的设置仅在首次安装 1Panel 时有效。如果需要在安装完成后修改这些设置，请通过 1Panel 的网页面板进行操作。
    
4. **如何更换 1Panel 版本？**

    环境变量中的设置仅在首次安装 1Panel 时有效。对于常规升级，您可直接在 1Panel 的网页面板中进行在线更新。若需进行版本切换（如降级、或在 `stable` 与 `dev` 等通道间切换），则需要重建容器。请确保 1Panel 数据目录已正确持久化到宿主机，然后停止并删除旧容器，最后使用原部署命令，修改 `INSTALL_MODE` 或 `VERSION` 环境变量后重新创建容器。

5. **如何使用 1pctl 命令行操作？**

    请先使用以下命令进入容器内部 Bash 终端，然后输入 `1pctl` 即可操作，注意将容器名 `1panel` 修改为您的实际容器名称。

    ```bash
    docker exec -it 1panel bash
    ```

6. **能否不设置安全入口？**

    首次安装时必须设置安全入口。如果您想关闭安全入口，请在 1Panel 安装完成后，进入网页面板进行关闭操作。**请勿手动将 `PANEL_ENTRANCE` 环境变量设置为空字符串，这会导致安装完成后 1Panel 无法启动！**

7. **为什么不在镜像构建阶段就安装好 1Panel，而是在运行容器时才安装？这是否违背了 Docker 的不变性原则？**

    1Panel 版本更新频繁，本项目旨在提供一个通用的容器化运行环境，而非固化特定版本。采用运行时安装的方式，可以避免频繁构建容器镜像，并允许用户通过 `INSTALL_MODE` 和 `VERSION` 环境变量灵活指定需要安装的 1Panel 版本。
