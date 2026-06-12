# Golang 部署模板

> Golang 后端（容器化 go build、distroless 运行）+ 静态前端 + MySQL/Redis 的容器化部署编排。
> 基础件、nginx、前端部署方式与 `../java/` 模板保持一致，主要差异是后端 API 的构建和运行方式。

## 在仓库中的位置

```text
templ/
├── golang/                  # Golang 栈部署模板（本目录）
│   ├── docker-compose.yml
│   ├── .env                 # 项目变量集中地
│   ├── nginx/conf/nginx.conf
│   ├── bin/
│   │   ├── update.sh
│   │   └── update-web.sh
│   ├── CLAUDE.md
│   └── README.md
├── java/
└── python/
```

源代码不在本仓库，需配合：
- 后端 git 仓库（`${SRC_BACKEND}`）：标准 Go module，包含 `go.mod` 和 `go.sum`
- 前端 git 仓库（`${SRC_FRONTEND}`）：`pnpm run build` 产物默认为 `dist/`

## Golang 后端约定

后端默认按仓库根目录构建：

```bash
CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/${PROJECT_NAME} .
```

生成的静态二进制同步到 `${DEPLOY_ROOT}/app/${PROJECT_NAME}`，运行容器使用 `gcr.io/distroless/static-debian12:nonroot`，容器内直接执行 `/app/${PROJECT_NAME}`。

默认约定 API 在容器内监听 `8080`，nginx 的 `/api/` 反代到 `app:8080`。如果项目入口在 `cmd/server` 或监听端口不同，直接修改 `bin/update.sh` 的 `go build` 参数和 `docker-compose.yml` / nginx 配置。

## 快速开始

```bash
cd golang/
sed -i "s/aps/cookbook/g" .env
docker compose config
docker compose up -d
```

`.env` 顶部 4 行是新项目必改项：

| 变量 | 含义 | 示例 |
|------|------|------|
| `PROJECT_NAME` | 项目短名，驱动库名/容器名/二进制名/路径 | `cookbook` |
| `DEPLOY_ROOT` | 本部署模板所在目录 | `/home/xmap/cookbook` |
| `SRC_BACKEND` | Golang 后端仓库路径 | `~/src/cookbook` |
| `SRC_FRONTEND` | 前端仓库路径 | `~/src/cookbook-web` |

## 部署命令

```bash
bin/update.sh        # 拉取后端 → 容器内 go build → 重启 app
bin/update-web.sh    # 拉取前端 → 条件 pnpm install → 构建 → 同步 dist 到 nginx
```

`bin/update.sh` 不要求宿主机安装 Go，而是使用 `golang:1.22-bookworm` 构建容器。构建产物为 Linux 静态二进制，适合 distroless 运行镜像。

## 服务结构

`docker-compose.yml` 定义 4 个服务：

- `mysql`：MySQL 8.0，库名和账号由 `PROJECT_NAME` 派生。
- `redis`：Redis 7 Alpine，默认无密码。
- `app`：distroless 运行镜像，执行挂载的 Go 二进制。
- `web`：nginx，挂载静态前端并将 `/api/` 反代到 `app:8080`。

## 自定义清单

| 场景 | 改哪里 |
|------|--------|
| main 包不在仓库根目录 | `bin/update.sh` 的 `go build ... .` |
| 需要 CGO | `bin/update.sh` 的 `CGO_ENABLED` 和运行镜像 |
| API 监听端口不是 8080 | `docker-compose.yml` 的 `app.ports` 和 nginx `proxy_pass` |
| 前端输出目录不是 `dist/` | `.env` 的 `DIST_SRC` |
| 端口冲突 | `.env` 的 `APP_PORT` / `WEB_PORT` / `DATABASE_PORT` / `REDIS_PORT` |
| 生产数据库密码 | `.env` 的 `DATABASE_PASSWORD` |
