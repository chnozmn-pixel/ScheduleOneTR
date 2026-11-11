@echo off
title Schedule I - Turkce Yama Kurulumu
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1" %*
set RC=%ERRORLEVEL%

if not "%RC%"=="0" (
    echo.
    echo   Kurulum tamamlanamadi.
    echo   Yukaridaki mesaji okuyup tekrar dene.
)

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
exit /b %RC%
