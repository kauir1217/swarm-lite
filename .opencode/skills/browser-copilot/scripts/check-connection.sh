#!/usr/bin/env bash
# check-connection.sh — 验证 agent-browser 能否连接用户的 Windows Chrome
#   若 Chrome 未启动，自动调用 launch-chrome.sh 启动调试模式
#   支持端口自动切换（默认端口被占用时自动换端口）
#   自动获取 WebSocket URL，确保任意端口都能正确连接
# 用法: bash check-connection.sh [CDP_PORT]
# 输出:
#   CDP_PORT=<实际端口>
#   CDP_WS=<WebSocket URL>   ← 后续 agent-browser 命令必须用这个

set -euo pipefail

PORT="${1:-19222}"
HOST="127.0.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Browser Copilot 连接检查 ==="
echo "目标: ${HOST}:${PORT}"
echo ""

# 1) 检查 agent-browser 是否安装
if ! command -v agent-browser &>/dev/null; then
  echo "[FAIL] agent-browser not installed"
  echo "  修复: npm i -g agent-browser"
  exit 1
fi
echo "[OK] agent-browser 已安装: $(agent-browser --version 2>/dev/null || echo 'unknown')"

# --- 辅助函数 ---

# 检查端口是否有有效的 Chrome CDP（返回 0=有效 CDP，1=无效）
check_cdp_valid() {
  local p="$1"
  local info
  info=$(curl -s --connect-timeout 3 "http://${HOST}:${p}/json/version" 2>/dev/null)
  # 必须包含 webSocketDebuggerUrl 才算有效 CDP
  echo "$info" | node -e "
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      try {
        const j=JSON.parse(d);
        if(j.webSocketDebuggerUrl) { process.exit(0); }
        else { process.exit(1); }
      } catch { process.exit(1); }
    });
  " 2>/dev/null
}

# 2) 检查 CDP 端点是否为有效的 Chrome CDP，否则自动启动
echo ""
echo "检查 CDP 端点..."
if ! check_cdp_valid "$PORT"; then
  # 端口无有效 CDP（可能无响应、被其他程序占用、或非 CDP 服务）
  echo "[INFO] 端口 ${PORT} 无有效 Chrome CDP，自动启动..."
  echo ""
  LAUNCH_OUTPUT=$(bash "${SCRIPT_DIR}/launch-chrome.sh" "${PORT}" 2>&1) || {
    echo "${LAUNCH_OUTPUT}"
    echo "[FAIL] 自动启动 Chrome 失败"
    exit 1
  }
  echo "${LAUNCH_OUTPUT}"

  # 从 launch-chrome.sh 输出中提取实际端口（可能因冲突切换）
  ACTUAL_PORT=$(printf '%s\n' "${LAUNCH_OUTPUT}" | grep -oP 'CDP_PORT=\K[0-9]+' | tail -1)
  if [ -n "$ACTUAL_PORT" ] && [ "$ACTUAL_PORT" != "$PORT" ]; then
    echo ""
    echo "[INFO] 端口已切换: ${PORT} → ${ACTUAL_PORT}"
    PORT="$ACTUAL_PORT"
  fi
  echo ""
fi

# 3) 获取浏览器信息和 WebSocket URL
ENDPOINT="http://${HOST}:${PORT}/json/version"
BROWSER_INFO=$(curl -s --connect-timeout 3 "${ENDPOINT}")
BROWSER_VERSION=$(echo "${BROWSER_INFO}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).Browser)}catch{console.log('unknown')}})" 2>/dev/null || echo "unknown")
CDP_WS=$(echo "${BROWSER_INFO}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const u=JSON.parse(d).webSocketDebuggerUrl;console.log(u||'')}catch{console.log('')}})" 2>/dev/null || echo "")
echo "[OK] CDP 端点可达 — ${BROWSER_VERSION}"

if [ -z "$CDP_WS" ]; then
  echo "[FAIL] 无法获取 WebSocket URL"
  echo "  /json/version 返回: ${BROWSER_INFO}"
  exit 1
fi
echo "[OK] WebSocket URL: ${CDP_WS}"

# 4) 用 WebSocket URL 验证 agent-browser 连接
echo ""
echo "测试 agent-browser 连接..."

# 先 close 清除 agent-browser 可能的旧 tab 缓存，确保干净连接
agent-browser --cdp "${CDP_WS}" close --json &>/dev/null || true
sleep 0.5

SNAP_RESULT=$(agent-browser --cdp "${CDP_WS}" get url --json 2>&1) || true

if echo "${SNAP_RESULT}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);process.exit(r.success?0:1)})" 2>/dev/null; then
  CURRENT_URL=$(echo "${SNAP_RESULT}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).data.url))" 2>/dev/null)
  echo "[OK] agent-browser 连接成功"
  echo "  当前页面: ${CURRENT_URL}"
else
  echo "[FAIL] agent-browser 连接失败"
  echo "  输出: ${SNAP_RESULT}"
  echo "  可能原因: Chrome 在 chrome:// 内部页面，请打开一个正常网页"
  exit 1
fi

echo ""
echo "=== 连接就绪 ==="
echo "CDP_PORT=${PORT}"
echo "CDP_WS=${CDP_WS}"
echo "现在可以使用: agent-browser --cdp \"${CDP_WS}\" snapshot -i --json"
