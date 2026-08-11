@echo off
:: Windows 1-Click Cloud NAS Purge & Uninstall Script

set SCRIPT_DIR=%~dp0
set DRIVE_LETTER=Y:
set RCLONE_BIN=C:\rclone\rclone.exe

if not exist "%RCLONE_BIN%" (
    if exist "%SCRIPT_DIR%rclone.exe" (
        set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
    ) else (
        set RCLONE_BIN=rclone.exe
    )
)

echo ============================================================
echo       🗑️ Windows 1-Click Cloud NAS Purge & Uninstall 🗑️
echo ============================================================

:: 1. Terminate Rclone Background Process & Unmount Drive
echo [INFO] Stopping Rclone background processes and unmounting %DRIVE_LETTER% Drive...
taskkill /F /IM rclone.exe >nul 2>&1

:: 2. Remove Rclone Config Remote
echo [INFO] Removing GCS remote configuration...
"%RCLONE_BIN%" config create gcsnas googlecloudstorage service_account_file "" >nul 2>&1
"%RCLONE_BIN%" config delete gcsnas >nul 2>&1

:: 3. Remove Startup Shortcuts & Start Menu Launcher
set STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set STARTMENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs

if exist "%STARTUP_DIR%\CloudNAS-AutoMount.vbs" (
    echo [INFO] Removing startup auto-mount script...
    del /f /q "%STARTUP_DIR%\CloudNAS-AutoMount.vbs" >nul 2>&1
)

if exist "%STARTMENU_DIR%\Cloud NAS.lnk" (
    echo [INFO] Removing Cloud NAS from Windows Start Menu...
    del /f /q "%STARTMENU_DIR%\Cloud NAS.lnk" >nul 2>&1
)

echo ============================================================
echo [SUCCESS] Cloud NAS has been completely purged from Windows!
echo ============================================================
pause
