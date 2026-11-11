@echo off
title Schedule I - Turkce Yama Kurulumu
setlocal
cd /d "%~dp0"

rem Hazir pakette betik tools\ icinde; depo klasorunden calistirilinca
rem bir ust klasorun tools\ klasorunde.
set "PS1=%~dp0tools\install.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\tools\install.ps1"
if not exist "%PS1%" (
    echo.
    echo   Kurulum dosyasi bulunamadi: tools\install.ps1
    echo   Zip'i actiysan: sag tik - Tumunu ayikla ile tekrar ac,
    echo   zip'in icinden dogrudan calistirma.
    echo.
    echo   Kapatmak icin bir tusa bas.
    pause >nul
    exit /b 9
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
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
