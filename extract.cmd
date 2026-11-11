@echo off
rem Schedule I Turkce Yama - metin cikarici (kurulum gerektirmez).
rem Cift tikla calistir. Oyun klasorunu kendi bulur; bulamazsa yolu sorar.
rem
rem Elle yol vermek istersen:
rem   extract.cmd -GameDir "C:\...\steamapps\common\Schedule I"

setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\extract_strings.ps1" -Raw %*
set RC=%ERRORLEVEL%

echo.
if not "%RC%"=="0" (
    echo Cikarma basarisiz oldu ^(kod %RC%^).
) else (
    echo Cikti klasoru: "%~dp0extracted"
)
echo.
pause
endlocal
exit /b %RC%
