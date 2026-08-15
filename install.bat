@echo off
setlocal
title DeepSeek Harness Installer
echo ============================================
echo   DeepSeek Harness - Installer
echo   (npm install -g @deepseek-ai/dsh + desktop shortcut)
echo ============================================
echo.
cd /d "%~dp0"

rem Unblock files extracted from the ZIP (Zone.Identifier) so PowerShell policy allows them
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File -ErrorAction SilentlyContinue" > nul 2>&1

echo Installing DeepSeek Harness and creating desktop shortcut...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed. See message above.
    pause
    exit /b 1
)

echo.
echo Installation complete. You can close this window.
ping 127.0.0.1 -n 6 > nul
endlocal
