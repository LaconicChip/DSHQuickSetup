@echo off
setlocal
title DeepSeek Harness Stop
echo ============================================
echo   DeepSeek Harness - Stop Server
echo ============================================
echo.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File -ErrorAction SilentlyContinue" > nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop.ps1"
echo.
echo Done. You can close this window.
ping 127.0.0.1 -n 6 > nul
endlocal
