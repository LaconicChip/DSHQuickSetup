@echo off
setlocal
title DeepSeek Harness Launcher
echo ============================================
echo   DeepSeek Harness - Quick Launch
echo   (npx @deepseek-ai/dsh web -> http://127.0.0.1:3080)
echo ============================================
echo.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File -ErrorAction SilentlyContinue" > nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0DSH-Launcher.ps1"
endlocal
