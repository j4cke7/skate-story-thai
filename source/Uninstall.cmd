@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action Uninstall %*
set "SKATE_EXIT=%errorlevel%"
if not "%SKATE_EXIT%"=="0" pause
exit /b %SKATE_EXIT%
