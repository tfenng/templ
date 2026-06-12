#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# 定位项目根并加载 .env
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
: "${SRC_FRONTEND:?SRC_FRONTEND 未在 .env 中设置}"

# 前端构建产物目录（可在 .env 中覆盖，例如 Vite 配了 outDir）
DIST_SRC="${DIST_SRC:-$SRC_FRONTEND/dist/}"
DEST_DIR="$DEPLOY_ROOT/nginx/www/"

# ---------------------------------------------------------------------------
# 拉取代码
# ---------------------------------------------------------------------------
cd "$SRC_FRONTEND"

OLD_COMMIT=$(git rev-parse HEAD)

echo ">>> Pulling latest code from origin/master..."
git pull origin master

NEW_COMMIT=$(git rev-parse HEAD)

if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
    echo ">>> No code updates. Exiting."
    exit 0
fi

echo ">>> New code detected ($OLD_COMMIT -> $NEW_COMMIT). Checking package.json changes..."

# 检测 package.json 是否在本次更新中发生变化
if git diff --name-only "$OLD_COMMIT" "$NEW_COMMIT" | grep -q "^package.json$"; then
    echo ">>> package.json changed. Running pnpm install..."
    pnpm install
else
    echo ">>> package.json unchanged. Skipping pnpm install."
fi

# ---------------------------------------------------------------------------
# 构建 + 部署
# ---------------------------------------------------------------------------
echo ">>> Building web front-end project..."
pnpm run build

echo ">>> Syncing dist/ to $DEST_DIR"
mkdir -p "$DEST_DIR"
rsync -av --progress --delete "$DIST_SRC" "$DEST_DIR"

echo ">>> Web-app deployment completed successfully."
