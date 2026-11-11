@echo off
title Schedule I - Turkce Yama Kaldirma
setlocal
cd /d "%~dp0"

echo.
echo   Turkce yama kaldirilacak. Oyun tekrar Ingilizce acilacak.
echo   (MelonLoader ve kaydettigin oyunlar silinmez.)
echo.
set /p ONAY="  Devam edilsin mi? (E / H): "
if /i not "%ONAY%"=="E" (
    echo.
    echo   Vazgecildi, hicbir sey degismedi.
    echo.
    pause
    exit /b 0
)

set "PS1=%~dp0tools\install.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\tools\install.ps1"
if not exist "%PS1%" (
    echo.
    echo   Kaldirma dosyasi bulunamadi: tools\install.ps1
    echo.
    pause
    exit /b 9
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Uninstall
set RC=%ERRORLEVEL%

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
exit /b %RC%
