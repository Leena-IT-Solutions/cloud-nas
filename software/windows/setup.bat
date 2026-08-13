@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ============================================================
echo      🚀 Windows 1-Click Cloud NAS Dual-Engine Installer 🚀
echo ============================================================

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_ROOT=%%~fI"

set "KEY_FILE=%PROJECT_ROOT%\leena-it-solutions-412315-f63f3bd287c1.json"
set "RCLONE_BIN=%SCRIPT_DIR%\rclone.exe"
set "MOUNT_VBS=%SCRIPT_DIR%\windows-mount-hidden.vbs"
set "GUI_SCRIPT=%PROJECT_ROOT%\cloud_nas_gui.py"

rem 0. Dynamically resolve absolute Python executable path on Windows
set "PYTHON_EXE="
for %%P in (pythonw.exe pyw.exe python.exe py.exe) do (
    where %%P >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where %%P') do (
            if not defined PYTHON_EXE set "PYTHON_EXE=%%I"
        )
    )
)

if not defined PYTHON_EXE (
    set "PYTHON_EXE=python.exe"
)
echo [OK] Using Python Executable: %PYTHON_EXE%

rem 1. Check Key File
if not exist "%KEY_FILE%" (
    echo [ERROR] GCP Key file leena-it-solutions-412315-f63f3bd287c1.json not found in %PROJECT_ROOT%!
    pause
    exit /b 1
)
echo [OK] Found GCP Key: %KEY_FILE%

rem 2. Check / Download Rclone Binary (High Speed Silent Download)
if not exist "%RCLONE_BIN%" (
    echo [INFO] Downloading official Rclone binary for Windows...
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-windows-amd64.zip' -OutFile '%TEMP%\rclone.zip'"
    powershell -Command "Expand-Archive -Path '%TEMP%\rclone.zip' -DestinationPath '%TEMP%\rclone_out' -Force"
    copy /Y "%TEMP%\rclone_out\rclone-v1.70.0-windows-amd64\rclone.exe" "%RCLONE_BIN%" >nul
    del /F /Q "%TEMP%\rclone.zip"
    rmdir /S /Q "%TEMP%\rclone_out"
)
echo [OK] Rclone Binary Ready: %RCLONE_BIN%

rem 3. Check / Install WinFsp Driver for Native High-Speed Disk Drive Mounting
sc query winfsp >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing WinFsp Native Drive Driver for Windows...
    winget install --id WinFsp.WinFsp -e --source winget --accept-source-agreements --accept-package-agreements >nul 2>&1
    if errorlevel 1 (
        powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi' -OutFile '%TEMP%\winfsp.msi'"
        msiexec /i "%TEMP%\winfsp.msi" /qn /norestart >nul 2>&1
        del /F /Q "%TEMP%\winfsp.msi" >nul 2>&1
    )
)
echo [OK] WinFsp Native Drive Driver Ready!

rem 4. Start Windows WebClient Service & Configure Registry (WebDAV Fallback)
echo [INFO] Enabling Windows WebClient Service ^& Registry Settings...
reg add HKLM\SYSTEM\CurrentControlSet\Services\WebClient\Parameters /v BasicAuthLevel /t REG_DWORD /d 2 /f >nul 2>&1
sc config WebClient start= auto >nul 2>&1
net start WebClient >nul 2>&1

rem 5. Mount Cloud NAS Network Drive
echo [INFO] Mounting Cloud NAS Network Drive...
cscript //nologo "%MOUNT_VBS%"

rem 6. Add Windows Start Menu, Desktop & Startup Shortcuts for GUI
set "STARTMENU_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "DESKTOP_FOLDER=%USERPROFILE%\Desktop"
set "SHORTCUT_VBS=%TEMP%\create_shortcut.vbs"

echo Set oWS = WScript.CreateObject("WScript.Shell") > "%SHORTCUT_VBS%"

echo Sub MakeShortcut(path) >> "%SHORTCUT_VBS%"
echo   Set oLink = oWS.CreateShortcut(path) >> "%SHORTCUT_VBS%"
echo   oLink.TargetPath = "%PYTHON_EXE%" >> "%SHORTCUT_VBS%"
echo   oLink.Arguments = """%GUI_SCRIPT%""" >> "%SHORTCUT_VBS%"
echo   oLink.WorkingDirectory = "%PROJECT_ROOT%" >> "%SHORTCUT_VBS%"
echo   oLink.Description = "Cloud NAS Control Center" >> "%SHORTCUT_VBS%"
echo   oLink.Save >> "%SHORTCUT_VBS%"
echo End Sub >> "%SHORTCUT_VBS%"

echo MakeShortcut "%STARTMENU_FOLDER%\Cloud NAS Control Center.lnk" >> "%SHORTCUT_VBS%"
echo MakeShortcut "%STARTUP_FOLDER%\Cloud NAS Control Center.lnk" >> "%SHORTCUT_VBS%"
if exist "%DESKTOP_FOLDER%" echo MakeShortcut "%DESKTOP_FOLDER%\Cloud NAS Control Center.lnk" >> "%SHORTCUT_VBS%"

cscript //nologo "%SHORTCUT_VBS%" >nul 2>&1
del /F /Q "%SHORTCUT_VBS%" >nul 2>&1

echo ============================================================
echo [SUCCESS] Cloud NAS mounted ^& installed to Windows Startup!
echo ============================================================

start "" "%PYTHON_EXE%" "%GUI_SCRIPT%"
