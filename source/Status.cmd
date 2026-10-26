@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action Status %*
set "SKATE_EXIT=%errorlevel%"
pause
exit /b %SKATE_EXIT%
