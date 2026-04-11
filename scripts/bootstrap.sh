#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$PROJECT_ROOT/scripts/init-project.sh"
INIT_RC=$?

if [[ $INIT_RC -eq 2 ]]; then
  echo "[bootstrap] 初始化已取消，跳过依赖安装"
  exit 0
elif [[ $INIT_RC -ne 0 ]]; then
  echo "[bootstrap] init-project.sh 失败（exit $INIT_RC），已终止"
  exit 1
fi

bash "$PROJECT_ROOT/scripts/install-deps.sh"
