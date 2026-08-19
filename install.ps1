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
        Show-Message -Text "未检测到 npm。`n请重新安装 Node.js (LTS)：`nhttps://nodejs.org/zh-cn/download" -Kind 'Error'
        exit 1
    }
    Write-Host "[$AppName] Node.js: $(& node --version)   npm: $(& npm --version)"

    # 2) 安装 DeepSeek Harness（npx 方式，始终最新）
    #    通过 npx 下载 / 校验包（下载到 npx 缓存）；启动时 npx 会再次检查并自动更新。
    #    成败只以 npx 退出码为准：npx 向 stderr 输出的警告（npm WARN 等）不代表失败。
    Write-Host "[$AppName] Downloading $Package ..."
    # 局部放宽 EAP：Windows PowerShell 5.1 在 EAP=Stop 时会把原生命令的 stderr
    # 输出升级为终止性 NativeCommandError，导致安装被误判失败
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $npxTimeout = $false
    try {
        # 后台执行 npx 并轮询进度，避免长时间无输出被误认为卡住。
        # 注：不用 Start-Process（重定向场景下其 PassThru 对象读不到 ExitCode，
        #     为 Windows PowerShell 5.1 已知问题），改用 .NET Process。
        $npxCmd = @(Get-Command 'npx' -CommandType Application -ErrorAction SilentlyContinue)[0].Source
        if (-not $npxCmd) { throw '未找到 npx 命令，请重新安装 Node.js。' }
        $npxPsi = New-Object System.Diagnostics.ProcessStartInfo
        $npxPsi.FileName               = $npxCmd
        $npxPsi.Arguments              = "-y $Package --version"
        $npxPsi.UseShellExecute        = $false
        $npxPsi.RedirectStandardOutput = $true
        $npxPsi.RedirectStandardError  = $true
        $npxPsi.CreateNoWindow         = $true
        $p = [System.Diagnostics.Process]::Start($npxPsi)
        # 异步排空输出流，防止子进程因管道写满而阻塞（保留 Task 引用）
        $oTask = $p.StandardOutput.ReadToEndAsync()
        $eTask = $p.StandardError.ReadToEndAsync()
        $total = 0
        while (-not $p.WaitForExit(2000)) {
            $total += 2
            # 每 10 秒打一个进度点，避免长时间无输出被误认为卡住
            if ($total % 10 -eq 0) {
                Write-Host -NoNewline '.'
            }
            # 硬超时保护：超过 10 分钟仍未完成，终止并报错（网络可能已断开）
            if ($total -ge 600) {
                $npxTimeout = $true
                # taskkill /T 连同子进程（node 等）一并终止，避免孤儿进程继续占用网络
                $null = & "$env:windir\System32\taskkill.exe" /PID $p.Id /T /F 2>$null
                if (-not $p.HasExited) { try { $p.Kill() } catch {} }
                break
            }
        }
        Write-Host ''
        if ($npxTimeout) { $npxExit = 1 } else { $npxExit = $p.ExitCode }
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
    if ($npxTimeout) {
        Show-Message -Text "DeepSeek Harness 安装超时。`n请检查网络连接后重试；若网络正常，重新运行安装可续传/复用已下载缓存。" -Kind 'Error'
        exit 1
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

    # 3) 复制文件到安装目录，并维护一份干净备份（_dsh_backup），
    #    供“安装/修复”真正恢复被损坏的文件。
    #    关键：当从安装目录内运行本脚本时（src==dst），源即目标，
    #    无法自修复，因此改用备份中的干净副本覆盖已损坏文件。
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $backupDir = Join-Path $InstallDir '_dsh_backup'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $files = 'DSH-Launcher.ps1', 'DSH-whale-official.ico', 'DSH Manager.bat', 'DSH-Manager.ps1', 'install.ps1', 'stop.ps1', 'uninstall.ps1', 'README.md'
    foreach ($f in $files) {
        $src = Join-Path $ScriptDir $f
        $dst = Join-Path $InstallDir $f
        $bak = Join-Path $backupDir $f
        $isSelf = [string]::Equals($src, $dst, [System.StringComparison]::OrdinalIgnoreCase)
        if ($isSelf) {
            # 从安装目录运行（修复模式）：源即目标，无法自修复；
            # 用备份覆盖被损坏的文件。install.ps1 自身正在执行，跳过其自覆盖。
            if ($f -ne 'install.ps1' -and (Test-Path -LiteralPath $bak)) {
                Copy-Item -LiteralPath $bak -Destination $dst -Force
                Write-Host "[$AppName] 已从备份恢复: $f"
            }
        }
        elseif (Test-Path -LiteralPath $src) {
            # 常规安装/修复（从发行包所在目录运行）：源为干净副本，
            # 覆盖安装目录，并同步刷新备份。
            Copy-Item -LiteralPath $src -Destination $InstallDir -Force
            Copy-Item -LiteralPath $src -Destination $backupDir -Force
            Write-Host "[$AppName] 已写入: $f"
        }
        elseif (Test-Path -LiteralPath $bak) {
            # 源缺失时回退备份（容错性兜底）
            Copy-Item -LiteralPath $bak -Destination $dst -Force
            Write-Host "[$AppName] 已从备份恢复（源缺失）: $f"
        }
    }
    Write-Host "[$AppName] 文件与修复备份已就绪: $InstallDir"

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
    Show-Message -Text "安装完成！`n`n已创建桌面快捷方式 “$AppName” 。`n`n启动命令：npx @deepseek-ai/dsh web`n安装位置：$InstallDir"

    # 6) 询问是否立即启动
    if (-not $SkipStart) {
        try {
            $ans = Read-Host "是否立即启动 DeepSeek Harness？(Y/N)"
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
exit 0
