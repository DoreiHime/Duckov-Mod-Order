@echo off
chcp 65001 >nul
echo Restoring the latest mod-order backup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-DuckovModOrder.ps1" -Restore
echo.
pause
