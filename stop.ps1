# ============================================================================
#  DeepSeek Harness 停止脚本
#  作用：停止正在运行的 DSH Web 服务器
#        （监听 3080 端口、命令行含 dsh 的进程）
#
#  用法： 双击 stop.bat，或在 PowerShell 中执行本脚本
# ============================================================================
$ErrorActionPreference = 'Continue'

$AppName = 'DeepSeek Harness'
$Port    = 3080

# ---------------------------------------------------------------------------
# 查找监听指定端口的进程 PID
# 优先 Get-NetTCPConnection；不可用时回退 netstat -ano 解析
# （兼容旧系统 / 受限环境，netstat 始终可用）
# ---------------------------------------------------------------------------
function Get-PortPids {
    param([int]$TargetPort)
    $conns = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        return @($conns | ForEach-Object { [int]$_.OwningProcess } | Sort-Object -Unique)
    }
    $lines = netstat -ano 2>$null | Select-String 'LISTENING' | Select-String ":$TargetPort\s"
    return @($lines | ForEach-Object {
        $tokens = ($_ -split '\s+') | Where-Object { $_ }
        $last   = $tokens[$tokens.Count - 1]
        if ($last -match '^[1-9]\d*$') { [int]$last }   # 过滤 PID 0（系统占位，无法操作）
    } | Sort-Object -Unique)
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
$pids    = Get-PortPids $Port
$stopped = $false

foreach ($procId in $pids) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $procId" -ErrorAction SilentlyContinue
    if ($proc -and $proc.CommandLine -match 'dsh') {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Write-Host "[$AppName] 已停止服务器进程 (PID $procId)"
        $stopped = $true
    } elseif ($proc) {
        Write-Host "[$AppName] 端口 $Port 被非 DSH 进程占用 (PID $procId)，已跳过。如需释放端口请手动处理该进程。"
    } else {
        Write-Host "[$AppName] 端口 $Port 上的进程 (PID $procId) 无法读取信息，跳过（请确认是否为 dsh 服务器）"
    }
}

if ($stopped) {
    Write-Host "[$AppName] 服务器已停止。"
} else {
    Write-Host "[$AppName] 未发现运行中的 DSH Web 服务器（端口 $Port）。"
}
