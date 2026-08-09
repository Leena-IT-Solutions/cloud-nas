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
"%RCLONE_BIN%" config delete gcsnas >nul 2>&1

:: 3. Remove Startup Shortcuts
set STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
if exist "%STARTUP_DIR%\windows-mount-hidden.vbs" (
    echo [INFO] Removing startup auto-mount script...
    del /f /q "%STARTUP_DIR%\windows-mount-hidden.vbs" >nul 2>&1
)

echo ============================================================
echo [SUCCESS] Cloud NAS has been completely purged from Windows!
echo ============================================================
pause
