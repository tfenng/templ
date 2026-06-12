#!/bin/bash
set -euo pipefail  # 遇到错误、未定义变量、管道错误时退出

# ---------------------------------------------------------------------------
# 定位项目根（无论脚本被软链到哪，.env 始终在 PROJECT_ROOT 下）
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env not found at $ENV_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# 必需变量检查
: "${PROJECT_NAME:?PROJECT_NAME 未在 .env 中设置}"
: "${DEPLOY_ROOT:?DEPLOY_ROOT 未在 .env 中设置}"
: "${SRC_BACKEND:?SRC_BACKEND 未在 .env 中设置}"

APP_DIR="$DEPLOY_ROOT/app"
APP_BIN="$APP_DIR/$PROJECT_NAME"

# ---------------------------------------------------------------------------
# 拉取代码
# ---------------------------------------------------------------------------
cd "$SRC_BACKEND"

OLD_COMMIT=$(git rev-parse HEAD)

echo ">>> Pulling latest code from origin/master..."
git pull origin master

NEW_COMMIT=$(git rev-parse HEAD)

if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
    echo ">>> No new code updates. Skipping build and deploy."
    exit 0
fi

echo ">>> New code detected ($OLD_COMMIT -> $NEW_COMMIT). Starting build & deploy..."

# ---------------------------------------------------------------------------
# 构建 Go 静态二进制
# ---------------------------------------------------------------------------
echo ">>> Building static Go binary to $APP_BIN ..."
mkdir -p "$APP_DIR"
docker run --rm \
    -v "$SRC_BACKEND:/src" \
    -v "$APP_DIR:/out" \
    -w /src \
    -e CGO_ENABLED=0 \
    -e GOOS=linux \
    golang:1.22-bookworm \
    sh -c "go mod download && go build -trimpath -ldflags=\"-s -w\" -o /out/$PROJECT_NAME ."

chmod +x "$APP_BIN"

# ---------------------------------------------------------------------------
# 重启容器（用 docker compose 服务名 app，与 compose 文件保持一致）
# ---------------------------------------------------------------------------
echo ">>> Restarting app container..."
cd "$PROJECT_ROOT"
docker compose restart app

echo ">>> Deployment completed successfully."
