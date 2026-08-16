# ============================================================================
#  DeepSeek Harness 安装脚本
#  作用：
#    1. 检查 Node.js / npm 环境
#    2. 安装 DeepSeek Harness (dsh)：通过 npx 预热缓存并验证可用
#       （npx @deepseek-ai/dsh web 启动时每次都会自动更新到最新版，
#        这里只做首次下载与可用性校验，不安装全局固定版本）
#    3. 复制启动器 / 图标 / 卸载脚本 / 说明到 %LOCALAPPDATA%\DeepSeek Harness
#    4. 在桌面创建 “DeepSeek Harness” 快捷方式（一键启动）
#    5. （可选）安装完成后立即启动
#
#  用法： 双击 install.bat，或在 PowerShell 中执行本脚本
#         支持参数：-SkipStart （跳过“是否立即启动”询问，供静默安装）
# ============================================================================
param(
    [switch]$SkipStart
)

$ErrorActionPreference = 'Stop'

$AppName    = 'DeepSeek Harness'
$Package    = '@deepseek-ai/dsh'
$InstallDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) $AppName
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# 弹窗提示
# ---------------------------------------------------------------------------
function Show-Message {
    param([string]$Text, [string]$Title = $AppName, [string]$Kind = 'Info')
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        if ($Kind -eq 'Error') { $icon = [System.Windows.Forms.MessageBoxIcon]::Error }
        [System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
    } catch {
        Write-Host $Text
    }
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
try {
    # 1) 检查环境：Node.js / npm
    $node = Get-Command 'node' -ErrorAction SilentlyContinue
    $npm  = Get-Command 'npm'  -ErrorAction SilentlyContinue
    if (-not $node) {
        Show-Message -Text "未检测到 Node.js。`n请先安装 Node.js (LTS)：`nhttps://nodejs.org/zh-cn/download" -Kind 'Error'
        exit 1
    }
    if (-not $npm) {
        Show-Message -Text "未检测到 npm。`n请重新安装 Node.js（安装包自带 npm）。" -Kind 'Error'
        exit 1
    }
    Write-Host "[$AppName] Node.js: $(& node --version)   npm: $(& npm --version)"

    # 2) 安装 DeepSeek Harness（npx 方式，始终最新）
    #    通过 npx 下载 / 校验包（下载到 npx 缓存）；启动时 npx 会再次检查并自动更新。
    #    成败只以 npx 退出码为准：npx 向 stderr 输出的警告（npm WARN 等）不代表失败。
    Write-Host "[$AppName] 正在通过 npx 安装 $Package （首次会自动下载到 npx 缓存）..."
    # 局部放宽 EAP：Windows PowerShell 5.1 在 EAP=Stop 时会把原生命令的 stderr
    # 输出升级为终止性 NativeCommandError，导致安装被误判失败
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & npx -y $Package --version | Out-Null
        $npxExit = $LASTEXITCODE
        # npx 缓存根：优先读 npm 实际配置（支持自定义 cache 路径），读不到回退默认位置
        $cacheRoot = Join-Path $env:LOCALAPPDATA 'npm-cache'
        $cfgCache  = & npm config get cache 2>$null
        if ($LASTEXITCODE -eq 0 -and $cfgCache) {
            $cfgCache = ([string]@($cfgCache)[0]).Trim()
            if ($cfgCache -and (Test-Path -LiteralPath $cfgCache)) { $cacheRoot = $cfgCache }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($npxExit -ne 0) {
        Show-Message -Text "DeepSeek Harness 安装失败（npx 退出码 $npxExit）。`n请检查网络连接后重试。" -Kind 'Error'
        exit 1
    }
    $npxRoot = Join-Path $cacheRoot '_npx'
    $cached  = Get-ChildItem -LiteralPath $npxRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "node_modules\$Package") } |
        Select-Object -First 1
    if (-not $cached) {
        Show-Message -Text "DeepSeek Harness 安装失败。`n未能在 npx 缓存中定位 $Package，请检查网络与 npm 缓存配置后重试。" -Kind 'Error'
        exit 1
    }
    Write-Host "[$AppName] 安装完成（npx 缓存：$($cached.Name)）。"

    # 3) 复制文件到安装目录
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    foreach ($f in 'DSH-Launcher.ps1', 'DSH-whale-official.ico', 'DSH Manager.bat', 'DSH-Manager.ps1', 'uninstall.ps1', 'README.md') {
        $src = Join-Path $ScriptDir $f
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $InstallDir -Force }
    }
    Write-Host "[$AppName] 文件已安装到: $InstallDir"

    # 4) 创建桌面快捷方式
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop "$AppName.lnk"
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath       = 'powershell.exe'
    $sc.Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $InstallDir 'DSH-Launcher.ps1') + '"'
    $sc.WorkingDirectory = $InstallDir
    $sc.IconLocation     = Join-Path $InstallDir 'DSH-whale-official.ico'
    $sc.Description      = 'One-click launch of DeepSeek Harness Web GUI (npx @deepseek-ai/dsh web -> http://127.0.0.1:3080)'
    $sc.Save()
    Write-Host "[$AppName] 桌面快捷方式已创建: $lnkPath"

    # 5) 完成提示
    Write-Host "[$AppName] 安装完成！启动命令：npx @deepseek-ai/dsh web"
    Show-Message -Text "安装完成！`n`n桌面已创建 “$AppName” 快捷方式，双击即可启动。`n`n启动命令：npx @deepseek-ai/dsh web`n安装位置：$InstallDir"

    # 6) 询问是否立即启动
    if (-not $SkipStart) {
        try {
            $ans = Read-Host "是否立即启动 DeepSeek Harness？(Y/N，默认 N)"
        } catch {
            $ans = 'n'
        }
        if ($ans -match '^[Yy]') {
            Write-Host "[$AppName] 正在启动..."
            & (Join-Path $InstallDir 'DSH-Launcher.ps1')
        }
    }
} catch {
    Show-Message -Text ("安装失败：`n" + $_.Exception.Message) -Kind 'Error'
    exit 1
}
