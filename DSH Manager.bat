@echo off
setlocal
title DeepSeek Harness Manager
echo ============================================
echo   DeepSeek Harness - Manager
echo   (start / stop / install / uninstall)
echo ============================================
echo.
cd /d "%~dp0"

rem Unblock files extracted from the ZIP (Zone.Identifier) so PowerShell policy allows them
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File -ErrorAction SilentlyContinue" > nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0DSH-Manager.ps1" %*
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Operation failed. See message above.
    pause
    exit /b 1
)
endlocal
