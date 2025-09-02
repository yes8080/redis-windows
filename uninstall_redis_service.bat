@echo off
setlocal enabledelayedexpansion
SET REDIS_PATH=%~dp0

:: BatchGotAdmin - Enhanced version
:-------------------------------------
echo Redis Windows Service Uninstaller
echo ==================================

REM Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo Administrative privileges required...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
    pushd "%CD%"
    CD /D "%REDIS_PATH%"
:--------------------------------------

echo Checking Redis service status...

REM Check if service exists
sc.exe query "Redis" >nul 2>&1
if !errorlevel! neq 0 (
    echo Redis service is not installed
    echo Nothing to uninstall
    pause
    exit /b 0
)

echo Redis service found
echo.
echo WARNING: This will stop and remove the Redis service
echo All data in Redis will be lost unless persisted to disk
echo.
choice /M "Do you want to continue"
if !errorlevel! neq 1 (
    echo Operation cancelled
    pause
    exit /b 0
)

echo.
echo Stopping Redis service...
net stop "Redis" >nul 2>&1
if !errorlevel! equ 0 (
    echo Redis service stopped successfully
) else (
    echo Redis service was not running or failed to stop
)

echo.
echo Removing Redis service...
sc.exe delete "Redis"
if !errorlevel! equ 0 (
    echo Redis service removed successfully
    echo.
    echo The Redis service has been completely uninstalled
    echo Redis files remain in the installation directory
) else (
    echo Error: Failed to remove Redis service
    echo You may need to restart Windows and try again
    pause
    exit /b 1
)

echo.
echo Uninstallation completed successfully!
pause
exit /b 0
