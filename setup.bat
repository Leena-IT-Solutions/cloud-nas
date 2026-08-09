@echo off
:: Windows 1-Click Zero-Dependency Cloud NAS Installer
:: Works natively on Windows 10 & 11 without installing Python!

set SCRIPT_DIR=%~dp0
set KEY_FILE=%SCRIPT_DIR%leena-it-solutions-412315-f63f3bd287c1.json
set BUCKET_NAME=sv-school
set REMOTE_NAME=gcsnas
set DRIVE_LETTER=Y:
set RCLONE_BIN=C:\rclone\rclone.exe

echo ============================================================
echo       🚀 Windows 1-Click Cloud NAS Installer 🚀
echo ============================================================

:: Check Key File
if not exist "%KEY_FILE%" (
    echo [ERROR] GCP Key file leena-it-solutions-412315-f63f3bd287c1.json not found in %SCRIPT_DIR%!
    pause
    exit /b 1
)
echo [OK] Found GCP Credentials Key.

:: Check WinFSP
if not exist "C:\Program Files (x86)\WinFsp\bin" (
    if not exist "C:\Program Files\WinFsp\bin" (
        echo [NOTICE] WinFSP driver is required for Windows drive letters.
        echo Opening WinFSP installer webpage...
        start https://winfsp.dev/
    )
)

:: Check Rclone
if not exist "%RCLONE_BIN%" (
    if exist "%SCRIPT_DIR%rclone.exe" (
        set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
    ) else (
        echo [INFO] Downloading Rclone for Windows...
        powershell -Command "Invoke-WebRequest -Uri 'https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-windows-amd64.zip' -OutFile '%SCRIPT_DIR%rclone.zip'"
        powershell -Command "Expand-Archive -Path '%SCRIPT_DIR%rclone.zip' -DestinationPath '%SCRIPT_DIR%temp_rclone' -Force"
        copy /y "%SCRIPT_DIR%temp_rclone\rclone-v1.70.0-windows-amd64\rclone.exe" "%SCRIPT_DIR%rclone.exe"
        del /f "%SCRIPT_DIR%rclone.zip"
        rmdir /s /q "%SCRIPT_DIR%temp_rclone"
        set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
    )
)
echo [OK] Rclone Binary Ready: %RCLONE_BIN%

:: Configure Rclone
echo [INFO] Configuring Rclone GCS Remote...
"%RCLONE_BIN%" config create %REMOTE_NAME% googlecloudstorage service_account_file "%KEY_FILE%" bucket_policy_only true >nul 2>&1

:: Trigger Silent Background Mount
echo [INFO] Launching Cloud NAS Drive %DRIVE_LETTER%...
cscript //nologo "%SCRIPT_DIR%windows-mount-hidden.vbs"

echo ============================================================
echo [SUCCESS] Cloud NAS mounted! Check This PC -> Local Disk (%DRIVE_LETTER%)
echo ============================================================
pause
