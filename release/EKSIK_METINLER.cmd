@echo off
title Schedule I - Ingilizce Kalan Metinleri Topla
setlocal
cd /d "%~dp0"

set "PS1=%~dp0tools\collect_missing.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\release\tools\collect_missing.ps1"
if not exist "%PS1%" (
    echo.
    echo   Betik bulunamadi: tools\collect_missing.ps1
    echo.
    pause
    exit /b 9
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
