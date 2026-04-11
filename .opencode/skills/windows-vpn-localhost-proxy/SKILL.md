---
name: windows-vpn-localhost-proxy
description: Use when a target URL is only reachable through Windows VPN and you need a temporary localhost TCP mapping for WSL, browser automation, or agent tools.
---

# windows-vpn-localhost-proxy

## Overview
将“仅 Windows VPN 可访问”的目标地址，临时映射到本机 `localhost` 端口，供 WSL / agent-browser / CLI 工具访问。

默认采用 `netsh interface portproxy`（Windows 原生命令，TCP 转发）。

## Trigger Phrases
- `做端口映射`
- `创建 portproxy`
- `把某个地址映射到 localhost`
- `创建本地端口转发`

## When to Use
- 用户**明确要求**创建端口映射/转发
- 需要给某个工具一个固定的 localhost 入口
- **不要**在常规内网访问时自动触发（仅用于 VPN 内网地址映射）

## Required Workflow

### 1) 先确认前提
1. 在 **Windows（管理员 PowerShell）** 验证目标端口可达：
   ```powershell
   Test-NetConnection <connectAddress> -Port <connectPort>
   ```
2. 若目标不可达，先修复 VPN/网络策略，不要继续映射。

### 2) 新增映射（add）
```powershell
powershell -ExecutionPolicy Bypass -File ".opencode/skills/windows-vpn-localhost-proxy/scripts/vpn-portproxy.ps1" \
  -Action add \
  -ListenAddress 127.0.0.1 \
  -ListenPort 18000 \
  -ConnectAddress 172.20.4.185 \
  -ConnectPort 8000
```

### 3) 查看状态（status）
```powershell
powershell -ExecutionPolicy Bypass -File ".opencode/skills/windows-vpn-localhost-proxy/scripts/vpn-portproxy.ps1" \
  -Action status \
  -ListenPort 18000
```

### 4) 验证访问（test）
```powershell
powershell -ExecutionPolicy Bypass -File ".opencode/skills/windows-vpn-localhost-proxy/scripts/vpn-portproxy.ps1" \
  -Action test \
  -ListenAddress 127.0.0.1 \
  -ListenPort 18000 \
  -Path /login \
  -UseHttps
```

### 5) 使用完成后移除（remove）
```powershell
powershell -ExecutionPolicy Bypass -File ".opencode/skills/windows-vpn-localhost-proxy/scripts/vpn-portproxy.ps1" \
  -Action remove \
  -ListenAddress 127.0.0.1 \
  -ListenPort 18000
```

## Parameters
- `ListenAddress`：监听地址，默认 `127.0.0.1`
- `ListenPort`：本地监听端口（如 `18000`）
- `ConnectAddress`：VPN 内网目标地址（如 `172.20.4.185`）
- `ConnectPort`：目标端口（如 `8000`）
- `Path`：测试路径（默认 `/`）
- `UseHttps`：测试时是否按 HTTPS 请求

## Common Mistakes
- 未使用管理员 PowerShell，导致 `netsh` 写规则失败
- 目标本身不可达却继续排查映射
- 忘记清理规则，造成后续端口冲突
- 用 HTTPS 映射到 localhost 时忽略证书域名不匹配（测试可用 `-k`）

## Notes
- `portproxy` 仅转发 TCP。
- 依赖服务：`iphlpsvc`（脚本会自动拉起）。
- 如需给 WSL 通过 Windows 网卡 IP 访问，可把 `ListenAddress` 改为 `0.0.0.0`。
