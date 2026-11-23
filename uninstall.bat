
@echo off
@rem SPDX-License-Identifier: GPL-3.0-or-later
setlocal

set "TARGET=%APPDATA%\vlc\lua\extensions"
set "EXTENSION=%TARGET%\submerge.lua"

echo.
echo VLC 3 - SubMerge Extension Uninstaller
echo ======================================
echo.

if not exist "%TARGET%\" (
    echo ERROR: VLC extensions directory not found:
    echo %TARGET%
    goto :error
)

if not exist "%EXTENSION%" (
    echo Extension is not installed.
    goto :end
)

echo Removing submerge.lua...
del /F /Q "%EXTENSION%" >nul

if errorlevel 1 (
    echo ERROR: Failed to remove extension.
    goto :error
)

echo.
echo SUCCESS: Extension uninstalled!
echo Removed: %EXTENSION%
echo.
echo Restart VLC if it is currently running.
goto :end

:error
echo.
echo Uninstall failed.
pause
exit /b 1

:end
pause
exit /b 0
