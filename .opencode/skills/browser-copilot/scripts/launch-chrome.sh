#!/usr/bin/env bash
# launch-chrome.sh — 自动启动 Chrome 调试模式（多平台支持）
# 支持 WSL（Windows Chrome）、macOS、原生 Linux
# 用法: bash launch-chrome.sh [CDP_PORT]
# 环境变量:
#   CDP_TIMEOUT       — 等待 CDP 就绪的超时秒数（默认 15）
#   CHROME_DEBUG_DIR  — Chrome 调试 profile 目录名前缀（默认 ChromeDebug）
# 输出: 成功时输出 CDP_PORT=<实际使用的端口>

set -euo pipefail

REQUESTED_PORT="${1:-19222}"
HOST="127.0.0.1"
CDP_TIMEOUT="${CDP_TIMEOUT:-15}"
CHROME_DEBUG_DIR="${CHROME_DEBUG_DIR:-ChromeDebug}"

# 候选端口列表（从请求端口开始，依次 +1/+2/+3）
CANDIDATE_PORTS=("${REQUESTED_PORT}" "$((REQUESTED_PORT + 1))" "$((REQUESTED_PORT + 2))" "$((REQUESTED_PORT + 3))")

# ── 平台检测 ──────────────────────────────────────────

detect_platform() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "linux"
  fi
}

PLATFORM="$(detect_platform)"

# ── 用户数据目录（按平台 + 端口隔离 profile）────────────

get_user_data_base() {
  case "$PLATFORM" in
    wsl)
      local profile
      profile=$(powershell.exe -NoProfile -Command 'Write-Output $env:USERPROFILE' 2>/dev/null | tr -d '\r\n')
      if [[ -z "$profile" ]]; then
        echo "[FAIL] 无法获取 Windows USERPROFILE" >&2
        return 1
      fi
      echo "${profile}\\${CHROME_DEBUG_DIR}" ;;
    macos)
      echo "$HOME/${CHROME_DEBUG_DIR}" ;;
    linux)
      echo "$HOME/.${CHROME_DEBUG_DIR,,}" ;;  # 小写
  esac
}

USER_DATA_BASE="$(get_user_data_base)"

# ── Chrome 路径检测 ──────────────────────────────────────

find_chrome() {
  case "$PLATFORM" in
    wsl)
      local paths=(
        'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
        'C:\Program Files\Google\Chrome\Application\chrome.exe'
      )
      # 尝试从 LOCALAPPDATA 获取用户安装路径
      local localappdata
      localappdata=$(powershell.exe -NoProfile -Command 'Write-Output $env:LOCALAPPDATA' 2>/dev/null | tr -d '\r\n')
      if [[ -n "$localappdata" ]]; then
        paths+=("${localappdata}\\Google\\Chrome\\Application\\chrome.exe")
      fi
      for p in "${paths[@]}"; do
        local wsl_path
        wsl_path=$(echo "$p" | sed 's|\\|/|g; s|C:|/mnt/c|; s|D:|/mnt/d|')
        if [[ -f "$wsl_path" ]]; then
          echo "$p"
          return 0
        fi
      done
      ;;
    macos)
      local paths=(
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      )
      for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
          echo "$p"
          return 0
        fi
      done
      ;;
    linux)
      local cmds=("google-chrome" "google-chrome-stable" "chromium-browser" "chromium")
      for cmd in "${cmds[@]}"; do
        if command -v "$cmd" &>/dev/null; then
          echo "$cmd"
          return 0
        fi
      done
      ;;
  esac
  return 1
}

# ── 端口检测 ──────────────────────────────────────────

check_cdp_alive() {
  local p="$1"
  curl -s --connect-timeout 2 "http://${HOST}:${p}/json/version" &>/dev/null
}

check_port_busy() {
  local p="$1"
  case "$PLATFORM" in
    wsl)
      if command -v powershell.exe &>/dev/null; then
        local result
        result=$(powershell.exe -NoProfile -Command "
          \$c = Get-NetTCPConnection -LocalPort ${p} -ErrorAction SilentlyContinue | Select-Object -First 1
          if (\$c) { Write-Output 'BUSY' } else { Write-Output 'FREE' }
        " 2>/dev/null | tr -d '\r\n')
        [[ "$result" == "BUSY" ]] && return 0 || return 1
      fi
      ;;
    macos|linux)
      if command -v lsof &>/dev/null; then
        lsof -iTCP:"${p}" -sTCP:LISTEN &>/dev/null && return 0
      elif command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":${p} " && return 0
      elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":${p} " && return 0
      fi
      ;;
  esac
  return 1
}

# ── 启动 Chrome ──────────────────────────────────────────

