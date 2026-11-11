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

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1" -Uninstall
set RC=%ERRORLEVEL%

echo.
echo   Kapatmak icin bir tusa bas.
pause >nul
endlocal
exit /b %RC%
