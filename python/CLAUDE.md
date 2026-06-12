# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Python deployment template.

## 仓库性质

本目录是 **FastAPI 后端 + 静态前端 + MySQL/Redis** 的部署编排模板。应用源代码不在本仓库，分别位于：

- 后端：`${SRC_BACKEND}`（uv 项目，包含 `pyproject.toml` 和 `uv.lock`）
- 前端：`${SRC_FRONTEND}`（pnpm / Vite 或类似工具，构建产物默认为 `dist/`）

本仓库只负责把外部源码和构建产物编排成可运行的容器化服务。所有项目相关路径集中在 `.env`。

## 服务架构

```text
client -> nginx:80 (web) -> /api/ -> app:8000
                                 -> FastAPI main:app
                                 -> mysql:3306 / redis:6379
```

`docker-compose.yml` 定义 4 个服务：

- `mysql`：MySQL 8.0，库名、用户由 `PROJECT_NAME` 派生。
- `redis`：Redis 7 Alpine，默认缓存用途。
- `app`：`ghcr.io/astral-sh/uv:python3.12-bookworm-slim`，工作目录 `/app`，执行 `uv run uvicorn main:app --host 0.0.0.0 --port 8000`。
- `web`：nginx，挂载 `${DEPLOY_ROOT}/nginx/{log,conf,www}`，`/api/` 反代到 `app:8000`。

## Python 约定

默认后端入口为 `main.py` 中的 `app` 对象。不要为了常见入口新增 `.env` 变量；如果具体项目不是 `main:app`，直接修改 `docker-compose.yml` 的 `app.command`。

依赖由 uv 管理。后端仓库必须提交：

```text
pyproject.toml
uv.lock
```

部署时使用 `uv sync --frozen`，因此不会接受未锁定依赖。

## 常用命令

下面命令默认在 Python 模板目录执行：

```bash
docker compose config          # 验证 .env 展开和 compose 配置
docker compose up -d           # 启动 mysql/redis/app/web
docker compose logs -f app     # 查看 FastAPI 日志
docker compose restart app     # 重启 API 容器
bin/update.sh                  # 部署后端
bin/update-web.sh              # 部署前端
```

## update.sh 行为

1. `cd $SRC_BACKEND && git pull origin master`
2. 无 commit 变化则直接退出。
3. `rsync` 后端源码到 `$DEPLOY_ROOT/app/`。
4. 排除 `.git`、`.venv`、`__pycache__`、`.pytest_cache`。
5. 在 compose 服务镜像中执行 `docker compose run --rm --no-deps app uv sync --frozen`。
6. `docker compose restart app`。

## 修改本模板的典型场景

| 场景 | 改哪里 |
|------|--------|
| FastAPI 入口不是 `main:app` | `docker-compose.yml` 的 `app.command` |
| Python 版本变化 | `docker-compose.yml` 的 `app.image` |
| API 容器端口变化 | `docker-compose.yml` 和 `nginx/conf/nginx.conf` |
| 前端 dist 路径变化 | `.env` 的 `DIST_SRC` |
| 默认分支不是 master | `bin/update.sh` / `bin/update-web.sh` 的 `git pull origin master` |

## 关键约定

1. `.env` 尽量只放项目级变量，不放 Python 入口细节。
2. 后端部署不在宿主机安装依赖；依赖同步在 uv 容器中完成。
3. nginx 反代目标使用容器内 DNS：`proxy_pass http://app:8000`。
4. 保留 `mysql`、`redis`、`app`、`web` 四个服务名，与其它语言模板一致。
