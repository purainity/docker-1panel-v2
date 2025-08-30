# docker-1panel-v2

在 OpenWRT 上通过 Docker 的方式安装 1Panel，我之前一直用的是 [linkease/istorepanel](https://hub.docker.com/r/linkease/istorepanel)，但是它不适配 1Panel V2，也不开源。

就参考了 [dph5199278/docker-1panel](https://github.com/dph5199278/docker-1panel) 和 [Xeath/1panel-in-docker](https://github.com/Xeath/1panel-in-docker) 的实现，通过增加一个伪造的 systemctl，并魔改了官方的安装脚本，使 1Panel V2 的一些功能可用，并去除了安装时对安全入口、用户、密码等的一些限制。

### 已知问题

由于 V2 和 V1 部分逻辑不同，导致在容器内实际上能够访问宿主机上的 Docker 进程，但是 1Panel 仍然会显示 Docker 未运行。

登录 1Panel 后台后可以通过访问 `http://ip:port/apps/all?install=应用名称` 的方式正常在宿主机上安装应用，但是直接访问应用商店会显示 `当前未启动 Docker 服务，请在【配置】中开启`，且启动后无效，1Panel 依然会认为 Docker 未运行。

### 环境变量

- 时区：`TZ`（默认：`Asia/Shanghai`）
- 语言：`LANGUAGE`（可选`en`、`fa`、`pt-BR`、`ru`、`zh`，默认：`zh`）
- 安装模式: `INSTALL_MODE`（可选`stable`、`beta`、`dev`，默认：`stable`）
- 版本：`VERSION`（可手动指定版本号，默认在线获取最新版本）
- 安装目录: `PANEL_BASE_DIR`（默认：`/opt`）
- 面板端口: `PANEL_PORT`（默认：`9999`）
- 安全入口: `PANEL_ENTRANCE`（默认：`entrance`）
- 面板用户: `PANEL_USERNAME`（默认：`1panel`）
- 面板密码: `PANEL_PASSWORD`（默认：`1panel_password`）

###  挂载目录

- Docker 进程（不可修改）：`/var/run/docker.sock:/var/run/docker.sock`
- Docker 数据目录（请将前部分修改为你的宿主机上的 Docker 实际数据目录）：`/mnt/sata4-5/docker:/var/lib/docker`
- 1Panel 安装目录（容器内目录和容器外目录路径需要保持一致，都与环境变量中的`PANEL_BASE_DIR`相同）： `/mnt/sata4-5/new:/mnt/sata4-5/new`

如许挂载其他数据目录，自行添加即可。

### 部署方式

**以下以宿主机上的 Docker 实际数据目录为 `/mnt/sata4-5/docker`，安装目录为 `/mnt/sata4-5/test` 演示**

先将所有文件复制到同一目录下，然后 cd 到该目录，构建镜像

```
docker build -t new .
```

运行容器（自行修改环境变量），推荐加上 -it 参数方便查看安装日志，使用 host 网络以免额外设置端口映射

```
docker run -it \
--name new \
--network host \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /mnt/sata4-5/docker:/var/lib/docker \
-v /mnt/sata4-5/test:/mnt/sata4-5/test \
-e PANEL_BASE_DIR=/mnt/sata4-5/test \
-e PANEL_PORT=8888 \
-e PANEL_ENTRANCE=entrance \
-e PANEL_USERNAME=1panel \
-e PANEL_PASSWORD=1panel_password \
new
```

另附进入容器内部 bash 的命令

```
docker exec -it new bash
```