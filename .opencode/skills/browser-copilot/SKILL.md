---
name: browser-copilot
description: "Use when the user says '智能体协同', '协同浏览', '观察我的浏览器', 'browser copilot', or wants the AI agent to observe and interact with their Chrome browser in real-time via CDP. Supports '智能体协同 <port>' to specify a custom CDP port (e.g. '智能体协同 9333'). Supports '智能体协同 <task>' to auto-navigate after connection (e.g. '智能体协同 打开网站', '智能体协同 打开原型'). Different sessions can use different ports for independent browser debugging."
---

# browser-copilot

## Overview

自动启动并连接用户的 Chrome 浏览器（调试模式），通过 `agent-browser --cdp` 实时观察用户的页面操作，实现人机协同浏览。

**多平台支持**：自动检测运行环境（WSL / macOS / 原生 Linux），调用对应的 Chrome 启动方式。
**多实例支持**：不同 session 可指定不同端口，各自启动独立 Chrome 实例（隔离 profile），互不干扰。

## Trigger Syntax

| 用户输入 | 行为 |
|----------|------|
| `智能体协同` | 用默认端口 19222 启动/连接 Chrome |
| `智能体协同 <port>` | 用指定端口启动/连接（如 `智能体协同 9333`） |
| `智能体协同 <任务>` | 启动/连接 + 自动执行任务（如 `智能体协同 打开网站`） |
| `智能体协同 <port> <任务>` | 指定端口 + 自动执行任务 |
| `协同浏览` / `观察我的浏览器` / `browser copilot` | 同上，默认端口 |

> **解析规则**：纯数字 → CDP 端口号（建议 >1024）；非数字文本 → 附加任务；同时出现时数字在前。

## When to Use / NOT to Use

**Use**：需要 AI 实时看到用户在浏览器中的操作（演示、验收、协同填表、问题定位）。
**NOT**：AI 独立抓取网页数据（直接用 `agent-browser`）；不涉及观察用户浏览器的场景。

## Task Router

连接成功后，若触发短语带有附加任务，自动按关键词导航：

| 关键词 | 导航目标 |
|--------|---------|
| `打开网站` / `打开平台` | `project-context.yaml` 中 `browser_copilot.routes.platform.url`（未配则提示用户配置） |
| `打开原型` / `原型` | `docs/prototypes/` 下最新 `.html` 文件（`file:///` 协议） |
| `打开 <URL>` | 直接导航到该 URL |
| `打开 <文件路径>` | 本地 `.html` 转换为 `file:///` 打开（WSL 环境自动 `wslpath -w` 转换） |
| 其他自然语言 | 不自动导航，连接就绪后按任务内容开始执行 |

> **配置方式**：在 `project-context.yaml` 中添加：
> ```yaml
> browser_copilot:
>   routes:
>     platform:
>       url: "https://your-platform.example.com"   # 你的平台地址
> ```

## Required Workflow

### 1) 解析端口号与附加任务

```
"智能体协同"              → TARGET_PORT=19222, TASK=""
"智能体协同 9333"          → TARGET_PORT=9333,  TASK=""
"智能体协同 打开网站"       → TARGET_PORT=19222, TASK="打开网站"
"智能体协同 9333 打开原型"  → TARGET_PORT=9333,  TASK="打开原型"
```

### 2) 启动并获取连接信息

```bash
RESULT=$(bash .opencode/skills/browser-copilot/scripts/check-connection.sh $TARGET_PORT 2>&1)
echo "$RESULT"
CDP_WS=$(echo "$RESULT" | grep -oP 'CDP_WS=\K\S+' | tail -1)
CDP_PORT=$(echo "$RESULT" | grep -oP 'CDP_PORT=\K[0-9]+' | tail -1)
echo "端口: $CDP_PORT | WebSocket: $CDP_WS"
```

脚本自动完成：检查 agent-browser → 检测/启动 Chrome（多平台适配）→ 端口冲突自动切换 → 获取 WebSocket URL → 验证连接。

> **关键**：后续所有命令必须用 `$CDP_WS`（WebSocket URL），而非端口号。

**启动失败排查**：
- `未找到 powershell.exe`（WSL）→ WSL 与 Windows 互操作未开启
- `未找到 Chrome 安装` → Chrome 安装路径非标准，检查 launch-chrome.sh 路径列表
- `agent-browser not installed` → `npm i -g agent-browser`
- `连接失败` → Chrome 可能在 chrome:// 内部页面，让用户打开一个正常网页

### 3) 自动导航（若有附加任务）

若步骤 1 解析出 `TASK` 非空，按 Task Router 规则导航：

```bash
# 示例：打开平台（URL 从 project-context.yaml 读取）
agent-browser --cdp "$CDP_WS" open "$PLATFORM_URL" --json
agent-browser --cdp "$CDP_WS" wait --load networkidle --json

# 示例：打开原型（自动处理路径转换）
PROTO=$(ls -t docs/prototypes/*.html 2>/dev/null | head -1)
if [ -n "$PROTO" ]; then
  # WSL 环境需路径转换
  if grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_PATH=$(wslpath -w "$PROTO")
    FILE_URL="file:///${WIN_PATH//\\//}"
  else
    FILE_URL="file://$(realpath "$PROTO")"
  fi
  agent-browser --cdp "$CDP_WS" open "$FILE_URL" --json
fi
```

