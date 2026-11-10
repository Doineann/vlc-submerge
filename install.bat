
@echo off
@rem SPDX-License-Identifier: GPL-3.0-or-later
setlocal

set "SCRIPT_DIR=%~dp0"
set "SOURCE=%SCRIPT_DIR%submerge.lua"
set "TARGET=%APPDATA%\vlc\lua\extensions"

echo.
echo VLC 3 - Submerge Extension Installer
echo =====================================
echo.

if not exist "%SOURCE%" (
    echo ERROR: submerge.lua not found in installer directory.
    goto :error
)

if not exist "%TARGET%\" (
    echo ERROR: VLC extensions directory not found:
    echo %TARGET%
    echo.
    echo Please install VLC 3 and run VLC at least once.
    goto :error
)

echo Installing submerge.lua...
copy /Y "%SOURCE%" "%TARGET%\submerge.lua" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy extension.
    goto :error
)

echo.
echo SUCCESS: Extension installed!
echo Location: %TARGET%\submerge.lua
echo.
echo Restart VLC to load the extension.
goto :end

:error
echo.
echo Installation failed.
pause
exit /b 1

:end
pause
exit /b 0
