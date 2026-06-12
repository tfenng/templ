# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库性质

本仓库是 **Spring Boot fat-jar 后端 + 静态前端** 部署编排的**通用模板**。源代码不在本仓库，分别位于：
- 后端：`${SRC_BACKEND}`（Maven / Spring Boot，master 分支）
- 前端：`${SRC_FRONTEND}`（pnpm / Vite 或类似工具，master 分支）

本仓库只负责把外部构建产物编排成可运行的容器化服务。**所有项目相关路径都集中在 `.env` 里**，详见末尾"应用到新项目"。

## 服务架构

`docker-compose.yml` 定义 4 个服务，关系如下：

```
client → nginx:80 (web, 容器内 DNS) → app:8080
                                       ↑
                  java -jar /app/${PROJECT_NAME}.jar  ← 挂载的外部 JAR
                                       ↓
                  mysql:3306 ←  →  redis:6379
```

- **mysql** — MySQL 8.0，字符集 `utf8mb4`，排序规则 `utf8mb4_0900_as_cs`（大小写敏感）。库名/用户从 `PROJECT_NAME` 派生。
- **redis** — Redis 7 Alpine，纯缓存用途。数据目录从 `DATA_ROOT/${PROJECT_NAME}/redis` 派生。
- **app** — `eclipse-temurin:17-jdk-jammy`，启动时 `exec java -jar /app/${PROJECT_NAME}.jar`
  - 容器名 `${PROJECT_NAME}-app`
  - JAR 由 `${DEPLOY_ROOT}/app/${PROJECT_NAME}.jar` 只读挂载
  - **此服务不构建 JAR**，只负责运行已构建产物
  - 启动参数针对容器冷启动做了熵和 JIT 优化
- **web** — `nginx:latest`，挂载 `${DEPLOY_ROOT}/nginx/{log,conf,www}` 三件套

## 当前 .env 派生规则

docker-compose.yml 内做 `${...}` 嵌套展开（compose 自身支持）。`.env` 中只需保留叶子变量：

| 来源 | 派生为 |
|------|--------|
| `PROJECT_NAME=aps` | 容器名 `aps-app`、库名 `aps`、账号 `aps`、JAR 名 `aps.jar` |
| `DEPLOY_ROOT=/home/xmap/aps` | JAR 挂载点、nginx 三个挂载点 |
| `DATA_ROOT=/home/xmap/data` | mysql/redis 数据卷 `.../${PROJECT_NAME}/{db,redis}` |

修改任一上游变量，docker compose 会自动重算所有挂载点。

## 常用命令

> 下面命令默认在 `${DEPLOY_ROOT}`（即 `.env` 与 `docker-compose.yml` 同目录）执行。

```bash
# 启动 / 停止 / 重启整栈
docker compose up -d
docker compose down
docker compose restart

# 单服务操作
docker compose restart app        # 配合 bin/update.sh 重新加载 JAR
docker compose logs -f app        # 查看后端日志
docker compose logs -f web        # 查看 nginx 日志
docker compose exec mysql bash
docker compose exec redis sh

# 部署后端（拉取 → Maven 构建 → 同步 JAR → 重启容器）
bin/update.sh

# 部署前端（拉取 → 条件 pnpm install → 构建 → 同步 dist）
bin/update-web.sh
```

## 部署脚本行为

两个脚本均通过 `SCRIPT_DIR/..` 找到项目根并 `source .env`，因此可以从任意位置调用（即使被软链到 `/usr/local/bin` 也能正常工作）。

### `bin/update.sh`（后端）
1. `cd $SRC_BACKEND && git pull origin master`
2. 若 commit 无变化直接 `exit 0`（不构建、不重启）
3. `mvn clean package` 生成 `target/${ARTIFACT_NAME}.jar`（默认 `ARTIFACT_NAME=$PROJECT_NAME`，可在 `.env` 覆盖）
4. `rsync -av` 同步到 `$DEPLOY_ROOT/app/`
5. `cd $PROJECT_ROOT && docker compose restart app`（用 compose 服务名 `app`，不是旧的 `aps`）

### `bin/update-web.sh`（前端）
1. `cd $SRC_FRONTEND && git pull origin master`
2. 无 commit 变化直接退出
3. 用 `git diff --name-only OLD NEW | grep '^package.json$'` 判断是否需 `pnpm install`（仅在依赖变更时执行）
4. `pnpm run build` 生成 `dist/`（路径可通过 `.env` 的 `DIST_SRC` 覆盖）
5. `rsync -av --progress --delete` 同步到 `$DEPLOY_ROOT/nginx/www/`

## 应用到新项目

复制本仓库到新目录后，**只改 `.env` 顶部 4 行**即可：

```bash
PROJECT_NAME=xxx                  # 项目短名（驱动库名/容器名/JAR 名/路径）
DEPLOY_ROOT=/path/to/xxx          # 本仓库克隆到的地方（也是 docker-compose 运行的目录）
SRC_BACKEND=~/src/xxx             # 后端 git 仓库路径（遵循 ~src/<name> 约定可省略）
SRC_FRONTEND=~/src/xxx-web        # 前端 git 仓库路径
```

可选调整：
- `DATA_ROOT=/home/xmap/data` — 如果数据卷父目录不在默认位置
- `ARTIFACT_NAME=` — 如果 Maven `<artifactId>` 与 `PROJECT_NAME` 不一致（默认等于 `PROJECT_NAME`）
- `DIST_SRC=` — 如果前端构建输出目录不是 `dist/`（如 Vite 的 `outDir` 自定义）
- `APP_PORT` / `WEB_PORT` / `DATABASE_PORT` / `REDIS_PORT` — 端口冲突时调整
- `DATABASE_PASSWORD` — 生产环境必须改

**不需要改的**：
- `docker-compose.yml` 任何路径（已全部从 `${PROJECT_NAME}` / `${DEPLOY_ROOT}` 派生）
- `bin/update.sh` / `bin/update-web.sh` 任何路径（同上）
- `nginx/conf/nginx.conf`（代理目标是容器内 DNS `app:8080`，与项目无关）

## 修改本仓库的典型场景

| 场景 | 改哪里 |
|------|--------|
| 调整 DB/Redis 凭据或端口 | `.env` |
| 调整 nginx 代理目标 / 路由 | `nginx/conf/nginx.conf` |
| 调整后端 JVM 参数 | `docker-compose.yml` 中 `app.command` 那一行 |
| 添加新服务 | `docker-compose.yml`（如新服务需要端口/卷，按 `${...}` 模式引用 `.env`） |

## 关键约定

1. **所有镜像 `pull_policy: missing`** — 本地无则拉取，CI/CD 不需要预先 `docker pull`。
2. **Nginx 反向代理走容器内 DNS**：`proxy_pass http://app:8080`，不是 LAN IP。**配套要求**：Spring Boot 后端需在 `application.yml` 设置 `server.forward-headers-strategy: native`，否则 Controller 里 `request.getRemoteAddr()` 拿到的是 nginx 容器 IP。
3. **MySQL 字符集固定**：`utf8mb4_0900_as_cs`（大小写敏感）。如果新项目要大小写不敏感，改 `docker-compose.yml` 的 `mysql.command` 那一行。
4. **健康检查**：mysql 密码用 `${MYSQL_ROOT_PASSWORD}`（在容器内 shell 展开），与 `MYSQL_ROOT_PASSWORD` 环境变量保持一致。
5. **更新源**：`bin/update*.sh` 假设后端/前端仓库的默认分支都是 `master`。如需改默认分支，编辑脚本里的 `git pull origin master`。
