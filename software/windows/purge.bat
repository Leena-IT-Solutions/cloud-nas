@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo      🗑️ Windows 1-Click Cloud NAS Purge ^& Uninstall 🗑️
echo ============================================================

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_ROOT=%%~fI"

set "CONFIG_FILE=%PROJECT_ROOT%\drive_config.json"
set "USERS_FILE=%PROJECT_ROOT%\users_permissions.json"
set "ACTIVE_USER_FILE=%PROJECT_ROOT%\active_user_mount.json"
set "RCLONE_BIN=%SCRIPT_DIR%\rclone.exe"
set "STARTUP_SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Cloud NAS Control Center.lnk"

rem 1. Unmount Drives & Terminate Processes
echo [INFO] Terminating Cloud NAS background processes...
taskkill /f /im rclone.exe >nul 2>&1
taskkill /f /im pythonw.exe >nul 2>&1

rem 2. Remove Startup Shortcut
if exist "%STARTUP_SHORTCUT%" (
    echo [INFO] Removing Windows Startup Shortcut...
    del /F /Q "%STARTUP_SHORTCUT%" >nul 2>&1
)

rem 3. Remove Remote Configuration
if exist "%RCLONE_BIN%" (
    echo [INFO] Removing GCS remote configuration...
    "%RCLONE_BIN%" config delete gcsnas >nul 2>&1
)

rem 4. Remove Configuration Files
rmdir /S /Q "%LOCALAPPDATA%\rclone" >nul 2>&1
if exist "%CONFIG_FILE%" del /F /Q "%CONFIG_FILE%" >nul 2>&1
if exist "%USERS_FILE%" del /F /Q "%USERS_FILE%" >nul 2>&1
if exist "%ACTIVE_USER_FILE%" del /F /Q "%ACTIVE_USER_FILE%" >nul 2>&1

echo ============================================================
echo [SUCCESS] Cloud NAS has been completely purged from this PC!
echo ============================================================
pause
