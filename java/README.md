# APS 部署模板

> Spring Boot fat-jar 后端 + 静态前端 + MySQL/Redis 的容器化部署编排。
> 所有项目相关变量集中在 `.env`，克隆后改 4 行即可用于新项目。

## 在仓库中的位置

```
templ/
├── java/                    # Java 栈部署模板（本目录，已实现）
│   ├── docker-compose.yml
│   ├── .env                 # ★ 项目变量集中地
│   ├── nginx/conf/nginx.conf
│   ├── bin/
│   │   ├── update.sh
│   │   └── update-web.sh
│   ├── CLAUDE.md
│   └── README.md            # 本文件
├── python/                  # Python 栈部署模板（占位）
└── golang/                  # Golang 栈部署模板（占位）
```

> 总目录结构与共享设计原则见 [templ/ 根 README](../README.md)。
> 使用本 Java 模板时，所有命令均在 `java/` 子目录下执行。

源代码不在本仓库，需配合：
- 后端 git 仓库（`${SRC_BACKEND}`，Maven `mvn clean package` 产物为 `target/${ARTIFACT_NAME}.jar`）
- 前端 git 仓库（`${SRC_FRONTEND}`，`pnpm run build` 产物为 `dist/`）

## 快速开始

### 1. 拉取模板到新项目

```bash
# 方式 A：克隆整个仓库（保留 git 历史，方便后续 sync 模板更新）
git clone <templ-repo-url> /home/xmap/cookbook
cd /home/xmap/cookbook
rm -rf .git && git init   # 重新初始化为新项目的部署仓库

# 方式 B：仅复制需要的文件到已有项目目录
SRC=<templ-repo-url> && DEST=/home/xmap/cookbook
mkdir -p "$DEST"
curl -fsSL "$SRC/raw/master/docker-compose.yml" -o "$DEST/docker-compose.yml"
curl -fsSL "$SRC/raw/master/.env"             -o "$DEST/.env"
curl -fsSL "$SRC/raw/master/nginx.conf"       -o "$DEST/nginx.conf"
mkdir -p "$DEST/bin"
curl -fsSL "$SRC/raw/master/bin/update.sh"    -o "$DEST/bin/update.sh"
curl -fsSL "$SRC/raw/master/bin/update-web.sh" -o "$DEST/bin/update-web.sh"
chmod +x "$DEST/bin/"*.sh
```

### 2. 替换项目关键字（核心步骤）

`.env` 中所有 `aps` 都对应项目短名 `cookbook`，一行 sed 即可全部替换：

```bash
sed -i 's/aps/cookbook/g' .env
```

这条命令会改 `.env` 中 5 处 `aps`：

| 字段 | 替换前 | 替换后 |
|------|--------|--------|
| `PROJECT_NAME` | `aps` | `cookbook` |
| `DEPLOY_ROOT` | `/home/xmap/aps` | `/home/xmap/cookbook` |
| `SRC_BACKEND` | `~/src/aps` | `~/src/cookbook` |
| `SRC_FRONTEND` | `~/src/aps-web` | `~/src/cookbook-web` |
| `DATABASE_PASSWORD` | `aps` | `cookbook` |

> `docker-compose.yml` / `bin/*.sh` / `nginx.conf` 全部走 `${PROJECT_NAME}` 派生，不需要再改。

### 3. 验证派生结果

```bash
docker compose config | grep -E "(volume|container_name):" -A 1
```

应该看到所有路径里的 `aps` 都已经变成 `cookbook`，例如：
- `aps-app` → `cookbook-app`
- `/home/xmap/aps/app/aps.jar` → `/home/xmap/cookbook/app/cookbook.jar`
- `/home/xmap/data/aps/db` → `/home/xmap/data/cookbook/db`

### 4. 启动服务

```bash
docker compose up -d
docker compose ps      # mysql 应显示 healthy，app 应 Up
```

## 配置变量

`.env` 顶部 4 行是**新项目必改**：

| 变量 | 含义 | 示例 |
|------|------|------|
| `PROJECT_NAME` | 项目短名，驱动库名/容器名/JAR 名/路径 | `cookbook` |
| `DEPLOY_ROOT` | 本仓库所在目录（也是 `docker compose` 运行目录） | `/home/xmap/cookbook` |
| `SRC_BACKEND` | 后端 git 仓库路径 | `~/src/cookbook` |
| `SRC_FRONTEND` | 前端 git 仓库路径 | `~/src/cookbook-web` |

其余变量按需调整：

| 变量 | 默认值 | 何时需要改 |
|------|--------|-----------|
| `DATA_ROOT` | `/home/xmap/data` | 持久化数据不想放在默认位置 |
| `APP_PORT` / `WEB_PORT` | `8080` / `80` | 端口冲突 |
| `DATABASE_PORT` / `REDIS_PORT` | `3306` / `6379` | 同上 |
| `DATABASE_ROOT` | `imroot` | 改 root 密码 |
| `DATABASE_PASSWORD` | 跟随 `PROJECT_NAME` | **生产环境必须改** |
| `ARTIFACT_NAME` | `=PROJECT_NAME` | Maven `<artifactId>` 与项目名不一致 |
| `DIST_SRC` | `${SRC_FRONTEND}/dist/` | Vite `outDir` 自定义 |

## 部署命令

```bash
bin/update.sh        # 拉取后端 → Maven 构建 → 同步 JAR → 重启 app 容器
bin/update-web.sh    # 拉取前端 → 条件 pnpm install → 构建 → 同步 dist 到 nginx
```

两个脚本都通过 `BASH_SOURCE` 自动定位项目根，**支持软链到任意位置**调用。

## 自定义清单

> 复制模板后**只改 `.env` 4 行**就能跑起来；以下情况需要进一步定制：

| 场景 | 改哪里 |
|------|--------|
| 后端服务监听端口不是 8080 | `docker-compose.yml` 的 `app.ports` 目标端口 + `.env` 的 `APP_PORT` |
| 启动命令不是 `java -jar /app/...jar`（如需指定 active profile） | `docker-compose.yml` 的 `app.command` |
| Spring Boot 需要读 `application-prod.yml` | 同上，加 `--spring.profiles.active=prod` |
| MySQL 需要 utf8mb4 **大小写不敏感** | `docker-compose.yml` 的 `mysql.command` 改 collation |
| 多个前端 SPA 部署在同一域名 | `nginx.conf` 加 `location` 分流 |
| 后端 `application.yml` 反向代理头部 | 加 `server.forward-headers-strategy: native` |

## 常见问题

**Q：`docker compose config` 报 "variable not set"？**
A：`.env` 漏了某个变量，或 `docker-compose.yml` 引用了未在 `.env` 中定义的 key。检查顶部 4 行。

**Q：`update.sh` 报 "Permission denied" / "no such file"？**
A：`chmod +x bin/update.sh`；或 `${SRC_BACKEND}` 不存在——`git clone` 后端仓库到该路径。

**Q：前端 dist/ 同步后页面 404？**
A：检查 `nginx.conf` 的 `root` 路径（`/var/www/html`）与挂载点（`${DEPLOY_ROOT}/nginx/www`）是否一致；以及 `try_files` 规则。

**Q：mysql 容器一直 restarting / unhealthy？**
A：99% 是 `${DATA_ROOT}/${PROJECT_NAME}/db` 父目录权限问题。`mkdir -p` 后 `chown -R 999:999`。

**Q：nginx 反代后端后，后端日志里客户端 IP 全是 `172.x.x.x`？**
A：缺少 `X-Forwarded-For` 解析。后端 `application.yml` 加：
```yaml
server:
  forward-headers-strategy: native
```