launch_chrome() {
  local chrome_exe="$1"
  local port="$2"
  local user_data_dir="$3"

  local common_args=(
    "--remote-debugging-port=${port}"
    "--user-data-dir=${user_data_dir}"
    "--no-first-run"
    "--remote-allow-origins=*"
    "--ignore-certificate-errors"
  )

  case "$PLATFORM" in
    wsl)
      # 通过 powershell.exe 后台启动 Windows Chrome
      local args_str
      args_str=$(printf "'%s'," "${common_args[@]}")
      args_str="${args_str%,}"  # 去尾逗号
      powershell.exe -NoProfile -Command "Start-Process '${chrome_exe}' -ArgumentList ${args_str}" &>/dev/null
      ;;
    macos)
      "$chrome_exe" "${common_args[@]}" &>/dev/null &
      disown 2>/dev/null || true
      ;;
    linux)
      "$chrome_exe" "${common_args[@]}" &>/dev/null &
      disown 2>/dev/null || true
      ;;
  esac
}

# ── 主逻辑 ──────────────────────────────────────────────

echo "=== Chrome Launcher (${PLATFORM}) ==="

# 1) 在候选端口中找到可用端口
PORT=""
for candidate in "${CANDIDATE_PORTS[@]}"; do
  # 1a) 如果已有 Chrome CDP 在此端口运行 → 直接复用
  if check_cdp_alive "$candidate"; then
    echo "[OK] Chrome 调试模式已在端口 ${candidate} 运行，无需重复启动"
    echo "CDP_PORT=${candidate}"
    exit 0
  fi

  # 1b) 检查端口是否被其他程序占用
  if check_port_busy "$candidate"; then
    echo "[WARN] 端口 ${candidate} 已被其他程序占用，尝试下一个..."
    continue
  fi

  # 1c) 端口空闲，可以使用
  PORT="$candidate"
  break
done

if [[ -z "$PORT" ]]; then
  echo "[FAIL] 所有候选端口均被占用: ${CANDIDATE_PORTS[*]}"
  echo "  请手动释放端口或指定其他端口: bash launch-chrome.sh <port>"
  exit 1
fi

if [[ "$PORT" != "$REQUESTED_PORT" ]]; then
  echo "[INFO] 默认端口 ${REQUESTED_PORT} 被占用，改用端口 ${PORT}"
fi

# 2) 检测平台特有前置条件
case "$PLATFORM" in
  wsl)
    if ! command -v powershell.exe &>/dev/null; then
      echo "[FAIL] 未找到 powershell.exe，无法从 WSL 启动 Windows Chrome"
      echo "  请确认 WSL 与 Windows 互操作已开启"
      exit 1
    fi
    ;;
esac

# 3) 检测 Chrome 安装
CHROME_EXE=""
CHROME_EXE=$(find_chrome) || {
  echo "[FAIL] 未找到 Chrome 安装（平台: ${PLATFORM}）"
  case "$PLATFORM" in
    wsl)   echo "  已检查: Program Files (x86)/(x64), LOCALAPPDATA" ;;
    macos) echo "  已检查: /Applications, ~/Applications" ;;
    linux) echo "  已检查: google-chrome, google-chrome-stable, chromium-browser, chromium" ;;
  esac
  exit 1
}

# 4) 按端口生成隔离的 user-data-dir
if [[ "$PORT" == "19222" ]]; then
  USER_DATA_DIR="${USER_DATA_BASE}"
else
  USER_DATA_DIR="${USER_DATA_BASE}-${PORT}"
fi

echo "启动 Chrome 调试模式..."
echo "  路径: ${CHROME_EXE}"
echo "  端口: ${PORT}"
echo "  Profile: ${USER_DATA_DIR}"

# 5) 启动 Chrome
launch_chrome "$CHROME_EXE" "$PORT" "$USER_DATA_DIR"

# 6) 等待 CDP 端点就绪
ENDPOINT="http://${HOST}:${PORT}/json/version"
WAIT_LOOPS=$(( CDP_TIMEOUT * 2 ))  # 每次等 0.5 秒
echo -n "等待 CDP 端点就绪"
for i in $(seq 1 "$WAIT_LOOPS"); do
  sleep 0.5
  if curl -s --connect-timeout 1 "${ENDPOINT}" &>/dev/null; then
    echo ""
    echo "[OK] Chrome 调试模式已启动，端口 ${PORT}"
    echo "CDP_PORT=${PORT}"
    exit 0
  fi
  echo -n "."
done

echo ""
echo "[FAIL] Chrome 已启动但 CDP 端点未在 ${CDP_TIMEOUT} 秒内就绪"
echo "  请检查端口 ${PORT} 是否被占用，或手动验证 Chrome 是否正常运行"
exit 1
