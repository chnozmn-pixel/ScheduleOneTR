@echo off
rem GitHub zip indirenler icin: asil betik release\ klasorunde.
call "%~dp0release\GUNCELLE.cmd" %*
exit /b %ERRORLEVEL%