> 若 `TASK` 为空，跳过此步骤，直接进入步骤 4。

### 4) 开始协同

连接就绪后使用 Quick Reference 中的命令观察和操作页面。

### 5) 结束协同

```bash
agent-browser --cdp "$CDP_WS" close --json
```

> 只断开 agent-browser 连接，不关闭用户的 Chrome。

## Quick Reference

> `$CDP_WS` = 步骤 2 输出的 WebSocket URL（必须用引号包裹）

| 动作 | 命令 |
|------|------|
| **启动+连接** | `RESULT=$(bash .../check-connection.sh $PORT 2>&1)` |
| **捕获连接** | `CDP_WS=$(echo "$RESULT" \| grep -oP 'CDP_WS=\K\S+' \| tail -1)` |
| **页面快照** | `agent-browser --cdp "$CDP_WS" snapshot -i --json` |
| **快照摘要** | `bash .opencode/skills/browser-copilot/scripts/snap.sh "$CDP_WS"` |
| **局部快照** | `bash .../snap.sh "$CDP_WS" -s ".selector"` |
| **截图** | `agent-browser --cdp "$CDP_WS" screenshot --json` |
| **当前URL** | `agent-browser --cdp "$CDP_WS" get url --json` |
| **按角色点击** | `agent-browser --cdp "$CDP_WS" find role button click --name "文本" --exact` |
| **按文本点击** | `agent-browser --cdp "$CDP_WS" find text "文本" click --exact` |
| **按占位符填写** | `agent-browser --cdp "$CDP_WS" find placeholder "占位符" fill "值"` |
| **点击 ref** | `agent-browser --cdp "$CDP_WS" click @ref --json` |
| **填写 ref** | `agent-browser --cdp "$CDP_WS" fill @ref "text" --json` |
| **导航** | `agent-browser --cdp "$CDP_WS" open <url> --json` |
| **执行 JS** | `agent-browser --cdp "$CDP_WS" eval "js code" --json` |
| **等待文本** | `agent-browser --cdp "$CDP_WS" wait --text "目标文字" --json` |
| **等待 URL** | `agent-browser --cdp "$CDP_WS" wait --url "**/pattern" --json` |
| **等待条件** | `agent-browser --cdp "$CDP_WS" wait --fn "JS表达式" --json` |
| **等待加载** | `agent-browser --cdp "$CDP_WS" wait --load networkidle --json` |
| **断开连接** | `agent-browser --cdp "$CDP_WS" close --json` |

## Multi-Instance

不同 session 可同时运行不同端口的 Chrome 实例，每个实例完全独立（profile、cookie、登录状态）：

```
Session A: 智能体协同 9222  → profile: ChromeDebug,      端口 9222
Session B: 智能体协同 9333  → profile: ChromeDebug-9333, 端口 9333
```

## Common Mistakes

| 问题 | 原因 | 解决 |
|------|------|------|
| 自动启动失败（WSL） | WSL 互操作被禁用 | 确认 `/etc/wsl.conf` 中 `[interop]` 未设为 `enabled=false` |
| 非默认端口连不上 | 用 `--cdp <端口号>` 而非 WebSocket URL | **必须用 `--cdp "$CDP_WS"`** |
| snapshot 返回空 | 当前页面是 chrome:// 内部页面 | 导航到正常网页 |
| 操作后 ref 失效 | 页面 DOM 变化后 ref 自动失效 | 每次操作后重新 snapshot |
| 自签名 HTTPS 白屏 | 新 profile 未信任证书 | 启动参数已加 `--ignore-certificate-errors`（自动处理） |
| 第二个端口启动失败 | 同一 profile 不能多实例 | 已按端口隔离 profile（自动处理） |
| macOS Chrome 无 CDP | open -a 方式不传递调试参数 | 脚本已用直接命令行启动（自动处理） |

## Environment Notes

- **多平台**：自动检测 WSL / macOS / Linux，调用对应启动方式
- **WSL**：通过 `powershell.exe` 互操作启动 Windows Chrome
- **macOS**：直接调用 Chrome 命令行（`/Applications/Google Chrome.app/...`），后台运行
- **Linux**：检测 `google-chrome` / `chromium-browser`，后台运行
- **自签名证书**：所有平台均加 `--ignore-certificate-errors`
- **Profile 隔离**：默认端口用 `ChromeDebug`，其他端口用 `ChromeDebug-<port>`（可通过 `CHROME_DEBUG_DIR` 环境变量自定义前缀）
- **超时配置**：设置 `CDP_TIMEOUT=20` 环境变量可延长 CDP 就绪等待时间（默认 15 秒）

## Scripts

| 脚本 | 用途 |
|------|------|
| `scripts/check-connection.sh` | 自动启动 + 连接验证 + 输出 CDP_WS |
| `scripts/launch-chrome.sh` | 多平台 Chrome 启动器（WSL/macOS/Linux） |
| `scripts/snap.sh` | snapshot 摘要包装器（完整数据写文件，stdout 只输出摘要） |
