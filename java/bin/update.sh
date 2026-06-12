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

# 派生变量：Maven artifact 名默认与项目同名，必要时可通过 .env 覆盖
ARTIFACT_NAME="${ARTIFACT_NAME:-$PROJECT_NAME}"
APP_JAR="$DEPLOY_ROOT/app/$ARTIFACT_NAME.jar"

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

echo ">>> New code detected ( $OLD_COMMIT -> $NEW_COMMIT ). Starting build & deploy..."

# ---------------------------------------------------------------------------
# 构建
# ---------------------------------------------------------------------------
echo ">>> Maven clean package..."
mvn clean package

# ---------------------------------------------------------------------------
# 部署 JAR
# ---------------------------------------------------------------------------
echo ">>> Syncing jar to $APP_JAR ..."
mkdir -p "$(dirname "$APP_JAR")"
rsync -av "target/$ARTIFACT_NAME.jar" "$(dirname "$APP_JAR")/"

# ---------------------------------------------------------------------------
# 重启容器（用 docker compose 服务名 app，与 compose 文件保持一致）
# ---------------------------------------------------------------------------
echo ">>> Restarting app container..."
cd "$PROJECT_ROOT"
docker compose restart app

echo ">>> Deployment completed successfully."
