# ============================================================================
#  DeepSeek Harness 卸载脚本
#  作用：
#    1. 停止正在运行的 DSH Web 服务器（端口 3080）
#    2. 清理 dsh 相关安装产物：npx 缓存条目 + 旧版全局包（若存在）
#    3. 删除桌面快捷方式 “DeepSeek Harness”
#    4. 删除安装目录 %LOCALAPPDATA%\DeepSeek Harness
#    5. 清理 npx 缓存中的 dsh 条目（尽力而为；卸载开始时正被进程占用的条目会跳过）
#
#  用法： 双击 uninstall.bat，或在 PowerShell 中执行本脚本
#         支持参数：-Force （跳过确认询问，供静默卸载）
# ============================================================================
param(
    [switch]$Force
)

$ErrorActionPreference = 'Continue'

$AppName    = 'DeepSeek Harness'
$Package    = '@deepseek-ai/dsh'
$InstallDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) $AppName

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
Write-Host "[$AppName] 开始卸载..."

# 0) 确认（除非 -Force）
if (-not $Force) {
    try {
        $ans = Read-Host "将停止服务器、卸载 dsh（清理 npx 缓存与旧版全局包）并删除全部文件。`n确定继续吗？(Y/N)"
    } catch {
        $ans = 'n'
    }
    if ($ans -notmatch '^[Yy]') {
        Write-Host "[$AppName] 已取消卸载。"
        exit 0
    }
}

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
        if ($last -match '^\d+$') { [int]$last }
    } | Sort-Object -Unique)
}

# 0.5) 在停服之前捕获“正在被进程占用的 npx 缓存目录”。
#      必须在停服前捕获：第 1 步会杀掉 dsh 服务器，若服务器正从 npx 缓存运行，
#      停服后实时占用检测就会失效，导致误删正在使用的 harness 运行环境。
$npxRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
$inUseCacheDirs = @()
if (Test-Path -LiteralPath $npxRoot) {
    $inUseCacheDirs = @(Get-ChildItem -LiteralPath $npxRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $dirPath = $_.FullName
        $used = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.ExecutablePath -and $_.ExecutablePath -like "$dirPath*") -or
                ($_.CommandLine -and $_.CommandLine.IndexOf($dirPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
            }
        if ($used) { $dirPath }
    })
}

# 1) 停止服务器（端口 3080，命令行含 dsh 的进程）
$pids = Get-PortPids 3080
foreach ($procId in $pids) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $procId" -ErrorAction SilentlyContinue
    if ($proc -and $proc.CommandLine -match 'dsh') {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Write-Host "[$AppName] 已停止服务器进程 (PID $procId)"
    } elseif (-not $proc) {
        Write-Host "[$AppName] 端口 3080 上的进程 (PID $procId) 无法读取信息，跳过（请确认是否为 dsh 服务器）"
    }
}

# 2) 卸载 npm 全局包（兼容旧版本：新版安装不产生全局包，若仍存在则一并卸载）
Write-Host "[$AppName] 卸载 npm 全局包（若存在）: npm uninstall -g $Package"
& npm uninstall -g $Package 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[$AppName] 警告：npm 卸载返回非零退出码（未全局安装，可忽略）。"
}

# 3) 删除桌面快捷方式
$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop "$AppName.lnk"
if (Test-Path -LiteralPath $lnkPath) {
    Remove-Item -LiteralPath $lnkPath -Force
    Write-Host "[$AppName] 已删除桌面快捷方式: $lnkPath"
} else {
    Write-Host "[$AppName] 桌面快捷方式不存在，跳过"
}

# 4) 删除安装目录
if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $InstallDir) {
        Write-Host "[$AppName] 警告：部分文件未能删除（可能被占用），请稍后手动删除: $InstallDir"
    } else {
        Write-Host "[$AppName] 已删除安装目录: $InstallDir"
    }
} else {
    Write-Host "[$AppName] 安装目录不存在，跳过"
}

# 5) 清理 npx 缓存中的 dsh 条目（尽力而为；
#    卸载开始时正被进程占用的条目跳过，避免破坏正在运行的 dsh）
if (Test-Path -LiteralPath $npxRoot) {
    Get-ChildItem -LiteralPath $npxRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $pkgPath = Join-Path $_.FullName "node_modules\$Package"
        if (-not (Test-Path -LiteralPath $pkgPath)) { return }
        if ($inUseCacheDirs -contains $_.FullName) {
            Write-Host "[$AppName] 跳过清理 npx 缓存条目 $($_.Name)（卸载开始时正在被进程使用，避免破坏运行中的 dsh）。"
            return
        }
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[$AppName] 已清理 npx 缓存条目: $($_.Name)"
    }
}

# 6) 完成提示
Write-Host "[$AppName] 卸载完成。"
Show-Message -Text "卸载完成！`n`n已停止服务器、删除快捷方式与安装文件，并清理 npx 缓存中的 dsh。"
