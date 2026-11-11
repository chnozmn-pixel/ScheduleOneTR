@echo off
title Schedule I - Turkce Yama Guncelle
setlocal
cd /d "%~dp0"

echo.
echo   Yama bastan derlenip yeniden kurulacak.
echo   Oyun guncellendikten sonra bunu calistir.
echo.
echo   Oyunun kapali oldugundan emin ol.
echo.
pause

set "PS1=%~dp0tools\install.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\tools\install.ps1"
if not exist "%PS1%" (
    echo.
    echo   Kurulum dosyasi bulunamadi: tools\install.ps1
    echo.
    pause
    exit /b 9
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Force %*
set RC=%ERRORLEVEL%

if not "%RC%"=="0" (
    echo.
    echo   Guncelleme tamamlanamadi.
    echo   Yukaridaki mesaji okuyup tekrar dene.
)

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
exit /b %RC%
