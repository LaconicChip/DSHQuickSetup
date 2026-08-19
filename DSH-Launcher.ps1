# ============================================================================
#  DSH Quick Launch — 一键启动 DeepSeek Harness Web GUI
#
#  功能：
#    1. 检查 http://127.0.0.1:3080 是否已在运行
#    2. 若未运行，自动执行启动命令：
#         npx -y @deepseek-ai/dsh web      ← 默认，每次启动自动更新到最新版
#       （可加 -PreferGlobal 改用已全局安装的 dsh web：更快、可离线，但版本固定）
#    3. 在默认浏览器中打开 GUI
#
#  用法： 双击桌面快捷方式 / start.bat，或在 PowerShell 中执行本脚本
#         可选参数：
#           -TimeoutS <秒>     等待服务器启动的最长时间，默认 600 秒
#           -PreferGlobal      优先使用全局安装的 dsh（不自动更新，离线可用）
# ============================================================================
param(
    [int]$TimeoutS = 600,      # 秒；首次 npx 下载可能较慢，默认给足 10 分钟
    [switch]$PreferGlobal      # 优先全局 dsh web（版本固定），默认用 npx 自动更新
)

$ErrorActionPreference = 'Stop'

$AppName = 'DeepSeek Harness'
$GuiUrl = 'http://127.0.0.1:3080'
$Port   = 3080

# ----------------------------------------------------------------------------
# 检查端口是否在监听（基于 TCP 连接测试，最可靠）
# ----------------------------------------------------------------------------
function Test-PortListening {
    param([int]$TargetPort)
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $task   = $client.ConnectAsync('127.0.0.1', $TargetPort)
        if ($task.Wait(1200)) { $ok = $client.Connected } else { $ok = $false }
        $client.Dispose()
        return [bool]$ok
    } catch {
        return $false
    }
}

# ----------------------------------------------------------------------------
# 定位 dsh 命令行（优先 PATH 上已全局安装的 dsh.cmd / dsh.ps1）
# ----------------------------------------------------------------------------
function Find-DshCommand {
    # 仅返回可被 cmd.exe 直接执行的形式（.cmd/.bat/.exe）。
    # 只有 dsh.ps1 时无法用于 cmd /c 启动行，返回 $null。
    foreach ($name in 'dsh.cmd', 'dsh.bat', 'dsh.exe') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

# ----------------------------------------------------------------------------
# 弹窗提示（供无控制台窗口时使用）
# ----------------------------------------------------------------------------
function Show-Message {
    param([string]$Text, [string]$Title = 'DSH 快捷启动', [string]$Kind = 'Info')
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        if ($Kind -eq 'Error') { $icon = [System.Windows.Forms.MessageBoxIcon]::Error }
        [System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
    } catch {
        Write-Host $Text
    }
}

# ============================================================================
# 主流程
# ============================================================================

# 0) 预检 Node.js（启动命令 npx @deepseek-ai/dsh web 依赖它）
if (-not (Get-Command 'node' -ErrorAction SilentlyContinue)) {
    Show-Message -Text "未检测到 Node.js。`n请先安装 Node.js (LTS)：`nhttps://nodejs.org/zh-cn/download" -Kind 'Error'
    exit 1
}

# 1) 检查 GUI 是否已运行
if (Test-PortListening -TargetPort $Port) {
    Write-Host "[DSH] GUI 已在运行：$GuiUrl"
} else {
    Write-Host "[DSH] 未检测到运行中的 GUI，正在启动 DSH Web 服务器..."

    # 构造启动命令：
    #   默认 → npx -y @deepseek-ai/dsh web：每次启动检查 registry 并自动更新到最新版
    #   （-PreferGlobal → 已全局安装的 dsh web：更快、可离线，但版本固定；
    #    无全局 dsh 或没有 npx 时自动回退）
    #   CommandType Application 只匹配 cmd.exe 可直接执行的形式（.cmd/.bat/.exe），
    #   不会误匹配仅有的 npx.ps1（cmd /c 无法执行 .ps1）
    $npx = Get-Command 'npx' -CommandType Application -ErrorAction SilentlyContinue
    $dsh = Find-DshCommand
    if (-not $PreferGlobal -and $npx) {
        $startLine = 'title DSH Web Server && npx -y @deepseek-ai/dsh web'
        Write-Host "[DSH] 使用命令：npx -y @deepseek-ai/dsh web（自动更新到最新版）"
    } elseif ($dsh) {
        $startLine = 'title DSH Web Server && "' + $dsh + '" web'
        Write-Host "[DSH] 使用命令：$dsh web（全局版本，不自动更新）"
    } elseif ($npx) {
        # -PreferGlobal 但未找到全局 dsh：回退 npx
        $startLine = 'title DSH Web Server && npx -y @deepseek-ai/dsh web'
        Write-Host "[DSH] 未找到全局 DSH，改用：npx -y @deepseek-ai/dsh web"
    } else {
        Show-Message -Text "未找到 npx 或 DSH。`n请先安装 Node.js：`nhttps://nodejs.org/zh-cn/download" -Kind 'Error'
        exit 1
    }

    # 在独立控制台窗口启动服务器（关闭该窗口即停止服务；
    # 服务停止或启动命令退出时窗口会自动关闭）
    # 固定工作目录到安装目录（不存在时回退用户目录），避免继承调用方 cwd
    $workDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) $AppName
    if (-not (Test-Path -LiteralPath $workDir)) { $workDir = $env:USERPROFILE }
    Write-Host "[DSH] 正在启动服务器，请稍候…（首次需联网下载更新 DSH 包，请勿关闭本窗口）"
    try {
        $serverProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $startLine -WorkingDirectory $workDir -PassThru
    } catch {
        Show-Message -Text ("启动 DSH web 失败：`n" + $_.Exception.Message) -Kind 'Error'
        exit 1
    }

    # 2) 等待端口就绪
    #    - 启动进程提前退出（npx 下载失败 / 命令出错）→ 立即报错，不必空等
    #    - 首次 npx 下载可能较慢，最多等待 $TimeoutS 秒（默认 600）
    #    - 每 10 秒打一个进度点，避免用户误以为卡住
    $waited = 0
    while (-not (Test-PortListening -TargetPort $Port)) {
        Start-Sleep -Seconds 1
        $waited++
        if ($serverProc.HasExited) {
            Show-Message -Text "启动命令已退出，服务器未能启动。`n请检查网络连接后重试，或查看 “DSH Web Server” 窗口中的错误信息。" -Kind 'Error'
            exit 1
        }
        if ($waited -ge $TimeoutS) {
            Show-Message -Text "服务器在 ${TimeoutS} 秒内未能启动（首次 npx 下载可能较慢）。`n可稍后重新运行启动，或查看 “DSH Web Server” 窗口中的错误信息。" -Kind 'Error'
            exit 1
        }
        if ($waited % 10 -eq 0) {
            Write-Host -NoNewline '.'
        }
    }
    Write-Host ''
    Write-Host "[DSH] 服务器已就绪（约 ${waited}s）。"
}

# 3) 在浏览器中打开 GUI
Write-Host "[DSH] 正在打开浏览器：$GuiUrl"
try {
    Start-Process $GuiUrl
} catch {
    Show-Message -Text ("打开浏览器失败：`n" + $_.Exception.Message) -Kind 'Error'
    exit 1
}

Write-Host "[DSH] 完成。"
exit 0
