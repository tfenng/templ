# Python 部署模板（占位）

> 计划中的 Python 后端部署编排模板，参照 `../java/` 实现。
>
> **状态**：未开始

## 与 java/ 模板的差异点（待实现）

- **运行时镜像**：`python:3.12-slim`（或具体项目版本），无需 JDK
- **后端产物**：无 fat-jar；改用 `pip install -r requirements.txt` 或 `uv sync`，启动命令为 `gunicorn` / `uvicorn` / `python -m`
- **后端构建**：`bin/update.sh` 中 `mvn clean package` → `pip install --no-deps` 或 `uv pip install --system`
- **网络/挂载**：保留 `mysql` / `redis` / `web` 三个服务；`app` 服务换成 Python 镜像
- **派生规则**：`.env` 中 `ARTIFACT_NAME`（无意义，删除）；`DIST_SRC` 仍保留前端
- **依赖锁定**：`requirements.txt` 代替 `package.json` 检测逻辑（参考 `bin/update-web.sh` 中 `git diff` 检测）

## 占位文件

本目录为占位，等待首个 Python 项目落地时按 java/ 的结构填充：
- `docker-compose.yml`
- `.env`
- `nginx/conf/nginx.conf`
- `bin/update.sh` / `bin/update-web.sh`
- `CLAUDE.md`
