@echo off
setlocal enabledelayedexpansion

cd /d %~dp0

echo Starting Redis Server...

if not exist "redis-server.exe" (
    echo Error: redis-server.exe not found in current directory
    echo Please ensure Redis binaries are present
    pause
    exit /b 1
)

if not exist "redis.conf" (
    echo Warning: redis.conf not found, Redis will use default configuration
    echo Press any key to continue or Ctrl+C to cancel...
    pause >nul
    redis-server.exe
) else (
    echo Using configuration file: redis.conf
    redis-server.exe redis.conf
)

if !errorlevel! neq 0 (
    echo Error: Redis server failed to start (Exit code: !errorlevel!)
    echo Check the configuration file and ensure no other Redis instances are running
) else (
    echo Redis server started successfully
)

pause
