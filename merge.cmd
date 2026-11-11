@echo off
rem Schedule I Turkce Yama - oyundan toplanan yeni metinleri ceviriye ekler.
rem Kurulum gerektirmez. Cift tikla calistir.
rem
rem Once ne olacagini gormek istersen:
rem   merge.cmd -DryRun

setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\merge_export.ps1" %*
set RC=%ERRORLEVEL%

echo.
if not "%RC%"=="0" echo Birlestirme basarisiz oldu ^(kod %RC%^).
echo.
pause
endlocal
exit /b %RC%
