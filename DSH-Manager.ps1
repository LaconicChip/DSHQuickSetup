# ============================================================================
#  DSH Manager — DeepSeek Harness 统一管理工具（菜单 + 状态 + 子命令分发）
#
#  用法：
#    双击 DSH Manager.bat 或 `DSH Manager.bat menu`                    → 交互菜单（含状态显示）
#    DSH Manager.bat start   [-PreferGlobal] [-TimeoutS 秒]    → 启动
#    DSH Manager.bat stop                                       → 停止
#    DSH Manager.bat install [-SkipStart]                       → 安装/修复
#    DSH Manager.bat uninstall [-Force]                         → 卸载
# ============================================================================
$ErrorActionPreference = 'Continue'

$AppName    = 'DeepSeek Harness'
$GuiUrl     = 'http://127.0.0.1:3080'
$Port       = 3080
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) $AppName

# ---------------------------------------------------------------------------
# 状态检测（自带轻量 TCP 探测，与 DSH-Launcher.ps1 相同实现；
# 不 dot-source Launcher，避免触发其启动主流程）
# ---------------------------------------------------------------------------
function Test-PortListening {
    param([int]$TargetPort)
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $task   = $client.ConnectAsync('127.0.0.1', $TargetPort)
        if ($task.Wait(1200)) { $ok = $client.Connected } else { $ok = $false }
        $client.Dispose()
        return [bool]$ok
    } catch { return $false }
}

function Get-StatusLine {
    $running   = Test-PortListening -TargetPort $Port
    $installed = Test-Path -LiteralPath (Join-Path $InstallDir 'DSH-Launcher.ps1')
    $nodeOk    = [bool](Get-Command 'node' -ErrorAction SilentlyContinue)
    if ($running)       { $line = "● 运行中 ($GuiUrl)" }
    elseif ($installed) { $line = "○ 已安装，未运行" }
    else                { $line = "○ 未安装" }
    if (-not $nodeOk) { $line += "    [警告：未检测到 Node.js]" }
    return $line
}

# ---------------------------------------------------------------------------
# 带超时的"按任意键返回"：既支持立即按键返回（含回车），也支持等待超时后自动返回
# 用 [Console]::KeyAvailable 轮询实现（PS 5.1 可用），避免 Read-Host 无限阻塞
# ---------------------------------------------------------------------------
function Wait-KeyOrTimeout {
    param([int]$Seconds = 3)
    try {
        $deadline = [Environment]::TickCount + ($Seconds * 1000)
        while ([Environment]::TickCount -lt $deadline) {
            if ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
                return
            }
            Start-Sleep -Milliseconds 100
        }
    } catch {
        # 非交互环境（管道/重定向）下 KeyAvailable 不可用，退回 Read-Host
        Read-Host "按回车继续"
    }
}

function Show-Usage {
    Write-Host ""
    Write-Host "用法: DSH Manager.bat [命令] [参数]"
    Write-Host ""
    Write-Host "  （无参数）  打开交互菜单"
    Write-Host "  start       启动 DeepSeek Harness（可加 -PreferGlobal / -TimeoutS 秒）"
    Write-Host "  stop        停止服务器"
    Write-Host "  install     安装/修复（可加 -SkipStart 跳过启动询问）"
    Write-Host "  uninstall   卸载（可加 -Force 跳过确认）"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# 子命令模式（有参数：执行一次后退出；stop/uninstall 固定返回 0）
# ---------------------------------------------------------------------------
if ($args.Count -gt 0) {
    $cmd  = [string]$args[0]
    $rest = @($args | Select-Object -Skip 1)
    switch ($cmd.ToLower()) {
        'start' {
            if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'DSH-Launcher.ps1'))) {
                Write-Host "未检测到 DeepSeek Harness 安装，无法启动。"
                Write-Host "请先执行安装：DSH Manager.bat install（或菜单选择 [3] 安装/修复）。"
                exit 1
            }
            & (Join-Path $ScriptDir 'DSH-Launcher.ps1') @rest
            exit $LASTEXITCODE
        }
        'stop' {
            & (Join-Path $ScriptDir 'stop.ps1') @rest
            exit $LASTEXITCODE
        }
        'install' {
            & (Join-Path $ScriptDir 'install.ps1') @rest
            exit $LASTEXITCODE
        }
        'uninstall' {
            & (Join-Path $ScriptDir 'uninstall.ps1') @rest
            exit $LASTEXITCODE
        }
        'menu' { }
        default {
            Write-Host "未知命令: $cmd"
            Show-Usage
            exit 1
        }
    }
}

# ---------------------------------------------------------------------------
# 菜单模式（双击场景：循环显示菜单，动作完成后回车返回）
# ---------------------------------------------------------------------------
:menuLoop while ($true) {
    try { Clear-Host } catch {}
    Write-Host "===================================="
    Write-Host "  $AppName 管理工具"
    Write-Host "  状态：$(Get-StatusLine)"
    Write-Host "===================================="
    Write-Host "  [1] 启动"
    Write-Host "  [2] 停止"
    Write-Host "  [3] 安装/修复"
    Write-Host "  [4] 卸载"
    Write-Host "  [5] 退出"
    Write-Host "===================================="
    $choice = Read-Host "请输入数字以选择"
    switch ($choice) {
        '1' {
            if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'DSH-Launcher.ps1'))) {
                Write-Host "未检测到 DeepSeek Harness 安装，无法启动。"
                Write-Host "请先选择 [3] 安装/修复 后再启动。"
            } else {
                & (Join-Path $ScriptDir 'DSH-Launcher.ps1')
            }
        }
        '2' { & (Join-Path $ScriptDir 'stop.ps1') }
        '3' { & (Join-Path $ScriptDir 'install.ps1') }
        '4' { & (Join-Path $ScriptDir 'uninstall.ps1') }
        '5' { break menuLoop }
        default { Write-Host "无效选择，请输入 1-5。" }
    }
    Write-Host ""
    Write-Host "（3 秒后自动返回，或按回车立即返回菜单…）"
    Wait-KeyOrTimeout
}
exit 0
