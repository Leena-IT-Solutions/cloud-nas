@echo off
:: Windows Cloud NAS Auto-Mount Script
:: Ensure WinFSP and Rclone are installed

set BUCKET_NAME=sv-school
set REMOTE_NAME=gcsnas
set DRIVE_LETTER=Z:
set RCLONE_PATH=C:\rclone\rclone.exe

echo Mounting Google Cloud Storage Bucket '%BUCKET_NAME%' as %DRIVE_LETTER% Drive...

%RCLONE_PATH% mount %REMOTE_NAME%:%BUCKET_NAME% %DRIVE_LETTER% ^
    --vfs-cache-mode full ^
    --vfs-cache-max-size 10G ^
    --vfs-cache-max-age 24h ^
    --vfs-write-back 1s ^
    --gcs-bucket-policy-only ^
    --no-modtime

echo Cloud NAS Drive %DRIVE_LETTER% is now live in Windows File Explorer!
pause
