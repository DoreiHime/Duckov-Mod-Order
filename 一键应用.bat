@echo off
chcp 65001 >nul
echo Applying Duckov mod order...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-DuckovModOrder.ps1" %*
echo.
pause
