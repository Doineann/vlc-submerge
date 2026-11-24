@echo off
@rem SPDX-License-Identifier: GPL-3.0-or-later
setlocal

set "SCRIPT_DIR=%~dp0"
set "SOURCE=%SCRIPT_DIR%submerge.lua"
set "ROOT=%APPDATA%\vlc"
set "TARGET=%ROOT%\lua\extensions"
set "EXTENSION=%TARGET%\submerge.lua"

echo.
echo VLC 3 - SubMerge Extension Installer
echo =====================================
echo.

if not exist "%SOURCE%" (
    echo ERROR: submerge.lua not found in installer directory.
    goto :error
)

if not exist "%ROOT%\" (
    echo ERROR: VLC data directory not found:
    echo %ROOT%
    echo.
    echo Please install VLC 3 and run VLC at least once.
    goto :error
)

if not exist "%TARGET%\" (
    mkdir "%TARGET%"
    if errorlevel 1 (
        echo ERROR: Failed to create extensions directory:
        echo %TARGET%
        goto :error
    )
)

echo Installing submerge.lua...
copy /Y "%SOURCE%" "%EXTENSION%" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy extension.
    goto :error
)

echo.
echo SUCCESS: Extension installed!
echo Location: %EXTENSION%
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
