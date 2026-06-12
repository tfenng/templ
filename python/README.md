# Python 部署模板

> FastAPI 后端（uv 管理依赖、uvicorn 启动）+ 静态前端 + MySQL/Redis 的容器化部署编排。
> 基础件、nginx、前端部署方式与 `../java/` 模板保持一致，主要差异是后端 API 的运行方式。

## 在仓库中的位置

```text
templ/
├── python/                  # Python 栈部署模板（本目录）
│   ├── docker-compose.yml
│   ├── .env                 # 项目变量集中地
│   ├── nginx/conf/nginx.conf
│   ├── bin/
│   │   ├── update.sh
│   │   └── update-web.sh
│   ├── CLAUDE.md
│   └── README.md
├── java/
└── golang/
```

源代码不在本仓库，需配合：
- 后端 git 仓库（`${SRC_BACKEND}`）：标准 uv 项目，包含 `pyproject.toml` 和 `uv.lock`
- 前端 git 仓库（`${SRC_FRONTEND}`）：`pnpm run build` 产物默认为 `dist/`

## Python 后端约定

后端默认入口遵循 FastAPI 常见约定：

```text
main.py      # 文件名
app          # FastAPI 实例名
```

容器启动命令固定为：

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000
```

如果项目入口不是 `main:app`，直接修改 `docker-compose.yml` 的 `app.command`。`.env` 不为 Python 入口增加额外变量，保持模板配置简洁。

## 快速开始

```bash
cd python/
sed -i "s/app/cookbook/g" .env
docker compose config
docker compose up -d
```

`.env` 顶部 4 行是新项目必改项：

| 变量 | 含义 | 示例 |
|------|------|------|
| `PROJECT_NAME` | 项目短名，驱动库名/容器名/路径 | `cookbook` |
| `DEPLOY_ROOT` | 本部署模板所在目录 | `/home/tony/cookbook` |
| `SRC_BACKEND` | FastAPI 后端仓库路径 | `~/src/cookbook` |
| `SRC_FRONTEND` | 前端仓库路径 | `~/src/cookbook-web` |

## 部署命令

```bash
bin/update.sh        # 拉取后端 → 同步源码 → uv sync --frozen → 重启 app
bin/update-web.sh    # 拉取前端 → 条件 pnpm install → 构建 → 同步 dist 到 nginx
```

`bin/update.sh` 会把 `${SRC_BACKEND}` 同步到 `${DEPLOY_ROOT}/app/`，排除 `.git`、`.venv`、`__pycache__` 和 `.pytest_cache`。依赖安装在容器内执行：

```bash
docker compose run --rm --no-deps app uv sync --frozen
```

因此后端仓库必须提交 `uv.lock`。如果依赖未锁定，先在后端项目中执行 `uv lock`。

## 服务结构

`docker-compose.yml` 定义 4 个服务：

- `mysql`：MySQL 8.0，库名和账号由 `PROJECT_NAME` 派生。
- `redis`：Redis 7 Alpine，默认无密码。
- `app`：`ghcr.io/astral-sh/uv:python3.12-bookworm-slim`，运行 FastAPI。
- `web`：nginx，挂载静态前端并将 `/api/` 反代到 `app:8000`。

## 自定义清单

| 场景 | 改哪里 |
|------|--------|
| 后端入口不是 `main:app` | `docker-compose.yml` 的 `app.command` |
| Python 版本需要调整 | `docker-compose.yml` 的 `app.image` |
| FastAPI 监听端口不是 8000 | `docker-compose.yml` 的 `app.ports`、`app.command` 和 nginx `proxy_pass` |
| 前端输出目录不是 `dist/` | `.env` 的 `DIST_SRC` |
| 端口冲突 | `.env` 的 `APP_PORT` / `WEB_PORT` / `DATABASE_PORT` / `REDIS_PORT` |
| 生产数据库密码 | `.env` 的 `DATABASE_PASSWORD` |
