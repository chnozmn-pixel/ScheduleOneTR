@echo off
title Schedule I - Ingilizce Kalan Metinleri Topla
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\collect_missing.ps1" %*

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
