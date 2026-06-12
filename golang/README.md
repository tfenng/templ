# Golang 部署模板（占位）

> 计划中的 Golang 后端部署编排模板，参照 `../java/` 实现。
>
> **状态**：未开始

## 与 java/ 模板的差异点（待实现）

- **运行时镜像**：`gcr.io/distroless/static-debian12:nonroot` 或 `alpine` 极小镜像，无需 JDK
- **后端产物**：单个静态二进制（`go build -o app.bin`）；不再需要 Maven
- **后端挂载**：`${DEPLOY_ROOT}/app/${PROJECT_NAME}.bin` 挂载到容器 `/app/${PROJECT_NAME}`（可执行）
- **构建**：`bin/update.sh` 中 `mvn clean package` → `CGO_ENABLED=0 go build -o app.bin`
- **派生规则**：`ARTIFACT_NAME`（`bin` 后缀约定与 jar 不同）需要新增变量或重命名；可考虑 `BIN_NAME`
- **健康检查**：distroless 镜像无 shell，healthcheck 需用 `[ "CMD", "/app/xxx", "--health" ]` 形式而非 `CMD-SHELL`
- **网络/挂载**：保留 `mysql` / `redis` / `web` 三个服务；`app` 服务换为 distroless/alpine

## 占位文件

本目录为占位，等待首个 Golang 项目落地时按 java/ 的结构填充：
- `docker-compose.yml`
- `.env`
- `nginx/conf/nginx.conf`
- `bin/update.sh` / `bin/update-web.sh`
- `CLAUDE.md`
