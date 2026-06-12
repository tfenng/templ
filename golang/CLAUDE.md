# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Golang deployment template.

## 仓库性质

本目录是 **Golang 后端 + 静态前端 + MySQL/Redis** 的部署编排模板。应用源代码不在本仓库，分别位于：

- 后端：`${SRC_BACKEND}`（Go module，包含 `go.mod` 和 `go.sum`）
- 前端：`${SRC_FRONTEND}`（pnpm / Vite 或类似工具，构建产物默认为 `dist/`）

本仓库只负责把外部源码构建产物编排成可运行的容器化服务。所有项目相关路径集中在 `.env`。

## 服务架构

```text
client -> nginx:80 (web) -> /api/ -> app:8080
                                 -> /app/${PROJECT_NAME}
                                 -> mysql:3306 / redis:6379
```

`docker-compose.yml` 定义 4 个服务：

- `mysql`：MySQL 8.0，库名、用户由 `PROJECT_NAME` 派生。
- `redis`：Redis 7 Alpine，默认缓存用途。
- `app`：`gcr.io/distroless/static-debian12:nonroot`，直接执行挂载的 Go 静态二进制。
- `web`：nginx，挂载 `${DEPLOY_ROOT}/nginx/{log,conf,www}`，`/api/` 反代到 `app:8080`。

## Golang 约定

默认后端仓库根目录就是 main package。部署脚本使用构建容器执行：

```bash
CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/${PROJECT_NAME} .
```

不要为了常见 main 包路径新增 `.env` 变量。如果具体项目入口在 `cmd/server`，直接修改 `bin/update.sh` 的 `go build` 末尾路径。

## 常用命令

下面命令默认在 Golang 模板目录执行：

```bash
docker compose config          # 验证 .env 展开和 compose 配置
docker compose up -d           # 启动 mysql/redis/app/web
docker compose logs -f app     # 查看后端日志
docker compose restart app     # 重启 API 容器
bin/update.sh                  # 部署后端
bin/update-web.sh              # 部署前端
```

## update.sh 行为

1. `cd $SRC_BACKEND && git pull origin master`
2. 无 commit 变化则直接退出。
3. 使用 `golang:1.22-bookworm` 构建容器运行 `go mod download` 和 `go build`。
4. 输出二进制到 `$DEPLOY_ROOT/app/$PROJECT_NAME`。
5. `chmod +x` 后执行 `docker compose restart app`。

## 修改本模板的典型场景

| 场景 | 改哪里 |
|------|--------|
| main package 不在仓库根目录 | `bin/update.sh` 的 `go build` 路径 |
| 需要 CGO 或动态链接 | `bin/update.sh` 和 `docker-compose.yml` 的运行镜像 |
| API 容器端口变化 | `docker-compose.yml` 和 `nginx/conf/nginx.conf` |
| 前端 dist 路径变化 | `.env` 的 `DIST_SRC` |
| 默认分支不是 master | `bin/update.sh` / `bin/update-web.sh` 的 `git pull origin master` |

## 关键约定

1. `.env` 尽量只放项目级变量，不放 Go main 包路径细节。
2. 后端构建不要求宿主机安装 Go；构建在 Docker 容器中完成。
3. nginx 反代目标使用容器内 DNS：`proxy_pass http://app:8080`。
4. 保留 `mysql`、`redis`、`app`、`web` 四个服务名，与其它语言模板一致。
