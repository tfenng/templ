# 部署模板（多语言）

> 一组容器化部署编排模板，针对不同语言后端。所有子模板共享同一种"项目变量集中 + 多服务编排"模式。

## 仓库结构

```
templ/
├── java/        # Spring Boot fat-jar 后端（已实现）
├── python/      # Python 后端（占位）
└── golang/      # Golang 后端（占位）
```

## 各模板状态

| 目录 | 状态 | 后端形态 | 备注 |
|------|------|---------|------|
| [`java/`](java/) | ✅ 已实现 | Spring Boot fat-jar | 当前生产使用 |
| [`python/`](python/) | ⏳ 占位 | gunicorn / uvicorn | 待首个 Python 项目落地 |
| [`golang/`](golang/) | ⏳ 占位 | 单一静态二进制 | 待首个 Golang 项目落地 |

> 占位目录各含一份 `README.md`，列出相对于 `java/` 模板**实现时必须改的差异点**（镜像、构建命令、健康检查形式等）。

## 共享设计原则

所有子模板遵循同一套约定，便于横向迁移：

1. **变量集中**：所有项目相关变量（项目名、部署路径、源码路径、端口、凭据）集中在 `.env`。
2. **路径派生**：`docker-compose.yml` 内用 `${...}` 嵌套展开；`bin/*.sh` 通过 `source .env` 在 shell 中派生。
3. **服务结构固定**：`mysql` + `redis` + `app`（语言运行时） + `web`（nginx 反代） 四服务。
4. **轻量 CI/CD**：`bin/update*.sh` 拉代码 → 构建 → 同步产物 → 重启容器，每个脚本 50 行左右。
5. **镜像策略**：`pull_policy: missing`（本地优先，按需拉取），CI/CD 不需要预先 `docker pull`。
6. **健康检查**：DB/Redis 用容器镜像自带的客户端；app 用语言原生的健康端点。

## 进入子模板

每个子目录是**独立的部署单元**。进入对应目录操作：

```bash
cd java/           # 进入 Java 模板
cat README.md      # 阅读该模板的使用说明
sed -i 's/aps/<your-name>/g' .env   # 派生项目关键字
docker compose config              # 验证派生结果
docker compose up -d               # 启动
```

> `bin/update*.sh` 通过 `BASH_SOURCE` 自动定位项目根，支持软链到 `/usr/local/bin` 等任意位置调用。

## 实现新模板

直接复制 `java/` 整套文件作为起点，按对应占位 README 列出的差异点逐项修改：

```bash
cp -r java/ python/
rm -rf python/.git python/.env
# 然后按 python/README.md 列出的差异点逐项改
```

差异点（摘要）：

| 维度 | java/ | python/ | golang/ |
|------|-------|---------|---------|
| 基础镜像 | `eclipse-temurin:17` | `python:3.12-slim` | `distroless/static` |
| 后端产物 | `target/*.jar` | `pip install` | `go build -o *.bin` |
| 启动命令 | `java -jar ...` | `gunicorn` / `uvicorn` | 直接执行二进制 |
| 健康检查 | `CMD-SHELL` | `CMD-SHELL` | `CMD`（distroless 无 shell） |
| 依赖变更检测 | `package.json` | `requirements.txt` | `go.mod` / `go.sum` |
| 镜像体积 | ~500MB | ~150MB | ~10MB |
