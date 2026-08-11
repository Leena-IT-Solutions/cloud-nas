@echo off
setlocal enabledelayedexpansion

:: Windows 1-Click Zero-Dependency Cloud NAS Installer
set SCRIPT_DIR=%~dp0
set KEY_FILE=%SCRIPT_DIR%leena-it-solutions-412315-f63f3bd287c1.json
set BUCKET_NAME=sv-school
set REMOTE_NAME=gcsnas
set DRIVE_LETTER=Y:

echo ============================================================
echo       🚀 Windows 1-Click Cloud NAS Installer 🚀
echo ============================================================
echo.

:: 1. Check Key File
if not exist "%KEY_FILE%" (
    echo [ERROR] GCP Key file not found!
    echo Looking for: %KEY_FILE%
    echo Please make sure leena-it-solutions-412315-f63f3bd287c1.json is in the same folder as setup.bat.
    echo.
    pause
    exit /b 1
)
echo [OK] Found GCP Credentials Key.

:: 2. Check & Install WinFSP Driver
set WINFSP_FOUND=0
if exist "C:\Program Files (x86)\WinFsp\bin" set WINFSP_FOUND=1
if exist "C:\Program Files\WinFsp\bin" set WINFSP_FOUND=1

if %WINFSP_FOUND%==0 (
    echo [NOTICE] WinFSP driver is required for Windows drive letters.
    echo [INFO] Downloading WinFSP installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/winfsp/winfsp/releases/download/v2.0/winfsp-2.0.23075.msi' -OutFile '%SCRIPT_DIR%winfsp_installer.msi'"
    if exist "%SCRIPT_DIR%winfsp_installer.msi" (
        echo [INFO] Launching WinFSP Installer... Please complete the installation wizard!
        msiexec /i "%SCRIPT_DIR%winfsp_installer.msi" /qb
        echo [OK] WinFSP installation finished.
    ) else (
        echo [WARNING] Automatic WinFSP download failed. Opening download page...
        start https://winfsp.dev/
        echo Please install WinFSP and then press any key to continue...
        pause
    )
) else (
    echo [OK] WinFSP Driver is installed.
)

:: 3. Check & Prepare Rclone Binary
set RCLONE_BIN=C:\rclone\rclone.exe
if not exist "%RCLONE_BIN%" (
    if exist "%SCRIPT_DIR%rclone.exe" (
        set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
    ) else (
        echo [INFO] Downloading Rclone for Windows...
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-windows-amd64.zip' -OutFile '%SCRIPT_DIR%rclone.zip'"
        if exist "%SCRIPT_DIR%rclone.zip" (
            powershell -Command "Expand-Archive -Path '%SCRIPT_DIR%rclone.zip' -DestinationPath '%SCRIPT_DIR%temp_rclone' -Force"
            copy /y "%SCRIPT_DIR%temp_rclone\rclone-v1.70.0-windows-amd64\rclone.exe" "%SCRIPT_DIR%rclone.exe" >nul
            del /f /q "%SCRIPT_DIR%rclone.zip" >nul
            rmdir /s /q "%SCRIPT_DIR%temp_rclone" >nul
            set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
        ) else (
            echo [ERROR] Failed to download Rclone. Please check internet connection.
            pause
            exit /b 1
        )
    )
)
echo [OK] Rclone Binary Ready: %RCLONE_BIN%

:: 4. Configure Rclone Remote
echo [INFO] Configuring Rclone GCS Remote '%REMOTE_NAME%'...
"%RCLONE_BIN%" config create %REMOTE_NAME% googlecloudstorage service_account_file "%KEY_FILE%" bucket_policy_only true

:: 5. Create Auto-Mount script inside shell:startup
set STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
echo [INFO] Adding Cloud NAS auto-mount to Windows Startup folder (shell:startup)...

echo Set WshShell = CreateObject("WScript.Shell") > "%STARTUP_DIR%\CloudNAS-AutoMount.vbs"
echo WshShell.Run "cscript //nologo ""%SCRIPT_DIR%windows-mount-hidden.vbs""", 0, False >> "%STARTUP_DIR%\CloudNAS-AutoMount.vbs"
echo WshShell.Run "pythonw.exe ""%SCRIPT_DIR%cloud_nas_gui.py""", 0, False >> "%STARTUP_DIR%\CloudNAS-AutoMount.vbs"

echo [OK] Auto-mount on Windows boot enabled!

:: 6. Create Start Menu Programs Shortcut with custom icon
echo [INFO] Creating Windows Start Menu Shortcut with custom app icon...
powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Cloud NAS.lnk'); $s.TargetPath='pythonw.exe'; $s.Arguments='""%SCRIPT_DIR%cloud_nas_gui.py""'; $s.WorkingDirectory='%SCRIPT_DIR%'; $s.IconLocation='%SCRIPT_DIR%app_icon.png'; $s.Save()"
echo [OK] Installed 'Cloud NAS' with custom app icon in Windows Start Menu!

:: 7. Launch Background Mount & Control Center GUI Now
echo [INFO] Launching Cloud NAS Drive %DRIVE_LETTER% and Control Center GUI...
cscript //nologo "%SCRIPT_DIR%windows-mount-hidden.vbs"
start "" pythonw "%SCRIPT_DIR%cloud_nas_gui.py"

echo.
echo ============================================================
echo [SUCCESS] Cloud NAS Setup Completed!
echo Check 'This PC' in File Explorer for Local Disk (%DRIVE_LETTER%)
echo 'Cloud NAS' app added to Windows Start Menu Programs!
echo ============================================================
echo.
pause
