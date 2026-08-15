@echo off
setlocal
title DeepSeek Harness Uninstaller
echo ============================================
echo   DeepSeek Harness - Uninstaller
echo   (stop server + npm uninstall -g @deepseek-ai/dsh)
echo ============================================
echo.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File -ErrorAction SilentlyContinue" > nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
echo Uninstall finished. You can close this window.
ping 127.0.0.1 -n 6 > nul
endlocal
