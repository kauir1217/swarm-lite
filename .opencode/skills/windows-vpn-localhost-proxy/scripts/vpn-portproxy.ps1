param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('add','remove','status','test')]
  [string]$Action,

  [string]$ListenAddress = '127.0.0.1',
  [int]$ListenPort = 18000,
  [string]$ConnectAddress,
  [int]$ConnectPort,
  [string]$Path = '/',
  [switch]$UseHttps
)

$ErrorActionPreference = 'Stop'

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw '请使用管理员 PowerShell 运行此脚本。'
  }
}

function Ensure-IphlpSvc {
  $svc = Get-Service -Name iphlpsvc -ErrorAction Stop
  if ($svc.StartType -ne 'Automatic') {
    Set-Service -Name iphlpsvc -StartupType Automatic
  }
  if ($svc.Status -ne 'Running') {
    Start-Service -Name iphlpsvc
  }
}

function Run-Netsh([string[]]$args) {
  & netsh @args
  if ($LASTEXITCODE -ne 0) {
    throw "netsh 执行失败: netsh $($args -join ' ')"
  }
}

function Remove-Rule {
  param([string]$addr, [int]$port)
  & netsh interface portproxy delete v4tov4 listenaddress=$addr listenport=$port | Out-Null
}

function Add-Rule {
  param([string]$lAddr, [int]$lPort, [string]$cAddr, [int]$cPort)
  Remove-Rule -addr $lAddr -port $lPort
  Run-Netsh @('interface','portproxy','add','v4tov4',"listenaddress=$lAddr", "listenport=$lPort", "connectaddress=$cAddr", "connectport=$cPort")
}

function Show-Status {
  Write-Host '=== portproxy rules ==='
  & netsh interface portproxy show all
  if ($LASTEXITCODE -ne 0) {
    throw '读取 portproxy 规则失败。'
  }
}

function Test-Endpoint {
  param([string]$host, [int]$port, [string]$path, [bool]$https)

  Write-Host "=== Test-NetConnection ${host}:${port} ==="
  Test-NetConnection $host -Port $port | Format-List

  $scheme = if ($https) { 'https' } else { 'http' }
  $uri = "${scheme}://${host}:${port}${path}"
  Write-Host "=== Invoke-WebRequest HEAD $uri ==="
  try {
    $resp = Invoke-WebRequest -Uri $uri -Method Head -SkipCertificateCheck -TimeoutSec 10
    Write-Host "HTTP Status: $($resp.StatusCode)"
  } catch {
    Write-Warning "HTTP 检查失败: $($_.Exception.Message)"
  }
}

switch ($Action) {
  'add' {
    Assert-Admin
    Ensure-IphlpSvc
    if (-not $ConnectAddress -or -not $ConnectPort) {
      throw 'Action=add 时必须提供 -ConnectAddress 和 -ConnectPort。'
    }
    Add-Rule -lAddr $ListenAddress -lPort $ListenPort -cAddr $ConnectAddress -cPort $ConnectPort
    Write-Host "[OK] 已创建映射 ${ListenAddress}:${ListenPort} -> ${ConnectAddress}:${ConnectPort}"
    Show-Status
  }
  'remove' {
    Assert-Admin
    Ensure-IphlpSvc
    Remove-Rule -addr $ListenAddress -port $ListenPort
    Write-Host "[OK] 已移除映射 ${ListenAddress}:${ListenPort}"
    Show-Status
  }
  'status' {
    Show-Status
    if ($ListenPort) {
      Write-Host "=== Local listening test: ${ListenAddress}:${ListenPort} ==="
      Test-NetConnection $ListenAddress -Port $ListenPort | Format-List
    }
  }
  'test' {
    Test-Endpoint -host $ListenAddress -port $ListenPort -path $Path -https $UseHttps.IsPresent
  }
}
