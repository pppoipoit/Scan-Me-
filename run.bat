@echo off
title Scan Me! - Next-Gen File Scanner
cd /d "%~dp0"
echo Launching Scan Me! GUI...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\gui\MainWindow.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] An issue occurred while launching the application.
    pause
)
