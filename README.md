# docker-1panel-v2

在 Docker 容器中运行 1Panel V2（通过 DooD 方式），支持 OpenWRT/iStoreOS 环境。

## ⚙️ 工作原理

1. **伪造 systemctl**：在容器内部增加一个伪造的 `systemctl` 脚本，以模拟系统服务管理，满足 1Panel 对 systemctl 的依赖。
2. **魔改官方安装脚本**：对 1Panel 官方安装脚本进行修改，使其适应容器环境。
3. **挂载宿主机 Docker 套接字**：通过将宿主机的 `/var/run/docker.sock` 挂载到容器内部，实现容器内 1Panel 对宿主机 Docker 守护进程的直接访问和管理。

## ❤️ 感谢以下项目

- [dph5199278/docker-1panel](https://github.com/dph5199278/docker-1panel)：提供了在 Docker 容器中运行 1Panel 的初步思路与安装方式。
- [Xeath/1panel-in-docker](https://github.com/Xeath/1panel-in-docker)：提供了运行 1Panel V2 所需的 Docker 服务伪装脚本，解决了 1Panel 在容器中对 Docker 环境的依赖。
- [gdraheim/docker-systemctl-replacement](https://github.com/gdraheim/docker-systemctl-replacement)：提供了在 Docker 容器内部使用 systemctl 模拟脚本的实现。

## 📝 环境变量

- `TZ`: 时区（默认：`Asia/Shanghai`）
- `LANGUAGE`: 面板语言（可选：`en`、`fa`、`pt-BR`、`ru`、`zh`，默认：`zh`）
- `INSTALL_MODE`: 安装模式（可选：`stable`、`beta`、`dev`，默认：`stable`）
- `VERSION`: 版本号（可手动指定特定版本号，默认：在线获取最新稳定版本）
- `PANEL_BASE_DIR`: 安装目录（默认：`/opt`）
- `PANEL_PORT`: 面板端口（默认：`9999`）
- `PANEL_ENTRANCE`: 安全入口（默认：`entrance`）
- `PANEL_USERNAME`: 面板用户（默认：`1panel`）
- `PANEL_PASSWORD`: 面板密码（默认：`1panel_password`）

## 📂 挂载目录

- **Docker 进程套接字（不可修改）**

    `/var/run/docker.sock:/var/run/docker.sock`

    允许容器内的 1Panel 直接与宿主机的 Docker 守护进程通信，管理宿主机上的 Docker 容器。

- **1Panel 数据及应用安装目录（重要）**

    `/mnt/sata4-5/Configs:/mnt/sata4-5/Configs`（示例，请替换为你的实际路径）

    此目录用于持久化存储 1Panel 的配置、数据以及通过它安装的所有应用。
    
    **为保证所有应用正常工作，宿主机路径和容器内路径必须保持一致**。原因是 1Panel 安装应用时，会基于容器内的路径（由 `PANEL_BASE_DIR` 定义）来为应用创建数据卷。如果内外路径不匹配，1Panel 本身可能正常运行，但其创建的应用将因找不到正确的数据目录而启动失败。
    
    **你可以选择直接挂载 `PANEL_BASE_DIR` 指定的目录，或其任何一级父目录，前提是 -v 参数冒号前后的路径必须完全相同**。例如，如果 `PANEL_BASE_DIR` 是 `/mnt/sata4-5/Configs`，那么 `-v /mnt/sata4-5/Configs:/mnt/sata4-5/Configs` 和 `-v /mnt:/mnt` 都是有效的配置。

## 🐳 部署方式

### Docker CLI 部署示例

1. **准备文件**

    将本仓库中的所有文件复制到同一个目录下，`cd` 进入该目录。

2. **构建 Docker 镜像**

    在本地构建 Docker 镜像，你可以修改镜像名 `docker-1panel-v2`。

    ```bash
    docker build -t docker-1panel-v2 .
    ```

3. **运行 Docker 容器**

    使用以下命令运行 1Panel 容器。**请根据你的实际需求修改配置**，这里以容器名称为 `1panel`，1Panel 安装目录为 `/mnt/sata4-5/Configs`，面板端口 `9999`，安全入口 `entrance`，面板用户 `1panel`，面板密码 `1panel_password`，自动下载最新稳定版进行演示。

    使用 `-it` 参数可以在安装过程中查看实时日志。使用 `-d` 参数可以使安装过程在后台进行，而不会占用当前终端。

    使用 `--network host` 可以避免额外的端口映射配置，使 1Panel 直接监听宿主机的端口。

    使用 `--restart unless-stopped` 可以使 1Panel 容器在出错时自动重启。

    ```bash
    docker run -it \
    --name 1panel \
    --network host \
    --restart unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /mnt/sata4-5/Configs:/mnt/sata4-5/Configs \
    -e PANEL_BASE_DIR=/mnt/sata4-5/Configs \
    -e PANEL_PORT=9999 \
    -e PANEL_ENTRANCE=entrance \
    -e PANEL_USERNAME=1panel \
    -e PANEL_PASSWORD=1panel_password \
    docker-1panel-v2
    ```

4. **访问 1Panel**

    1Panel 安装完成后，可以通过 `http://你的宿主机IP:面板端口/安全入口` 访问 1Panel 面板，使用你在环境变量中设置的用户和密码登录。

5. **进入容器内部 Bash**

    如果需要进入容器内部进行调试或手动操作 1pctl，可以使用以下命令进入容器内部 Bash 终端，注意将容器名 `1panel` 修改为你的实际名称。

    ```bash
    docker exec -it 1panel bash
    ```

### Docker Compose 部署示例

1. **创建 `docker-compose.yml` 文件**

    在项目根目录下创建一个名为 `docker-compose.yml` 的文件，内容如下，**请根据你的实际需求修改配置**。

    ```yaml
    version: '3.8'

    services:
      1panel:
        build: . # 使用当前目录的 Dockerfile 构建镜像
        container_name: 1panel # 容器名称
        network_mode: host # 使用宿主机网络
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock # 挂载 Docker 套接字
          - /mnt/sata4-5/Configs:/mnt/sata4-5/Configs # 挂载 1Panel 数据目录，请确保宿主机路径和容器内路径一致
        environment:
          TZ: Asia/Shanghai # 时区
          LANGUAGE: zh # 面板语言
          PANEL_BASE_DIR: /mnt/sata4-5/Configs # 安装目录
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

    （如果你的系统使用的是旧版 docker-compose，请使用 `docker-compose up -d --build`）

3. **访问 1Panel**

    1Panel 安装完成后，可以通过 `http://你的宿主机IP:面板端口/安全入口` 访问 1Panel 面板，使用你在环境变量中设置的用户和密码登录。