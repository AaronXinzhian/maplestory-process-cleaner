@echo off
setlocal
if not exist "%~dp0Stop-MapleStory.ps1" (
    echo Missing Stop-MapleStory.ps1. Extract both files into the same folder.
    pause
    exit /b 2
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-MapleStory.ps1"
set "MapleCleanerExitCode=%errorlevel%"
echo.
pause
exit /b %MapleCleanerExitCode%
