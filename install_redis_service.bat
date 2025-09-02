@echo off
setlocal enabledelayedexpansion
SET REDIS_PATH=%~dp0

:: BatchGotAdmin - Enhanced version
:-------------------------------------
echo Redis Windows Service Installer
echo =================================

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

echo Checking prerequisites...

REM Check if RedisService.exe exists
if not exist "%REDIS_PATH%RedisService.exe" (
    echo Error: RedisService.exe not found in current directory
    echo Please ensure the service executable is built and present
    pause
    exit /b 1
)

echo.
echo 1. Redis installation path
echo Default: %REDIS_PATH%
echo Press Enter to use default or specify custom path:
set /p REDIS_INSTALL_PATH="Installation Path: "

echo.
echo 2. Redis configuration file path
echo Default: %REDIS_PATH%redis.conf
echo Must be absolute path. Press Enter to use default:
set /p REDIS_CONF_PATH="Configuration Path: "

REM Set defaults if not specified
if not defined REDIS_INSTALL_PATH set REDIS_INSTALL_PATH=%REDIS_PATH%
if not defined REDIS_CONF_PATH set REDIS_CONF_PATH=%REDIS_PATH%redis.conf

echo.
echo Installation Summary:
echo ---------------------
echo Installation Path: !REDIS_INSTALL_PATH!
echo Configuration Path: !REDIS_CONF_PATH!
echo Service Name: Redis
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

REM Remove existing service if it exists
sc.exe query "Redis" >nul 2>&1
if !errorlevel! equ 0 (
    echo Stopping existing Redis service...
    net stop "Redis" >nul 2>&1
    echo Removing existing Redis service...
    sc.exe delete "Redis"
    timeout /t 2 /nobreak >nul
)

REM Validate and create installation directory
if not "!REDIS_INSTALL_PATH!" == "%REDIS_PATH%" (
    call :validateInstallPath "!REDIS_INSTALL_PATH!"
    if !errorlevel! neq 0 exit /b !errorlevel!
    
    echo Copying Redis files...
    call :installRedis "!REDIS_INSTALL_PATH!"
    if !errorlevel! neq 0 exit /b !errorlevel!
)

REM Validate configuration file
call :validateConfPath "!REDIS_CONF_PATH!"
if !errorlevel! neq 0 exit /b !errorlevel!

REM Create service with appropriate command line
echo Creating Redis service...
if "!REDIS_CONF_PATH!" == "!REDIS_INSTALL_PATH!redis.conf" (
    sc.exe create "Redis" binpath="\"!REDIS_INSTALL_PATH!RedisService.exe\"" start= AUTO displayname="Redis Server"
) else (
    sc.exe create "Redis" binpath="\"!REDIS_INSTALL_PATH!RedisService.exe\" -c \"!REDIS_CONF_PATH!\"" start= AUTO displayname="Redis Server"
)

if !errorlevel! neq 0 (
    echo Error: Failed to create Redis service
    pause
    exit /b 1
)

echo Starting Redis service...
net start "Redis"

if !errorlevel! neq 0 (
    echo Warning: Service created but failed to start
    echo Check Windows Event Logs for details
    pause
    exit /b 1
)

echo.
echo Redis service installed and started successfully!
echo The service will automatically start on system boot.
echo.
pause
exit /b 0

:validateInstallPath
    set "path=%~1"
    if not exist "%path%" (
        echo Creating installation directory: %path%
        md "%path%" 2>nul
        if !errorlevel! neq 0 (
            echo Error: Failed to create installation directory
            pause
            exit /b 1
        )
    )
exit /b 0

:validateConfPath
    set "confPath=%~1"
    if not exist "%confPath%" (
        echo Warning: Configuration file does not exist: %confPath%
        echo Redis will use default configuration
        choice /M "Continue anyway"
        if !errorlevel! neq 1 exit /b 1
    )
exit /b 0

:installRedis
    set "targetPath=%~1"
    echo Copying files from %REDIS_PATH% to %targetPath%...
    xcopy "%REDIS_PATH%*" "%targetPath%" /E /I /Y /Q >nul
    if !errorlevel! neq 0 (
        echo Error: Failed to copy Redis files
        pause
        exit /b 1
    )
exit /b 0
