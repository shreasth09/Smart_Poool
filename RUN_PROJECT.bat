@echo off
setlocal EnableExtensions
for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
cd /d "%PROJECT_DIR%"
node -e "require('node:sqlite')" >nul 2>&1
if errorlevel 1 goto neednode

rem Find a free local port. This avoids opening an older project that already uses 3000.
set "APP_PORT="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; foreach ($p in 3000..3010) { $listener=$null; try { $listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any,$p); $listener.Start(); $listener.Stop(); Write-Output $p; break } catch { if ($listener -ne $null) { try { $listener.Stop() } catch {} } } }"`) do if not defined APP_PORT set "APP_PORT=%%P"
if not defined APP_PORT set "APP_PORT=3011"
set "PORT=%APP_PORT%"
echo.
echo Starting Smart Delivery Pooling System on port %APP_PORT%...
start "Smart Delivery Pooling Server" cmd /k "cd /d ""%PROJECT_DIR%"" && node server\src\index.js"
timeout /t 3 /nobreak >nul
start "" "http://localhost:%APP_PORT%"
exit /b 0

:neednode
echo.
echo Smart Delivery Pooling needs Node.js version 22.5 or newer (built-in SQLite support).
echo Install Node.js 22 LTS, then double-click this file again.
echo.
pause
exit /b 1
