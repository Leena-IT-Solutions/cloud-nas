@echo off
setlocal enabledelayedexpansion

:: Windows Cloud NAS Diagnostic & Test Tool
set SCRIPT_DIR=%~dp0
set KEY_FILE=%SCRIPT_DIR%leena-it-solutions-412315-f63f3bd287c1.json
set BUCKET_NAME=sv-school
set REMOTE_NAME=gcsnas
set DRIVE_LETTER=Y:

echo ============================================================
echo       🔍 Windows Cloud NAS Diagnostic & Test Tool 🔍
echo ============================================================
echo.

:: Test 1: Check Key File
echo [TEST 1] Checking GCP Key File...
if exist "%KEY_FILE%" (
    echo   [PASS] Key file found: %KEY_FILE%
) else (
    echo   [FAIL] Key file NOT found! Missing: %KEY_FILE%
)
echo.

:: Test 2: Check WinFSP
echo [TEST 2] Checking WinFSP Driver...
set WINFSP_INSTALLED=0
if exist "C:\Program Files (x86)\WinFsp\bin" set WINFSP_INSTALLED=1
if exist "C:\Program Files\WinFsp\bin" set WINFSP_INSTALLED=1

if %WINFSP_INSTALLED%==1 (
    echo   [PASS] WinFSP driver is installed.
) else (
    echo   [FAIL] WinFSP driver is NOT installed! (Required for Windows drive letters)
)
echo.

:: Test 3: Check Rclone Binary
echo [TEST 3] Checking Rclone Binary...
set RCLONE_BIN=C:\rclone\rclone.exe
if not exist "%RCLONE_BIN%" (
    if exist "%SCRIPT_DIR%rclone.exe" (
        set RCLONE_BIN=%SCRIPT_DIR%rclone.exe
    ) else (
        set RCLONE_BIN=rclone.exe
    )
)

"%RCLONE_BIN%" version >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Rclone executable working: %RCLONE_BIN%
) else (
    echo   [FAIL] Rclone executable missing or failed to run.
)
echo.

:: Test 4: Check GCS API Connection
echo [TEST 4] Testing Connection to Google Cloud Storage bucket '%BUCKET_NAME%'...
"%RCLONE_BIN%" ls %REMOTE_NAME%:%BUCKET_NAME% --gcs-bucket-policy-only
if %errorlevel%==0 (
    echo   [PASS] Successfully connected to GCS bucket '%BUCKET_NAME%'!
) else (
    echo   [FAIL] Failed to connect to GCS bucket. See error above.
)
echo.

:: Test 5: Live Foreground Mount Test
echo ============================================================
echo [TEST 5] Starting Live Test Mount on Drive %DRIVE_LETTER%...
echo Press Ctrl+C in this console when finished testing.
echo ============================================================
echo.

"%RCLONE_BIN%" mount %REMOTE_NAME%:%BUCKET_NAME% %DRIVE_LETTER% ^
    --vfs-cache-mode full ^
    --vfs-cache-max-size 10G ^
    --vfs-cache-max-age 24h ^
    --vfs-write-back 1s ^
    --gcs-bucket-policy-only ^
    --no-modtime

echo.
pause
