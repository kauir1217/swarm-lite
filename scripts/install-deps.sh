#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ROOT_ONLY=false
OPENCODE_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --root-only)
      ROOT_ONLY=true
      ;;
    --opencode-only)
      OPENCODE_ONLY=true
      ;;
    *)
      echo "未知参数: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$ROOT_ONLY" == true && "$OPENCODE_ONLY" == true ]]; then
  echo "不能同时指定 --root-only 和 --opencode-only" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "未找到 npm，请先安装 Node.js / npm" >&2
  exit 1
fi

if [[ "$OPENCODE_ONLY" == false && -f "$PROJECT_ROOT/package.json" ]]; then
  echo "安装根目录依赖..."
  (cd "$PROJECT_ROOT" && npm install)
fi

if [[ "$ROOT_ONLY" == false && -f "$PROJECT_ROOT/.opencode/package.json" ]]; then
  echo "安装 .opencode 依赖..."
  (cd "$PROJECT_ROOT/.opencode" && npm install)
fi

echo "依赖安装完成"
