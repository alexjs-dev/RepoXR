@echo off
rem Installs RepoXR for R.E.P.O. v0.5.4 and everything it needs, see install.ps1.
rem The execution policy is only changed for this one PowerShell process.
setlocal
set "SCRIPT=%~dp0install.ps1"
if not exist "%SCRIPT%" (
    echo install.ps1 is missing. Download the whole repository, not only install.bat.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo The installation failed, see the message above.
pause
exit /b %RESULT%
