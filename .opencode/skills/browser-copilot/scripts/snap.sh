#!/usr/bin/env bash
# snap.sh — snapshot wrapper: 完整数据写文件，stdout 只输出摘要
#
# 用法:
#   bash .opencode/skills/browser-copilot/scripts/snap.sh "$CDP_WS" [选项]
#
# 选项:
#   -i          只包含可交互元素（默认启用）
#   -c          移除空结构元素（默认启用）
#   -d <n>      限制树深度（默认不限）
#   -s <sel>    限定到 CSS 选择器范围
#   -f <file>   指定输出文件路径（默认 /tmp/snap-latest.txt）
#   --full      同时输出完整 snapshot 到 stdout（禁用摘要模式）
#
# 输出:
#   stdout → 摘要信息（元素计数、页面标题、关键元素列表）
#   文件   → 完整 snapshot 数据（默认 /tmp/snap-latest.txt）
#
# 后续查找具体 ref:
#   grep -n "button\|input\|link" /tmp/snap-latest.txt
#   Read /tmp/snap-latest.txt 按行号精确定位

set -euo pipefail

# ── 参数解析 ──────────────────────────────────────────
CDP_WS="${1:?用法: snap.sh <CDP_WS> [选项]}"
shift

SNAP_FILE="/tmp/snap-latest.txt"
SNAP_ARGS=("-i" "-c")  # 默认: 只交互元素 + compact
FULL_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)  SNAP_ARGS+=("-d" "$2"); shift 2 ;;
    -s)  SNAP_ARGS+=("-s" "$2"); shift 2 ;;
    -f)  SNAP_FILE="$2"; shift 2 ;;
    -i)  shift ;;  # 已默认启用
    -c)  shift ;;  # 已默认启用
    --full) FULL_MODE=true; shift ;;
    *)   SNAP_ARGS+=("$1"); shift ;;
  esac
done

# ── 执行 snapshot ──────────────────────────────────────
RAW=$(agent-browser --cdp "$CDP_WS" snapshot "${SNAP_ARGS[@]}" 2>&1) || {
  echo "SNAP_ERROR: snapshot 执行失败"
  echo "$RAW" > "${SNAP_FILE}.error"
  echo "$RAW" | tail -10
  echo "(完整错误已写入 ${SNAP_FILE}.error)"
  exit 1
}

# ── 写入完整数据到文件 ─────────────────────────────────
echo "$RAW" > "$SNAP_FILE"

# ── 全量模式：直接输出并退出 ──────────────────────────
if $FULL_MODE; then
  echo "$RAW"
  exit 0
fi

# ── 摘要模式：提取关键信息 ────────────────────────────

# 统计元素（使用 grep -E 代替 grep -P，兼容 macOS）
TOTAL_LINES=$(echo "$RAW" | wc -l)
REF_COUNT=$(echo "$RAW" | grep -oE '@e[0-9]+' | wc -l)
BUTTON_COUNT=$(echo "$RAW" | grep -ic 'button\|btn' || true)
INPUT_COUNT=$(echo "$RAW" | grep -ic 'input\|textbox\|combobox\|searchbox' || true)
LINK_COUNT=$(echo "$RAW" | grep -ic 'link\|href' || true)
TAB_COUNT=$(echo "$RAW" | grep -ic '\btab\b' || true)
TABLE_COUNT=$(echo "$RAW" | grep -ic 'table\|grid\|row\|cell' || true)

# 尝试提取页面标题（通常在前几行）
PAGE_TITLE=$(echo "$RAW" | head -20 | perl -ne 'print "$1\n" if /(?:heading |title |document )"(.*?)"/' | head -1 || true)
if [[ -z "$PAGE_TITLE" ]]; then
  PAGE_TITLE=$(echo "$RAW" | head -5 | grep -oE '"[^"]{3,60}"' | head -1 | tr -d '"' || true)
fi

# 提取关键可交互元素摘要（按钮名、输入框、链接 — 前 30 个）
INTERACTIVE_SUMMARY=$(echo "$RAW" | grep -E '@e[0-9]+' | grep -iE 'button|btn|link|input|textbox|combobox|tab|menuitem|checkbox|radio|switch' | head -30)

# ── 输出摘要 ──────────────────────────────────────────
echo "=== SNAP 摘要 ==="
echo "完整数据: $SNAP_FILE ($TOTAL_LINES 行)"
[[ -n "$PAGE_TITLE" ]] && echo "页面标题: $PAGE_TITLE"
echo "可交互元素: $REF_COUNT 个 (按钮:$BUTTON_COUNT 输入:$INPUT_COUNT 链接:$LINK_COUNT Tab:$TAB_COUNT 表格:$TABLE_COUNT)"
echo ""
echo "--- 关键元素 (前30) ---"
if [[ -n "$INTERACTIVE_SUMMARY" ]]; then
  echo "$INTERACTIVE_SUMMARY"
else
  echo "(无匹配的交互元素，完整数据见 $SNAP_FILE)"
fi
echo "=== END ==="
