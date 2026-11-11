@echo off
rem GitHub zip indirenler icin: asil betik release\ klasorunde.
call "%~dp0release\EKSIK_METINLER.cmd" %*
exit /b %ERRORLEVEL%
