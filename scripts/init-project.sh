#!/usr/bin/env bash
# init-project.sh — 项目模板初始化脚本
# 用法：bash scripts/init-project.sh                    # 交互模式
#       bash scripts/init-project.sh --name X --goal Y   # 非交互模式
#
# 非交互模式可选参数：
#   --name         项目名称（必需）
#   --goal         项目目标（必需）
#   --repo-path    代码仓库路径（可选）
#   --readonly   外部只读目录，逗号分隔（可选）
#   --install    初始化后自动安装依赖（可选）
#
# 职责：
#   1. 收集项目参数（交互或命令行）
#   2. 替换模板占位符
#   3. 输出初始化报告
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# 跨平台 sed -i 兼容（macOS 需要 sed -i ''）
sedi() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# 转义 sed 替换串中的特殊字符（/ & \）
sed_escape() {
  printf '%s' "$1" | sed 's/[\/&\\]/\\&/g'
}

# ─── 解析命令行参数 ──────────────────────────────────────
PROJECT_NAME=""
PROJECT_GOAL=""
REPO_PATH=""
READONLY_DIRS=""
AUTO_INSTALL=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       PROJECT_NAME="$2"; shift 2 ;;
    --goal)       PROJECT_GOAL="$2"; shift 2 ;;
    --repo-path)  REPO_PATH="$2"; shift 2 ;;
    --readonly)   READONLY_DIRS="$2"; shift 2 ;;
    --install)    AUTO_INSTALL=true; shift ;;
    *)            fail "未知参数: $1"; exit 1 ;;
  esac
done

# 如果 name 和 goal 都已通过命令行提供，进入非交互模式
if [[ -n "$PROJECT_NAME" && -n "$PROJECT_GOAL" ]]; then
  NON_INTERACTIVE=true
fi

echo ""

# ─── 1. 收集参数 ──────────────────────────────────────
if [[ "$NON_INTERACTIVE" == true ]]; then
  info "非交互模式（参数已通过命令行提供）"
else
  echo "╔══════════════════════════════════════════════╗"
  echo "║    多智能体协作项目模板 — 初始化向导          ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  read -rp "项目名称（英文，如 MyProject）: " PROJECT_NAME
  read -rp "项目目标（一句话描述核心目标）: " PROJECT_GOAL

  ADVANCED_CONFIG="N"
  echo ""
  read -rp "是否继续填写高级项（仓库路径、外部只读目录）？(y/N) " ADVANCED_CONFIG
  if [[ "$ADVANCED_CONFIG" == "y" || "$ADVANCED_CONFIG" == "Y" ]]; then
    read -rp "代码仓库本地路径（留空则跳过）: " REPO_PATH
    read -rp "外部只读代码目录（逗号分隔，留空则跳过）: " READONLY_DIRS
  fi
fi

if [[ -z "$PROJECT_NAME" ]]; then
  fail "项目名称不能为空"
  exit 1
fi

if [[ -z "$PROJECT_GOAL" ]]; then
  fail "项目目标不能为空"
  exit 1
fi

echo ""
info "收集到的参数："
info "  项目名称: $PROJECT_NAME"
info "  项目目标: $PROJECT_GOAL"
if [[ -n "$REPO_PATH" ]]; then
  info "  仓库路径: $REPO_PATH"
fi
if [[ -n "$READONLY_DIRS" ]]; then
  info "  只读目录: $READONLY_DIRS"
fi

if [[ "$NON_INTERACTIVE" != true ]]; then
  echo ""
  read -rp "确认以上信息？(y/N) " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    info "已取消初始化"
    exit 2  # 约定退出码 2 = 用户取消（区别于错误 exit 1 和成功 exit 0）
  fi

  echo ""
  read -rp "初始化后是否自动安装依赖？(Y/n) " INSTALL_ANSWER
  if [[ "$INSTALL_ANSWER" != "n" && "$INSTALL_ANSWER" != "N" ]]; then
    AUTO_INSTALL=true
  fi
fi

echo ""
info "开始初始化..."
echo ""

MODIFIED_FILES=()

# ─── 2. 替换 project-context.yaml ─────────────────────
CTX_FILE="$PROJECT_ROOT/.opencode/project-context.yaml"
if [[ -f "$CTX_FILE" ]]; then
  SAFE_NAME=$(sed_escape "$PROJECT_NAME")
  sedi "s|^project_name: \"\".*|project_name: \"$SAFE_NAME\"|" "$CTX_FILE"
  if [[ -n "$REPO_PATH" ]]; then
    SAFE_REPO=$(sed_escape "$REPO_PATH")
    sedi "s|^repo_path: \"\".*|repo_path: \"$SAFE_REPO\"|" "$CTX_FILE"
  fi
  MODIFIED_FILES+=("$CTX_FILE")
  ok "project-context.yaml 已更新"
fi

# ─── 3. 替换 AGENTS.md 只读目录 ───────────────────────
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
if [[ -f "$AGENTS_FILE" && -n "$READONLY_DIRS" ]]; then
  # 将逗号分隔转为 `dir/`、`dir/` 格式
  FORMATTED_DIRS=$(echo "$READONLY_DIRS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's|/*$|/|' | tr '\n' '、' | sed 's/、$//')
  SAFE_DIRS=$(sed_escape "$FORMATTED_DIRS")
  sedi "s|<!-- 在此声明只读目录，例如 \`src-ref/\` -->|\`$SAFE_DIRS\` |" "$AGENTS_FILE"
  MODIFIED_FILES+=("$AGENTS_FILE")
  ok "AGENTS.md 只读目录已更新"
else
  ok "AGENTS.md 保持默认（无只读目录）"
fi

# ─── 4. 清理运行态目录（确保干净） ───────────────────
for DIR in "$PROJECT_ROOT/.opencode/context" "$PROJECT_ROOT/.opencode/state" "$PROJECT_ROOT/.opencode/logs" "$PROJECT_ROOT/.opencode/artifacts"; do
  if [[ -d "$DIR" ]]; then
    rm -rf "$DIR"
    ok "已清理运行态目录: $DIR"
  fi
done

# ─── 5. 复制 .env.example 为 .env ─────────────────────
if [[ -f "$PROJECT_ROOT/.env.example" && ! -f "$PROJECT_ROOT/.env" ]]; then
  cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
  ok ".env 已从 .env.example 创建（请填入真实值）"
fi

# ─── 6. 安装依赖（可选） ───────────────────────────────
if [[ "$AUTO_INSTALL" == true ]]; then
  echo ""
  info "正在安装依赖..."
  bash "$SCRIPT_DIR/install-deps.sh"
  ok "依赖安装完成"
fi

# ─── 7. 输出初始化报告 ────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         初始化完成                            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
info "项目: $PROJECT_NAME"
info "已修改文件:"
for F in "${MODIFIED_FILES[@]}"; do
  echo "  - ${F#$PROJECT_ROOT/}"
done
echo ""
info "下一步操作:"
echo "  1. 编辑 .env 填入真实环境变量"
if [[ "$AUTO_INSTALL" != true ]]; then
  echo "  2. 执行 bash scripts/install-deps.sh 安装依赖"
  echo "  3. 编辑 .opencode/project-context.yaml 补充项目详细配置"
  echo "  4. 用 OpenCode 打开项目目录，开始使用多智能体协作"
else
  echo "  2. 编辑 .opencode/project-context.yaml 补充项目详细配置"
  echo "  3. 用 OpenCode 打开项目目录，开始使用多智能体协作"
fi
echo ""
ok "祝项目顺利！"
